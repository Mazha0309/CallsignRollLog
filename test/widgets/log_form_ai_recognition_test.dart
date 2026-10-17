import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/services/ai_audio_recorder.dart';
import 'package:openlogtool/services/app_logger.dart';
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
    expect(find.byKey(const Key('ai-experimental-notice')), findsOneWidget);
    expect(find.textContaining('Not finished yet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await aiSettings.setEnabled(false);
    await tester.pump();
    expect(find.byKey(const Key('ai-recognition-control')), findsNothing);
    expect(recorder.permissionRequests, 0);
    expect(recorder.startCalls, 0);
  });

  testWidgets('recognized fields stay out of the form until a chip is tapped',
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

    await _recordAndStop(tester);

    expect(find.text('BG5CRL，信号报告五七，八点。'), findsNothing);
    expect(find.byKey(const Key('ai-review-panel')), findsNothing);
    expect(find.byKey(const Key('ai-live-transcript')), findsNothing);
    expect(find.byKey(const Key('ai-live-field-time')), findsNothing);
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(_fieldController(tester, 'RST sent').text, '59');
    expect(_fieldController(tester, 'Time').text, isEmpty);
    expect(_fieldController(tester, 'Controller callsign *').text, isEmpty);

    await _tapLiveField(tester, 'callsign');
    expect(_fieldController(tester, 'Callsign').text, 'BG5CRL');
    expect(_fieldController(tester, 'RST sent').text, '59');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: _fieldFinder('Callsign'),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );

    await _tapLiveField(tester, 'rstSent');
    expect(_fieldController(tester, 'RST sent').text, '57');
    expect(_fieldController(tester, 'Callsign').text, 'BG5CRL');
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

    expect(find.byKey(const Key('ai-review-panel')), findsNothing);
    expect(find.text('The field changed after recording began'), findsNothing);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(_fieldController(tester, 'Callsign').text, 'BA1ABC');
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

    await _recordAndStop(tester);
    expect(collaboration.strictUpdates, isEmpty);

    await _tapLiveField(tester, 'callsign');

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

    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.text('BG5EUU，申请上台。'), findsNothing);
    expect(find.byKey(const Key('ai-live-transcript')), findsNothing);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(_fieldController(tester, 'Radio').text, isEmpty);
    expect(_fieldController(tester, 'QTH').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.byKey(const Key('ai-live-field-device')), findsOneWidget);
    expect(find.byKey(const Key('ai-live-field-qth')), findsOneWidget);

    await tester.pump(const Duration(seconds: 100));
    expect(find.byKey(const Key('ai-stop-recording')), findsOneWidget);
    expect(recorder.stopCalls, 0);

    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-review-panel')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);

    await _tapLiveField(tester, 'callsign');
    expect(_fieldController(tester, 'Callsign').text, 'BG5EUU');
    expect(_fieldController(tester, 'Radio').text, isEmpty);
    expect(_fieldController(tester, 'QTH').text, isEmpty);
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
    expect(find.byKey(const Key('ai-review-panel')), findsNothing);
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
  });

  testWidgets('speech mode ignores a saved multimodal profile', (tester) async {
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableAi(aiSettings);
    await _enableMultimodal(aiSettings);
    await aiSettings.setRecognitionMode(AiRecognitionMode.speech);
    var singleCalls = 0;
    var twoHopCalls = 0;

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(),
        recognizer: (audio, settings, cancellationToken) async {
          singleCalls++;
          return AiRecognitionResult(
            transcription: Transcription(text: 'should not run'),
            candidates: [
              RecognitionCandidate(fields: const {'callsign': 'BG5XXX'}),
            ],
          );
        },
        transcriptionExecutor: (audio, settings, token) async {
          twoHopCalls++;
          return Transcription(text: 'BG5DBL');
        },
        fieldExtractionExecutor: (
          transcription,
          settings,
          cancellationToken, {
          referenceContext,
        }) async =>
            AiRecognitionResult(
          transcription: transcription,
          candidates: [
            RecognitionCandidate(fields: const {'callsign': 'BG5DBL'}),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(singleCalls, 0);
    expect(twoHopCalls, 1);
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.text('should not run'), findsNothing);
  });

  testWidgets('shows a readable message instead of the raw error',
      (tester) async {
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableMultimodal(aiSettings);

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(),
        recognizer: (audio, settings, cancellationToken) async =>
            throw const AiRecognitionException(
          kind: AiRecognitionErrorKind.missingCredentials,
          message: 'missing credentials for provider multi',
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(find.textContaining('还没填 API Key'), findsOneWidget);
    expect(find.textContaining('missing credentials'), findsNothing);
    expect(find.textContaining('AiRecognitionException'), findsNothing);
  });

  testWidgets('logs the provider response without putting it on screen',
      (tester) async {
    AppLogger.instance.resetForTest();
    addTearDown(AppLogger.instance.resetForTest);
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableMultimodal(aiSettings);

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(),
        recognizer: (audio, settings, cancellationToken) async =>
            throw const AiRecognitionException(
          kind: AiRecognitionErrorKind.invalidResponse,
          message: 'The audio field extraction response is not JSON',
          responseBody: '抱歉，我没听清',
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(find.textContaining('无法解析'), findsOneWidget);
    expect(find.textContaining('抱歉，我没听清'), findsNothing);
    expect(
      AppLogger.instance
          .snapshotEntries()
          .map((entry) => entry.message)
          .join('\n'),
      contains('抱歉，我没听清'),
    );
  });

  testWidgets('moves a callsign out of QTH and drops 73 from RST',
      (tester) async {
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableMultimodal(aiSettings);

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(),
        recognizer: (audio, settings, cancellationToken) async =>
            AiRecognitionResult(
          transcription: Transcription(text: 'BG5CRL 73'),
          candidates: [
            RecognitionCandidate(
              fields: const {
                'qth': 'BG5CRL',
                'rstSent': '73',
                'rstRcvd': '59',
              },
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(_fieldController(tester, 'QTH').text, isEmpty);
    expect(_fieldController(tester, 'RST sent').text, '59');
    expect(_fieldController(tester, 'RST received').text, '59');
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.byKey(const Key('ai-live-field-qth')), findsNothing);
    expect(find.byKey(const Key('ai-live-field-rstSent')), findsNothing);
  });

  testWidgets('does not let a later chunk replace a dictionary device',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableMultimodal(aiSettings);
    var calls = 0;

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        dictionary: _FixedDictionaryProvider(
          devices: const ['泉盛UVK6'],
          callsigns: const ['BG5CRL'],
        ),
        recorder: _FakeAiAudioRecorder(
          live: true,
          liveChunks: [_audio(), _audio()],
          includeStopSegment: false,
        ),
        recognizer: (audio, settings, cancellationToken) async {
          calls += 1;
          if (calls == 1) {
            return AiRecognitionResult(
              transcription: Transcription(text: 'BG5CRL 泉盛UVK6'),
              candidates: [
                RecognitionCandidate(
                  fields: const {
                    'callsign': 'BG5CRL',
                    'device': '泉盛UVK6',
                  },
                ),
              ],
            );
          }
          return AiRecognitionResult(
            transcription: Transcription(text: '全盛U V K 六'),
            candidates: [
              RecognitionCandidate(
                fields: const {'device': '全盛U V K 六'},
              ),
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
    expect(_fieldController(tester, 'Radio').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-device')), findsOneWidget);
    expect(find.textContaining('全盛'), findsNothing);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(_fieldController(tester, 'Radio').text, isEmpty);
    expect(find.textContaining('全盛'), findsNothing);
    expect(find.textContaining('泉盛UVK6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();
    expect(_fieldController(tester, 'Radio').text, isEmpty);
    expect(find.textContaining('全盛'), findsNothing);
    expect(find.textContaining('泉盛UVK6'), findsOneWidget);
  });

  testWidgets('keeps earlier fields when the final slice is empty',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableMultimodal(aiSettings);
    var calls = 0;

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: _FakeAiAudioRecorder(
          live: true,
          liveChunks: [_audio()],
        ),
        recognizer: (audio, settings, cancellationToken) async {
          calls += 1;
          if (calls == 1) {
            return AiRecognitionResult(
              transcription: Transcription(text: 'BG5CRL'),
              candidates: [
                RecognitionCandidate(fields: const {'callsign': 'BG5CRL'}),
              ],
            );
          }
          throw const AiRecognitionException(
            kind: AiRecognitionErrorKind.nothingRecognized,
            message: 'The provider returned an empty transcript',
            responseBody: '{"transcript":"","fields":{}}',
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
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-review-panel')), findsNothing);
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.textContaining('没有听清'), findsNothing);
  });

  testWidgets('the next record keeps recording and drops the previous callsign',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final aiSettings = AiRecognitionSettingsProvider();
    addTearDown(aiSettings.dispose);
    await aiSettings.initialized;
    await _enableMultimodal(aiSettings);
    final recorder = _FakeAiAudioRecorder(
      live: true,
      liveChunks: [_audio(), _audio()],
      includeStopSegment: false,
    );
    var calls = 0;

    await tester.pumpWidget(
      _TestApp(
        aiSettings: aiSettings,
        recorder: recorder,
        recognizer: (audio, settings, cancellationToken) async {
          calls += 1;
          final callsign = calls == 1 ? 'BG5AAA' : 'BG5BBB';
          return AiRecognitionResult(
            transcription: Transcription(text: callsign),
            candidates: [
              RecognitionCandidate(fields: {'callsign': callsign}),
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
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsOneWidget);
    expect(find.textContaining('BG5AAA'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('clear-log-fields')));
    await tester.tap(find.byKey(const Key('clear-log-fields')));
    await tester.pump();

    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.byKey(const Key('ai-live-field-callsign')), findsNothing);
    expect(find.byKey(const Key('ai-stop-recording')), findsOneWidget);
    expect(recorder.stopCalls, 0);
    expect(recorder.cancelCalls, 0);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(_fieldController(tester, 'Callsign').text, isEmpty);
    expect(find.textContaining('BG5BBB'), findsOneWidget);
    expect(find.textContaining('BG5AAA'), findsNothing);
    expect(recorder.stopCalls, 0);
    expect(recorder.cancelCalls, 0);
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

Future<void> _tapLiveField(WidgetTester tester, String field) async {
  final chip = find.byKey(Key('ai-live-field-$field'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _recordAndStop(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('ai-start-recording')));
  tester
      .widget<FilledButton>(find.byKey(const Key('ai-start-recording')))
      .onPressed!();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('ai-stop-recording')), findsOneWidget);
  await tester.tap(find.byKey(const Key('ai-stop-recording')));
  await tester.pumpAndSettle();
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
    this.dictionary,
  });

  final AiRecognitionSettingsProvider aiSettings;
  final AiAudioRecorder recorder;
  final AiRecognitionExecutor? executor;
  final AiRecognitionExecutor? recognizer;
  final AiTranscriptionExecutor? transcriptionExecutor;
  final AiFieldExtractionExecutor? fieldExtractionExecutor;
  final InlineTextSuggestionExecutor? inlineTextSuggestionExecutor;
  final CollaborationProvider? collaboration;
  final DictionaryProvider? dictionary;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AiRecognitionSettingsProvider>.value(
            value: aiSettings,
          ),
          ChangeNotifierProvider<CollaborationProvider>(
            create: (_) => collaboration ?? CollaborationProvider(),
          ),
          ChangeNotifierProvider<DictionaryProvider>(
            create: (_) => dictionary ?? DictionaryProvider(autoload: false),
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

class _FixedDictionaryProvider extends DictionaryProvider {
  _FixedDictionaryProvider({
    this.devices = const [],
    this.callsigns = const [],
  }) : super(autoload: false);

  final List<String> devices;
  final List<String> callsigns;

  DictionaryItem _item(String raw, String type) => DictionaryItem(
        raw: raw,
        pinyin: '',
        abbreviation: '',
        type: type,
      );

  @override
  List<DictionaryItem> get deviceDict =>
      [for (final raw in devices) _item(raw, 'device')];

  @override
  List<DictionaryItem> get callsignDict =>
      [for (final raw in callsigns) _item(raw, 'callsign')];
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
