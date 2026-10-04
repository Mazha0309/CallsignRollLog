import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:openlogtool/models/personal_cloud_dto.dart';
import 'package:openlogtool/models/personal_dictionary_snapshot_dto.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/services/personal_promotion_state.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/services/server_api.dart';
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:openlogtool/utils/personal_cloud_merge.dart';
import 'package:openlogtool/utils/server_url.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:openlogtool/services/app_logger.dart';

enum PersonalCloudSyncState {
  signedOut,
  unsupported,
  checking,
  syncing,
  upToDate,
  decisionRequired,
  error,
}

enum PersonalCloudDecisionReason {
  differentInitialData,
  differentAccountData,
  databaseReplaced,
  localClearWouldDeleteCloud,
  concurrentChanges,
}

typedef PersonalRecordsExporter = Future<String> Function();
typedef PersonalRecordsCompareReplacer = Future<String> Function(
  String jsonData,
  String expectedLocalJsonData,
);
typedef PersonalDictionaryExporter = Future<String> Function();
typedef PersonalDictionaryCompareReplacer = Future<String> Function(
  String jsonData,
  String expectedLocalJsonData,
);
typedef PersonalCloudStateLoader = Future<String> Function(
  String scopeHash,
  String dataset,
);
typedef PersonalCloudBaselineSaver = Future<void> Function({
  required String scopeHash,
  required String dataset,
  required int remoteRevision,
  required String snapshotJson,
  required String checksum,
  required bool claimOwner,
  required bool clearPairingRequirement,
});

String personalSnapshotContentChecksum(PersonalCloudJsonObject snapshot) {
  final sessions = snapshot['sessions'];
  final logs = snapshot['logs'];
  if (snapshot['version'] != 1 || sessions is! List || logs is! List) {
    throw const FormatException('unsupported personal snapshot format');
  }
  final canonical = _personalCanonicalValue(<String, Object?>{
    'version': 1,
    'sessions': _personalCanonicalRows(sessions, 'session_id'),
    'logs': _personalCanonicalRows(logs, 'sync_id'),
  });
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

String personalDictionaryContentChecksum(
  PersonalDictionarySnapshotJson snapshot,
) {
  final items = snapshot['items'];
  if (snapshot['version'] != 1 || items is! List) {
    throw const FormatException('unsupported personal dictionary format');
  }
  final normalized = items.map(_personalCanonicalValue).toList(growable: false)
    ..sort((left, right) {
      final leftMap = left as Map;
      final rightMap = right as Map;
      final typeOrder = _compareUtf8(
        leftMap['dictType']?.toString() ?? '',
        rightMap['dictType']?.toString() ?? '',
      );
      return typeOrder != 0
          ? typeOrder
          : _compareUtf8(
              leftMap['raw']?.toString() ?? '',
              rightMap['raw']?.toString() ?? '',
            );
    });
  final canonical = _personalCanonicalValue(<String, Object?>{
    'version': 1,
    'items': normalized,
  });
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

int _compareUtf8(String left, String right) {
  final leftBytes = utf8.encode(left);
  final rightBytes = utf8.encode(right);
  final length = leftBytes.length < rightBytes.length
      ? leftBytes.length
      : rightBytes.length;
  for (var index = 0; index < length; index += 1) {
    final order = leftBytes[index].compareTo(rightBytes[index]);
    if (order != 0) return order;
  }
  return leftBytes.length.compareTo(rightBytes.length);
}

List<Object?> _personalCanonicalRows(List<Object?> rows, String idField) {
  final normalized = rows.map(_personalCanonicalValue).toList(growable: false);
  normalized.sort((left, right) {
    final leftId = left is Map ? left[idField]?.toString() ?? '' : '';
    final rightId = right is Map ? right[idField]?.toString() ?? '' : '';
    return leftId.compareTo(rightId);
  });
  return normalized;
}

Object? _personalCanonicalValue(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      sorted[entry.key.toString()] = _personalCanonicalValue(entry.value);
    }
    return sorted;
  }
  if (value is List) return value.map(_personalCanonicalValue).toList();
  return value;
}

/// Account-scoped synchronization for personal sessions and records.
///
/// Collaboration replicas remain on their existing realtime protocol. This
/// provider synchronizes only sessions without a collaboration binding, using
/// a revisioned complete snapshot so deletes and closed historical sessions
/// retain their exact local metadata across devices.
class PersonalCloudProvider with ChangeNotifier {
  PersonalCloudProvider({
    PersonalRecordsExporter? exporter,
    PersonalRecordsCompareReplacer? replacer,
    PersonalDictionaryExporter? dictionaryExporter,
    PersonalDictionaryCompareReplacer? dictionaryReplacer,
    PersonalCloudStateLoader? stateLoader,
    PersonalCloudBaselineSaver? baselineSaver,
    bool automaticSync = true,
    Duration automaticChangeDebounce = const Duration(seconds: 2),
    Duration maximumAutomaticDelay = const Duration(seconds: 15),
    Duration minimumPutInterval = const Duration(seconds: 6),
    Duration periodicInterval = const Duration(seconds: 30),
  })  : _exporter = exporter ?? RustApi.exportPersonalRecords,
        _replacer = replacer ??
            ((jsonData, expectedLocalJsonData) =>
                RustApi.replacePersonalRecordsIfUnchanged(
                  jsonData: jsonData,
                  expectedLocalJsonData: expectedLocalJsonData,
                )),
        _dictionaryExporter =
            dictionaryExporter ?? RustApi.exportPersonalDictionary,
        _dictionaryReplacer = dictionaryReplacer ??
            ((jsonData, expectedLocalJsonData) =>
                RustApi.replacePersonalDictionaryIfUnchanged(
                  jsonData: jsonData,
                  expectedLocalJsonData: expectedLocalJsonData,
                )),
        _stateLoader = stateLoader ??
            ((scopeHash, dataset) => RustApi.loadPersonalCloudState(
                  scopeHash: scopeHash,
                  dataset: dataset,
                )),
        _baselineSaver = baselineSaver ??
            (({
              required scopeHash,
              required dataset,
              required remoteRevision,
              required snapshotJson,
              required checksum,
              required claimOwner,
              required clearPairingRequirement,
            }) =>
                RustApi.savePersonalCloudBaseline(
                  scopeHash: scopeHash,
                  dataset: dataset,
                  remoteRevision: remoteRevision,
                  snapshotJson: snapshotJson,
                  checksum: checksum,
                  claimOwner: claimOwner,
                  clearPairingRequirement: clearPairingRequirement,
                )),
        // Existing provider tests and embedders inject the records exporter
        // without initializing the Rust library. They retain the v1
        // preferences adapter; production always uses the transactional store.
        _useNativeStateStore = exporter == null || stateLoader != null,
        _automaticSync = automaticSync,
        _automaticChangeDebounce = automaticChangeDebounce,
        _maximumAutomaticDelay = maximumAutomaticDelay,
        _minimumPutInterval = minimumPutInterval,
        _periodicInterval = periodicInterval;

  final PersonalRecordsExporter _exporter;
  final PersonalRecordsCompareReplacer _replacer;
  final PersonalDictionaryExporter _dictionaryExporter;
  final PersonalDictionaryCompareReplacer _dictionaryReplacer;
  final PersonalCloudStateLoader _stateLoader;
  final PersonalCloudBaselineSaver _baselineSaver;
  final bool _useNativeStateStore;
  final bool _automaticSync;
  final Duration _automaticChangeDebounce;
  final Duration _maximumAutomaticDelay;
  final Duration _minimumPutInterval;
  final Duration _periodicInterval;

