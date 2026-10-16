# 扫码加入服务器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 相机或图片识别出服务器地址后，先弹出一个确认框，确认才连接；Linux 与 Windows 用图片识别走同一条路径。

**Architecture:** 纯 Dart 从图片字节解出二维码文本。是否换服务器、手电筒和切换摄像头是否显示，都是无界面的判断。确认框只有一个函数。设置页的图片入口和扫码页都调用它；确认后设置页用 `skipSwitchConfirm: true` 调用现有的保存并检查，避免再弹出「切换服务器？」。相机页只在 Android、iOS、macOS 和网页打开，不给 Linux / Windows 接第二套摄像头。

**Tech Stack:** Flutter、`mobile_scanner` 7.4（仅相机）、`zxing2` 0.2 + `image` 4（图片解码）、现有 `file_picker`、四份 ARB、`flutter gen-l10n`、`flutter_test`。

**规格：** `docs/superpowers/specs/2026-10-16-scan-server-qr-design.md`

**分支：** 就在当前 `feature/ai-multimodal` 上做。不要 push，不要关 issue 61，不要改服务端仓库，不要改 `site/wechat-zjra.svg`。

---

## 文件

| 文件 | 职责 |
| --- | --- |
| `lib/utils/qr_image_decode.dart` | `decodeQrText`：图片字节 → 文本或 null |
| `lib/utils/server_scan_rules.dart` | 换服务器、手电筒、切换摄像头的判断 |
| `lib/utils/server_qr_image_pick.dart` | `pickServerQrImageBytes`，测试可替换 |
| `lib/widgets/server_scan_confirm_dialog.dart` | 唯一的确认框 |
| `lib/widgets/server_qr_scan_controls.dart` | 手电筒、切换、从图片识别三个按钮 |
| `lib/widgets/server_qr_scanner.dart` | 相机页：识别、确认、取消后继续扫 |
| `lib/widgets/settings/server_account_settings.dart` | 入口、写入地址、连接 |
| `lib/l10n/app_zh.arb` 及另外三份 | 文案。`@` 元数据只写在模板 `app_zh.arb` |
| `lib/l10n/generated/*` | `flutter gen-l10n` 生成，要提交 |
| `test/utils/qr_image_decode_test.dart` | 解码 |
| `test/utils/server_scan_rules_test.dart` | 三种确认文案的选择条件，以及按钮可见性 |
| `test/widgets/server_scan_confirm_dialog_test.dart` | 框里的句子 |
| `test/widgets/server_account_settings_test.dart` | 图片入口的取消、确认、不弹第二个框 |
| `test/widgets/server_qr_scan_controls_test.dart` | 按钮在不在 |

不改 `OpenLogToolServer`。`/connect` 页的二维码仍是浏览器当前地址。

## 已核实的事实

- `validatedServerConnectionInput` 在 `lib/utils/server_url.dart`。`/connect`、`/client/`、`/app`、`/admin` 会被去掉；带用户信息、非 http(s)、空主机返回 null。
- `_saveAndCheck` 在 `lib/widgets/settings/server_account_settings.dart`，已登录且地址不同时会再弹「切换服务器？」。扫码确认后必须跳过它。
- `ServerProvider` 在 `MaterialApp` 之上（`lib/main.dart` 的 `MultiProvider`）。扫码页里 `context.read<ServerProvider>()` 找得到。
- `mobile_scanner` 7.4 的 `analyzeImage` 不支持网页，Linux / Windows 没有该插件。图片解码不要用它。
- 网页相机仍用仓库里的 `web/vendor/zxing-0.23.0.min.js`。不要改成从 CDN 加载。
- `MobileScannerController.value.torchState` 与 `availableCameras` 是按钮的依据。网页的手电筒状态是 `TorchState.unavailable`。
- `ServerInfoDto` 在 `lib/models/collaboration_dto.dart`，六个字段都是 required。
- 四份 ARB 没有键一致性测试。漏一份不会被测试发现，每个文案任务都要人工对过四份。
- 测试机是 Linux 时，`defaultTargetPlatform` 默认就是 `TargetPlatform.linux`。涉及按钮的测试仍要显式设置 `debugDefaultTargetPlatformOverride`，并在 tearDown 里清掉。

## 不做

- 不自动登录。
- 不改粘贴和手输的现有确认。粘贴只填地址；手输后的「确认地址并连接」仍会在换服务器时弹出原来的框。
- 不在 widget 测试里打开 `MobileScanner`。相机插件在测试里没有平台实现。相机页的确认框与设置页共用同一个函数，设置页的图片入口把这条路径测完。

---

### Task 1: 从图片字节解出文本

**Files:**
- Create: `lib/utils/qr_image_decode.dart`
- Test: `test/utils/qr_image_decode_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: 加上依赖**

在 `pubspec.yaml` 的 `dependencies:` 里，紧挨 `file_picker` 增加：

```yaml
  image: ^4.5.4
  zxing2: ^0.2.4
