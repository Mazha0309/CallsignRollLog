import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition/models.dart' as models;

/// 实现新接口的假对象。接口不存在时本文件无法编译，这才是真正的红灯。
final class _FakeAudioFieldExtractionProvider
    implements AudioFieldExtractionProvider {
  _FakeAudioFieldExtractionProvider(this.profile);

  @override
  final AiProviderProfile profile;

  @override
  AiProviderCapabilities get capabilities => profile.capabilities;

  @override
  Future<AiRecognitionResult> extractFieldsFromAudio(
    AudioSegment audio, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  }) async =>
      AiRecognitionResult(
        transcription: Transcription(text: 'BG5DBL 宁波高新区'),
        candidates: [
          RecognitionCandidate(
            fields: const {'callsign': 'BG5DBL'},
            sourceText: 'BG5DBL 宁波高新区',
          ),
        ],
      );

  @override
  void close() {}
}

void main() {
  AiProviderProfile profile() => AiProviderProfile(
        id: 'p',
        name: 'qwen',
        kind: AiProviderKind.audioFieldExtraction,
        protocol: AiProtocol.openAiChatCompletionsAudio,
        baseUrl: Uri.parse('https://example.com/v1'),
        model: 'm',
      );

  AudioSegment segment() => AudioSegment(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        mimeType: 'audio/wav',
        fileName: 's.wav',
        sampleRateHz: 16000,
      );

  test('the audio field extraction contract returns transcript and fields',
      () async {
    final provider = _FakeAudioFieldExtractionProvider(profile());
    final result = await provider.extractFieldsFromAudio(
      segment(),
      instructions: 'extract one record',
    );
    expect(result.transcription.text, 'BG5DBL 宁波高新区');
    expect(result.candidates.single.fields['callsign'], 'BG5DBL');
  });

  test('AiRecognitionResult lives in models.dart', () {
    // 通过 models.dart 直接引用：若该类仍定义在 pipeline.dart，本文件将编译失败。
    final models.AiRecognitionResult result = models.AiRecognitionResult(
      transcription: models.Transcription(text: 'x'),
      candidates: const [],
    );
    expect(result.candidates, isEmpty);
  });

  group('shared audio message builder', () {
    test('emits a data URL when the profile asks for it', () {
      final profile = AiProviderProfile(
        id: 'p',
        name: 'qwen',
        kind: AiProviderKind.audioFieldExtraction,
        protocol: AiProtocol.openAiChatCompletionsAudio,
        baseUrl: Uri.parse('https://example.com/v1'),
        model: 'm',
        requestOptions: const {'audioDataEncoding': 'dataUrl'},
      );
      final content = buildChatAudioContent(
        profile,
        AudioSegment(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          mimeType: 'audio/wav',
          fileName: 's.wav',
        ),
        prompt: 'listen',
      );
      expect(content.first, {'type': 'text', 'text': 'listen'});
      final audio = content.last! as Map<String, Object?>;
      expect(audio['type'], 'input_audio');
      final payload = audio['input_audio']! as Map<String, Object?>;
      expect(payload['data'], 'data:audio/wav;base64,AQID');
      // includeAudioFormat 默认 true，fileName 的扩展名即音频率格式。
      expect(payload['format'], 'wav');
    });

    test('rejects an unknown audio encoding', () {
      final profile = AiProviderProfile(
        id: 'p',
        name: 'qwen',
        kind: AiProviderKind.audioFieldExtraction,
        protocol: AiProtocol.openAiChatCompletionsAudio,
        baseUrl: Uri.parse('https://example.com/v1'),
        model: 'm',
        requestOptions: const {'audioDataEncoding': 'bogus'},
      );
      expect(
        () => buildChatAudioContent(
          profile,
          AudioSegment(
            bytes: Uint8List.fromList(const [1, 2, 3]),
            mimeType: 'audio/wav',
            fileName: 's.wav',
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('ProtocolAudioFieldExtractionProvider', () {
    AiProviderProfile profileWith({Map<String, Object?> options = const {}}) =>
        AiProviderProfile(
          id: 'qwen',
          name: 'qwen-omni',
          kind: AiProviderKind.audioFieldExtraction,
          protocol: AiProtocol.openAiChatCompletionsAudio,
          baseUrl: Uri.parse('https://example.com/compatible-mode/v1'),
          model: 'qwen3.8-omni-flash',
          // 这些用例验证请求体与解析，不验证鉴权；默认 bearer 传输会在
          // 发请求前要求凭据，这里显式关闭以便聚焦被测行为。
          credentialTransport: const AiCredentialTransport.none(),
          requestOptions: options,
        );

    AudioSegment segment() => AudioSegment(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          mimeType: 'audio/wav',
          fileName: 's.wav',
          sampleRateHz: 16000,
        );

    test('parses transcript and fields from one response', () async {
      final provider = ProtocolAudioFieldExtractionProvider(
        profile: profileWith(),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['model'], 'qwen3.8-omni-flash');
          final messages = body['messages']! as List<Object?>;
          final userContent = (messages.last!
              as Map<String, Object?>)['content']! as List<Object?>;
          expect(
            (userContent.last! as Map<String, Object?>)['type'],
            'input_audio',
          );
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content':
                        '{"transcript":"BG5DBL 宁波高新区","fields":{"callsign":"BG5DBL","qth":"宁波高新区"},"uncertain":[]}',
                  },
                },
              ],
            }),
            200,
            headers: const {
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      final result = await provider.extractFieldsFromAudio(
        segment(),
        instructions: 'Extract one check-in record.',
      );

      expect(result.transcription.text, 'BG5DBL 宁波高新区');
      expect(result.candidates.single.fields, {
        'callsign': 'BG5DBL',
        'qth': '宁波高新区',
      });
      provider.close();
    });

    test('returns no candidates when the model reports an empty record',
        () async {
      final provider = ProtocolAudioFieldExtractionProvider(
        profile: profileWith(),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': '{"transcript":"嗯…","fields":{}}',
                  },
                },
              ],
            }),
            200,
            headers: const {
              'content-type': 'application/json; charset=utf-8',
            },
          ),
        ),
      );

      final result = await provider.extractFieldsFromAudio(segment());

      expect(result.transcription.text, '嗯…');
      expect(result.candidates, isEmpty);
      provider.close();
    });

    test('rejects a response that is not JSON', () async {
      final provider = ProtocolAudioFieldExtractionProvider(
        profile: profileWith(),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '抱歉，我没听清'}
                },
              ],
            }),
            200,
            headers: const {
              'content-type': 'application/json; charset=utf-8',
            },
          ),
        ),
      );

      await expectLater(
        provider.extractFieldsFromAudio(segment()),
        throwsA(
          isA<AiRecognitionException>().having(
            (e) => e.kind,
            'kind',
            AiRecognitionErrorKind.invalidResponse,
          ),
        ),
      );
      provider.close();
    });

    test('rejects a mismatched profile kind', () {
      expect(
        () => ProtocolAudioFieldExtractionProvider(
          profile: AiProviderProfile(
            id: 'p',
            name: 'asr',
            kind: AiProviderKind.speechRecognition,
            protocol: AiProtocol.openAiChatCompletionsAudio,
            baseUrl: Uri.parse('https://example.com/v1'),
            model: 'm',
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
