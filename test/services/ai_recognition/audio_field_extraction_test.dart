import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';

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

  test('AiRecognitionResult is reachable from models.dart', () {
    // 搬迁的目的：providers.dart 能引用它而不形成循环依赖。
    final AiRecognitionResult result = AiRecognitionResult(
      transcription: Transcription(text: 'x'),
      candidates: const [],
    );
    expect(result.candidates, isEmpty);
  });
}
