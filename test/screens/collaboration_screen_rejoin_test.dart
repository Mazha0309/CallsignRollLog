import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/screens/collaboration_screen.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('invite joining remains available for revoked and failed rejoin states',
      () {
    final binding = _binding();
    final revoked = _TestCollaborationProvider(
      binding: binding,
      state: CollaborationState.revoked,
    );
    final failedRejoin = _TestCollaborationProvider(
      binding: binding,
      state: CollaborationState.failed,
      failedOperation: 'join',
    );
    final ready = _TestCollaborationProvider(
      binding: binding,
      state: CollaborationState.ready,
    );
    final firstJoin = _TestCollaborationProvider(
      binding: null,
      state: CollaborationState.localOnly,
    );
    addTearDown(revoked.dispose);
    addTearDown(failedRejoin.dispose);
    addTearDown(ready.dispose);
    addTearDown(firstJoin.dispose);

    expect(revoked.canJoinWithInvite, isTrue);
    expect(failedRejoin.canJoinWithInvite, isTrue);
    expect(firstJoin.canJoinWithInvite, isTrue);
    expect(ready.canJoinWithInvite, isFalse);
  });

  testWidgets('a revoked member can submit a new invite from the bound session',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final collaboration = _TestCollaborationProvider(
      binding: _binding(),
      state: CollaborationState.revoked,
    );
    final server = _LoggedInServerProvider();
    final sessions = _TestSessionProvider();
    addTearDown(collaboration.dispose);
    addTearDown(server.dispose);
    addTearDown(sessions.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CollaborationProvider>.value(
            value: collaboration,
          ),
          ChangeNotifierProvider<ServerProvider>.value(value: server),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CollaborationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join-collaboration-card')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('collaboration-invite-code')),
      'ABCDE12345',
    );
    final joinButton = find.byKey(const Key('join-collaboration-button'));
    await tester.ensureVisible(joinButton);
    await tester.tap(joinButton);
    await tester.pumpAndSettle();

    expect(collaboration.joinedCodes, ['ABCDE12345']);
  });

  testWidgets(
      'offline collaboration exposes no destructive detach or local end',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final collaboration = _TestCollaborationProvider(
      binding: _binding(role: SessionRole.owner),
      state: CollaborationState.failed,
    );
    final server = _OfflineServerProvider();
    final sessions = _TestSessionProvider();
    addTearDown(collaboration.dispose);
    addTearDown(server.dispose);
    addTearDown(sessions.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CollaborationProvider>.value(
            value: collaboration,
          ),
          ChangeNotifierProvider<ServerProvider>.value(value: server),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CollaborationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('convert-collaboration-to-local')), findsNothing);
    expect(find.byKey(const Key('close-collaboration-locally')), findsNothing);
    expect(collaboration.localStopCalls, 0);
    expect(find.textContaining('切换页面或暂时断网不会退出协作'), findsOneWidget);
    expect(find.text('连接暂时不可用，已有记录仍保留在本机。'), findsOneWidget);
    expect(find.text('session-1'), findsNothing);
    final diagnostics = find
        .byKey(const PageStorageKey<String>('collaboration-technical-details'));
    await tester.ensureVisible(diagnostics);
    await tester
        .tap(find.descendant(of: diagnostics, matching: find.text('连接与诊断详情')));
    await tester.pumpAndSettle();
    expect(find.text('session-1'), findsOneWidget);
  });

  testWidgets('current collaboration data can be deleted only on this device',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final collaboration = _TestCollaborationProvider(
      binding: _binding(role: SessionRole.owner),
      state: CollaborationState.failed,
    );
    final server = _OfflineServerProvider();
    final sessions = _TestSessionProvider();
    addTearDown(collaboration.dispose);
    addTearDown(server.dispose);
    addTearDown(sessions.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CollaborationProvider>.value(
            value: collaboration,
          ),
          ChangeNotifierProvider<ServerProvider>.value(value: server),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CollaborationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final more = find.byKey(const Key('more-local-collaboration-actions'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-collaboration-locally')));
    await tester.pumpAndSettle();

    expect(find.textContaining('不会删除或关闭服务器上的共享会话'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('delete-current-collaboration-name')),
      'Revoked session',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const Key('confirm-delete-current-collaboration-locally'),
      ),
    );
    await tester.pumpAndSettle();

    expect(collaboration.localDeleteCalls, 1);
    expect(find.text('已永久删除本机会话'), findsOneWidget);
  });

  testWidgets('editable local copy remains available as a non-destructive path',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final collaboration = _TestCollaborationProvider(
      binding: _binding(role: SessionRole.owner),
      state: CollaborationState.failed,
    );
    final server = _OfflineServerProvider();
    final sessions = _TestSessionProvider();
    addTearDown(collaboration.dispose);
    addTearDown(server.dispose);
    addTearDown(sessions.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CollaborationProvider>.value(
            value: collaboration,
          ),
          ChangeNotifierProvider<ServerProvider>.value(value: server),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CollaborationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final more = find.byKey(const Key('more-local-collaboration-actions'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-editable-local-copy')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-create-editable-local-copy')),
    );
    await tester.pumpAndSettle();

    expect(collaboration.localCopyTitles, ['Revoked session（本地副本）']);
    expect(find.text('已另存并切换到独立会话，原协作会话已保留'), findsOneWidget);
  });

  testWidgets(
      'online session saves a copy without stopping or replacing collaboration',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final collaboration = _TestCollaborationProvider(
      binding: _binding(role: SessionRole.owner),
      state: CollaborationState.ready,
      directConversionReady: true,
    );
    final server = _LoggedInServerProvider();
    final sessions = _TestSessionProvider();
    addTearDown(collaboration.dispose);
    addTearDown(server.dispose);
    addTearDown(sessions.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CollaborationProvider>.value(
            value: collaboration,
          ),
          ChangeNotifierProvider<ServerProvider>.value(value: server),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CollaborationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('convert-collaboration-to-local')), findsNothing);
    expect(find.byKey(const Key('close-collaboration-locally')), findsNothing);
    final more = find.byKey(const Key('more-local-collaboration-actions'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-editable-local-copy')));
    await tester.pumpAndSettle();
    expect(find.textContaining('原协作会话和你的成员身份不变'), findsOneWidget);
    expect(find.textContaining('也不会删除'), findsOneWidget);
    await tester
        .tap(find.byKey(const Key('confirm-create-editable-local-copy')));
    await tester.pumpAndSettle();
    expect(collaboration.localCopyTitles, ['Revoked session（本地副本）']);
    expect(collaboration.directConversionCalls, 0);
    expect(collaboration.localStopCalls, 0);
  });
  for (final switchAccount in [false, true]) {
    testWidgets(
        'member leave changes only membership; stale context=$switchAccount',
        (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final collaboration = _TestCollaborationProvider(
        binding: _binding(role: SessionRole.editor),
        state: CollaborationState.ready,
      );
      final server = _LoggedInServerProvider();
      final sessions = _TestSessionProvider();
      addTearDown(collaboration.dispose);
      addTearDown(server.dispose);
      addTearDown(sessions.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CollaborationProvider>.value(
              value: collaboration),
          ChangeNotifierProvider<ServerProvider>.value(value: server),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CollaborationScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('close-collaboration-session')), findsNothing);
      final leave = find.widgetWithText(OutlinedButton, '离开协作');
      await tester.ensureVisible(leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(find.textContaining('其他成员可继续记录'), findsOneWidget);
      expect(find.textContaining('只是暂时离开页面，无需退出协作'), findsOneWidget);
      if (switchAccount) server.testContextRevision++;
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();
      expect(collaboration.leaveCalls, switchAccount ? 0 : 1);
      expect(collaboration.localCopyTitles, isEmpty);
      expect(collaboration.localStopCalls, 0);
      expect(collaboration.directConversionCalls, 0);
      expect(collaboration.localDeleteCalls, 0);
    });
  }
}

