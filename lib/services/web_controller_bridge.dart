import 'dart:convert';
import 'dart:js_interop';

import 'package:openlogtool/models/controller_display.dart';
import 'package:openlogtool/services/url_sync.dart' show buildSyncQuery;
import 'package:web/web.dart' as web;

/// 主控屏数据推送频道名（新标签页与主窗口共享）。
const String controllerBroadcastChannelName = 'openlogtool-controller';

/// 当前 URL 是否是主控屏标签页（?page=controller）。
/// 注意：不能依赖 Uri.base——index.html 的 <base> 标签会使它丢失 query。
bool isControllerTabRoute() {
  final uri = Uri.parse(web.window.location.href);
  return uri.queryParameters['page'] == 'controller';
}

/// 捕获当前 URL 的主控屏标签页参数。
/// 在启动时捕获，独立显示窗口不跟随主窗口之后的页面切换。
({bool isController, String? sessionId}) controllerTabRouteSnapshot() {
  final uri = Uri.parse(web.window.location.href);
  return (
    isController: uri.queryParameters['page'] == 'controller',
    sessionId: uri.queryParameters['session'],
  );
}

/// 主控屏标签页的会话参数（URL 无 session 时返回 null）。
String? controllerTabSessionId() {
  final uri = Uri.parse(web.window.location.href);
  return uri.queryParameters['session'];
}

/// 主控屏新标签页 URL（带 page/session 参数，须以 ? 开头否则会被浏览器
/// 当作相对路径）。
String controllerTabUrl(String sessionId) =>
    buildSyncQuery('controller', sessionId);

/// 在主标签页打开主控屏。
void openWebControllerTab(String sessionId) {
  web.window.open(controllerTabUrl(sessionId), '_blank');
}

/// 向主控屏新标签页推送最新显示数据。
void pushControllerDisplay(ControllerDisplayDto data) {
  final channel = web.BroadcastChannel(controllerBroadcastChannelName);
  channel.postMessage(jsonEncode(<String, Object?>{
    'type': 'display',
    'data': data.toJson(),
  }).toJS);
}

/// 新标签页订阅主窗口推送。
void listenControllerDisplay({
  required void Function(ControllerDisplayDto data) onData,
}) {
  final channel = web.BroadcastChannel(controllerBroadcastChannelName);
  channel.onmessage = ((web.MessageEvent event) {
    final raw = event.data;
    final message = raw.dartify();
    if (message is! String) return;
    try {
      final payload = jsonDecode(message);
      if (payload is Map && payload['type'] == 'display') {
        onData(ControllerDisplayDto.fromJson(payload['data']));
      }
    } catch (_) {
      // 忽略无法解析的消息。
    }
  }).toJS;
}
