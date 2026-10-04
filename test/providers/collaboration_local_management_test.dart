import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/log_entry.dart' as model;
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('offline stop selects a writable local replacement and forgets source',
      () async {
    final sessions = _ManagedSessions(_Mode.stop);
    final logs = _logs(sessions);
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    await logs.reloadForSession(source.sessionId);
    final pending = _log('pending-source');
    logs.stageCanonicalLog(pending);
    logs.setCollaborationReadOnly(source.sessionId, true);
    collaboration.updateDependencies(server, sessions, logs);

    await collaboration.stopCurrentSessionLocally();

    expect(sessions.stopCalls, 1);
    expect(sessions.currentSessionId, editableLocal.sessionId);
    expect(logs.currentSessionId, editableLocal.sessionId);
    expect(logs.currentSessionReadOnly, isFalse);
    expect(logs.mutationBlockReason(pending), isNull);
    expect(collaboration.state, CollaborationState.localOnly);
  });

  test(
      'offline independent copy is writable without stopping or deleting source',
      () async {
    final sessions = _ManagedSessions(_Mode.copy);
    final logs = _logs(sessions);
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    await logs.reloadForSession(source.sessionId);
    collaboration.updateDependencies(server, sessions, logs);

    await collaboration.createEditableLocalCopy(title: 'Independent');

    expect(sessions.copyCalls, 1);
    expect(sessions.stopCalls, 0);
    expect(sessions.deleteCalls, 0);
    expect(sessions.currentSessionId, editableLocal.sessionId);
    expect(logs.currentSessionId, editableLocal.sessionId);
    expect(logs.currentSessionReadOnly, isFalse);
    expect(collaboration.state, CollaborationState.localOnly);
  });

  test('committed local stop is not reported failed when log reload fails',
      () async {
    final sessions = _ManagedSessions(_Mode.stop);
    final logs = LogProvider(
      sessionListLoader: () async => throw StateError('projection unavailable'),
      sessionLogPageLoader: (_, __, ___) async => [],
    );
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    collaboration.updateDependencies(server, sessions, logs);

    await collaboration.stopCurrentSessionLocally();

    expect(sessions.currentSessionId, editableLocal.sessionId);
    expect(logs.currentSessionId, editableLocal.sessionId);
    expect(collaboration.state, CollaborationState.localOnly);
    expect(collaboration.errorCode, 'LOCAL_SESSION_RELOAD_FAILED');
  });

  test('deleting current offline replica clears both provider selections',
      () async {
    final sessions = _ManagedSessions(_Mode.delete);
    final logs = _logs(sessions);
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    await logs.reloadForSession(source.sessionId);
    logs.stageCanonicalLog(_log('pending-source'));
    logs.setCollaborationReadOnly(source.sessionId, true);
    collaboration.updateDependencies(server, sessions, logs);

    await collaboration.deleteCurrentSessionLocally();

    expect(sessions.deleteCalls, 1);
    expect(sessions.currentSessionId, isNull);
    expect(sessions.currentSession, isNull);
    expect(logs.currentSessionId, isNull);
    expect(logs.logs, isEmpty);
    expect(logs.currentSessionReadOnly, isFalse);
    expect(collaboration.state, CollaborationState.localOnly);
  });

  test('database maintenance resets session, log, and collaboration caches',
      () async {
    final sessions = _ManagedSessions(_Mode.stop);
    final logs = _logs(sessions);
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    await logs.reloadForSession(source.sessionId);
    final pending = _log('pending-source');
    logs.stageCanonicalLog(pending);
    logs.setCollaborationReadOnly(source.sessionId, true);
    collaboration.updateDependencies(server, sessions, logs);
    var operationCalls = 0;
    var sentinelWasDurableBeforeOperation = false;

    final result = await collaboration.runLocalDatabaseMaintenance(() async {
      operationCalls += 1;
      sentinelWasDurableBeforeOperation =
          (await SharedPreferences.getInstance())
                  .getBool('local_database_replacement_pending') ==
              true;
      return 7;
    });

    expect(result, 7);
    expect(operationCalls, 1);
    expect(sentinelWasDurableBeforeOperation, isTrue);
    expect(sessions.databaseReloadCalls, 1);
    expect(sessions.databaseReplacementPending, isFalse);
    expect(
      (await SharedPreferences.getInstance())
          .containsKey('local_database_replacement_pending'),
      isFalse,
    );
    expect(logs.currentSessionId, source.sessionId);
    expect(logs.mutationBlockReason(pending), isNull);
  });

  test('database maintenance exposes a stable busy error code', () async {
    final sessions = _ManagedSessions(_Mode.stop);
    final logs = _logs(sessions);
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    collaboration.updateDependencies(server, sessions, logs);
    final gate = Completer<void>();
    final first = collaboration.runLocalDatabaseMaintenance(() => gate.future);
    await Future<void>.delayed(Duration.zero);

    expect(collaboration.isBusy, isTrue);
    await expectLater(
      collaboration.refreshLiveDraft(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'COLLABORATION_OPERATION_IN_PROGRESS',
        ),
      ),
    );

    await expectLater(
      collaboration.runLocalDatabaseMaintenance(() async {}),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'COLLABORATION_OPERATION_IN_PROGRESS',
        ),
      ),
    );
    gate.complete();
    await first;
  });

  test('rolled-back database maintenance safely clears its sentinel', () async {
    final sessions = _ManagedSessions(_Mode.stop);
    final logs = _logs(sessions);
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    collaboration.updateDependencies(server, sessions, logs);

    await expectLater(
      collaboration.runLocalDatabaseMaintenance<void>(
        () async => throw StateError('transaction rolled back'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(sessions.databaseReloadCalls, 0);
    expect(sessions.databaseReplacementPending, isFalse);
    expect(
      (await SharedPreferences.getInstance())
          .containsKey('local_database_replacement_pending'),
      isFalse,
    );
  });

  test('failed retry never clears a sentinel left by an earlier crash',
      () async {
    SharedPreferences.setMockInitialValues({
      'local_database_replacement_pending': true,
    });
    final sessions = _ManagedSessions(_Mode.stop);
    final logs = _logs(sessions);
    final server = _OfflineServer();
    final collaboration = _ManagedCollaboration();
    addTearDown(sessions.dispose);
    addTearDown(logs.dispose);
    addTearDown(server.dispose);
    addTearDown(collaboration.dispose);
    collaboration.updateDependencies(server, sessions, logs);

    await expectLater(
      collaboration.runLocalDatabaseMaintenance<void>(
        () async => throw StateError('retry transaction rolled back'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(sessions.databaseReplacementPending, isTrue);
    expect(
      (await SharedPreferences.getInstance())
          .getBool('local_database_replacement_pending'),
      isTrue,
    );
  });
}

LogProvider _logs(_ManagedSessions sessions) => LogProvider(
      sessionListLoader: () async => switch (sessions.mode) {
        _Mode.stop => const [source, editableLocal],
        _Mode.copy => const [source, editableLocal],
        _Mode.delete => const [source],
      },
      sessionLogPageLoader: (_, __, ___) async => [],
    );

model.LogEntry _log(String id) => model.LogEntry(
      id: id,
      sessionId: source.sessionId,
      time: '2026-07-17T12:00:00Z',
      controller: 'BG5CRL',
      callsign: 'BA4AAA',
      report: '59',
      qth: '',
      device: '',
      power: '',
      antenna: '',
      height: '',
      createdAt: '2026-07-17T12:00:00Z',
      updatedAt: '2026-07-17T12:00:00Z',
    );

enum _Mode { stop, copy, delete }

class _ManagedSessions extends SessionProvider {
  _ManagedSessions(this.mode);

  final _Mode mode;
  Session? _current = source;
  int stopCalls = 0;
  int copyCalls = 0;
  int deleteCalls = 0;
  int databaseReloadCalls = 0;

  @override
  String? get currentSessionId => _current?.sessionId;

  @override
  Session? get currentSession => _current;

  @override
  Future<Session> stopCurrentCollaborationSessionLocally() async {
    stopCalls += 1;
    _current = editableLocal;
    notifyListeners();
    return editableLocal;
  }

  @override
  Future<Session> copyCurrentCollaborationSessionToLocal(
      {required String title}) async {
    copyCalls += 1;
    _current = editableLocal;
    notifyListeners();
    return editableLocal;
  }

  @override
  Future<void> deleteSessionLocally(String sessionId) async {
    deleteCalls += 1;
    _current = null;
    notifyListeners();
  }

  @override
  Future<void> reloadAfterDatabaseReplacement() async {
    databaseReloadCalls += 1;
    notifyListeners();
  }
}

class _ManagedCollaboration extends CollaborationProvider {
  @override
  LocalCollaborationBinding? get binding => const LocalCollaborationBinding(
        serverInstanceId: 'server-1',
        serverOrigin: 'https://offline.example.test',
        accountId: 'user-1',
        sessionId: 'collaboration-source',
        membershipId: 'membership-1',
        membershipVersion: 1,
        role: SessionRole.owner,
        replicaState: 'ready',
        lastAppliedSeq: 3,
        lastSeenHeadSeq: 5,
        revokedAt: null,
      );

  @override
  Future<void> refreshCurrentSession() async {}
}

class _OfflineServer extends ServerProvider {
  _OfflineServer() : super(autoLoadSettings: false);

  @override
  bool get isLoggedIn => false;

  @override
  String get serverUrl => 'https://offline.example.test';
}

const source = Session(
  sessionId: 'collaboration-source',
  title: 'Sunday net',
  status: 'active',
  createdAt: '2026-07-17T00:00:00Z',
  updatedAt: '2026-07-17T00:00:00Z',
);

const editableLocal = Session(
  sessionId: 'editable-local',
  title: 'Sunday net',
  status: 'active',
  createdAt: '2026-07-17T00:01:00Z',
  updatedAt: '2026-07-17T00:01:00Z',
);

const closedLocal = Session(
  sessionId: 'closed-local',
  title: 'Sunday net',
  status: 'closed',
  createdAt: '2026-07-17T00:01:00Z',
  updatedAt: '2026-07-17T00:02:00Z',
  closedAt: '2026-07-17T00:02:00Z',
);
