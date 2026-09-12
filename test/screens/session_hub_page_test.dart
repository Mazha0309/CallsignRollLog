import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/screens/collaboration_screen.dart';
import 'package:openlogtool/screens/session_hub_page.dart';
import 'package:openlogtool/src/bridge/models/log_entry.dart' as bridge_log;
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SessionHubPage uses the shared responsive section surfaces',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (_, __, ___) async => [],
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();

    // The shell AppBar is the only page-level heading. The body starts with
    // the current-session card instead of repeating the destination title.
    expect(find.byType(SettingsPageHeader), findsNothing);
    expect(find.byKey(const Key('session-hub-page-header')), findsNothing);
    expect(find.byKey(const Key('current-session-section')), findsOneWidget);
    expect(find.byKey(const Key('session-history-section')), findsOneWidget);
    expect(find.byType(SettingsSectionCard), findsAtLeastNWidgets(2));
    expect(find.byKey(const Key('open-live-share-management')), findsOneWidget);
    expect(find.byKey(const Key('join-collaboration')), findsOneWidget);
    expect(find.byKey(const Key('create-session')), findsOneWidget);
    expect(find.byKey(const Key('session-history-search')), findsOneWidget);
    expect(find.text('仅在本机关闭会话'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('database replacement and clear refresh cached history entries',
      (tester) async {
    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (_, __, ___) async => [],
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('导入的历史点名'), findsNothing);

    sessionProvider.simulateDatabaseReplacement([
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
      _session(
        id: 'imported-session',
        title: '导入的历史点名',
        status: 'closed',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('导入的历史点名'), findsOneWidget);

    sessionProvider.simulateDatabaseReplacement(const []);
    await tester.pumpAndSettle();

    expect(find.text('导入的历史点名'), findsNothing);
    expect(find.text('暂无历史会话'), findsOneWidget);
  });

  test('controller display prefers saved records over a stale live draft',
      () async {
    final logs = LogProvider(
      sessionListLoader: () async => [
        _session(
          id: 'current-session',
          title: '本周点名',
          status: 'active',
        ),
      ],
      sessionLogPageLoader: (_, __, ___) async => [
        _bridgeLog('row-1', 'BG5AAA'),
        _bridgeLog('row-2', 'BG5BBB'),
        _bridgeLog('row-3', 'BG5CCC'),
      ],
    );
    await logs.reloadForSession('current-session');
    final collaboration = _StaleOrdinalCollaborationProvider();

    final display = SessionHubPage.displayDataFor(
      '本周点名',
      logs,
      collaboration,
    );

    expect(display.currentOrdinal, 4);
    expect(display.totalRecords, 3);
  });

  testWidgets(
      'joining collaboration from the hub does not require a local session',
      (tester) async {
    final sessionProvider = _FakeSessionProvider(
      sessions: [],
      currentSessionId: null,
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => [],
      sessionLogPageLoader: (_, __, ___) async => [],
    );
    final collaboration = _JoinTrackingCollaborationProvider();
    addTearDown(collaboration.dispose);

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
        collaborationProvider: collaboration,
        serverProvider: _LoggedInServerProvider(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join-collaboration')), findsOneWidget);
    await tester.tap(find.byKey(const Key('join-collaboration')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('join-collaboration-code')),
      'ABCDE-12345',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-join-collaboration')));
    await tester.pumpAndSettle();

    expect(collaboration.joinedCodes, ['ABCDE-12345']);
    expect(find.byKey(const Key('workbench-after-history')), findsOneWidget);
  });

  testWidgets('joining collaboration without login shows the server hint',
      (tester) async {
    final sessionProvider = _FakeSessionProvider(
      sessions: [],
      currentSessionId: null,
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => [],
      sessionLogPageLoader: (_, __, ___) async => [],
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('join-collaboration')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join-collaboration-dialog')), findsNothing);
    expect(
      find.textContaining('请先在“设置 → 服务器与账户”中检测服务器并登录'),
      findsOneWidget,
    );
  });

  testWidgets('creating a session returns directly to the workbench',
      (tester) async {
    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (_, __, ___) async => [],
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-session')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create-session-name')),
      '周五晚间点名',
    );
    await tester.tap(find.byKey(const Key('confirm-create-session')));
    await tester.pumpAndSettle();

    expect(sessionProvider.startedTitles, ['周五晚间点名']);
    expect(sessionProvider.currentSession!.title, '周五晚间点名');
    expect(find.byKey(const Key('workbench-after-history')), findsOneWidget);
  });

  testWidgets(
      'closed collaboration history opens management and cannot reopen locally',
      (tester) async {
    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
      _session(
        id: 'shared-session',
        title: '远程协作点名',
        status: 'closed',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
      collaborationSessionIds: const {'shared-session'},
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (_, __, ___) async => [],
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reopen-history-session-shared-session')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('open-history-session-shared-session')),
      findsOneWidget,
    );
    expect(find.text('打开并管理协作'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-history-session-shared-session')).first,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const Key('open-history-session-shared-session')).first,
    );
    await tester.pumpAndSettle();

    expect(sessionProvider.currentSessionId, 'shared-session');
    expect(find.byType(CollaborationScreen), findsOneWidget);
  });

  testWidgets(
      'SessionHubPage exposes a direct Live Share entry for the current session',
      (tester) async {
    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (_, __, ___) async => [],
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('open-live-share-management'));
    expect(entry, findsOneWidget);
    expect(find.text('Live Share 公开页面'), findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('public-share-access-required')),
      findsOneWidget,
    );
  });

  testWidgets(
    'SessionHubPage opens a closed history session and returns to workbench',
    (tester) async {
      final sessions = [
        _session(
          id: 'current-session',
          title: '本周点名',
          status: 'active',
        ),
        _session(
          id: 'closed-session',
          title: '上周点名',
          status: 'closed',
        ),
      ];
      final sessionProvider = _FakeSessionProvider(
        sessions: sessions,
        currentSessionId: 'current-session',
      );
      final loadedSessionIds = <String>[];
      final logProvider = LogProvider(
        sessionListLoader: () async => sessions,
        sessionLogPageLoader: (sessionId, page, pageSize) async {
          loadedSessionIds.add(sessionId);
          return [];
        },
      );

      await tester.pumpWidget(
        _SessionHubTestApp(
          sessionProvider: sessionProvider,
          logProvider: logProvider,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('session-history-row-closed-session')).first,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('上周点名'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('session-history-row-closed-session')).first,
      );
      await tester.pumpAndSettle();

      expect(sessionProvider.currentSessionId, 'closed-session');
      expect(loadedSessionIds, contains('closed-session'));
      expect(logProvider.currentSessionReadOnly, isTrue);
      expect(find.byKey(const Key('workbench-after-history')), findsOneWidget);
    },
  );

  testWidgets('SessionHubPage keeps the dialog open when loading logs fails',
      (tester) async {
    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
      _session(
        id: 'broken-session',
        title: '损坏的历史会话',
        status: 'closed',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
    );
    final loadedSessionIds = <String>[];
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (sessionId, page, pageSize) async {
        loadedSessionIds.add(sessionId);
        if (sessionId == 'broken-session') {
          throw StateError('broken log page');
        }
        return [];
      },
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('session-history-row-broken-session')).first,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const Key('session-history-row-broken-session')).first,
    );
    await tester.pumpAndSettle();

    expect(sessionProvider.currentSessionId, 'current-session');
    expect(
        loadedSessionIds,
        containsAllInOrder([
          'broken-session',
          'current-session',
        ]));
    expect(find.byKey(const Key('session-history-section')), findsOneWidget);
    expect(find.textContaining('打开会话失败'), findsOneWidget);
    expect(find.byKey(const Key('workbench-after-history')), findsNothing);
  });

  testWidgets(
      'current closed local session has a visible reactivate action and returns to workbench',
      (tester) async {
    final sessions = [
      _session(
        id: 'closed-session',
        title: '上周点名',
        status: 'closed',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'closed-session',
    );
    final loadedSessionIds = <String>[];
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (sessionId, page, pageSize) async {
        loadedSessionIds.add(sessionId);
        return [];
      },
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reopen-current-local-session')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('reopen-current-local-session')),
    );
    await tester.pumpAndSettle();
    expect(find.text('重新激活本地会话'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('confirm-reopen-local-session')),
    );
    await tester.pumpAndSettle();

    expect(sessionProvider.currentSession!.status, 'active');
    expect(sessionProvider.currentSessionId, 'closed-session');
    expect(loadedSessionIds, contains('closed-session'));
    expect(logProvider.currentSessionReadOnly, isFalse);
    expect(find.byKey(const Key('workbench-after-history')), findsOneWidget);
  });

  testWidgets(
      'reactivating a non-current history session selects it and makes logs writable',
      (tester) async {
    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
      _session(
        id: 'closed-session',
        title: '上周点名',
        status: 'closed',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
    );
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (_, __, ___) async => [],
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('reopen-history-session-closed-session')).first,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const Key('reopen-history-session-closed-session')).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-reopen-local-session')),
    );
    await tester.pumpAndSettle();

    expect(sessionProvider.currentSessionId, 'closed-session');
    expect(sessionProvider.currentSession!.status, 'active');
    expect(logProvider.currentSessionReadOnly, isFalse);
    expect(find.byKey(const Key('workbench-after-history')), findsOneWidget);
    final refreshedSessions = await sessionProvider.listAvailableSessions();
    expect(
      refreshedSessions
          .singleWhere((session) => session.sessionId == 'current-session')
          .status,
      'closed',
    );
  });

  testWidgets(
      'reactivated history session stays selected but read-only when logs fail to load',
      (tester) async {
    final sessions = [
      _session(
        id: 'current-session',
        title: '本周点名',
        status: 'active',
      ),
      _session(
        id: 'broken-session',
        title: '日志损坏场次',
        status: 'closed',
      ),
    ];
    final sessionProvider = _FakeSessionProvider(
      sessions: sessions,
      currentSessionId: 'current-session',
    );
    var brokenLoadAttempts = 0;
    final logProvider = LogProvider(
      sessionListLoader: () async => sessions,
      sessionLogPageLoader: (sessionId, _, __) async {
        if (sessionId == 'broken-session' && brokenLoadAttempts++ == 0) {
          throw StateError('broken reopened log page');
        }
        return [];
      },
    );

    await tester.pumpWidget(
      _SessionHubTestApp(
        sessionProvider: sessionProvider,
        logProvider: logProvider,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('reopen-history-session-broken-session')).first,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const Key('reopen-history-session-broken-session')).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-reopen-local-session')),
    );
    await tester.pumpAndSettle();

    expect(sessionProvider.currentSessionId, 'broken-session');
    expect(sessionProvider.currentSession!.status, 'active');
    expect(logProvider.currentSessionId, 'broken-session');
    expect(logProvider.currentSessionReadOnly, isTrue);
    expect(find.textContaining('已重新激活，但日志暂时加载失败'), findsOneWidget);
    expect(find.byKey(const Key('workbench-after-history')), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(brokenLoadAttempts, 2);
    expect(logProvider.currentSessionId, 'broken-session');
    expect(logProvider.currentSessionReadOnly, isFalse);
  });
}

