import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';

void main() {
  group('AiProviderProfile', () {
    test('round-trips portable model configuration without credentials', () {
      final profile = AiProviderProfile(
        id: 'station-asr',
        name: 'Station ASR',
        kind: AiProviderKind.speechRecognition,
        protocol: AiProtocol.openAiAudioTranscriptions,
        baseUrl: Uri.parse('https://speech.example.test/v1'),
        model: 'operator-selected-model',
        headers: const {'X-Tenant': 'club-1'},
        requestOptions: const {
          'responsePath': 'result.text',
          'fields': {'temperature': 0},
        },
        capabilities: const AiProviderCapabilities(
          supportsAudioTranscription: true,
          supportsLanguageHint: true,
          supportedAudioMimeTypes: {'audio/wav', 'audio/mpeg'},
          maxAudioBytes: 1024,
        ),
        credentialId: 'secure-ref-1',
        credentialTransport: AiCredentialTransport.header(
          name: 'X-Provider-Key',
        ),
      );
      final credentials = AiCredentials(apiKey: 'never-export-this-key');

      final encoded = jsonEncode(profile.toJson());
      final restored = AiProviderProfile.fromJson(jsonDecode(encoded));

      expect(encoded, isNot(contains(credentials.apiKey)));
      expect(restored.id, profile.id);
      expect(restored.model, 'operator-selected-model');
      expect(restored.protocol, AiProtocol.openAiAudioTranscriptions);
      expect(restored.headers, {'X-Tenant': 'club-1'});
      expect(restored.requestOptions['responsePath'], 'result.text');
      expect(restored.capabilities.maxAudioBytes, 1024);
      expect(restored.credentialId, 'secure-ref-1');
      expect(
        restored.credentialTransport.location,
        AiCredentialLocation.header,
      );
      expect(restored.credentialTransport.name, 'X-Provider-Key');
    });

    test('rejects credentials embedded in exported configuration', () {
      expect(
        () => AiProviderProfile(
          id: 'unsafe-url',
          name: 'Unsafe URL',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.jsonHttp,
          baseUrl: Uri.parse('https://example.test/asr?api_key=secret'),
          model: 'configurable-model',
        ),
        throwsArgumentError,
      );
      expect(
        () => AiProviderProfile(
          id: 'unsafe-auth-alias',
          name: 'Unsafe auth alias',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.jsonHttp,
          baseUrl: Uri.parse('https://example.test'),
          model: 'configurable-model',
          headers: const {'X-Auth-Token': 'secret'},
        ),
        throwsArgumentError,
      );
      expect(
        () => AiProviderProfile(
          id: 'unsafe',
          name: 'Unsafe',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.jsonHttp,
          baseUrl: Uri.parse('https://example.test'),
          model: 'configurable-model',
          headers: const {'Authorization': 'Bearer secret'},
        ),
        throwsArgumentError,
      );
      expect(
        () => AiProviderProfile(
          id: 'unsafe-google',
          name: 'Unsafe Google header',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.jsonHttp,
          baseUrl: Uri.parse('https://example.test'),
          model: 'configurable-model',
          headers: const {'X-Goog-Api-Key': 'secret'},
        ),
        throwsArgumentError,
      );
      expect(
        () => AiProviderProfile(
          id: 'unsafe',
          name: 'Unsafe',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.jsonHttp,
          baseUrl: Uri.parse('https://example.test'),
          model: 'configurable-model',
          requestOptions: const {
            'requestTemplate': {'api_key': 'secret'},
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects a protocol that cannot implement the provider kind', () {
      expect(
        () => AiProviderProfile(
          id: 'wrong-kind',
          name: 'Wrong kind',
          kind: AiProviderKind.fieldExtraction,
          protocol: AiProtocol.openAiAudioTranscriptions,
          baseUrl: Uri.parse('https://example.test'),
          model: 'configurable-model',
        ),
        throwsArgumentError,
      );
    });

    test('keeps nested request configuration immutable after validation', () {
      final source = <String, Object?>{
        'requestTemplate': <String, Object?>{
          'model': '{{model}}',
          'messages': <Object?>[],
        },
      };
      final profile = AiProviderProfile(
        id: 'immutable',
        name: 'Immutable',
        kind: AiProviderKind.speechRecognition,
        protocol: AiProtocol.jsonHttp,
        baseUrl: Uri.parse('https://example.test'),
        model: 'configurable-model',
        requestOptions: source,
      );

      (source['requestTemplate']! as Map<String, Object?>)['api_key'] =
          'outside-secret';
      final template =
          profile.requestOptions['requestTemplate']! as Map<String, Object?>;
      expect(template, isNot(contains('api_key')));
      expect(
        () => template['api_key'] = 'late-secret',
        throwsUnsupportedError,
      );
      expect(
        () => (template['messages']! as List<Object?>).add('late-message'),
        throwsUnsupportedError,
      );
    });
  });

  group('JSON configuration helpers', () {
    test('renders typed placeholders and reads array response paths', () {
      final rendered = renderAiJsonTemplate(
        const {
          'model': '{{model}}',
          'audio': '{{audio.base64}}',
          'description': 'file={{audio.fileName}}',
          'language': '{{language}}',
        },
        const {
          'model': 'configured-model',
          'audio': {'base64': 'AQID', 'fileName': 'sample.wav'},
          'language': null,
        },
      );

      expect(rendered, {
        'model': 'configured-model',
        'audio': 'AQID',
        'description': 'file=sample.wav',
        'language': null,
      });
      expect(
        readAiJsonPath(
          const {
            'choices': [
              {
                'message': {'content': 'heard text'},
              },
            ],
          },
          r'$.choices[0].message.content',
        ),
        'heard text',
      );
    });
  });

  group('audioFieldExtraction kind', () {
    test('accepts the chat audio protocol', () {
      expect(
        AiProtocol.openAiChatCompletionsAudio
            .supports(AiProviderKind.audioFieldExtraction),
        isTrue,
      );
    });

    test('accepts jsonHttp for providers with a request template', () {
      expect(
        AiProtocol.jsonHttp.supports(AiProviderKind.audioFieldExtraction),
        isTrue,
      );
    });

    test('rejects protocols that cannot carry audio', () {
      expect(
        AiProtocol.openAiChatCompletions
            .supports(AiProviderKind.audioFieldExtraction),
        isFalse,
      );
      expect(
        AiProtocol.openAiAudioTranscriptions
            .supports(AiProviderKind.audioFieldExtraction),
        isFalse,
      );
    });

    test('profile rejects a protocol that cannot carry audio', () {
      expect(
        () => AiProviderProfile(
          id: 'p1',
          name: 'bad',
          kind: AiProviderKind.audioFieldExtraction,
          protocol: AiProtocol.openAiChatCompletions,
          baseUrl: Uri.parse('https://example.com/v1'),
          model: 'm',
        ),
        throwsArgumentError,
      );
    });

    test('kind survives a JSON round trip', () {
      final json = AiProviderProfile(
        id: 'p1',
        name: 'qwen',
        kind: AiProviderKind.audioFieldExtraction,
        protocol: AiProtocol.openAiChatCompletionsAudio,
        baseUrl: Uri.parse('https://example.com/compatible-mode/v1'),
        model: 'qwen3.8-omni-flash',
      ).toJson();
      expect(
        AiProviderProfile.fromJson(json).kind,
        AiProviderKind.audioFieldExtraction,
      );
    });
  });

  group('capabilities', () {
    test('defaults to not supporting audio field extraction', () {
      expect(
        const AiProviderCapabilities().supportsAudioFieldExtraction,
        isFalse,
      );
    });

    test('round trips through JSON', () {
      const capabilities = AiProviderCapabilities(
        supportsAudioFieldExtraction: true,
      );
      expect(
        AiProviderCapabilities.fromJson(capabilities.toJson())
            .supportsAudioFieldExtraction,
        isTrue,
      );
    });
  });

  group('audioFieldExtraction jsonHttp profile', () {
    test('profile accepts jsonHttp for audio field extraction', () {
      expect(
        () => AiProviderProfile(
          id: 'p2',
          name: 'template',
          kind: AiProviderKind.audioFieldExtraction,
          protocol: AiProtocol.jsonHttp,
          baseUrl: Uri.parse('https://example.com/v1'),
          model: 'm',
          requestOptions: const {
            'requestTemplate': {'audio': '{{audio.dataUrl}}'},
          },
        ),
        returnsNormally,
      );
    });
  });
}
