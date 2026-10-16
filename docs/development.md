# Callsign Roll Log 开发指南

这份文档说明代码放在哪、改一处功能要动哪些文件、提交前跑什么。环境版本、各平台构建命令和 WebClient 部署仍以仓库 [README](../README.md) 为准，这里不复制一遍。

使用方式见 [使用手册](user-guide.md)。语音接口的配置项见 [AI 语音识别配置指南](ai-speech-recognition.md)。

`docs/superpowers/` 里是某次功能的设计稿和施工计划，不是现行行为的说明书。和代码不一致时，以代码和测试为准。

## 仓库地图

| 路径 | 是什么 |
| --- | --- |
| `lib/` | Flutter 界面、状态和网络。用户能点到的行为大多从这里进。 |
| `lib/screens/` | 四个主页面：点名台所在的 `home_screen.dart`、会话、数据、协作相关页。 |
| `lib/widgets/` | 表单、表格、设置、共享对话框。 |
| `lib/providers/` | 屏幕之间共享的状态。 |
| `lib/services/` | 导出、同步、日志、服务器 API、AI。 |
| `lib/l10n/` | 文案。`generated/` 不要手改。 |
| `rust/` | 本机数据库、迁移、词库搜索、协作副本。Flutter 和 Web 用的是同一套。 |
| `rust/src/api/` | 暴露给 Dart 的数据接口。 |
| `test/` | `flutter test` 用的测试，目录大致对应 `lib/`。 |
| `tool/` | 版本号、Web 构建、Windows 打包。 |
| `site/` | 产品主页，不是应用本身。 |
| `web/` | Flutter Web 外壳。业务不写在这里。 |

应用名在界面上是 Callsign Roll Log。仓库目录、Dart 包名 `openlogtool`、数据库文件名和环境变量前缀都还是旧标识，改显示名时不要顺手改这些。

## 数据怎么走

界面不直接写 SQLite。

1. Widget 调用 Provider。
2. Provider 调用 `lib/src/bridge` 里生成的 Rust API，或在登录后调用 `lib/services/server_api.dart`。
3. Rust 在 `init_database` 里打开库并跑 `rust/src/db/migrations.rs`。
4. 桌面和手机的库文件是应用支持目录下的 `openlogtool_rust.db`。Web 使用同一文件名，由浏览器持久化，按站点来源隔离。

改了 `rust/src/api` 里对 Dart 可见的函数之后，运行：

```bash
flutter_rust_bridge_codegen generate
```

不要手改 `rust/src/frb_generated.rs` 和 `lib/src/bridge` 里的生成文件。代码生成器版本固定为 2.12.0，和 README、CI 一致。Web 构建走 `bash tool/build_web.sh`，它会调用 `flutter_rust_bridge_codegen build-web`。

## 改哪里

| 想改的行为 | 先打开 |
| --- | --- |
| 点名表单、联想、一键复用 | `lib/widgets/log_form.dart`、`lib/widgets/callsign_history_field.dart` |
| 记录表 | `lib/widgets/log_table.dart`、`lib/providers/log_provider.dart` |
| 会话列表和结束/恢复 | `lib/screens/session_hub_page.dart`、`lib/providers/session_provider.dart` |
| 词库管理和搜索 | `lib/widgets/dictionary_manager.dart`、`rust/src/api/dictionaries.rs`、`rust/src/dict/` |
| 本机记录的增删改 | `rust/src/api/logs.rs`、`rust/src/db/logs.rs` |
| 导入导出 | `lib/widgets/export_panel.dart`、`lib/services/export_service.dart`、`lib/services/excel_import_service.dart` |
| 整库备份 | `lib/widgets/local_database_panel.dart`、`rust/src/api/database.rs` |
| 个人云 | `lib/providers/personal_cloud_provider.dart`、`rust/src/api/personal_cloud.rs`、`personal_dictionary.rs` |
| 协作同步、冲突、草稿 | `lib/services/collaboration_*.dart`、`lib/providers/collaboration_provider.dart` |
| 好友和通知 | `lib/screens/social_screen.dart`、`lib/services/social_realtime.dart` |
| 账号会话共享、共享词库 | `lib/providers/account_share_provider.dart`、`lib/widgets/session_sharing_dialog.dart`、`lib/models/shared_dictionary.dart` |
| 服务器请求 | `lib/services/server_api.dart`。新字段要先看服务器是否宣告了对应 `features` |
| AI | `lib/services/ai_recognition/`、`lib/providers/ai_recognition_settings_provider.dart` |
| 主控屏 | `lib/screens/controller_display_screen.dart`、`lib/services/controller_window_service.dart` |
| 图标 | `assets/images/logo.svg` 是母版。各平台 PNG/ICO 由它栅格化，换图标时一起换，并保持原来的画布尺寸和底色。`site/wechat-zjra.svg` 不是应用图标。 |

账号共享和好友协作、公开 Live Share 是三条路。给其中一条加能力时，不要复用另一条的接口或本地表。

共享词库还有两条客户端约束：

- 只有 `server-info.features` 含 `accountShareDictionary` 时才发送 `shareDictionary`。旧服务器把未知字段当成 422。
- 新授权默认打开；省略这个字段在服务器上表示关闭，所以旧客户端不会把已有授权突然打开。
- 复用填表只在当前共享允许 `canEditLogs` 时发生。只读授权不应出现可用的复用结果。

## 文案

用户看得见的字在四份 ARB 里，要一起改：

- `lib/l10n/app_zh.arb`
- `lib/l10n/app_zh_CN.arb`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_en_US.arb`

然后：

```bash
flutter gen-l10n
```

把 ARB 和 `lib/l10n/generated/` 一起提交。现有的 l10n 测试不检查四份文件的键是否齐全，漏一份不会红。

## 验证

只跑刚改到的测试：

```bash
flutter test test/providers/account_share_dictionary_test.dart
flutter analyze
```

Rust 侧：

```bash
cargo test
```

在 `rust/` 目录执行。全量 `flutter test` 很慢，提交涉及面大时再跑。不要为了看测试去改生产数据库或登录真实服务器。

## 版本号

版本只改一次：

```bash
dart run tool/bump_version.dart 3.0.4-R+16
dart run tool/bump_version.dart --check
```

它会同步 Flutter、Rust 和 Cargo 锁文件。`android/local.properties` 不是版本来源，也不进 Git。

## 不要做的事

- 不要把签名私钥、keystore 口令、API 密钥写进仓库、文档或测试夹具。Android 发布证书只存在离线备份和 CI secrets 里。
- macOS 的 `DebugProfile.entitlements` 和 `Release.entitlements` 不要加回 `keychain-access-groups`，空数组也不行。adhoc 签名里出现这个键，系统会在启动时杀掉进程（AMFI -424）。CI 会检查已签名的 macOS 包。安全存储插件只在 iOS 上设置 access group。
- 不要把 `docs/superpowers/` 的计划当成还没做完就必须继续的任务。多模态 AI 若要接着做，从 `docs/superpowers/plans/2026-10-07-ai-mode-a-usable.md` 的 Plan 2 Task 4 看，那是暂停点，不是这份指南的范围。
