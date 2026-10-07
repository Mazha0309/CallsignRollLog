import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition/presets.dart';

void main() {
  test('every preset builds a usable profile for its kind', () {
    for (final preset in aiProviderPresets) {
      // 有两个预设的 defaultModel 故意留空（让用户在界面里填），而
      // AiProviderProfile 要求 model 非空。这里只补一个测试用占位模型，
      // 预设本身仍不编造任何模型名。
      final model =
          preset.defaultModel.isEmpty ? 'test-model' : preset.defaultModel;
      final profile = preset.buildProfile(
        id: 'p',
        name: 'n',
        model: model,
      );
      expect(profile.kind, preset.kind);
      expect(profile.baseUrl.hasScheme, isTrue);
      // 构造成功本身即证明 kind 与 protocol 配对合法。
      // capabilities 是按 kind 推导的，改坏了必须能被发现。
      expect(
        profile.capabilities.supportsAudioFieldExtraction,
        preset.kind == AiProviderKind.audioFieldExtraction,
      );
      expect(
        profile.capabilities.supportsAudioTranscription,
        preset.kind == AiProviderKind.speechRecognition,
      );
      expect(
        profile.capabilities.supportsFieldExtraction,
        preset.kind == AiProviderKind.fieldExtraction,
      );
      expect(profile.capabilities.supportsPrompt, isTrue);
    }
  });

  test('presets never carry credentials', () {
    for (final preset in aiProviderPresets) {
      final json = preset.buildProfile(id: 'p', name: 'n', model: 'm').toJson();
      expect(json.containsKey('credentialId'), isFalse);
      expect(json['headers'], isEmpty);
    }
  });

  test('the multimodal presets ask for the encoding and turn thinking off', () {
    final bailian =
        aiProviderPresets.firstWhere((preset) => preset.id == 'bailian-audio');
    final profile = bailian.buildProfile(id: 'p', name: 'n', model: 'm');
    // 前者决定请求能否被接受，后者决定它是否可用（见 Task 1 的结论文档）。
    expect(profile.requestOptions['audioDataEncoding'], 'dataUrl');
    expect(
      (profile.requestOptions['body'] as Map)['enable_thinking'],
      isFalse,
    );
  });

  test('presets we have not measured keep an empty default model', () {
    // 未实测就不要编造模型名；实测后再更新这条断言。
    for (final id in ['siliconflow-audio', 'custom']) {
      final preset = aiProviderPresets.firstWhere((p) => p.id == id);
      expect(preset.defaultModel, isEmpty, reason: '$id 尚未实测');
    }
  });

  test('every preset has a non-empty label and hint key', () {
    for (final preset in aiProviderPresets) {
      expect(preset.labelKey, isNotEmpty);
      expect(preset.hintKey, isNotEmpty);
    }
  });
}
