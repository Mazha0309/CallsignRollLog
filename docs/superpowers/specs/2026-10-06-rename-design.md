# 更名设计：OpenLogTool → Callsign Roll Log

日期：2026-10-06
状态：待实施

## 1. 决定

| 用途 | 采用 |
|---|---|
| 全名 | **Callsign Roll Log** |
| 字标 / 圈内标记 | **CRL** |
| 中文副标 | **呼号点名日志** |
| 短名 / 域名 / 仓库 | **CallsignRoll** |

命名规则：任何出现处**成对书写** `CRL · Callsign Roll Log`，不要单独使用 `CRL` 作为检索名——`CRL` 在技术语境几乎等同于「证书吊销列表」，单独使用会被检索淹没。字标 `CRL` 可以单独出现在 logo/角标位置。

## 2. 范围

只改**人眼可见的字符串**，所有机器标识符保持不变。这样老用户升级无感，**零迁移**。

### 2.1 要改

| 位置 | 现值 | 新值 |
|---|---|---|
| `android/app/src/main/AndroidManifest.xml` | `android:label="OpenLogTool"` | `Callsign Roll Log` |
| `ios/Runner/Info.plist` | `CFBundleDisplayName=Openlogtool`、`CFBundleName=openlogtool` | `CallsignRoll` |
| `macos/Runner/Info.plist` | `CFBundleDisplayName` | `CallsignRoll` |
| `windows/runner/Runner.rc` | `FileDescription`/`ProductName="OpenLogTool"` | `Callsign Roll Log` |
| `windows/runner/main.cpp` | `window.Create(L"OpenLogTool", …)` | `L"Callsign Roll Log"` |
| `linux/runner/my_application.cc` | `gtk_header_bar_set_title` / `gtk_window_set_title("OpenLogTool")` | `Callsign Roll Log` |
| `linux/runner/openlogtool.desktop` | `Name=OpenLogTool` | `Callsign Roll Log` |
| `lib/main.dart` | `MaterialApp(title: 'OpenLogTool')` | `Callsign Roll Log` |
| `lib/l10n/app_zh.arb` / `app_en.arb`（及生成物） | `aboutAppTitle`、`aboutAppDescription`、`aboutLicenseHint`、`controllerScreenTitle`、`controllerFloatingWindowTitle`、`fontPreviewSample`、`serverInvalidResponse`、`databaseExportDialogTitle` 等 | 换用新名/新副标 |
| `README.md`、`docs/`、`web/update.html` | `OpenLogTool` | `Callsign Roll Log` |
| 发布产物名 | `OpenLogTool-<ver>-<sha>.<build>-*` | `CallsignRoll-<ver>-<sha>.<build>-*` |

已核实：`web/update.js` 只引用 Rust WASM 的 `pkg/openlogtool_core.*`，**与产物名无关**，改产物名不影响网页更新器。

### 2.2 不改（机器标识）

- Dart 包名 `openlogtool`（`package:openlogtool/...` 导入不变）
- Android `applicationId` / `namespace` = `com.mazha0309.openlogtool`
- iOS/macOS `PRODUCT_BUNDLE_IDENTIFIER` = `com.mazha0309.openlogtool`
- Linux `APPLICATION_ID` = `com.mazha0309.openlogtool`
- Windows `BINARY_NAME` = `openlogtool`
- 数据目录、存储 key（`openlogtool.kv.*`）、数据库 `openlogtool_rust.db`、崩溃目录 `%LOCALAPPDATA%\OpenLogTool\CrashDumps`、`$XDG_DATA_HOME/openlogtool/crashes`
- Rust crate `openlogtool_core`（改它会动 WASM 的 `pkg/` 路径）
- 服务端项目 `openlogtool-server` 与 Docker 镜像名
- macOS `PRODUCT_NAME = openlogtool`（决定 `.app` 文件名，CI 打包路径依赖它）

## 3. 非目标

- 不改任何会让老用户"变成新 App"或丢数据的标识符。
- 本次不注册新域名、不改 GitHub 仓库名。
- 不做品牌视觉重设计（官网另行处理）。

### 3.1 官网落点

官网使用现有主域的子域 **`crl.mazha0309.com`**，不额外购买域名。使用约定：

- 该子域是**短链/入口**，不是品牌本身；页面上第一眼必须是 `CRL · Callsign Roll Log · 呼号点名日志` 的完整写法。
- 任何地方不要只写 `CRL` 或只写裸域名当作产品名（`CRL` 在技术语境近似「证书吊销列表」，且裸子域把品牌绑在个人域名上）。
- 站点为纯静态、零构建，可部署到 Cloudflare Pages / Vercel / GitHub Pages 任一，再绑定该子域。

## 4. 风险与注意

- **升级路径**：由于标识符全留，覆盖安装即可，无需迁移逻辑。
- **历史 release**：旧产物仍以 `OpenLogTool-*` 命名并继续可下载，文档中旧链接不失效。
- **产物名变更**：需要同步 CI 与打包脚本中的名称拼装（`tool/package_windows.ps1`、`.github/workflows/build.yml` 的 artifact 名）。
- **一致性检查**：`aboutCopyright` 已含 `BG5CRL`，与新命名的出处故事一致，保留。

## 5. 验收

1. `flutter analyze` 无问题，`flutter test` 全通过。
2. 四端构建后：启动器名 / 窗口标题 / 关于页显示为新名，且包标识符仍为 `com.mazha0309.openlogtool`。
3. 新一次发版的产物名为 `CallsignRoll-<版本>-*`。
4. 旧版本覆盖安装后，本机记录、设置、词库、协作绑定均保留。
