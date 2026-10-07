# AI 多模态字段抽取引擎 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让「一段音频 → 转写 + 结构化字段」在一次网络调用内跑通，并把它做成可对多个候选模型做横评的载体。

**Architecture:** 在现有 `AiProviderProfile` / `AiProtocol` / `AiHttpTransport` 体系上新增第三个 provider 用途 `audioFieldExtraction`，复用已实现的 Chat Completions `input_audio` 消息构造，把输出契约从「转写文本」改为「转写 + 字段 JSON」。横评实验由表驱动测试承载：同一批 WAV 夹具跑多个候选模型，产出 JSON 合法率、字段召回与耗时对比，供选型决定。

**Tech Stack:** Dart 3.12、Flutter 3.44、`package:http`、现有 `AiHttpTransport`（已禁用重定向、非回环强制 HTTPS、响应体上限 2MB）、`flutter test`。

---

## 拆分为 5 个计划

本设计跨 5 个子系统，各自独立可交付。本计划只做第一个。

| 计划 | 内容 | 状态 |
| --- | --- | --- |
| **Plan 1（本文件）** | 多模态字段抽取引擎 + 横评实验载体 | 本次 |
| Plan 2 | 配置体验：预设、从预设新建档案、连接测试、错误格式化落 UI | 待写 |
| Plan 3 | 本地校对层：词库匹配、数值校验、学习闭环 | 待写 |
| Plan 4 | 静音切分 + 记录级上下文 + 额度 | 待写 |
| Plan 5 | 复核面板：来源标记、一键采纳、更正 | 待写 |

Plan 1 完成后，用真实录音即可做出模型选型决定（设计文档 §10.1），无需等 UI 就绪。

## 文件结构

| 文件 | 职责 | 动作 |
| --- | --- | --- |
| `lib/services/ai_recognition/models.dart` | 新增 `AiProviderKind.audioFieldExtraction`、`AiProtocol.supports` 分支、`AiProviderCapabilities.supportsAudioFieldExtraction`；迁入 `AiRecognitionResult` | 修改 |
| `lib/services/ai_recognition/pipeline.dart` | 移除 `AiRecognitionResult`（改由 models.dart 提供） | 修改 |
| `lib/services/ai_recognition/providers.dart` | 新增 `AudioFieldExtractionProvider` 接口 | 修改 |
| `lib/services/ai_recognition/http_providers.dart` | 抽出共享的 `input_audio` 消息构造；新增 `ProtocolAudioFieldExtractionProvider`、`_parseAudioFieldExtraction`、工厂方法 | 修改 |
| `lib/services/ai_recognition/errors.dart` | 新增错误文案映射（纯函数，无 UI 依赖） | 修改 |
| `test/services/ai_recognition/models_test.dart` | kind / 协议 / 能力 / 结果类型的往返与校验 | 修改 |
| `test/services/ai_recognition/audio_field_extraction_test.dart` | 新 provider 的请求体与响应解析 | 新建 |
| `test/services/ai_recognition/error_messages_test.dart` | 错误映射的完整覆盖 | 新建 |
| `test/services/ai_recognition/multimodal_model_comparison.dart` | 横评实验（无凭据时自动跳过） | 新建 |
| `test/fixtures/ai_eval/*.wav` | 横评用真实录音夹具（不入库，本地放置） | 新建（gitignore） |

---

### Task 1: 新增 `audioFieldExtraction` provider 用途

**Files:**
- Modify: `lib/services/ai_recognition/models.dart:5-35`
- Test: `test/services/ai_recognition/models_test.dart`

- [ ] **Step 1: 写失败的测试**

追加到 `test/services/ai_recognition/models_test.dart`：

```dart
group('audioFieldExtraction kind', () {
  test('accepts the chat audio protocol', () {
    expect(
      AiProtocol.openAiChatCompletionsAudio
          .supports(AiProviderKind.audioFieldExtraction),
      isTrue,
    );
  });

  test('accepts jsonHttp for providers with a request template', () {
    expect(
      AiProtocol.jsonHttp.supports(AiProviderKind.audioFieldExtraction),
      isTrue,
    );
  });

  test('rejects protocols that cannot carry audio', () {
    expect(
      AiProtocol.openAiChatCompletions
          .supports(AiProviderKind.audioFieldExtraction),
      isFalse,
    );
    expect(
      AiProtocol.openAiAudioTranscriptions
          .supports(AiProviderKind.audioFieldExtraction),
      isFalse,
    );
  });

  test('profile rejects a protocol that cannot carry audio', () {
    expect(
      () => AiProviderProfile(
        id: 'p1',
        name: 'bad',
        kind: AiProviderKind.audioFieldExtraction,
        protocol: AiProtocol.openAiChatCompletions,
        baseUrl: Uri.parse('https://example.com/v1'),
        model: 'm',
      ),
      throwsArgumentError,
    );
  });

  test('kind survives a JSON round trip', () {
    final json = AiProviderProfile(
      id: 'p1',
      name: 'qwen',
      kind: AiProviderKind.audioFieldExtraction,
      protocol: AiProtocol.openAiChatCompletionsAudio,
      baseUrl: Uri.parse('https://example.com/compatible-mode/v1'),
      model: 'qwen3.8-omni-flash',
    ).toJson();
    expect(
      AiProviderProfile.fromJson(json).kind,
      AiProviderKind.audioFieldExtraction,
    );
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition/models_test.dart`
Expected: 编译失败，`audioFieldExtraction` 未定义