```

Run: `flutter pub get`

Expected: 结束时没有错误，`pubspec.lock` 出现 `image` 和 `zxing2`。

- [ ] **Step 2: 写失败的测试**

创建 `test/utils/qr_image_decode_test.dart`：

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:openlogtool/utils/qr_image_decode.dart';
import 'package:openlogtool/utils/server_url.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  test('a connect QR normalizes to the server origin', () {
    final text = decodeQrText(_qrPng('https://server.example/connect'));
    expect(text, 'https://server.example/connect');
    expect(validatedServerConnectionInput(text!), 'https://server.example');
  });

  test('garbage and a picture without a QR return null', () {
    expect(decodeQrText(Uint8List.fromList(const [1, 2, 3, 4])), isNull);
    final blank = img.Image(width: 32, height: 32, numChannels: 4);
    img.fill(blank, color: img.ColorRgba8(255, 255, 255, 255));
    expect(decodeQrText(img.encodePng(blank)), isNull);
  });
}

Uint8List _qrPng(String text) {
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.medium).matrix!;
  const scale = 8;
  const quiet = 4;
  final modules = matrix.width + quiet * 2;
  final image = img.Image(
    width: modules * scale,
    height: modules * scale,
    numChannels: 4,
  );
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) != 1) continue;
      final left = (x + quiet) * scale;
      final top = (y + quiet) * scale;
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: left + scale,
        y2: top + scale,
        color: img.ColorRgba8(0, 0, 0, 255),
      );
    }
  }
  return img.encodePng(image);
}
```

- [ ] **Step 3: 跑测试，确认失败**

Run: `flutter test test/utils/qr_image_decode_test.dart`

Expected: 编译失败，找不到 `package:openlogtool/utils/qr_image_decode.dart`。

- [ ] **Step 4: 实现解码**

创建 `lib/utils/qr_image_decode.dart`：

```dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// The text inside a QR picture, or null when the bytes are not a readable QR.
String? decodeQrText(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  try {
    final rgba = decoded.convert(numChannels: 4);
    final raw = Uint8List.fromList(
      rgba.getBytes(order: img.ChannelOrder.abgr),
    );
    final result = QRCodeReader().decode(
      BinaryBitmap(
        HybridBinarizer(
          RGBLuminanceSource(
            rgba.width,
            rgba.height,
            raw.buffer.asInt32List(),
          ),
        ),
      ),
    );
    final text = result.text.trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}
```

这是 `zxing2` 文档里的解码方式，只把 binarizer 换成更适合照片二维码的 `HybridBinarizer`。解码在本机完成，字节不上传。

- [ ] **Step 5: 跑测试，确认通过**

Run: `flutter test test/utils/qr_image_decode_test.dart`

Expected: 两个测试都通过。若生成的二维码解不出来，只改 `decodeQrText` 里的 binarizer 为 `GlobalHistogramBinarizer`，再跑一次。不要改测试里的期望地址。

- [ ] **Step 6: 提交**

```bash
git add pubspec.yaml pubspec.lock lib/utils/qr_image_decode.dart test/utils/qr_image_decode_test.dart
git commit -m "feat: decode a server QR from image bytes"
```

---

### Task 2: 确认框选哪句、按钮出不出现

**Files:**
- Create: `lib/utils/server_scan_rules.dart`
- Test: `test/utils/server_scan_rules_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/utils/server_scan_rules_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/utils/server_scan_rules.dart';

void main() {
  test('only a signed-in user and a different server switches accounts', () {
    expect(
      serverScanSwitchesAccount(
        loggedIn: false,
        currentServerUrl: 'https://current.example',
        candidateUrl: 'https://other.example',
      ),
      isFalse,
    );
    expect(
      serverScanSwitchesAccount(
        loggedIn: true,
        currentServerUrl: 'https://server.example',
        candidateUrl: 'https://server.example/connect',
      ),
      isFalse,
    );
    expect(
      serverScanSwitchesAccount(
        loggedIn: true,
        currentServerUrl: 'https://current.example',
        candidateUrl: 'https://other.example/app/friends?x=1#tab',
      ),
      isTrue,
    );
  });

  test('torch and camera switch stay hidden unless the controller reports them',
      () {
    expect(
      serverScanTorchVisible(failed: false, torchAvailable: false),
      isFalse,
    );
    expect(
      serverScanTorchVisible(failed: true, torchAvailable: true),
      isFalse,
    );
    expect(
      serverScanTorchVisible(failed: false, torchAvailable: true),
      isTrue,
    );
    expect(serverScanSwitchVisible(failed: false, cameras: null), isFalse);
    expect(serverScanSwitchVisible(failed: false, cameras: 1), isFalse);
    expect(serverScanSwitchVisible(failed: true, cameras: 2), isFalse);
    expect(serverScanSwitchVisible(failed: false, cameras: 2), isTrue);
  });
}
```

同一台服务器的比较必须走 `validatedServerConnectionInput` 能接受的地址。`/connect` 与带查询参数的 `/app` 都要先整理再比，不能用字符串全等。

- [ ] **Step 2: 跑测试，确认失败**

Run: `flutter test test/utils/server_scan_rules_test.dart`

Expected: 编译失败，找不到 `server_scan_rules.dart`。

- [ ] **Step 3: 实现判断**

创建 `lib/utils/server_scan_rules.dart`：

