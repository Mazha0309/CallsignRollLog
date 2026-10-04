import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'current_session_id': source.sessionId,
    });
  });

  test('offline stop follows the replacement local session and persists it',
      () async {
    final requested = <String>[];
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      collaborationSessionLocalStopper: (sessionId) async {
        requested.add(sessionId);
        return editableLocal;
      },
    );
    addTearDown(provider.dispose);
    await provider.ready;

    final result = await provider.stopCurrentCollaborationSessionLocally();

    expect(requested, [source.sessionId]);
    expect(result, same(editableLocal));
    expect(provider.currentSessionId, editableLocal.sessionId);
    expect(provider.currentSession, same(editableLocal));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('current_session_id'), editableLocal.sessionId);
  });

  test('new session delegates lifecycle replacement to the transactional API',
      () async {
    final startedTitles = <String>[];
    final separatelyClosed = <String>[];
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      localSessionStarter: (title) async {
        startedTitles.add(title);
        return editableLocal;
      },
      localSessionCloser: (sessionId) async {
        separatelyClosed.add(sessionId);
        return closedLocal;
      },
    );
    addTearDown(provider.dispose);
    await provider.ready;

    await provider.startNewSession(title: '  Sunday replacement  ');

    expect(startedTitles, ['Sunday replacement']);
    expect(separatelyClosed, isEmpty);
    expect(provider.currentSession, same(editableLocal));
    expect(provider.currentSessionId, editableLocal.sessionId);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('current_session_id'), editableLocal.sessionId);
  });

  test('session entries consume collaboration metadata from one summary load',
      () async {
    var fallbackBindingChecks = 0;
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      sessionSummaryLoader: () async => const [
        SessionSummary(
          session: source,
          hasCollaborationBinding: true,
        ),
        SessionSummary(
          session: closedLocal,
          hasCollaborationBinding: false,
        ),
      ],
      sessionBindingChecker: (_) async {
        fallbackBindingChecks += 1;
        return false;
      },
    );
    addTearDown(provider.dispose);
    await provider.ready;

    final entries = await provider.listAvailableSessionEntries();

    expect(entries, hasLength(2));
    expect(entries.first.session, closedLocal);
    expect(entries.last.session, source);
    expect(entries.last.hasCollaborationBinding, isTrue);
    expect(fallbackBindingChecks, 0);
  });

  test('end rejects a collaboration replica before invoking the local closer',
      () async {
    final requested = <String>[];
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      sessionBindingChecker: (_) async => true,
      localSessionCloser: (sessionId) async {
        requested.add(sessionId);
        return closedLocal;
      },
    );
    addTearDown(provider.dispose);
    await provider.ready;

    await expectLater(
      provider.closeSessionLocally(source.sessionId),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', 'LOCAL_CLOSE_COLLABORATION_FORBIDDEN')),
    );
    expect(requested, isEmpty);
    expect(provider.currentSessionId, source.sessionId);
    expect(provider.currentSession, same(source));
  });

  test('ending local recording keeps the same identity and persists its status',
      () async {
    final ended = Session(
      sessionId: source.sessionId,
      title: source.title,
      status: 'closed',
      createdAt: source.createdAt,
      updatedAt: '2026-10-04T12:00:00Z',
      closedAt: '2026-10-04T12:00:00Z',
    );
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      sessionBindingChecker: (_) async => false,
      localSessionCloser: (_) async => ended,
    );
    addTearDown(provider.dispose);
    await provider.ready;
    await provider.closeSessionLocally(source.sessionId);
    expect(provider.currentSessionId, source.sessionId);
    expect(provider.currentSession?.status, 'closed');
    expect(provider.currentSession?.createdAt, source.createdAt);
  });

  test('deleting the selected local replica clears the safe selection',
      () async {
    final requested = <String>[];
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      localSessionDeleter: (sessionId) async => requested.add(sessionId),
    );
    addTearDown(provider.dispose);
    await provider.ready;

    await provider.deleteSessionLocally(source.sessionId);

    expect(requested, [source.sessionId]);
    expect(provider.currentSessionId, isNull);
    expect(provider.currentSession, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('current_session_id'), isFalse);
  });

  test('closing a non-current row does not replace the current selection',
      () async {
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      localSessionCloser: (_) async => otherClosed,
      sessionBindingChecker: (_) async => false,
    );
    addTearDown(provider.dispose);
    await provider.ready;

    await provider.closeSessionLocally('other-collaboration');

    expect(provider.currentSessionId, source.sessionId);
    expect(provider.currentSession, same(source));
  });

  test('a committed offline stop does not overwrite a newer selection',
      () async {
    final committed = Completer<Session>();
    final provider = SessionProvider(
      sessionListLoader: () async => [source, otherActive],
      collaborationSessionLocalStopper: (_) => committed.future,
    );
    addTearDown(provider.dispose);
    await provider.ready;

    final stopping = provider.stopCurrentCollaborationSessionLocally();
    await Future<void>.delayed(Duration.zero);
    await provider.switchToSession(otherActive.sessionId);
    committed.complete(editableLocal);

    expect(await stopping, same(editableLocal));
    expect(provider.currentSessionId, otherActive.sessionId);
    expect(provider.currentSession, same(otherActive));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('current_session_id'), otherActive.sessionId);
  });

  test('default provider does not automatically end an idle session', () async {
    var sweeps = 0;
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      inactiveLocalSessionCloser: () async {
        sweeps++;
        return [closedLocal];
      },
    );
    addTearDown(provider.dispose);
    await provider.ready;
    expect(sweeps, 0);
    expect(provider.currentSession?.status, 'active');
  });

  test('explicitly enabled legacy inactivity maintenance adopts its result',
      () async {
    var sweeps = 0;
    final provider = SessionProvider(
      sessionListLoader: () async => [source],
      inactiveLocalSessionCloser: () async {
        sweeps += 1;
        return const [automaticallyClosed];
      },
      enableAutomaticInactivityClose: true,
    );
    addTearDown(provider.dispose);

    await provider.ready;

    expect(sweeps, 1);
    expect(provider.currentSessionId, source.sessionId);
    expect(provider.currentSession, same(automaticallyClosed));
    expect(provider.currentSession?.status, 'closed');
    expect(provider.dataRevision, 1);
  });
}

