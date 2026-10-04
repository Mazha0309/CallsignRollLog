# OpenLogTool WebClient

升级后若浏览器仍显示旧版，请打开本部署地址下的 `update.html`，点击“保留本机数据并更新”。更新页及 `update.js` 随每个 Release 包一起提供，不会清除 IndexedDB、OPFS 或本机记录；不要使用浏览器的“清除站点数据”。

This release bundle contains the prebuilt Flutter Web and Rust WASM assets.
Docker only packages those assets into Nginx; it does not rebuild Flutter or
Rust.

本发布包已包含构建完成的 Flutter Web 与 Rust WASM 文件。Docker 只会将它们
打包进 Nginx，不会重新编译 Flutter 或 Rust。

```bash
docker compose up -d
```

The default external port is `5973`:

默认外部端口为 `5973`：

```text
http://127.0.0.1:5973
```

To use another port:

如需修改端口：

```bash
OPENLOGTOOL_WEB_PORT=8080 docker compose up -d
```

For access from another machine, use an HTTPS reverse proxy. Rust WASM workers
require a secure browser context outside `localhost`.

从其他设备访问时请配置 HTTPS 反向代理；除 `localhost` 外，Rust WASM 工作线程
需要浏览器安全上下文。

If this WebClient and OpenLogTool Server use different origins, add the
WebClient origin to the server's `CORS_ORIGINS`, then recreate the server
container. Native clients do not require this setting.

如果 WebClient 与 OpenLogTool Server 使用不同 Origin，请将 WebClient Origin
加入服务端的 `CORS_ORIGINS`，随后重新创建服务端容器。原生客户端无需此设置。

```dotenv
CORS_ORIGINS=https://log.example.com
```

升级后若浏览器仍显示旧版本，请先保存编辑并关闭其他应用标签页，再打开
`/update.html`，选择“保留本机数据并更新”。该页面只停用本应用的旧 Flutter
Service Worker，不清除 IndexedDB、OPFS 或其他本机数据。不要使用浏览器的
“清除站点数据”，那可能删除尚未上传的记录。部署在 `/client/` 时入口为
`/client/update.html`。
