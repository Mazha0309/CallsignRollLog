import 'dart:async';
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/services/ai_audio_recorder.dart';
import 'package:openlogtool/services/app_logger.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/services/ai_candidate_guard.dart';
import 'package:openlogtool/services/ai_field_proofread.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition_runtime.dart';
import 'package:provider/provider.dart';

typedef AiDraftSnapshotBuilder = AiDraftSnapshot Function(
  int captureGeneration,
);
typedef AiApplicationStateBuilder = AiCandidateApplicationState Function(
  int captureGeneration,
);
typedef AiCandidateFieldsApplier = Future<void> Function(
  Map<String, String> values,
  AiDraftSnapshot expectedSnapshot,
);
typedef AiReferenceContextBuilder = String? Function(String transcript);

enum _AiControlStage { idle, recording, recognizing }

/// Optional workbench entry point. The parent only inserts this widget while
/// AI recognition is enabled, so an off setting never touches the microphone.
class AiRecognitionControl extends StatefulWidget {
  const AiRecognitionControl({
    super.key,
    this.recordEpoch = 0,
    required this.captureSnapshot,
    required this.currentState,
    required this.applyFields,
    this.readOnly = false,
    this.busy = false,
    this.audioRecorder,
    this.executor,
    this.recognizer = AiRecognitionRuntime.recognizeRecord,
    this.transcriptionExecutor = AiRecognitionRuntime.transcribe,
    this.fieldExtractionExecutor = AiRecognitionRuntime.extractFields,
    this.referenceContextBuilder,
  });

  /// Changes when the visible record is saved or cleared. Recording stays up;
  /// only the previous recognition context is dropped.
  final int recordEpoch;
  final AiDraftSnapshotBuilder captureSnapshot;
  final AiApplicationStateBuilder currentState;
  final AiCandidateFieldsApplier applyFields;
  final bool readOnly;
  final bool busy;
  final AiAudioRecorder? audioRecorder;
  final AiRecognitionExecutor? executor;
  final AiRecognitionExecutor recognizer;
  final AiTranscriptionExecutor transcriptionExecutor;
  final AiFieldExtractionExecutor fieldExtractionExecutor;
  final AiReferenceContextBuilder? referenceContextBuilder;

  @override
  State<AiRecognitionControl> createState() => _AiRecognitionControlState();
}

class _AiRecognitionControlState extends State<AiRecognitionControl> {
  static const _liveChunkInterval = Duration(seconds: 15);

  late final AiAudioRecorder _audioRecorder;
  _AiControlStage _stage = _AiControlStage.idle;
  AiCancellationToken? _cancellationToken;
  AiDraftSnapshot? _baseline;
  Timer? _elapsedTimer;
  Timer? _liveChunkTimer;
  Future<void>? _liveTranscriptionInFlight;
  final Map<int, Transcription> _liveTranscriptions = {};
  final Map<int, AiRecognitionResult> _singleCallResults = {};
  final List<({int sequence, AudioSegment audio})> _retryChunks = [];
  String? _liveTranscriptionError;
  AiRecognitionResult? _liveStructuredPreview;
  int _elapsedSeconds = 0;
  int _captureGeneration = 0;
  int _nextChunkSequence = 0;

  @override
  void initState() {
    super.initState();
    _audioRecorder = widget.audioRecorder ?? DeviceAiAudioRecorder();
  }