```dart
import 'package:openlogtool/utils/server_url.dart';

bool serverScanSwitchesAccount({
  required bool loggedIn,
  required String currentServerUrl,
  required String candidateUrl,
}) {
  if (!loggedIn) return false;
  // normalizeServerUrl keeps /connect. Connection pages have to be stripped
  // first, or the same server looks like a switch.
  return serverUrlFromConnectionInput(candidateUrl) !=
      serverUrlFromConnectionInput(currentServerUrl);
}

bool serverScanTorchVisible({
  required bool failed,
  required bool torchAvailable,
}) =>
    !failed && torchAvailable;

bool serverScanSwitchVisible({
  required bool failed,
  required int? cameras,
}) =>
    !failed && cameras != null && cameras >= 2;
```

- [ ] **Step 4: 跑测试，确认通过**

Run: `flutter test test/utils/server_scan_rules_test.dart`

Expected: 两个测试都通过。

- [ ] **Step 5: 提交**

```bash
git add lib/utils/server_scan_rules.dart test/utils/server_scan_rules_test.dart
git commit -m "feat: decide when a scanned server switches accounts"
```

---

### Task 3: 四份文案

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_zh_CN.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_en_US.arb`
- Modify: `lib/l10n/generated/app_localizations.dart`
- Modify: `lib/l10n/generated/app_localizations_zh.dart`
- Modify: `lib/l10n/generated/app_localizations_en.dart`

- [ ] **Step 1: 写入四份 ARB**

在每份文件最后一个属性后面加逗号，再把键放进根对象、最终的 `}` 之前。`@` 元数据只加到 `app_zh.arb`。

`app_zh.arb` 与 `app_zh_CN.arb` 的字符串相同。`app_zh.arb` 还要带上下面的 `@` 块：

```json
"serverScanButton": "扫一扫",
"serverScanImageButton": "识别二维码图片",
"serverScanTitle": "扫描服务器二维码",
"serverScanHint": "识别到有效地址后会请你确认。确认后才连接，不会登录，也不会上传相机画面或图片。",
"serverScanCameraUnavailable": "无法使用相机。请检查相机权限；网页版需使用 HTTPS。你也可以返回粘贴连接地址。",
"serverScanInvalid": "这不是有效的服务器连接地址。请扫描服务器“连接这台服务器”页面的二维码。",
"serverScanImageInvalid": "图片里没有有效的服务器连接地址。",
"serverScanPickImage": "从图片识别",
"serverScanTorch": "手电筒",
"serverScanSwitchCamera": "切换摄像头",
"serverScanConfirmTitle": "连接到这台服务器？",
"serverScanConfirmCheck": "将检查 {address}。不会登录，也不会上传相机画面或图片。",
"@serverScanConfirmCheck": {
  "placeholders": {
    "address": {"type": "String"}
  }
},
"serverScanConfirmSwitch": "将连接到 {address}。当前账号会退出，原登录凭据不会发到新地址；本机记录保留。",
"@serverScanConfirmSwitch": {
  "placeholders": {
    "address": {"type": "String"}
  }
}
```

`app_en.arb` 与 `app_en_US.arb` 只写字符串，不写 `@`：

```json
"serverScanButton": "Scan QR",
"serverScanImageButton": "Scan a QR image",
"serverScanTitle": "Scan server QR code",
"serverScanHint": "A valid address asks for confirmation before connecting. This does not sign in, and it does not upload the camera or the picture.",
"serverScanCameraUnavailable": "Camera unavailable. Check camera permission and use HTTPS on the web, or go back and paste a connection address.",
"serverScanInvalid": "This is not a valid server address. Scan the QR code on the server connection page.",
"serverScanImageInvalid": "This picture does not contain a valid server address.",
"serverScanPickImage": "Scan an image",
"serverScanTorch": "Torch",
"serverScanSwitchCamera": "Switch camera",
"serverScanConfirmTitle": "Connect to this server?",
"serverScanConfirmCheck": "This will check {address}. It will not sign in, and it will not upload the camera or the picture.",
"serverScanConfirmSwitch": "Connect to {address}. The current account will be signed out. Its credentials will not be sent to the new server; local records are kept."
```

- [ ] **Step 2: 生成并核对四份都有这些键**

Run:

```bash
flutter gen-l10n
rg -l "serverScanConfirmSwitch" lib/l10n
```

Expected: `flutter gen-l10n` 成功。`rg` 列出四份 ARB，以及 `app_localizations.dart`、`app_localizations_zh.dart`、`app_localizations_en.dart`。少一份就补上再生成，不要只改生成文件。

- [ ] **Step 3: 提交**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_zh_CN.arb lib/l10n/app_en.arb lib/l10n/app_en_US.arb lib/l10n/generated
git commit -m "feat: add copy for confirming a scanned server"
```

---

### Task 4: 确认框只说一种情况

