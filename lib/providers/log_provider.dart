import 'package:flutter/material.dart';
import 'dart:async';
import 'package:openlogtool/models/log_entry.dart' as old;
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:openlogtool/src/bridge/models/log_entry.dart' as bridge;
import 'package:openlogtool/src/bridge/models/session.dart' as session_bridge;
import 'package:openlogtool/utils/log_time.dart';
import 'package:openlogtool/services/app_logger.dart';

typedef LogMutationGuard = String? Function(old.LogEntry log);
typedef SessionListLoader = Future<List<session_bridge.Session>> Function();
typedef SessionLogPageLoader = Future<List<bridge.LogEntry>> Function(
  String sessionId,
  int page,
  int pageSize,
);
typedef LogCreator = Future<bridge.LogEntry> Function(
  String sessionId,
  old.LogEntry log,
);
typedef LogUpdater = Future<bridge.LogEntry> Function(
  String syncId,
  old.LogEntry original,
  old.LogEntry replacement,
);
typedef LogDeleter = Future<void> Function(String syncId);
typedef LogRestorer = Future<bridge.LogEntry> Function(String syncId);

Future<bridge.LogEntry> _createLogWithRust(
  String sessionId,
  old.LogEntry log,
) =>
    RustApi.addLog(
      sessionId: sessionId,
      controller: log.controller,
      callsign: log.callsign,
      time: normalizeLogTimeForStorage(
        log.time,
        reference: DateTime.tryParse(log.createdAt),
      ),
      rstSent: log.report,
      rstRcvd: log.rstRcvd,
      qth: log.qth,
      device: log.device,
      power: log.power,
      antenna: log.antenna,
      height: log.height,
      remarks: log.remarks.isNotEmpty ? log.remarks : null,
    );

Future<bridge.LogEntry> _updateLogWithRust(
  String syncId,
  old.LogEntry original,
  old.LogEntry replacement,
) =>
    RustApi.updateLog(
      syncId: syncId,
      controller: replacement.controller,
      callsign: replacement.callsign,
      time: normalizeLogTimeForStorage(
        replacement.time,
        reference: DateTime.tryParse(original.time) ??
            DateTime.tryParse(original.createdAt),
      ),
      rstSent: replacement.report,
      rstRcvd: replacement.rstRcvd,
      qth: replacement.qth,
      device: replacement.device,
      power: replacement.power,
      antenna: replacement.antenna,
      height: replacement.height,
      remarks: replacement.remarks.isNotEmpty ? replacement.remarks : null,
    );

class LogProvider with ChangeNotifier {
  static const int _maxUndoStack = 50;

  bool _disposed = false;
  // Keep the client-side contract chronological (oldest -> newest). The Rust
  // query returns newest first for efficient paging, while the table reverses
  // this list for display and other consumers use `logs.last` as the latest
  // completed record.
  List<old.LogEntry> _logs = [];
  final List<old.LogEntry> _undoStack = [];
  final Map<String, old.LogEntry> _pendingCanonicalLogs = {};
  Future<void> Function()? _onDataChanged;
  Future<void> Function(old.LogEntry log, bool isDelete)? _onLogChanged;
  LogMutationGuard? _logMutationGuard;
  final SessionListLoader _sessionListLoader;
  final SessionLogPageLoader _sessionLogPageLoader;
  final LogCreator _logCreator;
  final LogUpdater _logUpdater;
  final LogDeleter _logDeleter;
  final LogRestorer _logRestorer;
  String? _currentSessionId;
  bool _currentSessionWritable = false;
  int _sessionStateGeneration = 0;
  int _loadGeneration = 0;
  final Set<String> _collaborationReadOnlySessions = <String>{};
  int _dataRevision = 0;

  List<old.LogEntry> get logs => _logs;
  bool get hasReadAccess => true;
  int get logCount => _logs.length;
  int get dataRevision => _dataRevision;
  String? get currentSessionId => _currentSessionId;
  bool get canUndo =>
      _undoStack.isNotEmpty &&
      !currentSessionReadOnly &&
      mutationBlockReason(_undoStack.last) == null;
  bool get canClearAllLogs =>
      _logs.isNotEmpty &&
      !currentSessionReadOnly &&
      _logs.every((log) => mutationBlockReason(log) == null);
  bool get currentSessionReadOnly =>
      _currentSessionId != null &&
      (!_currentSessionWritable ||
          _collaborationReadOnlySessions.contains(_currentSessionId));

