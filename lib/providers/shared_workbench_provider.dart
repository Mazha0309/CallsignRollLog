import 'dart:async';
import 'dart:convert';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/utils/log_time.dart';

/// A remote-only workbench. It deliberately has no local database or replica
/// binding: equal session/log IDs do not imply equal ownership or permissions.
class SharedWorkbenchProvider extends LogProvider {
  SharedWorkbenchProvider(this.sharing, this.target)
      : scope = sharing.accountScope,
        super(
          sessionListLoader: () async => [],
          sessionLogPageLoader: (_, __, ___) async => [],
          logCreator: (_, __) => throw StateError('REMOTE_ONLY'),
          logUpdater: (_, __, ___) => throw StateError('REMOTE_ONLY'),
          logDeleter: (_) => throw StateError('REMOTE_ONLY'),
          logRestorer: (_) => throw StateError('REMOTE_ONLY'),
        ) {
    sharing.addListener(_changed);
    unawaited(refresh());
  }

  final AccountShareProvider sharing;
  final SharedSessionDto target;
  final String? scope;
  final _versions = Expando<int>();
  final _snapshotRevisions = Expando<int>();
  final _pendingCreates = <String, String>{};
  List<LogEntry> _rows = [];
  SharedSessionDto? _canonical;
  bool _dead = false, _loading = false, _writing = false, _refreshAgain = false;
  int _revision = -1, _request = 0, _dataRevision = 0;
  Object? error;
  bool get loading => _loading;
  bool get writing => _writing;
  SharedSessionDto get session => _canonical ?? target;
  SharedSessionDto? get permission => scope == sharing.accountScope
      ? sharing.sharedSessions
          .where((row) =>
              row.identity == target.identity &&
              row.grantorUserId == target.grantorUserId)
          .firstOrNull
      : null;
  @override
  List<LogEntry> get logs => _rows;
  @override
  int get dataRevision => _dataRevision;
  @override
  bool get hasReadAccess => !_dead && permission != null;
  @override
  int get logCount => _rows.length;
  @override
  String get currentSessionId => target.sessionId;
  @override
  bool get currentSessionReadOnly =>
      _dead ||
      error != null ||
      _canonical == null ||
      _writing ||
      _canonical?.status != 'active' ||
      _canonical?.canEditLogs != true ||
      permission?.status != 'active' ||
      permission?.canEditLogs != true;
  @override
  bool get canUndo => false;
  @override
  bool get canClearAllLogs => false;
  @override
  String? mutationBlockReason(LogEntry log) => currentSessionReadOnly ||
          log.sessionId != target.sessionId ||
          !_rows.any((row) => row.id == log.id)
      ? 'SHARE_ACCESS_CHANGED'
      : null;
  @override
  bool canDeleteLog(LogEntry log) =>
      canMutateLog(log) &&
      permission?.canDeleteLogs == true &&
      _canonical?.canDeleteLogs == true;

  void _notify() {
    if (!_dead) notifyListeners();
  }

  void _changed() {
    if (_dead) return;
    if (permission == null) {
      ++_request;
      _rows = [];
      _canonical = null;
      error = StateError('SHARE_ACCESS_CHANGED');
      _notify();
      return;
    }
    _notify();
    if (_revision != sharing.revision) {
      _revision = sharing.revision;
      if (_writing || _loading) {
        _refreshAgain = true;
      } else {
        unawaited(refresh());
      }
    }
  }

