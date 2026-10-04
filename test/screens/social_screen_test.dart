import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/screens/social_screen.dart';
import 'package:openlogtool/services/browser_url_history.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/theme/app_theme.dart';

import '../support/fake_platform_location.dart';

void main() {
  testWidgets('recipient accepts, closes messages and opens the session URL',
      (tester) async {
    final social = FakeSocial()..snapshot = _incomingInvitation();
    final collaboration = FakeCollaboration();
    final location = FakePlatformLocation('/client/?page=settings');
    final history = BrowserUrlHistory(location);
    var openedCallbacks = 0;
    await pumpSocial(tester, social, collaboration,
        initialTab: 1,
        asChildRoute: true,
        observers: [history], onSessionOpened: () {
      openedCallbacks++;
      history.pushQuery('?page=workbench&session=net-1');
    });
    final queries = <String>[];
    final detach = history.attach(onQueryChanged: queries.add);
    addTearDown(detach);
    await tester.tap(find.byKey(const Key('test-open-social')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接受'));
    await tester.pumpAndSettle();
    expect(social.calls.single[1], '/session-requests/invite-1/accept');
    expect(collaboration.opened, 'net-1');
    expect(openedCallbacks, 1);
    expect(find.byType(SocialScreen), findsNothing);
    expect(history.navigator!.canPop(), isFalse);
    expect(location.pathname, '/client/');
    expect(location.search, '?page=workbench&session=net-1');
    expect(tester.takeException(), isNull);
    location.go(-1);
    await tester.pumpAndSettle();
    expect(queries.last, '?page=settings');
    expect(find.byType(SocialScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late acceptance after leaving messages does not navigate',
      (tester) async {
    final pending = Completer<void>();
    final social = FakeSocial()
      ..snapshot = _incomingInvitation()
      ..mutationBarrier = pending.future;
    final collaboration = FakeCollaboration();
    await pumpSocial(tester, social, collaboration,
        initialTab: 1, asChildRoute: true);
    await tester.tap(find.byKey(const Key('test-open-social')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接受'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(SocialScreen))).pop();
    // Complete while the departing route is still mounted for its animation.
    pending.complete();
    await tester.pumpAndSettle();
    expect(collaboration.opened, isNull);
    expect(find.byType(SocialScreen), findsNothing);
    expect(find.byKey(const Key('test-open-social')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late acceptance cannot open a session under a changed account',
      (tester) async {
    final pending = Completer<void>();
    final social = FakeSocial()
      ..snapshot = _incomingInvitation()
      ..mutationBarrier = pending.future;
    final collaboration = FakeCollaboration();
    await pumpSocial(tester, social, collaboration, initialTab: 1);
    await tester.tap(find.text('接受'));
    await tester.pump();
    social.scope = 'another-account';
    social.notifyListeners();
    pending.complete();
    await tester.pumpAndSettle();
    expect(collaboration.opened, isNull);
    expect(find.byType(SocialScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'late search keeps newer WebSocket relationship without another search',
      (tester) async {
    final late = Completer<SocialUserSearchPage>();
    final social = FakeSocial()..searchHandler = (_) => late.future;
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-username')), 'BA1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-search-submit')));
    await tester.pump();
    social.snapshot = SocialSnapshot(friends: [
      SocialPerson.fromJson({'userId': 'alice', 'username': 'BA1ABC'})
    ]);
    social.revision++;
    social.notifyListeners();
    await tester.pump();
    late.complete(social.searchPage);
    await tester.pumpAndSettle();
    expect(find.text('已是好友'), findsOneWidget);
    expect(find.byKey(const Key('friend-search-action-alice')), findsNothing);
    expect(social.queries, ['BA1']);
  });

  testWidgets('remove confirmation cannot act on a changed account',
      (tester) async {
    final social = FakeSocial()
      ..snapshot = SocialSnapshot(friends: [
        SocialPerson.fromJson({'userId': 'alice', 'username': 'BA1ABC'})
      ]);
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除好友'));
    await tester.pumpAndSettle();
    social.scope = 'other-server-or-account';
    social.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(social.calls, isEmpty);
  });

  testWidgets('phone keyboard resize keeps search draft and focus',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final social = FakeSocial();
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-username')), 'BG5');
    tester.view.viewInsets = const FakeViewPadding(bottom: 330);
    social.notifyListeners();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('friend-username')))
            .controller!
            .text,
        'BG5');
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('phone layout sends a named friend request without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final social = FakeSocial();
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('friend-username')), '  BA1ABC  ');
    expect(social.calls, isEmpty, reason: 'Typing must not send a request');
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-search-submit')));
    await tester.pumpAndSettle();
    expect(social.queries, ['BA1ABC']);
    await tester.tap(find.text('发送申请'));
    await tester.pumpAndSettle();
    expect(social.calls.single, [
      'POST',
      '/friend-requests',
      {'username': 'BA1ABC'}
    ]);
    expect(tester.takeException(), isNull);
    expect(find.text('申请已发送'), findsOneWidget);
  });

  testWidgets('search requires two characters and reports an empty result',
      (tester) async {
    final social = FakeSocial()..searchPage = const SocialUserSearchPage();
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-username')), 'B');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(social.queries, isEmpty);
    await tester.enterText(find.byKey(const Key('friend-username')), 'BG');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('没有找到匹配的用户'), findsOneWidget);
    expect(social.calls, isEmpty);
  });

  testWidgets('editing query invalidates an older response', (tester) async {
    final late = Completer<SocialUserSearchPage>();
    final social = FakeSocial()
      ..searchHandler = (query) async => query == 'old'
          ? await late.future
          : const SocialUserSearchPage(items: [
              SocialUserSearchResult(
                  userId: 'new', username: 'NewAccount', relationship: 'none')
            ]);
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-username')), 'old');
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-search-submit')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('friend-username')), 'new');
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-search-submit')));
    await tester.pumpAndSettle();
    late.complete(const SocialUserSearchPage(items: [
      SocialUserSearchResult(
          userId: 'old', username: 'OldAccount', relationship: 'none')
    ]));
    await tester.pumpAndSettle();
    expect(find.text('NewAccount'), findsOneWidget);
    expect(find.text('OldAccount'), findsNothing);
  });

  testWidgets('switching account clears results and rejects late data',
      (tester) async {
    final late = Completer<SocialUserSearchPage>();
    final social = FakeSocial()..searchHandler = (_) => late.future;
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-username')), 'BA1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-search-submit')));
    await tester.pump();
    social.scope = 'another-account';
    social.notifyListeners();
    await tester.pump();
    late.complete(social.searchPage);
    await tester.pumpAndSettle();
    expect(find.text('BA1ABC'), findsNothing);
    expect(find.textContaining('服务器、账号或当前会话已切换'), findsOneWidget);
    expect(social.calls, isEmpty);
  });

  testWidgets('incoming result accepts request and WS updates friendship',
      (tester) async {
    final social = FakeSocial()
      ..searchPage = const SocialUserSearchPage(items: [
        SocialUserSearchResult(
            userId: 'alice',
            username: 'BA1ABC',
            relationship: 'incoming',
            requestId: 'request-1')
      ]);
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-username')), 'BA1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-search-submit')));
    await tester.pumpAndSettle();
    expect(find.text('对方已申请加你为好友'), findsOneWidget);
    await tester.tap(find.byKey(const Key('friend-search-action-alice')));
    await tester.pumpAndSettle();
    expect(social.calls.single[1], '/friend-requests/request-1/accept');
    expect(find.text('已是好友'), findsOneWidget);
    social.snapshot = SocialSnapshot(friends: [
      SocialPerson.fromJson({'userId': 'alice', 'username': 'BA1ABC'})
    ]);
    social.revision++;
    social.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('已是好友'), findsOneWidget);
    expect(find.byKey(const Key('friend-search-action-alice')), findsNothing);
  });

  testWidgets('failed search can retry without sending a friend request',
      (tester) async {
    final social = FakeSocial()
      ..searchHandler = (_) => Future.error(StateError('offline'));
    await pumpSocial(tester, social, FakeCollaboration());
    await tester.tap(find.byKey(const Key('social-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('friend-username')), 'BA1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('friend-search-submit')));
    await tester.pumpAndSettle();
    expect(find.text('搜索失败，请检查连接后重试。'), findsOneWidget);
    social.searchHandler = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('BA1ABC'), findsOneWidget);
    expect(social.calls, isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets('search layout fits 320px and long names in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final social = FakeSocial()
        ..searchPage = SocialUserSearchPage(hasMore: true, items: [
          SocialUserSearchResult(
              userId: 'long',
              username: 'BG5CRL${'a' * 50}',
              relationship: 'none')
        ]);
      await pumpSocial(tester, social, FakeCollaboration(),
          brightness: brightness, locale: const Locale('en', 'US'));
      await tester.tap(find.byKey(const Key('social-add-friend')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('friend-username')), 'BG');
      await tester.pump();
      await tester.tap(find.byKey(const Key('friend-search-submit')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('friend-search-result-long')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'direct join sends no client role and retains retry after failed open',
      (tester) async {
    final social = FakeSocial()..directSupport = true;
    social.snapshot = SocialSnapshot(sessions: [
      FriendSession.fromJson({
        'sessionId': 'direct-1',
        'title': '朋友的会话',
        'ownerId': 'alice',
        'ownerUsername': 'BA1ABC',
        'visibility': 'friends',
        'joinPolicy': 'direct',
        'defaultRole': 'viewer'
      })
    ]);
    final collaboration = FakeCollaboration()..failOpen = true;
    social.afterMutation = () {
      social.snapshot = const SocialSnapshot();
      social.notifyListeners();
    };
    await pumpSocial(tester, social, collaboration, initialTab: 2);
    await tester.tap(find.text('直接加入'));
    await tester.pumpAndSettle();
    expect(social.calls.single,
        ['POST', '/sessions/direct-1/join', <String, Object?>{}]);
    expect(
        find.byKey(const Key('social-joined-session-retry')), findsOneWidget);
    collaboration.failOpen = false;
    await tester.tap(find.text('打开会话'));
    await tester.pumpAndSettle();
    expect(collaboration.opened, 'direct-1');
    expect(social.calls.length, 1);
  });

  testWidgets('accepted invitation opens the actual collaboration coordinator',
      (tester) async {
    final social = FakeSocial()
      ..snapshot = SocialSnapshot(sessionRequests: [
        SocialRequest.fromJson({
          'id': 'invite-1',
          'senderId': 'alice',
          'senderUsername': 'BA1ABC',
          'recipientId': 'bob',
          'recipientUsername': 'BA2ABC',
          'status': 'pending',
          'kind': 'invitation',
          'role': 'editor',
          'sessionId': 'net-1',
          'sessionTitle': '今晚点名'
        }),
      ]);
    final collaboration = FakeCollaboration();
    await pumpSocial(tester, social, collaboration);
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BA1ABC'), findsOneWidget);
    await tester.tap(find.text('接受'));
    await tester.pumpAndSettle();
    expect(social.calls.single[1], '/session-requests/invite-1/accept');
    expect(collaboration.opened, 'net-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed initial snapshot leaves an accepted invitation available to retry',
      (tester) async {
    final request = {
      'id': 'invite-2',
      'senderId': 'alice',
      'senderUsername': 'BA1ABC',
      'recipientId': 'bob',
      'recipientUsername': 'BA2ABC',
      'status': 'pending',
      'kind': 'invitation',
      'role': 'viewer',
      'sessionId': 'net-2',
      'sessionTitle': '点名'
    };
    final social = FakeSocial()
      ..snapshot =
          SocialSnapshot(sessionRequests: [SocialRequest.fromJson(request)]);
    social.afterMutation = () {
      social.snapshot = SocialSnapshot(sessionRequests: [
        SocialRequest.fromJson({...request, 'status': 'accepted'})
      ]);
      social.notifyListeners();
    };
    final collaboration = FakeCollaboration()..failOpen = true;
    await pumpSocial(tester, social, collaboration);
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接受'));
    await tester.pumpAndSettle();
    expect(find.text('打开会话'), findsOneWidget);
    collaboration.failOpen = false;
    await tester.tap(find.text('打开会话'));
    await tester.pumpAndSettle();
    expect(collaboration.opened, 'net-2');
    expect(social.calls.length, 1);
  });
}

Future<void> pumpSocial(
    WidgetTester tester, FakeSocial social, FakeCollaboration collaboration,
    {Brightness brightness = Brightness.light,
    Locale locale = const Locale('zh', 'CN'),
    int initialTab = 0,
    bool asChildRoute = false,
    List<NavigatorObserver> observers = const [],
    VoidCallback? onSessionOpened}) async {
  final screen =
      SocialScreen(initialTab: initialTab, onSessionOpened: onSessionOpened);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AccountShareProvider>(create: (_) => social),
        ChangeNotifierProvider<CollaborationProvider>(
            create: (_) => collaboration),
        ChangeNotifierProvider<SessionProvider>(create: (_) => FakeSessions()),
        ChangeNotifierProvider<ServerProvider>(
            create: (_) => ServerProvider(autoLoadSettings: false)),
      ],
      child: MaterialApp(
          navigatorObservers: observers,
          theme: buildAppTheme(brightness: brightness, seedColor: Colors.teal),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: asChildRoute
              ? Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          key: const Key('test-open-social'),
                          onPressed: () => Navigator.push<void>(context,
                              MaterialPageRoute(builder: (_) => screen)),
                          child: const Text('open messages'))))
              : screen)));
  await tester.pumpAndSettle();
}

class FakeSocial extends AccountShareProvider {
  String scope = 'current-account';
  bool directSupport = false;
  final queries = <String>[];
  SocialUserSearchPage searchPage = const SocialUserSearchPage(items: [
    SocialUserSearchResult(
        userId: 'alice', username: 'BA1ABC', relationship: 'none')
  ]);
  Future<SocialUserSearchPage> Function(String)? searchHandler;
  @override
  String get accountScope => scope;
  @override
  bool get supportsDirectJoin => directSupport;
  @override
  Future<SocialUserSearchPage> searchUsers(String query) async {
    queries.add(query);
    return searchHandler == null ? searchPage : await searchHandler!(query);
  }

  SocialSnapshot snapshot = const SocialSnapshot();
  final calls = <List<Object?>>[];
  VoidCallback? afterMutation;
  Future<void>? mutationBarrier;
  @override
  bool get supportsFriends => true;
  @override
  String get accountId => 'bob';
  @override
  SocialSnapshot get social => snapshot;
  @override
  int get pendingInboundCount =>
      snapshot.sessionRequests.where((r) => r.status == 'pending').length;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> mutateSocial(String method, String path,
      [Map<String, Object?> body = const {}]) async {
    calls.add([method, path, body]);
    if (mutationBarrier != null) await mutationBarrier;
    afterMutation?.call();
  }
}

SocialSnapshot _incomingInvitation() => SocialSnapshot(sessionRequests: [
      SocialRequest.fromJson({
        'id': 'invite-1',
        'senderId': 'alice',
        'senderUsername': 'BG5CRL',
        'recipientId': 'bob',
        'recipientUsername': 'BA2ABC',
        'status': 'pending',
        'kind': 'invitation',
        'role': 'viewer',
        'sessionId': 'net-1',
        'sessionTitle': '共享会话',
      })
    ]);

class FakeCollaboration extends CollaborationProvider {
  String? opened;
  bool failOpen = false;
  @override
  Future<void> openJoinedSession(String sessionId) async {
    if (failOpen) throw StateError('offline');
    opened = sessionId;
  }
}

class FakeSessions extends ChangeNotifier implements SessionProvider {
  @override
  Session? get currentSession => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
