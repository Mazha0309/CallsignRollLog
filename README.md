# OpenLogTool - 业余无线电点名记录与协作工具

专为业余无线电爱好者设计的点名记录工具，支持跨平台运行。

本地使用不需要服务器，也不需要注册账号。新建会话后即可记录、管理词库、查看历史和导入导出。
服务器是可选扩展，用于个人云同步、好友及多人协作；没有服务器不会阻止单机记录。

## 会话首页

- “新建会话”和“继续记录”是主要操作，无服务器时不展示加入协作、公开分享等操作
- 历史可按“全部 / 我的记录 / 共同记录 / 已结束”筛选；没有协作副本时不显示“共同记录”，已有协作副本在退出登录后仍可找到
- “已结束”只是本机会话状态分类，不会发布为公开归档；会话 ID 收在可展开的详细信息中
- “同步与协作（可选）”在未登录时折叠，仅在主动展开后提供服务器设置入口
- 已有协作会话的负责人可以直接邀请好友；本地会话开启协作前会确认上传范围与目标服务器，取消确认不上传、不邀请

会话生命周期统一为以下规则：

- 本地会话用“结束记录”，保留原会话及记录，之后可恢复；不需要服务器
- 协作发起人在“协作与成员”中“结束共同记录”，同步确认后所有成员停止编辑；已有记录及成员关系保留
- 参与者“离开协作”只退出自己的成员关系，保留本机已有的只读记录，不影响其他成员
- 切换页面、切换会话、暂时断网都不等于离开协作，无需先点结束或退出
- 新建、恢复或另存会话不会结束其他会话；客户端不再定时因闲置而结束记录
- “更多操作 → 另存独立会话”复制已保存的表格记录，并切换到独立本地会话；原协作会话、成员身份、待同步队列、冲突及草稿仍保留，不会自动退出
- 不再提供“仅在本机关闭协作”和“停止协作并转本地”的常用入口；本地结束 API 在数据库事务内拒绝协作副本，避免误清待同步数据

个人云同步仍沿用已有账号配置和同步规则；上述会话协作确认不会修改其他会话的云同步设置。

## 功能

### 记录管理
- 快速添加记录：支持主控呼号、点名呼号、设备、天线、功率、QTH、高度、时间、信号报告等字段
- 智能表单：自动大写呼号，保留主控呼号，支持词典自动补全
- 编辑和删除记录
- 撤销上一条记录
- 统计信息：总记录数、今日记录、最近7天记录

### 词典管理
- 设备、天线、呼号、QTH词典管理
- 支持自动补全
- 输入新内容时自动添加到词典
- 支持 JSON 导入导出
- 可选文字助手可从本机历史聚合识别缺失词条，并为四类词库提出新增、改名或合并建议；所有变更均需确认且不会改写历史记录

### 可选 AI 辅助
- 语音识别与文字助手相互独立，可分别启用；文字助手支持 OpenAI Responses API、Anthropic Messages API 和旧版 OpenAI Chat Completions 兼容协议
- 设备、天线、QTH、高度和功率字段停止输入约 300 毫秒后，可在原下拉框中显示一条格式规范建议
- 文字模型请求默认关闭或弱化推理以优先获得快速结构化结果；API 密钥使用平台安全存储，不写入普通设置或导出文件
- 语音接口格式、录音行为和排错方法见 [AI 语音识别配置指南](docs/ai-speech-recognition.md)

### 数据导入导出
- JSON导出/导入
- Excel导出

### 个人云同步
- 登录支持 `personalCloudSnapshots` 与 `personalDictionarySnapshots` 的自建服务器后，自动双向同步个人会话、点名记录及词库用户改动
- 个人记录不会写入协作会话，也不会出现在服务端的“协作会话（Sessions）”列表；协作会话继续使用独立的实时同步
- 使用账户隔离、完整本地基线、内容校验和与 revision 条件写入；多设备的独立改动自动三方合并，真实字段冲突才要求选择
- 词库只同步用户词条和对内置词条的删除覆盖，不复制整份内置词库；从云端替换记录不会修改设置或协作会话
- 导入或清空整库后会立即刷新会话列表，并暂停自动覆盖，等待用户确认新的同步基线