  ServerProvider? _server;
  SessionProvider? _sessions;
  LogProvider? _logs;
  CollaborationProvider? _collaboration;
  DictionaryProvider? _dictionaries;
  String? _scope;
  bool _supported = false;
  bool _dictionarySupported = false;
  Timer? _debounce;
  Timer? _periodic;
  DateTime? _automaticBurstStartedAt;
  DateTime? _lastRecordsPutAt;
  DateTime? _lastDictionaryPutAt;
  Future<void>? _activeOperation;
  bool _automaticRerunRequested = false;
  int _automaticConflictRetries = 0;
  bool _disposed = false;
  bool _suppressDependencySignal = false;
  int? _observedSessionDataRevision;
  int? _observedLogDataRevision;
  int? _observedDatabaseRevision;
  int? _observedDictionaryRevision;

  PersonalCloudSyncState _state = PersonalCloudSyncState.signedOut;
  PersonalCloudDecisionReason? _decisionReason;
  PersonalCloudSnapshotMeta? _cloudMeta;
  int _localSessionCount = 0;
  int _localLogCount = 0;
  String? _localSnapshotToken;
  String? _lastError;
  DateTime? _lastSyncedAt;
  _PersonalCloudBaseline? _baseline;
  _PersonalCloudBaseline? _dictionaryBaseline;
  bool _baselineLoaded = false;
  bool _dictionaryBaselineLoaded = false;
  bool _recordsPairingAcknowledged = false;
  bool _dictionaryPairingAcknowledged = false;
  String? _localOwnerScope;
  String? _pairingRequiredReason;
  PersonalDictionarySnapshotMeta? _dictionaryCloudMeta;
  int _localDictionaryItemCount = 0;
  String? _localDictionarySnapshotToken;
  List<PersonalCloudMergeConflict> _conflicts = const [];
  _PendingPersonalMerge? _pendingMerge;

  PersonalCloudSyncState get state => _state;
  PersonalCloudDecisionReason? get decisionReason => _decisionReason;
  PersonalCloudSnapshotMeta? get cloudMeta => _cloudMeta;
  int get localSessionCount => _localSessionCount;
  int get localLogCount => _localLogCount;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isBusy =>
      _state == PersonalCloudSyncState.checking ||
      _state == PersonalCloudSyncState.syncing;
  bool get isSignedIn => _scope != null;
  bool get isSupported => _supported;
  String? get localSnapshotToken => _localSnapshotToken;
  bool get isDictionarySupported => _dictionarySupported;
  PersonalDictionarySnapshotMeta? get dictionaryCloudMeta =>
      _dictionaryCloudMeta;
  int get localDictionaryItemCount => _localDictionaryItemCount;
  String? get localDictionarySnapshotToken => _localDictionarySnapshotToken;
  List<PersonalCloudMergeConflict> get conflicts =>
      List.unmodifiable(_conflicts);
  bool get hasPendingMerge => _pendingMerge != null;
  PersonalCloudDataset? get pendingDataset => _pendingMerge?.dataset;
  bool get pendingMergeNeedsConfirmation =>
      _pendingMerge?.requiresInitialConfirmation ?? false;

  void updateDependencies(
    ServerProvider server,
    SessionProvider sessions,
    LogProvider logs,
    CollaborationProvider collaboration, [
    DictionaryProvider? dictionaries,
  ]) {
    _server = server;
    _sessions = sessions;
    _logs = logs;
    _collaboration = collaboration;
    _dictionaries = dictionaries;
    final accountId = server.accountId;
    final serverInfo = server.serverInfo;
    final canonicalOrigin = normalizeServerUrl(server.serverUrl);
    final nextScope = server.isLoggedIn &&
            !server.passwordChangeRequired &&
            accountId != null &&
            canonicalOrigin.isNotEmpty &&
            serverInfo != null &&
            serverInfo.serverInstanceId.isNotEmpty
        ? '$canonicalOrigin\n${serverInfo.serverInstanceId}\n$accountId'
        : null;
    final nextSupported = nextScope != null &&
        (serverInfo?.features.contains('personalCloudSnapshots') ?? false);
    final nextDictionarySupported = nextScope != null &&
        dictionaries != null &&
        (serverInfo?.features.contains('personalDictionarySnapshots') ?? false);

    final sessionDataRevision = sessions.dataRevision;
    final logDataRevision = logs.dataRevision;
    final databaseRevision = sessions.databaseRevision;
    final dictionaryRevision = dictionaries?.dataRevision;
    final databaseGenerationChanged = _observedDatabaseRevision != null &&
        _observedDatabaseRevision != databaseRevision;
    final personalDataChanged = _observedSessionDataRevision != null &&
        (_observedSessionDataRevision != sessionDataRevision ||
            _observedLogDataRevision != logDataRevision ||
            _observedDatabaseRevision != databaseRevision);
    final dictionaryDataChanged = _observedDictionaryRevision != null &&
        dictionaryRevision != null &&
        _observedDictionaryRevision != dictionaryRevision;
    _observedSessionDataRevision = sessionDataRevision;
    _observedLogDataRevision = logDataRevision;
    _observedDatabaseRevision = databaseRevision;
    _observedDictionaryRevision = dictionaryRevision;

    if (nextScope != _scope ||
        nextSupported != _supported ||
        nextDictionarySupported != _dictionarySupported) {
      _scope = nextScope;
      _supported = nextSupported;
      _dictionarySupported = nextDictionarySupported;
      _baseline = null;
      _dictionaryBaseline = null;
      _baselineLoaded = false;
      _dictionaryBaselineLoaded = false;
      _recordsPairingAcknowledged = false;
      _dictionaryPairingAcknowledged = false;
      _localOwnerScope = null;
      _pairingRequiredReason = null;
      _cloudMeta = null;
      _dictionaryCloudMeta = null;
      _localSnapshotToken = null;
      _decisionReason = null;
      _conflicts = const [];
      _pendingMerge = null;
      _lastError = null;
      _debounce?.cancel();
      _periodic?.cancel();
      _automaticBurstStartedAt = null;
      _lastRecordsPutAt = null;
      _lastDictionaryPutAt = null;
      if (nextScope == null) {
        _state = PersonalCloudSyncState.signedOut;
      } else if (!nextSupported) {
        _state = PersonalCloudSyncState.unsupported;
      } else {
        _state = PersonalCloudSyncState.checking;
        if (_automaticSync) {
          _periodic = Timer.periodic(
            _periodicInterval,
            (_) => _scheduleAutomaticSync(Duration.zero),
          );
          _scheduleAutomaticSync(Duration.zero);
        }
      }
      _notifySoon();
      return;
    }

    // A whole-database import or clear deletes both durable cloud baselines.
    // Drop both in-memory copies in the same dependency turn so accepting the
    // records side can never leave a stale dictionary baseline armed. Cloud
    // downloads run with dependency signals suppressed and install their new
    // baseline themselves after the transactional replacement completes.
    if (databaseGenerationChanged && !_suppressDependencySignal) {
      _baseline = null;
      _dictionaryBaseline = null;
      _baselineLoaded = false;
      _dictionaryBaselineLoaded = false;
      _recordsPairingAcknowledged = false;
      _dictionaryPairingAcknowledged = false;
      _pairingRequiredReason = null;
      _pendingMerge = null;
      _conflicts = const [];
    }

    if (nextScope != null &&
        _supported &&
        _automaticSync &&
        !_suppressDependencySignal &&
        (personalDataChanged || dictionaryDataChanged)) {
      _scheduleAutomaticSync(_automaticChangeDebounce);
    }
  }

  Future<void> syncNow() => _runExclusive(
        () => _reconcile(automatic: false),
        automatic: false,
      );