  void setCollaborationReadOnly(String sessionId, bool readOnly) {
    final changed = readOnly
        ? _collaborationReadOnlySessions.add(sessionId)
        : _collaborationReadOnlySessions.remove(sessionId);
    if (changed) _safeNotify();
  }

  void setLogMutationGuard(LogMutationGuard? guard) {
    if (identical(_logMutationGuard, guard)) return;
    _logMutationGuard = guard;
  }

  void refreshMutationPermissions() => _safeNotify();

  /// Shows a canonical server row while its durable collaboration event is
  /// still catching up through Rust. The overlay survives intervening reloads
  /// and is retired once SQLite returns the same sync id.
  void stageCanonicalLog(old.LogEntry log) {
    final sessionId = log.sessionId;
    if (sessionId == null || sessionId != _currentSessionId) return;
    _loadGeneration += 1;
    _pendingCanonicalLogs[log.id] = log;
    _logs = [
      for (final candidate in _logs)
        if (candidate.id != log.id) candidate,
      log,
    ]..sort(_compareChronologically);
    _safeNotify();
  }

  /// Replaces an optimistic server row with the latest durable SQLite state.
  /// A later update/delete may already follow the original create event, so
  /// merely removing the pending marker would leave a stale or ghost row.
  Future<void> reconcileStagedCanonicalLog(String syncId) async {
    final staged = _pendingCanonicalLogs.remove(syncId);
    try {
      await _loadLogs(propagateErrors: true);
    } catch (_) {
      if (staged != null) {
        _pendingCanonicalLogs[syncId] = staged;
        _safeNotify();
      }
      rethrow;
    }
  }

  String? mutationBlockReason(old.LogEntry log) {
    final sessionId = log.sessionId ?? _currentSessionId;
    if (sessionId != null &&
        _collaborationReadOnlySessions.contains(sessionId)) {
      return 'COLLABORATION_SESSION_READ_ONLY';
    }
    if (_pendingCanonicalLogs.containsKey(log.id)) {
      return 'COLLABORATION_LOG_SYNC_PENDING';
    }
    return _logMutationGuard?.call(log);
  }

  bool canMutateLog(old.LogEntry log) => mutationBlockReason(log) == null;

  bool canDeleteLog(old.LogEntry log) => canMutateLog(log);

  Future<void> deleteLogFromOriginal(old.LogEntry original) =>
      deleteLogById(original.id);

  /// Keep the editor's original row available to remote CAS implementations.
  Future<void> updateLogFromOriginal(
          old.LogEntry original, old.LogEntry replacement) =>
      updateLogById(original.id, replacement);

  void _ensureWritable(String? sessionId) {
    if (sessionId != null &&
        sessionId == _currentSessionId &&
        !_currentSessionWritable) {
      throw StateError('SESSION_CLOSED: 已关闭的会话只能查看');
    }
    if (sessionId != null &&
        _collaborationReadOnlySessions.contains(sessionId)) {
      throw StateError(
        'COLLABORATION_SESSION_READ_ONLY: 当前角色、会话状态或同步状态不允许写入',
      );
    }
  }

  void _ensureLogWritable(old.LogEntry log) {
    _ensureWritable(log.sessionId ?? _currentSessionId);
    final reason = mutationBlockReason(log);
    if (reason != null) throw StateError(reason);
  }

  void setOnDataChanged(Future<void> Function()? callback) {
    _onDataChanged = callback;
  }

  void setOnLogChanged(
      Future<void> Function(old.LogEntry log, bool isDelete)? callback) {
    _onLogChanged = callback;
  }

