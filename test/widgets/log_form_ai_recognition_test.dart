import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/services/ai_audio_recorder.dart';
import 'package:openlogtool/services/ai_credential_store.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition_runtime.dart';
import 'package:openlogtool/services/secure_token_store.dart';
import 'package:openlogtool/services/text_assistant.dart';
import 'package:openlogtool/services/text_assistant_tasks.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('workbench entry follows the AI enabled setting', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    final recorder = _FakeAiAudioRecorder();

    await tester.pumpWidget(
      _TestApp(aiSettings: aiSettings, recorder: recorder),
    );
    await tester.pump();
    expect(find.byKey(const Key('ai-recognition-control')), findsNothing);

    await _enableAi(aiSettings);
    await tester.pump();
    expect(find.byKey(const Key('ai-recognition-control')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await aiSettings.setEnabled(false);
    await tester.pump();
    expect(find.byKey(const Key('ai-recognition-control')), findsNothing);
    expect(recorder.permissionRequests, 0);
    expect(recorder.startCalls, 0);
  });

  testWidgets('recognized fields require review and never apply time',
      (tester) async {
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableAi(aiSettings);
    final recorder = _FakeAiAudioRecorder();

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: recorder,
        executor: (_, __, ___) async => AiRecognitionResult(
          transcription: Transcription(text: 'BG5CRL，信号报告五七，八点。'),
          candidates: [
            RecognitionCandidate(
              fields: const {
                'controller': 'BA5AAA',
                'callsign': 'BG5CRL',
                'rstSent': '57',
                'time': '20:00',
                'power': '',
              },
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await _recordAndOpenReview(tester);
    expect(find.text('BG5CRL，信号报告五七，八点。'), findsOneWidget);
    expect(find.textContaining('Callsign: BG5CRL'), findsOneWidget);
    expect(find.textContaining('Time: 20:00'), findsOneWidget);
    expect(find.textContaining('Controller callsign: BA5AAA'), findsNothing);
    expect(find.textContaining('Power:'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('ai-apply-candidates')));
    await tester.tap(find.byKey(const Key('ai-apply-candidates')));
    await tester.pumpAndSettle();

    expect(_fieldController(tester, 'Callsign').text, 'BG5CRL');
    expect(_fieldController(tester, 'RST sent').text, '59');
    expect(_fieldController(tester, 'Time').text, isEmpty);
  });

  testWidgets('field changes while recognition runs make suggestions stale',
      (tester) async {
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableAi(aiSettings);
    final recorder = _FakeAiAudioRecorder();
    final response = Completer<AiRecognitionResult>();

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: recorder,
        executor: (_, __, ___) => response.future,
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
    tester
        .widget<FilledButton>(
          find.byKey(const Key('ai-start-recording')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pump();

    await tester.enterText(_fieldFinder('Callsign'), 'BA1ABC');
    response.complete(
      AiRecognitionResult(
        transcription: Transcription(text: 'BG5CRL'),
        candidates: [
          RecognitionCandidate(fields: const {'callsign': 'BG5CRL'}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('The field changed after recording began'), findsOneWidget);
    final apply = tester.widget<FilledButton>(
      find.byKey(const Key('ai-apply-candidates')),
    );
    expect(apply.onPressed, isNull);
    expect(_fieldController(tester, 'Callsign').text, 'BA1ABC');

    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('collaboration applies reviewed suggestions through strict CAS',
      (tester) async {
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableAi(aiSettings);
    final collaboration = _EditableCollaborationProvider();

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(),
        collaboration: collaboration,
        executor: (_, __, ___) async => AiRecognitionResult(
          transcription: Transcription(text: 'BG5CRL'),
          candidates: [
            RecognitionCandidate(fields: const {'callsign': 'BG5CRL'}),
          ],
        ),
      ),
    );
    await tester.pump();

    await _recordAndOpenReview(tester);
    await tester.ensureVisible(find.byKey(const Key('ai-apply-candidates')));
    await tester.tap(find.byKey(const Key('ai-apply-candidates')));
    await tester.pumpAndSettle();

    expect(collaboration.strictUpdates, [
      const {'callsign': 'BG5CRL'}
    ]);
    expect(collaboration.strictExpectedDraftId, 'draft-1');
    expect(collaboration.strictExpectedValues, const {'callsign': ''});
    expect(collaboration.strictExpectedRevisions, const {'callsign': 0});
  });

  testWidgets('shows cumulative structured fields with no recording time limit',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableAi(aiSettings);
    final recorder = _FakeAiAudioRecorder(
      live: true,
      liveChunks: [_audio(), _audio()],
      includeStopSegment: false,
    );
    var transcriptionCalls = 0;

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: recorder,
        transcriptionExecutor: (_, __, ___) async => Transcription(
          text: ++transcriptionCalls == 1 ? 'BG5EUU，申请上台。' : '设备威诺 N7，QTH 二楼。',
        ),
        fieldExtractionExecutor: (
          transcription,
          settings,
          cancellationToken, {
          referenceContext,
        }) async {
          final fields = <String, String>{
            if (transcription.text.contains('BG5EUU')) 'callsign': 'BG5EUU',
            if (transcription.text.contains('威诺 N7')) 'device': '威诺 N7',
            if (transcription.text.contains('二楼')) 'qth': '二楼',
          };
          return AiRecognitionResult(
            transcription: transcription,
            candidates: [
              RecognitionCandidate(fields: fields),
            ],
          );
        },
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(find.byKey(const Key('ai-live-structured')), findsOneWidget);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.text('BG5EUU'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.byKey(const Key('ai-live-field-device')), findsOneWidget);
    expect(find.byKey(const Key('ai-live-field-qth')), findsOneWidget);

    await tester.pump(const Duration(seconds: 100));
    expect(find.byKey(const Key('ai-stop-recording')), findsOneWidget);
    expect(recorder.stopCalls, 0);

    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-review-panel')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'inline normalization appears after 300 ms and fills on selection',
      (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final aiSettings = AiRecognitionSettingsProvider(
      credentialStore: AiCredentialStore(secureValues: _MemorySecureValues()),
    );
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await aiSettings.saveTextAssistant(
      provider: TextAssistantProvider.openAiCompatible,
      baseUrl: Uri.parse('https://text.example/v1'),
      model: 'fast-model',
      secret: 'secret',
    );
    var calls = 0;

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(),
        inlineTextSuggestionExecutor: ({
          required settings,
          required field,
          required value,
          localReferences = const <String>[],
          cancellationToken,
        }) async {
          calls += 1;
          expect(field, 'device');
          expect(value, 'ft991a');
          return 'FT-991A';
        },
      ),
    );
    await tester.pump();
    final device = _fieldFinder('Radio');
    await tester.ensureVisible(device);
    await tester.tap(device);
    await tester.enterText(device, 'ft991a');
    await tester.pump(const Duration(milliseconds: 299));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(calls, 1);
    final suggestion = find.byKey(const Key('inline-ai-suggestion-device'));
    expect(suggestion, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_fieldController(tester, 'Radio').text, 'FT-991A');
  });

  testWidgets('uses the single-call path when a multimodal profile is set',
      (tester) async {
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableMultimodal(aiSettings);
    var singleCalls = 0;
    var twoHopCalls = 0;

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(),
        recognizer: (audio, settings, cancellationToken) async {
          singleCalls++;
          return AiRecognitionResult(
            transcription: Transcription(text: 'BG5DBL'),
            candidates: [
              RecognitionCandidate(fields: const {'callsign': 'BG5DBL'}),
            ],
          );
        },
        transcriptionExecutor: (audio, settings, token) async {
          twoHopCalls++;
          return Transcription(text: 'should not run');
        },
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(singleCalls, 1);
    expect(twoHopCalls, 0);
    expect(find.byKey(const Key('ai-review-panel')), findsOneWidget);
    expect(find.textContaining('Callsign: BG5DBL'), findsOneWidget);
  });
}

Future<void> _enableAi(AiRecognitionSettingsProvider settings) async {
  final profile = AiProviderProfile(
    id: 'asr-test',
    name: 'Test ASR',
    kind: AiProviderKind.speechRecognition,
    protocol: AiProtocol.openAiAudioTranscriptions,
    baseUrl: Uri.parse('https://example.test'),
    model: 'test-model',
    credentialTransport: const AiCredentialTransport.none(),
  );
  await settings.upsertProfile(profile);
  await settings.setActiveAsrProfile(profile.id);
  await settings.setEnabled(true);
}

Future<void> _enableMultimodal(AiRecognitionSettingsProvider settings) async {
  final profile = AiProviderProfile(
    id: 'multimodal-test',
    name: 'Test multimodal',
    kind: AiProviderKind.audioFieldExtraction,
    protocol: AiProtocol.openAiChatCompletionsAudio,
    baseUrl: Uri.parse('https://audio.example.test/v1'),
    model: 'audio-model',
    credentialTransport: const AiCredentialTransport.none(),
    capabilities: const AiProviderCapabilities(
      supportsAudioFieldExtraction: true,
    ),
  );
  await settings.upsertProfile(profile);
  await settings.setActiveAudioFieldExtractionProfile(profile.id);
  await settings.setEnabled(true);
}

Future<void> _recordAndOpenReview(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
  tester
      .widget<FilledButton>(find.byKey(const Key('ai-start-recording')))
      .onPressed!();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ai-stop-recording')), findsOneWidget);
  await tester.tap(find.byKey(const Key('ai-stop-recording')));
  await tester.pumpAndSettle();
  expect(find.text('Review AI suggestions'), findsOneWidget);
}

Finder _fieldFinder(String label) => find
    .ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    )
    .first;

TextEditingController _fieldController(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(_fieldFinder(label)).controller!;

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.aiSettings,
    required this.recorder,
    this.executor,
    this.recognizer,
    this.transcriptionExecutor,
    this.fieldExtractionExecutor,
    this.inlineTextSuggestionExecutor,
    this.collaboration,
  });

  final AiRecognitionSettingsProvider aiSettings;
  final AiAudioRecorder recorder;
  final AiRecognitionExecutor? executor;
  final AiRecognitionExecutor? recognizer;
  final AiTranscriptionExecutor? transcriptionExecutor;
  final AiFieldExtractionExecutor? fieldExtractionExecutor;
  final InlineTextSuggestionExecutor? inlineTextSuggestionExecutor;
  final CollaborationProvider? collaboration;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AiRecognitionSettingsProvider>.value(
            value: aiSettings,
          ),
          ChangeNotifierProvider<CollaborationProvider>(
            create: (_) => collaboration ?? CollaborationProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => DictionaryProvider(autoload: false),
          ),
          ChangeNotifierProvider(
            create: (_) => LogProvider(
              sessionListLoader: () async => [],
              sessionLogPageLoader: (_, __, ___) async => [],
            ),
          ),
          ChangeNotifierProvider<SessionProvider>(
            create: (_) => _TestSessionProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(systemFontsLoader: () async => []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LogForm(
                aiAudioRecorder: recorder,
                aiRecognitionExecutor: executor,
                aiRecognizer: recognizer,
                aiTranscriptionExecutor: transcriptionExecutor,
                aiFieldExtractionExecutor: fieldExtractionExecutor,
                inlineTextSuggestionExecutor: inlineTextSuggestionExecutor,
              ),
            ),
          ),
        ),
      );
}

