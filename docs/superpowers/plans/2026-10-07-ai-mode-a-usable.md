# 模式 A 可用化 实施计划（Plan 2）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让「一次调用把音频变成字段」（模式 A）从引擎变成**用户可配、现场可用**：设置里能建多模态档案、录音时走模式 A、出错时看到可读提示。

**Architecture:** Plan 1 交付了引擎（枚举、provider、运行时入口 `AiRecognitionRuntime.recognizeRecord`、错误文案映射），但**没有任何 UI 与调用方**——`recognizeRecord` 全仓零调用、设置界面无法创建 `audioFieldExtraction` 档案。本计划补三件事：把该 kind 提升为设置里的一等公民（含服务商预设与显式 active-id）、把入口接进录音控件、把错误文案落到界面。

**Tech Stack:** Flutter 3.44、Dart 3.12、`flutter gen-l10n`（四份 ARB）、`flutter_test`。

---

## 前置事实（已核实，写代码时按这些来）

| 事实 | 位置 |
| --- | --- |
| 设置界面只挂了 ASR 一张 stage 卡 | `lib/widgets/settings/ai_recognition_settings.dart:87-93`（`_buildStageCard` 本身是通用的） |
| `_AiProfileEditorDialog` 已接收 `kind` | 同文件 `:731-739` |
| 能力声明只按 ASR / fieldExtraction 推导，**无 audioFieldExtraction 支路** | 同文件 `:1047-1054` |
| `_defaultRequestOptions` 对 jsonHttp 只分「ASR vs 非 ASR」，audio kind 会被当成文本 | 同文件 `:1089-1112` |
| `_editProfile` 保存后只把档案设为 ASR 或 fieldExtraction 的 active | 同文件 `:401-409` |
| provider 只有**临时** getter `activeAudioFieldExtractionProfile`，无 active-id 槽位 | `lib/providers/ai_recognition_settings_provider.dart:70-75` |
| `schemaVersion` 与存档**严格相等**，不等即抛 `FormatException` 并清空全部 AI 设置 | 同文件 `:106-110` |
| 新增 active 槽位要同步 6 处 | `_restore :119-126`、`_persist :459-460`、`setEnabled :144`、`upsertProfile :286-294`、`removeProfile :314-320`、`importProfiles :413-414`、`reset :436-437` |
| 录音控件**从不调用** `recognizeRecord` | `lib/widgets/ai_recognition_control.dart` 全文；执行器只有 `transcriptionExecutor` / `fieldExtractionExecutor` / `executor`（`:31-43`） |
| 控件挂载条件依赖 `activeAsrProfile != null` | `lib/widgets/log_form.dart:1877-1878` |
| 错误文案映射已实现但**零调用** | `lib/services/ai_recognition/errors.dart:47-67` |
| 用户可见处仍在拼原始异常 | `ai_recognition_control.dart:148,196,204,234,241,316,320,415`；`dictionary_manager.dart:148,189,220,260,313,370,510,517` |
| Excel 导入泄漏 http 客户端 | `lib/widgets/export_panel.dart:1378`（无 `close()`） |
| l10n 是**四份** ARB，新增键要四处都补 | `app_zh.arb` / `app_zh_CN.arb` / `app_en.arb` / `app_en_US.arb`，然后 `flutter gen-l10n` |

**注意**：`test/l10n/l10n_test.dart` **没有**中英键一致性检查，所以漏补某一份 ARB 不会被测试发现，必须人工核对（每个任务都要求）。

## 本计划不做（写清楚以免被当成遗漏）

- **连接测试按钮**（设计 §8.3）：Plan 3。理由——本计划的 Task 1 已用真实端点验证过链路，而「每个档案一个测试按钮」是便利性；(Task 6) 的可读错误提示已覆盖大部分配错场景。
- **诊断信息「复制」按钮**（设计 §13.3）：Plan 3。
- **复核面板的来源标记 / 一键采纳 / 更正交互**（设计 §7）：Plan 5。本计划只把候选**送进现有面板**，不改面板本身。
- **静音切分、记录级上下文、额度**（设计 §3.2/3.3/§6）：Plan 4。本计划沿用控件现有的分段与触发策略，只把**识别执行体**换成模式 A。
- **本地校对层**：Plan 5。

---

### Task 1: 验证服务商的音频输入格式（决定预设内容）

Plan 1 的横评实验对 `qwen3.8-omni-flash` 发裸 base64 音频时被拒：

