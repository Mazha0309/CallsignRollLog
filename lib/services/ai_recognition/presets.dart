import 'models.dart';

/// 一个服务商预设：把「协议 + 端点 + 鉴权 + 请求选项 + 默认模型」一次填好，
/// 用户只需粘 API Key。普通用户不可能自己猜出这些组合。
final class AiProviderPreset {
  AiProviderPreset({
    required this.id,
    required this.labelKey,
    required this.hintKey,
    required this.kind,
    required this.protocol,
    required this.baseUrl,
    required this.defaultModel,
    AiJsonObject requestOptions = const {},
    this.credentialTransport = const AiCredentialTransport.bearer(),
  }) : requestOptions = Map.unmodifiable(requestOptions);

  final String id;

  /// l10n 键名（四份 ARB 都要有）。
  final String labelKey;
  final String hintKey;

  final AiProviderKind kind;
  final AiProtocol protocol;

  /// 存字符串而非 Uri：`Uri.parse` 不是 const 构造函数；存字符串让预设保持
  /// 纯数据，不把解析后的对象嵌进清单。
  final String baseUrl;

  /// 未实测的预设用空串作为「让用户自己填」的哨兵；真实模型名不会为空，
  /// 因此空串不会与任何真实模型名冲突。
  final String defaultModel;

  /// 构造时已用 [Map.unmodifiable] 包裹，非 const 实例也不会把可变映射暴露出去。
  final AiJsonObject requestOptions;
  final AiCredentialTransport credentialTransport;

  AiProviderProfile buildProfile({
    required String id,
    required String name,
    required String model,
  }) =>
      AiProviderProfile(
        id: id,
        name: name,
        kind: kind,
        protocol: protocol,
        baseUrl: Uri.parse(baseUrl),
        model: model,
        requestOptions: requestOptions,
        credentialTransport: credentialTransport,
        capabilities: AiProviderCapabilities(
          supportsAudioTranscription: kind == AiProviderKind.speechRecognition,
          supportsFieldExtraction: kind == AiProviderKind.fieldExtraction,
          supportsAudioFieldExtraction:
              kind == AiProviderKind.audioFieldExtraction,
          supportsPrompt: true,
        ),
      );
}

/// 预设清单。Base URL / 模型 ID / 请求选项都必须实测过再写进来——
/// 服务商改接口的代价会直接落到用户身上（见 Task 1 的结论文档）。
final aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    id: 'bailian-audio',
    labelKey: 'aiPresetBailianAudio',
    hintKey: 'aiPresetBailianAudioHint',
    kind: AiProviderKind.audioFieldExtraction,
    protocol: AiProtocol.openAiChatCompletionsAudio,
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen3.8-omni-flash',
    // Task 1 的实测结论：两者缺一不可。
    //   audioDataEncoding —— 决定请求能否被接受（裸 base64 会被当成 URL 拒绝）
    //   enable_thinking    —— 决定它是否可用（开启思考时单条 174 秒；关闭后 3 秒）
    // 后者是服务商专属参数，正是预设该承载的东西。
    requestOptions: {
      'audioDataEncoding': 'dataUrl',
      'body': {'enable_thinking': false},
    },
  ),
  AiProviderPreset(
    id: 'siliconflow-audio',
    labelKey: 'aiPresetSiliconFlowAudio',
    hintKey: 'aiPresetSiliconFlowAudioHint',
    kind: AiProviderKind.audioFieldExtraction,
    protocol: AiProtocol.openAiChatCompletionsAudio,
    baseUrl: 'https://api.siliconflow.cn/v1',
    // 未实测：连是否需要 dataUrl 都未验证（无凭据）。不要照抄百炼的值，
    // 因此不设 requestOptions，一切走 provider 默认值。
    defaultModel: '',
  ),
  AiProviderPreset(
    id: 'custom',
    labelKey: 'aiPresetCustom',
    hintKey: 'aiPresetCustomHint',
    kind: AiProviderKind.audioFieldExtraction,
    protocol: AiProtocol.openAiChatCompletionsAudio,
    baseUrl: 'https://example.com/v1',
    defaultModel: '',
  ),
];