  Future<void> reloadForSession(
    String? sessionId, {
    bool propagateErrors = false,
  }) async {
    final sessionChanged = _currentSessionId != sessionId;
    if (sessionChanged) {
      _undoStack.clear();
      _logs = [];
    }
    final stateGeneration = ++_sessionStateGeneration;
    _currentSessionId = sessionId;
    _currentSessionWritable = false;
    if (sessionChanged) _safeNotify();
    if (sessionId != null) {
      try {
        final sessions = await _sessionListLoader();
        if (stateGeneration != _sessionStateGeneration ||
            _currentSessionId != sessionId) {
          return;
        }
        _currentSessionWritable = sessions.any(
          (session) =>
              session.sessionId == sessionId &&
              session.status == 'active' &&
              session.deletedAt == null,
        );
      } catch (error, stackTrace) {
        AppLogger.instance.log(
          AppLogLevel.error,
          'Could not load writable state for session $sessionId',
          source: 'LogProvider',
          error: error,
          stackTrace: stackTrace,
        );
        if (stateGeneration != _sessionStateGeneration ||
            _currentSessionId != sessionId) {
          return;
        }
        _safeNotify();
        if (propagateErrors) rethrow;
      }
    }
    await _loadLogs(propagateErrors: propagateErrors);
  }

  /// Drops all in-memory state tied to the previous database contents, then
  /// loads the selected session from the newly cleared/imported database.
  Future<void> reloadAfterDatabaseReplacement(String? sessionId) async {
    _undoStack.clear();
    _pendingCanonicalLogs.clear();
    _collaborationReadOnlySessions.clear();
    _logs = [];
    _safeNotify();
    await reloadForSession(sessionId, propagateErrors: true);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> _notifyDataChanged() async {
    if (_onDataChanged != null) {
      unawaited(_onDataChanged!());
    }
  }

  int get todayLogCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _logs.where((log) {
      final dt = _parseLogTimestamp(log);
      if (dt == null) return false;
      return dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
    }).length;
  }

  int get last7DaysCount {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _logs.where((log) {
      final dt = _parseLogTimestamp(log);
      if (dt == null) return false;
      return dt.isAfter(weekAgo) || dt.isAtSameMomentAs(weekAgo);
    }).length;
  }

  DateTime? _parseLogTimestamp(old.LogEntry log) {
    // Prefer creation timestamp; fall back to QSO time if it is a full ISO/RFC3339 string.
    final candidates = [log.createdAt, log.time];
    for (final value in candidates) {
      if (value.isEmpty) continue;
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt.toLocal();
    }
    return null;
  }

