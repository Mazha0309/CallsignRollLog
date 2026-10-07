import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition_runtime.dart';

void main() {
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

  test('recognizeRecord returns transcript and fields from one provider call',
      () async {
    var calls = 0;
    final segment = AudioSegment(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'audio/wav',
      fileName: 's.wav',
    );
    final result = await AiRecognitionRuntime.recognizeRecordWith(
      segment,
      (audio, instructions) async {
        calls++;
        expect(instructions, 'extract one record');
        return AiRecognitionResult(
          transcription: Transcription(text: 'BG5DBL 宁波高新区'),
          candidates: [
            RecognitionCandidate(
              fields: const {'callsign': 'BG5DBL'},
              sourceText: 'BG5DBL 宁波高新区',
            ),
          ],
        );
      },
      instructions: 'extract one record',
    );

    expect(calls, 1);
    expect(result.transcription.text, 'BG5DBL 宁波高新区');
    expect(result.candidates.single.fields['callsign'], 'BG5DBL');
  });
}
