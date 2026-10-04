@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:openlogtool/services/browser_url_history.dart';
import 'package:openlogtool/services/url_sync.dart';

void main() {
  UrlSync.configure();

  testWidgets('real browser accept/pop/query transition keeps one home route',
      (tester) async {
    final location = BrowserPlatformLocation();
    final originalUrl =
        '${location.pathname}${location.search}${location.hash}';
    final originalState = location.state;
    addTearDown(() => location.replaceState(originalState, '', originalUrl));
    location.replaceState(null, '', '${location.pathname}?page=settings');
    final history = BrowserUrlHistory(location);
    final queries = <String>[];
    await tester.pumpWidget(MaterialApp(
        initialRoute: '/',
        navigatorObservers: [history],
        home: const Scaffold(body: TextField())));
    final detach = history.attach(onQueryChanged: queries.add);
    addTearDown(detach);
    expect(urlStrategy, isNull);
    final home = tester.element(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '保留未保存的记录');
    history.navigator!.push<void>(MaterialPageRoute(
        builder: (context) => Scaffold(
                body: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                history.pushQuery('?page=workbench&session=accepted');
              },
              child: const Text('接受'),
            ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接受'));
    await tester.pumpAndSettle();
    expect(location.search, '?page=workbench&session=accepted');
    expect(history.navigator!.canPop(), isFalse);
    expect(tester.element(find.byType(TextField)), same(home));
    expect(find.text('保留未保存的记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _browserGo(tester, location, -1);
    expect(location.search, '?page=settings');
    expect(queries.last, '?page=settings');
    expect(history.navigator!.canPop(), isFalse);
    await _browserGo(tester, location, 1);
    expect(location.search, '?page=workbench&session=accepted');
    expect(queries.last, '?page=workbench&session=accepted');
    expect(tester.element(find.byType(TextField)), same(home));
    expect(tester.takeException(), isNull);
  });

  testWidgets('real browser back dismisses the top dialog', (tester) async {
    final location = BrowserPlatformLocation();
    location.replaceState(null, '', '${location.pathname}?page=settings');
    final history = BrowserUrlHistory(location);
    await tester.pumpWidget(MaterialApp(
        initialRoute: '/',
        navigatorObservers: [history],
        home: const Scaffold(body: Text('settings'))));
    final detach = history.attach(onQueryChanged: (_) {});
    addTearDown(detach);
    showDialog<void>(
        context: tester.element(find.text('settings')),
        builder: (_) => const AlertDialog(content: Text('login')));
    await tester.pumpAndSettle();
    await _browserGo(tester, location, -1);
    expect(find.text('login'), findsNothing);
    expect(find.text('settings'), findsOneWidget);
    expect(location.search, '?page=settings');
    expect(history.navigator!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _browserGo(
    WidgetTester tester, PlatformLocation location, int direction) async {
  await tester.runAsync(() async {
    final event = Completer<void>();
    void onPop(Object _) {
      if (!event.isCompleted) event.complete();
    }

    location.addPopStateListener(onPop);
    try {
      location.go(direction);
      await event.future.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    } finally {
      location.removePopStateListener(onPop);
    }
  });
  await tester.pumpAndSettle();
}