class _SessionHubTestApp extends StatefulWidget {
  const _SessionHubTestApp({
    required this.sessionProvider,
    required this.logProvider,
    this.collaborationProvider,
    this.serverProvider,
  });

  final SessionProvider sessionProvider;
  final LogProvider logProvider;
  final CollaborationProvider? collaborationProvider;
  final ServerProvider? serverProvider;

  @override
  State<_SessionHubTestApp> createState() => _SessionHubTestAppState();
}

class _SessionHubTestAppState extends State<_SessionHubTestApp> {
  bool _showWorkbench = false;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionProvider>.value(
            value: widget.sessionProvider,
          ),
          ChangeNotifierProvider<LogProvider>.value(value: widget.logProvider),
          if (widget.collaborationProvider != null)
            ChangeNotifierProvider<CollaborationProvider>.value(
              value: widget.collaborationProvider!,
            )
          else
            ChangeNotifierProvider(create: (_) => CollaborationProvider()),
          if (widget.serverProvider != null)
            ChangeNotifierProvider<ServerProvider>.value(
              value: widget.serverProvider!,
            )
          else
            ChangeNotifierProvider(
              create: (_) => ServerProvider(autoLoadSettings: false),
            ),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _showWorkbench
                ? const Text(
                    'workbench',
                    key: Key('workbench-after-history'),
                  )
                : SessionHubPage(
                    onSessionOpened: () {
                      setState(() => _showWorkbench = true);
                    },
                  ),
          ),
        ),
      );
}