const source = Session(
  sessionId: 'collaboration-session',
  title: 'Sunday net',
  status: 'active',
  createdAt: '2026-07-13T00:00:00Z',
  updatedAt: '2026-07-13T00:00:00Z',
);

const editableLocal = Session(
  sessionId: 'editable-local',
  title: 'Sunday net',
  status: 'active',
  createdAt: '2026-07-14T00:00:00Z',
  updatedAt: '2026-07-14T00:00:00Z',
);

const closedLocal = Session(
  sessionId: 'closed-local',
  title: 'Sunday net',
  status: 'closed',
  createdAt: '2026-07-14T00:00:00Z',
  updatedAt: '2026-07-14T00:01:00Z',
  closedAt: '2026-07-14T00:01:00Z',
);

const otherClosed = Session(
  sessionId: 'other-local-history',
  title: 'Other net',
  status: 'closed',
  createdAt: '2026-07-14T00:00:00Z',
  updatedAt: '2026-07-14T00:01:00Z',
  closedAt: '2026-07-14T00:01:00Z',
);

const otherActive = Session(
  sessionId: 'other-local-active',
  title: 'Other active net',
  status: 'active',
  createdAt: '2026-07-14T00:00:00Z',
  updatedAt: '2026-07-14T00:01:00Z',
);

const automaticallyClosed = Session(
  sessionId: 'collaboration-session',
  title: 'Sunday net',
  status: 'closed',
  createdAt: '2026-07-13T00:00:00Z',
  updatedAt: '2026-07-13T02:01:00Z',
  closedAt: '2026-07-13T02:01:00Z',
);
