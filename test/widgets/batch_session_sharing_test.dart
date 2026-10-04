import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/widgets/session_history_dialog.dart';
import 'package:openlogtool/widgets/session_sharing_dialog.dart';
import 'package:openlogtool/widgets/shared_session_records_dialog.dart';
import 'package:openlogtool/widgets/record_editor_dialog.dart';

const shared = SharedSessionDto(
    source: 'personal',
    sessionId: 'p1',
    title: '好友的记录',
    status: 'active',
    grantorUsername: 'bob',
    grantorUserId: 'bob-id',
    grantId: 'grant1',
    canJoin: false,
    createdAt: '2026-10-04T10:00:00Z',
    updatedAt: '2026-10-04T10:00:00Z',
    canEditLogs: true,
    snapshotRevision: 3);
const local = Session(
    sessionId: 'p1',
    title: '本机当前记录',
    status: 'active',
    createdAt: '2026-10-04T09:00:00Z',
    updatedAt: '2026-10-04T09:00:00Z');

class SharingFixture extends AccountShareProvider {
  String scope = 'one';
  Map<String, Object?>? saved;
  bool failRecords = false;
  final reads = <int>[];
  Completer<SharedRecordsPage>? latePage;
  @override
  String? get accountScope => scope;
  @override
  bool get supportsBatchSharing => true;
  @override
  bool get supportsLegacySharing => true;
  @override
  List<SharedSessionDto> get sharedSessions => [shared];
  @override
  SocialSnapshot get social => SocialSnapshot(friends: [
        SocialPerson.fromJson({'userId': 'bob-id', 'username': 'bob'})
      ]);
  @override
  List<AccountShareGrantDto> get outgoing => [];
  @override
  Future<void> refresh() async {}
  @override
  List<SessionListEntry> sharedHistoryEntries() => [
        const SessionListEntry(
            session: Session(
                sessionId: 'p1',
                title: '好友的记录',
                status: 'active',
                createdAt: '2026-10-04T10:00:00Z',
                updatedAt: '2026-10-04T10:00:00Z'),
            hasCollaborationBinding: false,
            isShared: true,
            sharedGrantorUsername: 'bob',
            sharedSession: shared)
      ];
  @override
  Future<List<ShareSessionRef>> loadShareCandidates() async => [
        const ShareSessionRef(
            source: 'collaboration', sessionId: 'c1', title: '自己的协作一'),
        const ShareSessionRef(
            source: 'collaboration', sessionId: 'c2', title: '自己的协作二')
      ];
  @override
  Future<void> saveShare(
      {required String username,
      required String scopeMode,
      required List<ShareSessionRef> sessions,
      required bool canEditLogs,
      required bool canDeleteLogs,
      required String? expectedScope,
      String? grantId}) async {
    saved = {
      'username': username,
      'scopeMode': scopeMode,
      'sessions': sessions.map((s) => s.identity).toList(),
      'edit': canEditLogs,
      'delete': canDeleteLogs,
      'scope': expectedScope
    };
  }

  @override
  Future<SharedRecordsPage> loadSharedRecords(SharedSessionDto session,
      {int page = 1, String query = '', required String? expectedScope}) async {
    reads.add(page);
    if (failRecords) throw StateError('offline');
    if (latePage != null) return latePage!.future;
    return SharedRecordsPage(
        session: shared,
        page: page,
        totalPages: 2,
        total: 51,
        items: [
          {
            'sync_id': 'record-$page',
            'callsign': 'BG5CRL-$page',
            'time': '2026-10-04T10:12:34Z',
            'controller': 'BG5AAA',
            'version': 1
          }
        ]);
  }

  void changeAccount() {
    scope = 'two';
    revision++;
    notifyListeners();
  }
}

class HistoryFixture extends SessionProvider {
  HistoryFixture(this.current)
      : super(
            sessionListLoader: () async => [local],
            sessionBindingChecker: (_) async => false);
  final bool current;
  @override
  Future<void> get ready => Future.value();
  @override
  String? get currentSessionId => current ? local.sessionId : null;
  @override
  Future<void> switchToSession(String sessionId) async =>
      throw StateError('Shared browsing must not switch the workbench');
}

class InboxSharingFixture extends SharingFixture {
  List<AccountShareGrantDto> invitations = [
    const AccountShareGrantDto(
      id: 'incoming',
      grantorUserId: 'alice',
      grantorUsername: 'Alice',
      granteeUserId: 'me',
      status: 'pending',
    )
  ];
  String? response;
  @override
  List<AccountShareGrantDto> get inbox => invitations;
  @override
  Future<List<ShareSessionRef>> loadShareCandidates() async =>
      throw StateError('catalog unavailable');
  @override
  Future<void> respondShare(String id, String action,
      {required String? expectedScope}) async {
    expect(id, 'incoming');
    expect(expectedScope, scope);
    response = action;
    invitations = [];
    notifyListeners();
  }
}

Future<SessionProvider> pump(
    WidgetTester tester, SharingFixture sharing, Widget child,
    {bool current = false}) async {
  SharedPreferences.setMockInitialValues(
      current ? {'current_session_id': 'p1'} : {});
  final sessions = HistoryFixture(current);
  addTearDown(sessions.dispose);
  addTearDown(sharing.dispose);
  final dictionary = DictionaryProvider(autoload: false);
  addTearDown(dictionary.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>.value(value: sessions),
        ChangeNotifierProvider<AccountShareProvider>.value(value: sharing),
        ChangeNotifierProvider<DictionaryProvider>.value(value: dictionary),
      ],
      child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child))));
  await tester.pumpAndSettle();
  return sessions;
}

