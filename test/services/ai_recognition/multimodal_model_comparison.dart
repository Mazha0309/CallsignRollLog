import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition_runtime.dart';

/// 横评：同一批录音跑多个候选模型，比较 JSON 合法率、字段召回与耗时。
///
/// 夹具命名约定：`<期望呼号>__<说明>.wav`，例如
/// `BG5DBL__宁波高新区_森海克斯.wav`。文件名中 `__` 之前的前缀就是该条录音的
/// 期望呼号基准，实验据此计算呼号命中率，因此录音与文件名必须一一对应。
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
      .map((m) => m.trim())
      .where((m) => m.isNotEmpty)
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

    // 夹具命名 <期望呼号>__<说明>.wav。没有 `__` 的文件基准不可用：跳过它的
    // 呼号命中统计（期望呼号记为 null）并在输出里点名，避免被静默算成 miss。
    final expectedCallsigns = <File, String?>{};
    final skippedClips = <String>[];
    for (final clip in clips) {
      final name = clip.uri.pathSegments.last;
      if (name.contains('__')) {
        expectedCallsigns[clip] = name.split('__').first;
      } else {
        expectedCallsigns[clip] = null;
        skippedClips.add(name);
      }
    }

    // 表头只在第一轮前打印一次；结果边跑边打，避免整轮超时后一行都没有，
    // 花了额度却拿不到任何数据。
    // ignore: avoid_print
    print('模型横评结果：');
    if (skippedClips.isNotEmpty) {
      // ignore: avoid_print
      print('  跳过呼号统计（文件名缺少 __ 约定）: ${skippedClips.join(', ')}');
    }

    final report = <String, Map<String, Object?>>{};
    for (final model in models) {
      var jsonOk = 0;
      var calls = 0;
      var callsignsExact = 0;
      final failuresByKind = <AiRecognitionErrorKind, int>{};
      final durationsMs = <int>[];
      for (final clip in clips) {
        final profile = AiProviderProfile(
          id: 'eval-$model',
          name: model,
          kind: AiProviderKind.audioFieldExtraction,
          protocol: AiProtocol.openAiChatCompletionsAudio,
          baseUrl: Uri.parse(base),
          model: model,
          credentialTransport: const AiCredentialTransport.bearer(),
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
          final expected = expectedCallsigns[clip];
          if (expected != null && callsign == expected) callsignsExact++;
        } on AiRecognitionException catch (error) {
          failuresByKind.update(
            error.kind,
            (n) => n + 1,
            ifAbsent: () => 1,
          );
          // 环境/配置类错误说明凭据或地址根本没配对，继续跑只会浪费额度。
          if (const {
            AiRecognitionErrorKind.missingCredentials,
            AiRecognitionErrorKind.invalidConfiguration,
            AiRecognitionErrorKind.unsupportedProtocol,
          }.contains(error.kind)) {
            fail(
              '模型 $model 出现 ${error.kind.name}：凭据或配置未配对，'
              '请检查 CRL_AI_EVAL_KEY / CRL_AI_EVAL_BASE / CRL_AI_EVAL_MODELS。',
            );
          }
          // 其余（invalidResponse / httpStatus / timeout / network /
          // audioRejected）只记入失败分布，不中断整轮横评。
        } finally {
          stopwatch.stop();
          durationsMs.add(stopwatch.elapsedMilliseconds);
          provider.close();
        }
      }
      durationsMs.sort();
      final row = <String, Object?>{
        'JSON 合法率': calls == 0 ? 0 : (jsonOk / calls * 100).round(),
        '呼号命中': callsignsExact,
        '样本数': calls,
        '失败分布': {
          for (final entry in failuresByKind.entries)
            entry.key.name: entry.value,
        },
        'P50 毫秒':
            durationsMs.isEmpty ? 0 : durationsMs[durationsMs.length ~/ 2],
        'P95 毫秒': durationsMs.isEmpty
            ? 0
            : durationsMs[((durationsMs.length * 95) / 100).floor().clamp(
                  0,
                  durationsMs.length - 1,
                )],
      };
      report[model] = row;
      // 每个模型算完立即打印它那一行，防止整轮超时导致报告为空。
      // ignore: avoid_print
      print('  $model  $row');
    }

    // 至少有一个模型产出了可解析结果；全部为 0 通常意味着环境或模型选错了。
    expect(
      report.values.any((row) => (row['JSON 合法率']! as int) > 0),
      isTrue,
      reason: '所有模型的 JSON 合法率都是 0，先检查凭据、地址与模型名',
    );
    // 单次调用自带 60 秒超时兜底，这里不再设 test 级上限：设计 §10.1 的
    // 「至少 20 条 × 3 模型」在限流/超时下可能超过任何固定值，宁可慢也不要
    // 因为超时而丢掉已经花掉额度的结果。
  }, timeout: Timeout.none);
}