```
400 invalid_parameter_error
The provided URL does not appear to be valid. Ensure it is correctly formatted.
```

纯文本请求是 200，说明鉴权与模型名都对——问题只在**音频字段的编码形态**。而代码里已有 `audioDataEncoding` 开关（`base64` / `dataUrl`），文档也提示过它。本任务把它验证清楚，结论直接决定 Task 2 预设里写什么。

**Files:**
- Create: `docs/superpowers/notes/2026-10-07-bailian-audio-format.md`（结论记录）

- [ ] **Step 1: 用真实端点逐个验证音频形态**

用 `test/fixtures/ai_eval/` 里的 WAV（若为空，先用 `espeak-ng -v cmn -s 130 -w ..."BG5DBL, 宁波高新区, 森海克斯 GT12, 五瓦, 八楼, 五九, 五九"` 生成一段）。凭据从环境变量读、**不落盘、不写进任何文件**。

逐个发送并记录 HTTP 状态与响应体前 400 字：

| 形态 | 请求体要点 |
| --- | --- |
| A 裸 base64 | `{'type':'input_audio','input_audio':{'data':<b64>,'format':'wav'}}`（已知 400，作为对照） |
| B dataUrl | `data` 为 `'data:audio/wav;base64,<b64>'` |
| C dataUrl 无 `format` | 同上但去掉 `format` |
| D 顶层 audio_url | `{'type':'input_audio','input_audio':{'data':{'url':'data:audio/wav;base64,<b64>'}}}` |

- [ ] **Step 2: 用一个真实形态验证「能出字段」**

对上一步唯一成功的形态，追加 system 指令（就是 `AiRecognitionRuntime.audioFieldExtractionInstructions` 的内容），确认返回的 `content` 是**可解析的 JSON 对象**，含 `transcript` 与 `fields` 两个键。把返回片段（**不要含密钥**）记进结论文档。

- [ ] **Step 3: 写结论文档**

`docs/superpowers/notes/2026-10-07-bailian-audio-format.md` 内容要求：

- 端点与模型（不含密钥）
- 四形态各自的状态码与原文错误
- 结论：百炼需要哪种编码；`audioDataEncoding` 应设为哪个值
- 是否支持「一次调用同时出转写与字段」；JSON 是否可直接解析
- 未验证的部分（例如其他模型、其他音频格式）

- [ ] **Step 4: 提交**

```bash
git add docs/superpowers/notes/2026-10-07-bailian-audio-format.md
git commit -m "docs: record the Bailian audio input shape"
```

**若四种形态全部失败**：不要编造结论。把它记为阻塞，停下来上报——预设里就写「该端点需要公网可访问的音频 URL」之类的事实描述，并在计划里标注模式 A 对百炼暂不可用。

---

### Task 2: 服务商预设（纯数据 + 单测）

**Files:**
- Create: `lib/services/ai_recognition/presets.dart`
- Test: `test/services/ai_recognition/presets_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';
import 'package:openlogtool/services/ai_recognition/presets.dart';

void main() {
  test('every preset builds a usable profile for its kind', () {
    for (final preset in aiProviderPresets) {
      final profile = preset.buildProfile(
        id: 'p',
        name: 'n',
        model: preset.defaultModel,
      );
      expect(profile.kind, preset.kind);
      expect(profile.baseUrl.hasScheme, isTrue);
      // 构造成功本身即证明 kind 与 protocol 配对合法。
      expect(profile.model, isNotEmpty);
    }
  });

  test('presets never carry credentials', () {
    for (final preset in aiProviderPresets) {
      final json = preset.buildProfile(id: 'p', name: 'n', model: 'm').toJson();
      expect(json.containsKey('credentialId'), isFalse);
      expect(json['headers'], isEmpty);
    }
  });

  test('the multimodal presets ask for the encoding the provider needs', () {
    final bailian = aiProviderPresets
        .firstWhere((preset) => preset.id == 'bailian-audio');
    expect(
      bailian.buildProfile(id: 'p', name: 'n', model: 'm')
          .requestOptions['audioDataEncoding'],
      'dataUrl', // Task 1 的结论；若结论不同，此处同步改
    );
  });

  test('every preset has a non-empty label and a reachable hint', () {
    for (final preset in aiProviderPresets) {
      expect(preset.labelKey, isNotEmpty);
      expect(preset.hintKey, isNotEmpty);
    }
  });
}
```

