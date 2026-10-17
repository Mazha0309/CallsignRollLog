import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/services/ai_credential_store.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition_runtime.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:openlogtool/services/secure_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('asks for Simplified Chinese equipment and QTH', () {
    expect(
      AiRecognitionRuntime.extractionInstructions,
      contains('Simplified Chinese (zh-CN)'),
    );
    expect(
      AiRecognitionRuntime.audioFieldExtractionInstructions,
      contains('Simplified Chinese (zh-CN)'),
    );
  });

  test('rejects filler-only transcripts before field extraction', () {
    expect(AiRecognitionRuntime.isActionableTranscription('嗯。'), isFalse);
    expect(AiRecognitionRuntime.isActionableTranscription('嗯嗯……'), isFalse);
    expect(AiRecognitionRuntime.isActionableTranscription(' uh! '), isFalse);
    expect(AiRecognitionRuntime.isActionableTranscription('BG5CDL'), isTrue);
  });

  test('extracts only explicitly stated wattage as a power fallback', () {
    expect(
      AiRecognitionRuntime.extractExplicitPower('五个瓦特功率发射'),
      '5 W',
    );
    expect(AiRecognitionRuntime.extractExplicitPower('功率二十五瓦'), '25 W');
    expect(AiRecognitionRuntime.extractExplicitPower('power 10 watts'), '10 W');
    expect(AiRecognitionRuntime.extractExplicitPower('没有提到功率'), isNull);
  });

  test('recognizeRecord drives the real entry once with the chosen profile',
      () async {
    final settings = await _settingsWithAudioFieldProfile();
    final profile = settings.activeAudioFieldExtractionProfile!;
    final segment = _segment();
    final expected = AiRecognitionResult(
      transcription: Transcription(text: 'BG5DBL 宁波高新区'),
      candidates: [
        RecognitionCandidate(
          fields: const {'callsign': 'BG5DBL'},
          sourceText: 'BG5DBL 宁波高新区',
        ),
      ],
    );
    final provider = _FakeAudioFieldExtractionProvider(
      profile: profile,
      result: expected,
    );
    final factoryProfiles = <AiProviderProfile>[];

    final result = await AiRecognitionRuntime.recognizeRecord(
      segment,
      settings,
      AiCancellationToken(),
      providerFactory: (selected) {
        factoryProfiles.add(selected);
        return provider;
      },
    );

    expect(factoryProfiles, hasLength(1));
    expect(factoryProfiles.single, same(profile));
    expect(provider.extractionCalls, 1);
    expect(provider.lastAudio, same(segment));
    expect(
      provider.lastInstructions,
      AiRecognitionRuntime.audioFieldExtractionInstructions,
    );
    expect(provider.closeCalls, 1);
    expect(result.transcription.text, 'BG5DBL 宁波高新区');
    expect(result.candidates.single.fields['callsign'], 'BG5DBL');
  });

  test('recognizeRecord rejects a missing mode A profile', () async {
    final settings = AiRecognitionSettingsProvider(
      credentialStore: AiCredentialStore(secureValues: _MemorySecureValues()),
    );
    await settings.initialized;

    await expectLater(
      AiRecognitionRuntime.recognizeRecord(
        _segment(),
        settings,
        AiCancellationToken(),
      ),
      throwsA(
        isA<AiRecognitionException>().having(
          (error) => error.kind,
          'kind',
          AiRecognitionErrorKind.invalidConfiguration,
        ),
      ),
    );
  });

  test(
      'recognizeRecord waits for settings initialization before reading '
      'the mode A profile', () async {
    // Persist a configured mode A profile, then hand the next provider a
    // loader we control so that its initialization cannot complete early.
    final seed = AiRecognitionSettingsProvider(
      credentialStore: AiCredentialStore(secureValues: _MemorySecureValues()),
    );
    await seed.initialized;
    await seed.upsertProfile(_audioFieldExtractionProfile());
    await seed.setActiveAudioFieldExtractionProfile(
      _audioFieldExtractionProfile().id,
    );

    final preferences = await SharedPreferences.getInstance();
    final pendingPreferences = Completer<KeyValueStore>();
    final settings = AiRecognitionSettingsProvider(
      preferencesLoader: () => pendingPreferences.future,
      credentialStore: AiCredentialStore(secureValues: _MemorySecureValues()),
    );

    // The provider has not loaded the persisted profile yet.
    expect(settings.activeAudioFieldExtractionProfile, isNull);

    final expected = AiRecognitionResult(
      transcription: Transcription(text: 'BG5DBL 宁波高新区'),
      candidates: [
        RecognitionCandidate(
          fields: const {'callsign': 'BG5DBL'},
          sourceText: 'BG5DBL 宁波高新区',
        ),
      ],
    );
    final provider = _FakeAudioFieldExtractionProvider(
      profile: _audioFieldExtractionProfile(),
      result: expected,
    );
    final factoryProfiles = <AiProviderProfile>[];

    // Intentionally do NOT await settings.initialized here: recognizeRecord
    // itself must wait for the pending load before selecting the profile.
    final pendingResult = AiRecognitionRuntime.recognizeRecord(
      _segment(),
      settings,
      AiCancellationToken(),
      providerFactory: (selected) {
        factoryProfiles.add(selected);
        return provider;
      },
    );

    await Future<void>.delayed(Duration.zero);
    expect(
      factoryProfiles,
      isEmpty,
      reason: 'the runtime must wait for settings initialization',
    );

    pendingPreferences.complete(PrefsKeyValueStore(preferences));

    final result = await pendingResult;
    expect(factoryProfiles, hasLength(1));
    expect(factoryProfiles.single.id, _audioFieldExtractionProfile().id);
    expect(provider.extractionCalls, 1);
    expect(result.candidates.single.fields['callsign'], 'BG5DBL');
  });
}

Future<AiRecognitionSettingsProvider> _settingsWithAudioFieldProfile() async {
  final settings = AiRecognitionSettingsProvider(
    credentialStore: AiCredentialStore(secureValues: _MemorySecureValues()),
  );
  await settings.initialized;
  await settings.upsertProfile(_audioFieldExtractionProfile());
  await settings.setActiveAudioFieldExtractionProfile(
    _audioFieldExtractionProfile().id,
  );
  return settings;
}

AudioSegment _segment() => AudioSegment(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'audio/wav',
      fileName: 's.wav',
    );

AiProviderProfile _audioFieldExtractionProfile() => AiProviderProfile(
      id: 'audio-extractor',
      name: 'Audio fields',
      kind: AiProviderKind.audioFieldExtraction,
      protocol: AiProtocol.openAiChatCompletionsAudio,
      baseUrl: Uri.parse('https://speech.example/v1'),
      model: 'omni-model',
      capabilities: const AiProviderCapabilities(
        supportsAudioFieldExtraction: true,
      ),
    );

final class _FakeAudioFieldExtractionProvider
    implements AudioFieldExtractionProvider {
  _FakeAudioFieldExtractionProvider({
    required this.profile,
    required this.result,
  });

  @override
  final AiProviderProfile profile;

  final AiRecognitionResult result;
  int extractionCalls = 0;
  int closeCalls = 0;
  AudioSegment? lastAudio;
  String? lastInstructions;

  @override
  AiProviderCapabilities get capabilities => profile.capabilities;

  @override
  Future<AiRecognitionResult> extractFieldsFromAudio(
    AudioSegment audio, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  }) async {
    extractionCalls++;
    lastAudio = audio;
    lastInstructions = instructions;
    return result;
  }

  @override
  void close() => closeCalls++;
}

final class _MemorySecureValues implements SecureValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