  @override
  void didUpdateWidget(covariant AiRecognitionControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recordEpoch != oldWidget.recordEpoch) {
      if (_stage == _AiControlStage.recording) {
        _beginNextRecord();
      } else {
        _liveStructuredPreview = null;
        _liveTranscriptionError = null;
      }
    }
  }

  @override
  void dispose() {
    _captureGeneration += 1;
    _cancellationToken?.cancel();
    _elapsedTimer?.cancel();
    _liveChunkTimer?.cancel();
    unawaited(_audioRecorder.dispose().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_stage != _AiControlStage.idle || widget.readOnly || widget.busy) {
      return;
    }
    final settings = context.read<AiRecognitionSettingsProvider>();
    if (!settings.enabled || settings.activeRecognitionProfile == null) {
      return;
    }

    try {
      final permitted = await _audioRecorder.requestPermission();
      if (!mounted) return;
      if (!permitted) {
        _showMessage(context.l10n.aiMicrophonePermissionDenied);
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      final generation = ++_captureGeneration;
      final baseline = widget.captureSnapshot(generation);
      final cancellationToken = AiCancellationToken();
      await _audioRecorder.start();
      if (!mounted || generation != _captureGeneration) {
        await _audioRecorder.cancel();
        return;
      }
      _baseline = baseline;
      _cancellationToken = cancellationToken;
      _elapsedSeconds = 0;
      _liveTranscriptions.clear();
      _singleCallResults.clear();
      _retryChunks.clear();
      _nextChunkSequence = 0;
      _liveTranscriptionError = null;
      _liveStructuredPreview = null;
      setState(() => _stage = _AiControlStage.recording);
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _stage != _AiControlStage.recording) {
          timer.cancel();
          return;
        }
        setState(() => _elapsedSeconds += 1);
      });
      if (_audioRecorder.supportsLiveChunks) {
        _liveChunkTimer = Timer.periodic(_liveChunkInterval, (_) {
          if (!mounted || _stage != _AiControlStage.recording) return;
          _scheduleLiveTranscription(_captureGeneration);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _stage = _AiControlStage.idle);
        _showMessage(_reportedFailure(
          error,
          ai: (message) => context.l10n.aiRecordingFailed(message),
        ));
      }
    }
  }

  void _scheduleLiveTranscription(int generation) {
    if (_liveTranscriptionInFlight != null ||
        _stage != _AiControlStage.recording ||
        generation != _captureGeneration) {
      return;
    }
    late final Future<void> operation;
    operation = _transcribeLiveChunk(generation).whenComplete(() {
      if (identical(_liveTranscriptionInFlight, operation)) {
        _liveTranscriptionInFlight = null;
      }
    });
    _liveTranscriptionInFlight = operation;
  }

  Future<void> _transcribeLiveChunk(int generation) async {
    AudioSegment? chunk;
    late final int sequence;
    late final Transcription transcription;
    AiRecognitionResult? direct;
    try {
      chunk = await _audioRecorder.takeLiveChunk();
      if (chunk == null ||
          !mounted ||
          generation != _captureGeneration ||
          _stage != _AiControlStage.recording) {
        return;
      }
      sequence = _nextChunkSequence++;
      final token = _cancellationToken;
      if (token == null) return;
      final settings = context.read<AiRecognitionSettingsProvider>();
      direct = await _directRecognition(chunk, settings, token);
      if (direct != null && !_hasRecognizedSpeech(direct)) return;
      transcription = direct?.transcription ??
          await widget.transcriptionExecutor(
            chunk,
            settings,
            token,
          );
      if (!mounted || generation != _captureGeneration) return;
      _liveTranscriptions[sequence] = transcription;
      if (direct != null) _singleCallResults[sequence] = direct;
    } on AiRecognitionException catch (error) {
      if (error.kind == AiRecognitionErrorKind.cancelled ||
          error.kind == AiRecognitionErrorKind.nothingRecognized) {
        return;
      }
      _logProviderResponse(error);
      if (chunk != null) {
        _retryChunks.add((sequence: sequence, audio: chunk));
      }
      if (mounted && generation == _captureGeneration) {
        setState(() => _liveTranscriptionError = _visibleFailure(error));
      }
      return;
    } catch (error) {
      if (chunk != null) {
        _retryChunks.add((sequence: sequence, audio: chunk));
      }
      if (mounted && generation == _captureGeneration) {
        setState(() => _liveTranscriptionError = _visibleFailure(error));
      }
      return;
    }

    if (direct != null) {
      if (!mounted || generation != _captureGeneration) return;
      final preview = _combinedSingleCallResult();
      setState(() {
        _liveTranscriptionError = null;
        _liveStructuredPreview = preview;
      });
      return;
    }

    final text = _joinedTranscript;
    if (text.isEmpty || !mounted || generation != _captureGeneration) return;
    setState(() => _liveTranscriptionError = null);
    try {
      final token = _cancellationToken;
      if (token == null) return;
      final result = await widget.fieldExtractionExecutor(
        Transcription(text: text),
        context.read<AiRecognitionSettingsProvider>(),
        token,
        referenceContext: widget.referenceContextBuilder?.call(text),
      );
      if (!mounted || generation != _captureGeneration) return;
      final proofread = _proofread(result, locked: _livePreviewFields);
      setState(() {
        _liveStructuredPreview = proofread;
        _liveTranscriptionError = null;
      });
    } on AiRecognitionException catch (error) {
      if (error.kind == AiRecognitionErrorKind.cancelled) return;
      _logProviderResponse(error);
      if (mounted && generation == _captureGeneration) {
        setState(() => _liveTranscriptionError = _visibleFailure(error));
      }
    } catch (error) {
      if (mounted && generation == _captureGeneration) {
        setState(() => _liveTranscriptionError = _visibleFailure(error));
      }
    }
  }

  Future<void> _stopAndRecognize() async {
    if (_stage != _AiControlStage.recording) return;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _liveChunkTimer?.cancel();
    _liveChunkTimer = null;
    final generation = _captureGeneration;
    final baseline = _baseline;
    final usedLiveChunks = _audioRecorder.supportsLiveChunks;
    setState(() => _stage = _AiControlStage.recognizing);
    try {
      await _liveTranscriptionInFlight;
      final audio = await _audioRecorder.stop();
      if (!mounted || generation != _captureGeneration || baseline == null) {
        return;
      }
      final cancellationToken = _cancellationToken ?? AiCancellationToken();
      final settings = context.read<AiRecognitionSettingsProvider>();
      late final AiRecognitionResult result;
      if (!usedLiveChunks) {
        if (audio == null) throw StateError('AI_AUDIO_EMPTY');
        final direct =
            await _directRecognition(audio, settings, cancellationToken);
        if (direct != null) {
          result = direct;
        } else {
          final transcription = await widget.transcriptionExecutor(
            audio,
            settings,
            cancellationToken,
          );
          result = await widget.fieldExtractionExecutor(
            transcription,
            settings,
            cancellationToken,
            referenceContext:
                widget.referenceContextBuilder?.call(transcription.text),
          );
        }
      } else {
        final remaining = <({int sequence, AudioSegment audio})>[
          ..._retryChunks,
          if (audio != null) (sequence: _nextChunkSequence++, audio: audio),
        ];
        remaining.sort((a, b) => a.sequence.compareTo(b.sequence));
        _retryChunks.clear();
        final directPath = widget.executor != null || _usesSingleCall(settings);
        for (final chunk in remaining) {
          if (directPath) {
            final AiRecognitionResult recognized;
            try {
              final direct = await _directRecognition(
                chunk.audio,
                settings,
                cancellationToken,
              );
              if (direct == null) throw StateError('AI_AUDIO_EMPTY');
              recognized = direct;
            } on AiRecognitionException catch (error) {
              if (error.kind == AiRecognitionErrorKind.nothingRecognized) {
                continue;
              }
              rethrow;
            }
            if (!_hasRecognizedSpeech(recognized)) continue;
            _liveTranscriptions[chunk.sequence] = recognized.transcription;
            _singleCallResults[chunk.sequence] = recognized;
          } else {
            final transcription = await widget.transcriptionExecutor(
              chunk.audio,
              settings,
              cancellationToken,
            );
            _liveTranscriptions[chunk.sequence] = transcription;
          }
          if (mounted && generation == _captureGeneration) setState(() {});
        }
        if (directPath) {
          if (_singleCallResults.isEmpty) {
            throw const AiRecognitionException(
              kind: AiRecognitionErrorKind.nothingRecognized,
              message: 'The provider returned an empty transcript',
            );
          }
          result = _combinedSingleCallResult();
        } else {
          final text = _joinedTranscript;
          if (text.isEmpty) throw StateError('AI_AUDIO_EMPTY');
          result = await widget.fieldExtractionExecutor(
            Transcription(text: text),
            settings,
            cancellationToken,
            referenceContext: widget.referenceContextBuilder?.call(text),
          );
        }
      }
      if (!mounted || generation != _captureGeneration) return;
      final proofread = _proofread(result, locked: _livePreviewFields);
      setState(() {
        _stage = _AiControlStage.idle;
        _liveStructuredPreview = proofread;
      });
    } on AiRecognitionException catch (error) {
      if (error.kind != AiRecognitionErrorKind.cancelled) {
        _logProviderResponse(error);
      }
      if (error.kind != AiRecognitionErrorKind.cancelled && mounted) {
        _showMessage(
          context.l10n.aiRecognitionFailed(aiUserFacingErrorMessage(error)),
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context.l10n.aiUnknownFailure);
      }
    } finally {
      if (mounted && generation == _captureGeneration) {
        setState(() => _stage = _AiControlStage.idle);
      }
      _cancellationToken = null;
      _baseline = null;
    }
  }

  Future<void> _cancel() async {
    if (_stage == _AiControlStage.idle) return;
    _captureGeneration += 1;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _liveChunkTimer?.cancel();
    _liveChunkTimer = null;
    _cancellationToken?.cancel();
    if (_stage == _AiControlStage.recording) {
      try {
        await _audioRecorder.cancel();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _stage = _AiControlStage.idle;
        _elapsedSeconds = 0;
        _baseline = null;
        _liveTranscriptions.clear();
        _singleCallResults.clear();
        _retryChunks.clear();
        _liveTranscriptionError = null;
        _liveStructuredPreview = null;
      });
    }
  }

  void _beginNextRecord() {
    final generation = ++_captureGeneration;
    _cancellationToken?.cancel();
    _cancellationToken = AiCancellationToken();
    _baseline = widget.captureSnapshot(generation);
    _liveTranscriptions.clear();
    _singleCallResults.clear();
    _retryChunks.clear();
    _nextChunkSequence = 0;
    _liveTranscriptionError = null;
    _liveStructuredPreview = null;
  }

  Future<void> _applyLiveField(String field, String value) async {
    if (!mounted || widget.readOnly || widget.busy) return;
    final generation = _captureGeneration;
    final state = widget.currentState(generation);
    if (state.readOnly ||
        state.busy ||
        generation != _captureGeneration ||
        state.composingFields.contains(field) ||
        state.lockedFields.contains(field)) {
      return;
    }
    try {
      await widget.applyFields({field: value}, state.snapshot);
    } catch (error) {
      if (mounted && generation == _captureGeneration) {
        _showMessage(context.l10n.operationFailed('$error'));
      }
    }
  }

  bool _usesSingleCall(AiRecognitionSettingsProvider settings) =>
      settings.recognitionMode == AiRecognitionMode.audio &&
      settings.activeAudioFieldExtractionProfile != null;

  /// An injected executor wins. Otherwise the selected mode decides: multimodal
  /// is one call, speech recognition stays speech-then-extraction.
  Future<AiRecognitionResult?> _directRecognition(
    AudioSegment audio,
    AiRecognitionSettingsProvider settings,
    AiCancellationToken cancellationToken,
  ) {
    final injected = widget.executor;
    if (injected != null) {
      return injected(audio, settings, cancellationToken);
    }
    if (!_usesSingleCall(settings)) {
      return Future<AiRecognitionResult?>.value();
    }
    return widget.recognizer(audio, settings, cancellationToken);
  }

  AiRecognitionResult _combinedSingleCallResult() {
    final ordered = (_singleCallResults.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((entry) => entry.value)
        .toList(growable: false);
    if (ordered.isEmpty) throw StateError('AI_AUDIO_EMPTY');
    if (ordered.length == 1) return ordered.single;
    final text = ordered
        .map((result) => result.transcription.text.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (text.isEmpty) throw StateError('AI_AUDIO_EMPTY');
    final dictionary = _dictionaryTerms();
    var fields = <String, String>{};
    for (final result in ordered) {
      if (result.candidates.isEmpty) continue;
      fields = proofreadAiFields(
        result.candidates.first.fields,
        locked: fields,
        dictionary: dictionary,
      );
    }
    return AiRecognitionResult(
      transcription: Transcription(text: text),
      candidates: [
        if (fields.isNotEmpty)
          RecognitionCandidate(fields: Map<String, Object?>.of(fields)),
      ],
    );
  }

  bool _hasRecognizedSpeech(AiRecognitionResult result) =>
      result.transcription.text.trim().isNotEmpty;

  AiDictionaryTerms _dictionaryTerms() {
    final dictionaries = context.read<DictionaryProvider>();
    return AiDictionaryTerms(
      callsigns: [for (final item in dictionaries.callsignDict) item.raw],
      devices: [for (final item in dictionaries.deviceDict) item.raw],
      antennas: [for (final item in dictionaries.antennaDict) item.raw],
      qths: [for (final item in dictionaries.qthDict) item.raw],
    );
  }

  AiRecognitionResult _proofread(
    AiRecognitionResult result, {
    Map<String, String> locked = const {},
  }) =>
      proofreadAiResult(
        result,
        locked: locked,
        dictionary: _dictionaryTerms(),
      );

  String get _joinedTranscript => (_liveTranscriptions.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)))
      .map((entry) => entry.value.text.trim())
      .where((text) => text.isNotEmpty)
      .join(' ');

  Map<String, String> get _livePreviewFields {
    final candidates = _liveStructuredPreview?.candidates;
    if (candidates == null || candidates.isEmpty) return const {};
    final fields = <String, String>{};
    for (final entry in candidates.first.fields.entries) {
      final value = entry.value;
      if (!AiCandidateGuard.supportedFields.contains(entry.key) ||
          value is! String ||
          value.trim().isEmpty) {
        continue;
      }
      fields[entry.key] = value.trim();
    }
    return fields;
  }

  void _logProviderResponse(AiRecognitionException error) {
    final body = error.responseBody?.trim();
    AppLogger.instance.log(
      AppLogLevel.error,
      [
        error.message,
        if (error.statusCode != null) 'HTTP ${error.statusCode}',
        if (body != null && body.isNotEmpty) body,
      ].join('\n'),
      source: 'AI',
    );
  }

  String _visibleFailure(Object error) => error is AiRecognitionException
      ? aiUserFacingErrorMessage(error)
      : context.l10n.aiUnknownFailure;

  String _reportedFailure(
    Object error, {
    required String Function(String message) ai,
  }) =>
      error is AiRecognitionException
          ? ai(aiUserFacingErrorMessage(error))
          : context.l10n.aiUnknownFailure;

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showLoggedSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = widget.readOnly || widget.busy;
    final isRecording = _stage == _AiControlStage.recording;
    final isRecognizing = _stage == _AiControlStage.recognizing;
    final status = isRecording
        ? context.l10n.aiRecordingStatus(_formatElapsed(_elapsedSeconds))
        : isRecognizing
            ? context.l10n.aiRecognizingStatus
            : context.l10n.aiReadyStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('ai-recognition-control'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRecording
                  ? colorScheme.error.withValues(alpha: 0.7)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isRecording
                        ? Icons.graphic_eq
                        : Icons.auto_awesome_outlined,
                    color:
                        isRecording ? colorScheme.error : colorScheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.aiWorkbenchTitle,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          disabled
                              ? context.l10n.aiWorkbenchUnavailable
                              : status,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (_stage != _AiControlStage.idle) ...[
                    IconButton(
                      key: const Key('ai-cancel-recognition'),
                      tooltip: context.l10n.cancel,
                      onPressed: _cancel,
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 4),
                  ],
                  FilledButton.tonalIcon(
                    key: Key(
                      isRecording ? 'ai-stop-recording' : 'ai-start-recording',
                    ),
                    onPressed: disabled || isRecognizing
                        ? null
                        : isRecording
                            ? _stopAndRecognize
                            : _startRecording,
                    icon: Icon(isRecording ? Icons.stop : Icons.mic_none),
                    label: Text(
                      isRecording
                          ? context.l10n.aiStopAndRecognize
                          : context.l10n.aiStartRecording,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.aiExperimentalNotice,
                key: const Key('ai-experimental-notice'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              if (_liveTranscriptionError case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.aiLiveTranscriptionRetrying(error),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (_livePreviewFields.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            key: const Key('ai-live-fields'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final field in _chipFieldOrder)
                if (_livePreviewFields[field] case final value?)
                  ActionChip(
                    key: Key('ai-live-field-$field'),
                    label: Text(_chipLabel(context, field, value)),
                    onPressed: disabled
                        ? null
                        : () => unawaited(_applyLiveField(field, value)),
                  ),
            ],
          ),
        ],
      ],
    );
  }

  static const _chipFieldOrder = [
    'callsign',
    'rstSent',
    'rstRcvd',
    'qth',
    'device',
    'power',
    'antenna',
    'height',
    'remarks',
  ];

  String _chipLabel(BuildContext context, String field, String value) {
    final name = switch (field) {
      'callsign' => context.l10n.fieldCallsign,
      'rstSent' => context.l10n.fieldRstSent,
      'rstRcvd' => context.l10n.fieldRstRcvd,
      'qth' => context.l10n.fieldQth,
      'device' => context.l10n.fieldDevice,
      'power' => context.l10n.fieldPower,
      'antenna' => context.l10n.fieldAntenna,
      'height' => context.l10n.fieldHeight,
      'remarks' => context.l10n.fieldRemarks,
      _ => field,
    };
    return '$name $value';
  }

  String _formatElapsed(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
