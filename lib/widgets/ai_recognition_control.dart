import 'dart:async';
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/services/ai_audio_recorder.dart';
import 'package:openlogtool/services/ai_candidate_guard.dart';
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
  bool _liveFormatting = false;
  _AiPendingReview? _pendingReview;
  int _elapsedSeconds = 0;
  int _captureGeneration = 0;
  int _nextChunkSequence = 0;

  @override
  void initState() {
    super.initState();
    _audioRecorder = widget.audioRecorder ?? DeviceAiAudioRecorder();
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
    if (_stage != _AiControlStage.idle ||
        widget.readOnly ||
        widget.busy ||
        _pendingReview != null) {
      return;
    }
    final settings = context.read<AiRecognitionSettingsProvider>();
    if (!settings.enabled ||
        (settings.activeAsrProfile == null &&
            settings.activeAudioFieldExtractionProfile == null)) {
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
      _liveFormatting = false;
      setState(() => _stage = _AiControlStage.recording);
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _stage != _AiControlStage.recording) {
          timer.cancel();
          return;
        }
        setState(() => _elapsedSeconds += 1);
      });
      if (_audioRecorder.supportsLiveChunks) {
        _liveChunkTimer = Timer.periodic(
          _liveChunkInterval,
          (_) => _scheduleLiveTranscription(generation),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _stage = _AiControlStage.idle);
        _showMessage(context.l10n.aiRecordingFailed(error.toString()));
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
      if (error.kind == AiRecognitionErrorKind.cancelled) return;
      if (chunk != null) {
        _retryChunks.add((sequence: sequence, audio: chunk));
      }
      if (mounted && generation == _captureGeneration) {
        setState(() => _liveTranscriptionError = error.message);
      }
      return;
    } catch (error) {
      if (chunk != null) {
        _retryChunks.add((sequence: sequence, audio: chunk));
      }
      if (mounted && generation == _captureGeneration) {
        setState(() => _liveTranscriptionError = error.toString());
      }
      return;
    }

    if (direct != null) {
      if (!mounted || generation != _captureGeneration) return;
      setState(() {
        _liveTranscriptionError = null;
        _liveStructuredPreview = _combinedSingleCallResult();
        _liveFormatting = false;
      });
      return;
    }

    final text = _joinedTranscript;
    if (text.isEmpty || !mounted || generation != _captureGeneration) return;
    setState(() {
      _liveTranscriptionError = null;
      _liveFormatting = true;
    });
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
      setState(() {
        _liveStructuredPreview = result;
        _liveTranscriptionError = null;
        _liveFormatting = false;
      });
    } on AiRecognitionException catch (error) {
      if (error.kind == AiRecognitionErrorKind.cancelled) return;
      if (mounted && generation == _captureGeneration) {
        setState(() {
          _liveTranscriptionError = error.message;
          _liveFormatting = false;
        });
      }
    } catch (error) {
      if (mounted && generation == _captureGeneration) {
        setState(() {
          _liveTranscriptionError = error.toString();
          _liveFormatting = false;
        });
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
        final directPath = widget.executor != null ||
            settings.activeAudioFieldExtractionProfile != null;
        for (final chunk in remaining) {
          if (directPath) {
            final recognized = await _directRecognition(
              chunk.audio,
              settings,
              cancellationToken,
            );
            if (recognized == null) throw StateError('AI_AUDIO_EMPTY');
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
      setState(() => _stage = _AiControlStage.idle);
      await _reviewResult(result, baseline, generation);
    } on AiRecognitionException catch (error) {
      if (error.kind != AiRecognitionErrorKind.cancelled && mounted) {
        _showMessage(context.l10n.aiRecognitionFailed(error.message));
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context.l10n.aiRecognitionFailed(error.toString()));
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
        _liveFormatting = false;
      });
    }
  }

  Future<void> _reviewResult(
    AiRecognitionResult result,
    AiDraftSnapshot baseline,
    int generation,
  ) async {
    final initialState = widget.currentState(generation);
    final initialAssessments = [
      for (final candidate in result.candidates)
        AiCandidateGuard.assess(
          candidate,
          baseline: baseline,
          current: initialState,
        ).where(_showCandidateAssessment).toList(growable: false),
    ];
    setState(
      () => _pendingReview = _AiPendingReview(
        result: result,
        baseline: baseline,
        generation: generation,
        assessments: initialAssessments,
      ),
    );
  }

  Future<void> _applyPendingReview(_AiReviewSelection selection) async {
    final pending = _pendingReview;
    if (pending == null || pending.generation != _captureGeneration) {
      return;
    }

    final candidate = pending.result.candidates[selection.candidateIndex];
    final applicationState = widget.currentState(pending.generation);
    final reassessed = AiCandidateGuard.assess(
      candidate,
      baseline: pending.baseline,
      current: applicationState,
    );
    final byField = {for (final item in reassessed) item.field: item};
    final values = <String, String>{};
    for (final field in selection.fields) {
      final assessment = byField[field];
      if (assessment?.canOfferApply ?? false) {
        values[field] = assessment!.value;
      }
    }
    if (values.isEmpty) {
      _showMessage(context.l10n.aiCandidatesStale);
      return;
    }
    try {
      await widget.applyFields(values, applicationState.snapshot);
      if (mounted) {
        setState(() => _pendingReview = null);
        _showMessage(context.l10n.aiCandidatesApplied(values.length));
      }
    } catch (error) {
      if (mounted) {
        _showMessage(context.l10n.aiApplyFailed(error.toString()));
      }
    }
  }

  /// An injected executor wins. Otherwise a selected multimodal profile takes
  /// the single call. Returning null keeps the speech-then-extraction path.
  Future<AiRecognitionResult?> _directRecognition(
    AudioSegment audio,
    AiRecognitionSettingsProvider settings,
    AiCancellationToken cancellationToken,
  ) {
    final injected = widget.executor;
    if (injected != null) {
      return injected(audio, settings, cancellationToken);
    }
    if (settings.activeAudioFieldExtractionProfile == null) {
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
    final fields = <String, Object?>{};
    for (final result in ordered) {
      if (result.candidates.isEmpty) continue;
      fields.addAll(result.candidates.first.fields);
    }
    return AiRecognitionResult(
      transcription: Transcription(text: text),
      candidates: [
        if (fields.isNotEmpty) RecognitionCandidate(fields: fields),
      ],
    );
  }

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

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showLoggedSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = widget.readOnly || widget.busy || _pendingReview != null;
    final isRecording = _stage == _AiControlStage.recording;
    final isRecognizing = _stage == _AiControlStage.recognizing;
    final status = isRecording
        ? context.l10n.aiRecordingStatus(_formatElapsed(_elapsedSeconds))
        : isRecognizing
            ? context.l10n.aiRecognizingStatus
            : context.l10n.aiReadyStatus;

    final livePreviewFields = _livePreviewFields;
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
                          disabled && _pendingReview == null
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
              if (_stage != _AiControlStage.idle) ...[
                const Divider(height: 20),
                Text(
                  context.l10n.aiLiveTranscriptTitle,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                if (livePreviewFields.isNotEmpty)
                  _AiLiveStructuredPreview(fields: livePreviewFields)
                else
                  Text(
                    _liveFormatting
                        ? context.l10n.aiLiveStructuredUpdating
                        : context.l10n.aiLiveStructuredWaiting,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (_liveTranscriptionError case final error?) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.aiLiveTranscriptionRetrying(error),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (_pendingReview case final pending?) ...[
          const SizedBox(height: 10),
          _AiRecognitionReviewPanel(
            result: pending.result,
            assessments: pending.assessments,
            onCancel: () => setState(() => _pendingReview = null),
            onApply: _applyPendingReview,
          ),
        ],
      ],
    );
  }

  String _formatElapsed(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _AiLiveStructuredPreview extends StatelessWidget {
  const _AiLiveStructuredPreview({required this.fields});

  static const _fieldOrder = <String>[
    'callsign',
    'device',
    'antenna',
    'power',
    'qth',
    'height',
    'rstSent',
    'rstRcvd',
    'remarks',
  ];

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = [
      for (final field in _fieldOrder)
        if (fields[field] case final value?) MapEntry(field, value),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 420
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          key: const Key('ai-live-structured'),
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Container(
                  key: Key('ai-live-field-${entry.key}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_fieldLabel(context, entry.key)}：',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _AiReviewSelection {
  const _AiReviewSelection({
    required this.candidateIndex,
    required this.fields,
  });

  final int candidateIndex;
  final Set<String> fields;
}

final class _AiPendingReview {
  const _AiPendingReview({
    required this.result,
    required this.baseline,
    required this.generation,
    required this.assessments,
  });

  final AiRecognitionResult result;
  final AiDraftSnapshot baseline;
  final int generation;
  final List<List<AiFieldCandidateAssessment>> assessments;
}

class _AiRecognitionReviewPanel extends StatefulWidget {
  const _AiRecognitionReviewPanel({
    required this.result,
    required this.assessments,
    required this.onCancel,
    required this.onApply,
  });

  final AiRecognitionResult result;
  final List<List<AiFieldCandidateAssessment>> assessments;
  final VoidCallback onCancel;
  final ValueChanged<_AiReviewSelection> onApply;

  @override
  State<_AiRecognitionReviewPanel> createState() =>
      _AiRecognitionReviewPanelState();
}

class _AiRecognitionReviewPanelState extends State<_AiRecognitionReviewPanel> {
  int _candidateIndex = 0;
  Set<String> _selectedFields = const {};

  @override
  void initState() {
    super.initState();
    _resetSelection();
  }

  void _resetSelection() {
    if (widget.assessments.isEmpty) {
      _selectedFields = const {};
      return;
    }
    _selectedFields = {
      for (final item in widget.assessments[_candidateIndex])
        if (item.decision == AiCandidateDecision.fillEmpty) item.field,
    };
  }

  @override
  Widget build(BuildContext context) {
    final assessments = widget.assessments.isEmpty
        ? const <AiFieldCandidateAssessment>[]
        : widget.assessments[_candidateIndex];
    final hasCandidates = assessments.isNotEmpty;
    return Card(
      key: const Key('ai-review-panel'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.aiReviewTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.aiTranscriptTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SelectableText(widget.result.transcription.text),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: widget.result.transcription.text),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showLoggedSnackBar(
                      SnackBar(content: Text(context.l10n.aiTranscriptCopied)),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text(context.l10n.aiCopyTranscript),
              ),
            ),
            const Divider(height: 24),
            if (!hasCandidates)
              Text(context.l10n.aiNoStructuredCandidates)
            else ...[
              if (widget.result.candidates.length > 1)
                DropdownButtonFormField<int>(
                  initialValue: _candidateIndex,
                  decoration: InputDecoration(
                    labelText: context.l10n.aiCandidateRecord,
                  ),
                  items: [
                    for (var index = 0;
                        index < widget.result.candidates.length;
                        index += 1)
                      DropdownMenuItem(
                        value: index,
                        child: Text(context.l10n.aiCandidateNumber(index + 1)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _candidateIndex = value;
                      _resetSelection();
                    });
                  },
                ),
              if (widget.result.candidates.length > 1)
                const SizedBox(height: 10),
              Text(
                context.l10n.aiCandidateHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final assessment in assessments)
                _CandidateFieldTile(
                  assessment: assessment,
                  selected: _selectedFields.contains(assessment.field),
                  onChanged: assessment.canOfferApply
                      ? (selected) {
                          setState(() {
                            final next = Set<String>.of(_selectedFields);
                            selected
                                ? next.add(assessment.field)
                                : next.remove(assessment.field);
                            _selectedFields = next;
                          });
                        }
                      : null,
                ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(context.l10n.cancel),
                ),
                if (hasCandidates) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('ai-apply-candidates'),
                    onPressed: _selectedFields.isEmpty
                        ? null
                        : () => widget.onApply(
                              _AiReviewSelection(
                                candidateIndex: _candidateIndex,
                                fields: Set.unmodifiable(_selectedFields),
                              ),
                            ),
                    child: Text(context.l10n.aiApplySelected),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateFieldTile extends StatelessWidget {
  const _CandidateFieldTile({
    required this.assessment,
    required this.selected,
    required this.onChanged,
  });

  final AiFieldCandidateAssessment assessment;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final replacement = assessment.requiresReplacementConfirmation;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged:
          onChanged == null ? null : (value) => onChanged!(value == true),
      title: Text(
        '${_fieldLabel(context, assessment.field)}: ${assessment.value}',
      ),
      subtitle: Text(
        replacement
            ? context.l10n.aiWillReplaceValue(assessment.currentValue)
            : _decisionLabel(context, assessment.decision),
      ),
    );
  }
}

String _fieldLabel(BuildContext context, String field) => switch (field) {
      'callsign' => context.l10n.fieldCallsign,
      'device' => context.l10n.fieldDevice,
      'antenna' => context.l10n.fieldAntenna,
      'power' => context.l10n.fieldPower,
      'qth' => context.l10n.fieldQth,
      'height' => context.l10n.fieldHeight,
      'rstSent' => context.l10n.fieldRstSent,
      'rstRcvd' => context.l10n.fieldRstRcvd,
      'remarks' => context.l10n.fieldRemarks,
      'time' => context.l10n.fieldTime,
      _ => field,
    };

bool _showCandidateAssessment(AiFieldCandidateAssessment assessment) =>
    assessment.decision != AiCandidateDecision.invalidValue &&
    (assessment.decision != AiCandidateDecision.unsupportedField ||
        assessment.field == 'time');

String _decisionLabel(BuildContext context, AiCandidateDecision decision) =>
    switch (decision) {
      AiCandidateDecision.fillEmpty => context.l10n.aiWillFillEmpty,
      AiCandidateDecision.replaceWithConfirmation =>
        context.l10n.aiReplacementNeedsConfirmation,
      AiCandidateDecision.unchanged => context.l10n.aiCandidateUnchanged,
      AiCandidateDecision.stale => context.l10n.aiCandidateStale,
      AiCandidateDecision.focused ||
      AiCandidateDecision.composing =>
        context.l10n.aiCandidateBeingEdited,
      AiCandidateDecision.locked => context.l10n.aiCandidateLocked,
      AiCandidateDecision.readOnly => context.l10n.aiCandidateReadOnly,
      AiCandidateDecision.busy => context.l10n.aiCandidateBusy,
      AiCandidateDecision.unsupportedField ||
      AiCandidateDecision.invalidValue =>
        context.l10n.aiCandidateInvalid,
    };