（`labelKey` / `hintKey` 是 l10n 键名，见 Task 3 的文案表；测试只断言非空，不依赖生成产物。）

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/ai_recognition/presets_test.dart`
Expected: FAIL，`presets.dart` 不存在

- [ ] **Step 3: 实现**

`lib/services/ai_recognition/presets.dart`：

```dart
import 'models.dart';

/// 一个服务商预设：把「协议 + 端点 + 鉴权 + 请求选项 + 默认模型」一次填好，
/// 用户只需粘 API Key。普通用户不可能自己猜出这些组合。
final class AiProviderPreset {
  const AiProviderPreset({
    required this.id,
    required this.labelKey,
    required this.hintKey,
    required this.kind,
    required this.protocol,
    required this.baseUrl,
    required this.defaultModel,
    this.requestOptions = const {},
    this.credentialTransport = const AiCredentialTransport.bearer(),
  });

  final String id;

  /// l10n 键名（四份 ARB 都要有）。
  final String labelKey;
  final String hintKey;

  final AiProviderKind kind;
  final AiProtocol protocol;
  final Uri baseUrl;
  final String defaultModel;
  final Map<String, Object?> requestOptions;
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
        baseUrl: baseUrl,
        model: model,
        requestOptions: requestOptions,
        credentialTransport: credentialTransport,
        capabilities: AiProviderCapabilities(
          supportsAudioTranscription:
              kind == AiProviderKind.speechRecognition,
          supportsFieldExtraction: kind == AiProviderKind.fieldExtraction,
          supportsAudioFieldExtraction:
              kind == AiProviderKind.audioFieldExtraction,
          supportsPrompt: true,
        ),
      );
}

/// 预设清单。Base URL / 模型 ID / 请求选项都必须实测过再写进来——
/// 服务商改接口的代价会直接落到用户身上（见 Task 1 的结论文档）。
const aiProviderPresets = <AiProviderPreset>[
  AiProviderPreset(
    id: 'bailian-audio',
    labelKey: 'aiPresetBailianAudio',
    hintKey: 'aiPresetBailianAudioHint',
    kind: AiProviderKind.audioFieldExtraction,
    protocol: AiProtocol.openAiChatCompletionsAudio,
    baseUrl: Uri.parse('https://dashscope.aliyuncs.com/compatible-mode/v1'),
    defaultModel: 'qwen3.8-omni-flash',
    // Task 1 的结论：裸 base64 会被当成 URL 拒绝，必须带 data URL 前缀。
    requestOptions: {'audioDataEncoding': 'dataUrl'},
  ),
  AiProviderPreset(
    id: 'siliconflow-audio',
    labelKey: 'aiPresetSiliconFlowAudio',
    hintKey: 'aiPresetSiliconFlowAudioHint',
    kind: AiProviderKind.audioFieldExtraction,
    protocol: AiProtocol.openAiChatCompletionsAudio,
    baseUrl: Uri.parse('https://api.siliconflow.cn/v1'),
    defaultModel: '',
    requestOptions: {'audioDataEncoding': 'dataUrl'},
  ),
  AiProviderPreset(
    id: 'custom',
    labelKey: 'aiPresetCustom',
    hintKey: 'aiPresetCustomHint',
    kind: AiProviderKind.audioFieldExtraction,
    protocol: AiProtocol.openAiChatCompletionsAudio,
    baseUrl: Uri.parse('https://example.com/v1'),
    defaultModel: '',
  ),
];
```

**注意**：硅基流动的默认模型与是否需要 `dataUrl` **未经实测**——`defaultModel` 故意留空（界面上让用户填），并要求在 Task 1 的结论文档里注明「硅基流动未验证」。不要编造模型名。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/services/ai_recognition/presets_test.dart`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/ai_recognition/presets.dart test/services/ai_recognition/presets_test.dart
git commit -m "feat(ai): add provider presets for the multimodal kind"
```

---

### Task 3: 多模态档案在设置里成为一等公民

一次做完三件事，因为它们是同一个「让 `audioFieldExtraction` 可配」的改动：设置界面挂卡、对话框支持该 kind、provider 加显式 active-id 槽位。

**Files:**
- Modify: `lib/providers/ai_recognition_settings_provider.dart`
- Modify: `lib/widgets/settings/ai_recognition_settings.dart`
- Modify: 四份 ARB + `flutter gen-l10n` 产物
- Test: `test/providers/ai_recognition_settings_provider_test.dart`、`test/widgets/settings_panel_responsive_test.dart`

- [ ] **Step 1: 先给 provider 加第四个 active 槽位（写失败测试）**

在 `test/providers/ai_recognition_settings_provider_test.dart` 追加：

```dart
  test('keeps a separate active slot for audio field extraction', () async {
    final settings = AiRecognitionSettingsProvider(
      preferencesLoader: () async => InMemoryKeyValueStore(),
      credentialStore: AiCredentialStore(secureValues: InMemorySecureValues()),
    );
    await settings.initialized;

    final profile = AiProviderProfile(
      id: 'multi',
      name: 'multi',
      kind: AiProviderKind.audioFieldExtraction,
      protocol: AiProtocol.openAiChatCompletionsAudio,
      baseUrl: Uri.parse('https://example.com/v1'),
      model: 'm',
    );
    await settings.upsertProfile(profile);
    await settings.setActiveAudioFieldExtractionProfile('multi');

    expect(settings.activeAudioFieldExtractionProfileId, 'multi');
    expect(settings.activeAudioFieldExtractionProfile?.id, 'multi');

    // 设为 null 后不再返回档案
    await settings.setActiveAudioFieldExtractionProfile(null);
    expect(settings.activeAudioFieldExtractionProfile, isNull);
  });

  test('rejects an audio active slot pointing at another kind', () async {
    final settings = AiRecognitionSettingsProvider(
      preferencesLoader: () async => InMemoryKeyValueStore(),
      credentialStore: AiCredentialStore(secureValues: InMemorySecureValues()),
    );
    await settings.initialized;
    await settings.upsertProfile(AiProviderProfile(
      id: 'asr',
      name: 'asr',
      kind: AiProviderKind.speechRecognition,
      protocol: AiProtocol.openAiAudioTranscriptions,
      baseUrl: Uri.parse('https://example.com/v1'),
      model: 'm',
    ));
    await expectLater(
      settings.setActiveAudioFieldExtractionProfile('asr'),
      throwsStateError,
    );
  });