### 协作会话（v1 阶段 3）
- 使用 `/api/v1` 短期 Access Token 与 Refresh Token 登录自建服务器
- 将完整本地 Session 分批发布，保留 sessionId、syncId、RST、时间和备注
- 发布前按服务端字段约束校验冻结快照，并同时按 500 条与 UTF-8 请求字节上限动态分批
- 通过 10 位成员邀请码加入同一个 Session，并原子安装服务端规范快照
- Owner 可创建/撤销邀请、调整或移除成员、转移所有权
- Owner/Editor 的 Log 增改删恢复会与 durable outbox 在同一个本地事务提交；Owner 还可重命名、关闭和重开 Session
- 通过连续事件 REST 补拉和鉴权 WebSocket 提示保持在线同步；断线、重启和请求结果丢失后复用原 mutationId 恢复
- 本地持久化服务器绑定、成员角色、shadow、游标、outbox 和冲突记录；accepted mutation 只在规范事件落库后清除
- 永久 rejected 会保留可见提示；再次编辑同一实体时基于规范 shadow 原子重建新 mutation，不复用被拒 payload 或 ID
- Viewer、已撤权成员及服务端已关闭的 Session 强制只读，角色变化会持久化后重连
- 协作页优先展示连接状态和待处理问题；会话 ID、事件游标及队列统计收进可展开的“技术详情”
- 服务器、账号、Session 切换会立即隔离管理状态；加入和管理操作保留可重放的幂等 ID
- 事件游标过期或 WebSocket 请求重同步时，自动拉取包含 Log tombstone 的一致快照，原子重装规范基线，再叠加未提交 outbox 并继续补拉
- 对完整本地 mutation 链执行安全三方 rebase；无重叠修改自动生成新的 mutation，生命周期或同字段冲突进入持久冲突中心
- 冲突实体在解决前禁止继续编辑；可按 Rust 返回的允许操作采用远端、保留本地重试，或把本地日志复制为全新记录

### 好友、邀请与申请

- 登录声明 `friendCollaboration` 能力的新服务端后，会话页提供“好友与协作”，包含好友、消息、会话三个入口
- 按用户名添加好友，对方接受后双方成为好友；个人记录及历史不会因此开放
- 会话所有者可以邀请好友、选择“可编辑”或“仅查看”；受邀人接受后直接下载并打开协作会话
- 默认私有；所有者开启好友发现后，好友可看标题并申请加入，获批后才能看记录
- 消息支持接受、拒绝及取消；好友支持删除、拉黑及解除拉黑；成员权限继续在会话管理中调整
- 删除好友不会踢出已经加入的成员；旧共享记录与已有授权保留，不会自动转换成好友
- 邀请已接受但下载失败时，可从消息重新打开，已有本地副本不会清空待同步修改

好友数据与当前服务器/账号隔离。支持 `socialWebSocket` 的服务器通过账号级 WebSocket
实时通知好友请求、会话邀请与申请变化；客户端收到通知后获取最新状态，断线重连也会补刷新。
无需先加入会话即可收到邀请；工作台顶部的消息提醒可直接进入待处理消息。
新服务器不再定时轮询，只有不支持此能力的旧服务器保留 30 秒兼容刷新，也支持手动刷新。
未登录或纯本地使用时不建立此连接。旧服务器仍使用旧共享入口。

### 与服务端共用一个地址

WebClient 可以安装到 OpenLogToolServer 的 `/client/`，首次使用自动选择同源服务器。
服务器的 `/connect` 提供连接地址和二维码；桌面/手机客户端可以把该链接直接粘贴到
“服务器与账号”，无需手工删除门户路径。登录仍使用自己的账号，链接不携带凭据。
构建及安装步骤见服务端 README 的“统一客户端入口”；独立 WebClient 部署继续受支持。

公开 Live Share 与好友邀请是独立能力，均需主动启用；结束本地会话不会自动公开记录。

### 主题设置
- 自定义主题颜色
- 暗色/亮色模式
- 可折叠侧边栏与响应式布局

### 跨平台
- Linux
- Windows
- macOS
- Android
- WebClient（Flutter Web + Rust WASM）

## 开始使用

### 环境要求
- Flutter SDK 3.44+
- Dart SDK 3.12+
- Rust toolchain 1.91.1（仓库中的 `rust-toolchain.toml` 会固定版本）
- Android 构建额外需要 Android NDK 28.2.13676358 与 cargo-ndk 4.1.2
- WebClient 构建额外需要 `nightly-2026-07-26`、`rust-src`、
  `wasm32-unknown-unknown`、wasm-pack 0.15.0 和
  flutter_rust_bridge_codegen 2.12.0