LocalCollaborationBinding _binding({
  SessionRole role = SessionRole.viewer,
}) =>
    LocalCollaborationBinding(
      serverInstanceId: 'server-1',
      serverOrigin: 'http://127.0.0.1:3000',
      accountId: 'user-1',
      sessionId: 'session-1',
      membershipId: 'membership-1',
      membershipVersion: 2,
      role: role,
      // The in-memory binding can still say ready when the sync coordinator
      // has just persisted revocation and changed the provider state.
      replicaState: 'ready',
      lastAppliedSeq: 4,
      lastSeenHeadSeq: 4,
      revokedAt: null,
    );

class _TestCollaborationProvider extends CollaborationProvider {
  _TestCollaborationProvider({
    required LocalCollaborationBinding? binding,
    required CollaborationState state,
    String? failedOperation,
    this.directConversionReady = false,
  })  : testBinding = binding,
        testState = state,
        testFailedOperation = failedOperation;

  final LocalCollaborationBinding? testBinding;
  final CollaborationState testState;
  final String? testFailedOperation;
  final bool directConversionReady;
  final List<String> joinedCodes = [];
  final List<String> localCopyTitles = [];
  int directConversionCalls = 0;
  int localStopCalls = 0;
  int localDeleteCalls = 0;
  int leaveCalls = 0;

  @override
  SessionRole? get effectiveRole =>
      testState == CollaborationState.ready ? testBinding?.role : null;

  @override
  bool get isOwner => effectiveRole == SessionRole.owner;

  @override
  Future<void> leaveCurrentSession() async => leaveCalls++;

  @override
  LocalCollaborationBinding? get binding => testBinding;

  @override
  CollaborationState get state => testState;

  @override
  String? get failedOperation => testFailedOperation;

  @override
  bool get canConvertCurrentSessionDirectly => directConversionReady;

  @override
  Future<void> refreshCurrentSession() async {}

  @override
  Future<void> joinWithCode(String code) async {
    joinedCodes.add(code);
  }

  @override
  Future<void> createEditableLocalCopy({required String title}) async {
    localCopyTitles.add(title);
  }

  @override
  Future<void> convertCurrentSessionToLocal() async {
    directConversionCalls += 1;
  }

  @override
  Future<void> stopCurrentSessionLocally() async {
    localStopCalls += 1;
  }

  @override
  Future<void> deleteCurrentSessionLocally() async {
    localDeleteCalls += 1;
  }
}

class _LoggedInServerProvider extends ServerProvider {
  _LoggedInServerProvider() : super(autoLoadSettings: false);

  int testContextRevision = 0;

  @override
  int get contextRevision => testContextRevision;

  @override
  bool get isLoggedIn => true;

  @override
  String get serverUrl => 'http://127.0.0.1:3000';

  @override
  String? get accountId => 'user-1';

  @override
  String? get username => 'member';
}

class _OfflineServerProvider extends ServerProvider {
  _OfflineServerProvider() : super(autoLoadSettings: false);

  @override
  bool get isLoggedIn => false;

  @override
  String get serverUrl => 'https://offline.example.test';

  @override
  String? get accountId => null;
}

class _TestSessionProvider extends SessionProvider {
  _TestSessionProvider();

  static const session = Session(
    sessionId: 'session-1',
    title: 'Revoked session',
    status: 'active',
    createdAt: '2026-07-13T00:00:00Z',
    updatedAt: '2026-07-13T00:00:00Z',
  );

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String get currentSessionId => session.sessionId;

  @override
  Session get currentSession => session;
}
