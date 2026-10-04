import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/shared_workbench_provider.dart';

SharedSessionDto shared(
        {bool edit = true, bool delete = false, String status = 'active'}) =>
    SharedSessionDto(
        source: 'collaboration',
        sessionId: 'same-local-id',
        title: 'Shared',
        status: status,
        grantorUsername: 'owner',
        grantorUserId: 'owner-id',
        grantId: 'grant',
        canJoin: false,
        createdAt: '2026-10-04T10:00:00Z',
        updatedAt: '2026-10-04T10:00:00Z',
        canEditLogs: edit,
        canDeleteLogs: delete);

class RemoteFixture extends AccountShareProvider {
  String scope = 'one';
  List<SharedSessionDto> catalog = [shared()];
  int version = 1;
  bool fail = false;
  Completer<SharedRecordsPage>? pending;
  final writes = <Map<String, Object?>>[];
  @override
  String? get accountScope => scope;
  @override
  List<SharedSessionDto> get sharedSessions => catalog;
  @override
  Future<SharedRecordsPage> loadSharedRecords(SharedSessionDto session,
      {int page = 1, String query = '', required String? expectedScope}) async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return SharedRecordsPage(
        session: catalog.first,
        page: 1,
        total: 1,
        totalPages: 1,
        items: [
          {
            'sync_id': 'record',
            'version': version,
            'session_id': session.sessionId,
            'time': '2026-10-04T10:12:34Z',
            'controller': 'BG5CRL',
            'callsign': 'BG5AAA'
          }
        ]);
  }

  @override
  Future<void> mutateSharedRecord(
      SharedSessionDto session, Map<String, Object?> body,
      {required String? expectedScope}) async {
    expect(expectedScope, scope);
    writes.add(body);
    if (fail) throw StateError('offline');
    if (body['operation'] != 'create' && body['baseVersion'] != version) {
      throw StateError('VERSION_CONFLICT');
    }
    version++;
  }

  void update() {
    revision++;
    notifyListeners();
  }
}

Future<SharedWorkbenchProvider> setup(RemoteFixture sharing) async {
  final provider = SharedWorkbenchProvider(sharing, sharing.catalog.first);
  addTearDown(provider.dispose);
  addTearDown(sharing.dispose);
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  test('remote editing uses explicit capabilities and never needs local Rust',
      () async {
    final sharing = RemoteFixture();
    final provider = await setup(sharing);
    expect(provider.logs.single.sessionId, 'same-local-id');
    final original = provider.logs.single;
    expect(provider.canUndo, false);
    expect(provider.canClearAllLogs, false);
    expect(provider.canDeleteLog(original), false);
    await provider.updateLogFromOriginal(
        original, original.copyWith(qth: 'changed'));
    expect(sharing.writes.single['patch'], {'qth': 'changed'});
    expect(sharing.writes.single['baseVersion'], 1);
    await expectLater(
        provider.deleteLogFromOriginal(provider.logs.single), throwsStateError);
    await expectLater(provider.closeSession('same-local-id'), throwsStateError);
    await expectLater(
        provider.hardDeleteSession('same-local-id'), throwsStateError);
    await expectLater(provider.importLogs([]), throwsStateError);
    expect(sharing.writes.length, 1);
  });
  test('stale editor retains its original version after a WS refresh',
      () async {
    final sharing = RemoteFixture();
    final provider = await setup(sharing);
    final original = provider.logs.single;
    sharing.version = 2;
    await provider.refresh();
    await expectLater(
        provider.updateLogFromOriginal(
            original, original.copyWith(qth: 'stale')),
        throwsStateError);
    expect(sharing.writes.single['baseVersion'], 1);
  });
  test('read-only, closed and revoked sessions reject all writes', () async {
    final sharing = RemoteFixture();
    final provider = await setup(sharing);
    final original = provider.logs.single;
    for (final session in [shared(edit: false), shared(status: 'closed')]) {
      sharing.catalog = [session];
      sharing.update();
      await Future<void>.delayed(Duration.zero);
      expect(provider.currentSessionReadOnly, true);
      await expectLater(
          provider.updateLogFromOriginal(
              original, original.copyWith(qth: 'bad')),
          throwsStateError);
    }
    sharing.catalog = [];
    sharing.update();
    expect(provider.logs, isEmpty);
    expect(provider.hasReadAccess, false);
    await expectLater(provider.addLog(original), throwsStateError);
    expect(sharing.writes, isEmpty);
  });
  test('late response cannot repopulate a changed account', () async {
    final sharing = RemoteFixture()..pending = Completer<SharedRecordsPage>();
    final provider = await setup(sharing);
    sharing.scope = 'two';
    sharing.update();
    sharing.pending!.complete(SharedRecordsPage(
        session: shared(),
        items: [
          {'sync_id': 'secret', 'callsign': 'SECRET'}
        ],
        page: 1,
        total: 1,
        totalPages: 1));
    await Future<void>.delayed(Duration.zero);
    expect(provider.logs, isEmpty);
    expect(provider.hasReadAccess, false);
  });
  test('deletion requires its own permission and the original record version',
      () async {
    final sharing = RemoteFixture()..catalog = [shared(delete: true)];
    final provider = await setup(sharing);
    final row = provider.logs.single;
    expect(provider.canDeleteLog(row), true);
    await provider.deleteLogFromOriginal(row);
    expect(sharing.writes.single['operation'], 'delete');
    expect(sharing.writes.single['baseVersion'], 1);
  });
  test('failed loading fails closed and an explicit refresh can recover',
      () async {
    final sharing = RemoteFixture()..fail = true;
    final provider = await setup(sharing);
    expect(provider.error, isNotNull);
    expect(provider.currentSessionReadOnly, true);
    sharing.fail = false;
    await provider.refresh();
    expect(provider.error, isNull);
    expect(provider.currentSessionReadOnly, false);
  });
  test(
      'create retry retains the same record ID after an ambiguous network failure',
      () async {
    final sharing = RemoteFixture();
    final provider = await setup(sharing);
    final row = provider.logs.single;
    sharing.fail = true;
    await expectLater(
        provider.addLog(row.copyWith(id: 'first')), throwsStateError);
    sharing.fail = false;
    await provider.refresh();
    await provider.addLog(row.copyWith(id: 'retry'));
    expect(sharing.writes.map((w) => w['syncId']), ['first', 'first']);
  });
}