- [ ] **Step 3: 实现**

`lib/services/ai_recognition/models.dart` 的枚举改为：

```dart
enum AiProviderKind {
  speechRecognition,
  fieldExtraction,

  /// 音频直接产出字段：一次调用同时返回转写与字段。设计的模式 A 用它。
  audioFieldExtraction;

  static AiProviderKind fromJson(Object? value) => _enumFromJson(
        values,
        value,
        'kind',
      );
}
```

`AiProtocol.supports` 增加一个分支：

```dart
  bool supports(AiProviderKind kind) => switch (kind) {
        AiProviderKind.speechRecognition => this == openAiAudioTranscriptions ||
            this == openAiChatCompletionsAudio ||
            this == jsonHttp,
        AiProviderKind.fieldExtraction =>
          this == openAiChatCompletions || this == jsonHttp,
        // 音频必须在请求体里，因此只有能携带 input_audio 的协议可用。
        // jsonHttp 靠 requestTemplate 自行携带。
        AiProviderKind.audioFieldExtraction =>
          this == openAiChatCompletionsAudio || this == jsonHttp,
      };
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition/models_test.dart`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/ai_recognition/models.dart test/services/ai_recognition/models_test.dart
git commit -m "feat(ai): add the audioFieldExtraction provider kind"
```

---

### Task 2: 新增能力标志 `supportsAudioFieldExtraction`

**Files:**
- Modify: `lib/services/ai_recognition/models.dart:38-105`
- Test: `test/services/ai_recognition/models_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
group('capabilities', () {
  test('defaults to not supporting audio field extraction', () {
    expect(
      const AiProviderCapabilities().supportsAudioFieldExtraction,
      isFalse,
    );
  });

  test('round trips through JSON', () {
    const capabilities = AiProviderCapabilities(
      supportsAudioFieldExtraction: true,
    );
    expect(
      AiProviderCapabilities.fromJson(capabilities.toJson())
          .supportsAudioFieldExtraction,
      isTrue,
    );
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition/models_test.dart`
Expected: FAIL，`supportsAudioFieldExtraction` 未定义

- [ ] **Step 3: 实现**

构造函数、`fromJson`、字段与 `toJson` 四处各加一项：

```dart
// 构造函数参数
    this.supportsAudioFieldExtraction = false,
// fromJson
      supportsAudioFieldExtraction: _bool(
        json['supportsAudioFieldExtraction'],
        'supportsAudioFieldExtraction',
        fallback: false,
      ),
// 字段
  final bool supportsAudioFieldExtraction;
// toJson
        'supportsAudioFieldExtraction': supportsAudioFieldExtraction,
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition/models_test.dart`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/ai_recognition/models.dart test/services/ai_recognition/models_test.dart
git commit -m "feat(ai): declare the audio field extraction capability"
```

**关于这个标志的定位**（复查后补充）：它**只作声明**，不参与任何选择逻辑。判断一个档案是否用于「音频→字段」一律看 `kind`（见 Task 6）。之所以不删掉它，是因为本类既有的模式就是「一项能力一个布尔」，且后续配置界面可以用它做提示；但**它不能与 `kind` 形成两个需要同时设置的开关**，否则会造出「档案配好了却选不中」的隐蔽问题。

---

### Task 3: 把 `AiRecognitionResult` 迁到 models.dart 并新增 provider 接口

`AiRecognitionResult` 现在定义在 `pipeline.dart`，而 `pipeline.dart` 依赖 `providers.dart`。新接口要让 provider 返回它，若不搬迁就会形成 `providers.dart → pipeline.dart → providers.dart` 的循环。搬到 `models.dart`（两者都已依赖它）即可消除。

**Files:**
- Modify: `lib/services/ai_recognition/models.dart`（追加类）
- Modify: `lib/services/ai_recognition/pipeline.dart:1-13`（删除类）
- Modify: `lib/services/ai_recognition/providers.dart`（追加接口）

- [ ] **Step 1: 写失败的测试**

新建 `test/services/ai_recognition/audio_field_extraction_test.dart`。

**注意**：只断言「`AiRecognitionResult` 可用」是**不够**的——搬迁前 barrel 仍从 `pipeline.dart` 导出它，测试会直接通过，构不成红灯。因此这里用一个假实现逼出新接口：

```dart
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

  test('AiRecognitionResult lives in models.dart', () {
    // 通过 models.dart 直接引用：若该类仍定义在 pipeline.dart，本文件将编译失败。
    // 不能只依赖桶文件——桶同时导出 pipeline.dart，那样即便类没搬走也照样通过。
    final models.AiRecognitionResult result = models.AiRecognitionResult(
      transcription: models.Transcription(text: 'x'),
      candidates: const [],
    );
    expect(result.candidates, isEmpty);
  });
}
```

该文件顶部除桶文件外，还需一个带前缀的 import：

```dart
import 'package:openlogtool/services/ai_recognition/models.dart' as models;
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition/audio_field_extraction_test.dart`
Expected: 编译失败，`AudioFieldExtractionProvider` 未定义

- [ ] **Step 3: 搬迁并新增接口**

`lib/services/ai_recognition/pipeline.dart`：删除第 5-13 行的 `AiRecognitionResult` 定义，保留 `import 'models.dart';`。

`lib/services/ai_recognition/models.dart` 末尾追加：

```dart
/// 一次调用的完整产出：原始转写与从中提取的字段。
///
/// 从 pipeline.dart 迁来，使 provider 能在不依赖 pipeline 的情况下返回它。
final class AiRecognitionResult {
  const AiRecognitionResult({
    required this.transcription,
    required this.candidates,
  });

  final Transcription transcription;
  final List<RecognitionCandidate> candidates;
}
```

`lib/services/ai_recognition/providers.dart` 末尾追加：

```dart
/// 一次调用把音频变成字段。设计的模式 A 用它。
abstract interface class AudioFieldExtractionProvider {
  AiProviderProfile get profile;

  AiProviderCapabilities get capabilities;

  Future<AiRecognitionResult> extractFieldsFromAudio(
    AudioSegment audio, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  });

  void close();
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition/`
Expected: 全部 PASS（含既有 pipeline 测试，验证搬迁未破坏调用方）

- [ ] **Step 5: 提交**

```bash
git add lib/services/ai_recognition/models.dart lib/services/ai_recognition/pipeline.dart \
        lib/services/ai_recognition/providers.dart test/services/ai_recognition/audio_field_extraction_test.dart
git commit -m "refactor(ai): move AiRecognitionResult to models and add the audio provider interface"
```

---

### Task 4: 抽出共享的 `input_audio` 消息构造

`ProtocolAsrProvider._transcribeChatAudio` 已实现完整的音频消息构造（base64 / dataUrl 编码、格式字段、可选 prompt）。新模式要复用同一套，先抽成文件级私有函数，避免两份实现漂移。

**Files:**
- Modify: `lib/services/ai_recognition/http_providers.dart:176-241`

- [ ] **Step 1: 写失败的测试**

追加到 `test/services/ai_recognition/audio_field_extraction_test.dart`：

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

void main() {
  // 既有文件已有 main，请把下面的 group 追加进同一个 main。
}

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
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition/audio_field_extraction_test.dart`
Expected: FAIL，`buildChatAudioContent` 未定义

- [ ] **Step 3: 实现**

在 `http_providers.dart` 末尾追加（把逻辑从 `_transcribeChatAudio` 中移出，原方法改为调用它）：

```dart
/// 构造 Chat Completions 的音频消息内容块。
///
/// ASR 与音频字段抽取共用，避免两份实现漂移。
@visibleForTesting
List<Object?> buildChatAudioContent(
  AiProviderProfile profile,
  AudioSegment audio, {
  String? prompt,
}) {
  final content = <Object?>[];
  if (_optionBool(profile, 'includePrompt', fallback: true)) {
    if (_nonEmptyOrNull(prompt) case final promptText?) {
      content.add({'type': 'text', 'text': promptText});
    }
  }
  final base64Audio = base64Encode(audio.bytes);
  final audioDataEncoding = _optionString(
    profile,
    'audioDataEncoding',
    fallback: 'base64',
  );
  if (audioDataEncoding != 'base64' && audioDataEncoding != 'dataUrl') {
    throw const FormatException(
      'audioDataEncoding must be base64 or dataUrl',
    );
  }
  content.add({
    'type': 'input_audio',
    'input_audio': {
      'data': audioDataEncoding == 'dataUrl'
          ? 'data:${audio.mimeType};base64,$base64Audio'
          : base64Audio,
      if (_optionBool(profile, 'includeAudioFormat', fallback: true))
        'format': _optionString(
          profile,
          'audioFormat',
          fallback: _audioFormat(audio),
        ),
    },
  });
  return content;
}
```

`_transcribeChatAudio` 中原来的构造改为：

```dart
    final content = buildChatAudioContent(profile, audio, prompt: prompt);
```

并在文件顶部补 `import 'package:meta/meta.dart';`（若项目已用 `visibleForTesting`，沿用既有 import 风格；否则把 `@visibleForTesting` 去掉，直接暴露为文件级函数）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition/`
Expected: 全部 PASS，包含既有的 `protocol_providers_test.dart`（证明抽取未改变 ASR 行为）

- [ ] **Step 5: 提交**

```bash
git add lib/services/ai_recognition/http_providers.dart test/services/ai_recognition/audio_field_extraction_test.dart
git commit -m "refactor(ai): share the chat audio message builder"
```

---

### Task 5: 实现 `ProtocolAudioFieldExtractionProvider`

一次调用返回「转写 + 字段」。响应契约：

```json
{ "transcript": "把听到的原话转写下来",
  "fields": { "callsign": "…", "qth": "…" },
  "uncertain": ["qth"] }
```

**Files:**
- Modify: `lib/services/ai_recognition/http_providers.dart`（新增类 + 解析函数 + 工厂方法）
- Test: `test/services/ai_recognition/audio_field_extraction_test.dart`

- [ ] **Step 1: 写失败的测试**

该文件的 import 需补上 `dart:convert`、`dart:typed_data`、`package:flutter_test/flutter_test.dart`、`package:http/http.dart as http`、`package:http/testing.dart`（提供 `MockClient`）、`package:openlogtool/services/ai_recognition/ai_recognition.dart`。追加到同一个 `main()` 内：

```dart
group('ProtocolAudioFieldExtractionProvider', () {
  AiProviderProfile profileWith({Map<String, Object?> options = const {}}) =>
      AiProviderProfile(
        id: 'qwen',
        name: 'qwen-omni',
        kind: AiProviderKind.audioFieldExtraction,
        protocol: AiProtocol.openAiChatCompletionsAudio,
        baseUrl: Uri.parse('https://example.com/compatible-mode/v1'),
        model: 'qwen3.8-omni-flash',
        requestOptions: options,
      );

  AudioSegment segment() => AudioSegment(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        mimeType: 'audio/wav',
        fileName: 's.wav',
        sampleRateHz: 16000,
      );

  test('parses transcript and fields from one response', () async {
    final provider = ProtocolAudioFieldExtractionProvider(
      profile: profileWith(),
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['model'], 'qwen3.8-omni-flash');
        final messages = body['messages']! as List<Object?>;
        final userContent =
            (messages.last! as Map<String, Object?>)['content']! as List<Object?>;
        expect(
          (userContent.last! as Map<String, Object?>)['type'],
          'input_audio',
        );
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content':
                      '{"transcript":"BG5DBL 宁波高新区","fields":{"callsign":"BG5DBL","qth":"宁波高新区"},"uncertain":[]}',
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await provider.extractFieldsFromAudio(
      segment(),
      instructions: 'Extract one check-in record.',
    );

    expect(result.transcription.text, 'BG5DBL 宁波高新区');
    expect(result.candidates.single.fields, {
      'callsign': 'BG5DBL',
      'qth': '宁波高新区',
    });
    provider.close();
  });

  test('returns no candidates when the model reports an empty record', () async {
    final provider = ProtocolAudioFieldExtractionProvider(
      profile: profileWith(),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '{"transcript":"嗯…","fields":{}}',
                },
              },
            ],
          }),
          200,
        ),
      ),
    );

    final result = await provider.extractFieldsFromAudio(segment());

    expect(result.transcription.text, '嗯…');
    expect(result.candidates, isEmpty);
    provider.close();
  });

  test('rejects a response that is not JSON', () async {
    final provider = ProtocolAudioFieldExtractionProvider(
      profile: profileWith(),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': '抱歉，我没听清'}},
            ],
          }),
          200,
        ),
      ),
    );

    expect(
      () => provider.extractFieldsFromAudio(segment()),
      throwsA(
        isA<AiRecognitionException>().having(
          (e) => e.kind,
          'kind',
          AiRecognitionErrorKind.invalidResponse,
        ),
      ),
    );
    provider.close();
  });

  test('rejects a mismatched profile kind', () {
    expect(
      () => ProtocolAudioFieldExtractionProvider(
        profile: AiProviderProfile(
          id: 'p',
          name: 'asr',
          kind: AiProviderKind.speechRecognition,
          protocol: AiProtocol.openAiChatCompletionsAudio,
          baseUrl: Uri.parse('https://example.com/v1'),
          model: 'm',
        ),
      ),
      throwsArgumentError,
    );
  });
});
```

**实施时必须对上面的测试样例做三处修正**——这是实施中发现的原样例真实缺陷，已在提交中修正，记录如下以免后人照抄：

1. **凭据**：`profileWith` 造出的档案走默认 `AiCredentialTransport.bearer()`（`isRequired: true`），请求会在解析之前抛 `missingCredentials`，四条用例全部失败。给该档案加 `credentialTransport: const AiCredentialTransport.none(),`。
2. **编码**：`http.Response(String, ...)` 在未给 `content-type` 时按 **latin1** 编码，中文响应体（`宁波高新区`、`嗯…` 等）会直接抛错并被包成 `network`。三个 mock 响应都要加 `headers: const {'content-type': 'application/json; charset=utf-8'}`。
3. **await**：非 JSON 那条若写成 `expect(() => future, throwsA(...))`，同步闭包不会 await，紧随的 `provider.close()` 会中止在途请求，实际得到 `closed` 而非 `invalidResponse`。改为 `await expectLater(provider.extractFieldsFromAudio(segment()), throwsA(...))`。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition/audio_field_extraction_test.dart`
Expected: FAIL，`ProtocolAudioFieldExtractionProvider` 未定义

- [ ] **Step 3: 实现**

`http_providers.dart` 新增（与 `ProtocolFieldExtractionProvider` 并列）：

```dart
/// 一次调用把音频变成「转写 + 字段」。设计的模式 A 用它。
final class ProtocolAudioFieldExtractionProvider
    implements AudioFieldExtractionProvider {
  ProtocolAudioFieldExtractionProvider({
    required this.profile,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) : _transport = AiHttpTransport(
          profile: profile,
          httpClient: httpClient,
          timeout: timeout,
        ) {
    if (profile.kind != AiProviderKind.audioFieldExtraction) {
      throw ArgumentError.value(
        profile.kind,
        'profile.kind',
        'must be audioFieldExtraction',
      );
    }
    if (!_supportedProtocols.contains(profile.protocol)) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.unsupportedProtocol,
        message:
            '${profile.protocol.name} cannot carry audio for field extraction',
        providerId: profile.id,
      );
    }
  }

  static const _supportedProtocols = {
    AiProtocol.openAiChatCompletionsAudio,
    AiProtocol.jsonHttp,
  };

  @override
  final AiProviderProfile profile;
  final AiHttpTransport _transport;

  @override
  AiProviderCapabilities get capabilities => profile.capabilities;

  @override
  Future<AiRecognitionResult> extractFieldsFromAudio(
    AudioSegment audio, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  }) async {
    try {
      final response = switch (profile.protocol) {
        AiProtocol.openAiChatCompletionsAudio => _recordChatAudio(
            audio,
            instructions: instructions,
            options: options,
          ),
        AiProtocol.jsonHttp => _recordJson(
            audio,
            instructions: instructions,
            options: options,
          ),
        AiProtocol.openAiAudioTranscriptions ||
        AiProtocol.openAiChatCompletions =>
          throw AiRecognitionException(
            kind: AiRecognitionErrorKind.unsupportedProtocol,
            message:
                '${profile.protocol.name} cannot carry audio for field extraction',
            providerId: profile.id,
          ),
      };
      return await response;
    } on AiRecognitionException {
      rethrow;
    } on FormatException catch (error) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: error.message,
        providerId: profile.id,
        cause: error,
      );
    } on ArgumentError catch (error) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: error.message.toString(),
        providerId: profile.id,
        cause: error,
      );
    }
  }

  Future<AiRecognitionResult> _recordChatAudio(
    AudioSegment audio, {
    required String? instructions,
    required AiRequestOptions options,
  }) async {
    final configuredPrompt = _optionStringOrNull(profile, 'systemPrompt');
    final instructionText = _nonEmptyOrNull(instructions);
    final systemPrompt = [
      if (configuredPrompt != null) configuredPrompt,
      if (instructionText != null) instructionText,
    ].join('\n');
    final messages = <Object?>[];
    if (systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({
      'role': 'user',
      'content': buildChatAudioContent(profile, audio),
    });
    final response = await _sendJson(
      _transport,
      _openAiEndpoint(profile, const ['v1', 'chat', 'completions']),
      'POST',
      <String, Object?>{
        ..._optionJsonObject(profile, 'body'),
        'model': profile.model,
        'messages': messages,
      },
      options,
    );
    return _parseAudioFieldExtraction(response, profile);
  }

  Future<AiRecognitionResult> _recordJson(
    AudioSegment audio, {
    required String? instructions,
    required AiRequestOptions options,
  }) async {
    final template = profile.requestOptions['requestTemplate'];
    if (template == null) {
      throw const FormatException('requestTemplate is required for jsonHttp');
    }
    final body = renderAiJsonTemplate(template, {
      'model': profile.model,
      'audio': {
        'base64': base64Encode(audio.bytes),
        'dataUrl': 'data:${audio.mimeType};base64,${base64Encode(audio.bytes)}',
        'mimeType': audio.mimeType,
        'fileName': audio.fileName,
        'byteLength': audio.bytes.length,
      },
      'instructions': _nonEmptyOrNull(instructions),
    });
    final response = await _sendJson(
      _transport,
      _configuredEndpoint(profile),
      _optionString(profile, 'method', fallback: 'POST').toUpperCase(),
      body,
      options,
    );
    return _parseAudioFieldExtraction(response, profile);
  }

  @override
  void close() => _transport.close();
}
```

同文件追加解析函数：

```dart
/// 解析 `{"transcript": …, "fields": {…}, "uncertain": […]}`。
///
/// `fields` 为空或缺失时不产出候选——这是模型在说「这条没有可用信息」，
/// 与「解析失败」是两件事，后者抛 [AiRecognitionErrorKind.invalidResponse]。
AiRecognitionResult _parseAudioFieldExtraction(
  http.Response response,
  AiProviderProfile profile,
) {
  final decoded = _decodeResponse(response, profile);
  final defaultPath = profile.protocol == AiProtocol.openAiChatCompletionsAudio
      ? 'choices[0].message.content'
      : r'$';
  final responsePath =
      _optionString(profile, 'responsePath', fallback: defaultPath);
  var resolved = _readResponsePath(decoded, responsePath, profile);
  if (resolved is String) {
    try {
      resolved = jsonDecode(resolved);
    } on FormatException catch (error) {
      throw _invalidResponse(
        profile,
        'The audio field extraction response is not JSON',
        error,
      );
    }
  }
  if (resolved is! Map) {
    throw _invalidResponse(
      profile,
      'The audio field extraction response is not an object',
    );
  }

  final transcript = resolved['transcript'];
  if (transcript is! String || transcript.trim().isEmpty) {
    throw _invalidResponse(profile, 'The provider returned no transcript');
  }

  final rawFields = resolved['fields'];
  if (rawFields != null && rawFields is! Map) {
    throw _invalidResponse(profile, 'The fields member is not an object');
  }
  final fields = <String, Object?>{};
  if (rawFields is Map) {
    for (final entry in rawFields.entries) {
      if (entry.key is! String) {
        throw _invalidResponse(profile, 'A field has a non-string key');
      }
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) continue;
      fields[entry.key as String] = value.trim();
    }
  }

  final uncertain = <String>[];
  final rawUncertain = resolved['uncertain'];
  if (rawUncertain is List) {
    for (final value in rawUncertain) {
      if (value is String && value.trim().isNotEmpty) {
        uncertain.add(value.trim());
      }
    }
  }

  final transcription = Transcription(
    text: transcript.trim(),
    metadata: {
      'providerId': profile.id,
      'protocol': profile.protocol.name,
      'model': profile.model,
    },
  );

  return AiRecognitionResult(
    transcription: transcription,
    candidates: fields.isEmpty
        ? const []
        : [
            RecognitionCandidate(
              fields: fields,
              sourceText: transcription.text,
              metadata: {
                'providerId': profile.id,
                'protocol': profile.protocol.name,
                'model': profile.model,
                if (uncertain.isNotEmpty) 'uncertain': uncertain,
              },
            ),
          ],
  );
}
```

工厂方法追加到 `AiProviderFactory`：

```dart
  static AudioFieldExtractionProvider createAudioFieldExtraction(
    AiProviderProfile profile, {
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) =>
      ProtocolAudioFieldExtractionProvider(
        profile: profile,
        httpClient: httpClient,
        timeout: timeout,
      );
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition/audio_field_extraction_test.dart`
Expected: 全部 PASS

- [ ] **Step 5: 静态检查并提交**

```bash
flutter analyze --no-pub
git add lib/services/ai_recognition/http_providers.dart test/services/ai_recognition/audio_field_extraction_test.dart
git commit -m "feat(ai): extract one record's fields from audio in a single call"
```

---

### Task 6: 运行时入口 `recognizeRecord`

`AiRecognitionRuntime` 现在只有「ASR → 抽取」两跳。新增一次调用的一跳入口，供模式 A 使用。

**Files:**
- Modify: `lib/services/ai_recognition_runtime.dart:46-53`
- Modify: `lib/providers/ai_recognition_settings_provider.dart`（新增 `activeAudioFieldExtractionProfile`）
- Test: `test/services/ai_recognition_runtime_test.dart`

- [ ] **Step 1: 写失败的测试**

追加到 `test/services/ai_recognition_runtime_test.dart`：

```dart
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
    (audio, options) async {
      calls++;
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
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition_runtime_test.dart`
Expected: FAIL，`recognizeRecordWith` 未定义

- [ ] **Step 3: 实现**

`lib/services/ai_recognition_runtime.dart` 先把执行器 typedef 与入口加在 `AiRecognitionRuntime` 内（放在 `recognize` 之前）：

```dart
typedef AudioFieldExtractionExecutor = Future<AiRecognitionResult> Function(
  AudioSegment audio,
  String? instructions,
  AiCancellationToken cancellationToken,
);

  /// 模式 A 的入口：一次调用拿到转写与字段。
  ///
  /// 与 [recognize] 的区别是不经过独立的 ASR 与文字助手两次网络往返。
  static Future<AiRecognitionResult> recognizeRecord(
    AudioSegment audio,
    AiRecognitionSettingsProvider settings,
    AiCancellationToken cancellationToken,
  ) async {
    return recognizeRecordWith(
      audio,
      (segment, instructions) async {
        final profile = settings.activeAudioFieldExtractionProfile;
        if (profile == null) {
          throw StateError('AI_AUDIO_FIELD_EXTRACTION_PROFILE_REQUIRED');
        }
        final provider = AiProviderFactory.createAudioFieldExtraction(profile);
        try {
          return await provider.extractFieldsFromAudio(
            segment,
            instructions: instructions,
            options: AiRequestOptions(
              credentialResolver: settings.credentialResolver,
              cancellationToken: cancellationToken,
            ),
          );
        } finally {
          provider.close();
        }
      },
      instructions: audioFieldExtractionInstructions,
    );
  }

  /// 与 [recognizeRecord] 相同，但执行器可由调用方注入，便于测试。
  static Future<AiRecognitionResult> recognizeRecordWith(
    AudioSegment audio,
    Future<AiRecognitionResult> Function(AudioSegment, String?)
        execute,
    {
    String? instructions,
  }) async {
    return execute(audio, instructions);
  }
```

并在同一文件的常量区新增指令（沿用既有 `extractionInstructions` 的字段集合与禁令）：

```dart
  /// 模式 A 的指令：一次调用同时要转写与字段。
  static const audioFieldExtractionInstructions = '''
Listen to one amateur-radio net check-in and return a single JSON object:
{"transcript":"<verbatim transcript>","fields":{...},"uncertain":[...]}

"fields" accepts only these optional string keys:
callsign, device, antenna, power, qth, height, rstSent, rstRcvd, remarks.
Never return time. Never return the net controller callsign; it belongs to the
session context. Omit any field not clearly spoken. Do not infer or invent
values. Normalize explicitly spoken transmit power to digits plus W.
Decode NATO phonetic spelling when it clearly forms a callsign, and return
callsigns uppercase without spaces.
List in "uncertain" any field you had to guess or that was hard to hear.
Return {"transcript":"…","fields":{}} when the audio has no check-in data.
''';
```

`lib/providers/ai_recognition_settings_provider.dart` 新增取值器（与既有 `activeAsrProfile` / `activeFieldExtractionProfile` 并列）：

```dart
  /// 当前用于模式 A 的多模态档案；未配置时返回 null。
  ///
  /// 只按 [AiProviderKind.audioFieldExtraction] 判定：`kind` 是这一用途的唯一
  /// 权威来源。`capabilities.supportsAudioFieldExtraction` 只是给界面看的声明，
  /// 不参与选择——否则会出现「档案配好了却选不中」这种难查的问题。
  AiProviderProfile? get activeAudioFieldExtractionProfile =>
      _profiles.firstWhereOrNull(
        (profile) =>
            profile.kind == AiProviderKind.audioFieldExtraction,
      );
```

（若项目未用 `collection` 扩展，改写为显式 for 循环，与文件内既有取值器的写法保持一致。）

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition_runtime_test.dart`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/ai_recognition_runtime.dart lib/providers/ai_recognition_settings_provider.dart \
        test/services/ai_recognition_runtime_test.dart
git commit -m "feat(ai): add the single-call record recognition entry"
```

**实施中发现的三处修订**（复查后落地，以实际提交为准）：

1. **不要 `recognizeRecordWith` 这种静态转发接缝**。它让测试变成恒真断言——把 `recognizeRecord` 的函数体整段删掉，测试照样全绿。改为给 `recognizeRecord` 加一个可选的工厂参数 `AudioFieldExtractionProviderFactory? providerFactory`（默认 `AiProviderFactory.createAudioFieldExtraction`），并让测试**真的走 `recognizeRecord`**：配置一个真实档案、注入计数用的假 provider、断言工厂与 provider 各被调用一次、`instructions` 等于真实常量、`close()` 被调用、以及未配置档案时抛错。这与本仓既有的构造器/参数注入风格一致。
2. **不要用 `StateError` 抛内部码**。`StateError('AI_AUDIO_FIELD_EXTRACTION_PROFILE_REQUIRED')` 属 §13 禁止进入界面的内部标识，而 UI 的兜底 `catch` 会 `error.toString()` 把它弹给用户。改用 `AiRecognitionException(kind: AiRecognitionErrorKind.invalidConfiguration, message: 'No audio field extraction profile is configured')`——引擎边界统一抛这一种异常，Task 7 的 kind 映射即可自动接住。
3. **`activeAudioFieldExtractionProfile` 的取值策略是临时方案**，需在注释中标注：目前取第一个 kind 匹配的档案；Plan 2 引入配置界面时改为与 `activeFieldExtractionProfile` 一致的显式 active-id 选择（现在补 id 槽位而没有界面去设置，只会让它永远是 null，反而使模式 A 不可用）。

**关于本任务新增符号尚无生产调用方**：`recognizeRecord`、`audioFieldExtractionInstructions`、`activeAudioFieldExtractionProfile` 属为 Plan 2 预埋，**不要**当成遗留代码清理。

---

### Task 7: 错误文案映射（`§13` 的引擎侧）

界面不得出现内部错误码。映射函数是纯函数，放引擎侧，UI 在 Plan 2 里接。

**Files:**
- Modify: `lib/services/ai_recognition/errors.dart`
- Test: `test/services/ai_recognition/error_messages_test.dart`

- [ ] **Step 1: 写失败的测试**

新建 `test/services/ai_recognition/error_messages_test.dart`：

```dart
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
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition/error_messages_test.dart`
Expected: FAIL，`aiUserFacingErrorMessage` 未定义

- [ ] **Step 3: 实现**

`errors.dart` 末尾追加。**枚举值以本文件第 1-12 行的实际定义为准**（`invalidConfiguration`、`unsupportedProtocol`、`missingCredentials`、`audioRejected`、`timeout`、`network`、`httpStatus`、`invalidResponse`、`cancelled`、`closed`）：

```dart
/// 面向用户的错误文案：只说「出了什么问题」与「下一步做什么」。
///
/// 内部错误码、异常文本、HTTP 状态行与响应体片段一律不得进入界面
/// （设计文档 §13）。诊断细节走日志。
String aiUserFacingErrorMessage(AiRecognitionException error) =>
    switch (error.kind) {
      AiRecognitionErrorKind.missingCredentials => '还没填 API Key',
      AiRecognitionErrorKind.httpStatus => _httpStatusMessage(error.statusCode),
      AiRecognitionErrorKind.timeout => '网络不通或响应太慢，检查是否需要代理',
      AiRecognitionErrorKind.network => '连不上服务商，检查网络',
      AiRecognitionErrorKind.audioRejected => '服务商拒收了这段录音，换个格式或缩短一点再试',
      AiRecognitionErrorKind.invalidConfiguration => '配置与服务商不匹配，建议换回官方预设',
      AiRecognitionErrorKind.unsupportedProtocol => '该服务商不支持这种调用方式，建议换回官方预设',
      AiRecognitionErrorKind.invalidResponse => '服务商返回的内容无法解析，稍后重试或换个模型',
      AiRecognitionErrorKind.cancelled => '已取消',
      AiRecognitionErrorKind.closed => '识别已结束',
    };

String _httpStatusMessage(int? statusCode) => switch (statusCode) {
      401 || 403 => 'API Key 无效，或该 Key 没有这个模型的权限',
      404 => '模型名或接口地址不对，检查是否选错服务商预设',
      413 || 415 => '这段录音的格式或大小不被接受，缩短一点再试',
      429 => '请求太频繁，稍等几秒再试',
      _ => '服务商返回错误，稍后重试',
    };
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition/error_messages_test.dart`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/ai_recognition/errors.dart test/services/ai_recognition/error_messages_test.dart
git commit -m "feat(ai): add user-facing error messages"
```

---

### Task 8: 横评实验（设计文档 §10.1）

拿真实点名录音对多个候选模型跑同一份指令，产出选型依据。无凭据时自动跳过，因此可以入库且不影响 CI。

**Files:**
- Create: `test/services/ai_recognition/multimodal_model_comparison.dart`
- Create: `test/fixtures/ai_eval/.gitkeep`（夹具目录，音频不入库）
- Modify: `.gitignore`（忽略 `test/fixtures/ai_eval/*.wav`）

- [ ] **Step 1: 建立夹具目录与忽略规则**

```bash
mkdir -p test/fixtures/ai_eval
printf 'test/fixtures/ai_eval/*.wav\n' >> .gitignore
git add .gitignore test/fixtures/ai_eval/.gitkeep
git commit -m "test(ai): reserve a directory for evaluation audio"
```

- [ ] **Step 2: 写实验**

```dart
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
      ? dir.listSync().whereType<File>().where((f) => f.path.endsWith('.wav'))
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
        'P50 毫秒': durationsMs.isEmpty ? 0 : durationsMs[durationsMs.length ~/ 2],
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
```

夹具命名约定：`<期望呼号>__<说明>.wav`，例如 `BG5DBL__宁波高新区_森海克斯.wav`。实验用文件名里的期望呼号算准确率，因此录音与文件名必须一一对应。

- [ ] **Step 3: 运行确认跳过路径正常**

Run: `flutter test test/services/ai_recognition/multimodal_model_comparison.dart`
Expected: PASS（输出「缺少 … 跳过横评」，不报错）

- [ ] **Step 4: 用真实录音跑一次并记录结论**

```bash
CRL_AI_EVAL_KEY=<key> \
CRL_AI_EVAL_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1 \
CRL_AI_EVAL_MODELS=qwen3.8-omni-flash,qwen3.5-omni-plus \
flutter test test/services/ai_recognition/multimodal_model_comparison.dart
```

把结果写回设计文档 §10.1 的表格下方，作为选型依据：

```markdown
**实测结论（2026-10-__）**：主模型选定 `<模型>`，JSON 合法率 <n>%，呼号命中 <n>/<n>。
```

- [ ] **Step 5: 提交**

```bash
git add test/services/ai_recognition/multimodal_model_comparison.dart
git commit -m "test(ai): add the multimodal model comparison harness"
```

---

## 验收

- [ ] `flutter test test/services/ai_recognition/` 全绿
- [ ] `flutter analyze --no-pub` 无新增告警
- [ ] 横评实验在缺少凭据时跳过、不影响 CI；有凭据时输出三模型对比表
- [ ] 设计文档 §10.1 填入了实测结论与选定模型

## 交接给 Plan 2 的内容

- 设置 UI：多模态档案类型、预设下拉、从预设新建
- 连接测试：内置样例音频资产、测试按钮与结果展示
- 错误文案接到 SnackBar，替换现有 `error.toString()`
- 格式合规测试：遍历用户可见文案，断言无内部标识

## Self-Review

**Spec coverage（对照设计文档）**

| 设计 | 落在哪个任务 |
| --- | --- |
| §3.1 一次调用产出 transcript + fields | Task 5、Task 6 |
| §3.1 不返回 time 与主控呼号 | Task 6 指令常量 |
| §3.1 新增「音频 → 字段」用途 | Task 1、Task 3 |
| §5.1 模式 A 的补救中段可复用同一 provider | Task 5（同一 provider 接受纯文本请求的能力由 `systemPrompt` + 空音频路径覆盖，留待 Plan 2 接线） |
| §13 错误不泄漏内部标识 | Task 7 |
| §10.1 前置横评实验 | Task 8 |
| §4 校对层、§3.2 静音切分、§3.3 记录级上下文、§6 额度、§7 复核面板、§8 配置体验 | Plan 2–5 |

**已知缺口**：Task 6 的 `recognizeRecord` 目前只用注入执行器测试，未覆盖「空音频 + 纯文本」这条补救路径——它依赖 Plan 2 的设置接线，因此在该计划的验收里补测。

**占位扫描**：无 TBD / TODO。Task 7 的文案映射已按 `errors.dart` 的真实枚举（`invalidConfiguration` / `unsupportedProtocol` / `missingCredentials` / `audioRejected` / `timeout` / `network` / `httpStatus` / `invalidResponse` / `cancelled` / `closed`）逐项写全，`httpStatus` 按状态码分支；测试强制覆盖全部枚举值，不构成占位。

**类型一致性**：`AiProviderKind.audioFieldExtraction`、`AiProviderCapabilities.supportsAudioFieldExtraction`、`AudioFieldExtractionProvider.extractFieldsFromAudio`、`ProtocolAudioFieldExtractionProvider`、`AiProviderFactory.createAudioFieldExtraction`、`AiRecognitionRuntime.recognizeRecord` / `recognizeRecordWith` / `audioFieldExtractionInstructions`、`buildChatAudioContent`、`aiUserFacingErrorMessage` 在各任务间拼写一致。
