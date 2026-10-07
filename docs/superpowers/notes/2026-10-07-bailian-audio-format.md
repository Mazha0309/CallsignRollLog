# 百炼（DashScope 兼容模式）音频输入形态与延迟实测

日期：2026-10-07
目的：确定模式 A（音频一次调用产出字段）在阿里云百炼上该怎么配。
端点：`https://ws-qk7oakinq4svzukw.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`（工作区专属），模型 `qwen3.8-omni-flash`。
凭据从环境变量读取，**未落盘、未写进任何文件**。以下记录不含密钥。

## 1. 音频字段的形态

夹具：4.0 秒、22050 Hz、单声道 16 bit WAV（`espeak-ng` 合成）。

| 形态 | 结果 |
| --- | --- |
| A 裸 base64 + `format` | **400** `invalid_parameter_error`：`The provided URL does not appear to be valid. Ensure it is correctly formatted.` |
| B `data:audio/wav;base64,…` + `format` | **200** |
| C 同 B，去掉 `format` | **200**（`format` 可省） |
| D 嵌套 `input_audio.data = {"url": …}` | **400**：`'messages.[0].content[1].input_audio.data'. must be string.` |

**结论**：`audioDataEncoding` 必须为 `dataUrl`；`input_audio.data` 必须是字符串。裸 base64 会被服务端当成 URL 去解析，因此被拒——这一点从 A 与 D 两条错误互相印证。

## 2. 输出契约

按 `AiRecognitionRuntime.audioFieldExtractionInstructions` 的措辞发 system 指令后，`choices[0].message.content` 是一个**可直接 `jsonDecode` 的 JSON 对象**，三个键齐全，`fields` 只含指令允许的键，没把握的内容进 `uncertain`。与 Plan 1 实现的 `_parseAudioFieldExtraction` 契约一致。

样例（真实返回，未修改）：

```json
{"transcript":"59，宁波高新区，卢瓦。","fields":{"rstRcvd":"59","qth":"宁波高新区"},"uncertain":[]}
```

## 3. 延迟与成本：必须关闭思考（本次最重要的结论）

同一段 4.0 秒音频：

| 配置 | 耗时 | completion tokens | reasoning tokens |
| --- | --- | --- | --- |
| 默认（思考开启） | **174.3 s** | 13 636 | 13 540 |
| `enable_thinking: false` | **3.0 s** | 42 | 0 |
| 同上 + `max_tokens: 300` | 2.6 s | 51 | 0 |

- 思考开启时，模型为几秒音频生成**上万 token** 的推理内容，单条 174 秒——现场不可用。
- 关闭后稳定在 40–50 个 completion token，**快 58 倍、输出 token 少 320 倍**。
- `enable_thinking` 是 DashScope 的**顶层请求体参数**，经 provider 的 `requestOptions['body']` 透传即可（`_recordChatAudio` 会把 `body` 合并进请求）。
- 这是**服务商专属参数**，不该写死在代码里——正是「预设」该承载的东西。

## 4. 音频 token 折算（修正设计文档的估值）

实测 `prompt_tokens_details.audio_tokens = 30`，对应 4.0 秒音频 → **约 7.5 token/秒**，而非设计文档 §6.1 引用的 12.5（该数字来自另一个模型的文档）。

按实测值：1 小时音频 ≈ 27 000 audio token；以 0.8 元/百万 token 计约 **0.022 元/小时**。音频输入依然便宜到可忽略——**真正的成本与延迟都来自输出**，这才是必须关思考的原因。

## 5. 未能验证的部分（不要当成已验证）

- **准确率未测**。夹具是 `espeak-ng` 的机器人中文，模型听到的是 `Five kilo` / `Wuwa` / `Bravo 5 Golf Lima Papa` 这类，与真实点名录音差距很大，有一次把 `BG5DBL` 听成了 `BG5GLP`。**呼号准确率必须用真实录音才能判断**（横评工具已就绪：`test/services/ai_recognition/multimodal_model_comparison.dart`）。
- **硅基流动未验证**（无凭据）。预设里它的默认模型故意留空，不编造。
- 未测其他音频格式（mp3 / m4a）与单次音频时长上限。
- 未测 `max_tokens` 压到更低时是否截断 JSON。

## 6. 对 Plan 2 的直接结论

预设「阿里云百炼」的 `requestOptions` 应包含：

```dart
{
  'audioDataEncoding': 'dataUrl',
  'body': {'enable_thinking': false},
}
```

两者缺一不可：前者决定请求能否被接受，后者决定它是否可用。