**Files:**
- Create: `lib/widgets/server_scan_confirm_dialog.dart`
- Test: `test/widgets/server_scan_confirm_dialog_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/widgets/server_scan_confirm_dialog_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/widgets/server_scan_confirm_dialog.dart';

void main() {
  testWidgets('signed out and the same server use the check copy',
      (tester) async {
    await _open(
      tester,
      loggedIn: false,
      currentServerUrl: '',
      candidateUrl: 'https://server.example',
    );
    expect(find.text('连接到这台服务器？'), findsOneWidget);
    expect(find.textContaining('将检查 https://server.example'), findsOneWidget);
    expect(find.textContaining('不会登录'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsNothing);
  });

  testWidgets('the same signed-in server still uses the check copy',
      (tester) async {
    await _open(
      tester,
      loggedIn: true,
      currentServerUrl: 'https://server.example',
      candidateUrl: 'https://server.example',
    );
    expect(find.textContaining('不会登录'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsNothing);
  });

  testWidgets('a different signed-in server uses the switch copy only',
      (tester) async {
    await _open(
      tester,
      loggedIn: true,
      currentServerUrl: 'https://current.example',
      candidateUrl: 'https://other.example',
    );
    expect(find.textContaining('将连接到 https://other.example'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsOneWidget);
    expect(find.textContaining('不会登录'), findsNothing);
    expect(find.text('切换服务器？'), findsNothing);
  });
}

Future<void> _open(
  WidgetTester tester, {
  required bool loggedIn,
  required String currentServerUrl,
  required String candidateUrl,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmScannedServerAddress(
              context,
              loggedIn: loggedIn,
              currentServerUrl: currentServerUrl,
              candidateUrl: candidateUrl,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `flutter test test/widgets/server_scan_confirm_dialog_test.dart`

Expected: 编译失败，找不到 `server_scan_confirm_dialog.dart`。

- [ ] **Step 3: 实现确认框**

创建 `lib/widgets/server_scan_confirm_dialog.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/utils/server_scan_rules.dart';

