import 'package:openlogtool/services/deployed_config_stub.dart'
    show defaultServerUrlFromMeta;
import 'package:web/web.dart' as web;

/// 部署注入的默认服务器地址（Web）。
///
/// 由部署方在 index.html 的 meta[name=openlogtool-default-server] 中注入；
/// 未注入时，服务端内置的 /client/ 使用同源服务器；独立部署返回 null。
String? deployedDefaultServerUrl() {
  final meta = web.document.querySelector(
    'meta[name="openlogtool-default-server"]',
  );
  final content = meta?.getAttribute('content');
  return defaultServerUrlFromMeta(content) ??
      (web.window.location.pathname.startsWith('/client/')
          ? web.window.location.origin
          : null);
}
