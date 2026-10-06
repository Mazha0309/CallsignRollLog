# AI 语音识别配置指南

本文只介绍 Callsign Roll Log 的语音识别（ASR）功能。文字助手有独立配置，两者职责不同：

- 语音模型负责把录音转换为原始转写文本。
- 文字助手负责把累计转写整理成呼号、设备、天线、功率、QTH、高度、RST 和备注等候选字段。
- 所有候选字段都需要用户确认；AI 不会直接保存记录，也不会自动填写时间或主控呼号。

语音识别不依赖 Callsign Roll Log Server。客户端会直接请求你配置的模型服务。

## 快速配置

1. 打开“设置 → AI 辅助识别”。
2. 在“语音识别（ASR）”区域新增配置。
3. 填写配置名称、API Base URL、模型名称、接口格式和鉴权方式。
4. 保存后把该配置选为当前语音配置，再开启“AI 辅助识别”。
5. 如需自动整理表单字段，继续配置并启用独立的“文字助手”。

配置字段说明：

| 字段 | 说明 |
| --- | --- |
| 配置名称 | 仅用于客户端内区分不同配置，可以自由填写。 |
| API Base URL | 服务地址。OpenAI 兼容地址通常以 `/v1` 结尾。 |
| 模型名称 | 服务商要求的实际 ASR 或音频模型 ID。 |
| 接口格式 | 必须按照服务商的 HTTP 请求格式选择，而不是按照模型名称选择。 |
| 鉴权方式 | 支持 Bearer、自定义请求头、查询参数和无需鉴权。 |
| API 密钥 | 只保存在设备的安全凭据存储中，不写入普通设置和配置导出。 |
| 高级请求选项 | JSON 对象，用于覆盖路径、请求字段或响应路径。不要在这里填写密钥。 |

## 如何选择接口格式

Callsign Roll Log 支持三种语音接口格式：

| 接口格式 | 适用情况 | 默认请求地址 | 默认转写响应路径 |
| --- | --- | --- | --- |
| 音频转写 multipart | 接口接收 `multipart/form-data`，包含音频文件和模型名 | `/v1/audio/transcriptions` | `text` |
| Chat `input_audio` | 接口使用 Chat Completions JSON，并在消息中接收 Base64 音频 | `/v1/chat/completions` | `choices[0].message.content` |
| 通用 JSON HTTP | 服务商使用自定义 JSON 请求结构 | Base URL 本身或配置的 `path` | `text`，可通过 `responsePath` 修改 |

Base URL 已以 `/v1` 结尾时，客户端不会重复追加 `/v1`。高级选项中的 `path` 可以覆盖默认路径，但不能改变 Base URL 的域名。

### 音频转写 multipart

这是最常见的 ASR 接口。客户端默认发送：

- `file`：录音文件。
- `model`：配置中的模型名称。
- `language`：存在语言提示时发送。
- `prompt`：Callsign Roll Log 的业余无线电识别提示。

标准兼容接口通常可以把高级请求选项保持为：

```json
{}
```

需要覆盖接口细节时可以使用：

```json
{
  "path": "/v1/audio/transcriptions",
  "fileField": "file",
  "modelField": "model",
  "languageField": "language",
  "promptField": "prompt",
  "fields": {
    "response_format": "json"
  },
  "responsePath": "text"
}
```

`fields` 只接受字符串、数字或布尔值。客户端仍会单独写入模型、语言和提示字段。

### Chat `input_audio`

适用于能够在 Chat Completions 消息中接收 `input_audio` 的音频模型。模型必须真正支持音频输入；普通文字模型不能因为接口兼容就用于这里。

常用高级请求选项：

```json
{
  "audioDataEncoding": "base64",
  "includeAudioFormat": true,
  "includePrompt": true,
  "responsePath": "choices[0].message.content"
}
```

可用选项包括：