- Linux 构建需要 `libsecret-1-dev`，运行需要 `libsecret-1-0` 和可用的 Secret Service/keyring
- Windows 构建需要 Visual Studio C++ ATL 组件

### 崩溃诊断

Dart 层日志（`lib/services/app_logger.dart`）在应用支持目录写 `app.log`，并预留
`.run-active` 标记：进程非正常退出时，下次启动会记录一条警告，并列出上一次运行
可能留下的崩溃文件位置（`lib/services/crash_report_guidance.dart`）。Windows 上
每次启动还会记录一条 `[Accessibility]` 行，说明无障碍兼容保护是否生效，便于事后
把崩溃与防护状态对应起来。原生崩溃不经过 Dart，不会直接出现在 `app.log`，由各
平台的捕获机制落盘：

| 平台 | 捕获方式 | 产物位置 |
|---|---|---|
| Windows | `windows/runner/crash_handler.cpp`（未处理异常过滤器 + `MiniDumpWriteDump`） | `%LOCALAPPDATA%\OpenLogTool\CrashDumps\*.dmp` |
| Linux | `linux/runner/crash_handler.cc`（SIGSEGV/SIGBUS/SIGILL/SIGFPE/SIGABRT） | `$XDG_DATA_HOME/openlogtool/crashes/*.txt`（回退 `~/.local/share`） |
| macOS | 系统崩溃报告（应用未自带处理器） | `~/Library/Logs/DiagnosticReports/*.ips` |

Linux 的文本报告包含信号、可执行路径、回溯（`module(+offset)`）与
`/proc/self/maps`。Windows 的 minidump 需要匹配构建的 `.pdb` 才能读取。macOS 的
`.ips` 由系统生成、带符号化回溯；应用只负责在启动时把它的位置报出来。系统级
core dump（`coredumpctl`、`/var/crash`）由操作系统管理。

#### Windows 无障碍崩溃

Flutter 的 Windows 无障碍桥在处理「节点重新挂载」的语义更新时会解引用空的父
节点：`AccessibilityBridge::CreateRemoveReparentedNodesUpdate()` 对
`child->parent()` 的判空只靠 `assert`，该断言在 release 构建中被裁掉，于是变成
`flutter_windows.dll` 的 `0xc0000005` 原生崩溃（Windows 事件日志 1000）。此缺陷
影响所有 Windows 版本（含 Windows 11），上游仍未修复（flutter/flutter#175041、
#186886、#190357）。在修复版引擎发布前，桌面端默认启用无障碍语义树兼容保护，
把语义树折叠为单个无子节点，避免触发重挂载路径。确实需要屏幕阅读器的用户可在
启动前设置 `OPENLOGTOOL_ENABLE_WINDOWS_ACCESSIBILITY=1`，重新启用完整 Windows
语义树。

验收方式：装上带该保护的构建后，在曾崩溃的机器上正常使用，确认
`%LOCALAPPDATA%\OpenLogTool\CrashDumps` 不再新增 `flutter_windows.dll+0x3A9FA`、
读 `0x48` 的 minidump；同时 `app.log` 里应有 `[Accessibility]` 的 ACTIVE 记录。

正式 Windows 便携包会在应用目录内携带 Visual C++ CRT 与 Universal CRT，
不要求系统预先安装 VC++ Redistributable。便携包必须完整解压后运行，不能只复制
`openlogtool.exe`；安装版会自动安装同一套完整文件。

### 构建

```bash
git clone https://github.com/Mazha0309/OpenLogTool.git
cd OpenLogTool
flutter pub get
flutter build linux
flutter build windows
flutter build macos
flutter build apk
bash tool/build_web.sh
```

Linux、Windows 和 macOS 的平台工程会在 Flutter 构建时自动编译并打包 Rust
动态库。首次构建 Android 前还需要安装对应 Rust targets 和固定版本的
cargo-ndk；macOS 的 Release 默认生成 universal App：

```bash
# Android（在 Linux 或 macOS 上执行）
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo install --locked cargo-ndk --version 4.1.2
flutter build apk --release --split-per-abi \
  --target-platform=android-arm,android-arm64,android-x64
# Universal 兼容包
flutter build apk --release \
  --target-platform=android-arm,android-arm64,android-x64

# macOS universal Release
rustup target add aarch64-apple-darwin x86_64-apple-darwin
flutter build macos --release

# WebClient（首次执行前安装一次）
rustup toolchain install nightly-2026-07-26 \
  --profile minimal \
  --component rust-src \
  --target wasm32-unknown-unknown
cargo install --locked wasm-pack --version 0.15.0
cargo install --locked flutter_rust_bridge_codegen --version 2.12.0
bash tool/build_web.sh
```

