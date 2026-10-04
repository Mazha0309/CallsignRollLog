import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/live_draft.dart';
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

  testWidgets('an incomplete live draft can be discarded before closing',
      (tester) async {
    final collaboration = _CloseTestCollaborationProvider(
      fields: LiveDraftFieldsDto(const {'callsign': 'BG5CRL'}),
    );
    await _pumpCloseScreen(tester, collaboration);

    await _openCloseDialog(tester);

    expect(
      find.byKey(const Key('close-collaboration-draft-incomplete')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('discard-live-draft-and-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('submit-live-draft-and-close')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('discard-live-draft-and-close')),
    );
    await tester.pumpAndSettle();

    expect(collaboration.discardCount, 1);
    expect(collaboration.closeCount, 1);
    expect(find.text('结束共同记录的请求已保存，等待同步确认'), findsOneWidget);
  });

  testWidgets('a complete live draft can be submitted before closing',
      (tester) async {
    final collaboration = _CloseTestCollaborationProvider(
      fields: LiveDraftFieldsDto(const {
        'time': '20:00',
        'controller': 'BG5AAA',
        'callsign': 'BG5CRL',
      }),
    );
    await _pumpCloseScreen(tester, collaboration);

    await _openCloseDialog(tester);
    await tester.tap(find.byKey(const Key('submit-live-draft-and-close')));
    await tester.pumpAndSettle();

    expect(collaboration.commitCount, 1);
    expect(collaboration.closeCount, 1);
    expect(find.text('结束共同记录的请求已保存，等待同步确认'), findsOneWidget);
  });

  testWidgets('an offline-queued draft never reports the session as closed',
      (tester) async {
    final collaboration = _CloseTestCollaborationProvider(
      fields: LiveDraftFieldsDto(const {
        'time': '20:00',
        'controller': 'BG5AAA',
        'callsign': 'BG5CRL',
      }),
      commitDisposition: LiveDraftCommitDisposition.queuedOffline,
    );
    await _pumpCloseScreen(tester, collaboration);

    await _openCloseDialog(tester);
    await tester.tap(find.byKey(const Key('submit-live-draft-and-close')));
    await tester.pumpAndSettle();

    expect(collaboration.commitCount, 1);
    expect(collaboration.closeCount, 0);
    expect(find.textContaining('共同记录尚未结束'), findsOneWidget);
    expect(find.text('结束共同记录的请求已保存，等待同步确认'), findsNothing);
  });

  testWidgets('active draft locks block every destructive close action',
      (tester) async {
    final collaboration = _CloseTestCollaborationProvider(
      fields: LiveDraftFieldsDto(const {
        'time': '20:00',
        'controller': 'BG5AAA',
        'callsign': 'BG5CRL',
      }),
      locks: [
        LiveDraftLockDto(
          leaseId: 'lease-1',
          sessionId: 'session-1',
          field: 'callsign',
          userId: 'user-2',
          username: 'remote-editor',
          deviceId: 'device-2',
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
      ],
    );
    await _pumpCloseScreen(tester, collaboration);

    await _openCloseDialog(tester);

    expect(
      find.byKey(const Key('close-collaboration-draft-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('confirm-close-collaboration-session')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('discard-live-draft-and-close')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('submit-live-draft-and-close')),
      findsNothing,
    );
    expect(collaboration.closeCount, 0);
  });

  testWidgets('a lock owned by this device does not block draft resolution',
      (tester) async {
    final collaboration = _CloseTestCollaborationProvider(
      fields: LiveDraftFieldsDto(const {'callsign': 'BG5CRL'}),
      locks: [
        LiveDraftLockDto(
          leaseId: 'lease-own',
          sessionId: 'session-1',
          field: 'callsign',
          userId: 'user-1',
          username: 'owner',
          deviceId: 'device-1',
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
      ],
    );
    await _pumpCloseScreen(tester, collaboration);

    await _openCloseDialog(tester);

    expect(
      find.byKey(const Key('close-collaboration-draft-locked')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('discard-live-draft-and-close')),
      findsOneWidget,
    );
  });

  testWidgets('a live-draft refresh failure is reported without opening dialog',
      (tester) async {
    final collaboration = _CloseTestCollaborationProvider(
      fields: LiveDraftFieldsDto.empty(),
      refreshError: StateError('network down'),
    );
    await _pumpCloseScreen(tester, collaboration);

    final closeButton = find.byKey(const Key('close-collaboration-session'));
    await tester.ensureVisible(closeButton);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('close-collaboration-session-dialog')),
      findsNothing,
    );
    expect(find.textContaining('network down'), findsOneWidget);
    expect(collaboration.closeCount, 0);
  });
}

Future<void> _openCloseDialog(WidgetTester tester) async {
  final closeButton = find.byKey(const Key('close-collaboration-session'));
  await tester.ensureVisible(closeButton);
  await tester.tap(closeButton);
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('close-collaboration-session-dialog')),
    findsOneWidget,
  );
}

Future<void> _pumpCloseScreen(
  WidgetTester tester,
  _CloseTestCollaborationProvider collaboration,
) async {
  tester.view.physicalSize = const Size(900, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final server = _CloseTestServerProvider();
  final sessions = _CloseTestSessionProvider();
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
}

class _CloseTestCollaborationProvider extends CollaborationProvider {
  _CloseTestCollaborationProvider({
    required LiveDraftFieldsDto fields,
    this.locks = const [],
    this.commitDisposition = LiveDraftCommitDisposition.committed,
    this.refreshError,
  }) : testFields = fields;

  LiveDraftFieldsDto testFields;
  final List<LiveDraftLockDto> locks;
  final LiveDraftCommitDisposition commitDisposition;
  final Object? refreshError;
  int discardCount = 0;
  int commitCount = 0;
  int closeCount = 0;

  @override
  CollaborationState get state => CollaborationState.ready;

  @override
  LocalCollaborationBinding get binding => const LocalCollaborationBinding(
        serverInstanceId: 'server-1',
        serverOrigin: 'https://example.test',
        accountId: 'user-1',
        sessionId: 'session-1',
        membershipId: 'membership-1',
        membershipVersion: 1,
        role: SessionRole.owner,
        replicaState: 'ready',
        lastAppliedSeq: 1,
        lastSeenHeadSeq: 1,
        revokedAt: null,
      );

  @override
  bool get isOwner => true;

  @override
  bool get canJoinWithInvite => false;

  @override
  bool get supportsInvites => false;

  @override
  bool get supportsPublicShareManagement => false;

  @override
  bool get supportsLiveDraft => true;

  @override
  bool get canEditLiveDraft => true;

  @override
  bool get canEditCurrentSession => true;

  @override
  SessionRole get effectiveRole => SessionRole.owner;

  @override
  LiveDraftFieldsDto get liveDraftFields => testFields;

  @override
  List<LiveDraftLockDto> get liveDraftLocks => locks;

  @override
  bool fieldLockedByAnotherUser(String field) => locks.any(
        (lock) => lock.field == field && lock.userId != 'user-1',
      );

  @override
  Future<void> refreshCurrentSession() async {}

  @override
  Future<void> refreshLiveDraft() async {
    final error = refreshError;
    if (error != null) throw error;
  }

  @override
  Future<void> discardCurrentLiveDraft() async {
    discardCount += 1;
    testFields = LiveDraftFieldsDto.empty();
    notifyListeners();
  }

  @override
  Future<LiveDraftCommitDisposition> commitCurrentLiveDraft() async {
    commitCount += 1;
    return commitDisposition;
  }

  @override
  Future<void> closeCurrentSession() async {
    closeCount += 1;
  }
}

class _CloseTestServerProvider extends ServerProvider {
  _CloseTestServerProvider() : super(autoLoadSettings: false);

  @override
  bool get isLoggedIn => true;

  @override
  String get serverUrl => 'https://example.test';

  @override
  String? get accountId => 'user-1';

  @override
  String? get username => 'owner';
}

class _CloseTestSessionProvider extends SessionProvider {
  static const session = Session(
    sessionId: 'session-1',
    title: 'Sunday net',
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