- `path`：覆盖请求路径。
- `audioDataEncoding`：`base64` 或 `dataUrl`。
- `includeAudioFormat`：是否在 `input_audio` 中发送格式。
- `audioFormat`：覆盖自动识别的音频格式。
- `includePrompt`：是否把识别提示作为文字内容一并发送。
- `systemPrompt`：额外的 system 消息。
- `body`：合并到请求体的额外 JSON 字段。
- `languageField`：服务商支持顶层语言字段时指定字段名。
- `responsePath`、`languageResponsePath`、`confidenceResponsePath`：响应取值路径。

### 通用 JSON HTTP

当服务商既不使用 multipart，也不使用 Chat `input_audio` 时选择此格式。`requestTemplate` 是必填项。

示例：

```json
{
  "path": "/asr",
  "method": "POST",
  "requestTemplate": {
    "model": "{{model}}",
    "audio": "{{audio.dataUrl}}",
    "language": "{{language}}",
    "prompt": "{{prompt}}"
  },
  "responsePath": "data.text",
  "languageResponsePath": "data.language",
  "confidenceResponsePath": "data.confidence"
}
```

模板支持以下变量：

| 变量 | 内容 |
| --- | --- |
| `{{model}}` | 配置中的模型名称。 |
| `{{audio.base64}}` | 不带前缀的 Base64 音频。 |
| `{{audio.dataUrl}}` | 带 MIME 类型前缀的 Data URL。 |
| `{{audio.mimeType}}` | 例如 `audio/wav` 或 `audio/mp4`。 |
| `{{audio.fileName}}` | 临时音频文件名。 |
| `{{audio.byteLength}}` | 音频字节数。 |
| `{{language}}` | 可选语言提示。 |
| `{{prompt}}` | 业余无线电转写提示。 |

如果一个字符串完全由一个模板变量组成，客户端会保留变量的 JSON 类型；变量嵌入普通字符串时会转换为文本。

响应路径支持点号和数组下标，例如：

```text
text
data.transcript
choices[0].message.content
$.result[0].text
```

## 鉴权设置

常见配置如下：

- Bearer：请求头为 `Authorization: Bearer <API Key>`。
- 自定义请求头：例如名称填写 `X-API-Key`，前缀通常留空。
- 查询参数：例如名称填写 `api_key`；只有服务商明确要求时才使用。
- 无鉴权：仅适用于本机或受信任网络中的自建服务。

为了防止密钥明文传输，配置了凭据时，非回环地址必须使用 HTTPS。`http://127.0.0.1` 和 `http://localhost` 可用于本机服务。

## MiMo 配置示例

下面是 OpenAI 风格 multipart 端点的示例。模型名称和接口能力可能随服务商调整，最终应以你账户当前的服务商文档为准。

| 字段 | 示例值 |
| --- | --- |
| 配置名称 | `MiMo-V2.5-ASR` |
| API Base URL | `https://api.xiaomimimo.com/v1` |
| 模型名称 | `mimo-v2.5-asr` |
| 接口格式 | 音频转写 multipart |
| 鉴权方式 | Bearer 请求头 |
| 密钥前缀 | `Bearer ` |
| 高级请求选项 | `{}` |

如果服务商返回的 JSON 不是 `{"text":"..."}`，只需要根据实际响应调整 `responsePath`。如果服务商要求完全不同的请求体，则改用“通用 JSON HTTP”。

DeepSeek 或其他文字模型应配置在“文字助手”中。只有明确支持音频输入并能返回转写文本的模型，才应添加为语音配置。

## 录音与实时预览行为

客户端优先使用以下录音方式：

1. 16 kHz、单声道、PCM16 内存流。
2. 若平台不支持 PCM 流，则回退到 WAV 文件。
3. WAV 也不可用时，再回退到 AAC/M4A 文件。

使用 PCM 流时，客户端每 15 秒生成一个标准 WAV 片段并请求一次语音转写。页面显示的是按顺序累计的转写和结构化结果，不是逐字 WebSocket 流式输出。停止录音后，尚未发送的尾部音频和失败片段会再次处理。