  Future<void> refresh() async {
    if (_dead) return;
    if (_loading || _writing) {
      _refreshAgain = true;
      return;
    }
    final request = ++_request;
    _loading = true;
    _notify();
    try {
      if (permission == null) throw StateError('SHARE_ACCESS_CHANGED');
      final rows = <LogEntry>[];
      SharedSessionDto? canonical;
      final ids = <String>{};
      for (var page = 1;; page++) {
        final result = await sharing.loadSharedRecords(target,
            page: page, expectedScope: scope);
        if (_dead || request != _request) return;
        if (permission == null) throw StateError('SHARE_ACCESS_CHANGED');
        final next = result.session ?? permission!;
        if (next.identity != target.identity ||
            next.grantorUserId != target.grantorUserId) {
          throw StateError('SHARE_ACCESS_CHANGED');
        }
        if (canonical != null &&
            (canonical.snapshotRevision != next.snapshotRevision ||
                canonical.updatedAt != next.updatedAt ||
                canonical.logCount != next.logCount)) {
          throw StateError('VERSION_CONFLICT');
        }
        canonical = next;
        for (final raw in result.items) {
          final row = LogEntry.fromJson({
            ...raw,
            'id': raw['syncId'] ?? raw['sync_id'],
            'sessionId': target.sessionId
          });
          if (!ids.add(row.id)) throw StateError('VERSION_CONFLICT');
          _versions[row] = (raw['version'] as num?)?.toInt();
          _snapshotRevisions[row] = next.snapshotRevision;
          rows.add(row);
        }
        if (page >= result.totalPages) break;
      }
      rows.sort((a, b) => (DateTime.tryParse(a.time) ?? DateTime(1970))
          .compareTo(DateTime.tryParse(b.time) ?? DateTime(1970)));
      _rows = List.unmodifiable(rows);
      _dataRevision++;
      _canonical = canonical;
      error = null;
    } catch (failure) {
      if (_dead || request != _request) return;
      _rows = [];
      _canonical = null;
      error = failure;
    } finally {
      _loading = false;
      _notify();
      if (!_dead && _refreshAgain) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  Map<String, Object?> _value(LogEntry row, {LogEntry? original}) => {
        'time': original != null &&
                row.time == formatLogTimeForDisplay(original.time)
            ? original.time
            : normalizeLogTimeForStorage(row.time,
                reference: DateTime.tryParse(original?.time ?? row.time) ??
                    DateTime.tryParse(original?.createdAt ?? row.createdAt)),
        'controller': row.controller,
        'callsign': row.callsign,
        'rstSent': row.report,
        'rstRcvd': row.rstRcvd,
        'qth': row.qth,
        'device': row.device,
        'power': row.power,
        'antenna': row.antenna,
        'height': row.height,
        'remarks': row.remarks,
      };

  Future<void> _mutate(String operation, LogEntry row,
      [LogEntry? original]) async {
    if (currentSessionReadOnly ||
        (operation == 'delete' && !canDeleteLog(row)) ||
        (operation != 'create' &&
            (original == null || !canMutateLog(original)))) {
      throw StateError('SHARE_ACCESS_CHANGED');
    }
    final revision = original == null
        ? session.snapshotRevision
        : _snapshotRevisions[original];
    final version = original == null ? 0 : _versions[original];
    if (target.source == 'personal' ? revision == null : version == null) {
      throw StateError('VERSION_CONFLICT');
    }
    final value = _value(row, original: original);
    if (operation == 'update') {
      final before = _value(original!);
      value.removeWhere((field, next) => before[field] == next);
      if (value.isEmpty) return;
    }
    _writing = true;
    _notify();
    try {
      await sharing.mutateSharedRecord(
          session,
          {
            'operation': operation,
            'syncId': original?.id ?? row.id,
            if (target.source == 'personal')
              'expectedRevision': revision
            else
              'baseVersion': version,
            if (operation != 'delete')
              operation == 'create' ? 'value' : 'patch': value,
          },
          expectedScope: scope);
    } finally {
      _writing = false;
      _refreshAgain = false;
      await refresh();
    }
  }

  @override
  Future<void> addLog(LogEntry log, {String? sessionId}) async {
    if (sessionId != null && sessionId != target.sessionId) {
      throw StateError('SHARE_ACCESS_CHANGED');
    }
    final content = jsonEncode(_value(log));
    final id = _pendingCreates.putIfAbsent(content, () => log.id);
    await _mutate('create', log.copyWith(id: id));
    _pendingCreates.remove(content);
  }

  @override
  Future<void> updateLogFromOriginal(LogEntry original, LogEntry replacement) =>
      _mutate('update', replacement, original);
  @override
  Future<void> updateLogById(String syncId, LogEntry log) async =>
      throw StateError('REMOTE_EDIT_REQUIRES_ORIGINAL');
  @override
  Future<void> updateLog(int index, LogEntry log) async =>
      throw StateError('REMOTE_EDIT_REQUIRES_ORIGINAL');
  @override
  Future<void> deleteLogById(String syncId) async {
    final row = _rows.where((row) => row.id == syncId).firstOrNull;
    if (row == null) throw StateError('SHARE_ACCESS_CHANGED');
    await _mutate('delete', row, row);
  }

  @override
  Future<void> deleteLogFromOriginal(LogEntry original) =>
      _mutate('delete', original, original);
  @override
  Future<void> deleteLog(int index) => deleteLogById(_rows[index].id);
  @override
  Future<void> reloadForSession(String? sessionId,
      {bool propagateErrors = false}) async {
    if (sessionId != target.sessionId) throw StateError('REMOTE_ONLY');
    await refresh();
    if (propagateErrors && error != null) throw error!;
  }

  @override
  Future<void> undoLastLog() async =>
      throw StateError('SHARE_PERMISSION_DENIED');
  @override
  Future<void> clearAllLogs() async =>
      throw StateError('SHARE_PERMISSION_DENIED');
  @override
  Future<void> closeSession(String sessionId) async =>
      throw StateError('SHARE_PERMISSION_DENIED');
  @override
  Future<void> hardDeleteSession(String sessionId) async =>
      throw StateError('SHARE_PERMISSION_DENIED');
  @override
  Future<void> importLogs(List<LogEntry> importedLogs,
          {String? sessionId}) async =>
      throw StateError('SHARE_PERMISSION_DENIED');
  @override
  void dispose() {
    _dead = true;
    ++_request;
    sharing.removeListener(_changed);
    super.dispose();
  }
}