final class _MemorySecureValues implements SecureValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _TestSessionProvider extends SessionProvider {
  @override
  String? get currentSessionId => 'session-1';
}

class _FakeAiAudioRecorder implements AiAudioRecorder {
  _FakeAiAudioRecorder({
    this.live = false,
    List<AudioSegment> liveChunks = const [],
    bool includeStopSegment = true,
    AudioSegment? stopSegment,
  })  : _liveChunks = List<AudioSegment>.of(liveChunks),
        _stopSegment = includeStopSegment ? stopSegment ?? _audio() : null;

  final bool live;
  final List<AudioSegment> _liveChunks;
  final AudioSegment? _stopSegment;
  int permissionRequests = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  bool get supportsLiveChunks => live;

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return true;
  }

  @override
  Future<void> start() async {
    startCalls += 1;
  }

  @override
  Future<AudioSegment?> stop() async {
    stopCalls += 1;
    return _stopSegment;
  }

  @override
  Future<AudioSegment?> takeLiveChunk() async =>
      _liveChunks.isEmpty ? null : _liveChunks.removeAt(0);

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
  }

  @override
  Future<void> dispose() async {}
}

AudioSegment _audio() => AudioSegment(
      bytes: const [82, 73, 70, 70],
      mimeType: 'audio/wav',
      fileName: 'test.wav',
    );