```

（`InMemoryKeyValueStore` / `InMemorySecureValues` 请用该测试文件里**既有的**替身；上面的名字是示意，按实际改。下同。）

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/providers/ai_recognition_settings_provider_test.dart`
Expected: FAIL，`setActiveAudioFieldExtractionProfile` / `activeAudioFieldExtractionProfileId` 未定义

- [ ] **Step 3: 实现 provider 侧**

照 `_activeFieldExtractionProfileId` 的既有模式，逐处补第四个槽位（**`schemaVersion` 保持 1**，绝不要升版——`_restore :106-110` 严格相等，升版会清空所有用户的 AI 设置）：

1. 字段 `String? _activeAudioFieldExtractionProfileId;`
2. getter `activeAudioFieldExtractionProfileId`
3. `activeAudioFieldExtractionProfile` 改为 `_profileById(_activeAudioFieldExtractionProfileId, AiProviderKind.audioFieldExtraction)`——**替换掉现有的「取第一个 kind 匹配」临时实现**，并把那段临时注释删掉
4. setter `setActiveAudioFieldExtractionProfile(String? profileId)`：`_requireKind(profileId, AiProviderKind.audioFieldExtraction)`，与既有 setter 同构
5. `_persist` 增加 `'activeAudioFieldExtractionProfileId'`
6. `_restore` 用 `_validActiveId(json['activeAudioFieldExtractionProfileId'], AiProviderKind.audioFieldExtraction)` 读取
7. `upsertProfile` / `removeProfile` / `importProfiles` / `reset` 的清理逻辑各补一处（与既有两个槽位并列）

- [ ] **Step 4: 运行确认 provider 测试通过**

Run: `flutter test test/providers/ai_recognition_settings_provider_test.dart`
Expected: 全部 PASS（含既有用例，证明加槽位没有破坏持久化）

- [ ] **Step 5: 设置界面挂上多模态卡片 + 补对话框支路（写失败测试）**

在 `test/widgets/settings_panel_responsive_test.dart` 追加：

```dart
  testWidgets('offers an audio field extraction profile', (tester) async {
    await pumpSettingsPanel(tester); // 用该文件既有的 pump 辅助
    expect(find.byKey(const Key('ai-stage-audioFieldExtraction')), findsOneWidget);
    expect(
      find.byKey(const Key('ai-add-profile-audioFieldExtraction')),
      findsOneWidget,
    );
  });
```

- [ ] **Step 6: 实现界面侧**

1. `build()`（`:85-93` 附近）在 ASR 卡之后并列再加一张同构的卡：

