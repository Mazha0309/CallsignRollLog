import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/app_info_provider.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/personal_cloud_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/screens/home_screen.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:openlogtool/widgets/log_table.dart';
import 'package:openlogtool/widgets/session_sharing_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('direct workbench without a session is informative and inert',
      (tester) async {
    final sessions = _EmptySessionProvider();
    await tester.pumpWidget(_AddRecordTestApp(sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byType(LogForm), findsNothing);
    expect(find.byType(LogTable), findsNothing);
    expect(find.byKey(const Key('current-ordinal-badge')), findsNothing);
    expect(find.text('当前没有点名会话'), findsOneWidget);
    expect(find.text('请先到会话页新建会话，或加入协作后再开始记录。'), findsOneWidget);
    expect(find.byKey(const Key('open-sessions-from-empty-workbench')),
        findsNothing);
    expect(find.byKey(const Key('start-new-record')), findsNothing);
    expect(
      find.byKey(const Key('open-workbench-session-history')),
      findsNothing,
    );
    expect(find.byKey(const Key('create-session')), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'workbench exposes live invitation count and opens Messages directly',
      (tester) async {
    final sessions = _EmptySessionProvider();
    await sessions.startNewSession(title: '当前点名');
    final sharing = _IncomingSharingProvider();
    await tester
        .pumpWidget(_HomeScreenTestApp(sessions: sessions, sharing: sharing));
    await tester.pumpAndSettle();
    final notification = find.byKey(const Key('global-invitations'));
    expect(notification, findsOneWidget);
    expect(find.descendant(of: notification, matching: find.text('2')),
        findsOneWidget);
    sharing.incoming = 3;
    sharing.notifyListeners();
    await tester.pump();
    expect(find.descendant(of: notification, matching: find.text('3')),
        findsOneWidget);
    await tester.tap(notification);
    await tester.pumpAndSettle();
    expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index, 1);
    expect(find.text('当前点名'), findsNothing);
  });

  testWidgets('sharing notice opens acceptance without going through Messages',
      (tester) async {
    final sessions = _EmptySessionProvider();
    final sharing = _PendingShareProvider();
    await tester
        .pumpWidget(_HomeScreenTestApp(sessions: sessions, sharing: sharing));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view-incoming-invitations')));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSharingDialog), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    final accept = find.byKey(const Key('accept-share-share-1'));
    expect(accept.hitTestable(), findsOneWidget);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(sharing.accepted, isTrue);
    expect(sessions.currentSessionId, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first launch opens Sessions without a startup dialog',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessions = _EmptySessionProvider();
    await tester.pumpWidget(_HomeScreenTestApp(sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('global-invitations')), findsNothing);
    expect(find.byKey(const Key('current-session-section')), findsOneWidget);
    expect(find.byKey(const Key('create-session')), findsOneWidget);
    expect(find.textContaining('无需服务器或账号'), findsOneWidget);
    expect(find.byKey(const Key('join-collaboration')), findsNothing);
    expect(find.byKey(const Key('session-history-section')), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(find.byKey(const Key('mobile-navigation')))
          .selectedIndex,
      1,
    );
    expect(find.byType(LogForm), findsNothing);
    expect(find.byType(LogTable), findsNothing);
    expect(find.byKey(const Key('workbench-status-bar')), findsNothing);
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    expect(find.text('单机记录'), findsNothing);

    await tester.tap(find.text('点名台'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<NavigationBar>(find.byKey(const Key('mobile-navigation')))
          .selectedIndex,
      1,
    );
    expect(find.text('请先新建会话或加入协作'), findsOneWidget);
    expect(find.byKey(const Key('create-session')), findsOneWidget);
  });

  testWidgets(
      'phone system back returns from a settings category before leaving settings',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _HomeScreenTestApp(sessions: _EmptySessionProvider()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byKey(const Key('mobile-navigation')),
      matching: find.text('设置'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-appearance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-category-back')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NavigationBar>(find.byKey(const Key('mobile-navigation')))
            .selectedIndex,
        3);
    expect(
        find.byKey(const Key('settings-category-navigation')), findsOneWidget);
    expect(find.byKey(const Key('settings-category-back')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active workbench keeps the new hierarchy on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessions = _EmptySessionProvider();
    await sessions.startNewSession(title: '周五晚间点名');
    await tester.pumpWidget(_HomeScreenTestApp(sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-navigation')), findsOneWidget);
    expect(find.byKey(const Key('workbench-session-header')), findsOneWidget);
    expect(find.byKey(const Key('current-record-section')), findsOneWidget);
    expect(find.byKey(const Key('saved-records-section')), findsOneWidget);
    expect(find.byType(LogForm), findsOneWidget);
    expect(find.byType(LogTable), findsOneWidget);
    expect(find.byKey(const Key('start-new-record')), findsNothing);
    expect(
      find.byKey(const Key('open-workbench-session-history')),
      findsNothing,
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    final statusBar = find.byKey(const Key('workbench-status-bar'));
    final statusScroll = find.ancestor(
      of: statusBar,
      matching: find.byType(SingleChildScrollView),
    );
    final formScroll = find.ancestor(
      of: find.byType(LogForm),
      matching: find.byType(SingleChildScrollView),
    );
    expect(statusScroll, findsOneWidget);
    expect(formScroll, findsOneWidget);
    expect(tester.element(statusScroll), same(tester.element(formScroll)));
    expect(tester.getSize(statusBar).height, lessThanOrEqualTo(56));
    final formWidth = tester.getSize(find.byType(LogForm)).width;
    for (final label in const ['主控呼号 *', '来台呼号', '备注']) {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      expect(field, findsOneWidget, reason: label);
      expect(
        tester.getSize(field).width,
        closeTo(formWidth, 0.1),
        reason: '$label should keep the full phone width',
      );
    }
    final currentTitle = tester.getRect(find.text('当前记录'));
    final ordinal =
        tester.getRect(find.byKey(const Key('current-ordinal-badge')));
    expect(
      (currentTitle.center.dy - ordinal.center.dy).abs(),
      lessThanOrEqualTo(8),
    );

    final initialTop = tester.getTopLeft(statusBar).dy;
    await tester.drag(statusScroll, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(statusBar).dy, lessThan(initialTop - 80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop workbench actions align at screenshot-sized width',
      (tester) async {
    tester.view.physicalSize = const Size(1270, 685);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessions = _EmptySessionProvider();
    await sessions.startNewSession(title: '周五晚间点名');
    await tester.pumpWidget(_HomeScreenTestApp(sessions: sessions));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-navigation')), findsOneWidget);
    final statusHeader =
        tester.getRect(find.byKey(const Key('workbench-session-header')));
    final statuses =
        tester.getRect(find.byKey(const Key('workbench-session-statuses')));
    final currentSection =
        tester.getRect(find.byKey(const Key('current-record-section')));
    final ordinal =
        tester.getRect(find.byKey(const Key('current-ordinal-badge')));
    final savedSection =
        tester.getRect(find.byKey(const Key('saved-records-section')));
    final restore = tester.getRect(
      find.widgetWithText(OutlinedButton, '恢复最近删除'),
    );

    expect(tester.getSize(find.byKey(const Key('workbench-status-bar'))).height,
        lessThanOrEqualTo(56));
    expect(statusHeader.right - statuses.right, lessThanOrEqualTo(13));
    expect(currentSection.right - ordinal.right, lessThanOrEqualTo(20));
    expect(savedSection.right - restore.right, lessThanOrEqualTo(20));
    expect(tester.takeException(), isNull);
  });
}

class _AddRecordTestApp extends StatelessWidget {
  const _AddRecordTestApp({required this.sessions});

  final _EmptySessionProvider sessions;

  @override
  Widget build(BuildContext context) => _TestProviders(
        sessions: sessions,
        child: const Scaffold(body: AddRecordPage()),
      );
}

class _HomeScreenTestApp extends StatelessWidget {
  const _HomeScreenTestApp({required this.sessions, this.sharing});

  final _EmptySessionProvider sessions;
  final AccountShareProvider? sharing;

  @override
  Widget build(BuildContext context) => _TestProviders(
        sessions: sessions,
        includeHomeDependencies: true,
        sharing: sharing,
        child: const HomeScreen(),
      );
}

class _TestProviders extends StatelessWidget {
  const _TestProviders({
    required this.sessions,
    required this.child,
    this.includeHomeDependencies = false,
    this.sharing,
  });

  final _EmptySessionProvider sessions;
  final Widget child;
  final bool includeHomeDependencies;
  final AccountShareProvider? sharing;

  @override
  Widget build(BuildContext context) {
    final providers = [
      ChangeNotifierProvider<SessionProvider>.value(value: sessions),
      ChangeNotifierProvider(
        create: (_) => LogProvider(
          sessionListLoader: () async => [
            if (sessions.currentSession case final session?) session,
          ],
          sessionLogPageLoader: (_, __, ___) async => [],
        ),
      ),
      ChangeNotifierProvider(create: (_) => CollaborationProvider()),
      ChangeNotifierProvider<AccountShareProvider>(
          create: (_) => sharing ?? AccountShareProvider()),
      ChangeNotifierProvider(
        create: (_) => PersonalCloudProvider(
          exporter: () async => '{"version":1,"sessions":[],"logs":[]}',
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => DictionaryProvider(autoload: false),
      ),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => AiRecognitionSettingsProvider()),
      if (includeHomeDependencies) ...[
        ChangeNotifierProvider(create: (_) => AppInfoProvider()),
        ChangeNotifierProvider(
          create: (_) => ServerProvider(autoLoadSettings: false),
        ),
      ],
    ];
    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
}

class _IncomingSharingProvider extends AccountShareProvider {
  int incoming = 2;
  @override
  bool get supportsFriends => true;
  @override
  int get pendingInboundCount => incoming;
  @override
  Future<void> refresh() async {}
}

class _PendingShareProvider extends AccountShareProvider {
  bool accepted = false;
  @override
  bool get supportsFriends => true;
  @override
  bool get supportsLegacySharing => true;
  @override
  bool get supportsBatchSharing => true;
  @override
  List<AccountShareGrantDto> get inbox => accepted
      ? []
      : [
          const AccountShareGrantDto(
              id: 'share-1',
              grantorUserId: 'alice',
              grantorUsername: 'Alice',
              granteeUserId: 'me',
              status: 'pending'),
        ];
  @override
  Future<void> refresh() async {}
  @override
  Future<List<ShareSessionRef>> loadShareCandidates() async => [];
  @override
  Future<void> respondShare(String id, String action,
      {required String? expectedScope}) async {
    expect(id, 'share-1');
    expect(action, 'accept');
    accepted = true;
    revision++;
    notifyListeners();
  }
}

class _EmptySessionProvider extends SessionProvider {
  _EmptySessionProvider() : super(sessionListLoader: () async => const []);

  Session? _current;
  final List<String?> startedTitles = [];

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get currentSessionId => _current?.sessionId;

  @override
  Session? get currentSession => _current;

  @override
  Future<void> startNewSession({
    String? title,
    bool autoGenerated = false,
  }) async {
    startedTitles.add(title);
    _current = const Session(
      sessionId: 'new-session',
      title: '周五晚间点名',
      status: 'active',
      createdAt: '2026-07-17T10:00:00Z',
      updatedAt: '2026-07-17T10:00:00Z',
    );
    notifyListeners();
  }
}