使用 WAV 或 AAC 回退模式时，录音期间没有分段预览，停止录音后才上传整段音频。

客户端没有固定的 90 秒录音上限，但仍会受到模型服务的单次音频大小、时长、请求超时和账户额度限制。

## 字段整理与安全限制

开启文字助手后，累计转写会被整理为以下候选字段：

- 来台呼号、设备、天线、功率、QTH、高度。
- RST 发、RST 收和备注。

客户端会额外执行以下限制：

- 不允许 AI 填写时间。
- 不从转写中填写主控呼号。
- 已被用户修改、正在输入、被协作者锁定或只读的字段不会直接接受旧候选。
- 替换已有内容时必须手动勾选确认。
- 本地词库和近期记录只作为拼写参考，不能作为“确实听到该内容”的证据。

未配置文字助手时，语音模型仍可产生原始转写，但不会获得当前文字助手提供的统一结构化整理能力。

## 隐私与数据流

- 录音会直接发送给所选语音模型服务。
- 启用文字助手后，转写文本以及少量匹配到的本地拼写参考会发送给所选文字模型服务。
- API 密钥仅用于请求鉴权，并通过客户端安全凭据存储保存。
- 语音配置和密钥不会自动上传到 Callsign Roll Log Server。
- 配置导出不包含 API 密钥，但高级请求选项会被导出，因此不得把密钥写进 JSON。

处理真实点名录音前，请确认所选模型服务的隐私政策、数据保留规则和所在地法规符合你的使用要求。

## 常见问题

### `AI_AUDIO_PCM16_UNSUPPORTED`

这是旧版录音实现可能出现的错误。当前版本会直接尝试 PCM16 流，并在失败后自动回退到 WAV 或 AAC。仍然看到该错误时，请确认正在运行最新构建。

### `AI_AUDIO_ENCODER_UNSUPPORTED`

当前平台既不能提供 PCM16 流，也没有可用的 WAV/AAC 录音编码器。先检查系统录音组件和应用麦克风权限。

### `AI_AUDIO_EMPTY`

录音没有产生可上传内容。检查麦克风输入设备、权限和系统静音状态，然后重新录制。

### `missingCredentials`

当前配置要求密钥，但本机安全存储中没有对应凭据。编辑该语音配置并重新填写 API Key。

### `invalidConfiguration`

通常表示高级请求选项类型错误、`requestTemplate` 缺失、路径无效，或者把密钥配置到了不安全的 HTTP 地址。

### HTTP 400、404 或 422

- 400/422：重点检查接口格式、模型是否支持音频、音频编码和请求字段。
- 404：重点检查 Base URL 是否已经包含接口路径，以及 `path` 是否重复。
- 401/403：检查鉴权方式、请求头名称、前缀和 API Key。

### `invalidResponse` 或“找不到转写路径”

接口请求已经成功，但返回 JSON 与 `responsePath` 不一致。查看服务商的实际响应，并把路径改到包含转写文本的字段。

### 有转写但没有候选字段

先检查原始转写是否完整，再确认文字助手已经配置并启用。语音模型只负责 ASR；设备、QTH、功率等字段的统一整理由文字助手完成。

### 长录音被切成多段

这是当前的实时预览设计。PCM 流每 15 秒转写一次，但字段整理使用累计文本，不会只分析最后一个片段。停止录音后会生成一次完整确认结果。

## 开发位置

- 录音与 WAV 封装：`lib/services/ai_audio_recorder.dart`
- 三种 ASR 协议：`lib/services/ai_recognition/http_providers.dart`
- 请求鉴权与超时：`lib/services/ai_recognition/http_transport.dart`
- 累计转写和候选确认：`lib/widgets/ai_recognition_control.dart`
- 语音配置界面：`lib/widgets/settings/ai_recognition_settings.dart`
