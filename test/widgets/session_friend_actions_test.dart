import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/widgets/session_friend_actions.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'invite retries remain in the dialog and duplicate taps cannot send twice',
      (tester) async {
    final server = _Server();
    final social = _Social();
    final wait = Completer<void>();
    social.send = () => wait.future;
    await _pump(tester, server, social);
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('send-session-friend-invite'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(social.calls, 1);
    wait.completeError(StateError('connection lost'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('session-friend-invite-dialog')), findsOneWidget);
    expect(find.textContaining('connection lost'), findsOneWidget);
    social.send = () async {};
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(social.calls, 2);
    expect(find.byKey(const Key('session-friend-invite-dialog')), findsNothing);
  });

  testWidgets(
      'an account change disables a pending dialog and hides the former friend list',
      (tester) async {
    final server = _Server();
    final social = _Social();
    await _pump(tester, server, social);
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    server.switchAccount();
    await tester.pumpAndSettle();
    expect(find.text('BA2ABC'), findsNothing);
    expect(find.text('Private session'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('send-session-friend-invite')))
            .onPressed,
        isNull);
    expect(social.calls, 0);
    expect(find.textContaining('服务器、账号或当前会话已切换'), findsOneWidget);
  });

  testWidgets(
      'a response after account switch cannot report successful invitation',
      (tester) async {
    final server = _Server();
    final social = _Social();
    final wait = Completer<void>();
    social.send = () => wait.future;
    SessionInvitationResult? result;
    await _pump(tester, server, social, onResult: (value) => result = value);
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-session-friend-invite')));
    await tester.pump();
    server.switchAccount();
    await tester.pump();
    wait.complete();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
        find.byKey(const Key('session-friend-invite-dialog')), findsOneWidget);
  });

  testWidgets(
      'removing the selected friend does not silently select someone else',
      (tester) async {
    final social = _Social();
    await _pump(tester, _Server(), social);
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    social.friendName = 'BA3NEW';
    social.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('BA2ABC'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('send-session-friend-invite')))
            .onPressed,
        isNull);
    expect(social.calls, 0);
  });

  testWidgets(
      'empty friend list on a small English screen offers adding friends without sending',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final social = _Social()..hasFriends = false;
    SessionInvitationResult? result;
    await _pump(tester, _Server(), social,
        locale: const Locale('en', 'US'), onResult: (value) => result = value);
    await tester.tap(find.text('invite'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('send-session-friend-invite')), findsNothing);
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    expect(result, SessionInvitationResult.friends);
    expect(social.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'switching accounts while upload consent is open prevents publishing',
      (tester) async {
    final server = _Server();
    final collaboration = _Collaboration();
    Object? error;
    await _pump(tester, server, _Social(),
        collaboration: collaboration, onError: (value) => error = value);
    await tester.tap(find.text('publish'));
    await tester.pumpAndSettle();
    server.switchAccount();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-session-upload')));
    await tester.pumpAndSettle();
    expect(collaboration.publishCalls, 0);
    expect(error, isA<StateError>());
  });
}

Future<void> _pump(
  WidgetTester tester,
  _Server server,
  _Social social, {
  Locale locale = const Locale('zh', 'CN'),
  void Function(SessionInvitationResult?)? onResult,
  void Function(Object)? onError,
  _Collaboration? collaboration,
}) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<ServerProvider>(create: (_) => server),
      ChangeNotifierProvider<AccountShareProvider>(create: (_) => social),
      ChangeNotifierProvider<CollaborationProvider>(
          create: (_) => collaboration ?? _Collaboration()),
      ChangeNotifierProvider<SessionProvider>(create: (_) => _Sessions()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: Builder(
              builder: (context) => Column(children: [
                    TextButton(
                        onPressed: () async {
                          final result = await showSessionInvitationDialog(
                              context,
                              sessionId: 'current-session',
                              sessionTitle: 'Private session');
                          onResult?.call(result);
                        },
                        child: const Text('invite')),
                    TextButton(
                        onPressed: () async {
                          try {
                            await confirmAndPublishCurrentSession(context);
                          } catch (error) {
                            onError?.call(error);
                          }
                        },
                        child: const Text('publish')),
                  ]))),
    ),
  ));
  await tester.pumpAndSettle();
}

class _Server extends ServerProvider {
  _Server() : super(autoLoadSettings: false);
  String id = 'alice';
  @override
  bool get isLoggedIn => true;
  @override
  String get serverUrl => 'https://example.test';
  @override
  String get accountId => id;
  void switchAccount() {
    id = 'carol';
    notifyListeners();
  }
}

class _Social extends AccountShareProvider {
  int calls = 0;
  bool hasFriends = true;
  String friendName = 'BA2ABC';
  Future<void> Function() send = () async {};
  @override
  bool get supportsFriends => true;
  @override
  SocialSnapshot get social => SocialSnapshot(friends: [
        if (hasFriends)
          SocialPerson.fromJson({'userId': 'bob', 'username': friendName}),
      ]);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> mutateSocial(String method, String path,
      [Map<String, Object?> body = const {}]) async {
    calls++;
    await send();
  }
}

class _Collaboration extends CollaborationProvider {
  int publishCalls = 0;
  @override
  Future<void> publishCurrentSession() async {
    publishCalls++;
  }
}

class _Sessions extends ChangeNotifier implements SessionProvider {
  @override
  Session get currentSession => const Session(
      sessionId: 'current-session',
      title: 'Private session',
      status: 'active',
      createdAt: '2026-10-04',
      updatedAt: '2026-10-04');
  @override
  String get currentSessionId => 'current-session';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