Future<bool> confirmScannedServerAddress(
  BuildContext context, {
  required bool loggedIn,
  required String currentServerUrl,
  required String candidateUrl,
}) async {
  final l10n = context.l10n;
  final switching = serverScanSwitchesAccount(
    loggedIn: loggedIn,
    currentServerUrl: currentServerUrl,
    candidateUrl: candidateUrl,
  );
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.serverScanConfirmTitle),
      content: Text(
        switching
            ? l10n.serverScanConfirmSwitch(candidateUrl)
            : l10n.serverScanConfirmCheck(candidateUrl),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('server-scan-confirm-button'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
  return confirmed == true;
}
```

框里的地址必须是调用方已经整理过的地址。这个函数不再整理，也不连接。

- [ ] **Step 4: 跑测试，确认通过**

Run: `flutter test test/widgets/server_scan_confirm_dialog_test.dart`

Expected: 三个测试都通过。

- [ ] **Step 5: 提交**

```bash
git add lib/widgets/server_scan_confirm_dialog.dart test/widgets/server_scan_confirm_dialog_test.dart
git commit -m "feat: confirm a scanned server in one dialog"
```

---

### Task 5: Linux 与 Windows 从图片确认后连接

**Files:**
- Create: `lib/utils/server_qr_image_pick.dart`
- Modify: `lib/widgets/settings/server_account_settings.dart`
- Test: `test/widgets/server_account_settings_test.dart`

- [ ] **Step 1: 在现有测试文件末尾加入图片入口测试**

`test/widgets/server_account_settings_test.dart` 增加这些 import：

```dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/utils/server_qr_image_pick.dart';
import 'package:openlogtool/widgets/server_qr_scanner.dart';
import 'package:zxing2/qrcode.dart';
```

图片字节由 `_qrPng` 生成。把 Task 1 测试文件里的 `_qrPng` 原样复制到这个测试文件底部，名字保持 `_qrPng`。不要把解码器的测试 helper 抽成公共库。

在 `void main()` 的最后一个测试之后、文件里第一个辅助类之前，加入：

```dart
  testWidgets('linux and windows scan an image and do not create a camera',
      (tester) async {
    final originalCamera = createServerQrCameraController;
    addTearDown(() => createServerQrCameraController = originalCamera);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      debugDefaultTargetPlatformOverride = platform;
      var cameras = 0;
      createServerQrCameraController = () {
        cameras++;
        return originalCamera();
      };
      final previousPick = pickServerQrImageBytes;
      pickServerQrImageBytes = () async => null;
      final server = _ScanSettingsServer(
        'https://current.example',
        loggedIn: true,
      );
      addTearDown(server.dispose);
      await tester.pumpWidget(_ScanSettingsApp(provider: server));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('server-scan-button')), findsNothing);
      expect(find.byKey(const Key('server-image-scan-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('server-image-scan-button')));
      await tester.pumpAndSettle();
      expect(cameras, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(server.checked, isEmpty);
      pickServerQrImageBytes = previousPick;
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('canceling an image scan leaves the signed-in server untouched',
      (tester) async {
    final server = await _pumpImageScan(
      tester,
      server: _ScanSettingsServer('https://current.example', loggedIn: true),
      bytes: _qrPng('https://other.example/connect'),
    );
    expect(find.textContaining('当前账号会退出'), findsOneWidget);
    expect(find.text('切换服务器？'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(server.checked, isEmpty);
    expect(_serverFieldText(tester), 'https://current.example');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirming a different server checks it without a second dialog',
      (tester) async {
    final server = await _pumpImageScan(
      tester,
      server: _ScanSettingsServer('https://current.example', loggedIn: true),
      bytes: _qrPng('https://other.example/app/friends?x=1#tab'),
    );
    expect(find.textContaining('https://other.example'), findsOneWidget);
    expect(find.textContaining('x=1'), findsNothing);
    expect(find.text('切换服务器？'), findsNothing);
    await tester.tap(find.byKey(const Key('server-scan-confirm-button')));
    await tester.pumpAndSettle();
    expect(find.text('切换服务器？'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(server.checked, ['https://other.example']);
    expect(_serverFieldText(tester), 'https://other.example');
  });

  testWidgets('the same server and a signed-out server use the check copy',
      (tester) async {
    final same = await _pumpImageScan(
      tester,
      server: _ScanSettingsServer('https://server.example', loggedIn: true),
      bytes: _qrPng('https://server.example/connect'),
    );
    expect(find.textContaining('不会登录'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsNothing);
    await tester.tap(find.byKey(const Key('server-scan-confirm-button')));
    await tester.pumpAndSettle();
    expect(same.checked, ['https://server.example']);

    final signedOut = await _pumpImageScan(
      tester,
      server: _ScanSettingsServer('', loggedIn: false),
      bytes: _qrPng('https://server.example/client/'),
    );
    expect(find.textContaining('不会登录'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(signedOut.checked, isEmpty);
    expect(_serverFieldText(tester), isEmpty);
  });

  testWidgets('an invalid picture or a dismissed picker does not connect',
      (tester) async {
    final server = await _pumpImageScan(
      tester,
      server: _ScanSettingsServer('https://current.example', loggedIn: true),
      bytes: Uint8List.fromList(const [1, 2, 3, 4]),
    );
    expect(find.text('图片里没有有效的服务器连接地址。'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(server.checked, isEmpty);
    expect(_serverFieldText(tester), 'https://current.example');

    pickServerQrImageBytes = () async => null;
    await tester.tap(find.byKey(const Key('server-image-scan-button')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(server.checked, isEmpty);
  });

  testWidgets('a credential QR is rejected without connecting', (tester) async {
    final server = await _pumpImageScan(
      tester,
      server: _ScanSettingsServer('https://current.example', loggedIn: true),
      bytes: _qrPng('https://user:pass@server.example/connect'),
    );
    expect(find.text('图片里没有有效的服务器连接地址。'), findsOneWidget);
    expect(find.textContaining('user:pass'), findsNothing);
    expect(server.checked, isEmpty);
  });

  testWidgets('paste still only fills the field', (tester) async {
    final server = _ScanSettingsServer('https://current.example', loggedIn: true);
    addTearDown(server.dispose);
    await tester.pumpWidget(_ScanSettingsApp(provider: server));
    await tester.pumpAndSettle();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': 'https://pasted.example/connect'};
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ));
    await tester.tap(find.byKey(const Key('server-paste-button')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(_serverFieldText(tester), 'https://pasted.example');
    expect(server.checked, isEmpty);
  });

  testWidgets('typing a new address still asks with the old switch dialog',
      (tester) async {
    final server = _ScanSettingsServer('https://current.example', loggedIn: true);
    addTearDown(server.dispose);
    await tester.pumpWidget(_ScanSettingsApp(provider: server));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('server-url-field')),
      'https://typed.example',
    );
    await tester.tap(find.byKey(const Key('server-check-button')));
    await tester.pumpAndSettle();
    expect(find.text('切换服务器？'), findsOneWidget);
    expect(find.text('连接到这台服务器？'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(server.checked, isEmpty);
  });
```

在文件底部、现有辅助函数旁边加上：

```dart
class _ScanSettingsServer extends _AuthTestServer {
  _ScanSettingsServer(this.url, {required this.loggedIn});
  String url;
  final bool loggedIn;
  final checked = <String>[];

  @override
  String get serverUrl => url;

  @override
  bool get isLoggedIn => loggedIn;

  @override
  Future<ServerInfoDto> saveAndCheckServerUrl(String candidate) async {
    checked.add(candidate);
    url = candidate;
    notifyListeners();
    return ServerInfoDto(
      serverInstanceId: 'instance',
      protocolMin: 1,
      protocolMax: 1,
      features: const [],
      serverTime: DateTime.utc(2026, 10, 16),
      environment: 'test',
    );
  }
}

class _ScanSettingsApp extends StatelessWidget {
  const _ScanSettingsApp({required this.provider});
  final ServerProvider provider;

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<ServerProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServerAccountSettings(cardPadding: 16),
            ),
          ),
        ),
      );
}

Future<_ScanSettingsServer> _pumpImageScan(
  WidgetTester tester, {
  required _ScanSettingsServer server,
  required Uint8List bytes,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  final previousPick = pickServerQrImageBytes;
  pickServerQrImageBytes = () async => bytes;
  addTearDown(() => pickServerQrImageBytes = previousPick);
  addTearDown(server.dispose);
  await tester.pumpWidget(_ScanSettingsApp(provider: server));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('server-image-scan-button')));
  await tester.tap(find.byKey(const Key('server-image-scan-button')));
  await tester.pumpAndSettle();
  return server;
}

String _serverFieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('server-url-field')))
        .controller!
        .text;
```

`_pumpImageScan` 每次都会 `pumpWidget` 一棵新树。同一个测试里调用两次时，第二次会换掉上一棵。这是故意的。

- [ ] **Step 2: 跑测试，确认失败**

Run: `flutter test test/widgets/server_account_settings_test.dart`

Expected: 新测试编译失败或断言失败。现有测试仍应通过；若现有测试因为新按钮溢出而失败，先不要改那些测试的断言，把入口放进已有的 `Wrap`。

- [ ] **Step 3: 图片选择函数**

创建 `lib/utils/server_qr_image_pick.dart`：

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

typedef ServerQrImagePicker = Future<Uint8List?> Function();

ServerQrImagePicker pickServerQrImageBytes = _pickServerQrImageBytes;

Future<Uint8List?> _pickServerQrImageBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.single.bytes;
}
```

用户关掉选择器时返回 null。没有字节的文件也返回 null，调用方什么都不做。

- [ ] **Step 4: 先放上相机制造函数，再接设置页**

Task 5 的测试要计数 `createServerQrCameraController`。在替换整个扫码页之前，先把下面两段加进现有的 `lib/widgets/server_qr_scanner.dart`，放在 `serverCameraScanSupported` 后面。现有的 `ServerQrScanner` 先不要改行为。

```dart
MobileScannerController Function() createServerQrCameraController =
    _defaultServerQrCameraController;

MobileScannerController _defaultServerQrCameraController() =>
    MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
```

`server_account_settings.dart` 增加 import：

```dart
import 'package:openlogtool/utils/qr_image_decode.dart';
import 'package:openlogtool/utils/server_qr_image_pick.dart';
import 'package:openlogtool/widgets/server_scan_confirm_dialog.dart';
```

`dart:typed_data` 不需要单独 import，`qr_image_decode.dart` 的公开函数只接收 `Uint8List`，本文件不写那个类型。

把扫码按钮那段换成：

```dart
                if (serverCameraScanSupported)
                  OutlinedButton.icon(
                    key: const Key('server-scan-button'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l10n.serverScanButton),
                    onPressed: server.isBusy
                        ? null
                        : () async {
                            final result = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ServerQrScanner(),
                              ),
                            );
                            if (!mounted || result == null) return;
                            setState(() {
                              _serverUrlController.text = result;
                              _urlEdited = true;
                            });
                            await _saveAndCheck(
                              server,
                              skipSwitchConfirm: true,
                            );
                          },
                  )
                else
                  OutlinedButton.icon(
                    key: const Key('server-image-scan-button'),
                    icon: const Icon(Icons.image_search_outlined),
                    label: Text(l10n.serverScanImageButton),
                    onPressed: server.isBusy
                        ? null
                        : () => _scanServerImage(server),
                  ),
```

粘贴按钮的 `onPressed` 不要改。

把 `_saveAndCheck` 的签名和换服务器条件改成：

```dart
  Future<void> _saveAndCheck(
    ServerProvider server, {
    bool skipSwitchConfirm = false,
  }) async {
    final candidateUrl =
        validatedServerConnectionInput(_serverUrlController.text);
    if (candidateUrl == null) {
      context.showLoggedSnackBar(SnackBar(
          content: Text(Localizations.localeOf(context).languageCode == 'zh'
              ? '请输入完整的 HTTP 或 HTTPS 服务器地址，不要包含账号密码。'
              : 'Enter a full HTTP(S) server address without credentials.')));
      return;
    }
    if (!skipSwitchConfirm &&
        server.isLoggedIn &&
        normalizeServerUrl(candidateUrl) !=
            normalizeServerUrl(server.serverUrl)) {
```

条件后面的对话框和 `saveAndCheckServerUrl` 调用保持原样。

在 `_saveAndCheck` 前面增加：

```dart
  Future<void> _scanServerImage(ServerProvider server) async {
    final bytes = await pickServerQrImageBytes();
    if (!mounted || bytes == null) return;
    final candidate = validatedServerConnectionInput(decodeQrText(bytes) ?? '');
    if (candidate == null) {
      context.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.serverScanImageInvalid)),
      );
      return;
    }
    final confirmed = await confirmScannedServerAddress(
      context,
      loggedIn: server.isLoggedIn,
      currentServerUrl: server.serverUrl,
      candidateUrl: candidate,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _serverUrlController.text = candidate;
      _urlEdited = true;
    });
    await _saveAndCheck(server, skipSwitchConfirm: true);
  }
```

相机按钮这次先把返回值直接拿去连接。Task 6 才让扫码页在弹出之前自己确认。在那之前，相机按钮仍会连接，但桌面测试不点它。

- [ ] **Step 5: 跑测试，确认通过**

Run: `flutter test test/widgets/server_account_settings_test.dart test/utils/server_scan_rules_test.dart`

Expected: 全部通过。`debugDefaultTargetPlatformOverride` 若在测试结束时仍非 null，Flutter 会直接失败；每个测试的 tearDown 必须清掉。

- [ ] **Step 6: 提交**

```bash
git add lib/utils/server_qr_image_pick.dart lib/widgets/settings/server_account_settings.dart test/widgets/server_account_settings_test.dart
git commit -m "feat: connect from a QR image after confirmation"
```

---

### Task 6: 相机页的按钮和确认

**Files:**
- Create: `lib/widgets/server_qr_scan_controls.dart`
- Modify: `lib/widgets/server_qr_scanner.dart`
- Test: `test/widgets/server_qr_scan_controls_test.dart`

- [ ] **Step 1: 写按钮测试**

创建 `test/widgets/server_qr_scan_controls_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/widgets/server_qr_scan_controls.dart';

void main() {
  testWidgets('unsupported torch and camera switch take no space',
      (tester) async {
    await _pump(tester, torch: false, switchCamera: false);
    expect(find.byKey(const Key('server-scan-torch')), findsNothing);
    expect(find.byKey(const Key('server-scan-switch-camera')), findsNothing);
    expect(find.byKey(const Key('server-scan-image')), findsOneWidget);
  });

  testWidgets('available torch and camera switch are shown', (tester) async {
    var torch = 0;
    var switched = 0;
    var images = 0;
    await _pump(
      tester,
      torch: true,
      switchCamera: true,
      onTorch: () => torch++,
      onSwitchCamera: () => switched++,
      onPickImage: () => images++,
    );
    await tester.tap(find.byKey(const Key('server-scan-torch')));
    await tester.tap(find.byKey(const Key('server-scan-switch-camera')));
    await tester.tap(find.byKey(const Key('server-scan-image')));
    expect(torch, 1);
    expect(switched, 1);
    expect(images, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool torch,
  required bool switchCamera,
  VoidCallback? onTorch,
  VoidCallback? onSwitchCamera,
  VoidCallback? onPickImage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ServerQrScanControls(
          torchVisible: torch,
          switchVisible: switchCamera,
          onTorch: onTorch ?? () {},
          onSwitchCamera: onSwitchCamera ?? () {},
          onPickImage: onPickImage ?? () {},
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `flutter test test/widgets/server_qr_scan_controls_test.dart`

Expected: 编译失败，找不到 `server_qr_scan_controls.dart`。

- [ ] **Step 3: 实现按钮行**

创建 `lib/widgets/server_qr_scan_controls.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';

class ServerQrScanControls extends StatelessWidget {
  const ServerQrScanControls({
    required this.torchVisible,
    required this.switchVisible,
    required this.onTorch,
    required this.onSwitchCamera,
    required this.onPickImage,
    super.key,
  });

  final bool torchVisible;
  final bool switchVisible;
  final VoidCallback onTorch;
  final VoidCallback onSwitchCamera;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (torchVisible)
            OutlinedButton.icon(
              key: const Key('server-scan-torch'),
              onPressed: onTorch,
              icon: const Icon(Icons.flashlight_on_outlined),
              label: Text(l10n.serverScanTorch),
            ),
          if (switchVisible)
            OutlinedButton.icon(
              key: const Key('server-scan-switch-camera'),
              onPressed: onSwitchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
              label: Text(l10n.serverScanSwitchCamera),
            ),
          OutlinedButton.icon(
            key: const Key('server-scan-image'),
            onPressed: onPickImage,
            icon: const Icon(Icons.image_search_outlined),
            label: Text(l10n.serverScanPickImage),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 换掉扫码页**

用下面的文件完整替换 `lib/widgets/server_qr_scanner.dart`：

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/utils/qr_image_decode.dart';
import 'package:openlogtool/utils/server_qr_image_pick.dart';
import 'package:openlogtool/utils/server_scan_rules.dart';
import 'package:openlogtool/utils/server_url.dart';
import 'package:openlogtool/widgets/server_qr_scan_controls.dart';
import 'package:openlogtool/widgets/server_scan_confirm_dialog.dart';
import 'package:provider/provider.dart';

bool get serverCameraScanSupported =>
    kIsWeb ||
    const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

MobileScannerController Function() createServerQrCameraController =
    _defaultServerQrCameraController;

MobileScannerController _defaultServerQrCameraController() =>
    MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );

class ServerQrScanner extends StatefulWidget {
  const ServerQrScanner({super.key});

  @override
  State<ServerQrScanner> createState() => _ServerQrScannerState();
}

class _ServerQrScannerState extends State<ServerQrScanner> {
  late final MobileScannerController _controller;
  bool _offering = false;
  bool _invalid = false;
  bool _torchFailed = false;
  bool _switchFailed = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      MobileScannerPlatform.instance
          .setWebBarcodeReader(WebBarcodeReader.zxingJs);
      MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
        Uri.base.resolve('vendor/zxing-0.23.0.min.js').toString(),
      );
    }
    _controller = createServerQrCameraController();
    _controller.addListener(_onController);
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (!mounted || _offering) return;
    String? candidate;
    var sawInvalid = false;
    for (final code in capture.barcodes) {
      final parsed = validatedServerConnectionInput(code.rawValue ?? '');
      if (parsed == null) {
        sawInvalid = true;
        continue;
      }
      candidate = parsed;
      break;
    }
    if (candidate == null) {
      if (sawInvalid && mounted) setState(() => _invalid = true);
      return;
    }
    await _offer(candidate);
  }

  Future<void> _pickImage() async {
    if (_offering) return;
    final bytes = await pickServerQrImageBytes();
    if (!mounted || bytes == null) return;
    final candidate = validatedServerConnectionInput(decodeQrText(bytes) ?? '');
    if (candidate == null) {
      setState(() => _invalid = true);
      return;
    }
    await _offer(candidate);
  }

  Future<void> _offer(String candidate) async {
    if (!mounted || _offering) return;
    setState(() {
      _offering = true;
      _invalid = false;
    });
    try {
      await _controller.stop();
    } catch (_) {}
    if (!mounted) return;
    final server = context.read<ServerProvider>();
    final confirmed = await confirmScannedServerAddress(
      context,
      loggedIn: server.isLoggedIn,
      currentServerUrl: server.serverUrl,
      candidateUrl: candidate,
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _offering = false);
      try {
        await _controller.start();
      } catch (_) {}
      return;
    }
    Navigator.pop(context, candidate);
  }

  Future<void> _torch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) setState(() => _torchFailed = true);
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {
      if (mounted) setState(() => _switchFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = _controller.value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverScanTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.serverScanHint),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _detected,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.serverScanCameraUnavailable),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_invalid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.serverScanInvalid),
            ),
          ServerQrScanControls(
            torchVisible: serverScanTorchVisible(
              failed: _torchFailed,
              torchAvailable: state.torchState != TorchState.unavailable,
            ),
            switchVisible: serverScanSwitchVisible(
              failed: _switchFailed,
              cameras: state.availableCameras,
            ),
            onTorch: () => unawaited(_torch()),
            onSwitchCamera: () => unawaited(_switchCamera()),
            onPickImage: () => unawaited(_pickImage()),
          ),
        ],
      ),
    );
  }
}
```

`DetectionSpeed.normal` 是故意的。取消确认后，同一张二维码还停在画面里，也要能再次弹出确认框。`_offering` 保证框还开着时不会叠第二个。

有效码先把 `_invalid` 清掉，再弹框。图片选择器返回 null 时不改 `_invalid`。

- [ ] **Step 5: 跑测试**

Run:

```bash
flutter test test/widgets/server_qr_scan_controls_test.dart test/widgets/server_account_settings_test.dart test/utils/qr_image_decode_test.dart test/utils/server_scan_rules_test.dart test/widgets/server_scan_confirm_dialog_test.dart
```

Expected: 全部通过。不要新写一个会 `pumpWidget(ServerQrScanner)` 的测试，相机会在测试里初始化失败。

- [ ] **Step 6: 提交**

```bash
git add lib/widgets/server_qr_scan_controls.dart lib/widgets/server_qr_scanner.dart test/widgets/server_qr_scan_controls_test.dart
git commit -m "feat: confirm a camera scan before connecting"
```

---

### Task 7: 手册与规格状态

**Files:**
- Modify: `docs/user-guide.md`
- Modify: `site/docs.html`
- Modify: `docs/superpowers/specs/2026-10-16-scan-server-qr-design.md`

- [ ] **Step 1: 改使用说明**

`docs/user-guide.md` 里「服务器与账户」那一条，在「链接里没有密码。」后面加上：

```markdown
手机、macOS 和网页可以扫描服务器连接页的二维码；Linux 和 Windows 改为从图片识别。识别到地址后会先确认，确认后才检查服务器，不会登录。
```

`site/docs.html` 里同一段 `<dt>服务器与账户</dt>` 的 `<dd>`，在「链接里没有密码。」后面加上同一句，不加 Markdown。

规格文件开头的 `> 状态：待实施` 改为 `> 状态：已实现`。

- [ ] **Step 2: 分析改过的 Dart**

Run:

```bash
flutter analyze lib/utils/qr_image_decode.dart lib/utils/server_scan_rules.dart lib/utils/server_qr_image_pick.dart lib/widgets/server_scan_confirm_dialog.dart lib/widgets/server_qr_scan_controls.dart lib/widgets/server_qr_scanner.dart lib/widgets/settings/server_account_settings.dart test/utils/qr_image_decode_test.dart test/utils/server_scan_rules_test.dart test/widgets/server_scan_confirm_dialog_test.dart test/widgets/server_qr_scan_controls_test.dart test/widgets/server_account_settings_test.dart
```

Expected: `No issues found`。有问题就改实现，不要用 `ignore` 压掉。

- [ ] **Step 3: 再跑一遍相关测试**

Run:

```bash
flutter test test/utils/qr_image_decode_test.dart test/utils/server_scan_rules_test.dart test/widgets/server_scan_confirm_dialog_test.dart test/widgets/server_qr_scan_controls_test.dart test/widgets/server_account_settings_test.dart test/utils/server_connection_link_test.dart
```

Expected: 全部通过。

- [ ] **Step 4: 提交**

```bash
git add docs/user-guide.md site/docs.html docs/superpowers/specs/2026-10-16-scan-server-qr-design.md
git commit -m "docs: describe confirming a scanned server"
```

不要把 `server.log` 加进去。不要 push。
