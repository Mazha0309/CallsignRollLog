import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:openlogtool/services/browser_url_history.dart';

/// 页面名与 HomeScreen tab 索引映射。
const _pages = ['workbench', 'sessions', 'data', 'settings'];

String pageForHomeIndex(int index) =>
    index >= 0 && index < _pages.length ? _pages[index] : _pages.first;

int homeIndexForPage(String? page) {
  final index = _pages.indexOf(page ?? '');
  return index < 0 ? 0 : index;
}

String buildSyncQuery(String page, String? session) {
  final params = <String, String>{'page': page};
  if (session != null && session.isNotEmpty) {
    params['session'] = session;
  }
  return '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
}

class SyncRoute {
  final String? page;
  final String? session;
  const SyncRoute({this.page, this.session});
}

SyncRoute parseSyncQuery(String query) {
  final uri = Uri.parse(query.isEmpty ? '?x' : query);
  return SyncRoute(
    page: uri.queryParameters['page'],
    session: uri.queryParameters['session'],
  );
}

/// 浏览器 URL 同步：非 Web 平台为空实现。
class UrlSync {
  static final BrowserUrlHistory? _history =
      kIsWeb ? BrowserUrlHistory(BrowserPlatformLocation()) : null;

  /// Call before binding initialization. Query links belong to this service,
  /// not to MaterialApp's named-route machinery.
  static void configure() => setUrlStrategy(null);

  static List<NavigatorObserver> get navigatorObservers =>
      [if (_history case final history?) history];

  /// 初始化：立即回调一次当前 URL 的路由，并监听浏览器前进/后退。
  static VoidCallback init({
    required void Function(SyncRoute route) onRouteChanged,
    bool Function()? onBackWithinPage,
  }) =>
      _history?.attach(
        onQueryChanged: (query) => onRouteChanged(parseSyncQuery(query)),
        onBackWithinPage: onBackWithinPage,
      ) ??
      () {};

  /// 更新 URL（不触发 popstate，避免与前进/后退冲突）。
  static void push(String page, String? session) =>
      _history?.pushQuery(buildSyncQuery(page, session));

  static void checkpoint() => _history?.checkpoint();
}
