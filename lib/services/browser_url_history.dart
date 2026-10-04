import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

/// Owns browser history for the stateful home tabs and their pageless routes.
/// Flutter's URL strategy must be disabled before creating the binding: mixing
/// its single-entry history with pushState turns query URLs into named routes.
class BrowserUrlHistory extends NavigatorObserver {
  BrowserUrlHistory(this.location);

  final PlatformLocation location;
  final _routes = <Route<dynamic>>[];
  final _instance = DateTime.now().microsecondsSinceEpoch.toString();
  int _index = 0;
  String _url = '';
  bool _handlingPop = false;
  void Function(String)? _onQueryChanged;
  bool Function()? _onBackWithinPage;
  void _listener(Object event) => unawaited(_handlePop());

  int get _depth => _routes.isEmpty ? 0 : _routes.length - 1;
  String get _browserUrl =>
      '${location.pathname}${location.search}${location.hash}';

  VoidCallback attach({
    required void Function(String) onQueryChanged,
    bool Function()? onBackWithinPage,
  }) {
    assert(
        _onQueryChanged == null, 'Only one home screen owns browser history');
    _onQueryChanged = onQueryChanged;
    _onBackWithinPage = onBackWithinPage;
    _url = _browserUrl;
    _write(push: false, url: _url);
    location.addPopStateListener(_listener);
    onQueryChanged(location.search);
    return () {
      location.removePopStateListener(_listener);
      _onQueryChanged = null;
      _onBackWithinPage = null;
    };
  }

  void pushQuery(String query) {
    if (_onQueryChanged == null) return;
    final nextUrl = '${location.pathname}$query';
    if (nextUrl != _url) _write(push: true, url: nextUrl);
  }

  /// Makes an in-page detail (e.g. a phone settings category) returnable with
  /// the browser back button, including when the app was opened from a link.
  void checkpoint() {
    if (_onQueryChanged != null) _write(push: true, url: _url);
  }

  void _write({required bool push, required String url}) {
    if (push) _index++;
    _url = url;
    final state = <String, Object?>{
      'openlogtool': {'instance': _instance, 'index': _index, 'depth': _depth},
    };
    if (push) {
      location.pushState(state, '', url);
    } else {
      location.replaceState(state, '', url);
    }
  }

  Future<void> _handlePop() async {
    if (_onQueryChanged == null) return;
    final targetUrl = _browserUrl;
    final targetQuery = location.search;
    final state = location.state;
    final entry = state is Map ? state['openlogtool'] : null;
    final owned = entry is Map && entry['instance'] == _instance;
    final targetIndex =
        owned && entry['index'] is int ? entry['index'] as int : _index - 1;
    final targetDepth =
        owned && entry['depth'] is int ? entry['depth'] as int : 0;
    final direction = targetIndex < _index ? -1 : 1;
    final previousUrl = _url;
    _index = targetIndex;
    var poppedRoute = false;
    _handlingPop = true;
    try {
      while (_depth > targetDepth && navigator != null) {
        final before = _depth;
        await navigator!.maybePop();
        if (_onQueryChanged == null) return;
        if (_depth == before) {
          // A dirty form or another PopScope vetoed the back operation.
          _write(push: true, url: previousUrl);
          return;
        }
        poppedRoute = true;
      }
      if (!poppedRoute &&
          direction < 0 &&
          (_onBackWithinPage?.call() ?? false)) {
        _write(push: true, url: previousUrl);
        return;
      }
      if (!poppedRoute && owned && targetUrl == previousUrl) {
        // Programmatic closes replace their entry synchronously. Skip those
        // now-redundant entries on back/forward; never start an asynchronous
        // history.back during an invitation's pop-then-open transition.
        location.go(direction);
        return;
      }
      _write(push: false, url: targetUrl);
      _onQueryChanged?.call(targetQuery);
    } finally {
      _handlingPop = false;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    if (previousRoute != null && !_handlingPop) checkpoint();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _replaceAfterClose();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _replaceAfterClose();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _replaceAfterClose();
  }

  void _replaceAfterClose() {
    if (_onQueryChanged != null && !_handlingPop) {
      _write(push: false, url: _url);
    }
  }
}
