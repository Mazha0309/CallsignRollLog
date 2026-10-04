import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/log_entry.dart' as model;
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/src/bridge/models/log_entry.dart' as bridge;
import 'package:openlogtool/src/bridge/models/session.dart';

void main() {
  test('add re-reads the durable table and retains its canonical row',
      () async {
    var pageReads = 0;
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async {
        pageReads += 1;
        return [];
      },
      logCreator: (_, __) async => _bridgeLog(
        id: 'canonical-new',
        sessionId: 'session-a',
        time: '2026-07-13T12:00:00Z',
        callsign: 'BG5NEW',
      ),
    );
    await provider.reloadForSession('session-a');
    final readsBeforeAdd = pageReads;
    var notifications = 0;
    provider.addListener(() => notifications += 1);

    await provider.addLog(_modelLog(id: 'temporary', sessionId: 'session-a'));

    expect(pageReads, readsBeforeAdd + 1);
    expect(provider.logs.map((log) => log.id), ['canonical-new']);
    expect(provider.logs.single.callsign, 'BG5NEW');
    expect(notifications, greaterThan(0));
    provider.dispose();
  });

  test('add aligns a stale table projection to the requested session',
      () async {
    final provider = LogProvider(
      sessionListLoader: () async => [
        _session('old-session'),
        _session('new-session'),
      ],
      sessionLogPageLoader: (sessionId, _, __) async =>
          sessionId == 'old-session'
              ? [
                  _bridgeLog(
                    id: 'old-row',
                    sessionId: 'old-session',
                    time: '2026-07-13T10:00:00Z',
                  ),
                ]
              : [],
      logCreator: (sessionId, _) async {
        expect(sessionId, 'new-session');
        return _bridgeLog(
          id: 'new-row',
          sessionId: 'new-session',
          time: '2026-07-13T11:00:00Z',
          callsign: 'BG5FRESH',
        );
      },
    );
    await provider.reloadForSession('old-session');
    expect(provider.logs.single.id, 'old-row');

    await provider.addLog(
      _modelLog(id: 'temporary', sessionId: 'new-session'),
      sessionId: 'new-session',
    );

    expect(provider.currentSessionId, 'new-session');
    expect(provider.logs.map((log) => log.id), ['new-row']);
    expect(provider.logs.single.callsign, 'BG5FRESH');
    provider.dispose();
  });

  test('an add finishing after a session switch cannot pollute the new table',
      () async {
    final createStarted = Completer<void>();
    final releaseCreate = Completer<void>();
    final provider = LogProvider(
      sessionListLoader: () async => [
        _session('session-a'),
        _session('session-b'),
      ],
      sessionLogPageLoader: (sessionId, _, __) async => sessionId == 'session-b'
          ? [
              _bridgeLog(
                id: 'session-b-row',
                sessionId: 'session-b',
                time: '2026-07-13T12:00:00Z',
              ),
            ]
          : [],
      logCreator: (sessionId, _) async {
        expect(sessionId, 'session-a');
        createStarted.complete();
        await releaseCreate.future;
        return _bridgeLog(
          id: 'late-session-a-row',
          sessionId: 'session-a',
          time: '2026-07-13T11:00:00Z',
        );
      },
    );
    await provider.reloadForSession('session-a');

    final add = provider.addLog(
      _modelLog(id: 'temporary', sessionId: 'session-a'),
      sessionId: 'session-a',
    );
    await createStarted.future;
    await provider.reloadForSession('session-b');
    releaseCreate.complete();
    await add;

    expect(provider.currentSessionId, 'session-b');
    expect(provider.logs.map((log) => log.id), ['session-b-row']);
    provider.dispose();
  });

  test('a stale reload cannot overwrite a canonical add', () async {
    final staleReadStarted = Completer<void>();
    final releaseStaleRead = Completer<void>();
    var blockNextRead = false;
    final old = _bridgeLog(
      id: 'old',
      sessionId: 'session-a',
      time: '2026-07-13T10:00:00Z',
    );
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async {
        if (blockNextRead) {
          blockNextRead = false;
          staleReadStarted.complete();
          await releaseStaleRead.future;
        }
        return [old];
      },
      logCreator: (_, __) async => _bridgeLog(
        id: 'new',
        sessionId: 'session-a',
        time: '2026-07-13T11:00:00Z',
      ),
    );
    await provider.reloadForSession('session-a');
    blockNextRead = true;
    final staleReload = provider.reloadForSession('session-a');
    await staleReadStarted.future;

    await provider.addLog(_modelLog(id: 'temporary', sessionId: 'session-a'));
    releaseStaleRead.complete();
    await staleReload;

    expect(provider.logs.map((log) => log.id), ['old', 'new']);
    provider.dispose();
  });

  test('a staged server row survives reload until SQLite materializes it',
      () async {
    var rows = <bridge.LogEntry>[];
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async => rows,
    );
    await provider.reloadForSession('session-a');
    provider.stageCanonicalLog(
      _modelLog(id: 'server-log', sessionId: 'session-a'),
    );

    await provider.reloadForSession('session-a');
    expect(provider.logs.map((log) => log.id), ['server-log']);
    expect(
      provider.mutationBlockReason(provider.logs.single),
      'COLLABORATION_LOG_SYNC_PENDING',
    );

    rows = [
      _bridgeLog(
        id: 'server-log',
        sessionId: 'session-a',
        time: '2026-07-13T11:00:00Z',
      ),
    ];
    await provider.reloadForSession('session-a');
    expect(provider.mutationBlockReason(provider.logs.single), isNull);
    rows = [];
    await provider.reloadForSession('session-a');

    expect(provider.logs, isEmpty);
    provider.dispose();
  });

  test('an awaited durable event retires a late optimistic overlay', () async {
    final rows = [
      _bridgeLog(
        id: 'already-durable',
        sessionId: 'session-a',
        time: '2026-07-13T11:00:00Z',
        callsign: 'DB-LATEST',
      ),
    ];
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async => rows,
    );
    await provider.reloadForSession('session-a');
    provider.stageCanonicalLog(
      _modelLog(id: 'already-durable', sessionId: 'session-a'),
    );
    expect(
      provider.mutationBlockReason(provider.logs.single),
      'COLLABORATION_LOG_SYNC_PENDING',
    );

    await provider.reconcileStagedCanonicalLog('already-durable');

    expect(provider.mutationBlockReason(provider.logs.single), isNull);
    expect(provider.logs.single.callsign, 'DB-LATEST');
    expect(provider.logs.map((log) => log.id), ['already-durable']);
    provider.dispose();
  });

  test('update replaces by sync id and reorders by canonical time', () async {
    final initial = [
      _bridgeLog(
        id: 'later',
        sessionId: 'session-a',
        time: '2026-07-13T12:00:00Z',
      ),
      _bridgeLog(
        id: 'target',
        sessionId: 'session-a',
        time: '2026-07-13T11:00:00Z',
      ),
    ];
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async => initial,
      logUpdater: (syncId, _, __) async {
        expect(syncId, 'target');
        return _bridgeLog(
          id: syncId,
          sessionId: 'session-a',
          time: '2026-07-13T13:00:00Z',
          callsign: 'BG5UPDATED',
        );
      },
    );
    await provider.reloadForSession('session-a');

    await provider.updateLog(
      0,
      _modelLog(id: 'target', sessionId: 'session-a'),
    );

    expect(provider.logs.map((log) => log.id), ['later', 'target']);
    expect(provider.logs.last.callsign, 'BG5UPDATED');
    provider.dispose();
  });

  test('delete removes the captured sync id after a concurrent reorder',
      () async {
    final deleteStarted = Completer<void>();
    final releaseDelete = Completer<void>();
    var rows = [
      _bridgeLog(
        id: 'keep',
        sessionId: 'session-a',
        time: '2026-07-13T12:00:00Z',
      ),
      _bridgeLog(
        id: 'delete',
        sessionId: 'session-a',
        time: '2026-07-13T11:00:00Z',
      ),
    ];
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async => rows,
      logDeleter: (syncId) async {
        expect(syncId, 'delete');
        deleteStarted.complete();
        await releaseDelete.future;
      },
    );
    await provider.reloadForSession('session-a');
    final deletion = provider.deleteLog(0);
    await deleteStarted.future;
    rows = [
      _bridgeLog(
        id: 'delete',
        sessionId: 'session-a',
        time: '2026-07-13T13:00:00Z',
      ),
      _bridgeLog(
        id: 'keep',
        sessionId: 'session-a',
        time: '2026-07-13T10:00:00Z',
      ),
    ];
    await provider.reloadForSession('session-a');
    releaseDelete.complete();
    await deletion;

    expect(provider.logs.map((log) => log.id), ['keep']);
    provider.dispose();
  });

  test('undo restores the deleted stack entry without removing the latest log',
      () async {
    final restoredIds = <String>[];
    var rows = [
      _bridgeLog(
        id: 'latest',
        sessionId: 'session-a',
        time: '2026-07-13T12:00:00Z',
      ),
      _bridgeLog(
        id: 'deleted',
        sessionId: 'session-a',
        time: '2026-07-13T11:00:00Z',
      ),
    ];
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async => rows,
      logDeleter: (syncId) async {
        rows = rows.where((row) => row.syncId != syncId).toList();
      },
      logRestorer: (syncId) async {
        restoredIds.add(syncId);
        final restored = _bridgeLog(
          id: syncId,
          sessionId: 'session-a',
          time: '2026-07-13T11:00:00Z',
        );
        rows = [rows.single, restored];
        return restored;
      },
    );
    await provider.reloadForSession('session-a');

    await provider.deleteLogById('deleted');
    expect(provider.logs.map((log) => log.id), ['latest']);

    await provider.undoLastLog();

    expect(restoredIds, ['deleted']);
    expect(provider.logs.map((log) => log.id), ['deleted', 'latest']);
    provider.dispose();
  });

  test('failed restore keeps the deleted record available for retry', () async {
    var rows = [
      _bridgeLog(
        id: 'deleted',
        sessionId: 'session-a',
        time: '2026-07-13T11:00:00Z',
      ),
    ];
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async => rows,
      logDeleter: (syncId) async {
        rows = rows.where((row) => row.syncId != syncId).toList();
      },
      logRestorer: (_) async => throw StateError('restore failed'),
    );
    await provider.reloadForSession('session-a');
    await provider.deleteLogById('deleted');

    await expectLater(
      provider.undoLastLog(),
      throwsA(isA<StateError>()),
    );

    expect(provider.logs, isEmpty);
    expect(provider.canUndo, isTrue);
    provider.dispose();
  });

  test('database replacement drops stale overlays and permission markers',
      () async {
    var rows = [
      _bridgeLog(
        id: 'before-import',
        sessionId: 'session-a',
        time: '2026-07-13T10:00:00Z',
      ),
    ];
    final provider = LogProvider(
      sessionListLoader: () async => [_session('session-a')],
      sessionLogPageLoader: (_, __, ___) async => rows,
    );
    await provider.reloadForSession('session-a');
    provider.setCollaborationReadOnly('session-a', true);
    provider.stageCanonicalLog(
      _modelLog(id: 'stale-overlay', sessionId: 'session-a'),
    );

    rows = [
      _bridgeLog(
        id: 'after-import',
        sessionId: 'session-a',
        time: '2026-07-13T12:00:00Z',
      ),
    ];
    await provider.reloadAfterDatabaseReplacement('session-a');

    expect(provider.logs.map((log) => log.id), ['after-import']);
    expect(provider.currentSessionReadOnly, isFalse);
    expect(provider.mutationBlockReason(provider.logs.single), isNull);
    provider.dispose();
  });
}

Session _session(String sessionId) => Session(
      sessionId: sessionId,
      title: 'Test',
      status: 'active',
      createdAt: '2026-07-13T10:00:00Z',
      updatedAt: '2026-07-13T10:00:00Z',
    );

bridge.LogEntry _bridgeLog({
  required String id,
  required String sessionId,
  required String time,
  String callsign = 'BG5FBT',
}) =>
    bridge.LogEntry(
      syncId: id,
      sessionId: sessionId,
      time: time,
      controller: 'BG5CRL',
      callsign: callsign,
      rstSent: '59',
      rstRcvd: '59',
      createdAt: time,
      updatedAt: time,
    );

model.LogEntry _modelLog({
  required String id,
  required String sessionId,
}) =>
    model.LogEntry(
      id: id,
      sessionId: sessionId,
      time: '2026-07-13T11:00:00Z',
      controller: 'BG5CRL',
      callsign: 'BG5FBT',
      report: '59',
      rstRcvd: '59',
      qth: '',
      device: '',
      power: '',
      antenna: '',
      height: '',
      createdAt: '2026-07-13T11:00:00Z',
      updatedAt: '2026-07-13T11:00:00Z',
    );