void main() {
  testWidgets(
      'Sharing opens with actionable received invitations even when its catalog fails',
      (tester) async {
    final sharing = InboxSharingFixture();
    await pump(tester, sharing, const SessionSharingDialog());
    final accept = find.byKey(const Key('accept-share-incoming'));
    expect(accept.hitTestable(), findsOneWidget);
    expect(
        tester.getTopLeft(accept).dy,
        lessThan(
            tester.getTopLeft(find.byKey(const Key('share-recipient'))).dy));
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(sharing.response, 'accept');
    expect(find.text('暂无待处理的共享邀请'), findsOneWidget);
    expect(find.textContaining('当前记录会话不会切换'), findsOneWidget);
  });
  testWidgets(
      'shared history has its own filter, owner badge and collision-safe identity without switching workbench',
      (tester) async {
    final sharing = SharingFixture();
    final sessions = await pump(tester, sharing,
        const SingleChildScrollView(child: SessionHistoryPanel()),
        current: true);
    expect(find.text('好友的记录'), findsOneWidget);
    expect(find.textContaining('bob'), findsOneWidget);
    expect(find.byKey(const Key('session-collection-shared')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-collection-shared')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('browse-shared-session-p1')));
    await tester.pumpAndSettle();
    expect(find.text('BG5CRL-1'), findsOneWidget);
    expect(sessions.currentSessionId, 'p1');
    expect(find.byKey(const Key('shared-record-add')), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.byKey(const Key('shared-records-next')));
    await tester.pumpAndSettle();
    expect(find.text('BG5CRL-2'), findsOneWidget);
    expect(sharing.reads, [1, 2]);
    await tester.tap(find.byKey(const Key('shared-record-record-2')));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditorDialog), findsOneWidget);
    sharing.changeAccount();
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditorDialog), findsNothing);
    expect(find.textContaining('BG5CRL'), findsNothing);
  });
  testWidgets(
      'multiple selection submits editing with deletion separately disabled',
      (tester) async {
    final sharing = SharingFixture();
    await pump(tester, sharing, const SessionSharingDialog());
    await tester.enterText(find.byKey(const Key('share-recipient')), 'bob');
    for (final id in ['c1', 'c2']) {
      final tile = find.byKey(Key('share-select-collaboration:$id'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
    final edit = find.byKey(const Key('share-edit-permission'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    final deletion = tester.widget<SwitchListTile>(
        find.byKey(const Key('share-delete-permission')));
    expect(deletion.value, isFalse);
    expect(deletion.onChanged, isNotNull);
    await tester.tap(find.byKey(const Key('share-save')));
    await tester.pumpAndSettle();
    expect(sharing.saved, {
      'username': 'bob',
      'scopeMode': 'selected',
      'sessions': ['collaboration:c1', 'collaboration:c2'],
      'edit': true,
      'delete': false,
      'scope': 'one'
    });
  });
  testWidgets(
      'ongoing all sharing is explicit and clears deletion when edit is disabled',
      (tester) async {
    final sharing = SharingFixture();
    await pump(tester, sharing, const SessionSharingDialog());
    await tester.tap(find.byKey(const Key('share-scope-all')));
    await tester.pumpAndSettle();
    expect(find.textContaining('以后新建的所有本人会话'), findsOneWidget);
    expect(find.byKey(const Key('share-session-search')), findsNothing);
    for (final key in [
      'share-edit-permission',
      'share-delete-permission',
      'share-edit-permission'
    ]) {
      final tile = find.byKey(Key(key));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }
    final deletion = tester.widget<SwitchListTile>(
        find.byKey(const Key('share-delete-permission')));
    expect(deletion.value, isFalse);
    expect(deletion.onChanged, isNull);
  });
  testWidgets('failed shared records show a retry error, not an empty history',
      (tester) async {
    await pump(tester, SharingFixture()..failRecords = true,
        const SharedSessionRecordsDialog(session: shared));
    expect(find.textContaining('操作未完成'), findsOneWidget);
    expect(find.text('暂无历史会话'), findsNothing);
    expect(find.byKey(const Key('shared-record-add')), findsNothing);
  });
  testWidgets('late records cannot repopulate a changed account',
      (tester) async {
    final sharing = SharingFixture()..latePage = Completer<SharedRecordsPage>();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider<AccountShareProvider>.value(
        value: sharing,
        child: const MaterialApp(
            locale: Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home:
                Scaffold(body: SharedSessionRecordsDialog(session: shared)))));
    await tester.pump();
    sharing.changeAccount();
    await tester.pump();
    sharing.latePage!.complete(const SharedRecordsPage(items: [
      {'sync_id': 'late', 'callsign': 'SECRET'}
    ], page: 1, totalPages: 1, total: 1));
    await tester.pumpAndSettle();
    expect(find.text('SECRET'), findsNothing);
    expect(find.text('好友的记录'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    sharing.dispose();
  });
  testWidgets('sharing form remains usable at narrow phone width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, SharingFixture(), const SessionSharingDialog());
    expect(tester.takeException(), isNull);
    final edit = find.byKey(const Key('share-edit-permission'));
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
