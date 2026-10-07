import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/services/ai_credential_store.dart';
import 'package:openlogtool/services/ai_recognition/models.dart';
import 'package:openlogtool/services/ai_recognition/providers.dart';
import 'package:openlogtool/services/secure_token_store.dart';
import 'package:openlogtool/services/text_assistant.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AI is disabled by default and requires an ASR profile', () async {
    final provider = _provider();
    await provider.initialized;

    expect(provider.enabled, false);
    expect(provider.useLocalReferenceContext, isTrue);
    await expectLater(
      provider.setEnabled(true),
      throwsA(isA<StateError>()),
    );

    await provider.upsertProfile(_asrProfile());
    await provider.setActiveAsrProfile('asr');
    await provider.setEnabled(true);
    expect(provider.enabled, true);
  });

  test('persists the local reference context preference', () async {
    final provider = _provider();
    await provider.initialized;

    await provider.setUseLocalReferenceContext(false);

    final restarted = _provider();
    await restarted.initialized;
    expect(restarted.useLocalReferenceContext, isFalse);
  });

  test('persists profiles and active stages without storing an API key',
      () async {
    final values = _MemorySecureValues();
    final first = _provider(values);
    await first.initialized;
    await first.upsertProfile(_asrProfile());
    await first.upsertProfile(_extractorProfile());
    await first.setActiveAsrProfile('asr');
    await first.setActiveFieldExtractionProfile('extractor');
    await first.saveCredential('asr', 'top-secret');
    await first.setEnabled(true);

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString('openlogtool.ai.settings.v1')!;
    expect(stored, isNot(contains('top-secret')));

    final restarted = _provider(values);
    await restarted.initialized;
    expect(restarted.enabled, true);
    expect(restarted.activeAsrProfile?.model, 'speech-model');
    expect(restarted.activeFieldExtractionProfile?.model, 'text-model');
    expect(await restarted.hasCredential('asr'), true);
  });

  test('portable profile export never contains credential values', () async {
    final values = _MemorySecureValues();
    final provider = _provider(values);
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());
    await provider.saveCredential('asr', 'not-exported');

    final exported = provider.exportProfiles();

    expect(exported, isNot(contains('asr-secret')));
    expect(exported, isNot(contains('not-exported')));
    expect(jsonDecode(exported)['profiles'], hasLength(1));
  });

  test('import rejects credentials hidden in headers or request options',
      () async {
    final provider = _provider();
    await provider.initialized;
    final profile = _asrProfile().toJson();
    profile['headers'] = {'Authorization': 'Bearer leaked'};

    await expectLater(
      provider.importProfiles(jsonEncode({
        'schemaVersion': 1,
        'profiles': [profile],
      })),
      throwsArgumentError,
    );
  });

  test('removing the selected ASR profile disables recognition', () async {
    final provider = _provider();
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());
    await provider.setActiveAsrProfile('asr');
    await provider.setEnabled(true);

    await provider.removeProfile('asr');

    expect(provider.enabled, false);
    expect(provider.activeAsrProfile, isNull);
  });

  test('portable import discards credential references and stays disabled',
      () async {
    final provider = _provider();
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());
    await provider.setActiveAsrProfile('asr');
    await provider.setEnabled(true);
    final imported = _asrProfile().toJson()..['credentialId'] = 'asr-secret';

    await provider.importProfiles(jsonEncode({
      'schemaVersion': 1,
      'profiles': [imported],
    }));

    expect(provider.enabled, false);
    expect(provider.activeAsrProfile, isNull);
    expect(provider.profiles.single.credentialId, isNull);
  });

  test('changing a credential destination requires an explicit rebind',
      () async {
    final provider = _provider();
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());

    await expectLater(
      provider.upsertProfile(
        AiProviderProfile(
          id: 'asr',
          name: 'Speech',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.openAiAudioTranscriptions,
          baseUrl: Uri.parse('https://other.example/v1'),
          model: 'speech-model',
          credentialId: 'asr-secret',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('a shared credential cannot silently authorize another origin',
      () async {
    final provider = _provider();
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());

    await expectLater(
      provider.upsertProfile(
        AiProviderProfile(
          id: 'other-asr',
          name: 'Other speech',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.openAiChatCompletionsAudio,
          baseUrl: Uri.parse('https://other.example/v1'),
          model: 'other-model',
          credentialId: 'asr-secret',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('ASR and extraction may share a credential at the same origin',
      () async {
    final provider = _provider();
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());

    await provider.upsertProfile(
      AiProviderProfile(
        id: 'same-api-extractor',
        name: 'Fields',
        kind: AiProviderKind.fieldExtraction,
        protocol: AiProtocol.openAiChatCompletions,
        baseUrl: Uri.parse('https://speech.example/v1'),
        model: 'text-model',
        credentialId: 'asr-secret',
      ),
    );

    expect(provider.profiles, hasLength(2));
  });

  test('portable import removes credentials orphaned by profile replacement',
      () async {
    final values = _MemorySecureValues();
    final provider = _provider(values);
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());
    await provider.saveCredential('asr', 'old-key');
    expect(values.values, isNotEmpty);

    await provider.importProfiles(jsonEncode({
      'schemaVersion': 1,
      'profiles': <Object?>[],
    }));

    expect(values.values, isEmpty);
  });

  test('reset is ordered after pending mutations and cannot be overwritten',
      () async {
    final values = _MemorySecureValues();
    final provider = _provider(values);
    await provider.initialized;

    final pendingUpsert = provider.upsertProfile(_asrProfile());
    final pendingReset = provider.reset();
    await Future.wait([pendingUpsert, pendingReset]);

    final restarted = _provider(values);
    await restarted.initialized;
    expect(restarted.profiles, isEmpty);
    expect(restarted.enabled, isFalse);
    expect(values.values, isEmpty);
  });

  test('reset is safe before any AI settings have been saved', () async {
    final provider = _provider();
    await provider.initialized;

    await provider.reset();

    expect(provider.profiles, isEmpty);
    expect(provider.enabled, isFalse);
  });

  test('credential resolver reads the secure value by opaque id', () async {
    final values = _MemorySecureValues();
    final provider = _provider(values);
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());
    await provider.saveCredential('asr', 'resolved-key');

    final credentials = await provider.resolveCredentials(
      const AiCredentialRequest(
        providerId: 'asr',
        credentialId: 'asr-secret',
      ),
    );

    expect(credentials?.apiKey, 'resolved-key');
  });

  test('text assistant persists separately and keeps an explicit inline choice',
      () async {
    final values = _MemorySecureValues();
    final provider = _provider(values);
    await provider.initialized;
    await provider.saveTextAssistant(
      provider: TextAssistantProvider.openAiCompatible,
      baseUrl: Uri.parse('https://text.example/v1'),
      model: 'fast-model',
      secret: 'text-secret',
    );
    await provider.setInlineTextSuggestionsEnabled(false);
    await provider.saveTextAssistant(
      provider: TextAssistantProvider.openAiCompatible,
      baseUrl: Uri.parse('https://text.example/v1'),
      model: 'faster-model',
    );

    final restarted = _provider(values);
    await restarted.initialized;
    expect(restarted.textAssistantEnabled, true);
    expect(restarted.inlineTextSuggestionsEnabled, false);
    expect(restarted.textAssistantConfig?.model, 'faster-model');
    expect(await restarted.hasTextAssistantCredential(), true);
  });

  test('portable ASR profile import does not erase text assistant settings',
      () async {
    final values = _MemorySecureValues();
    final provider = _provider(values);
    await provider.initialized;
    await provider.saveTextAssistant(
      provider: TextAssistantProvider.anthropic,
      baseUrl: Uri.parse('https://api.anthropic.com'),
      model: 'claude-test',
      secret: 'text-secret',
    );

    await provider.importProfiles(jsonEncode({
      'schemaVersion': 1,
      'profiles': <Object?>[],
    }));

    expect(provider.textAssistantEnabled, true);
    expect(provider.textAssistantConfig?.provider,
        TextAssistantProvider.anthropic);
    expect(await provider.hasTextAssistantCredential(), true);
  });

  test('legacy selected chat extractor migrates without losing its credential',
      () async {
    final values = _MemorySecureValues();
    final first = _provider(values);
    await first.initialized;
    await first.upsertProfile(_extractorProfile());
    await first.setActiveFieldExtractionProfile('extractor');
    await first.saveCredential('extractor', 'legacy-secret');

    final restarted = _provider(values);
    await restarted.initialized;
    expect(restarted.textAssistantEnabled, true);
    expect(restarted.textAssistantConfig?.provider,
        TextAssistantProvider.openAiCompatible);
    expect(restarted.textAssistantConfig?.model, 'text-model');
    expect(await restarted.hasTextAssistantCredential(), true);

    await restarted.removeProfile('extractor');
    expect(await restarted.hasTextAssistantCredential(), true);
  });

  test('the multimodal kind has its own active slot', () async {
    final values = _MemorySecureValues();
    final provider = _provider(values);
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());
    await provider.upsertProfile(_audioExtractionProfile());

    expect(
      provider.audioFieldExtractionProfiles.map((profile) => profile.id),
      ['multimodal'],
    );

    await provider.setActiveAudioFieldExtractionProfile('multimodal');
    expect(provider.activeAudioFieldExtractionProfileId, 'multimodal');
    expect(provider.activeAudioFieldExtractionProfile?.id, 'multimodal');

    final restarted = _provider(values);
    await restarted.initialized;
    expect(restarted.activeAudioFieldExtractionProfileId, 'multimodal');
    expect(restarted.activeAudioFieldExtractionProfile?.id, 'multimodal');

    await restarted.setActiveAudioFieldExtractionProfile(null);
    expect(restarted.activeAudioFieldExtractionProfile, isNull);
  });

  test('the multimodal active slot rejects another kind', () async {
    final provider = _provider();
    await provider.initialized;
    await provider.upsertProfile(_asrProfile());

    await expectLater(
      provider.setActiveAudioFieldExtractionProfile('asr'),
      throwsStateError,
    );
  });
}

AiRecognitionSettingsProvider _provider([_MemorySecureValues? values]) =>
    AiRecognitionSettingsProvider(
      credentialStore: AiCredentialStore(
        secureValues: values ?? _MemorySecureValues(),
      ),
    );

AiProviderProfile _asrProfile() => AiProviderProfile(
      id: 'asr',
      name: 'Speech',
      kind: AiProviderKind.speechRecognition,
      protocol: AiProtocol.openAiAudioTranscriptions,
      baseUrl: Uri.parse('https://speech.example/v1'),
      model: 'speech-model',
      credentialId: 'asr-secret',
      capabilities: const AiProviderCapabilities(
        supportsAudioTranscription: true,
      ),
    );

AiProviderProfile _extractorProfile() => AiProviderProfile(
      id: 'extractor',
      name: 'Fields',
      kind: AiProviderKind.fieldExtraction,
      protocol: AiProtocol.openAiChatCompletions,
      baseUrl: Uri.parse('https://text.example/v1'),
      model: 'text-model',
      credentialId: 'extractor-secret',
      capabilities: const AiProviderCapabilities(
        supportsFieldExtraction: true,
      ),
    );

AiProviderProfile _audioExtractionProfile() => AiProviderProfile(
      id: 'multimodal',
      name: 'Multimodal',
      kind: AiProviderKind.audioFieldExtraction,
      protocol: AiProtocol.openAiChatCompletionsAudio,
      baseUrl: Uri.parse('https://audio.example/v1'),
      model: 'audio-model',
      credentialId: 'multimodal-secret',
      capabilities: const AiProviderCapabilities(
        supportsAudioFieldExtraction: true,
      ),
    );

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