  /// Publication removes a personal session from the snapshot atomically on
  /// the server. Do not upload an export taken between the local publish lease
  /// and installation of the canonical collaboration replica.
  Future<void> runWithPersonalSyncPaused(Future<void> Function() operation) {
    final scope = _scope;
    return _runExclusive(() async {
      if (_disposed || scope != _scope) throw StateError('ACCOUNT_CHANGED');
      await operation();
    }, automatic: false);
  }

  /// Explicitly replaces the account snapshot with this device's personal
  /// sessions. This is the only path allowed to resolve an initial mismatch in
  /// favor of local data or to clear non-empty cloud content.
  Future<void> replaceCloudWithLocal({
    required int expectedCloudRevision,
    required String expectedLocalSnapshotToken,
  }) =>
      _runExclusive(
        () => _replaceCloudWithLocal(
          expectedCloudRevision: expectedCloudRevision,
          expectedLocalSnapshotToken: expectedLocalSnapshotToken,
        ),
        automatic: false,
      );

  /// Explicitly replaces personal sessions on this device with the current
  /// account snapshot. Dictionaries, settings, QTH history and collaboration
  /// replicas are preserved by the Rust transaction.
  Future<void> restoreCloudToLocal({
    required int expectedCloudRevision,
    required String expectedLocalSnapshotToken,
  }) =>
      _runExclusive(
        () => _restoreCloudToLocal(
          expectedCloudRevision: expectedCloudRevision,
          expectedLocalSnapshotToken: expectedLocalSnapshotToken,
        ),
        automatic: false,
      );

  void _scheduleAutomaticSync(Duration delay) {
    if (_scope == null || !_supported || _disposed) return;
    _debounce?.cancel();
    var effectiveDelay = delay;
    if (delay > Duration.zero) {
      final now = DateTime.now();
      _automaticBurstStartedAt ??= now;
      final remaining =
          _maximumAutomaticDelay - now.difference(_automaticBurstStartedAt!);
      if (remaining <= Duration.zero) {
        effectiveDelay = Duration.zero;
      } else if (remaining < effectiveDelay) {
        effectiveDelay = remaining;
      }
    } else {
      _automaticBurstStartedAt = null;
    }
    _debounce = Timer(effectiveDelay, () {
      _automaticBurstStartedAt = null;
      _runExclusive(
        () => _reconcile(automatic: true),
        automatic: true,
      ).catchError((Object error, StackTrace stackTrace) {
        AppLogger.instance.log(
          AppLogLevel.error,
          'Automatic personal-cloud synchronization failed',
          source: 'PersonalCloud',
          error: error,
          stackTrace: stackTrace,
        );
      });
    });
  }

  Future<void> _waitForPutSlot(PersonalCloudDataset dataset) async {
    if (_minimumPutInterval <= Duration.zero) return;
    final previous = dataset == PersonalCloudDataset.records
        ? _lastRecordsPutAt
        : _lastDictionaryPutAt;
    if (previous == null) return;
    final remaining = _minimumPutInterval - DateTime.now().difference(previous);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
  }

  void _markPutCompleted(PersonalCloudDataset dataset) {
    final now = DateTime.now();
    if (dataset == PersonalCloudDataset.records) {
      _lastRecordsPutAt = now;
    } else {
      _lastDictionaryPutAt = now;
    }
  }

