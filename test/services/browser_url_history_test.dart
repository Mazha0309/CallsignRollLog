import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/browser_url_history.dart';
import 'package:openlogtool/services/url_sync.dart';

import '../support/fake_platform_location.dart';

void main() {
  test('initial links and subsequent URLs preserve the deployment path', () {
    final location = FakePlatformLocation('/client/?page=workbench&session=a');
    final history = BrowserUrlHistory(location);
    final queries = <String>[];
    final detach = history.attach(onQueryChanged: queries.add);
    expect(queries, ['?page=workbench&session=a']);
    history.pushQuery(buildSyncQuery('workbench', '会话 / b'));
    expect(location.pathname, '/client/');
    expect(parseSyncQuery(location.search).session, '会话 / b');
    expect(queries.length, 1, reason: 'pushState must not dispatch a route');
    history.pushQuery(buildSyncQuery('workbench', '会话 / b'));
    expect(location.entries.length, 2, reason: 'Identical URLs are not pushed');
    detach();
    expect(location.listeners, isEmpty);
  });

  testWidgets('browser back and forward keep the same home and draft',
      (tester) async {
    final location = FakePlatformLocation('/?page=settings');
    final history = BrowserUrlHistory(location);
    await tester.pumpWidget(_app(history));
    final homeState = tester.state(find.byType(_Home));
    await tester.enterText(find.byType(TextField), 'unfinished log');
    history.pushQuery('?page=workbench&session=joined');
    location.go(-1);
    await tester.pumpAndSettle();
    expect(find.text('?page=settings'), findsOneWidget);
    location.go(1);
    await tester.pumpAndSettle();
    expect(find.text('?page=workbench&session=joined'), findsOneWidget);
    expect(tester.state(find.byType(_Home)), same(homeState));
    expect(find.text('unfinished log'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pop then open a session never races a browser history.back',
      (tester) async {
    final location = FakePlatformLocation('/?page=settings');
    final history = BrowserUrlHistory(location);
    await tester.pumpWidget(_app(history));
    final navigator = history.navigator!;
    navigator.push<void>(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('invitation'))));
    await tester.pumpAndSettle();
    navigator.pop();
    history.pushQuery('?page=workbench&session=accepted');
    await tester.pumpAndSettle();
    expect(location.search, '?page=workbench&session=accepted');
    expect(find.text('invitation'), findsNothing);
    expect(navigator.canPop(), isFalse);
    location.go(-1);
    await tester.pumpAndSettle();
    expect(find.text('?page=settings'), findsOneWidget);
    expect(find.byType(_Home), findsOneWidget);
    location.go(-1);
    await tester.pumpAndSettle();
    expect(location.outsideAppMoves, 1, reason: 'Closed overlay entries skip');
    expect(tester.takeException(), isNull);
  });

  testWidgets('browser back closes a dialog before changing the home tab',
      (tester) async {
    final location = FakePlatformLocation('/?page=workbench');
    final history = BrowserUrlHistory(location);
    await tester.pumpWidget(_app(history));
    history.pushQuery('?page=settings');
    showDialog<void>(
        context: tester.element(find.byType(_Home)),
        builder: (_) => const AlertDialog(content: Text('login')));
    await tester.pumpAndSettle();
    location.go(-1);
    await tester.pumpAndSettle();
    expect(find.text('login'), findsNothing);
    expect(location.search, '?page=settings');
    expect(history.navigator!.canPop(), isFalse);
    location.go(-1);
    await tester.pumpAndSettle();
    expect(location.search, '?page=workbench');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blocked route remains open and keeps its browser checkpoint',
      (tester) async {
    final location = FakePlatformLocation('/?page=settings');
    final history = BrowserUrlHistory(location);
    await tester.pumpWidget(_app(history));
    history.navigator!.push<void>(MaterialPageRoute(
        builder: (_) => const PopScope(
            canPop: false, child: Scaffold(body: Text('unsaved')))));
    await tester.pumpAndSettle();
    location.go(-1);
    await tester.pumpAndSettle();
    expect(find.text('unsaved'), findsOneWidget);
    expect(location.index, 1);
    expect(location.search, '?page=settings');
    expect(tester.takeException(), isNull);
  });

  test('back consumes phone settings detail before changing tabs', () async {
    final location = FakePlatformLocation('/?page=workbench');
    final history = BrowserUrlHistory(location);
    var categoryOpen = false;
    final queries = <String>[];
    final detach = history.attach(
        onQueryChanged: queries.add,
        onBackWithinPage: () {
          if (!categoryOpen) return false;
          categoryOpen = false;
          return true;
        });
    history.pushQuery('?page=settings');
    categoryOpen = true;
    history.checkpoint();
    location.go(-1);
    await Future<void>.delayed(Duration.zero);
    expect(categoryOpen, isFalse);
    expect(location.search, '?page=settings');
    location.go(-1);
    await Future<void>.delayed(Duration.zero);
    expect(location.search, '?page=workbench');
    expect(queries.last, '?page=workbench');
    detach();
  });
}

Widget _app(BrowserUrlHistory history) => MaterialApp(
    initialRoute: '/', navigatorObservers: [history], home: _Home(history));

class _Home extends StatefulWidget {
  const _Home(this.history);
  final BrowserUrlHistory history;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  late final VoidCallback detach;
  String query = '';
  @override
  void initState() {
    super.initState();
    detach = widget.history
        .attach(onQueryChanged: (value) => setState(() => query = value));
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Column(children: [Text(query), const TextField()]));
}