```dart
        _buildStageCard(
          context,
          settings: settings,
          kind: AiProviderKind.audioFieldExtraction,
          profiles: settings.audioFieldExtractionProfiles.toList(growable: false),
          active: settings.activeAudioFieldExtractionProfile,
        ),
```

（`audioFieldExtractionProfiles` 是 provider 上的新过滤 getter，照 `asrProfiles` / `fieldExtractionProfiles` 写。）

2. `_AiProfileEditorDialogState._submit` 的能力声明（`:1047-1054`）补：

```dart
          supportsAudioFieldExtraction:
              widget.kind == AiProviderKind.audioFieldExtraction,
```

3. `_editProfile` 的 active 分支（`:401-409`）补第三路：

```dart
      switch (kind) {
        case AiProviderKind.speechRecognition:
          await settings.setActiveAsrProfile(draft.profile.id);
        case AiProviderKind.fieldExtraction:
          await settings.setActiveFieldExtractionProfile(draft.profile.id);
        case AiProviderKind.audioFieldExtraction:
          await settings.setActiveAudioFieldExtractionProfile(draft.profile.id);
      }
```

4. `initState` 默认协议（`:758-761`）与 `_defaultRequestOptions`（`:1089-1112`）补 `audioFieldExtraction` 支路：默认协议取 `AiProtocol.openAiChatCompletionsAudio`；jsonHttp 时给**带音频**的模板（`{{audio.dataUrl}}`），不要再落进文本模板。

5. `_buildStageCard` 里若有按 kind 分支的标题/文案（`:232-385`），补该 kind 的文案键。

- [ ] **Step 7: 补 l10n 文案（四份 ARB）**

在 `app_zh.arb`、`app_zh_CN.arb`、`app_en.arb`、`app_en_US.arb` **各加**下列键（中英对照如下；`zh_CN` 与 `zh` 同、`en_US` 与 `en` 同，跟随文件既有做法）：

| key | zh | en |
| --- | --- | --- |
| `aiStageAudioFieldExtractionTitle` | 多模态识别 | Multimodal recognition |
| `aiStageAudioFieldExtractionHint` | 一次调用直接从录音得到字段，不需要单独配置语音识别 | Turns a recording into fields in one call; no separate speech model needed |
| `aiPresetBailianAudio` | 阿里云百炼 | Alibaba Cloud Bailian |
| `aiPresetBailianAudioHint` | 推荐。按量计费，音频极便宜 | Recommended. Pay as you go; audio is very cheap |
| `aiPresetSiliconFlowAudio` | 硅基流动 | SiliconFlow |
| `aiPresetSiliconFlowAudioHint` | 便于横向对比开源音频模型 | Convenient for comparing open audio models |
| `aiPresetCustom` | 自定义 | Custom |
| `aiPresetCustomHint` | 手工填写端点与模型 | Enter the endpoint and model yourself |

然后跑 `flutter gen-l10n`，并**人工核对四份 ARB 都有这 8 个键**（`test/l10n/l10n_test.dart` 不做键一致性检查，漏补不会被发现）。

- [ ] **Step 8: 运行测试确认通过**

Run: `flutter test test/widgets/settings_panel_responsive_test.dart test/providers/ai_recognition_settings_provider_test.dart test/l10n/l10n_test.dart`
Expected: 全部 PASS

- [ ] **Step 9: 提交**

```bash
git add lib/providers/ai_recognition_settings_provider.dart lib/widgets/settings/ai_recognition_settings.dart \
        lib/l10n test/providers/ai_recognition_settings_provider_test.dart test/widgets/settings_panel_responsive_test.dart
git commit -m "feat(ai): make the multimodal profile first-class in settings"
```

---

### Task 4: 从预设新建档案

**Files:**
- Modify: `lib/widgets/settings/ai_recognition_settings.dart`（`_editProfile` 与 `_AiProfileEditorDialog`）
- Test: `test/widgets/settings_panel_responsive_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
  testWidgets('prefills the editor from a preset', (tester) async {
    await pumpSettingsPanel(tester);
    await tester.tap(find.byKey(const Key('ai-add-profile-audioFieldExtraction')));
    await tester.pumpAndSettle();

    // 预设下拉存在，且默认为百炼；Base URL 与模型已按预设预填
    expect(find.byKey(const Key('ai-profile-preset')), findsOneWidget);
    final baseUrl = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('ai-profile-base-url')),
        matching: find.byType(TextField),
      ),
    );
    expect(baseUrl.controller!.text, contains('dashscope'));
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/widgets/settings_panel_responsive_test.dart`
Expected: FAIL，`ai-profile-preset` 不存在

