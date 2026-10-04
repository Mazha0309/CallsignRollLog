import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:openlogtool/src/bridge/api/sessions.dart' as session_api;
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/src/bridge/frb_generated.dart';
import 'package:openlogtool/services/app_logger.dart';
import 'package:openlogtool/models/account_share_dto.dart';

typedef LocalSessionReopener = Future<Session> Function(String sessionId);
typedef LocalSessionStarter = Future<Session> Function(String title);
typedef CollaborationSessionLocalCopier = Future<Session> Function(
  String sessionId,
  String title,
);
typedef CollaborationSessionLocalConverter = Future<Session> Function(
  String sessionId,
);
typedef CollaborationSessionLocalStopper = Future<Session> Function(
  String sessionId,
);
typedef LocalSessionCloser = Future<Session> Function(String sessionId);
typedef LocalSessionDeleter = Future<void> Function(String sessionId);
typedef CurrentSessionIdWriter = Future<bool> Function(String sessionId);
typedef SessionListLoader = Future<List<Session>> Function();
typedef SessionSummaryLoader = Future<List<SessionSummary>> Function();
typedef SessionCollaborationBindingChecker = Future<bool> Function(
  String sessionId,
);
typedef InactiveLocalSessionCloser = Future<List<Session>> Function();

@immutable
class SessionListEntry {
  const SessionListEntry({
    required this.session,
    required this.hasCollaborationBinding,
    this.isShared = false,
    this.sharedGrantorUsername,
    this.sharedSession,
  });

  final Session session;
  final bool hasCollaborationBinding;
  final bool isShared;
  final String? sharedGrantorUsername;
  final SharedSessionDto? sharedSession;
}

class SessionProvider with ChangeNotifier {
  static const _key = 'current_session_id';
  static const _inactivityCheckInterval = Duration(minutes: 1);
  static const _databaseRevisionKey = 'local_database_replacement_revision';
  static const _databaseReplacementPendingKey =
      'local_database_replacement_pending';

  final LocalSessionReopener _localSessionReopener;
  final LocalSessionStarter _localSessionStarter;
  final CollaborationSessionLocalCopier _collaborationSessionLocalCopier;
  final CollaborationSessionLocalConverter _collaborationSessionLocalConverter;
  final CollaborationSessionLocalStopper _collaborationSessionLocalStopper;
  final LocalSessionCloser _localSessionCloser;
  final LocalSessionDeleter _localSessionDeleter;
  final CurrentSessionIdWriter? _currentSessionIdWriter;
  final SessionListLoader _sessionListLoader;
  final SessionSummaryLoader? _sessionSummaryLoader;
  final SessionCollaborationBindingChecker _sessionBindingChecker;
  final InactiveLocalSessionCloser _inactiveLocalSessionCloser;
  final bool _inactivityCloserRequiresRust;
  final bool _automaticInactivityCloseEnabled;
  bool _disposed = false;
  bool _inactivityCheckRunning = false;
  Timer? _inactivityTimer;
  String? _currentSessionId;
  Session? _currentSession;
  int _databaseRevision = 0;
  int _dataRevision = 0;
  int _collaborationCatalogRevision = 0;
  // Fail closed until SharedPreferences has proved that no replacement was
  // interrupted. Personal-cloud synchronization awaits [ready], so a
  // preference read failure cannot accidentally expose a stale baseline.
  bool _databaseReplacementPending = true;
  Completer<void>? _initCompleter;

  String? get currentSessionId => _currentSessionId;
  Session? get currentSession => _currentSession;
  int get databaseRevision => _databaseRevision;
  int get dataRevision => _dataRevision;
  int get collaborationCatalogRevision => _collaborationCatalogRevision;
  bool get databaseReplacementPending => _databaseReplacementPending;

  Future<void> get ready => _initCompleter?.future ?? Future.value();