class _StaleOrdinalCollaborationProvider extends CollaborationProvider {
  @override
  LiveDraftSnapshotDto get liveDraftSnapshot => LiveDraftSnapshotDto(
        draft: LiveDraftDto(
          draftId: 'draft-1',
          sessionId: 'current-session',
          version: 1,
          fields: LiveDraftFieldsDto(const {}),
          fieldRevisions: const {},
          lastUpdatedBy: null,
          createdAt: DateTime.utc(2026, 7, 13),
          lastUpdatedAt: DateTime.utc(2026, 7, 13),
        ),
        locks: const [],
        currentOrdinal: 1,
        totalRecords: 0,
        previousRecord: null,
      );
}

bridge_log.LogEntry _bridgeLog(String syncId, String callsign) =>
    bridge_log.LogEntry(
      syncId: syncId,
      sessionId: 'current-session',
      time: '2026-07-26T09:20:46.808Z',
      controller: 'BG5CTRL',
      callsign: callsign,
      rstSent: '59',
      rstRcvd: '59',
      createdAt: '2026-07-26T09:20:46.808Z',
      updatedAt: '2026-07-26T09:20:46.808Z',
    );

class _JoinTrackingCollaborationProvider extends CollaborationProvider {
  final List<String> joinedCodes = [];

  @override
  Future<void> joinWithCode(String code) async {
    joinedCodes.add(code);
  }
}

