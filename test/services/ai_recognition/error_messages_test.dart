import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';

void main() {
  test('every error kind has a user message', () {
    for (final kind in AiRecognitionErrorKind.values) {
      expect(
        aiUserFacingErrorMessage(
          AiRecognitionException(kind: kind, message: 'internal detail'),
        ),
        isNotEmpty,
        reason: '$kind 缺少用户文案',
      );
    }
  });

  test('messages never leak internal identifiers or the raw message', () {
    // 内部错误码形如 AI_AUDIO_PCM16_UNSUPPORTED，异常文本形如
    // AiRecognitionException: kind: message。
    final banned = RegExp(r'[A-Z][A-Z0-9_]{4,}|Exception|internal detail');
    for (final kind in AiRecognitionErrorKind.values) {
      expect(
        aiUserFacingErrorMessage(
          AiRecognitionException(kind: kind, message: 'internal detail'),
        ),
        isNot(matches(banned)),
        reason: '$kind 的文案泄漏了内部标识',
      );
    }
  });

  test('http status maps to an actionable next step', () {
    String messageFor(int code) => aiUserFacingErrorMessage(
          AiRecognitionException(
            kind: AiRecognitionErrorKind.httpStatus,
            message: 'HTTP $code',
            statusCode: code,
          ),
        );

    expect(messageFor(401), contains('API Key'));
    expect(messageFor(404), contains('模型'));
    expect(messageFor(429), contains('稍等'));
  });
}
