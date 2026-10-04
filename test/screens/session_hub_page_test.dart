import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
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

  testWidgets('local recording can continue without connecting or logging in',
      (tester) async {
    final rows = [
      _session(id: 'current-session', title: '离线点名', status: 'active')
    ];
    await tester.pumpWidget(_SessionHubTestApp(
      sessionProvider: _FakeSessionProvider(
          sessions: rows, currentSessionId: 'current-session'),
      logProvider: LogProvider(
          sessionListLoader: () async => rows,
          sessionLogPageLoader: (_, __, ___) async => []),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-friends')), findsNothing);
    expect(find.byKey(const Key('open-live-share-management')), findsNothing);
    await tester.tap(find.byKey(const Key('continue-current-session')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workbench-after-history')), findsOneWidget);
  });

  testWidgets(
      'record filters use local metadata and preserve collaborative copies while logged out',
      (tester) async {
    final rows = [
      _session(id: 'current-session', title: '当前记录', status: 'active'),
      _session(id: 'my-active', title: '本地进行中', status: 'active'),
      _session(id: 'my-closed', title: '本地已结束', status: 'closed'),
      _session(id: 'shared-active', title: '共同进行中', status: 'active'),
      _session(id: 'shared-closed', title: '共同已结束', status: 'closed'),
    ];
    await tester.pumpWidget(_SessionHubTestApp(
      sessionProvider: _FakeSessionProvider(
          sessions: rows,
          currentSessionId: 'current-session',
          collaborationSessionIds: {'shared-active', 'shared-closed'}),
      logProvider: LogProvider(
          sessionListLoader: () async => rows,
          sessionLogPageLoader: (_, __, ___) async => []),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-collaboration')), findsNothing);
    for (final pair in [
      ('personal', '本地'),
      ('collaboration', '共同'),
      ('closed', '已结束')
    ]) {
      final filter = find.byKey(Key('session-collection-${pair.$1}'));
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      for (final row in rows.skip(1)) {
        expect(find.byKey(Key('session-history-row-${row.sessionId}')),
            row.title.contains(pair.$2) ? findsOneWidget : findsNothing);
      }
    }
    await tester.enterText(
        find.byKey(const Key('session-history-search')), '本地');
    await tester.pumpAndSettle();
    expect(find.text('本地已结束'), findsOneWidget);
    expect(find.text('共同已结束'), findsNothing);
  });

  testWidgets(
      'an owner invites a named friend directly from the current session',
      (tester) async {
    final rows = [
      _session(id: 'current-session', title: '今晚点名', status: 'active')
    ];
    final social = _HubSharingProvider();
    await tester.pumpWidget(_SessionHubTestApp(
      sessionProvider: _FakeSessionProvider(
          sessions: rows, currentSessionId: 'current-session'),
      logProvider: LogProvider(
          sessionListLoader: () async => rows,
          sessionLogPageLoader: (_, __, ___) async => []),
      collaborationProvider: _HubCollaborationProvider(collaborative: true),
      serverProvider: _LoggedInServerProvider(),
      sharingProvider: social,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-current-session-friend')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('session-friend-invite-dialog')), findsOneWidget);
    expect(find.text('BA2ABC'), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-invite-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('只能查看').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-session-friend-invite')));
    await tester.pumpAndSettle();
    expect(social.calls.single, [
      'POST',
      '/sessions/current-session/invitations',
      {'username': 'BA2ABC', 'role': 'viewer'}
    ]);
  });

  testWidgets(
      'ended history refreshes after device-local lifecycle changes without a server',
      (tester) async {
    final rows = [
      _session(id: 'current-session', title: '当前点名', status: 'active'),
      _session(id: 'background-session', title: '本机历史', status: 'active'),
    ];
    final sessions = _FakeSessionProvider(
        sessions: rows, currentSessionId: 'current-session');
    await tester.pumpWidget(_SessionHubTestApp(
      sessionProvider: sessions,
      logProvider: LogProvider(
          sessionListLoader: () async => rows,
          sessionLogPageLoader: (_, __, ___) async => []),
    ));
    await tester.pumpAndSettle();
    final ended = find.byKey(const Key('session-collection-closed'));
    await tester.ensureVisible(ended);
    await tester.pumpAndSettle();
    await tester.tap(ended);
    await tester.pumpAndSettle();
    expect(find.text('本机历史'), findsNothing);
    sessions.simulateLocalClose('background-session');
    await tester.pumpAndSettle();
    expect(find.text('本机历史'), findsOneWidget);
  });

  testWidgets(
      'local-to-collaborative conversion requires upload consent before inviting anyone',
      (tester) async {
    final rows = [
      _session(id: 'current-session', title: '本地私有点名', status: 'active')
    ];
    final collaboration = _HubCollaborationProvider();
    final social = _HubSharingProvider();
    await tester.pumpWidget(_SessionHubTestApp(
      sessionProvider: _FakeSessionProvider(
          sessions: rows, currentSessionId: 'current-session'),
      logProvider: LogProvider(
          sessionListLoader: () async => rows,
          sessionLogPageLoader: (_, __, ___) async => []),
      collaborationProvider: collaboration,
      serverProvider: _LoggedInServerProvider(),
      sharingProvider: social,
    ));
    await tester.pumpAndSettle();
    expect(collaboration.publishCalls, 0);
    final enable =
        find.byKey(const Key('enable-current-session-collaboration'));
    await tester.ensureVisible(enable);
    await tester.pumpAndSettle();
    await tester.tap(enable);
    await tester.pumpAndSettle();
    expect(find.textContaining('此操作只上传当前会话'), findsOneWidget);
    expect(find.text('http://127.0.0.1:3000'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(collaboration.publishCalls, 0);
    expect(social.calls, isEmpty);
    await tester.ensureVisible(enable);
    await tester.pumpAndSettle();
    await tester.tap(enable);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-session-upload')));
    await tester.pumpAndSettle();
    expect(collaboration.publishCalls, 1);
    expect(social.calls, isEmpty);
    expect(
        find.byKey(const Key('session-friend-invite-dialog')), findsOneWidget);
  });

  testWidgets(
      'a logged-out collaborative replica is not presented as an ordinary local session',
      (tester) async {
    final rows = [
      _session(id: 'current-session', title: '协作副本', status: 'active')
    ];
    await tester.pumpWidget(_SessionHubTestApp(
      sessionProvider: _FakeSessionProvider(
          sessions: rows, currentSessionId: 'current-session'),
      logProvider: LogProvider(
          sessionListLoader: () async => rows,
          sessionLogPageLoader: (_, __, ___) async => []),
      collaborationProvider: _HubCollaborationProvider(collaborative: true),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close-current-local-session')), findsNothing);
    expect(find.byKey(const Key('close-collaboration-locally')), findsNothing);
    expect(
        find.byKey(const Key('convert-collaboration-to-local')), findsNothing);
    expect(find.byKey(const Key('delete-current-local-session')), findsNothing);
    expect(
        find.byKey(const Key('open-collaboration-management')), findsOneWidget);
    expect(find.byKey(const Key('create-session')), findsOneWidget);
  });

  testWidgets('collaborative history never offers a local end action',
      (tester) async {
    final rows = [
      _session(id: 'current', title: '本地当前', status: 'active'),
      _session(id: 'shared', title: '共同记录', status: 'active'),
    ];
    await tester.pumpWidget(_SessionHubTestApp(
      sessionProvider: _FakeSessionProvider(
        sessions: rows,
        currentSessionId: 'current',
        collaborationSessionIds: {'shared'},
      ),
      logProvider: LogProvider(
        sessionListLoader: () async => rows,
        sessionLogPageLoader: (_, __, ___) async => [],
      ),
    ));
    await tester.pumpAndSettle();
    final menu = find.byKey(const Key('session-history-menu-shared'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PopupMenuItem<dynamic>, '结束记录'), findsNothing);
    expect(find.text('协作与成员'), findsOneWidget);
    expect(find.text('仅在本机关闭会话'), findsNothing);
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
    expect(find.byKey(const Key('open-live-share-management')), findsNothing);
    expect(find.byKey(const Key('join-collaboration')), findsNothing);
    expect(
        find.byKey(const Key('open-collaboration-management')), findsNothing);
    expect(find.byKey(const Key('continue-current-session')), findsOneWidget);
    expect(find.text('current-session'), findsNothing);
    expect(find.byKey(const Key('create-session')), findsOneWidget);
    expect(find.byKey(const Key('session-history-search')), findsOneWidget);
    expect(find.text('结束记录'), findsOneWidget);
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

  testWidgets(
      'offline first launch offers recording without a login requirement',
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

    expect(find.byKey(const Key('create-session')), findsOneWidget);
    expect(find.byKey(const Key('join-collaboration')), findsNothing);
    expect(find.byKey(const Key('join-collaboration-dialog')), findsNothing);
    expect(find.textContaining('无需服务器或账号'), findsOneWidget);
    expect(find.byKey(const Key('configure-optional-server')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('optional-online-expand')));
    await tester.tap(find.byKey(const Key('optional-online-expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('configure-optional-server')), findsOneWidget);
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
      'Live Share remains available for a connected collaborative session',
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
        collaborationProvider: _HubCollaborationProvider(collaborative: true),
        serverProvider: _LoggedInServerProvider(),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('open-live-share-management'));
    expect(entry, findsOneWidget);
    expect(find.text('Live Share 公开页面'), findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<CollaborationScreen>(find.byType(CollaborationScreen))
            .focusPublicShare,
        isTrue);
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
      'active',
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
    this.sharingProvider,
  });

  final SessionProvider sessionProvider;
  final LogProvider logProvider;
  final CollaborationProvider? collaborationProvider;
  final ServerProvider? serverProvider;
  final AccountShareProvider? sharingProvider;

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
          if (widget.sharingProvider != null)
            ChangeNotifierProvider<AccountShareProvider>.value(
                value: widget.sharingProvider!)
          else
            ChangeNotifierProvider(create: (_) => AccountShareProvider()),
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

  @override
  ServerInfoDto get serverInfo => ServerInfoDto(
      serverInstanceId: 'server-1',
      protocolMin: 1,
      protocolMax: 1,
      features: const ['sessionPublishing', 'friendCollaboration'],
      serverTime: DateTime.utc(2026),
      environment: 'test');
}

class _HubCollaborationProvider extends CollaborationProvider {
  _HubCollaborationProvider({this.collaborative = false});
  bool collaborative;
  int publishCalls = 0;
  @override
  bool get isOwner => collaborative;
  @override
  LocalCollaborationBinding? get binding => !collaborative
      ? null
      : const LocalCollaborationBinding(
          serverInstanceId: 'server-1',
          serverOrigin: 'http://127.0.0.1:3000',
          accountId: 'user-1',
          sessionId: 'current-session',
          membershipId: 'membership-1',
          membershipVersion: 1,
          role: SessionRole.owner,
          replicaState: 'ready',
          lastAppliedSeq: 0,
          lastSeenHeadSeq: 0,
          revokedAt: null);
  @override
  Future<void> publishCurrentSession() async {
    publishCalls++;
    collaborative = true;
    notifyListeners();
  }
}

class _HubSharingProvider extends AccountShareProvider {
  final calls = <List<Object?>>[];
  @override
  bool get supportsFriends => true;
  @override
  SocialSnapshot get social => SocialSnapshot(friends: [
        SocialPerson.fromJson({'userId': 'bob', 'username': 'BA2ABC'})
      ]);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> mutateSocial(String method, String path,
      [Map<String, Object?> body = const {}]) async {
    calls.add([method, path, body]);
  }
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
  int _localDataRevision = 0;
  final List<String?> startedTitles = [];

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get currentSessionId => _currentSession?.sessionId;

  @override
  Session? get currentSession => _currentSession;

  @override
  int get databaseRevision => _databaseRevision;

  @override
  int get dataRevision => _localDataRevision;

  void simulateLocalClose(String id) {
    final index = _sessions.indexWhere((session) => session.sessionId == id);
    final old = _sessions[index];
    _sessions[index] = _session(id: id, title: old.title, status: 'closed');
    _localDataRevision++;
    notifyListeners();
  }

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