- [ ] **Step 3: 实现**

1. `_AiProfileEditorDialog` 增加可选参数 `AiProviderPreset? initialPreset`，并在 `initState` 用它预填 `_baseUrlController` / `_modelController` / `_protocol` / `_requestOptionsController`。
2. 对话框里在「配置名称」上方加一个预设下拉（`Key('ai-profile-preset')`），选项来自 `aiProviderPresets`，标签用 `context.l10n` 按 `labelKey` 取；选中后**只覆盖预设负责的字段**（Base URL / 协议 / 请求选项 / 模型），不覆盖用户已填的名称与密钥。
3. 「新增」按钮仍然打开同一个对话框，但 `initialPreset` 取预设列表第一个（百炼）。
4. 预设选择器旁边显示所选预设的 `hintKey` 文案。

**l10n 新增（四份 ARB，同 Task 3 的做法）**：

| key | zh | en |
| --- | --- | --- |
| `aiPreset` | 服务商 | Provider |
| `aiPresetApplied` | 已按预设填好，只需填 API 密钥 | Filled in from the preset; you only need the API key |

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/widgets/settings_panel_responsive_test.dart`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/settings/ai_recognition_settings.dart lib/l10n test/widgets/settings_panel_responsive_test.dart
git commit -m "feat(ai): create a multimodal profile from a preset"
```

---

### Task 5: 把模式 A 接进录音控件

这是「可用」的关键一步：让录音控件在配好多模态档案时调用 `recognizeRecord` 而不是「ASR + 抽取」两跳。

**Files:**
- Modify: `lib/widgets/ai_recognition_control.dart`
- Modify: `lib/widgets/log_form.dart`
- Test: `test/widgets/log_form_ai_recognition_test.dart`

- [ ] **Step 1: 写失败的测试**

在 `test/widgets/log_form_ai_recognition_test.dart` 追加（用该文件既有的 harness）：

```dart
  testWidgets('uses the single-call path when a multimodal profile is set',
      (tester) async {
    var singleCalls = 0;
    var twoHopCalls = 0;
    await pumpLogFormWithAi(
      tester,
      settings: aiSettingsWithAudioProfile(), // 配好 audioFieldExtraction 档案并设为 active
      recognizer: (audio, settings, cancellationToken) async {
        singleCalls++;
        return AiRecognitionResult(
          transcription: Transcription(text: 'BG5DBL'),
          candidates: [
            RecognitionCandidate(fields: const {'callsign': 'BG5DBL'}),
          ],
        );
      },
      transcriptionExecutor: (audio, settings, token) async {
        twoHopCalls++;
        return Transcription(text: '不该走这里');
      },
    );

    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(singleCalls, 1);
    expect(twoHopCalls, 0);
    expect(find.byKey(const Key('ai-review-panel')), findsOneWidget);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/widgets/log_form_ai_recognition_test.dart`
Expected: FAIL，`pumpLogFormWithAi` 不接受 `recognizer`（或控件没有该注入点）

- [ ] **Step 3: 实现控件侧**

1. 给 `AiRecognitionControl` 增加注入点（照既有 `transcriptionExecutor` / `fieldExtractionExecutor` 的写法）：

```dart
    this.recognizer = AiRecognitionRuntime.recognizeRecord,
```

类型为 `AiRecognitionExecutor`（`Future<AiRecognitionResult> Function(AudioSegment, AiRecognitionSettingsProvider, AiCancellationToken)`，已存在于 `ai_recognition_runtime.dart:4-8`——注意它是位置参数版本，与 `recognizeRecord` 的签名一致）。

2. 在控件内部读一次设置，决定走哪条路：

```dart
    final useSingleCall =
        context.read<AiRecognitionSettingsProvider>().activeAudioFieldExtractionProfile != null;
```

**优先级**：显式注入的 `widget.executor` 最高（测试与嵌入方用），其次 `useSingleCall` 走 `widget.recognizer`，否则维持现有的两跳。

3. 三个调用点都要分派，不能只改一处：
   - `_stopAndRecognize` 的整段路径（`:267-285`）
   - `_stopAndRecognize` 的重试路径（`:286-310`）
   - `_transcribeLiveChunk`（`:168-246`）——实时分段同样按 `useSingleCall` 走单跳；走单跳时不再调用 `fieldExtractionExecutor`

   单跳分支里：把音频交给 `recognizer`，拿到的 `AiRecognitionResult` 直接 `_reviewResult(...)`（与两跳路径相同的后处理），不要重复实现复核逻辑。