  LogProvider({
    SessionListLoader? sessionListLoader,
    SessionLogPageLoader? sessionLogPageLoader,
    LogCreator? logCreator,
    LogUpdater? logUpdater,
    LogDeleter? logDeleter,
    LogRestorer? logRestorer,
  })  : _sessionListLoader = sessionListLoader ?? RustApi.listSessions,
        _sessionLogPageLoader = sessionLogPageLoader ??
            ((sessionId, page, pageSize) => RustApi.getLogs(
                  sessionId: sessionId,
                  page: page,
                  pageSize: pageSize,
                )),
        _logCreator = logCreator ?? _createLogWithRust,
        _logUpdater = logUpdater ?? _updateLogWithRust,
        _logDeleter =
            logDeleter ?? ((syncId) => RustApi.deleteLog(syncId: syncId)),
        _logRestorer =
            logRestorer ?? ((syncId) => RustApi.restoreLog(syncId: syncId)) {
    scheduleMicrotask(_loadLogs);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadLogs({bool propagateErrors = false}) async {
    final generation = ++_loadGeneration;
    final sid = _currentSessionId;
    try {
      if (sid == null) {
        if (generation != _loadGeneration || _currentSessionId != sid) return;
        _logs = [];
        _safeNotify();
        return;
      }
      const pageSize = 500;
      final bridgeLogs = <bridge.LogEntry>[];
      for (var page = 1;; page += 1) {
        final batch = await _sessionLogPageLoader(sid, page, pageSize);
        if (generation != _loadGeneration || _currentSessionId != sid) return;
        bridgeLogs.addAll(batch);
        if (batch.length < pageSize) break;
      }
      if (generation != _loadGeneration || _currentSessionId != sid) return;
      final loaded = normalizeLoadedLogs(bridgeLogs);
      final loadedIds = loaded.map((log) => log.id).toSet();
      _pendingCanonicalLogs.removeWhere(
        (id, log) => log.sessionId == sid && loadedIds.contains(id),
      );
      loaded.addAll(
        _pendingCanonicalLogs.values.where(
          (log) => log.sessionId == sid && !loadedIds.contains(log.id),
        ),
      );
      loaded.sort(_compareChronologically);
      _logs = loaded;
      AppLogger.instance.log(
        AppLogLevel.debug,
        'Loaded ${loaded.length} records for session $sid',
        source: 'LogProvider',
      );
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not load records for session ${sid ?? '(none)'}',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      if (generation != _loadGeneration || _currentSessionId != sid) return;
      if (propagateErrors) {
        // A session whose records could not be loaded must never remain
        // writable. Keep it selected so providers stay aligned, but fail
        // closed until a later successful reload.
        _currentSessionWritable = false;
        _safeNotify();
        rethrow;
      }
    }
    _safeNotify();
  }

  Future<void> addLog(old.LogEntry log, {String? sessionId}) async {
    final effectiveSessionId = sessionId ?? _currentSessionId ?? '';
    if (effectiveSessionId.isEmpty) {
      throw StateError('SESSION_CONTEXT_MISSING: 当前没有可写会话');
    }

    // The form follows SessionProvider, while this provider owns the table
    // projection. During startup or a session switch those two providers can
    // briefly point at different sessions. Align before writing so a
    // successful insert cannot be followed by a reload of the old session.
    if (_currentSessionId != effectiveSessionId) {
      await reloadForSession(effectiveSessionId, propagateErrors: true);
    }
    if (_currentSessionId != effectiveSessionId) {
      throw StateError(
        'SESSION_CONTEXT_CHANGED: 会话已切换，请重新保存当前记录',
      );
    }
    _ensureWritable(effectiveSessionId);
    try {
      final canonical = await _logCreator(effectiveSessionId, log);
      _markPersonalDataChanged();
      if (canonical.sessionId != effectiveSessionId) {
        throw StateError(
          'LOG_SESSION_MISMATCH: 保存结果与当前会话不匹配',
        );
      }
      // The user may switch sessions while the durable insert is in flight.
      // The row is already saved, but it must never leak into the newly opened
      // session's in-memory table.
      if (_currentSessionId == effectiveSessionId) {
        _mergeCanonicalLog(canonical);
        await _reconcileCanonicalLogAfterWrite(
          effectiveSessionId,
          canonical,
        );
      }
      await _notifyDataChanged();
      if (_onLogChanged != null) {
        await _onLogChanged!(_toOldLog(canonical), false);
      }
      AppLogger.instance.log(
        AppLogLevel.info,
        'Saved record ${canonical.syncId} in session $effectiveSessionId',
        source: 'LogProvider',
      );
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not save a record in session $effectiveSessionId',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> updateLog(int index, old.LogEntry log) async {
    if (index < 0 || index >= _logs.length) return;
    final original = _logs[index];
    _ensureLogWritable(original);
    final syncId = original.id;
    final sessionId = original.sessionId ?? _currentSessionId;
    if (syncId.isEmpty) return;
    try {
      final canonical = await _logUpdater(syncId, original, log);
      _markPersonalDataChanged();
      if (_currentSessionId == sessionId) {
        _mergeCanonicalLog(canonical);
      }
      await _notifyDataChanged();
      AppLogger.instance.log(
        AppLogLevel.info,
        'Updated record $syncId',
        source: 'LogProvider',
      );
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not update record $syncId',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> updateLogById(String syncId, old.LogEntry log) async {
    final index = logs.indexWhere((candidate) => candidate.id == syncId);
    if (index < 0) return;
    await updateLog(index, log);
  }

  Future<void> deleteLog(int index) async {
    if (index < 0 || index >= _logs.length) return;
    final log = _logs[index];
    _ensureLogWritable(log);
    final syncId = log.id;
    final sessionId = log.sessionId ?? _currentSessionId;
    if (syncId.isEmpty) return;
    try {
      await _logDeleter(syncId);
      _markPersonalDataChanged();
      if (_currentSessionId == sessionId) {
        _pushUndo(log);
        _loadGeneration += 1;
        _pendingCanonicalLogs.remove(syncId);
        _logs = [
          for (final candidate in _logs)
            if (candidate.id != syncId) candidate
        ];
        _safeNotify();
      }
      await _notifyDataChanged();
      if (_onLogChanged != null) {
        await _onLogChanged!(log, true);
      }
      AppLogger.instance.log(
        AppLogLevel.info,
        'Deleted record $syncId',
        source: 'LogProvider',
      );
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not delete record $syncId',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> deleteLogById(String syncId) async {
    final index = logs.indexWhere((candidate) => candidate.id == syncId);
    if (index < 0) return;
    await deleteLog(index);
  }

  Future<void> undoLastLog() async {
    if (_undoStack.isEmpty) return;
    final pendingRestore = _undoStack.last;
    _ensureLogWritable(pendingRestore);
    final log = _undoStack.removeLast();
    _safeNotify();
    try {
      final restored = await _logRestorer(log.id);
      _markPersonalDataChanged();
      if (_currentSessionId == restored.sessionId) {
        _mergeCanonicalLog(restored);
      }
      if (_onLogChanged != null) {
        await _onLogChanged!(log, false);
      }
      await _notifyDataChanged();
      AppLogger.instance.log(
        AppLogLevel.info,
        'Restored record ${log.id}',
        source: 'LogProvider',
      );
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not restore record ${log.id}',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      _undoStack.add(log);
      _safeNotify();
      rethrow;
    }
  }

  void _pushUndo(old.LogEntry log) {
    _undoStack.add(log);
    if (_undoStack.length > _maxUndoStack) {
      _undoStack.removeAt(0);
    }
  }

  Future<void> clearAllLogs() async {
    if (_logs.isEmpty) return;
    _ensureWritable(_currentSessionId);
    final snapshot = List<old.LogEntry>.from(_logs);
    for (final log in snapshot) {
      _ensureLogWritable(log);
    }
    var durableRowsChanged = false;
    var revisionMarked = false;
    try {
      for (final log in snapshot) {
        if (log.id.isNotEmpty) {
          await RustApi.deleteLog(syncId: log.id);
          durableRowsChanged = true;
        }
      }
      if (durableRowsChanged) {
        _markPersonalDataChanged();
        revisionMarked = true;
      }
      for (final log in snapshot) {
        _pushUndo(log);
      }
      _logs.clear();
      _safeNotify();
      await _notifyDataChanged();
      AppLogger.instance.log(
        AppLogLevel.info,
        'Cleared ${snapshot.length} records from session '
        '${_currentSessionId ?? '(none)'}',
        source: 'LogProvider',
      );
    } catch (e, st) {
      if (durableRowsChanged && !revisionMarked) {
        _markPersonalDataChanged();
      }
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not clear records from session ${_currentSessionId ?? '(none)'}',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      await _loadLogs();
      rethrow;
    }
  }

  Future<void> switchToSession(String sessionId) async {
    await reloadForSession(sessionId);
  }

  Future<void> closeSession(String sessionId) async {
    _ensureWritable(sessionId);
    try {
      await RustApi.closeSession(sessionId: sessionId);
      _markPersonalDataChanged();
      if (_currentSessionId == sessionId) {
        await reloadForSession(sessionId, propagateErrors: true);
      } else {
        _safeNotify();
      }
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not close session $sessionId',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> hardDeleteSession(String sessionId) async {
    if (_currentSessionId == sessionId) {
      throw StateError('CURRENT_SESSION_DELETE_FORBIDDEN');
    }
    try {
      await RustApi.hardDeleteSession(sessionId: sessionId);
      _markPersonalDataChanged();
      _collaborationReadOnlySessions.remove(sessionId);
      _undoStack.removeWhere((log) => log.sessionId == sessionId);
      _pendingCanonicalLogs.removeWhere((_, log) => log.sessionId == sessionId);
      _safeNotify();
    } catch (e, st) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not permanently delete session $sessionId',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Drops every in-memory reference to a session that has already been
  /// permanently removed from the local database.
  Future<void> forgetDeletedSession(String sessionId) async {
    _collaborationReadOnlySessions.remove(sessionId);
    _undoStack.removeWhere((log) => log.sessionId == sessionId);
    _pendingCanonicalLogs.removeWhere((_, log) => log.sessionId == sessionId);
    if (_currentSessionId == sessionId) {
      await reloadForSession(null, propagateErrors: true);
    } else {
      _safeNotify();
    }
  }

  Future<int> purgeDeletedRecords() async => 0;

  Future<void> importLogs(List<old.LogEntry> importedLogs,
      {String? sessionId}) async {
    final effectiveSessionId = sessionId ?? _currentSessionId ?? '';
    _ensureWritable(effectiveSessionId);
    var durableRowsChanged = false;
    var revisionMarked = false;
    try {
      for (final log in importedLogs) {
        await RustApi.addLog(
          sessionId: effectiveSessionId,
          controller: log.controller,
          callsign: log.callsign,
          time: normalizeLogTimeForStorage(
            log.time,
            reference: DateTime.tryParse(log.createdAt),
          ),
          rstSent: log.report,
          rstRcvd: log.rstRcvd,
          qth: log.qth,
          device: log.device,
          power: log.power,
          antenna: log.antenna,
          height: log.height,
          remarks: log.remarks.isNotEmpty ? log.remarks : null,
        );
        durableRowsChanged = true;
      }
      if (durableRowsChanged) {
        _markPersonalDataChanged();
        revisionMarked = true;
      }
      await _loadLogs();
      _safeNotify();
      await _notifyDataChanged();
      AppLogger.instance.log(
        AppLogLevel.info,
        'Imported ${importedLogs.length} records into session '
        '$effectiveSessionId',
        source: 'LogProvider',
      );
    } catch (e, st) {
      if (durableRowsChanged && !revisionMarked) {
        _markPersonalDataChanged();
      }
      AppLogger.instance.log(
        AppLogLevel.error,
        'Could not import records into session $effectiveSessionId',
        source: 'LogProvider',
        error: e,
        stackTrace: st,
      );
      await _loadLogs();
      rethrow;
    }
  }

  List<List<String>> getLogsAsList() {
    return _logs.map((log) => log.toList()).toList();
  }

  @visibleForTesting
  static List<old.LogEntry> normalizeLoadedLogs(
    List<bridge.LogEntry> newestFirst,
  ) {
    final normalized = newestFirst.map(_toOldLog).toList();
    normalized.sort(_compareChronologically);
    return normalized;
  }

  void _mergeCanonicalLog(bridge.LogEntry canonical) {
    _loadGeneration += 1;
    final converted = _toOldLog(canonical);
    _pendingCanonicalLogs.remove(converted.id);
    _logs = [
      for (final candidate in _logs)
        if (candidate.id != converted.id) candidate,
      converted,
    ]..sort(_compareChronologically);
    _safeNotify();
  }

  /// Re-reads the durable projection after a successful insert.
  ///
  /// The Web bridge completes on a worker. Publishing its returned row
  /// synchronously is useful for responsiveness, while the durable re-read
  /// keeps the mounted table in step with the worker-backed SQLite projection.
  /// If a backend returns a temporarily stale page, retain the already-confirmed
  /// canonical row.
  Future<void> _reconcileCanonicalLogAfterWrite(
    String sessionId,
    bridge.LogEntry canonical,
  ) async {
    if (_currentSessionId != sessionId) return;

    await _loadLogs();
    if (_currentSessionId != sessionId) return;
    if (_logs.any((candidate) => candidate.id == canonical.syncId)) return;
    _mergeCanonicalLog(canonical);
  }

  void _markPersonalDataChanged() {
    _dataRevision += 1;
    _safeNotify();
  }

  static int _compareChronologically(old.LogEntry left, old.LogEntry right) {
    final leftTime = DateTime.tryParse(left.time)?.toUtc();
    final rightTime = DateTime.tryParse(right.time)?.toUtc();
    var compared = leftTime != null && rightTime != null
        ? leftTime.compareTo(rightTime)
        : left.time.compareTo(right.time);
    if (compared != 0) return compared;
    compared = left.createdAt.compareTo(right.createdAt);
    if (compared != 0) return compared;
    return left.id.compareTo(right.id);
  }

  static old.LogEntry _toOldLog(bridge.LogEntry b) {
    return old.LogEntry(
      id: b.syncId,
      sessionId: b.sessionId,
      time: b.time,
      controller: b.controller,
      callsign: b.callsign,
      report: b.rstSent ?? '',
      rstRcvd: b.rstRcvd ?? '',
      qth: b.qth ?? '',
      device: b.device ?? '',
      power: b.power ?? '',
      antenna: b.antenna ?? '',
      height: b.height ?? '',
      remarks: b.remarks ?? '',
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
      deletedAt: b.deletedAt,
      sourceDeviceId: b.sourceDeviceId,
    );
  }
}
