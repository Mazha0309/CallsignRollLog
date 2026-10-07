import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition_runtime.dart';

/// 横评：同一批录音跑多个候选模型，比较 JSON 合法率、字段召回与耗时。
///
/// 用法（凭据不落盘，只从环境变量读）：
///   CRL_AI_EVAL_KEY=sk-xxx \
///   CRL_AI_EVAL_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1 \
///   CRL_AI_EVAL_MODELS=qwen3.8-omni-flash,qwen3.5-omni-plus \
///   flutter test test/services/ai_recognition/multimodal_model_comparison.dart
void main() {
  final key = Platform.environment['CRL_AI_EVAL_KEY'];
  final base = Platform.environment['CRL_AI_EVAL_BASE'];
  final models = (Platform.environment['CRL_AI_EVAL_MODELS'] ?? '')
      .split(',')
      .where((m) => m.trim().isNotEmpty)
      .toList();
  final dir = Directory('test/fixtures/ai_eval');
  final clips = dir.existsSync()
      ? dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.wav'))
          .toList()
      : <File>[];

  test('compare candidate models on real net recordings', () async {
    if (key == null || base == null || models.isEmpty || clips.isEmpty) {
      markTestSkipped(
        '缺少 CRL_AI_EVAL_KEY / CRL_AI_EVAL_BASE / 模型列表或录音夹具，跳过横评',
      );
      return;
    }

    final report = <String, Map<String, Object?>>{};
    for (final model in models) {
      var jsonOk = 0;
      var calls = 0;
      var callsignsExact = 0;
      final durationsMs = <int>[];
      for (final clip in clips) {
        final profile = AiProviderProfile(
          id: 'eval-$model',
          name: model,
          kind: AiProviderKind.audioFieldExtraction,
          protocol: AiProtocol.openAiChatCompletionsAudio,
          baseUrl: Uri.parse(base),
          model: model,
          capabilities: const AiProviderCapabilities(
            supportsAudioFieldExtraction: true,
          ),
        );
        final provider = AiProviderFactory.createAudioFieldExtraction(profile);
        final stopwatch = Stopwatch()..start();
        calls++;
        try {
          final result = await provider.extractFieldsFromAudio(
            AudioSegment(
              bytes: clip.readAsBytesSync(),
              mimeType: 'audio/wav',
              fileName: clip.uri.pathSegments.last,
            ),
            instructions: AiRecognitionRuntime.audioFieldExtractionInstructions,
            options: AiRequestOptions(
              credentials: AiCredentials(apiKey: key),
            ),
          );
          jsonOk++;
          final callsign = result.candidates.isEmpty
              ? null
              : result.candidates.first.fields['callsign'];
          final expected = clip.uri.pathSegments.last.split('__').first;
          if (callsign == expected) callsignsExact++;
        } on AiRecognitionException {
          // 计入失败率，不中断整轮横评。
        } finally {
          stopwatch.stop();
          durationsMs.add(stopwatch.elapsedMilliseconds);
          provider.close();
        }
      }
      durationsMs.sort();
      report[model] = {
        'JSON 合法率': calls == 0 ? 0 : (jsonOk / calls * 100).round(),
        '呼号命中': callsignsExact,
        '样本数': calls,
        'P50 毫秒':
            durationsMs.isEmpty ? 0 : durationsMs[durationsMs.length ~/ 2],
        'P95 毫秒': durationsMs.isEmpty
            ? 0
            : durationsMs[((durationsMs.length * 95) / 100).floor().clamp(
                  0,
                  durationsMs.length - 1,
                )],
      };
    }

    // ignore: avoid_print
    print('模型横评结果：');
    report.forEach((model, row) {
      // ignore: avoid_print
      print('  $model  $row');
    });
    expect(report.keys, containsAll(models));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