class _EditableCollaborationProvider extends CollaborationProvider {
  _EditableCollaborationProvider()
      : _snapshot = LiveDraftSnapshotDto(
          draft: LiveDraftDto(
            draftId: 'draft-1',
            sessionId: 'session-1',
            version: 1,
            fields: LiveDraftFieldsDto(const {
              'controller': 'BY1ABC',
              'rstSent': '59',
              'rstRcvd': '59',
            }),
            fieldRevisions: {
              for (final field in liveDraftFieldNames) field: 0,
            },
            lastUpdatedBy: null,
            createdAt: DateTime.utc(2026, 7, 21),
            lastUpdatedAt: DateTime.utc(2026, 7, 21),
          ),
          locks: const [],
          currentOrdinal: 1,
          totalRecords: 0,
          previousRecord: null,
        );

  final LiveDraftSnapshotDto _snapshot;
  final List<Map<String, String>> strictUpdates = [];
  String? strictExpectedDraftId;
  Map<String, String>? strictExpectedValues;
  Map<String, int>? strictExpectedRevisions;

  @override
  LiveDraftSnapshotDto get liveDraftSnapshot => _snapshot;

  @override
  LiveDraftFieldsDto get liveDraftDisplayFields => _snapshot.draft.fields;

  @override
  bool get canEditLiveDraft => true;

  @override
  Future<void> updateLiveDraftFieldsStrict(
    Map<String, String> updates, {
    required String expectedDraftId,
    required Map<String, String> expectedValues,
    required Map<String, int> expectedRevisions,
  }) async {
    strictUpdates.add(Map<String, String>.from(updates));
    strictExpectedDraftId = expectedDraftId;
    strictExpectedValues = Map<String, String>.from(expectedValues);
    strictExpectedRevisions = Map<String, int>.from(expectedRevisions);
  }
}