class _LoggedInServerProvider extends ServerProvider {
  _LoggedInServerProvider() : super(autoLoadSettings: false);

  @override
  bool get isLoggedIn => true;

  @override
  String get serverUrl => 'http://127.0.0.1:3000';

  @override
  String? get accountId => 'user-1';
}

class _FakeSessionProvider extends SessionProvider {
  _FakeSessionProvider({
    required List<Session> sessions,
    required String? currentSessionId,
    Set<String> collaborationSessionIds = const {},
  })  : _sessions = sessions,
        _collaborationSessionIds = collaborationSessionIds,
        _currentSession = currentSessionId == null
            ? null
            : sessions.firstWhere(
                (session) => session.sessionId == currentSessionId,
              );

  final List<Session> _sessions;
  final Set<String> _collaborationSessionIds;
  Session? _currentSession;
  int _databaseRevision = 0;
  final List<String?> startedTitles = [];

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get currentSessionId => _currentSession?.sessionId;

  @override
  Session? get currentSession => _currentSession;

  @override
  int get databaseRevision => _databaseRevision;

  void simulateDatabaseReplacement(List<Session> sessions) {
    final previousSessionId = _currentSession?.sessionId;
    _sessions
      ..clear()
      ..addAll(sessions);
    _currentSession = previousSessionId == null
        ? null
        : sessions
            .where((session) => session.sessionId == previousSessionId)
            .firstOrNull;
    _databaseRevision++;
    notifyListeners();
  }

  @override
  Future<List<Session>> listAvailableSessions() async => [..._sessions];

  @override
  Future<List<SessionListEntry>> listAvailableSessionEntries() async => [
        for (final session in _sessions)
          SessionListEntry(
            session: session,
            hasCollaborationBinding:
                _collaborationSessionIds.contains(session.sessionId),
          ),
      ];

  @override
  Future<void> startNewSession({
    String? title,
    bool autoGenerated = false,
  }) async {
    startedTitles.add(title);
    final created = _session(
      id: 'created-session-${_sessions.length}',
      title: title ?? '新记录',
      status: 'active',
    );
    for (var index = 0; index < _sessions.length; index += 1) {
      final existing = _sessions[index];
      if (existing.status == 'active' &&
          !_collaborationSessionIds.contains(existing.sessionId)) {
        _sessions[index] = Session(
          sessionId: existing.sessionId,
          title: existing.title,
          status: 'closed',
          shareCode: existing.shareCode,
          createdAt: existing.createdAt,
          updatedAt: created.createdAt,
          closedAt: created.createdAt,
          deletedAt: existing.deletedAt,
        );
      }
    }
    _sessions.add(created);
    _currentSession = created;
    notifyListeners();
  }

  @override
  Future<void> switchToSession(String sessionId) async {
    _currentSession = _sessions.firstWhere(
      (session) => session.sessionId == sessionId,
    );
    notifyListeners();
  }

  @override
  Future<void> reloadCurrentSession() async {
    final currentSessionId = _currentSession?.sessionId;
    if (currentSessionId == null) return;
    _currentSession = _sessions.firstWhere(
      (session) => session.sessionId == currentSessionId,
    );
    notifyListeners();
  }

  @override
  Future<void> reopenLocalSession(String sessionId) async {
    for (var candidate = 0; candidate < _sessions.length; candidate += 1) {
      final existing = _sessions[candidate];
      if (existing.sessionId != sessionId && existing.status == 'active') {
        _sessions[candidate] = Session(
          sessionId: existing.sessionId,
          title: existing.title,
          status: 'closed',
          shareCode: existing.shareCode,
          createdAt: existing.createdAt,
          updatedAt: '2026-07-13T12:00:00Z',
          closedAt: '2026-07-13T12:00:00Z',
          deletedAt: existing.deletedAt,
        );
      }
    }
    final index = _sessions.indexWhere(
      (session) => session.sessionId == sessionId,
    );
    if (index < 0) throw StateError('Session not found: $sessionId');
    final previous = _sessions[index];
    final reopened = Session(
      sessionId: previous.sessionId,
      title: previous.title,
      status: 'active',
      shareCode: previous.shareCode,
      createdAt: previous.createdAt,
      updatedAt: '2026-07-13T12:00:00Z',
      closedAt: null,
      deletedAt: previous.deletedAt,
    );
    _sessions[index] = reopened;
    _currentSession = reopened;
    notifyListeners();
  }
}

Session _session({
  required String id,
  required String title,
  required String status,
}) =>
    Session(
      sessionId: id,
      title: title,
      status: status,
      createdAt: '2026-07-13T10:00:00Z',
      updatedAt: '2026-07-13T11:00:00Z',
      closedAt: status == 'closed' ? '2026-07-13T11:00:00Z' : null,
    );