  Future<void> _runExclusive(
    Future<void> Function() operation, {
    required bool automatic,
  }) async {
    final operationScope = _scope;
    final active = _activeOperation;
    if (active != null) {
      if (automatic) {
        _automaticRerunRequested = true;
        return active;
      }
      await active;
      return _runExclusive(operation, automatic: false);
    }

    late final Future<void> running;
    running = operation();
    _activeOperation = running;
    try {
      await running;
      _automaticConflictRetries = 0;
      AppLogger.instance.log(
        AppLogLevel.debug,
        'Personal-cloud synchronization completed',
        source: 'PersonalCloud',
      );
    } catch (error, stackTrace) {
      if (_scope != operationScope || _disposed) rethrow;
      if (_requiresDecision(error)) {
        if (automatic &&
            _isRemoteRevisionConflict(error) &&
            _automaticConflictRetries < 3) {
          _automaticConflictRetries += 1;
          _automaticRerunRequested = true;
          _state = PersonalCloudSyncState.checking;
          _lastError = null;
          _safeNotify();
          return;
        }
        _decisionReason = PersonalCloudDecisionReason.concurrentChanges;
        _lastError = null;
        _state = PersonalCloudSyncState.decisionRequired;
        _safeNotify();
        AppLogger.instance.log(
          AppLogLevel.warning,
          'Personal-cloud synchronization requires a conflict decision',
          source: 'PersonalCloud',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
      _lastError = error.toString();
      _state = PersonalCloudSyncState.error;
      _safeNotify();
      AppLogger.instance.log(
        AppLogLevel.error,
        'Personal-cloud synchronization failed',
        source: 'PersonalCloud',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      if (identical(_activeOperation, running)) _activeOperation = null;
      if (_automaticRerunRequested && !_disposed) {
        _automaticRerunRequested = false;
        _scheduleAutomaticSync(_automaticChangeDebounce);
      }
    }
  }

  static bool _requiresDecision(Object error) =>
      (error is ServerApiException &&
          (error.code == 'PERSONAL_SNAPSHOT_REVISION_CONFLICT' ||
              error.code ==
                  'PERSONAL_DICTIONARY_SNAPSHOT_REVISION_CONFLICT')) ||
      error.toString().contains('PERSONAL_RECORDS_LOCAL_CHANGED') ||
      error.toString().contains('PERSONAL_DICTIONARY_LOCAL_CHANGED') ||
      error.toString().contains('PERSONAL_SNAPSHOT_REVISION_CONFLICT') ||
      error
          .toString()
          .contains('PERSONAL_DICTIONARY_SNAPSHOT_REVISION_CONFLICT');

  static bool _isRemoteRevisionConflict(Object error) =>
      (error is ServerApiException &&
          (error.code == 'PERSONAL_SNAPSHOT_REVISION_CONFLICT' ||
              error.code ==
                  'PERSONAL_DICTIONARY_SNAPSHOT_REVISION_CONFLICT')) ||
      error.toString().contains('PERSONAL_SNAPSHOT_REVISION_CONFLICT') ||
      error
          .toString()
          .contains('PERSONAL_DICTIONARY_SNAPSHOT_REVISION_CONFLICT');

  Future<void> _reconcile({required bool automatic}) async {
    await _reconcileRecords(automatic: automatic);
    if (_state != PersonalCloudSyncState.upToDate || !_dictionarySupported) {
      return;
    }
    await _reconcileDictionaries();
  }

  Future<void> _reconcileRecords({required bool automatic}) async {
    final context = _captureContext();
    if (context == null) return;
    _state = PersonalCloudSyncState.checking;
    _lastError = null;
    _safeNotify();

    await context.sessions.ready;
    if (!_isCurrent(context)) return;
    final local = await _readLocalSnapshot();
    final meta = await context.server.api.getPersonalCloudSnapshotMeta();
    if (!_isCurrent(context)) return;
    await _ensureSyncStateLoaded(context.scope);
    if (!_isCurrent(context)) return;
    _adoptVisibleSnapshot(local, meta);

    if (context.sessions.databaseReplacementPending) {
      _requireDecision(PersonalCloudDecisionReason.databaseReplaced);
      return;
    }
    if (_pairingRequiredReason != null && !_recordsPairingAcknowledged) {
      _requireDecision(
        _pairingRequiredReason == 'local_cleared'
            ? PersonalCloudDecisionReason.localClearWouldDeleteCloud
            : PersonalCloudDecisionReason.databaseReplaced,
      );
      return;
    }

    final ownsLocalData = _localOwnerScope == _scopeIdentity(context.scope);
    if (!ownsLocalData) {
      if (_localOwnerScope != null) {
        _requireDecision(PersonalCloudDecisionReason.differentAccountData);
        return;
      }
      await _pairInitialRecords(context, local, meta);
      return;
    }

    final baseline = _baseline;
    if (baseline == null) {
      await _pairInitialRecords(context, local, meta);
      return;
    }
    if (baseline.databaseRevision != context.sessions.databaseRevision) {
      _requireDecision(PersonalCloudDecisionReason.databaseReplaced);
      return;
    }

    // A PUT may have committed even when its response was lost. Once the
    // database-generation guard has passed, identical content proves that
    // advancing the baseline is non-destructive and avoids a false conflict.
    if (meta.exists && meta.checksum == local.checksum) {
      await _saveBaseline(
        context.scope,
        _PersonalCloudBaseline(
          revision: meta.revision,
          localChecksum: local.checksum,
          databaseRevision: context.sessions.databaseRevision,
          snapshot: local.json,
        ),
      );
      if (!_isCurrent(context)) return;
      _markUpToDate();
      return;
    }

    if (!meta.exists) {
      if (local.hasContent) {
        await _upload(
          context,
          local,
          expectedRevision: 0,
        );
      } else {
        await _saveBaseline(
          context.scope,
          _PersonalCloudBaseline(
            revision: 0,
            localChecksum: local.checksum,
            databaseRevision: context.sessions.databaseRevision,
            snapshot: local.json,
          ),
        );
        _markUpToDate();
      }
      return;
    }

    final localChanged = local.checksum != baseline.localChecksum;
    final cloudChanged = meta.revision != baseline.revision;
    if (!localChanged && !cloudChanged) {
      _markUpToDate();
      return;
    }
    if (localChanged && cloudChanged) {
      if (baseline.snapshot == null) {
        _requireDecision(PersonalCloudDecisionReason.concurrentChanges);
        return;
      }
      await _prepareRecordsMerge(
        context,
        local: local,
        meta: meta,
        base: baseline.snapshot,
        initial: false,
      );
      return;
    }
    if (localChanged) {
      if (!local.hasContent && meta.sessionCount > 0) {
        _requireDecision(
          PersonalCloudDecisionReason.localClearWouldDeleteCloud,
        );
        return;
      }
      await _upload(
        context,
        local,
        expectedRevision: baseline.revision,
      );
      return;
    }

    await _downloadAndReplace(
      context,
      expectedCloudRevision: meta.revision,
      expectedLocal: local,
    );
  }

  Future<void> _pairInitialRecords(
    _PersonalCloudContext context,
    _LocalPersonalSnapshot local,
    PersonalCloudSnapshotMeta meta,
  ) async {
    if (!meta.exists) {
      if (local.hasContent) {
        await _claimLocalOwnership(context.scope);
        await _upload(
          context,
          local,
          expectedRevision: 0,
          claimOwnership: true,
        );
      } else {
        await _claimLocalOwnership(context.scope);
        await _saveBaseline(
          context.scope,
          _PersonalCloudBaseline(
            revision: 0,
            localChecksum: local.checksum,
            databaseRevision: context.sessions.databaseRevision,
            snapshot: local.json,
          ),
        );
        if (_isCurrent(context)) _markUpToDate();
      }
      return;
    }
    if (meta.checksum == local.checksum) {
      await _claimLocalOwnership(context.scope);
      await _saveBaseline(
        context.scope,
        _PersonalCloudBaseline(
          revision: meta.revision,
          localChecksum: local.checksum,
          databaseRevision: context.sessions.databaseRevision,
          snapshot: local.json,
        ),
      );
      if (_isCurrent(context)) _markUpToDate();
      return;
    }
    if (!local.hasContent) {
      await _claimLocalOwnership(context.scope);
      await _downloadAndReplace(
        context,
        expectedCloudRevision: meta.revision,
        expectedLocal: local,
        claimOwnership: true,
      );
      return;
    }
    await _prepareRecordsMerge(
      context,
      local: local,
      meta: meta,
      base: null,
      initial: true,
    );
  }

  Future<void> _prepareRecordsMerge(
    _PersonalCloudContext context, {
    required _LocalPersonalSnapshot local,
    required PersonalCloudSnapshotMeta meta,
    required Map<String, Object?>? base,
    required bool initial,
  }) async {
    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    final download = await context.server.api.downloadPersonalCloudSnapshot();
    if (!_isCurrent(context)) return;
    if (download.meta.revision != meta.revision) {
      throw StateError('PERSONAL_SNAPSHOT_REVISION_CONFLICT');
    }
    final remote = _snapshotFromJson(download.snapshot);
    _validateDownload(download, remote);
    final baseline = base ?? _emptyRecordsSnapshot();
    final preview = mergePersonalCloudSnapshots(
      dataset: PersonalCloudDataset.records,
      base: baseline,
      local: local.json,
      remote: remote.json,
    );
    _pendingMerge = _PendingPersonalMerge(
      dataset: PersonalCloudDataset.records,
      base: baseline,
      local: local.json,
      remote: remote.json,
      remoteRevision: download.meta.revision,
      expectedLocalRaw: local.rawJson,
      requiresInitialConfirmation: initial,
    );
    _conflicts = List.unmodifiable(preview.conflicts);
    if (initial || preview.hasConflicts) {
      _requireDecision(
        initial
            ? PersonalCloudDecisionReason.differentInitialData
            : PersonalCloudDecisionReason.concurrentChanges,
      );
      return;
    }
    await _commitPendingMerge(const {});
  }

  static Map<String, Object?> _emptyRecordsSnapshot() => {
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'sessions': <Object?>[],
        'logs': <Object?>[],
      };

  Future<void> _reconcileDictionaries() async {
    final context = _captureContext();
    final dictionaries = context?.dictionaries;
    if (context == null || dictionaries == null || !_dictionarySupported) {
      return;
    }
    await dictionaries.ready;
    if (!_isCurrent(context)) return;
    final local = await _readLocalDictionarySnapshot();
    final meta = await context.server.api.getPersonalDictionarySnapshotMeta();
    if (!_isCurrent(context)) return;
    await _ensureDictionaryStateLoaded(context.scope);
    if (!_isCurrent(context)) return;
    _localDictionaryItemCount = local.itemCount;
    _localDictionarySnapshotToken = local.checksum;
    _dictionaryCloudMeta = meta;

    final baseline = _dictionaryBaseline;
    if (baseline == null) {
      await _pairInitialDictionary(context, local, meta);
      return;
    }
    if (meta.exists && meta.checksum == local.checksum) {
      await _saveDictionaryBaseline(
        context.scope,
        _PersonalCloudBaseline(
          revision: meta.revision,
          localChecksum: local.checksum,
          databaseRevision: dictionaries.dataRevision,
          snapshot: local.json,
        ),
      );
      if (_isCurrent(context)) _markUpToDate();
      return;
    }
    if (!meta.exists) {
      await _uploadDictionary(context, local, expectedRevision: 0);
      return;
    }
    final localChanged = local.checksum != baseline.localChecksum;
    final cloudChanged = meta.revision != baseline.revision;
    if (!localChanged && !cloudChanged) {
      _markUpToDate();
      return;
    }
    if (localChanged && cloudChanged) {
      if (baseline.snapshot == null) {
        _requireDecision(PersonalCloudDecisionReason.concurrentChanges);
        return;
      }
      await _prepareDictionaryMerge(
        context,
        local: local,
        meta: meta,
        base: baseline.snapshot,
        initial: false,
      );
      return;
    }
    if (localChanged) {
      await _uploadDictionary(
        context,
        local,
        expectedRevision: baseline.revision,
      );
      return;
    }
    await _downloadAndReplaceDictionary(
      context,
      expectedCloudRevision: meta.revision,
      expectedLocal: local,
    );
  }

  Future<void> _pairInitialDictionary(
    _PersonalCloudContext context,
    _LocalDictionarySnapshot local,
    PersonalDictionarySnapshotMeta meta,
  ) async {
    if (!meta.exists) {
      if (local.hasContent) {
        await _uploadDictionary(context, local, expectedRevision: 0);
      } else {
        await _saveDictionaryBaseline(
          context.scope,
          _PersonalCloudBaseline(
            revision: 0,
            localChecksum: local.checksum,
            databaseRevision: context.dictionaries?.dataRevision ?? 0,
            snapshot: local.json,
          ),
        );
        if (_isCurrent(context)) _markUpToDate();
      }
      return;
    }
    if (meta.checksum == local.checksum) {
      await _saveDictionaryBaseline(
        context.scope,
        _PersonalCloudBaseline(
          revision: meta.revision,
          localChecksum: local.checksum,
          databaseRevision: context.dictionaries?.dataRevision ?? 0,
          snapshot: local.json,
        ),
      );
      if (_isCurrent(context)) _markUpToDate();
      return;
    }
    if (!local.hasContent) {
      await _downloadAndReplaceDictionary(
        context,
        expectedCloudRevision: meta.revision,
        expectedLocal: local,
      );
      return;
    }
    await _prepareDictionaryMerge(
      context,
      local: local,
      meta: meta,
      base: null,
      initial: true,
    );
  }

  Future<void> _prepareDictionaryMerge(
    _PersonalCloudContext context, {
    required _LocalDictionarySnapshot local,
    required PersonalDictionarySnapshotMeta meta,
    required Map<String, Object?>? base,
    required bool initial,
  }) async {
    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    final download =
        await context.server.api.downloadPersonalDictionarySnapshot();
    if (!_isCurrent(context)) return;
    if (download.meta.revision != meta.revision) {
      throw StateError('PERSONAL_DICTIONARY_SNAPSHOT_REVISION_CONFLICT');
    }
    final remote = _dictionarySnapshotFromJson(download.snapshot);
    _validateDictionaryDownload(download, remote);
    final baseline = base ?? _emptyDictionarySnapshot();
    final preview = mergePersonalCloudSnapshots(
      dataset: PersonalCloudDataset.dictionaries,
      base: baseline,
      local: local.json,
      remote: remote.json,
    );
    _pendingMerge = _PendingPersonalMerge(
      dataset: PersonalCloudDataset.dictionaries,
      base: baseline,
      local: local.json,
      remote: remote.json,
      remoteRevision: download.meta.revision,
      expectedLocalRaw: local.rawJson,
      requiresInitialConfirmation: initial,
    );
    _conflicts = List.unmodifiable(preview.conflicts);
    if (initial || preview.hasConflicts) {
      _requireDecision(
        initial
            ? PersonalCloudDecisionReason.differentInitialData
            : PersonalCloudDecisionReason.concurrentChanges,
      );
      return;
    }
    await _commitPendingMerge(const {});
  }

  static Map<String, Object?> _emptyDictionarySnapshot() => {
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'items': <Object?>[],
      };

  /// Confirms an initial merge or resolves every currently visible conflict.
  /// A per-conflict map can be supplied by a richer UI; the settings panel uses
  /// [resolveAllPendingConflicts] for its two safe bulk actions.
  Future<void> resolvePendingConflicts(
    Map<String, PersonalCloudConflictChoice> resolutions,
  ) =>
      _runExclusive(
        () => _commitPendingMerge(resolutions),
        automatic: false,
      );

  Future<void> resolveAllPendingConflicts(
    PersonalCloudConflictChoice choice,
  ) {
    final resolutions = {
      for (final conflict in _conflicts) conflict.conflictId: choice,
    };
    return resolvePendingConflicts(resolutions);
  }

  Future<void> _commitPendingMerge(
    Map<String, PersonalCloudConflictChoice> resolutions,
  ) async {
    final pending = _pendingMerge;
    final context = _captureContext();
    if (pending == null || context == null) {
      throw StateError('PERSONAL_CLOUD_MERGE_NOT_PENDING');
    }
    final result = mergePersonalCloudSnapshots(
      dataset: pending.dataset,
      base: pending.base,
      local: pending.local,
      remote: pending.remote,
      resolutions: resolutions,
    );
    if (result.hasConflicts) {
      _conflicts = List.unmodifiable(result.conflicts);
      _requireDecision(PersonalCloudDecisionReason.concurrentChanges);
      return;
    }
    if (pending.dataset == PersonalCloudDataset.dictionaries) {
      await _commitDictionaryMerge(context, pending, result.snapshot);
      return;
    }

    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    final encoded = jsonEncode(result.snapshot);
    _suppressDependencySignal = true;
    try {
      await context.collaboration.runLocalDatabaseMaintenance(
        () => _replacer(encoded, pending.expectedLocalRaw),
      );
    } finally {
      _suppressDependencySignal = false;
    }
    if (!_isCurrent(context)) return;
    final local = _snapshotFromJson(result.snapshot, rawJson: encoded);
    await _waitForPutSlot(PersonalCloudDataset.records);
    if (!_isCurrent(context)) return;
    final replaced = await context.server.api.replacePersonalCloudSnapshot(
      expectedRevision: pending.remoteRevision,
      snapshot: local.json,
    );
    _markPutCompleted(PersonalCloudDataset.records);
    if (!_isCurrent(context)) return;
    if (pending.requiresInitialConfirmation) {
      await _claimLocalOwnership(context.scope);
    }
    await _saveBaseline(
      context.scope,
      _PersonalCloudBaseline(
        revision: replaced.meta.revision,
        localChecksum: local.checksum,
        databaseRevision: context.sessions.databaseRevision,
        snapshot: local.json,
      ),
    );
    if (!_isCurrent(context)) return;
    _pendingMerge = null;
    _conflicts = const [];
    _adoptVisibleSnapshot(local, replaced.meta);
    _markUpToDate();
  }

  Future<void> _replaceCloudWithLocal({
    required int expectedCloudRevision,
    required String expectedLocalSnapshotToken,
  }) async {
    final context = _captureContext();
    if (context == null) throw StateError('PERSONAL_CLOUD_SIGN_IN_REQUIRED');
    _state = PersonalCloudSyncState.syncing;
    _lastError = null;
    _safeNotify();
    final local = await _readLocalSnapshot();
    if (!_isCurrent(context)) return;
    if (local.checksum != expectedLocalSnapshotToken) {
      throw StateError('PERSONAL_RECORDS_LOCAL_CHANGED');
    }
    await _upload(
      context,
      local,
      expectedRevision: expectedCloudRevision,
      claimOwnership: true,
      acknowledgeReplacement: true,
    );
  }

  Future<void> _restoreCloudToLocal({
    required int expectedCloudRevision,
    required String expectedLocalSnapshotToken,
  }) async {
    final context = _captureContext();
    if (context == null) throw StateError('PERSONAL_CLOUD_SIGN_IN_REQUIRED');
    _state = PersonalCloudSyncState.syncing;
    _lastError = null;
    _safeNotify();
    final local = await _readLocalSnapshot();
    if (!_isCurrent(context)) return;
    if (local.checksum != expectedLocalSnapshotToken) {
      throw StateError('PERSONAL_RECORDS_LOCAL_CHANGED');
    }
    await _downloadAndReplace(
      context,
      expectedCloudRevision: expectedCloudRevision,
      expectedLocal: local,
      claimOwnership: true,
    );
  }

  Future<void> _upload(
    _PersonalCloudContext context,
    _LocalPersonalSnapshot local, {
    required int expectedRevision,
    bool claimOwnership = false,
    bool acknowledgeReplacement = false,
  }) async {
    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    await _waitForPutSlot(PersonalCloudDataset.records);
    if (!_isCurrent(context)) return;
    final result = await context.server.api.replacePersonalCloudSnapshot(
      expectedRevision: expectedRevision,
      snapshot: local.json,
    );
    _markPutCompleted(PersonalCloudDataset.records);
    if (!_isCurrent(context)) return;
    if (claimOwnership) await _claimLocalOwnership(context.scope);
    if (!_isCurrent(context)) return;
    await _saveBaseline(
      context.scope,
      _PersonalCloudBaseline(
        revision: result.meta.revision,
        localChecksum: local.checksum,
        databaseRevision: context.sessions.databaseRevision,
        snapshot: local.json,
      ),
    );
    if (!_isCurrent(context)) return;
    _cloudMeta = result.meta;
    if (acknowledgeReplacement) {
      await context.sessions.acknowledgeDatabaseReplacement();
      if (!_isCurrent(context)) return;
    }
    _markUpToDate();
  }

  Future<void> _downloadAndReplace(
    _PersonalCloudContext context, {
    required int expectedCloudRevision,
    required _LocalPersonalSnapshot expectedLocal,
    bool claimOwnership = false,
  }) async {
    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    final download = await context.server.api.downloadPersonalCloudSnapshot();
    if (!_isCurrent(context)) return;
    if (download.meta.revision != expectedCloudRevision) {
      throw StateError('PERSONAL_SNAPSHOT_REVISION_CONFLICT');
    }
    final encoded = jsonEncode(download.snapshot);
    final replacement = _snapshotFromJson(
      download.snapshot,
      rawJson: encoded,
    );
    _validateDownload(download, replacement);
    _suppressDependencySignal = true;
    try {
      await context.collaboration.runLocalDatabaseMaintenance(
        () async {
          if (!_isCurrent(context)) {
            throw StateError('PERSONAL_CLOUD_CONTEXT_CHANGED');
          }
          return _replacer(encoded, expectedLocal.rawJson);
        },
      );
    } finally {
      _suppressDependencySignal = false;
    }
    if (!_isCurrent(context)) return;
    if (claimOwnership) await _claimLocalOwnership(context.scope);
    if (!_isCurrent(context)) return;
    await _saveBaseline(
      context.scope,
      _PersonalCloudBaseline(
        revision: download.meta.revision,
        localChecksum: replacement.checksum,
        databaseRevision: context.sessions.databaseRevision,
        snapshot: replacement.json,
      ),
    );
    if (!_isCurrent(context)) return;
    _adoptVisibleSnapshot(replacement, download.meta);
    _markUpToDate();
  }

  Future<void> _uploadDictionary(
    _PersonalCloudContext context,
    _LocalDictionarySnapshot local, {
    required int expectedRevision,
  }) async {
    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    await _waitForPutSlot(PersonalCloudDataset.dictionaries);
    if (!_isCurrent(context)) return;
    final result = await context.server.api.replacePersonalDictionarySnapshot(
      expectedRevision: expectedRevision,
      snapshot: local.json,
    );
    _markPutCompleted(PersonalCloudDataset.dictionaries);
    if (!_isCurrent(context)) return;
    await _saveDictionaryBaseline(
      context.scope,
      _PersonalCloudBaseline(
        revision: result.meta.revision,
        localChecksum: local.checksum,
        databaseRevision: context.dictionaries?.dataRevision ?? 0,
        snapshot: local.json,
      ),
    );
    if (!_isCurrent(context)) return;
    _dictionaryCloudMeta = result.meta;
    _localDictionaryItemCount = local.itemCount;
    _localDictionarySnapshotToken = local.checksum;
    _markUpToDate();
  }

  Future<void> _downloadAndReplaceDictionary(
    _PersonalCloudContext context, {
    required int expectedCloudRevision,
    required _LocalDictionarySnapshot expectedLocal,
  }) async {
    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    final download =
        await context.server.api.downloadPersonalDictionarySnapshot();
    if (!_isCurrent(context)) return;
    if (download.meta.revision != expectedCloudRevision) {
      throw StateError('PERSONAL_DICTIONARY_SNAPSHOT_REVISION_CONFLICT');
    }
    final encoded = jsonEncode(download.snapshot);
    final replacement = _dictionarySnapshotFromJson(
      download.snapshot,
      rawJson: encoded,
    );
    _validateDictionaryDownload(download, replacement);
    _suppressDependencySignal = true;
    try {
      await _dictionaryReplacer(encoded, expectedLocal.rawJson);
      await context.dictionaries?.reloadFromDatabase();
    } finally {
      _suppressDependencySignal = false;
    }
    if (!_isCurrent(context)) return;
    await _saveDictionaryBaseline(
      context.scope,
      _PersonalCloudBaseline(
        revision: download.meta.revision,
        localChecksum: replacement.checksum,
        databaseRevision: context.dictionaries?.dataRevision ?? 0,
        snapshot: replacement.json,
      ),
    );
    if (!_isCurrent(context)) return;
    _dictionaryCloudMeta = download.meta;
    _localDictionaryItemCount = replacement.itemCount;
    _localDictionarySnapshotToken = replacement.checksum;
    _markUpToDate();
  }

  Future<void> _commitDictionaryMerge(
    _PersonalCloudContext context,
    _PendingPersonalMerge pending,
    Map<String, Object?> merged,
  ) async {
    _state = PersonalCloudSyncState.syncing;
    _safeNotify();
    final encoded = jsonEncode(merged);
    _suppressDependencySignal = true;
    try {
      await _dictionaryReplacer(encoded, pending.expectedLocalRaw);
      await context.dictionaries?.reloadFromDatabase();
    } finally {
      _suppressDependencySignal = false;
    }
    if (!_isCurrent(context)) return;
    final local = _dictionarySnapshotFromJson(merged, rawJson: encoded);
    await _waitForPutSlot(PersonalCloudDataset.dictionaries);
    if (!_isCurrent(context)) return;
    final result = await context.server.api.replacePersonalDictionarySnapshot(
      expectedRevision: pending.remoteRevision,
      snapshot: local.json,
    );
    _markPutCompleted(PersonalCloudDataset.dictionaries);
    if (!_isCurrent(context)) return;
    await _saveDictionaryBaseline(
      context.scope,
      _PersonalCloudBaseline(
        revision: result.meta.revision,
        localChecksum: local.checksum,
        databaseRevision: context.dictionaries?.dataRevision ?? 0,
        snapshot: local.json,
      ),
    );
    if (!_isCurrent(context)) return;
    _pendingMerge = null;
    _conflicts = const [];
    _dictionaryCloudMeta = result.meta;
    _localDictionaryItemCount = local.itemCount;
    _localDictionarySnapshotToken = local.checksum;
    _markUpToDate();
  }

  void _validateDownload(
    PersonalCloudSnapshotDownload download,
    _LocalPersonalSnapshot replacement,
  ) {
    final meta = download.meta;
    if (!meta.exists ||
        meta.formatVersion != 1 ||
        meta.sessionCount != replacement.sessionCount ||
        meta.logCount != replacement.logCount ||
        meta.checksum != replacement.checksum) {
      throw const FormatException('PERSONAL_SNAPSHOT_INTEGRITY_FAILED');
    }
  }

  void _validateDictionaryDownload(
    PersonalDictionarySnapshotDownload download,
    _LocalDictionarySnapshot replacement,
  ) {
    final meta = download.meta;
    if (!meta.exists ||
        meta.formatVersion != 1 ||
        meta.itemCount != replacement.itemCount ||
        meta.activeCount != replacement.activeCount ||
        meta.deletedCount != replacement.deletedCount ||
        meta.checksum != replacement.checksum) {
      throw const FormatException(
        'PERSONAL_DICTIONARY_SNAPSHOT_INTEGRITY_FAILED',
      );
    }
  }

  void _requireDecision(PersonalCloudDecisionReason reason) {
    _decisionReason = reason;
    _state = PersonalCloudSyncState.decisionRequired;
    _safeNotify();
  }

  void _markUpToDate() {
    _decisionReason = null;
    _state = PersonalCloudSyncState.upToDate;
    _lastSyncedAt = DateTime.now();
    _safeNotify();
  }

  Future<_LocalPersonalSnapshot> _readLocalSnapshot() async {
    final instance = _server?.serverInfo?.serverInstanceId;
    final account = _server?.accountId;
    if (instance != null &&
        account != null &&
        await hasPendingPersonalPromotion(
            await openKeyValueStore(), instance, account)) {
      throw StateError(
          'PERSONAL_PROMOTION_PENDING: 共享升级尚未完成，请到对应会话重试发布；个人云同步已暂停，原记录保留。');
    }
    final raw = await _exporter();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('personal snapshot must be a JSON object');
    }
    return _snapshotFromJson(
      Map<String, Object?>.from(decoded),
      rawJson: raw,
    );
  }

  Future<_LocalDictionarySnapshot> _readLocalDictionarySnapshot() async {
    final raw = await _dictionaryExporter();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException(
        'personal dictionary snapshot must be a JSON object',
      );
    }
    return _dictionarySnapshotFromJson(
      Map<String, Object?>.from(decoded),
      rawJson: raw,
    );
  }

  static _LocalPersonalSnapshot _snapshotFromJson(
    Map<String, Object?> snapshot, {
    String? rawJson,
  }) {
    final sessions = snapshot['sessions'];
    final logs = snapshot['logs'];
    if (snapshot['version'] != 1 || sessions is! List || logs is! List) {
      throw const FormatException('unsupported personal snapshot format');
    }
    return _LocalPersonalSnapshot(
      json: Map<String, Object?>.from(snapshot),
      rawJson: rawJson ?? jsonEncode(snapshot),
      checksum: personalSnapshotContentChecksum(snapshot),
      sessionCount: sessions.length,
      logCount: logs.length,
    );
  }

  static _LocalDictionarySnapshot _dictionarySnapshotFromJson(
    Map<String, Object?> snapshot, {
    String? rawJson,
  }) {
    final items = snapshot['items'];
    if (snapshot['version'] != 1 || items is! List) {
      throw const FormatException('unsupported personal dictionary format');
    }
    var activeCount = 0;
    var deletedCount = 0;
    for (final value in items) {
      if (value is! Map) {
        throw const FormatException('invalid personal dictionary item');
      }
      if (value['state'] == 'active') {
        activeCount += 1;
      } else if (value['state'] == 'deleted') {
        deletedCount += 1;
      } else {
        throw const FormatException('invalid personal dictionary state');
      }
    }
    return _LocalDictionarySnapshot(
      json: Map<String, Object?>.from(snapshot),
      rawJson: rawJson ?? jsonEncode(snapshot),
      checksum: personalDictionaryContentChecksum(snapshot),
      itemCount: items.length,
      activeCount: activeCount,
      deletedCount: deletedCount,
    );
  }

  void _adoptVisibleSnapshot(
    _LocalPersonalSnapshot local,
    PersonalCloudSnapshotMeta meta,
  ) {
    _localSessionCount = local.sessionCount;
    _localLogCount = local.logCount;
    _localSnapshotToken = local.checksum;
    _cloudMeta = meta;
  }

  _PersonalCloudContext? _captureContext() {
    final scope = _scope;
    final server = _server;
    final sessions = _sessions;
    final logs = _logs;
    final collaboration = _collaboration;
    if (scope == null ||
        !_supported ||
        server == null ||
        sessions == null ||
        logs == null ||
        collaboration == null ||
        !server.isLoggedIn) {
      return null;
    }
    return _PersonalCloudContext(
      scope: scope,
      server: server,
      sessions: sessions,
      logs: logs,
      collaboration: collaboration,
      dictionaries: _dictionaries,
    );
  }

  bool _isCurrent(_PersonalCloudContext context) =>
      !_disposed &&
      _supported &&
      _scope == context.scope &&
      identical(_server, context.server) &&
      identical(_sessions, context.sessions) &&
      identical(_logs, context.logs) &&
      context.server.isLoggedIn &&
      !context.server.passwordChangeRequired;

  Future<void> _ensureSyncStateLoaded(String scope) async {
    if (_baselineLoaded) return;
    final identity = _scopeIdentity(scope);
    if (_useNativeStateStore) {
      final decoded = jsonDecode(await _stateLoader(identity, 'records'));
      if (decoded is! Map) {
        throw const FormatException('PERSONAL_CLOUD_STATE_INVALID');
      }
      final state = Map<String, Object?>.from(decoded);
      _localOwnerScope = state['ownerScopeHash']?.toString();
      _pairingRequiredReason = state['pairingRequiredReason']?.toString();
      final rawBaseline = state['baseline'];
      if (rawBaseline != null) {
        if (rawBaseline is! Map) {
          throw const FormatException('PERSONAL_CLOUD_BASELINE_INVALID');
        }
        final value = Map<String, Object?>.from(rawBaseline);
        final snapshotValue = value['snapshot'];
        if (value['remoteRevision'] is! int ||
            value['checksum'] is! String ||
            snapshotValue is! Map) {
          throw const FormatException('PERSONAL_CLOUD_BASELINE_INVALID');
        }
        final snapshot = Map<String, Object?>.from(snapshotValue);
        final checksum = value['checksum']! as String;
        if (personalSnapshotContentChecksum(snapshot) != checksum) {
          throw const FormatException('PERSONAL_CLOUD_BASELINE_INVALID');
        }
        _baseline = _PersonalCloudBaseline(
          revision: value['remoteRevision']! as int,
          localChecksum: checksum,
          databaseRevision: _sessions?.databaseRevision ?? 0,
          snapshot: snapshot,
        );
      }
      _recordsPairingAcknowledged =
          _pairingRequiredReason != null && _baseline != null;
      _baselineLoaded = true;
      return;
    }
    final prefs = await openKeyValueStore();
    if (_scope != scope) return;
    final prefix = _preferencePrefix(scope);
    final revision = await prefs.getInt('${prefix}revision');
    final checksum = await prefs.getString('${prefix}local_checksum');
    final databaseRevision = await prefs.getInt('${prefix}database_revision');
    _localOwnerScope =
        await prefs.getString('personal_cloud_v1_local_owner_scope');
    _baseline = revision == null || checksum == null || databaseRevision == null
        ? null
        : _PersonalCloudBaseline(
            revision: revision,
            localChecksum: checksum,
            databaseRevision: databaseRevision,
          );
    _baselineLoaded = true;
  }

  Future<void> _saveBaseline(
    String scope,
    _PersonalCloudBaseline baseline,
  ) async {
    final identity = _scopeIdentity(scope);
    final clearPairingRequirement = _pairingRequiredReason == null ||
        !_dictionarySupported ||
        _dictionaryPairingAcknowledged;
    if (_useNativeStateStore) {
      final snapshot = baseline.snapshot;
      if (snapshot == null) {
        throw StateError('PERSONAL_CLOUD_BASELINE_SNAPSHOT_MISSING');
      }
      await _baselineSaver(
        scopeHash: identity,
        dataset: 'records',
        remoteRevision: baseline.revision,
        snapshotJson: jsonEncode(snapshot),
        checksum: baseline.localChecksum,
        claimOwner: _localOwnerScope == identity,
        clearPairingRequirement: clearPairingRequirement,
      );
    }
    final prefs = await openKeyValueStore();
    if (_scope != scope) return;
    final prefix = _preferencePrefix(scope);
    final revisionSaved =
        await prefs.setInt('${prefix}revision', baseline.revision);
    final checksumSaved = await prefs.setString(
      '${prefix}local_checksum',
      baseline.localChecksum,
    );
    final databaseRevisionSaved = await prefs.setInt(
      '${prefix}database_revision',
      baseline.databaseRevision,
    );
    if (!revisionSaved || !checksumSaved || !databaseRevisionSaved) {
      throw StateError('PERSONAL_CLOUD_BASELINE_PERSIST_FAILED');
    }
    if (_scope == scope) {
      _baseline = baseline;
      _baselineLoaded = true;
      _recordsPairingAcknowledged = true;
      if (clearPairingRequirement) _pairingRequiredReason = null;
      if (_pairingRequiredReason != null && _dictionarySupported) {
        _automaticRerunRequested = true;
      }
    }
  }

  Future<void> _ensureDictionaryStateLoaded(String scope) async {
    if (_dictionaryBaselineLoaded) return;
    final identity = _scopeIdentity(scope);
    if (_useNativeStateStore) {
      final decoded = jsonDecode(await _stateLoader(identity, 'dictionaries'));
      if (decoded is! Map) {
        throw const FormatException('PERSONAL_CLOUD_STATE_INVALID');
      }
      final state = Map<String, Object?>.from(decoded);
      _localOwnerScope = state['ownerScopeHash']?.toString();
      _pairingRequiredReason = state['pairingRequiredReason']?.toString();
      final rawBaseline = state['baseline'];
      if (rawBaseline != null) {
        if (rawBaseline is! Map) {
          throw const FormatException('PERSONAL_CLOUD_BASELINE_INVALID');
        }
        final value = Map<String, Object?>.from(rawBaseline);
        final snapshotValue = value['snapshot'];
        if (value['remoteRevision'] is! int ||
            value['checksum'] is! String ||
            snapshotValue is! Map) {
          throw const FormatException('PERSONAL_CLOUD_BASELINE_INVALID');
        }
        final snapshot = Map<String, Object?>.from(snapshotValue);
        final checksum = value['checksum']! as String;
        if (personalDictionaryContentChecksum(snapshot) != checksum) {
          throw const FormatException('PERSONAL_CLOUD_BASELINE_INVALID');
        }
        _dictionaryBaseline = _PersonalCloudBaseline(
          revision: value['remoteRevision']! as int,
          localChecksum: checksum,
          databaseRevision: _dictionaries?.dataRevision ?? 0,
          snapshot: snapshot,
        );
      }
      _dictionaryPairingAcknowledged =
          _pairingRequiredReason != null && _dictionaryBaseline != null;
      _dictionaryBaselineLoaded = true;
      return;
    }
    final prefs = await openKeyValueStore();
    if (_scope != scope) return;
    final prefix = '${_preferencePrefix(scope)}dictionary_';
    final revision = await prefs.getInt('${prefix}revision');
    final checksum = await prefs.getString('${prefix}local_checksum');
    _dictionaryBaseline = revision == null || checksum == null
        ? null
        : _PersonalCloudBaseline(
            revision: revision,
            localChecksum: checksum,
            databaseRevision: _dictionaries?.dataRevision ?? 0,
          );
    _dictionaryBaselineLoaded = true;
  }

  Future<void> _saveDictionaryBaseline(
    String scope,
    _PersonalCloudBaseline baseline,
  ) async {
    final identity = _scopeIdentity(scope);
    final clearPairingRequirement =
        _pairingRequiredReason == null || _recordsPairingAcknowledged;
    if (_useNativeStateStore) {
      final snapshot = baseline.snapshot;
      if (snapshot == null) {
        throw StateError('PERSONAL_CLOUD_BASELINE_SNAPSHOT_MISSING');
      }
      await _baselineSaver(
        scopeHash: identity,
        dataset: 'dictionaries',
        remoteRevision: baseline.revision,
        snapshotJson: jsonEncode(snapshot),
        checksum: baseline.localChecksum,
        claimOwner: _localOwnerScope == identity,
        clearPairingRequirement: clearPairingRequirement,
      );
    }
    final prefs = await openKeyValueStore();
    if (_scope != scope) return;
    final prefix = '${_preferencePrefix(scope)}dictionary_';
    final revisionSaved =
        await prefs.setInt('${prefix}revision', baseline.revision);
    final checksumSaved = await prefs.setString(
      '${prefix}local_checksum',
      baseline.localChecksum,
    );
    if (!revisionSaved || !checksumSaved) {
      throw StateError('PERSONAL_CLOUD_BASELINE_PERSIST_FAILED');
    }
    if (_scope == scope) {
      _dictionaryBaseline = baseline;
      _dictionaryBaselineLoaded = true;
      _dictionaryPairingAcknowledged = true;
      if (clearPairingRequirement) _pairingRequiredReason = null;
    }
  }

  static String _preferencePrefix(String scope) =>
      'personal_cloud_v1_${sha256.convert(utf8.encode(scope))}_';

  static String _scopeIdentity(String scope) =>
      sha256.convert(utf8.encode(scope)).toString();

  Future<void> _claimLocalOwnership(String scope) async {
    final identity = _scopeIdentity(scope);
    final prefs = await openKeyValueStore();
    if (_scope != scope) return;
    final saved = await prefs.setString(
      'personal_cloud_v1_local_owner_scope',
      identity,
    );
    if (!saved) {
      throw StateError('PERSONAL_CLOUD_OWNER_PERSIST_FAILED');
    }
    if (_scope == scope) {
      _localOwnerScope = identity;
    }
  }

  void _notifySoon() {
    scheduleMicrotask(_safeNotify);
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}

@immutable
final class _PersonalCloudBaseline {
  const _PersonalCloudBaseline({
    required this.revision,
    required this.localChecksum,
    required this.databaseRevision,
    this.snapshot,
  });

  final int revision;
  final String localChecksum;
  final int databaseRevision;
  final Map<String, Object?>? snapshot;
}

@immutable
final class _PendingPersonalMerge {
  const _PendingPersonalMerge({
    required this.dataset,
    required this.base,
    required this.local,
    required this.remote,
    required this.remoteRevision,
    required this.expectedLocalRaw,
    required this.requiresInitialConfirmation,
  });

  final PersonalCloudDataset dataset;
  final Map<String, Object?> base;
  final Map<String, Object?> local;
  final Map<String, Object?> remote;
  final int remoteRevision;
  final String expectedLocalRaw;
  final bool requiresInitialConfirmation;
}

@immutable
final class _LocalPersonalSnapshot {
  const _LocalPersonalSnapshot({
    required this.json,
    required this.rawJson,
    required this.checksum,
    required this.sessionCount,
    required this.logCount,
  });

  final PersonalCloudJsonObject json;
  final String rawJson;
  final String checksum;
  final int sessionCount;
  final int logCount;

  bool get hasContent => sessionCount > 0 || logCount > 0;
}

@immutable
final class _LocalDictionarySnapshot {
  const _LocalDictionarySnapshot({
    required this.json,
    required this.rawJson,
    required this.checksum,
    required this.itemCount,
    required this.activeCount,
    required this.deletedCount,
  });

  final PersonalDictionarySnapshotJson json;
  final String rawJson;
  final String checksum;
  final int itemCount;
  final int activeCount;
  final int deletedCount;

  bool get hasContent => itemCount > 0;
}

@immutable
final class _PersonalCloudContext {
  const _PersonalCloudContext({
    required this.scope,
    required this.server,
    required this.sessions,
    required this.logs,
    required this.collaboration,
    required this.dictionaries,
  });

  final String scope;
  final ServerProvider server;
  final SessionProvider sessions;
  final LogProvider logs;
  final CollaborationProvider collaboration;
  final DictionaryProvider? dictionaries;
}