Android Release 会分别生成 `armeabi-v7a`、`arm64-v8a` 和 `x86_64`
三个 APK。CI 发布时还会额外保留一个包含全部架构的 Universal APK 作为兼容
兜底；手机下载与处理器匹配的独立文件即可获得更小体积。

Android Release 使用 applicationId
`com.mazha0309.openlogtool` 和固定签名证书（SHA-256：
`086f88968be282b45a8253de5a48b5c0c45c33321285116fde5fde86bbe78942`）。
Release CI 会校验证书并拒绝误用其他密钥的产物。签名私钥和口令只保存在受控
离线备份及 GitHub Actions Secrets，不得写入仓库或 Release。

### WebClient 数据与部署

WebClient 与原生客户端共用同一套 Rust 数据核心、迁移和备份格式。浏览器端
SQLite 优先使用 OPFS，并在不可用时回退到持久化 IndexedDB；数据按网站来源
（协议、域名、端口）隔离，清除该网站数据会同时删除本地数据库。WebClient
不再携带旧的 Dart/sqflite 数据库实现。

Rust 工作线程依赖 `SharedArrayBuffer`。部署服务器必须返回
`Cross-Origin-Opener-Policy: same-origin` 和
`Cross-Origin-Embedder-Policy: credentialless`，WASM 还应使用
`application/wasm` MIME 类型。除 `localhost` 外应通过 HTTPS 访问，否则浏览器
不会提供安全上下文。

仓库内置的 Nginx 镜像已包含这些响应头，Docker Compose 默认使用外部端口
`5973`：

```bash
# 从源码构建 WebClient
docker compose -f docker-compose.web.yml up -d --build
# 本机访问：http://127.0.0.1:5973
```

可以覆盖外部端口，但容器内仍监听 80：

```bash
OPENLOGTOOL_WEB_PORT=8080 \
  docker compose -f docker-compose.web.yml up -d --build
```

该容器只提供静态 WebClient，不包含 OpenLogTool Server。公网部署时应由现有的
HTTPS 反向代理转发到 `127.0.0.1:5973`。GitHub Actions 会在每次推送和 PR
自动构建 WebClient；普通构建可下载 Actions artifact，`v*` 标签发布时
WebClient 压缩包会一并加入 GitHub Release。

Release 中的 WebClient 压缩包是完整的预构建 Docker 部署包，不需要仓库源码，
也不会在部署机器上重新编译 Flutter 或 Rust。下载并解压后直接运行：

```bash
tar -xzf OpenLogTool-*-WebClient.tar.gz
cd OpenLogTool-*-WebClient
docker compose up -d
```

发布包中已包含静态网页、Rust WASM、Dockerfile、Nginx 配置和
`docker-compose.yml`，默认同样映射到外部端口 `5973`。

浏览器连接 OpenLogTool Server 时还要遵守同源策略。如果 WebClient 与 API 使用
不同 Origin（协议、域名或端口任一不同），服务端的 `CORS_ORIGINS` 必须包含
WebClient 的完整 Origin，例如：

```dotenv
CORS_ORIGINS=https://log.example.com
```

修改后需重新创建服务端容器。原生客户端不受 CORS 限制；使用同源反向代理时也
不需要额外配置。

### 迭代版本

版本号只需输入一次。下面的命令会同步 Flutter、Rust、Cargo 锁文件和应用内
版本常量，并使用 `cargo check --locked` 校验结果：

```bash
dart run tool/bump_version.dart 2.6.3-R+15
```

只检查当前文件是否一致而不修改内容：

```bash
dart run tool/bump_version.dart --check
```

`android/local.properties` 是 Flutter 在本机生成的构建配置，不是版本来源，也不
纳入 Git。Android 的 `versionName` 和 `versionCode` 均来自 `pubspec.yaml`。

Android 发布包允许连接局域网内的明文 HTTP 自建服务器，以匹配应用中可配置的
`http://` 地址；通过公网访问或承载真实账号时应使用 HTTPS，避免凭据和点名记录
在传输中暴露。

## 技术栈

- Flutter
- Provider（状态管理）
- Rust + rusqlite + SQLite（原生端）
- Rust + sqlite-wasm-rs（Web 持久化 SQLite）
- flutter_rust_bridge
- Excel（导出）

## License

GNU Affero General Public License V3
