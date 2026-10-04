import 'dart:async';

import 'package:flutter_web_plugins/url_strategy.dart';

/// Browser history semantics without a real browser or platform route channel.
class FakePlatformLocation implements PlatformLocation {
  FakePlatformLocation(String url) : entries = [(url: url, state: null)];

  final List<({String url, Object? state})> entries;
  final listeners = <EventListener>[];
  int index = 0;
  int outsideAppMoves = 0;
  Uri get _uri => Uri.parse(entries[index].url);
  @override
  String get pathname => _uri.path;
  @override
  String get search => _uri.hasQuery ? '?${_uri.query}' : '';
  @override
  String get hash => _uri.hasFragment ? '#${_uri.fragment}' : '';
  @override
  Object? get state => entries[index].state;
  @override
  String getBaseHref() => '/';
  @override
  void addPopStateListener(EventListener fn) => listeners.add(fn);
  @override
  void removePopStateListener(EventListener fn) => listeners.remove(fn);
  @override
  void pushState(Object? state, String title, String url) {
    entries.removeRange(index + 1, entries.length);
    entries.add((url: url, state: state));
    index++;
  }

  @override
  void replaceState(Object? state, String title, String url) {
    entries[index] = (url: url, state: state);
  }

  @override
  void go(int count) {
    scheduleMicrotask(() {
      final target = index + count;
      if (target < 0 || target >= entries.length) {
        outsideAppMoves++;
        return;
      }
      index = target;
      for (final listener in List.of(listeners)) {
        listener(Object());
      }
    });
  }
}