  SessionProvider({
    LocalSessionStarter? localSessionStarter,
    LocalSessionReopener? localSessionReopener,
    CollaborationSessionLocalCopier? collaborationSessionLocalCopier,
    CollaborationSessionLocalConverter? collaborationSessionLocalConverter,
    CollaborationSessionLocalStopper? collaborationSessionLocalStopper,
    LocalSessionCloser? localSessionCloser,
    LocalSessionDeleter? localSessionDeleter,
    CurrentSessionIdWriter? currentSessionIdWriter,
    SessionListLoader? sessionListLoader,
    SessionSummaryLoader? sessionSummaryLoader,
    SessionCollaborationBindingChecker? sessionBindingChecker,
    InactiveLocalSessionCloser? inactiveLocalSessionCloser,
    bool? enableAutomaticInactivityClose,
  })  : _localSessionStarter = localSessionStarter ??
            ((title) => session_api.startLocalSession(title: title)),
        _localSessionReopener = localSessionReopener ??
            ((sessionId) => RustApi.reopenLocalSession(sessionId: sessionId)),
        _collaborationSessionLocalCopier = collaborationSessionLocalCopier ??
            ((sessionId, title) => RustApi.copyCollaborationSessionToLocal(
                  sessionId: sessionId,
                  title: title,
                )),
        _collaborationSessionLocalConverter =
            collaborationSessionLocalConverter ??
                ((sessionId) => RustApi.convertCollaborationSessionToLocal(
                      sessionId: sessionId,
                    )),
        _collaborationSessionLocalStopper = collaborationSessionLocalStopper ??
            ((sessionId) => RustApi.stopCollaborationSessionLocally(
                  sessionId: sessionId,
                )),
        _localSessionCloser = localSessionCloser ??
            ((sessionId) => RustApi.closeSessionLocally(sessionId: sessionId)),
        _localSessionDeleter = localSessionDeleter ??
            ((sessionId) => RustApi.hardDeleteSession(sessionId: sessionId)),
        _currentSessionIdWriter = currentSessionIdWriter,
        _sessionListLoader = sessionListLoader ?? RustApi.listSessions,
        _sessionSummaryLoader = sessionSummaryLoader ??
            (sessionListLoader == null
                ? session_api.listSessionSummaries
                : null),
        _sessionBindingChecker = sessionBindingChecker ??
            ((sessionId) async =>
                await RustApi.getSessionCollaborationBinding(
                  sessionId: sessionId,
                ) !=
                null),
        _inactiveLocalSessionCloser = inactiveLocalSessionCloser ??
            (() => session_api.closeInactiveLocalSessions()),
        _inactivityCloserRequiresRust = inactiveLocalSessionCloser == null,
        // Lifecycle maintenance is enabled explicitly by the production app
        // root. Isolated widget/provider tests and alternate embedders do not
        // have to initialize Rust merely by constructing this provider.
        _automaticInactivityCloseEnabled =
            enableAutomaticInactivityClose ?? false {
    final completer = Completer<void>();
    _initCompleter = completer;
    scheduleMicrotask(() async {
      try {
        await _init();
      } catch (e, st) {
        AppLogger.instance.log(
          AppLogLevel.error,
          'Session provider initialization failed',
          source: 'SessionProvider',
          error: e,
          stackTrace: st,
        );
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    super.dispose();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> _init() async {
    final prefs = await openKeyValueStore();
    _databaseRevision = await prefs.getInt(_databaseRevisionKey) ?? 0;
    _databaseReplacementPending =
        await prefs.getBool(_databaseReplacementPendingKey);
    final storedId = await prefs.getString(_key);

    if (storedId != null && storedId.isNotEmpty) {
      try {
        final sessions = await _sessionListLoader();
        final match = sessions
            .where((s) => s.sessionId == storedId && s.deletedAt == null)
            .toList();
        if (match.isNotEmpty) {
          _currentSession = match.first;
          _currentSessionId = match.first.sessionId;
        } else {
          AppLogger.instance.log(
            AppLogLevel.warning,
            'Stored current session $storedId no longer exists; clearing it',
            source: 'SessionProvider',
          );
          await prefs.remove(_key);
        }
      } catch (_) {}
    }

    if (_automaticInactivityCloseEnabled &&
        (!_inactivityCloserRequiresRust || RustLib.instance.initialized)) {
      await _runInactivityCheck();
      if (!_disposed) {
        _inactivityTimer = Timer.periodic(
          _inactivityCheckInterval,
          (_) => unawaited(_runInactivityCheck()),
        );
      }
    }

    // Don't auto-create — wait for user to create via dialog
    _safeNotify();
  }

  /// Runs the same inactivity maintenance used at startup and once per minute.
  /// Rust performs the two-hour cutoff check and close atomically; this layer
  /// only reconciles the selected Session and personal-cloud dirty revision.
  Future<List<Session>> closeInactiveLocalSessionsNow() async {
    await ready;
    return _runInactivityCheck();
  }

  Future<List<Session>> _runInactivityCheck() async {
    if (_disposed || _inactivityCheckRunning) return const [];
    _inactivityCheckRunning = true;
    try {
      final closed = await _inactiveLocalSessionCloser();
      if (closed.isEmpty || _disposed) return closed;

      final currentId = _currentSessionId;
      if (currentId != null) {
        for (final session in closed) {
          if (session.sessionId == currentId &&
              _currentSessionId == currentId) {
            _currentSession = session;
            break;
          }
        }
      }
      _markPersonalDataChanged();
      AppLogger.instance.log(
        AppLogLevel.info,
        'Closed ${closed.length} inactive local session(s)',
        source: 'SessionProvider',
      );
      return closed;
    } catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Inactive-session maintenance failed',
        source: 'SessionProvider',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    } finally {
      _inactivityCheckRunning = false;
    }
  }

  Future<String> getOrCreateSessionId() async {
    await ready;
    if (_currentSessionId == null) {
      await _ensureActiveSession();
    }
    return _currentSessionId!;
  }

  Future<void> _ensureActiveSession() async {
    try {
      final sessions = await _sessionListLoader();
      final active = sessions
          .where((s) => s.status == 'active' && s.deletedAt == null)
          .toList();
      if (active.isNotEmpty) {
        _currentSession = active.first;
        _currentSessionId = active.first.sessionId;
        await _saveCurrentSessionId();
        _safeNotify();
        return;
      }
    } catch (_) {}
  }

  Future<void> startNewSession(
      {String? title, bool autoGenerated = false}) async {
    try {
      final now = DateTime.now();
      final defaultTitle = autoGenerated
          ? '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} 记录'
          : ((title?.trim().isNotEmpty ?? false) ? title!.trim() : '新记录');

      // Rust closes the previous local-only recorder and inserts the
      // replacement in one transaction. Collaboration replicas stay intact.
      final session = await _localSessionStarter(defaultTitle);
      // The database transaction has already committed, so adopt its
      // canonical result even if preference storage is temporarily broken.
      _currentSession = session;
      _currentSessionId = session.sessionId;
      _markPersonalDataChanged();
      _safeNotify();
      try {
        await _persistCurrentSessionId(session.sessionId);
      } catch (error, stackTrace) {
        AppLogger.instance.log(
          AppLogLevel.warning,
          'Could not persist the new current-session selection',
          source: 'SessionProvider',
          error: error,
          stackTrace: stackTrace,
        );
      }
      AppLogger.instance.log(
        AppLogLevel.info,
        'Started local session ${session.sessionId}',
        source: 'SessionProvider',
      );
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not start a local session',
        source: 'SessionProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<List<Session>> listAvailableSessions() async {
    await ready;
    final sessions = await _sessionListLoader();
    final available = sessions
        .where((session) => session.deletedAt == null)
        .toList(growable: false);
    return [...available]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  Future<List<SessionListEntry>> listAvailableSessionEntries() async {
    await ready;
    final summaryLoader = _sessionSummaryLoader;
    if (summaryLoader != null) {
      final summaries = await summaryLoader();
      final entries = summaries
          .where((summary) => summary.session.deletedAt == null)
          .map(
            (summary) => SessionListEntry(
              session: summary.session,
              hasCollaborationBinding: summary.hasCollaborationBinding,
            ),
          )
          .toList(growable: false)
        ..sort(
          (left, right) =>
              right.session.createdAt.compareTo(left.session.createdAt),
        );
      return entries;
    }

    // Injection-friendly fallback used by provider tests and embedders that
    // supply an alternate session list source.
    final sessions = await listAvailableSessions();
    return Future.wait(
      sessions.map(
        (session) async => SessionListEntry(
          session: session,
          hasCollaborationBinding:
              await _sessionBindingChecker(session.sessionId),
        ),
      ),
    );
  }

  Future<void> switchToSession(String sessionId) async {
    final sessions = await listAvailableSessions();
    final match = sessions.where((s) => s.sessionId == sessionId).toList();
    if (match.isEmpty) {
      throw StateError('Session not found: $sessionId');
    }

    final nextSession = match.first;
    await _persistCurrentSessionId(nextSession.sessionId);
    _currentSession = nextSession;
    _currentSessionId = nextSession.sessionId;
    _safeNotify();
  }

  /// Reactivates and selects a closed local-only session.
  ///
  /// Rust reactivates only the target; other sessions retain their status.
  Future<void> reopenLocalSession(String sessionId) async {
    final reopened = await _localSessionReopener(sessionId);

    // The database transaction has already committed. Adopt its canonical
    // result before touching preferences so an I/O failure cannot leave the
    // in-memory provider presenting the resumed session with stale status.
    _currentSession = reopened;
    _currentSessionId = reopened.sessionId;
    _markPersonalDataChanged();
    _safeNotify();
    try {
      await _persistCurrentSessionId(reopened.sessionId);
    } catch (error, stackTrace) {
      // Persistence only controls which session is restored on next launch.
      // The committed database state remains authoritative for this process.
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Could not persist the reopened current-session selection',
        source: 'SessionProvider',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Creates and selects an independent local copy of the current
  /// collaboration session without contacting its server.
  Future<Session> copyCurrentCollaborationSessionToLocal({
    required String title,
  }) async {
    await ready;
    final sourceSessionId = _currentSessionId;
    if (sourceSessionId == null || _currentSession == null) {
      throw StateError('NO_CURRENT_SESSION');
    }
    final normalized = title.trim();
    if (normalized.isEmpty || normalized.runes.length > 200) {
      throw ArgumentError('会话标题长度应为 1–200 个字符');
    }

    final local = await _collaborationSessionLocalCopier(
      sourceSessionId,
      normalized,
    );
    if (local.sessionId == sourceSessionId || local.status != 'active') {
      throw StateError('LOCAL_SESSION_COPY_INVALID');
    }
    if (_currentSessionId != sourceSessionId) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'A local collaboration copy completed after the current session '
        'changed; preserving the newer selection',
        source: 'SessionProvider',
      );
      return local;
    }

    _currentSession = local;
    _currentSessionId = local.sessionId;
    _markPersonalDataChanged();
    _safeNotify();
    try {
      await _persistCurrentSessionId(local.sessionId);
    } catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Could not persist the local-copy session selection',
        source: 'SessionProvider',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return local;
  }

  /// Replaces the current synchronized replica with one independent local
  /// Session. Rust changes the Session and Log IDs atomically so rejoining the
  /// server Session later cannot collide with the converted local record.
  Future<Session> convertCurrentCollaborationSessionToLocal() async {
    await ready;
    final sourceSessionId = _currentSessionId;
    if (sourceSessionId == null || _currentSession == null) {
      throw StateError('NO_CURRENT_SESSION');
    }

    final local = await _collaborationSessionLocalConverter(sourceSessionId);
    if (local.sessionId == sourceSessionId || local.status != 'active') {
      throw StateError('LOCAL_SESSION_CONVERSION_INVALID');
    }
    if (_currentSessionId != sourceSessionId) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Collaboration conversion completed after the current session '
        'changed; preserving the newer selection',
        source: 'SessionProvider',
      );
      return local;
    }

    _currentSession = local;
    _currentSessionId = local.sessionId;
    _markPersonalDataChanged();
    _safeNotify();
    try {
      await _persistCurrentSessionId(local.sessionId);
    } catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Could not persist the converted local-session selection',
        source: 'SessionProvider',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return local;
  }

  /// Stops synchronization for the current collaboration replica without
  /// contacting its server. Saved rows are retained in a replacement local
  /// session; replica queues and draft-only state are discarded by Rust.
  Future<Session> stopCurrentCollaborationSessionLocally() async {
    await ready;
    final sourceSessionId = _currentSessionId;
    if (sourceSessionId == null || _currentSession == null) {
      throw StateError('NO_CURRENT_SESSION');
    }

    final local = await _collaborationSessionLocalStopper(sourceSessionId);
    if (local.sessionId == sourceSessionId || local.status != 'active') {
      throw StateError('LOCAL_SESSION_CONVERSION_INVALID');
    }
    if (_currentSessionId != sourceSessionId) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Stopping local collaboration completed after the current session '
        'changed; preserving the newer selection',
        source: 'SessionProvider',
      );
      return local;
    }

    await _adoptCurrentSession(local, operation: 'stopped collaboration');
    _markPersonalDataChanged();
    return local;
  }

  /// Ends a local-only session, preserving its identity and records.
  /// Collaboration sessions are rejected, including by the native transaction,
  /// so ending a session can never silently detach a replica or discard a queue.
  Future<Session> closeSessionLocally(String sessionId) async {
    await ready;
    if (await _sessionBindingChecker(sessionId)) {
      throw StateError('LOCAL_CLOSE_COLLABORATION_FORBIDDEN');
    }
    final wasCurrent = _currentSessionId == sessionId;
    final closed = await _localSessionCloser(sessionId);
    _markPersonalDataChanged();
    if (wasCurrent && _currentSessionId == sessionId) {
      await _adoptCurrentSession(closed, operation: 'closed local session');
    }
    return closed;
  }

  /// Permanently deletes one device-local session or collaboration replica.
  /// This method never contacts the server.
  Future<void> deleteSessionLocally(String sessionId) async {
    await ready;
    await _localSessionDeleter(sessionId);
    _markPersonalDataChanged();
    if (_currentSessionId != sessionId) return;
    _currentSession = null;
    _currentSessionId = null;
    _safeNotify();
    try {
      final prefs = await openKeyValueStore();
      await prefs.remove(_key);
    } catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Could not clear the deleted current-session selection',
        source: 'SessionProvider',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _adoptCurrentSession(
    Session session, {
    required String operation,
  }) async {
    _currentSession = session;
    _currentSessionId = session.sessionId;
    _safeNotify();
    try {
      await _persistCurrentSessionId(session.sessionId);
    } catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Could not persist current-session selection after $operation',
        source: 'SessionProvider',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> reloadCurrentSession() async {
    final sessionId = _currentSessionId;
    if (sessionId == null) return;
    final sessions = await _sessionListLoader();
    final matches = sessions.where((session) => session.sessionId == sessionId);
    if (matches.isEmpty) {
      await handleSessionDeleted(sessionId);
      _safeNotify();
      return;
    }
    _currentSession = matches.first;
    _safeNotify();
  }

  /// Reconciles the selected session after the entire local database has been
  /// cleared or replaced from a backup.
  ///
  /// The previous selection is retained when the imported database contains
  /// it. Otherwise the newest active local row is selected so imported records
  /// become visible immediately; an empty database clears the selection.
  Future<void> reloadAfterDatabaseReplacement() async {
    await ready;
    final previousSessionId = _currentSessionId;
    final sessions = (await _sessionListLoader())
        .where((session) => session.deletedAt == null)
        .toList(growable: false);

    Session? selected;
    for (final session in sessions) {
      if (session.sessionId == previousSessionId) {
        selected = session;
        break;
      }
    }
    if (selected == null) {
      final active = sessions
          .where((session) => session.status == 'active')
          .toList(growable: false)
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      if (active.isNotEmpty) selected = active.first;
    }

    _currentSession = selected;
    _currentSessionId = selected?.sessionId;
    final nextDatabaseRevision = _databaseRevision + 1;
    _databaseRevision = nextDatabaseRevision;
    _safeNotify();

    final prefs = await openKeyValueStore();
    final revisionSaved =
        await prefs.setInt(_databaseRevisionKey, nextDatabaseRevision);
    if (!revisionSaved) {
      throw StateError('LOCAL_DATABASE_REVISION_PERSIST_FAILED');
    }
    try {
      if (selected == null) {
        await prefs.remove(_key);
      } else {
        await _persistCurrentSessionId(selected.sessionId);
      }
    } catch (error, stackTrace) {
      // The database replacement has already committed. A preference failure
      // must not put the in-memory providers back on stale database rows.
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Could not persist the current-session selection after database '
        'replacement',
        source: 'SessionProvider',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Persists a crash-recovery sentinel before any whole-database mutation.
  ///
  /// Callers must await this method before invoking the transaction. A write
  /// failure prevents the mutation and safely restores the prior in-memory
  /// state; a sentinel inherited from an earlier crash remains raised.
  Future<bool> prepareForDatabaseReplacement() async {
    await ready;
    final wasPending = _databaseReplacementPending;
    if (!_databaseReplacementPending) {
      _databaseReplacementPending = true;
      _safeNotify();
    }
    try {
      final prefs = await openKeyValueStore();
      final saved = await prefs.setBool(_databaseReplacementPendingKey, true);
      if (!saved) {
        throw StateError(
          'LOCAL_DATABASE_REPLACEMENT_SENTINEL_PERSIST_FAILED',
        );
      }
      return !wasPending;
    } catch (_) {
      // The database operation has not started, so restoring the previous
      // in-memory state is safe and lets the user retry once storage recovers.
      if (_databaseReplacementPending != wasPending) {
        _databaseReplacementPending = wasPending;
        _safeNotify();
      }
      rethrow;
    }
  }

  /// Clears a prepared sentinel only when the database transaction explicitly
  /// failed and therefore rolled back without changing durable rows.
  Future<void> rollbackFailedDatabaseReplacement() =>
      _clearDatabaseReplacementSentinel();

  /// Acknowledges a committed replacement after provider reload and database
  /// revision persistence have both completed successfully.
  Future<void> acknowledgeDatabaseReplacement() =>
      _clearDatabaseReplacementSentinel();

  Future<void> _clearDatabaseReplacementSentinel() async {
    final prefs = await openKeyValueStore();
    final removed = await prefs.remove(_databaseReplacementPendingKey);
    if (!removed && await prefs.containsKey(_databaseReplacementPendingKey)) {
      throw StateError('LOCAL_DATABASE_REPLACEMENT_SENTINEL_CLEAR_FAILED');
    }
    if (_databaseReplacementPending) {
      _databaseReplacementPending = false;
      _safeNotify();
    }
  }

  Future<void> renameCurrentSession(String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty || normalized.length > 200) {
      throw ArgumentError('会话标题长度应为 1–200 个字符');
    }
    final sessionId = _currentSessionId;
    final session = _currentSession;
    if (sessionId == null || session == null) {
      throw StateError('NO_CURRENT_SESSION');
    }
    if (session.status != 'active') {
      throw StateError('SESSION_CLOSED');
    }
    if (normalized == session.title) return;

    await RustApi.updateCollaborationSessionTitle(
      sessionId: sessionId,
      title: normalized,
    );
    _markPersonalDataChanged();
    if (_currentSessionId == sessionId) {
      await reloadCurrentSession();
    }
  }

  Future<void> handleSessionDeleted(String sessionId) async {
    if (_currentSessionId == sessionId) {
      _currentSession = null;
      _currentSessionId = null;
      final prefs = await openKeyValueStore();
      await prefs.remove(_key);
    }
  }

  Future<void> _saveCurrentSessionId() async {
    if (_currentSessionId != null) {
      await _persistCurrentSessionId(_currentSessionId!);
    }
  }

  Future<void> _persistCurrentSessionId(String sessionId) async {
    final writer = _currentSessionIdWriter;
    final saved = writer != null
        ? await writer(sessionId)
        : await (await openKeyValueStore()).setString(
            _key,
            sessionId,
          );
    if (!saved) {
      throw StateError('Failed to persist current session: $sessionId');
    }
  }

  void _markPersonalDataChanged() {
    _dataRevision += 1;
    _safeNotify();
  }

  /// Invalidates session-list readers after a background collaboration
  /// snapshot install without marking personal-cloud data as changed.
  void notifyCollaborationCatalogChanged() {
    _collaborationCatalogRevision += 1;
    _safeNotify();
  }
}
