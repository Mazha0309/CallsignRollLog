import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
}