4. 取消语义保持一致：把 `_cancellationToken` 传给 `recognizer`；`AiRecognitionException` 的处理沿用既有的 catch 分支。

- [ ] **Step 4: 放宽挂载条件**

`lib/widgets/log_form.dart:1877-1878` 目前要求 `activeAsrProfile != null`，纯多模态用户永远看不到控件。改为：

```dart
                if (aiSettings?.enabled == true &&
                    (aiSettings?.activeAsrProfile != null ||
                        aiSettings?.activeAudioFieldExtractionProfile != null)) ...[
```

**同时**：`AiRecognitionSettingsProvider.setEnabled`（`:142-151`）现在在开启时要求有 ASR，否则抛 `StateError('AI_ASR_PROFILE_REQUIRED')`——纯多模态用户根本开不了开关。改为「ASR 或 多模态 至少有一个」，否则抛同一含义的错误。这一条很关键，漏了会导致「配好了档案但开关打不开」。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/widgets/log_form_ai_recognition_test.dart test/providers/ai_recognition_settings_provider_test.dart`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add lib/widgets/ai_recognition_control.dart lib/widgets/log_form.dart \
        test/widgets/log_form_ai_recognition_test.dart test/providers/ai_recognition_settings_provider_test.dart
git commit -m "feat(ai): run the multimodal path from the recording control"
```

---

### Task 6: 错误文案落到界面（含顺带修掉的两个泄漏）

**Files:**
- Modify: `lib/widgets/ai_recognition_control.dart`、`lib/widgets/dictionary_manager.dart`、`lib/widgets/export_panel.dart`
- Test: `test/widgets/log_form_ai_recognition_test.dart`、`test/widgets/export_panel_test.dart`

- [ ] **Step 1: 写失败的测试**

```dart
  testWidgets('shows a readable message instead of the raw error',
      (tester) async {
    await pumpLogFormWithAi(
      tester,
      settings: aiSettingsWithAudioProfile(),
      recognizer: (audio, settings, cancellationToken) async => throw const AiRecognitionException(
        kind: AiRecognitionErrorKind.missingCredentials,
        message: 'missing credentials for provider multi',
      ),
      expectFailure: true,
    );

    await tester.tap(find.byKey(const Key('ai-start-recording')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai-stop-recording')));
    await tester.pumpAndSettle();

    expect(find.textContaining('还没填 API Key'), findsOneWidget);
    expect(find.textContaining('missing credentials'), findsNothing);
    expect(find.textContaining('AiRecognitionException'), findsNothing);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/widgets/log_form_ai_recognition_test.dart`
Expected: FAIL（显示的是原始异常文本）

- [ ] **Step 3: 替换所有泄漏点**

把 `AiRecognitionException` 的分支统一换成 `aiUserFacingErrorMessage(error)`（来自 `lib/services/ai_recognition/errors.dart`），非 `AiRecognitionException` 的兜底分支用一句通用文案（新增 l10n 键 `aiUnknownFailure`）。

要改的位置（**逐个核对，不要漏**）：

- `lib/widgets/ai_recognition_control.dart:148, 196, 204, 234, 241, 316, 320, 415`
- `lib/widgets/dictionary_manager.dart:148, 189, 220, 260, 313, 370, 510, 517`

其中 `:196/:234` 与 `:204/:241` 是 `_liveTranscriptionError` 的赋值，最终经 `context.l10n.aiLiveTranscriptionRetrying(error)` 渲染（`:557`）——把该处也改成不接收原始文本。

**l10n 新增（四份 ARB）**：

| key | zh | en |
| --- | --- | --- |
| `aiUnknownFailure` | 操作失败，请稍后重试 | Something went wrong. Try again. |

- [ ] **Step 4: 顺带修掉 Excel 导入的客户端泄漏**

`lib/widgets/export_panel.dart:1378` 创建 `createTextAssistantClient(...)` 后全程无 `close()`。用 `try/finally` 包住，与 `ai_recognition_runtime.dart:144-177` 的写法一致。补一条测试断言客户端被关闭（用既有的假 client 替身模式）。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/widgets/log_form_ai_recognition_test.dart test/widgets/export_panel_test.dart test/l10n/l10n_test.dart`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add lib/widgets/ai_recognition_control.dart lib/widgets/dictionary_manager.dart lib/widgets/export_panel.dart \
        lib/l10n test/
git commit -m "fix(ai): show readable errors and close the Excel import client"
```

