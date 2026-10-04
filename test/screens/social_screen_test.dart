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
import 'package:openlogtool/src/bridge/models/session.dart';

void main() {
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
    await tester.tap(find.text('发送申请'));
    await tester.pumpAndSettle();
    expect(social.calls.single, [
      'POST',
      '/friend-requests',
      {'username': 'BA1ABC'}
    ]);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.text('消息 (1)'));
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
    await tester.tap(find.text('消息 (1)'));
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

Future<void> pumpSocial(WidgetTester tester, FakeSocial social,
    FakeCollaboration collaboration) async {
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AccountShareProvider>(create: (_) => social),
        ChangeNotifierProvider<CollaborationProvider>(
            create: (_) => collaboration),
        ChangeNotifierProvider<SessionProvider>(create: (_) => FakeSessions()),
        ChangeNotifierProvider<ServerProvider>(
            create: (_) => ServerProvider(autoLoadSettings: false)),
      ],
      child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SocialScreen())));
  await tester.pumpAndSettle();
}

class FakeSocial extends AccountShareProvider {
  SocialSnapshot snapshot = const SocialSnapshot();
  final calls = <List<Object?>>[];
  VoidCallback? afterMutation;
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
    afterMutation?.call();
  }
}

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