---

### Task 7: 端到端验收（手工，记录结果）

**Files:**
- Modify: `docs/superpowers/notes/2026-10-07-bailian-audio-format.md`（追加验收记录）

- [ ] **Step 1: 全量回归**

```bash
flutter analyze --no-pub
flutter test
```

Expected: 无告警；全绿（项数如实记录）。

- [ ] **Step 2: 构建设备上的包**

```bash
flutter build linux --release
```

Expected: `✓ Built build/linux/x64/release/bundle/openlogtool`

- [ ] **Step 3: 真机手工验收（需要凭据与麦克风）**

在隔离的数据目录里跑（避免碰真实点名数据）：

```bash
GDK_BACKEND=x11 XDG_DATA_HOME=/tmp/crl-accept-data XDG_CONFIG_HOME=/tmp/crl-accept-config \
  ./build/linux/x64/release/bundle/openlogtool
```

逐条核对并记录：

| 检查项 | 期望 |
| --- | --- |
| 设置 → AI 里出现「多模态识别」卡 | 有 |
| 新增档案时预设默认是百炼，Base URL 与模型已预填 | 有 |
| 只填 API Key 就能保存 | 能 |
| AI 开关能打开（没有 ASR 档案也不报错） | 能 |
| 点名台出现录音控件 | 有 |
| 录一句话 → 停止 → 出现候选面板 | 有 |
| 候选里的呼号/字段与所说内容一致 | 人工判断 |
| 故意把 Key 改错 → 提示是「API Key 无效…」而不是异常堆栈 | 是 |

- [ ] **Step 4: 记录结果并提交**

把上表逐项填上实测结果（含失败项与原因）追加到结论文档。**不要编造**——未通过就写未通过。

```bash
git add docs/superpowers/notes/2026-10-07-bailian-audio-format.md
git commit -m "docs: record the mode A acceptance run"
```

---

## 验收

- [ ] `flutter analyze --no-pub` 无告警
- [ ] `flutter test` 全绿（项数记录在案）
- [ ] 四份 ARB 的新增键齐全（人工核对，无测试兜底）
- [ ] `flutter build linux --release` 成功
- [ ] Task 7 的手工验收表逐项有实测结论，未通过项如实标注

## Self-Review

**Spec coverage（对照设计文档）**

| 设计 | 落在哪个任务 |
| --- | --- |
| §8.1 三步配置 | Task 3 挂卡 + Task 4 预设预填；「测试连接」按本计划说明推迟到 Plan 3 |
| §8.2 预设清单（百炼 / 硅基流动 / 自定义） | Task 2 |
| §8.4 错误可读化 | Task 6 |
| §13 用户只看到格式化后的内容 | Task 6（含 16 处替换与 Excel 泄漏） |
| §3.1 一次调用产出转写与字段 | Plan 1（引擎）+ Task 5（接线） |
| §5.1 模式 A 的补救中段 | **不在本计划**：Task 5 的分派只覆盖主路径；补救（重试 → 纯文本抽取）留待 Plan 4 与额度一起做 |
| §3.2 静音切分、§3.3 记录级上下文、§6 额度、§4 校对层、§7 复核面板交互 | Plan 4 / Plan 5 |

**已知缺口**

- Task 5 只接主路径，不接补救链：模式 A 失败时按现有错误处理提示，不做「用同一 provider 发纯文本重试」。这是有意的（补救与额度是一对，同属 Plan 4）。
- 连接测试按钮（§8.3）推迟到 Plan 3；在此之前用户自查的手段是 Task 6 的可读错误。
- `test/l10n/l10n_test.dart` 不做键一致性检查，四份 ARB 的齐全性只能靠人工核对——每个任务的验收里都写了这一条。

**占位扫描**：无 TBD / TODO。Task 2 的硅基流动默认模型**故意留空**并在注释里说明未实测，这不是占位而是不编造事实。

**类型一致性**：`AiProviderPreset`、`aiProviderPresets`、`labelKey`/`hintKey`、`buildProfile`、`activeAudioFieldExtractionProfileId`、`setActiveAudioFieldExtractionProfile`、`audioFieldExtractionProfiles`、`AiRecognitionControl.recognizer`、`aiUserFacingErrorMessage`、`aiUnknownFailure` 在各任务间拼写一致。
