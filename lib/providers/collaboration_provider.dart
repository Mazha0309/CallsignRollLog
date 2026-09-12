import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:openlogtool/models/collaboration_conflict.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/services/collaboration_publish.dart';
import 'package:openlogtool/services/collaboration_catalog_restore.dart';
import 'package:openlogtool/services/collaboration_conflicts.dart';
import 'package:openlogtool/services/collaboration_replica.dart';
import 'package:openlogtool/services/collaboration_sync.dart';
import 'package:openlogtool/services/server_api.dart';
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:openlogtool/utils/log_time.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:openlogtool/services/app_logger.dart';

enum CollaborationState {
  localOnly,
  publishing,
  joining,
  snapshotting,
  catchingUp,
  ready,
  resyncing,
  revoked,
  failed,
}

enum LiveDraftCommitDisposition { committed, queuedOffline }

final class _AutomaticLiveDraftTimeMarker {
  const _AutomaticLiveDraftTimeMarker({
    required this.draftId,
    required this.displayMinute,
    required this.maxTimeRevision,
  });

  final String draftId;
  final String displayMinute;
  final int maxTimeRevision;
}

@visibleForTesting
LiveDraftFieldsDto resetLiveDraftFieldsAfterCommit(
  LiveDraftFieldsDto previous,
) =>
    LiveDraftFieldsDto({
      'time': '',
      'controller': previous['controller'],
      'rstSent': '59',
      'rstRcvd': '59',
    });

@visibleForTesting
String projectLiveDraftTimeForDisplay({
  required String value,
  required int revision,
  required bool locallyDirty,
  required String draftId,
  String? automaticDraftId,
  String? automaticDisplayMinute,
  int? automaticMaxRevision,
}) {
  if (value.trim().isEmpty) return value;
  // Server releases before 2.0.3 initialized a fresh draft with the current
  // time at revision zero. That value is a default, not input for the next
  // record, and must not leak back into client editors.
  if (revision == 0 && !locallyDirty) return '';
  final suppressesThisDraft = automaticDraftId == draftId &&
      automaticDisplayMinute != null &&
      automaticDisplayMinute == formatLogTimeForDisplay(value);
  if (suppressesThisDraft &&
      (locallyDirty || revision <= (automaticMaxRevision ?? 0))) {
    return '';
  }
  return value;
}

final class LocalCollaborationBinding {
  const LocalCollaborationBinding({
    required this.serverInstanceId,
    required this.serverOrigin,
    required this.accountId,
    required this.sessionId,
    required this.membershipId,
    required this.membershipVersion,
    required this.role,
    required this.replicaState,
    required this.lastAppliedSeq,
    required this.lastSeenHeadSeq,
    required this.revokedAt,
  });

  factory LocalCollaborationBinding.fromJson(Object? value) {
    final map = Map<String, Object?>.from(value! as Map);
    return LocalCollaborationBinding(
      serverInstanceId: map['serverInstanceId']! as String,
      serverOrigin: map['serverOrigin']! as String,
      accountId: map['accountId']! as String,
      sessionId: map['sessionId']! as String,
      membershipId: map['membershipId']! as String,
      membershipVersion: map['membershipVersion']! as int,
      role: SessionRole.fromJson(map['role'], 'role'),
      replicaState: map['replicaState']! as String,
      lastAppliedSeq: map['lastAppliedSeq']! as int,
      lastSeenHeadSeq: map['lastSeenHeadSeq']! as int,
      revokedAt: map['revokedAt'] == null
          ? null
          : DateTime.parse(map['revokedAt']! as String),
    );
  }

  final String serverInstanceId;
  final String serverOrigin;
  final String accountId;
  final String sessionId;
  final String membershipId;
  final int membershipVersion;
  final SessionRole role;
  final String replicaState;
  final int lastAppliedSeq;
  final int lastSeenHeadSeq;
  final DateTime? revokedAt;
}

final class _OperationContext {
  _OperationContext({
    required this.server,
    required this.api,
    required this.sessions,
    required this.logs,
    required this.serverContextRevision,
    required this.serverUrl,
    required this.accountId,
    required this.sessionId,
    required this.epoch,
  });

  final ServerProvider server;
  final ServerApi api;
  final SessionProvider sessions;
  final LogProvider logs;
  final int serverContextRevision;
  final String serverUrl;
  final String accountId;
  String? sessionId;
  int epoch;
}

final class _OperationContextChanged implements Exception {
  const _OperationContextChanged();

  @override
  String toString() => 'COLLABORATION_CONTEXT_CHANGED: 服务器、账号或会话已切换';
}

CollaborationConflictPort _resolveConflictPort(
  CollaborationReplicaPort? replica,
) {
  if (replica is CollaborationConflictPort) {
    return replica as CollaborationConflictPort;
  }
  return const RustCollaborationReplicaPort();
}

@visibleForTesting
bool collaborationEventMayAffectOpenConflicts({
  required CollaborationEventDto event,
  required List<CollaborationConflict> openConflicts,
  required int reportedConflictCount,
}) {
  if (reportedConflictCount <= 0 && openConflicts.isEmpty) return false;
  // While the first list request is pending, conservatively invalidate on any
  // event so a response read just before that event cannot become permanent.
  if (openConflicts.isEmpty) return true;
  // Session status/version changes can alter the allowed resolutions of every
  // Log conflict, even when the conflicted entity itself did not change.
  if (event.entityType == 'session') return true;
  return openConflicts.any(
    (conflict) =>
        conflict.entityType.name == event.entityType &&
        conflict.entityId == event.entityId,
  );
}

@visibleForTesting
String? collaborationLogMutationBlockReason({
  required bool collaborationBound,
  required bool canEditSession,
  required bool sharedEditingSupported,
  required String? accountId,
  required bool authorshipKnown,
  required String? createdBy,
}) {
  if (!collaborationBound) return null;
  if (!canEditSession || accountId == null) {
    return 'COLLABORATION_SESSION_READ_ONLY';
  }
  if (sharedEditingSupported) return null;
  if (!authorshipKnown || createdBy == null) {
    return 'COLLABORATION_LOG_AUTHOR_UNKNOWN';
  }
  if (createdBy != accountId) return 'COLLABORATION_LOG_NOT_OWNED';
  return null;
}

typedef LiveDraftAtomicLockAcquirer = Future<LiveDraftLockDto> Function(
  String field,
);
typedef LiveDraftAtomicPatchSender = Future<LiveDraftPatchResultDto> Function(
  int clientSeq,
  List<LiveDraftPatchUpdateDto> updates,
);
typedef LiveDraftAtomicLockReleaser = Future<void> Function(
  String field,
  LiveDraftLockDto lock,
);
typedef _LiveDraftContext = ({
  ServerApi api,
  LocalCollaborationBinding binding,
  String deviceId,
  int epoch,
});
typedef _LiveDraftGuard = ({
  LocalCollaborationBinding binding,
  int epoch,
});

@visibleForTesting
final class LiveDraftAtomicPatchExecution {
  const LiveDraftAtomicPatchExecution({
    required this.result,
    required this.appliedClientSeq,
  });

  final LiveDraftPatchResultDto result;
  final int appliedClientSeq;
}

@visibleForTesting
final class LiveDraftAtomicStateMerge {
  const LiveDraftAtomicStateMerge({
    required this.localFields,
    required this.dirtyFields,
    required this.baseRevisions,
  });

  final LiveDraftFieldsDto localFields;
  final Set<String> dirtyFields;
  final Map<String, int> baseRevisions;
}

@visibleForTesting
final class LiveDraftLockRebaseProjection {
  const LiveDraftLockRebaseProjection({
    required this.canonicalDraft,
    required this.localFields,
    required this.dirtyFields,
    required this.baseRevisions,
    required this.conflictedFields,
    required this.generationChanged,
  });

  final LiveDraftDto canonicalDraft;
  final LiveDraftFieldsDto localFields;
  final Set<String> dirtyFields;
  final Map<String, int> baseRevisions;
  final Set<String> conflictedFields;
  final bool generationChanged;
}

/// Rebases one locally dirty field to the canonical revision captured at the
/// instant its exclusive lease was granted. Unrelated dirty fields keep their
/// original conflict baselines.
@visibleForTesting
LiveDraftLockRebaseProjection projectLiveDraftLockAcquisition({
  required String acquiredField,
  required LiveDraftDto currentDraft,
  required LiveDraftDto incomingDraft,
  required LiveDraftFieldsDto localFields,
  required Set<String> dirtyFields,
  required Map<String, int> baseRevisions,
}) {
  if (!liveDraftFieldNames.contains(acquiredField)) {
    throw ArgumentError.value(acquiredField, 'acquiredField');
  }
  if (incomingDraft.sessionId != currentDraft.sessionId) {
    throw const FormatException(
      'Live-draft lock snapshot belongs to another Session',
    );
  }
  if (incomingDraft.draftId != currentDraft.draftId) {
    return LiveDraftLockRebaseProjection(
      canonicalDraft: incomingDraft,
      localFields: incomingDraft.fields,
      dirtyFields: const <String>{},
      baseRevisions: const <String, int>{},
      conflictedFields: const <String>{},
      generationChanged: true,
    );
  }
  if (incomingDraft.version < currentDraft.version) {
    return LiveDraftLockRebaseProjection(
      canonicalDraft: currentDraft,
      localFields: localFields,
      dirtyFields: Set<String>.unmodifiable(dirtyFields),
      baseRevisions: Map<String, int>.unmodifiable(baseRevisions),
      conflictedFields: const <String>{},
      generationChanged: false,
    );
  }

  final rebasedDirtyFields = Set<String>.of(dirtyFields);
  final rebasedBaseRevisions = Map<String, int>.of(baseRevisions);
  final conflictedFields = <String>{};
  final values = <String, String>{};
  for (final field in liveDraftFieldNames) {
    if (!rebasedDirtyFields.contains(field)) {
      values[field] = incomingDraft.fields[field];
      continue;
    }
    final localValue = localFields[field];
    values[field] = localValue;
    if (localValue == incomingDraft.fields[field]) {
      rebasedDirtyFields.remove(field);
      rebasedBaseRevisions.remove(field);
    } else if (field == acquiredField) {
      final previousRevision = rebasedBaseRevisions[field] ??
          currentDraft.fieldRevisions[field] ??
          0;
      final incomingRevision = incomingDraft.fieldRevisions[field] ?? 0;
      if (incomingRevision != previousRevision) {
        // Granting the lease proves exclusivity only from this instant onward;
        // it does not authorize overwriting a collaborator's change that was
        // committed while the lock request crossed the network.
        conflictedFields.add(field);
        rebasedBaseRevisions[field] = previousRevision;
      } else {
        rebasedBaseRevisions[field] = incomingRevision;
      }
    } else {
      rebasedBaseRevisions[field] = rebasedBaseRevisions[field] ??
          currentDraft.fieldRevisions[field] ??
          0;
    }
  }
  return LiveDraftLockRebaseProjection(
    canonicalDraft: incomingDraft,
    localFields: LiveDraftFieldsDto(values),
    dirtyFields: Set<String>.unmodifiable(rebasedDirtyFields),
    baseRevisions: Map<String, int>.unmodifiable(rebasedBaseRevisions),
    conflictedFields: Set<String>.unmodifiable(conflictedFields),
    generationChanged: false,
  );
}

@visibleForTesting
bool canReleaseIdleLiveDraftLease({
  required bool fieldDirty,
  required LiveDraftLockDto? currentLock,
  required String? expectedLeaseId,
}) {
  return !fieldDirty &&
      currentLock != null &&
      (expectedLeaseId == null || currentLock.leaseId == expectedLeaseId);
}

/// Projects an atomic update into the local draft before the server responds.
///
/// The original canonical revision is retained for fields that were already
/// dirty, so the eventual atomic PATCH still performs the same conflict check
/// as a non-optimistic update.
@visibleForTesting
LiveDraftAtomicStateMerge stageOptimisticLiveDraftAtomicPatch({
  required LiveDraftDto canonicalDraft,
  required LiveDraftFieldsDto localFields,
  required Set<String> dirtyFields,
  required Map<String, int> baseRevisions,
  required Map<String, String> updates,
}) {
  final stagedValues = Map<String, String>.of(localFields.values);
  final stagedDirtyFields = Set<String>.of(dirtyFields);
  final stagedBaseRevisions = Map<String, int>.of(baseRevisions);
  for (final field in liveDraftFieldNames) {
    final value = updates[field];
    if (value == null) continue;
    stagedValues[field] = value;
    if (value == canonicalDraft.fields[field]) {
      stagedDirtyFields.remove(field);
      stagedBaseRevisions.remove(field);
      continue;
    }
    if (!stagedDirtyFields.contains(field) ||
        !stagedBaseRevisions.containsKey(field)) {
      stagedBaseRevisions[field] = canonicalDraft.fieldRevisions[field] ?? 0;
    }
    stagedDirtyFields.add(field);
  }
  return LiveDraftAtomicStateMerge(
    localFields: LiveDraftFieldsDto(stagedValues),
    dirtyFields: Set<String>.unmodifiable(stagedDirtyFields),
    baseRevisions: Map<String, int>.unmodifiable(stagedBaseRevisions),
  );
}

/// Removes only optimistic values that are still unchanged when a PATCH
/// fails. A later local edit is preserved, while previously dirty values are
/// restored with their original conflict baseline.
@visibleForTesting
LiveDraftAtomicStateMerge rollbackOptimisticLiveDraftAtomicPatch({
  required LiveDraftDto canonicalDraft,
  required LiveDraftFieldsDto beforeLocalFields,
  required Set<String> beforeDirtyFields,
  required Map<String, int> beforeBaseRevisions,
  required LiveDraftFieldsDto currentLocalFields,
  required Set<String> currentDirtyFields,
  required Map<String, int> currentBaseRevisions,
  required Map<String, String> stagedValues,
}) {
  final restoredValues = Map<String, String>.of(currentLocalFields.values);
  final restoredDirtyFields = Set<String>.of(currentDirtyFields);
  final restoredBaseRevisions = Map<String, int>.of(currentBaseRevisions);
  for (final field in liveDraftFieldNames) {
    final stagedValue = stagedValues[field];
    if (stagedValue == null || currentLocalFields[field] != stagedValue) {
      continue;
    }
    if (beforeDirtyFields.contains(field)) {
      restoredValues[field] = beforeLocalFields[field];
      restoredDirtyFields.add(field);
      restoredBaseRevisions[field] = beforeBaseRevisions[field] ??
          canonicalDraft.fieldRevisions[field] ??
          0;
    } else {
      restoredValues[field] = canonicalDraft.fields[field];
      restoredDirtyFields.remove(field);
      restoredBaseRevisions.remove(field);
    }
  }
  return LiveDraftAtomicStateMerge(
    localFields: LiveDraftFieldsDto(restoredValues),
    dirtyFields: Set<String>.unmodifiable(restoredDirtyFields),
    baseRevisions: Map<String, int>.unmodifiable(restoredBaseRevisions),
  );
}

/// Merges an accepted atomic PATCH without overwriting edits made while the
/// request was in flight.
@visibleForTesting
LiveDraftAtomicStateMerge mergeAcceptedLiveDraftAtomicPatch({
  required Set<String> targetFields,
  required LiveDraftFieldsDto beforeLocalFields,
  required Set<String> beforeDirtyFields,
  required Map<String, int> beforeBaseRevisions,
  required LiveDraftFieldsDto currentLocalFields,
  required Set<String> currentDirtyFields,
  required Map<String, int> currentBaseRevisions,
  required LiveDraftDto canonicalDraft,
}) {
  final dirtyFields = Set<String>.of(currentDirtyFields);
  final baseRevisions = Map<String, int>.of(currentBaseRevisions);
  final mergedValues = <String, String>{};
  for (final field in liveDraftFieldNames) {
    if (!targetFields.contains(field)) {
      mergedValues[field] = dirtyFields.contains(field)
          ? currentLocalFields[field]
          : canonicalDraft.fields[field];
      continue;
    }

    final changedWhilePending =
        currentLocalFields[field] != beforeLocalFields[field] ||
            currentDirtyFields.contains(field) !=
                beforeDirtyFields.contains(field) ||
            (currentDirtyFields.contains(field) &&
                currentBaseRevisions[field] != beforeBaseRevisions[field]);
    if (!changedWhilePending) {
      mergedValues[field] = canonicalDraft.fields[field];
      dirtyFields.remove(field);
      baseRevisions.remove(field);
      continue;
    }

    final currentValue = currentLocalFields[field];
    mergedValues[field] = currentValue;
    if (currentValue == canonicalDraft.fields[field]) {
      dirtyFields.remove(field);
      baseRevisions.remove(field);
    } else {
      dirtyFields.add(field);
      baseRevisions[field] = canonicalDraft.fieldRevisions[field] ?? 0;
    }
  }
  return LiveDraftAtomicStateMerge(
    localFields: LiveDraftFieldsDto(mergedValues),
    dirtyFields: Set<String>.unmodifiable(dirtyFields),
    baseRevisions: Map<String, int>.unmodifiable(baseRevisions),
  );
}

final class _OptimisticLiveDraftRollback {
  const _OptimisticLiveDraftRollback({
    required this.draftId,
    required this.beforeLocalFields,
    required this.beforeDirtyFields,
    required this.beforeBaseRevisions,
    required this.stagedValues,
  });

  final String draftId;
  final LiveDraftFieldsDto beforeLocalFields;
  final Set<String> beforeDirtyFields;
  final Map<String, int> beforeBaseRevisions;
  final Map<String, String> stagedValues;
}

@visibleForTesting
LiveDraftDto selectLiveDraftCanonicalAfterAtomicPatch({
  required LiveDraftDto current,
  required LiveDraftDto accepted,
}) {
  if (current.draftId != accepted.draftId ||
      current.version > accepted.version) {
    return current;
  }
  return accepted;
}

/// Accepts authoritative refreshes without allowing an older response from the
/// same draft generation to replace a newer in-memory draft.
///
/// Locks are independent leases, so the incoming lock list remains useful even
/// when its draft body is stale.
@visibleForTesting
LiveDraftSnapshotDto selectLiveDraftSnapshotAfterRefresh({
  required LiveDraftSnapshotDto current,
  required LiveDraftSnapshotDto incoming,
}) {
  if (current.draft.draftId == incoming.draft.draftId) {
    if (current.draft.version <= incoming.draft.version) {
      return incoming;
    }
    return LiveDraftSnapshotDto(
      draft: current.draft,
      locks: incoming.locks,
      currentOrdinal: current.currentOrdinal,
      totalRecords: current.totalRecords,
      previousRecord: current.previousRecord,
    );
  }
  if (incoming.currentOrdinal > current.currentOrdinal ||
      incoming.totalRecords > current.totalRecords ||
      incoming.draft.createdAt.isAfter(current.draft.createdAt)) {
    return incoming;
  }
  return current;
}

/// Complete in-memory projection produced by one member-only live-draft
/// WebSocket control message.
///
/// The server includes the complete canonical draft in update/reset controls,
/// so consumers do not need to turn every keystroke notification into another
/// GET request. Local dirty values remain optimistic until their serialized
/// PATCH is acknowledged.
@visibleForTesting
final class LiveDraftControlProjection {
  const LiveDraftControlProjection({
    required this.snapshot,
    required this.localFields,
    required this.dirtyFields,
    required this.baseRevisions,
    required this.changed,
  });

  final LiveDraftSnapshotDto snapshot;
  final LiveDraftFieldsDto localFields;
  final Set<String> dirtyFields;
  final Map<String, int> baseRevisions;
  final bool changed;
}

List<LiveDraftLockDto>? _liveDraftControlLocks(JsonObject message) {
  if (!message.containsKey('locks')) return null;
  final values = message['locks'];
  if (values is! List) {
    throw const FormatException('Live-draft control locks must be an array');
  }
  return List<LiveDraftLockDto>.unmodifiable(
    values.map(LiveDraftLockDto.fromJson),
  );
}

bool _sameLiveDraftLocks(
  List<LiveDraftLockDto> left,
  List<LiveDraftLockDto> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.leaseId != b.leaseId ||
        a.field != b.field ||
        a.userId != b.userId ||
        a.deviceId != b.deviceId ||
        a.expiresAt != b.expiresAt) {
      return false;
    }
  }
  return true;
}

/// Explicit history reuse is the one remote update allowed to replace local
/// edits in its declared station-detail fields. Ordinary member updates retain
/// the standard dirty-field preservation behavior.
@visibleForTesting
LiveDraftControlProjection applyLiveDraftHistoryReuseProjection({
  required LiveDraftControlProjection projection,
  required LiveDraftDto canonicalDraft,
  required LiveDraftHistoryReuseDto historyReuse,
  List<LiveDraftLockDto>? locks,
}) {
  if (projection.snapshot.draft.sessionId != canonicalDraft.sessionId ||
      projection.snapshot.draft.draftId != canonicalDraft.draftId) {
    throw const FormatException(
      'History reuse belongs to another live-draft generation',
    );
  }
  final dirtyFields = Set<String>.of(projection.dirtyFields)
    ..removeAll(historyReuse.affectedFields);
  final baseRevisions = Map<String, int>.of(projection.baseRevisions)
    ..removeWhere((field, _) => historyReuse.affectedFields.contains(field));
  return LiveDraftControlProjection(
    snapshot: LiveDraftSnapshotDto(
      draft: canonicalDraft,
      locks: locks ?? projection.snapshot.locks,
      currentOrdinal: projection.snapshot.currentOrdinal,
      totalRecords: projection.snapshot.totalRecords,
      previousRecord: projection.snapshot.previousRecord,
    ),
    localFields: LiveDraftFieldsDto({
      for (final field in liveDraftFieldNames)
        field: historyReuse.affectedFields.contains(field)
            ? canonicalDraft.fields[field]
            : projection.localFields[field],
    }),
    dirtyFields: Set<String>.unmodifiable(dirtyFields),
    baseRevisions: Map<String, int>.unmodifiable(baseRevisions),
    changed: true,
  );
}

/// A member-control acknowledgement for a PATCH whose HTTP response may have
/// been lost after the server committed it.
@visibleForTesting
final class LiveDraftPatchControlAcknowledgement {
  const LiveDraftPatchControlAcknowledgement({
    required this.draft,
    required this.releasedLeases,
  });

  final LiveDraftDto draft;
  final List<LiveDraftReleasedLeaseDto> releasedLeases;
}

/// Mirrors the server's canonical live-draft field normalization so a WebSocket
/// acknowledgement still matches when the accepted value was trimmed or an
/// identifier was uppercased before persistence.
@visibleForTesting
String canonicalLiveDraftPatchAckValue(String field, String? value) {
  if (!liveDraftFieldNames.contains(field)) {
    throw ArgumentError.value(field, 'field');
  }
  final normalized = value?.trim() ?? '';
  return field == 'controller' || field == 'callsign'
      ? normalized.toUpperCase()
      : normalized;
}

/// Returns whether a draft-generation transition would discard local input
/// that is neither present in the current canonical draft nor already
/// represented by an accepted record.
@visibleForTesting
bool hasUnpreservedLiveDraftChanges({
  required LiveDraftDto currentDraft,
  required LiveDraftFieldsDto localFields,
  required Set<String> dirtyFields,
  LiveDraftFieldsDto? acceptedFields,
}) {
  for (final field in dirtyFields) {
    if (!liveDraftFieldNames.contains(field)) continue;
    final localValue = canonicalLiveDraftPatchAckValue(
      field,
      localFields[field],
    );
    final currentValue = canonicalLiveDraftPatchAckValue(
      field,
      currentDraft.fields[field],
    );
    if (localValue == currentValue) continue;
    if (acceptedFields != null &&
        localValue ==
            canonicalLiveDraftPatchAckValue(field, acceptedFields[field])) {
      continue;
    }
    return true;
  }
  return false;
}

LiveDraftFieldsDto _liveDraftFieldsFromCommittedRecord(
  CollaborationLogDto record,
) =>
    LiveDraftFieldsDto({
      'time': record.time.toUtc().toIso8601String(),
      'controller': record.controller,
      'callsign': record.callsign,
      'rstSent': record.rstSent ?? '',
      'rstRcvd': record.rstRcvd ?? '',
      'qth': record.qth ?? '',
      'device': record.device ?? '',
      'power': record.power ?? '',
      'antenna': record.antenna ?? '',
      'height': record.height ?? '',
      'remarks': record.remarks ?? '',
    });

/// Matches only a control emitted for this exact device/client sequence and
/// exact field mutation. New servers identify [updatedFields] explicitly;
/// older servers remain compatible through value plus monotonic-revision
/// matching against the complete canonical draft.
@visibleForTesting
LiveDraftPatchControlAcknowledgement? matchLiveDraftPatchControlAck({
  required JsonObject message,
  required String sessionId,
  required String deviceId,
  required int clientSeq,
  required String draftId,
  required Map<String, String> expectedValues,
  required Map<String, int> expectedRevisions,
}) {
  if (message['type'] != 'liveDraft.updated' ||
      message['sessionId'] != sessionId ||
      message['deviceId'] != deviceId ||
      message['clientSeq'] != clientSeq) {
    return null;
  }
  try {
    final updatedFieldsValue = message['updatedFields'] ?? message['fields'];
    if (updatedFieldsValue != null) {
      if (updatedFieldsValue is! List ||
          updatedFieldsValue.any(
            (value) => value is! String || !liveDraftFieldNames.contains(value),
          )) {
        return null;
      }
      final updatedFields = updatedFieldsValue.cast<String>().toSet();
      if (!updatedFields.containsAll(expectedValues.keys)) return null;
    }
    final incoming = LiveDraftDto.fromJson(message['draft']);
    if (incoming.sessionId != sessionId || incoming.draftId != draftId) {
      return null;
    }
    for (final entry in expectedValues.entries) {
      final expectedRevision = expectedRevisions[entry.key];
      if (expectedRevision == null ||
          incoming.fields[entry.key] != entry.value ||
          (incoming.fieldRevisions[entry.key] ?? 0) <= expectedRevision) {
        return null;
      }
    }
    final releasedValue = message['releasedLeases'];
    if (releasedValue != null && releasedValue is! List) return null;
    final releasedValues =
        releasedValue is List ? releasedValue : const <Object?>[];
    return LiveDraftPatchControlAcknowledgement(
      draft: incoming,
      releasedLeases: releasedValues.isEmpty
          ? const <LiveDraftReleasedLeaseDto>[]
          : List<LiveDraftReleasedLeaseDto>.unmodifiable(
              releasedValues.map(LiveDraftReleasedLeaseDto.fromJson),
            ),
    );
  } on FormatException {
    return null;
  }
}

/// Applies a complete live-draft control payload with draft-generation and
/// version gating. Older controls from the same generation are ignored.
@visibleForTesting
LiveDraftControlProjection applyLiveDraftControlMessage({
  required LiveDraftSnapshotDto currentSnapshot,
  required LiveDraftFieldsDto currentLocalFields,
  required Set<String> currentDirtyFields,
  required Map<String, int> currentBaseRevisions,
  required JsonObject message,
}) {
  final sessionId = message['sessionId'];
  if (sessionId != currentSnapshot.draft.sessionId) {
    throw const FormatException(
      'Live-draft control belongs to another Session',
    );
  }
  final type = message['type'];
  if (type is! String) {
    throw const FormatException('Live-draft control type is missing');
  }

  LiveDraftControlProjection adoptDraft(
    LiveDraftDto incoming, {
    List<LiveDraftLockDto>? locks,
    int? currentOrdinal,
    int? totalRecords,
    CollaborationLogDto? previousRecord,
    bool replacePreviousRecord = false,
    bool allowGenerationChange = false,
    bool discardLocalState = false,
  }) {
    if (incoming.sessionId != currentSnapshot.draft.sessionId) {
      throw const FormatException(
        'Live-draft control contains a draft from another Session',
      );
    }
    final currentDraft = currentSnapshot.draft;
    final sameGeneration = currentDraft.draftId == incoming.draftId;
    final locksChanged =
        locks != null && !_sameLiveDraftLocks(currentSnapshot.locks, locks);
    if (!sameGeneration && !allowGenerationChange) {
      throw const FormatException(
        'Live-draft control cannot prove a draft generation change',
      );
    }
    if (sameGeneration &&
        incoming.version <= currentDraft.version &&
        !discardLocalState &&
        !locksChanged) {
      return LiveDraftControlProjection(
        snapshot: currentSnapshot,
        localFields: currentLocalFields,
        dirtyFields: currentDirtyFields,
        baseRevisions: currentBaseRevisions,
        changed: false,
      );
    }

    final preserveLocalState = sameGeneration && !discardLocalState;
    final dirtyFields = preserveLocalState
        ? Set<String>.unmodifiable(currentDirtyFields)
        : const <String>{};
    final baseRevisions = preserveLocalState
        ? Map<String, int>.unmodifiable({
            for (final field in dirtyFields)
              field: currentBaseRevisions[field] ??
                  currentDraft.fieldRevisions[field] ??
                  0,
          })
        : const <String, int>{};
    final localFields = LiveDraftFieldsDto({
      for (final field in liveDraftFieldNames)
        field: preserveLocalState && dirtyFields.contains(field)
            ? currentLocalFields[field]
            : incoming.fields[field],
    });
    return LiveDraftControlProjection(
      snapshot: LiveDraftSnapshotDto(
        draft: incoming,
        locks: locks ??
            (sameGeneration
                ? currentSnapshot.locks
                : const <LiveDraftLockDto>[]),
        currentOrdinal: currentOrdinal ?? currentSnapshot.currentOrdinal,
        totalRecords: totalRecords ?? currentSnapshot.totalRecords,
        previousRecord: replacePreviousRecord
            ? previousRecord
            : currentSnapshot.previousRecord,
      ),
      localFields: localFields,
      dirtyFields: dirtyFields,
      baseRevisions: baseRevisions,
      changed: true,
    );
  }

  switch (type) {
    case 'liveDraft.updated':
      return adoptDraft(
        LiveDraftDto.fromJson(message['draft']),
        locks: _liveDraftControlLocks(message),
      );
    case 'liveDraft.cleared':
      final nextDraft = LiveDraftDto.fromJson(message['nextDraft']);
      final terminalValue = message['terminal'];
      if (terminalValue != null && terminalValue is! bool) {
        throw const FormatException(
          'Live-draft clear control terminal marker is invalid',
        );
      }
      final terminal = terminalValue == true;
      final discardedDraftId = _liveDraftControlId(
        message,
        'discardedDraftId',
      );
      final currentDraftId = currentSnapshot.draft.draftId;
      if (currentDraftId != discardedDraftId &&
          currentDraftId != nextDraft.draftId &&
          !terminal) {
        throw const FormatException(
          'Live-draft clear control has an unknown predecessor',
        );
      }
      return adoptDraft(
        nextDraft,
        locks: const [],
        allowGenerationChange: terminal || currentDraftId == discardedDraftId,
        discardLocalState: terminal,
      );
    case 'liveDraft.committed':
      final nextDraft = LiveDraftDto.fromJson(message['nextDraft']);
      final committedDraftId = _liveDraftControlId(
        message,
        'committedDraftId',
      );
      final currentDraftId = currentSnapshot.draft.draftId;
      if (currentDraftId != committedDraftId &&
          currentDraftId != nextDraft.draftId) {
        throw const FormatException(
          'Live-draft commit control has an unknown predecessor',
        );
      }
      final currentOrdinal = message['currentOrdinal'];
      final totalRecords = message['totalRecords'];
      if (currentOrdinal is! int ||
          currentOrdinal < 1 ||
          totalRecords is! int ||
          totalRecords < 0) {
        throw const FormatException(
          'Live-draft commit counters are invalid',
        );
      }
      return adoptDraft(
        nextDraft,
        locks: const [],
        currentOrdinal: currentOrdinal,
        totalRecords: totalRecords,
        previousRecord: CollaborationLogDto.fromJson(message['record']),
        replacePreviousRecord: true,
        allowGenerationChange: currentDraftId == committedDraftId,
      );
    case 'liveDraft.lockChanged':
      final occurredAtValue = message['occurredAt'];
      final occurredAt =
          occurredAtValue is String ? DateTime.tryParse(occurredAtValue) : null;
      if (occurredAt == null) {
        throw const FormatException(
          'Live-draft lock control occurredAt is invalid',
        );
      }
      final generationStartedAt = currentSnapshot.draft.createdAt;
      if (occurredAt.isBefore(generationStartedAt)) {
        return LiveDraftControlProjection(
          snapshot: currentSnapshot,
          localFields: currentLocalFields,
          dirtyFields: currentDirtyFields,
          baseRevisions: currentBaseRevisions,
          changed: false,
        );
      }
      if (occurredAt.isAtSameMomentAs(generationStartedAt)) {
        throw const FormatException(
          'Live-draft lock control generation is ambiguous',
        );
      }
      final locks = _locksAfterLiveDraftControl(
        currentSnapshot.locks,
        message,
      );
      return LiveDraftControlProjection(
        snapshot: LiveDraftSnapshotDto(
          draft: currentSnapshot.draft,
          locks: locks,
          currentOrdinal: currentSnapshot.currentOrdinal,
          totalRecords: currentSnapshot.totalRecords,
          previousRecord: currentSnapshot.previousRecord,
        ),
        localFields: currentLocalFields,
        dirtyFields: currentDirtyFields,
        baseRevisions: currentBaseRevisions,
        changed: true,
      );
    default:
      throw FormatException('Unknown live-draft control type: $type');
  }
}

/// Projects the durable marker attached to an administrative forced-close
/// event into the same complete control shape used by the realtime channel.
/// Ordinary close events and non-terminal markers intentionally do not reset
/// draft generations.
@visibleForTesting
JsonObject? terminalLiveDraftClearControlFromEvent(
  CollaborationEventDto event,
) {
  if (event.type != 'session.closed' ||
      event.entityType != 'session' ||
      event.entityId != event.sessionId) {
    return null;
  }
  final marker = event.payload['liveDraftCleared'];
  if (marker is! Map || marker['terminal'] != true) return null;
  return {
    ...Map<String, Object?>.from(marker),
    'type': 'liveDraft.cleared',
    'sessionId': event.sessionId,
    'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    'terminal': true,
  };
}

String _liveDraftControlId(JsonObject message, String field) {
  final value = message[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('Live-draft control $field is invalid');
  }
  return value;
}

List<LiveDraftLockDto> _locksAfterLiveDraftControl(
  List<LiveDraftLockDto> current,
  JsonObject message,
) {
  final rawLocks = message['locks'];
  if (rawLocks is List) {
    return List.unmodifiable(rawLocks.map(LiveDraftLockDto.fromJson));
  }

  final rawLock = message['lock'];
  if (rawLock != null) {
    final lock = LiveDraftLockDto.fromJson(rawLock);
    return List.unmodifiable([
      for (final candidate in current)
        if (candidate.field != lock.field && candidate.leaseId != lock.leaseId)
          candidate,
      lock,
    ]);
  }

  final rawFields = message['fields'];
  if (rawFields is List) {
    final fields = rawFields.map((value) => value.toString()).toSet();
    return List.unmodifiable(
      current.where((lock) => !fields.contains(lock.field)),
    );
  }

  final leaseId = message['leaseId'];
  if (leaseId is String && leaseId.isNotEmpty) {
    return List.unmodifiable(
      current.where((lock) => lock.leaseId != leaseId),
    );
  }

  throw const FormatException('Live-draft lock control is incomplete');
}

@visibleForTesting
Map<String, LiveDraftLockDto> reconcileOwnedLiveDraftLocks({
  required Map<String, LiveDraftLockDto> owned,
  required List<LiveDraftLockDto> canonical,
}) {
  final reconciled = <String, LiveDraftLockDto>{};
  for (final entry in owned.entries) {
    LiveDraftLockDto? matching;
    for (final lock in canonical) {
      if (lock.field == entry.key &&
          lock.leaseId == entry.value.leaseId &&
          lock.userId == entry.value.userId &&
          lock.deviceId == entry.value.deviceId) {
        matching = lock;
        break;
      }
    }
    if (matching != null) reconciled[entry.key] = matching;
  }
  return Map.unmodifiable(reconciled);
}

@visibleForTesting
bool shouldRefreshLiveDraftAfterTransportTransition(
  CollaborationTransportPhase? previous,
  CollaborationTransportPhase current,
) =>
    current == CollaborationTransportPhase.online &&
    previous != CollaborationTransportPhase.online;

/// Returns whether replacing the synchronized replica can use the guarded,
/// clean-conversion path. The replacement is an active local recorder even
/// when the source replica is already closed.
@visibleForTesting
bool canSafelyConvertCollaborationSessionToLocal({
  required bool hasCurrentBinding,
  required bool operationInProgress,
  required CollaborationState state,
  required CollaborationSyncState? syncState,
  required bool hasOfflineRecords,
}) {
  final sync = syncState;
  return hasCurrentBinding &&
      !operationInProgress &&
      state == CollaborationState.ready &&
      sync != null &&
      sync.replicaPhase == CollaborationReplicaPhase.ready &&
      sync.transportPhase == CollaborationTransportPhase.online &&
      sync.pendingCount == 0 &&
      sync.conflictCount == 0 &&
      sync.rejectedCount == 0 &&
      !hasOfflineRecords &&
      !sync.remoteCommitPendingLocalApply &&
      sync.lastAppliedSeq >= sync.serverHeadSeq;
}

/// Lets device-local destructive actions proceed even if an already-running
/// HTTP request or WebSocket shutdown never settles. Both inputs must already
/// have been invalidated/detached before this bounded grace period begins.
@visibleForTesting
Future<void> waitForCollaborationLocalQuiescence(
  Iterable<Future<void>> pending, {
  Duration timeout = const Duration(milliseconds: 350),
}) async {
  try {
    await Future.wait<void>([
      for (final future in pending) future.catchError((_) {}),
    ]).timeout(timeout);
  } on TimeoutException {
    // Generation invalidation prevents future network responses from starting
    // new replica writes. Any SQLite transaction already in progress remains
    // serialized with the following device-local transaction.
  }
}

/// Rejects a late live-draft result after local maintenance or a binding
/// switch, including when an imported backup restores the same server/session
/// identifiers in a newer state epoch.
@visibleForTesting
bool isLiveDraftResultContextCurrent({
  required bool disposed,
  required bool operationInProgress,
  required int expectedEpoch,
  required int currentEpoch,
  required LocalCollaborationBinding expectedBinding,
  required LocalCollaborationBinding? currentBinding,
  required String? currentSessionId,
}) {
  return !disposed &&
      !operationInProgress &&
      expectedEpoch == currentEpoch &&
      currentBinding != null &&
      currentBinding.serverInstanceId == expectedBinding.serverInstanceId &&
      currentBinding.accountId == expectedBinding.accountId &&
      currentBinding.sessionId == expectedBinding.sessionId &&
      currentSessionId == expectedBinding.sessionId;
}

/// A serial executor whose current tail can be detached without waiting for it.
///
/// Device-local collaboration escape hatches use [detach] after invalidating
/// the old request context. A permanently stalled transport can then settle in
/// the detached chain without blocking draft work for a later collaboration.
@visibleForTesting
final class ResettableLiveDraftSerialExecutor {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _tail;
    _tail = () async {
      try {
        await previous;
      } catch (_) {
        // Each caller receives its own error; a failed action must not poison
        // later operations in the same chain.
      }
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  Future<void> detach() {
    final detached = _tail;
    _tail = Future<void>.value();
    return detached;
  }
}

typedef LiveDraftAtomicAttempt<T> = Future<T> Function();
typedef LiveDraftAtomicConflictRebaser = Future<void> Function(
  ServerApiException conflict,
);
typedef LiveDraftCommitAttempt<T> = Future<T> Function(int attempt);
typedef LiveDraftCommitRaceRecoverer = Future<void> Function(
  ServerApiException conflict,
  int attempt,
);

/// Retries an explicit atomic fill after rebasing a stale field/version
/// baseline. A few bounded retries absorb long-RTT races without weakening the
/// server's compare-and-swap protection.
@visibleForTesting
Future<T> executeLiveDraftAtomicPatchWithRebaseRetry<T>({
  required LiveDraftAtomicAttempt<T> attempt,
  required LiveDraftAtomicConflictRebaser rebase,
  int maxAttempts = 4,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }
  for (var attemptNumber = 1;; attemptNumber += 1) {
    try {
      return await attempt();
    } on ServerApiException catch (error) {
      if (attemptNumber >= maxAttempts ||
          !{
            'LIVE_DRAFT_FIELD_CONFLICT',
            'LIVE_DRAFT_VERSION_CONFLICT',
          }.contains(error.code)) {
        rethrow;
      }
      await rebase(error);
    }
  }
}

/// Retries a commit only for the two races that can settle without operator
/// input: a stale canonical version and a collaborator's short-lived lease.
/// The caller owns the recovery policy so production can back off while tests
/// remain deterministic.
@visibleForTesting
Future<T> executeLiveDraftCommitWithRaceRecovery<T>({
  required LiveDraftCommitAttempt<T> attempt,
  required LiveDraftCommitRaceRecoverer recover,
  int maxAttempts = 4,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }
  for (var attemptNumber = 1;; attemptNumber += 1) {
    try {
      return await attempt(attemptNumber);
    } on ServerApiException catch (error) {
      final recoverableRace = {
        'LIVE_DRAFT_VERSION_CONFLICT',
        'LIVE_DRAFT_BUSY',
      }.contains(error.code);
      if (!recoverableRace || attemptNumber >= maxAttempts) rethrow;
      await recover(error, attemptNumber);
    }
  }
}

final class _LiveDraftFieldFlushBatch {
  _LiveDraftFieldFlushBatch(this.epoch);

  final int epoch;
  final Completer<void> completer = Completer<void>();
}

final class _PendingLiveDraftPatchAck {
  _PendingLiveDraftPatchAck({
    required this.sessionId,
    required this.deviceId,
    required this.clientSeq,
    required this.draftId,
    required this.expectedValues,
    required this.expectedRevisions,
  });

  final String sessionId;
  final String deviceId;
  final int clientSeq;
  final String draftId;
  final Map<String, String> expectedValues;
  final Map<String, int> expectedRevisions;
  final Completer<LiveDraftPatchControlAcknowledgement> completer =
      Completer<LiveDraftPatchControlAcknowledgement>();
}

/// Acquires every required field lease before issuing exactly one PATCH.
///
/// Locks already owned by the caller are retained. Locks acquired by this
/// operation are best-effort released in reverse order on both success and
/// failure. The server validates every lease and field revision in one
/// transaction, so no requested field can be committed on its own.
@visibleForTesting
Future<LiveDraftAtomicPatchExecution> executeLiveDraftAtomicPatch({
  required Map<String, String> values,
  required Map<String, int> expectedRevisions,
  required Map<String, LiveDraftLockDto> ownedLocks,
  required int nextClientSeq,
  required LiveDraftAtomicLockAcquirer acquireLock,
  required LiveDraftAtomicPatchSender sendPatch,
  required LiveDraftAtomicLockReleaser releaseLock,
  required void Function(int clientSeq) onClientSeqChanged,
  void Function()? assertCurrent,
  DateTime? now,
}) async {
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'must not be empty');
  }
  if (nextClientSeq < 1) {
    throw ArgumentError.value(nextClientSeq, 'nextClientSeq');
  }
  for (final field in values.keys) {
    if (!liveDraftFieldNames.contains(field)) {
      throw ArgumentError.value(field, 'values', 'unsupported field');
    }
    if (!expectedRevisions.containsKey(field)) {
      throw ArgumentError.value(
        expectedRevisions,
        'expectedRevisions',
        'missing revision for $field',
      );
    }
  }

  final orderedFields =
      liveDraftFieldNames.where(values.containsKey).toList(growable: false);
  final acquiredHere = <String, LiveDraftLockDto>{};
  final leases = <String, LiveDraftLockDto>{};
  final serverReleasedLeaseIds = <String>{};
  final currentTime = now ?? DateTime.now();
  try {
    for (final field in orderedFields) {
      assertCurrent?.call();
      final existing = ownedLocks[field];
      if (existing != null &&
          existing.field == field &&
          existing.expiresAt.isAfter(currentTime)) {
        leases[field] = existing;
        continue;
      }
      final acquired = await acquireLock(field);
      leases[field] = acquired;
      acquiredHere[field] = acquired;
      // Register cleanup before checking context. The request can complete
      // after a binding switch/dispose; that late lease still needs a bounded
      // best-effort release.
      assertCurrent?.call();
    }

    final updates = [
      for (final field in orderedFields)
        LiveDraftPatchUpdateDto(
          field: field,
          value: values[field],
          expectedRevision: expectedRevisions[field]!,
          leaseId: leases[field]!.leaseId,
        ),
    ];
    var clientSeq = nextClientSeq;
    late LiveDraftPatchResultDto result;
    try {
      assertCurrent?.call();
      result = await sendPatch(clientSeq, updates);
      serverReleasedLeaseIds.addAll(
        result.releasedLeases.map((lease) => lease.leaseId),
      );
      assertCurrent?.call();
    } on ServerApiException catch (error) {
      assertCurrent?.call();
      if (error.code == 'LIVE_DRAFT_CLIENT_SEQ_GAP') {
        final expected = _expectedLiveDraftClientSeq(error);
        if (expected == null) rethrow;
        onClientSeqChanged(expected - 1);
        clientSeq = expected;
        assertCurrent?.call();
        result = await sendPatch(clientSeq, updates);
        serverReleasedLeaseIds.addAll(
          result.releasedLeases.map((lease) => lease.leaseId),
        );
        assertCurrent?.call();
      } else if (error.code == 'LIVE_DRAFT_CLIENT_SEQ_REUSED') {
        onClientSeqChanged(clientSeq);
        clientSeq += 1;
        assertCurrent?.call();
        result = await sendPatch(clientSeq, updates);
        serverReleasedLeaseIds.addAll(
          result.releasedLeases.map((lease) => lease.leaseId),
        );
        assertCurrent?.call();
      } else {
        rethrow;
      }
    }
    if (result.appliedClientSeq != clientSeq) {
      throw const FormatException(
        'live draft response acknowledged another clientSeq',
      );
    }
    onClientSeqChanged(result.appliedClientSeq);
    return LiveDraftAtomicPatchExecution(
      result: result,
      appliedClientSeq: result.appliedClientSeq,
    );
  } finally {
    for (final field in orderedFields.reversed) {
      final lock = acquiredHere[field];
      if (lock == null || serverReleasedLeaseIds.contains(lock.leaseId)) {
        continue;
      }
      try {
        await releaseLock(field, lock);
      } catch (_) {
        // Releasing a temporary lease is cleanup only. The lease is bounded
        // and must not hide an acquisition or PATCH failure.
      }
    }
  }
}

int? _expectedLiveDraftClientSeq(ServerApiException error) {
  final details = error.details;
  if (details is! Map) return null;
  final expected = details['expectedClientSeq'];
  return expected is int && expected > 0 ? expected : null;
}

@visibleForTesting
LiveDraftDto? liveDraftCanonicalFromConflict(
  ServerApiException error, {
  required String sessionId,
}) {
  final details = error.details;
  if (details is! Map || details['draft'] == null) return null;
  try {
    final draft = LiveDraftDto.fromJson(details['draft']);
    return draft.sessionId == sessionId ? draft : null;
  } on FormatException {
    return null;
  }
}

class CollaborationProvider with ChangeNotifier {
  CollaborationProvider({
    CollaborationReplicaPort? replica,
    CollaborationConflictPort? conflicts,
    CollaborationSocketConnector? sockets,
  })  : _replica = replica ?? const RustCollaborationReplicaPort(),
        _conflictPort = conflicts ?? _resolveConflictPort(replica),
        _sockets = sockets ?? const WebSocketChannelConnector();

  static const _pendingJoinPrefix = 'collaboration_pending_join_';
  static const _legacyPendingJoinIdKey = 'collaboration_pending_join_id';
  static const _legacyPendingJoinFingerprintKey =
      'collaboration_pending_join_fingerprint';
  static const _pendingMutationPrefix = 'collaboration_pending_mutation_';

  static const _publishFeatures = {
    'sessionPublishing',
    'sessionBootstrap',
    'sessionSnapshots',
    'sessionMembership',
  };
  static const _joinFeatures = {
    'collaborationInvites',
    'sessionSnapshots',
    'sessionMembership',
  };
  static const _refreshFeatures = {
    'sessionSnapshots',
    'sessionSnapshotTombstones',
    'sessionMembership',
  };
  static const _memberManagementFeatures = {
    'sessionMembership',
  };
  static const _inviteManagementFeatures = {
    'collaborationInvites',
  };
  static const _syncFeatures = {
    'sessionEvents',
    'sessionMutations',
    'collaborationWebSocket',
    'sessionSnapshotTombstones',
  };
  static const _liveDraftFeature = 'collaborationLiveDraft';
  static const _sharedLogEditingFeature = 'collaborationSharedLogEditing';
  static const _publicShareFeatures = {
    'publicLiveshare',
    'publicLivesharePage',
  };

  final CollaborationReplicaPort _replica;
  final CollaborationConflictPort _conflictPort;
  final CollaborationSocketConnector _sockets;

  ServerProvider? _server;
  SessionProvider? _sessions;
  LogProvider? _logs;
  String? _dependencyKey;
  bool _sharedLogEditingSupported = false;
  bool _refreshScheduled = false;
  bool _disposed = false;
  bool _operationInProgress = false;
  int _stateEpoch = 0;
  int _refreshGeneration = 0;
  String? _publishingSessionId;
  CollaborationSyncCoordinator? _syncCoordinator;
  CollaborationSyncState? _syncState;
  int _syncGeneration = 0;
  int _conflictRequestGeneration = 0;
  int _conflictInvalidationGeneration = 0;
  bool _conflictsNeedRefresh = false;
  bool _conflictReloadScheduled = false;
  int _liveDraftGeneration = 0;
  final ResettableLiveDraftSerialExecutor _liveDraftSerial =
      ResettableLiveDraftSerialExecutor();
  final Map<String, _LiveDraftFieldFlushBatch> _liveDraftFieldFlushBatches =
      <String, _LiveDraftFieldFlushBatch>{};
  final Map<int, _PendingLiveDraftPatchAck> _pendingLiveDraftPatchAcks =
      <int, _PendingLiveDraftPatchAck>{};
  Timer? _liveDraftRenewalTimer;
  Timer? _liveDraftHistoryPreviewExpiryTimer;
  Timer? _catalogTimer;
  Future<void>? _catalogOperation;
  String? _catalogScope;
  bool _catalogRefreshScheduled = false;
  bool _catalogSyncing = false;
  String? _catalogErrorMessage;
  int _catalogRestoredCount = 0;

  CollaborationState _state = CollaborationState.localOnly;
  LocalCollaborationBinding? _binding;
  MembershipDto? _membership;
  List<MembershipDto> _members = const [];
  List<CollaborationInviteDto> _invites = const [];
  final Map<String, String?> _logCreatedBy = <String, String?>{};
  CollaborationInviteDto? _lastCreatedInvite;
  String? _deviceId;
  String? _errorCode;
  String? _errorMessage;
  String? _failedOperation;
  String _progressLabel = '';
  double? _progress;
  List<CollaborationConflict> _openConflicts = const [];
  bool _conflictsLoaded = false;
  bool _conflictsLoading = false;
  String? _resolvingConflictId;
  LiveDraftSnapshotDto? _liveDraftSnapshot;
  LiveDraftFieldsDto? _localLiveDraftFields;
  _AutomaticLiveDraftTimeMarker? _automaticLiveDraftTime;
  Set<String> _dirtyLiveDraftFields = const {};
  Map<String, int> _liveDraftBaseRevisions = const {};
  Map<String, LiveDraftLockDto> _ownedLiveDraftLocks = const {};
  List<LocalOfflineRecordDto> _offlineRecords = const [];
  LiveDraftHistoryPreviewDto? _liveDraftHistoryPreview;
  int _liveDraftHistoryReuseEpoch = 0;
  Set<String> _liveDraftHistoryReuseAffectedFields = const {};
  String? _lastLiveDraftHistoryReuseToken;
  bool _liveDraftHistoryPreviewUnavailable = false;
  int _liveDraftLocalEditRevision = 0;
  Map<String, int> _liveDraftLocalFieldEditRevisions = const {};
  int _liveDraftClientSeq = 0;
  bool _liveDraftLoading = false;
  String? _liveDraftErrorCode;
  String? _liveDraftErrorMessage;
  List<PublicShareDto> _publicShares = const [];
  PublicShareDto? _lastCreatedPublicShare;

  CollaborationState get state => _state;
  LocalCollaborationBinding? get binding => _binding;
  MembershipDto? get membership => _membership;
  List<MembershipDto> get members => _members;
  List<CollaborationInviteDto> get invites => _invites;
  CollaborationInviteDto? get lastCreatedInvite => _lastCreatedInvite;
  String? get deviceId => _deviceId;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;
  String? get failedOperation => _failedOperation;
  String get progressLabel => _progressLabel;
  double? get progress => _progress;
  List<CollaborationConflict> get openConflicts => _openConflicts;
  bool get conflictsLoading => _conflictsLoading;
  String? get resolvingConflictId => _resolvingConflictId;
  LiveDraftSnapshotDto? get liveDraftSnapshot => _liveDraftSnapshot;
  LiveDraftFieldsDto? get liveDraftFields =>
      _localLiveDraftFields ?? _liveDraftSnapshot?.draft.fields;
  LiveDraftFieldsDto? get liveDraftDisplayFields {
    final snapshot = liveDraftSnapshot;
    final fields = liveDraftFields;
    if (snapshot == null || fields == null || fields['time'].isEmpty) {
      return fields;
    }
    final timeRevision = snapshot.draft.fieldRevisions['time'] ?? 0;
    final timeIsDirty = _dirtyLiveDraftFields.contains('time');
    final marker = _automaticLiveDraftTime;
    final displayTime = projectLiveDraftTimeForDisplay(
      value: fields['time'],
      revision: timeRevision,
      locallyDirty: timeIsDirty,
      draftId: snapshot.draft.draftId,
      automaticDraftId: marker?.draftId,
      automaticDisplayMinute: marker?.displayMinute,
      automaticMaxRevision: marker?.maxTimeRevision,
    );
    return displayTime == fields['time']
        ? fields
        : fields.withField('time', displayTime);
  }

  List<LiveDraftLockDto> get liveDraftLocks =>
      _liveDraftSnapshot?.locks ?? const [];
  Map<String, LiveDraftLockDto> get ownedLiveDraftLocks =>
      Map.unmodifiable(_ownedLiveDraftLocks);
  bool isLiveDraftFieldDirty(String field) =>
      _dirtyLiveDraftFields.contains(field);
  LiveDraftHistoryPreviewDto? get liveDraftHistoryPreview {
    final preview = _liveDraftHistoryPreview;
    return preview != null && preview.expiresAt.isAfter(DateTime.now())
        ? preview
        : null;
  }

  bool get liveDraftHistoryPreviewOwnedHere =>
      liveDraftHistoryPreview?.deviceId == _deviceId;
  int get liveDraftHistoryReuseEpoch => _liveDraftHistoryReuseEpoch;
  Set<String> get liveDraftHistoryReuseAffectedFields =>
      _liveDraftHistoryReuseAffectedFields;
  List<LocalOfflineRecordDto> get offlineRecords => _offlineRecords;
  bool get liveDraftLoading => _liveDraftLoading;
  String? get liveDraftErrorCode => _liveDraftErrorCode;
  String? get liveDraftErrorMessage => _liveDraftErrorMessage;
  List<PublicShareDto> get publicShares => _publicShares;
  PublicShareDto? get lastCreatedPublicShare => _lastCreatedPublicShare;
  bool get isBusy => _operationInProgress;
  bool get catalogSyncing => _catalogSyncing;
  String? get catalogErrorMessage => _catalogErrorMessage;
  int get catalogRestoredCount => _catalogRestoredCount;
  bool get canJoinWithInvite {
    final currentBinding = binding;
    return currentBinding == null ||
        state == CollaborationState.revoked ||
        currentBinding.replicaState == 'revoked' ||
        currentBinding.revokedAt != null ||
        failedOperation == 'join';
  }

  bool get hasCurrentSessionBinding {
    final currentBinding = binding;
    return currentBinding != null &&
        currentBinding.sessionId == _sessions?.currentSessionId;
  }

  /// A direct conversion deliberately removes this device's synchronized
  /// replica. Only expose it after the serial synchronizer has caught up and
  /// every recoverable local operation is durably represented by the server.
  bool get canConvertCurrentSessionDirectly =>
      canSafelyConvertCollaborationSessionToLocal(
        hasCurrentBinding: hasCurrentSessionBinding,
        operationInProgress: _operationInProgress,
        state: _state,
        syncState: _syncState,
        hasOfflineRecords: _offlineRecords.isNotEmpty,
      );

  CollaborationSyncState? get syncState => _syncState;
  CollaborationTransportPhase get transportPhase =>
      _syncState?.transportPhase ?? CollaborationTransportPhase.stopped;
  int get lastAppliedSeq =>
      _syncState?.lastAppliedSeq ?? _binding?.lastAppliedSeq ?? 0;
  int get serverHeadSeq =>
      _syncState?.serverHeadSeq ?? _binding?.lastSeenHeadSeq ?? 0;
  int get pendingCount => _syncState?.pendingCount ?? 0;
  int get conflictCount =>
      _conflictsLoaded ? _openConflicts.length : _syncState?.conflictCount ?? 0;
  int get rejectedCount => _syncState?.rejectedCount ?? 0;
  DateTime? get lastSuccessfulSyncAt => _syncState?.lastSuccessfulSyncAt;
  DateTime? get nextRetryAt => _syncState?.nextRetryAt;
  String? get syncErrorCode => _syncState?.lastErrorCode;
  String? get syncErrorMessage => _syncState?.lastErrorMessage;
  bool get remoteCommitPendingLocalApply =>
      _syncState?.remoteCommitPendingLocalApply ?? false;
  bool get canonicalSessionClosed => _syncState?.sessionClosed ?? false;
  SessionRole? get effectiveRole => _syncState?.role ?? _membership?.role;
  bool get canEditCurrentSession =>
      !_operationInProgress &&
      _state == CollaborationState.ready &&
      (_syncState?.canEdit ?? false);
  bool get canResolveConflicts => _currentConflictIdentity() != null;
  bool get hasOpenSessionConflict {
    final sessionId = _binding?.sessionId;
    return sessionId != null &&
        _openConflicts.any(
          (conflict) =>
              conflict.entityType == CollaborationConflictEntityType.session &&
              conflict.entityId == sessionId,
        );
  }

  Set<String> get conflictedLogIds => Set.unmodifiable(
        _openConflicts
            .where(
              (conflict) =>
                  conflict.entityType == CollaborationConflictEntityType.log,
            )
            .map((conflict) => conflict.entityId),
      );

  bool canResolveConflictWith(
    CollaborationConflict conflict,
    CollaborationConflictResolution resolution,
  ) =>
      canResolveConflicts &&
      conflict.sessionId == _binding?.sessionId &&
      conflict.allowedResolutions.contains(resolution);

  bool get isOwner {
    final server = _server;
    final sessions = _sessions;
    final binding = _binding;
    final membership = _membership;
    return server != null &&
        sessions != null &&
        binding != null &&
        membership != null &&
        _state == CollaborationState.ready &&
        binding.replicaState == 'ready' &&
        sessions.currentSessionId == binding.sessionId &&
        server.isLoggedIn &&
        server.accountId == binding.accountId &&
        server.serverInfo?.serverInstanceId == binding.serverInstanceId &&
        membership.membershipId == binding.membershipId &&
        membership.sessionId == binding.sessionId &&
        membership.userId == binding.accountId &&
        membership.removedAt == null &&
        effectiveRole == SessionRole.owner;
  }

  bool get supportsInvites =>
      isOwner &&
      (_server?.serverInfo?.features.contains('collaborationInvites') ?? false);

  bool get supportsLiveDraft =>
      _server?.serverInfo?.features.contains(_liveDraftFeature) ?? false;

  bool get supportsSharedLogEditing => _sharedLogEditingSupported;

  bool get canViewLiveDraft {
    final binding = _binding;
    final membership = _membership;
    return supportsLiveDraft &&
        binding != null &&
        membership != null &&
        membership.removedAt == null &&
        binding.sessionId == _sessions?.currentSessionId &&
        binding.accountId == _server?.accountId;
  }

  bool get canEditLiveDraft =>
      !_operationInProgress &&
      canViewLiveDraft &&
      _state == CollaborationState.ready &&
      !canonicalSessionClosed &&
      _sessions?.currentSession?.status == 'active' &&
      (effectiveRole == SessionRole.owner ||
          effectiveRole == SessionRole.editor);

  bool get supportsPublicShareManagement =>
      isOwner &&
      _publicShareFeatures
          .difference(
            _server?.serverInfo?.features.toSet() ?? const <String>{},
          )
          .isEmpty;

  LiveDraftLockDto? lockForField(String field) {
    for (final lock in liveDraftLocks) {
      if (lock.field == field) return lock;
    }
    return null;
  }

  bool fieldLockedByAnotherUser(String field) {
    final lock = lockForField(field);
    final accountId = _server?.accountId;
    final deviceId = _deviceId;
    return lock != null &&
        (lock.userId != accountId || lock.deviceId != deviceId);
  }

  bool get readOnly => isCurrentSessionReadOnly;

  bool get isCurrentSessionReadOnly {
    final sessionId = _sessions?.currentSessionId;
    if (sessionId == null) return false;
    if (_publishingSessionId == sessionId) return true;
    if (_binding?.sessionId == sessionId) return !canEditCurrentSession;
    return _logs?.currentSessionReadOnly ?? false;
  }

  String? _logMutationBlockReason(LogEntry log) {
    final binding = _binding;
    final boundLog = binding != null && log.sessionId == binding.sessionId;
    return collaborationLogMutationBlockReason(
      collaborationBound: boundLog,
      canEditSession: canEditCurrentSession,
      sharedEditingSupported: supportsSharedLogEditing,
      accountId: _server?.accountId,
      authorshipKnown: _logCreatedBy.containsKey(log.id),
      createdBy: _logCreatedBy[log.id],
    );
  }

  void updateDependencies(
    ServerProvider server,
    SessionProvider sessions,
    LogProvider logs,
  ) {
    final sharedLogEditingSupported =
        server.serverInfo?.features.contains(_sharedLogEditingFeature) ?? false;
    final mutationPermissionsChanged =
        _sharedLogEditingSupported != sharedLogEditingSupported;
    _sharedLogEditingSupported = sharedLogEditingSupported;
    _server = server;
    _sessions = sessions;
    if (!identical(_logs, logs)) {
      _logs?.setLogMutationGuard(null);
      _logs = logs;
      logs.setLogMutationGuard(_logMutationBlockReason);
    }
    if (mutationPermissionsChanged) {
      logs.refreshMutationPermissions();
    }
    _updateCatalogScope(server, sessions);
    final key = '${server.contextRevision}|${server.serverUrl}|'
        '${server.accountId ?? ''}|'
        '${sessions.currentSessionId ?? ''}';
    if (_dependencyKey == key) return;
    _dependencyKey = key;
    _stateEpoch += 1;
    _stopSynchronization();
    _clearScopedState();
    _safeNotify();
    _scheduleRefresh();
  }

  void _updateCatalogScope(
    ServerProvider server,
    SessionProvider sessions,
  ) {
    final info = server.serverInfo;
    final accountId = server.accountId;
    final supported = info != null &&
        info.features.contains('sessionSnapshots') &&
        info.features.contains('sessionMembership');
    final nextScope = server.isLoggedIn &&
            !server.passwordChangeRequired &&
            accountId != null &&
            server.serverUrl.isNotEmpty &&
            supported
        ? '${info.serverInstanceId}|${server.serverUrl}|$accountId'
        : null;
    if (_catalogScope == nextScope) return;

    _catalogScope = nextScope;
    _catalogTimer?.cancel();
    _catalogTimer = null;
    _catalogErrorMessage = null;
    _catalogRestoredCount = 0;
    if (nextScope == null) {
      _catalogSyncing = false;
      return;
    }

    _scheduleCatalogRefresh();
    _catalogTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _scheduleCatalogRefresh(),
    );
  }

  void _scheduleCatalogRefresh() {
    if (_catalogRefreshScheduled || _catalogScope == null || _disposed) return;
    _catalogRefreshScheduled = true;
    scheduleMicrotask(() async {
      _catalogRefreshScheduled = false;
      try {
        await refreshAccountCollaborationSessions();
      } catch (error, stackTrace) {
        debugPrint(
            '[CollaborationCatalog] refresh failed: $error\n$stackTrace');
      }
    });
  }

  /// Installs collaboration replicas visible to this account but absent from
  /// the device. This never changes the current Session selection.
  Future<void> refreshAccountCollaborationSessions() {
    final current = _catalogOperation;
    if (current != null) return current;
    late final Future<void> operation;
    operation = _refreshAccountCollaborationSessions().whenComplete(() {
      if (identical(_catalogOperation, operation)) _catalogOperation = null;
    });
    _catalogOperation = operation;
    return operation;
  }

  Future<void> _refreshAccountCollaborationSessions() async {
    final scope = _catalogScope;
    final server = _server;
    final sessions = _sessions;
    final info = server?.serverInfo;
    final accountId = server?.accountId;
    if (scope == null ||
        server == null ||
        sessions == null ||
        info == null ||
        accountId == null ||
        !server.isLoggedIn ||
        server.passwordChangeRequired) {
      return;
    }
    final contextRevision = server.contextRevision;
    final serverUrl = server.serverUrl;
    final serverInstanceId = info.serverInstanceId;
    bool isCurrent() =>
        !_disposed &&
        _catalogScope == scope &&
        identical(_server, server) &&
        identical(_sessions, sessions) &&
        server.contextRevision == contextRevision &&
        server.serverUrl == serverUrl &&
        server.accountId == accountId &&
        server.serverInfo?.serverInstanceId == serverInstanceId;

    _catalogSyncing = true;
    _catalogErrorMessage = null;
    _safeNotify();
    try {
      final remoteSessions = await server.api.listSessions();
      if (!isCurrent()) return;
      final result = await restoreMissingCollaborationSessions(
        remoteSessions: remoteSessions,
        accountId: accountId,
        isCurrent: isCurrent,
        bindingExists: (sessionId) async {
          final json = await RustApi.getCollaborationBinding(
            serverInstanceId: serverInstanceId,
            accountId: accountId,
            sessionId: sessionId,
          );
          if (json == null) return false;
          final binding = LocalCollaborationBinding.fromJson(jsonDecode(json));
          return binding.serverInstanceId == serverInstanceId &&
              binding.accountId == accountId &&
              binding.sessionId == sessionId;
        },
        loadMembership: server.api.getMembership,
        loadSnapshot: (sessionId) => server.api.getSessionSnapshot(
          sessionId,
          includeDeleted: false,
        ),
        installSnapshot: ({required membership, required snapshot}) async {
          final bindingJson = await RustApi.installCollaborationSnapshot(
            requestJson: jsonEncode({
              'mode': 'join',
              'serverInstanceId': serverInstanceId,
              'serverOrigin': serverUrl,
              'accountId': accountId,
              'membership': membership.toJson(),
              'snapshot': snapshot.toJson(),
            }),
          );
          final installed = LocalCollaborationBinding.fromJson(
            jsonDecode(bindingJson),
          );
          if (installed.serverInstanceId != serverInstanceId ||
              installed.accountId != accountId ||
              installed.sessionId != snapshot.session.sessionId) {
            throw StateError('COLLABORATION_CATALOG_INSTALL_MISMATCH');
          }
        },
      );
      if (!isCurrent() || result.cancelled) return;
      _catalogRestoredCount = result.installedSessionIds.length;
      if (result.installedSessionIds.isNotEmpty) {
        sessions.notifyCollaborationCatalogChanged();
      }
      if (result.issues.isNotEmpty) {
        _catalogErrorMessage = result.issues
            .map((issue) => '${issue.title}: ${issue.error}')
            .join('\n');
      }
    } catch (error) {
      if (isCurrent()) _catalogErrorMessage = error.toString();
    } finally {
      if (isCurrent()) {
        _catalogSyncing = false;
        _safeNotify();
      }
    }
  }

  Future<void> refreshCurrentSession() async {
    if (_operationInProgress) return;
    _stopSynchronization();
    final refreshGeneration = ++_refreshGeneration;
    final epoch = _stateEpoch;
    final server = _server;
    final sessions = _sessions;
    final logs = _logs;
    if (server == null || sessions == null || logs == null) return;
    final serverContextRevision = server.contextRevision;
    final serverUrl = server.serverUrl;
    final accountId = server.accountId;
    final sessionId = sessions.currentSessionId;

    bool isCurrent() =>
        !_disposed &&
        !_operationInProgress &&
        refreshGeneration == _refreshGeneration &&
        epoch == _stateEpoch &&
        identical(server, _server) &&
        identical(sessions, _sessions) &&
        identical(logs, _logs) &&
        server.contextRevision == serverContextRevision &&
        server.serverUrl == serverUrl &&
        server.accountId == accountId &&
        sessions.currentSessionId == sessionId;

    final resolvedDeviceId = _deviceId ?? await RustApi.getOrCreateDeviceId();
    _deviceId = resolvedDeviceId;
    if (!isCurrent()) return;
    await server.setDeviceId(resolvedDeviceId);
    if (!isCurrent()) return;
    if (sessionId == null) {
      _clearScopedState();
      _state = CollaborationState.localOnly;
      _safeNotify();
      return;
    }

    final bindingJson = await RustApi.getSessionCollaborationBinding(
      sessionId: sessionId,
    );
    if (!isCurrent()) return;
    if (bindingJson == null) {
      if (_publishingSessionId == sessionId) {
        _publishingSessionId = null;
      }
      logs.setCollaborationReadOnly(sessionId, false);
      _clearScopedState();
      _state = CollaborationState.localOnly;
      _safeNotify();
      return;
    }

    var currentBinding = LocalCollaborationBinding.fromJson(
      jsonDecode(bindingJson),
    );
    _binding = currentBinding;
    _membership = null;
    _members = const [];
    _invites = const [];
    logs.setCollaborationReadOnly(sessionId, true);
    _state = _stateFromReplica(currentBinding.replicaState);
    if (currentBinding.replicaState == 'publishing') {
      _publishingSessionId = sessionId;
      _safeNotify();
      return;
    }
    if (currentBinding.replicaState == 'ready') {
      _state = CollaborationState.snapshotting;
    }
    _safeNotify();

    await logs.reloadForSession(sessionId, propagateErrors: true);
    if (!isCurrent()) return;

    if (!server.isLoggedIn || accountId != currentBinding.accountId) {
      _state = _stateFromReplica(currentBinding.replicaState);
      _safeNotify();
      return;
    }
    final api = server.api;
    try {
      // Keep the provider capability cache populated after a persisted login
      // is restored. Public-share and invite UI gates read ServerProvider's
      // cached serverInfo rather than this method's local value.
      final info = server.serverInfo ?? await server.checkServer();
      if (!isCurrent()) return;
      _requireFeatures(info, _refreshFeatures);
      if (info.serverInstanceId != currentBinding.serverInstanceId) {
        _state = _stateFromReplica(currentBinding.replicaState);
        _setError(
          'SERVER_IDENTITY_MISMATCH',
          '当前地址指向另一台服务器；本地副本保持只读',
        );
        _safeNotify();
        return;
      }
      final remoteMembership = await api.getMembership(sessionId);
      if (!isCurrent()) return;
      SessionSnapshotDto authorshipSnapshot;
      if (remoteMembership.version > currentBinding.membershipVersion ||
          remoteMembership.role != currentBinding.role) {
        final snapshot = await api.getSessionSnapshot(
          sessionId,
          includeDeleted: includeDeletedLogsForSnapshotInstall(
            CollaborationSnapshotInstallTarget.existingReplica,
          ),
        );
        if (!isCurrent()) return;
        authorshipSnapshot = snapshot;
        final refreshedBinding = await RustApi.installCollaborationSnapshot(
          requestJson: jsonEncode({
            'mode': 'join',
            'serverInstanceId': currentBinding.serverInstanceId,
            'serverOrigin': serverUrl,
            'accountId': currentBinding.accountId,
            'membership': remoteMembership.toJson(),
            'snapshot': snapshot.toJson(),
          }),
        );
        if (!isCurrent()) return;
        currentBinding = LocalCollaborationBinding.fromJson(
          jsonDecode(refreshedBinding),
        );
        await logs.reloadForSession(sessionId, propagateErrors: true);
        if (!isCurrent()) return;
      } else {
        authorshipSnapshot = await api.getSessionSnapshot(
          sessionId,
          includeDeleted: includeDeletedLogsForSnapshotInstall(
            CollaborationSnapshotInstallTarget.existingReplica,
          ),
        );
        if (!isCurrent()) return;
      }
      _adoptLogAuthorship(authorshipSnapshot.logs);
      _markUnpublishedLocalLogsOwned(logs, accountId);

      var members = const <MembershipDto>[];
      var invites = const <CollaborationInviteDto>[];
      if (remoteMembership.role == SessionRole.owner) {
        _requireFeatures(info, _memberManagementFeatures);
        final supportsInvites = info.features.contains('collaborationInvites');
        final results = await Future.wait<Object>([
          api.listMembers(sessionId),
          if (supportsInvites) api.listInvites(sessionId),
        ]);
        if (!isCurrent()) return;
        members = results[0] as List<MembershipDto>;
        if (supportsInvites) {
          invites = results[1] as List<CollaborationInviteDto>;
        }
      }

      _binding = currentBinding;
      _membership = remoteMembership;
      _members = members;
      _invites = invites;
      _publishingSessionId = null;
      _state = CollaborationState.ready;
      _clearError();
      if (_syncFeatures.difference(info.features.toSet()).isEmpty) {
        _startSynchronization(
          currentBinding,
          remoteMembership,
          sessionClosed: sessions.currentSession?.status != 'active',
        );
      } else {
        logs.setCollaborationReadOnly(sessionId, true);
        _setError(
          'SYNC_FEATURE_UNAVAILABLE',
          '服务器未完整启用 Stage 2 实时同步；本地副本保持只读',
        );
      }
      if (info.features.contains(_liveDraftFeature)) {
        await _serializeLiveDraft(
          () => _refreshLiveDraftForBinding(
            currentBinding,
            requestGeneration: ++_liveDraftGeneration,
            hydrateCache: true,
          ),
        );
        if (!isCurrent()) return;
      }
    } on ServerApiException catch (error) {
      if (!isCurrent()) return;
      if ({'MEMBERSHIP_REVOKED', 'SESSION_DELETED', 'NOT_FOUND'}
          .contains(error.code)) {
        await RustApi.markCollaborationRevoked(
          serverInstanceId: currentBinding.serverInstanceId,
          accountId: currentBinding.accountId,
          sessionId: sessionId,
        );
        if (!isCurrent()) return;
        _membership = null;
        _members = const [];
        _invites = const [];
        _lastCreatedInvite = null;
        _state = CollaborationState.revoked;
        _setError(error.code, error.message);
      } else {
        if (error.code == 'FORBIDDEN') {
          _membership = null;
          _members = const [];
          _invites = const [];
          _lastCreatedInvite = null;
        }
        _setError(error.code, error.message);
      }
    }
    _safeNotify();
  }

  Future<void> publishCurrentSession() async {
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final sessionId = sessions.currentSessionId;
    final session = sessions.currentSession;
    if (sessionId == null || session == null) {
      throw StateError('没有可发布的本地会话');
    }
    await _runOperation((context) async {
      _assertOperationCurrent(context);
      if (context.sessionId != sessionId) {
        throw const _OperationContextChanged();
      }
      final info = await _ensureServerCapabilities(
        context,
        _publishFeatures,
      );
      _assertOperationCurrent(context);
      _state = CollaborationState.publishing;
      _failedOperation = null;
      _publishingSessionId = sessionId;
      logs.setCollaborationReadOnly(sessionId, true);
      _setProgress('锁定并准备本地快照', 0.02);

      var leaseStarted = false;
      var leaseCreated = false;
      var remoteTouched = false;
      var snapshotInstalled = false;
      try {
        final publishJson = await RustApi.beginPublishSnapshot(
          serverInstanceId: info.serverInstanceId,
          serverOrigin: context.serverUrl,
          accountId: context.accountId,
          sessionId: sessionId,
        );
        leaseStarted = true;
        _assertOperationCurrent(context);
        final publish = Map<String, Object?>.from(
          jsonDecode(publishJson) as Map,
        );
        leaseCreated = publish['leaseCreated']! as bool;
        final publishSession = Map<String, Object?>.from(
          publish['session']! as Map,
        );
        final rawLogs = List<Object?>.from(publish['logs']! as List);
        final bootstrapLogs = rawLogs.map(_bootstrapLogFromJson).toList();
        final prepared = prepareCollaborationPublish(
          sessionId: sessionId,
          title: publishSession['title']! as String,
          logs: bootstrapLogs,
        );

        _setProgress('创建远端协作会话', 0.08);
        remoteTouched = true;
        final remoteSession = await context.api.putSession(
          sessionId: sessionId,
          title: prepared.title,
          idempotencyKey: _uuidV4(),
        );
        _assertOperationCurrent(context);
        if (remoteSession.status == 'initializing') {
          var uploaded = 0;
          for (final batch in prepared.batches) {
            await context.api.bootstrapLogs(
              sessionId: sessionId,
              items: batch,
              idempotencyKey: _uuidV4(),
            );
            _assertOperationCurrent(context);
            uploaded += batch.length;
            final fraction =
                bootstrapLogs.isEmpty ? 1.0 : uploaded / bootstrapLogs.length;
            _setProgress(
              '上传记录 $uploaded/${bootstrapLogs.length}',
              0.1 + fraction * 0.65,
            );
          }
          _setProgress('激活远端会话', 0.8);
          await context.api.activateSession(
            sessionId: sessionId,
            expectedLogCount: bootstrapLogs.length,
            idempotencyKey: _uuidV4(),
          );
          _assertOperationCurrent(context);
        } else if (remoteSession.status != 'active') {
          throw StateError('REMOTE_SESSION_STATE_INVALID');
        }

        _setProgress('安装服务端规范快照', 0.9);
        final remoteMembership = await context.api.getMembership(sessionId);
        _assertOperationCurrent(context);
        final snapshot = await context.api.getSessionSnapshot(
          sessionId,
          includeDeleted: includeDeletedLogsForSnapshotInstall(
            CollaborationSnapshotInstallTarget.publish,
          ),
        );
        _assertOperationCurrent(context);
        validatePublishedCollaborationSnapshot(
          sessionId: sessionId,
          title: prepared.title,
          localLogs: bootstrapLogs,
          snapshot: snapshot,
        );
        final bindingJson = await RustApi.installCollaborationSnapshot(
          requestJson: jsonEncode({
            'mode': 'publish',
            'serverInstanceId': info.serverInstanceId,
            'serverOrigin': context.serverUrl,
            'accountId': context.accountId,
            'membership': remoteMembership.toJson(),
            'snapshot': snapshot.toJson(),
          }),
        );
        snapshotInstalled = true;
        final installedBinding = LocalCollaborationBinding.fromJson(
          jsonDecode(bindingJson),
        );
        if (!_isOperationCurrent(context)) {
          _scheduleRefresh();
          return;
        }
        _binding = installedBinding;
        _membership = remoteMembership;
        _publishingSessionId = null;
        _state = CollaborationState.ready;
        _failedOperation = null;
        _clearError();

        String? refreshWarning;
        try {
          await sessions.switchToSession(sessionId);
          if (sessions.currentSessionId != sessionId) {
            throw StateError('SESSION_SWITCH_NOT_CONFIRMED');
          }
          await logs.reloadForSession(sessionId, propagateErrors: true);
          if (_isOperationCurrent(context)) {
            await _refreshManagementForOperation(
              context,
              installedBinding,
            );
          }
        } catch (error) {
          refreshWarning = error.toString();
        }
        if (!_isOperationCurrent(context)) return;
        _setProgress('发布完成', 1);
        if (refreshWarning != null) {
          _setError(
            'PUBLISH_COMPLETED_REFRESH_FAILED',
            '发布已经完成，但本地界面刷新失败：$refreshWarning',
          );
        }
      } catch (error) {
        if (snapshotInstalled) {
          if (_isOperationCurrent(context)) {
            _state = CollaborationState.ready;
            _failedOperation = null;
            _setError(
              'PUBLISH_COMPLETED_REFRESH_FAILED',
              '发布已经完成，但本地界面刷新失败：$error',
            );
          }
          return;
        }

        var safelyAborted = false;
        if (leaseStarted && leaseCreated && !remoteTouched) {
          try {
            await RustApi.abortPublish(
              serverInstanceId: info.serverInstanceId,
              accountId: context.accountId,
              sessionId: sessionId,
            );
            safelyAborted = true;
          } catch (_) {
            // Conservatively retain the lease if local rollback cannot be
            // proven. The Session must remain read-only in that case.
          }
        }
        if (_isOperationCurrent(context)) {
          if (safelyAborted || !leaseStarted) {
            if (_binding == null) {
              logs.setCollaborationReadOnly(sessionId, false);
            }
            _publishingSessionId = null;
          }
          _state = safelyAborted
              ? CollaborationState.localOnly
              : CollaborationState.failed;
          _failedOperation = safelyAborted ? null : 'publish';
        }
        rethrow;
      }
    });
  }

  Future<void> joinWithCode(String code) async {
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final normalizedCode = code
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll(RegExp(r'[IL]'), '1');
    if (!RegExp(r'^[0-9A-HJKMNP-TV-Z]{10}$').hasMatch(normalizedCode)) {
      throw ArgumentError('邀请码应为 10 位字符');
    }
    await _runOperation((context) async {
      final rejoiningRevokedBinding = binding != null && canJoinWithInvite;
      try {
        final info = await _ensureServerCapabilities(
          context,
          _joinFeatures,
        );
        _assertOperationCurrent(context);
        final resolvedDeviceId =
            _deviceId ?? await RustApi.getOrCreateDeviceId();
        _deviceId = resolvedDeviceId;
        _assertOperationCurrent(context);
        final pendingJoin = await _pendingJoinRequestId(
          serverInstanceId: info.serverInstanceId,
          accountId: context.accountId,
          credentialKind: 'code',
          credentialValue: normalizedCode,
        );
        _assertOperationCurrent(context);
        _failedOperation = 'join';
        _state = CollaborationState.joining;
        _setProgress('兑换邀请码', 0.2);
        final redeemed = await context.api.redeemInvite(
          RedeemInviteRequestDto(
            code: normalizedCode,
            joinRequestId: pendingJoin.id,
            deviceId: resolvedDeviceId,
          ),
        );
        _assertOperationCurrent(context);
        _state = CollaborationState.snapshotting;
        _setProgress('下载协作快照', 0.55);
        final existingBinding = await RustApi.getCollaborationBinding(
          serverInstanceId: info.serverInstanceId,
          accountId: context.accountId,
          sessionId: redeemed.session.sessionId,
        );
        _assertOperationCurrent(context);
        final isReinstall = existingBinding != null;
        if (isReinstall &&
            !info.features.contains('sessionSnapshotTombstones')) {
          throw StateError(
            'SYNC_FEATURE_UNAVAILABLE: '
            '服务器不支持含删除记录的安全副本重装',
          );
        }
        final snapshot = await context.api.getSessionSnapshot(
          redeemed.session.sessionId,
          includeDeleted: includeDeletedLogsForSnapshotInstall(
            isReinstall
                ? CollaborationSnapshotInstallTarget.existingReplica
                : CollaborationSnapshotInstallTarget.firstJoin,
          ),
        );
        _assertOperationCurrent(context);
        if (snapshot.session.sessionId != redeemed.session.sessionId ||
            redeemed.membership.sessionId != redeemed.session.sessionId ||
            redeemed.membership.userId != context.accountId) {
          throw StateError('JOIN_REMOTE_CONTENT_MISMATCH');
        }
        _setProgress('原子安装本地副本', 0.8);
        final bindingJson = await RustApi.installCollaborationSnapshot(
          requestJson: jsonEncode({
            'mode': 'join',
            'serverInstanceId': info.serverInstanceId,
            'serverOrigin': context.serverUrl,
            'accountId': context.accountId,
            'membership': redeemed.membership.toJson(),
            'snapshot': snapshot.toJson(),
          }),
        );
        final installedBinding = LocalCollaborationBinding.fromJson(
          jsonDecode(bindingJson),
        );
        if (!_isServerIdentityCurrent(context)) {
          _scheduleRefresh();
          throw StateError(
            'JOIN_COMMITTED_CONTEXT_CHANGED: '
            '协作副本已安全安装，但服务器或账号已切换；请切回原账号后重试以完成界面切换',
          );
        }
        final joinedSessionId = redeemed.session.sessionId;
        logs.setCollaborationReadOnly(joinedSessionId, true);
        await sessions.switchToSession(joinedSessionId);
        if (sessions.currentSessionId != joinedSessionId) {
          throw StateError('SESSION_SWITCH_NOT_CONFIRMED');
        }
        _adoptOperationSession(context, joinedSessionId);
        await logs.reloadForSession(
          joinedSessionId,
          propagateErrors: true,
        );
        _assertOperationCurrent(context);
        await _clearPendingJoin(pendingJoin.storageKey);
        _assertOperationCurrent(context);
        _binding = installedBinding;
        _membership = redeemed.membership;
        _members = const [];
        _invites = const [];
        _lastCreatedInvite = null;
        _state = CollaborationState.ready;
        _failedOperation = null;
        _setProgress('加入完成', 1);
        _clearError();
      } catch (error) {
        if (_isOperationCurrent(context)) {
          _state = rejoiningRevokedBinding
              ? CollaborationState.revoked
              : CollaborationState.failed;
          _failedOperation = 'join';
          _safeNotify();
        }
        rethrow;
      }
    });
  }

  Future<void> refreshLiveDraft() => _serializeLiveDraft(() async {
        final binding = _binding;
        if (binding == null || !canViewLiveDraft) return;
        final generation = ++_liveDraftGeneration;
        _liveDraftLoading = true;
        _safeNotify();
        await _refreshLiveDraftForBinding(
          binding,
          requestGeneration: generation,
          hydrateCache: false,
        );
      });

  void _observeLiveDraftPatchControlAck(JsonObject message) {
    final seq = message['clientSeq'];
    if (seq is! int) return;
    final pending = _pendingLiveDraftPatchAcks[seq];
    if (pending == null || pending.completer.isCompleted) return;
    final acknowledgement = matchLiveDraftPatchControlAck(
      message: message,
      sessionId: pending.sessionId,
      deviceId: pending.deviceId,
      clientSeq: pending.clientSeq,
      draftId: pending.draftId,
      expectedValues: pending.expectedValues,
      expectedRevisions: pending.expectedRevisions,
    );
    if (acknowledgement != null) {
      pending.completer.complete(acknowledgement);
    }
  }

  Future<void> _applyLiveDraftControl(JsonObject message) =>
      _serializeLiveDraft(() async {
        final context = _tryLiveDraftContext(requireEdit: false);
        final binding = context?.binding;
        if (context == null ||
            binding == null ||
            message['sessionId'] != binding.sessionId) {
          return;
        }

        Future<void> recoverFromCanonicalSnapshot() =>
            _refreshLiveDraftForBinding(
              binding,
              requestGeneration: ++_liveDraftGeneration,
              hydrateCache: false,
            );

        final terminalClear = message['type'] == 'liveDraft.cleared' &&
            message['terminal'] == true;
        var snapshot = _liveDraftSnapshot;
        var localFields = _localLiveDraftFields;
        if (snapshot == null || localFields == null) {
          bool contextIsCurrent() => _isLiveDraftContextCurrent(context);
          await _hydrateLiveDraftCacheIfEmpty(binding, contextIsCurrent);
          if (!contextIsCurrent()) return;
          await _loadLiveDraftOfflineRecords(binding, contextIsCurrent);
          if (!contextIsCurrent()) return;
          snapshot = _liveDraftSnapshot;
          localFields = _localLiveDraftFields;
        }
        if (snapshot == null || localFields == null) {
          if (terminalClear) {
            final nextDraft = LiveDraftDto.fromJson(message['nextDraft']);
            _liveDraftControlId(message, 'discardedDraftId');
            if (nextDraft.sessionId != binding.sessionId) {
              throw const FormatException(
                'Live-draft terminal clear contains another Session',
              );
            }
            Object? cacheError;
            try {
              await RustApi.clearCollaborationLiveDraftCache(
                serverInstanceId: binding.serverInstanceId,
                accountId: binding.accountId,
                sessionId: binding.sessionId,
              );
            } catch (error) {
              cacheError = error;
            }
            if (!_isLiveDraftContextCurrent(context)) return;
            _liveDraftGeneration += 1;
            _clearOwnedLiveDraftLocks();
            _liveDraftSnapshot = null;
            _localLiveDraftFields = null;
            _liveDraftHistoryPreview = null;
            _cancelLiveDraftHistoryPreviewExpiry();
            _automaticLiveDraftTime = null;
            _dirtyLiveDraftFields = const {};
            _liveDraftBaseRevisions = const {};
            _liveDraftClientSeq = 0;
            _liveDraftLoading = false;
            _clearLiveDraftError();
            if (cacheError != null) {
              _setLiveDraftError(
                'LIVE_DRAFT_CACHE_CLEAR_FAILED',
                cacheError.toString(),
              );
            }
            _safeNotify();
            return;
          }
          await recoverFromCanonicalSnapshot();
          return;
        }

        late LiveDraftControlProjection projection;
        try {
          projection = applyLiveDraftControlMessage(
            currentSnapshot: snapshot,
            currentLocalFields: localFields,
            currentDirtyFields: _dirtyLiveDraftFields,
            currentBaseRevisions: _liveDraftBaseRevisions,
            message: message,
          );
        } on FormatException {
          // A future or malformed control shape must not strand the display.
          // Recover once from the canonical endpoint instead of GETting after
          // every ordinary control message.
          await recoverFromCanonicalSnapshot();
          return;
        }

        var historyPreviewSpecified = false;
        var nextHistoryPreview = _liveDraftHistoryPreview;
        LiveDraftHistoryReuseDto? historyReuse;
        LiveDraftDto? historyReuseDraft;
        if (message['type'] == 'liveDraft.updated') {
          try {
            final incoming = LiveDraftDto.fromJson(message['draft']);
            final controlIsCurrent =
                incoming.draftId == snapshot.draft.draftId &&
                    incoming.version >= snapshot.draft.version;
            if (controlIsCurrent && message.containsKey('historyPreview')) {
              historyPreviewSpecified = true;
              final value = message['historyPreview'];
              if (value == null) {
                nextHistoryPreview = null;
              } else {
                final preview = LiveDraftHistoryPreviewDto.fromJson(value);
                if (preview.draftId != incoming.draftId ||
                    preview.callsign != incoming.fields['callsign']) {
                  throw const FormatException(
                    'History preview does not match the canonical draft',
                  );
                }
                nextHistoryPreview =
                    preview.expiresAt.isAfter(DateTime.now()) ? preview : null;
              }
            }
            final reuseValue = message['historyReuse'];
            if (controlIsCurrent && reuseValue != null) {
              final candidateReuse =
                  LiveDraftHistoryReuseDto.fromJson(reuseValue);
              final token = '${incoming.sessionId}:${incoming.draftId}:'
                  '${incoming.version}:${candidateReuse.previewId}:'
                  '${candidateReuse.candidateId}';
              if (_lastLiveDraftHistoryReuseToken != token) {
                historyReuse = candidateReuse;
                historyReuseDraft = incoming;
                projection = applyLiveDraftHistoryReuseProjection(
                  projection: projection,
                  canonicalDraft: incoming,
                  historyReuse: candidateReuse,
                  locks: _liveDraftControlLocks(message),
                );
                historyPreviewSpecified = true;
                nextHistoryPreview = null;
              }
            }
          } on FormatException {
            await recoverFromCanonicalSnapshot();
            return;
          }
        }
        final historyPreviewChanged = historyPreviewSpecified &&
            nextHistoryPreview?.previewId !=
                _liveDraftHistoryPreview?.previewId;
        if (!projection.changed &&
            !historyPreviewChanged &&
            historyReuse == null) {
          return;
        }

        final generationChanged =
            projection.snapshot.draft.draftId != snapshot.draft.draftId;
        var displacedLocalDraft = false;
        if (generationChanged) {
          final type = message['type'];
          LiveDraftFieldsDto? acceptedFields;
          if (type == 'liveDraft.committed') {
            final record = projection.snapshot.previousRecord;
            if (record != null) {
              acceptedFields = _liveDraftFieldsFromCommittedRecord(record);
            }
          }
          try {
            displacedLocalDraft =
                await _preserveCurrentDisplacedLiveDraftUntilStable(
              context: context,
              snapshot: snapshot,
              acceptedFields: acceptedFields,
            );
          } catch (error, stackTrace) {
            AppLogger.instance.log(
              AppLogLevel.error,
              'Could not preserve local input before a draft generation change',
              source: 'CollaborationProvider',
              error: error,
              stackTrace: stackTrace,
            );
            if (_isLiveDraftContextCurrent(context)) {
              _setLiveDraftError(
                'LIVE_DRAFT_LOCAL_RECOVERY_SAVE_FAILED',
                '草稿已在服务器切换，但本机输入暂时无法安全保存；已保留当前表单，请先不要关闭应用。',
              );
            }
            return;
          }
          if (!_isLiveDraftContextCurrent(context)) return;
        }

        final draftChanged =
            projection.snapshot.draft.draftId != snapshot.draft.draftId ||
                projection.snapshot.draft.version != snapshot.draft.version;
        _liveDraftSnapshot = projection.snapshot;
        _localLiveDraftFields = projection.localFields;
        _dirtyLiveDraftFields = projection.dirtyFields;
        _liveDraftBaseRevisions = projection.baseRevisions;
        if (historyPreviewSpecified) {
          _liveDraftHistoryPreview = nextHistoryPreview;
          if (nextHistoryPreview == null) {
            _cancelLiveDraftHistoryPreviewExpiry();
          } else {
            _scheduleLiveDraftHistoryPreviewExpiry(nextHistoryPreview);
          }
        }
        if (historyReuse != null && historyReuseDraft != null) {
          _recordLiveDraftHistoryReuse(historyReuse, historyReuseDraft);
        }
        if (generationChanged) {
          _liveDraftHistoryPreview = null;
          _cancelLiveDraftHistoryPreviewExpiry();
        }
        if (terminalClear) _automaticLiveDraftTime = null;
        _reconcileOwnedLiveDraftLocks(projection.snapshot.locks);
        if (displacedLocalDraft) {
          _setDisplacedLiveDraftWarning();
        } else {
          _clearLiveDraftError();
        }
        _safeNotify();
        if (draftChanged) {
          await _persistLiveDraftState(_guardFor(context));
        }
      });

  Future<LiveDraftLockDto> acquireLiveDraftField(String field) =>
      _serializeLiveDraft(() async {
        if (!liveDraftFieldNames.contains(field)) {
          throw ArgumentError.value(field, 'field');
        }
        final context = _requireLiveDraftContext(requireEdit: true);
        final current = _ownedLiveDraftLocks[field];
        if (current != null && current.expiresAt.isAfter(DateTime.now())) {
          return current;
        }
        final acquisition = await context.api.acquireLiveDraftLockWithDraft(
          sessionId: context.binding.sessionId,
          field: field,
          deviceId: context.deviceId,
        );
        _assertLiveDraftContextCurrent(context);
        final lock = acquisition.lock;
        late final ({bool revisionConflict, bool displacedLocalDraft}) adoption;
        try {
          adoption = await _adoptLiveDraftAtLockAcquisition(
            field,
            acquisition.draft,
            context,
          );
        } catch (error, stackTrace) {
          await _releaseTemporaryLiveDraftField(field, lock, context);
          Error.throwWithStackTrace(error, stackTrace);
        }
        _ownedLiveDraftLocks = {..._ownedLiveDraftLocks, field: lock};
        _replaceLiveDraftLock(lock);
        if (adoption.revisionConflict) {
          await _releaseTemporaryLiveDraftField(field, lock, context);
          throw _liveDraftLockAcquisitionConflict(
            field,
            acquisition.draft!,
          );
        }
        _ensureLiveDraftRenewalTimer();
        if (adoption.displacedLocalDraft) {
          _setDisplacedLiveDraftWarning();
        } else {
          _clearLiveDraftError();
        }
        _safeNotify();
        return lock;
      });

  Future<void> releaseLiveDraftField(String field) =>
      _serializeLiveDraft(() async {
        final lock = _ownedLiveDraftLocks[field];
        if (lock == null) return;
        final context = _tryLiveDraftContext(requireEdit: false);
        _ownedLiveDraftLocks = Map.of(_ownedLiveDraftLocks)..remove(field);
        _removeLiveDraftLock(lock.leaseId);
        if (_ownedLiveDraftLocks.isEmpty) {
          _liveDraftRenewalTimer?.cancel();
          _liveDraftRenewalTimer = null;
        }
        _safeNotify();
        if (context == null) return;
        try {
          await _releaseLiveDraftLockWithBoundedRetry(lock, context);
          if (!_isLiveDraftContextCurrent(context)) return;
        } on ServerApiException catch (error) {
          if (!_isLiveDraftContextCurrent(context)) return;
          if (!{'LIVE_DRAFT_LOCK_NOT_FOUND', 'LIVE_DRAFT_LOCK_EXPIRED'}
              .contains(error.code)) {
            _setLiveDraftError(error.code, error.message);
          }
        } on TimeoutException catch (error) {
          if (_isLiveDraftContextCurrent(context)) {
            _setLiveDraftError('LIVE_DRAFT_RELEASE_TIMEOUT', error.toString());
          }
        }
      });

  /// Releases an idle field lease only after re-checking serialized state.
  /// A keystroke can arrive after a successful flush but before its cleanup
  /// enters the queue; in that case the newly dirty field keeps the lease.
  Future<void> releaseLiveDraftFieldIfClean(
    String field, {
    String? expectedLeaseId,
  }) =>
      _serializeLiveDraft(() async {
        final lock = _ownedLiveDraftLocks[field];
        if (!canReleaseIdleLiveDraftLease(
          fieldDirty: _dirtyLiveDraftFields.contains(field),
          currentLock: lock,
          expectedLeaseId: expectedLeaseId,
        )) {
          return;
        }
        final releasableLock = lock!;
        final context = _tryLiveDraftContext(requireEdit: false);
        _ownedLiveDraftLocks = Map.of(_ownedLiveDraftLocks)..remove(field);
        _removeLiveDraftLock(releasableLock.leaseId);
        if (_ownedLiveDraftLocks.isEmpty) {
          _liveDraftRenewalTimer?.cancel();
          _liveDraftRenewalTimer = null;
        }
        _safeNotify();
        if (context == null) return;
        try {
          await _releaseLiveDraftLockWithBoundedRetry(
            releasableLock,
            context,
          );
        } on ServerApiException catch (error) {
          if (!_isLiveDraftContextCurrent(context)) return;
          if (!{'LIVE_DRAFT_LOCK_NOT_FOUND', 'LIVE_DRAFT_LOCK_EXPIRED'}
              .contains(error.code)) {
            _setLiveDraftError(error.code, error.message);
          }
        } on TimeoutException catch (error) {
          if (_isLiveDraftContextCurrent(context)) {
            _setLiveDraftError('LIVE_DRAFT_RELEASE_TIMEOUT', error.toString());
          }
        }
      });

  /// Stages the latest local value immediately without waiting for the
  /// collaboration round trip. The form calls this for every local edit, then
  /// separately debounces [flushLiveDraftField].
  void _markLiveDraftLocalFieldsEdited(Iterable<String> fields) {
    final editedFields = fields.where(liveDraftFieldNames.contains).toSet();
    if (editedFields.isEmpty) return;
    _liveDraftLocalEditRevision += 1;
    final revision = _liveDraftLocalEditRevision;
    _liveDraftLocalFieldEditRevisions = {
      ..._liveDraftLocalFieldEditRevisions,
      for (final field in editedFields) field: revision,
    };
  }

  void stageLiveDraftField(String field, String value) {
    if (!liveDraftFieldNames.contains(field)) {
      throw ArgumentError.value(field, 'field');
    }
    if (!canEditLiveDraft) {
      throw StateError('LIVE_DRAFT_READ_ONLY');
    }
    final normalizedValue =
        field == 'time' ? _normalizeLiveDraftTime(value) : value;
    final current = liveDraftFields ?? LiveDraftFieldsDto.empty();
    if (current[field] == normalizedValue &&
        !_dirtyLiveDraftFields.contains(field)) {
      return;
    }
    _localLiveDraftFields = current.withField(field, normalizedValue);
    _markLiveDraftLocalFieldsEdited([field]);
    final canonicalValue = _liveDraftSnapshot?.draft.fields[field] ?? '';
    if (normalizedValue == canonicalValue) {
      _dirtyLiveDraftFields = Set.of(_dirtyLiveDraftFields)..remove(field);
      _liveDraftBaseRevisions = Map.of(_liveDraftBaseRevisions)..remove(field);
    } else if (!_dirtyLiveDraftFields.contains(field)) {
      _liveDraftBaseRevisions = {
        ..._liveDraftBaseRevisions,
        field: _liveDraftSnapshot?.draft.fieldRevisions[field] ?? 0,
      };
      _dirtyLiveDraftFields = {..._dirtyLiveDraftFields, field};
    } else {
      _dirtyLiveDraftFields = {..._dirtyLiveDraftFields, field};
    }
    _safeNotify();
  }

  Future<void> updateLiveDraftField(String field, String value) {
    try {
      stageLiveDraftField(field, value);
    } catch (error, stackTrace) {
      return Future<void>.error(error, stackTrace);
    }
    return flushLiveDraftField(field);
  }

  /// Flushes the most recent staged value. Repeated calls for one field share
  /// one pending batch; edits made while a PATCH is in flight are folded into
  /// the next PATCH instead of creating an unbounded high-latency queue.
  Future<void> flushLiveDraftField(String field) {
    if (!liveDraftFieldNames.contains(field)) {
      return Future<void>.error(ArgumentError.value(field, 'field'));
    }
    if (!_dirtyLiveDraftFields.contains(field)) {
      return Future<void>.value();
    }
    final existing = _liveDraftFieldFlushBatches[field];
    if (existing != null && existing.epoch == _stateEpoch) {
      return existing.completer.future;
    }
    if (existing != null && !existing.completer.isCompleted) {
      existing.completer.completeError(
        StateError('LIVE_DRAFT_CONTEXT_CHANGED'),
      );
    }
    final batch = _LiveDraftFieldFlushBatch(_stateEpoch);
    _liveDraftFieldFlushBatches[field] = batch;
    _scheduleLiveDraftFieldFlush(field, batch);
    return batch.completer.future;
  }

  void _scheduleLiveDraftFieldFlush(
    String field,
    _LiveDraftFieldFlushBatch batch,
  ) {
    final operation = _serializeLiveDraft(() => _flushLiveDraftField(field));
    unawaited(
      operation.then(
        (_) {
          if (!identical(_liveDraftFieldFlushBatches[field], batch)) {
            if (!batch.completer.isCompleted) {
              batch.completer.completeError(
                StateError('LIVE_DRAFT_CONTEXT_CHANGED'),
              );
            }
            return;
          }
          if (batch.epoch != _stateEpoch) {
            _liveDraftFieldFlushBatches.remove(field);
            if (!batch.completer.isCompleted) {
              batch.completer.completeError(
                StateError('LIVE_DRAFT_CONTEXT_CHANGED'),
              );
            }
            return;
          }
          if (_dirtyLiveDraftFields.contains(field)) {
            // Append the next latest-value PATCH behind controls and work that
            // arrived while this request was in flight, preventing starvation.
            _scheduleLiveDraftFieldFlush(field, batch);
            return;
          }
          _liveDraftFieldFlushBatches.remove(field);
          if (!batch.completer.isCompleted) batch.completer.complete();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_liveDraftFieldFlushBatches[field], batch)) {
            _liveDraftFieldFlushBatches.remove(field);
          }
          if (!batch.completer.isCompleted) {
            batch.completer.completeError(error, stackTrace);
          }
        },
      ),
    );
  }

  Future<void> updateLiveDraftFieldsAtomically(Map<String, String> updates) {
    return _queueLiveDraftFieldsAtomicUpdate(
      updates,
      retryRevisionConflicts: true,
    );
  }

  /// Shows a multi-field update locally first, then synchronizes it with one
  /// atomic server PATCH. If synchronization fails, only values from this
  /// batch that have not changed again are rolled back.
  Future<void> updateLiveDraftFieldsOptimistically(
    Map<String, String> updates,
  ) {
    return _queueLiveDraftFieldsAtomicUpdate(
      updates,
      retryRevisionConflicts: true,
      optimistic: true,
    );
  }

  /// Publishes the local callsign-history dropdown so other scribes can see
  /// the same candidates. Unsupported older servers return `null`; callers
  /// should keep their local dropdown and use the legacy atomic reuse path.
  Future<LiveDraftHistoryPreviewDto?> publishLiveDraftHistoryPreview({
    required String callsign,
    required List<LiveDraftHistoryCandidateDto> candidates,
  }) =>
      _serializeLiveDraft(() async {
        if (_liveDraftHistoryPreviewUnavailable || candidates.isEmpty) {
          return null;
        }
        final context = _requireLiveDraftContext(requireEdit: true);
        final snapshot = _liveDraftSnapshot;
        final normalizedCallsign = callsign.trim().toUpperCase();
        if (snapshot == null ||
            normalizedCallsign.isEmpty ||
            snapshot.draft.fields['callsign'] != normalizedCallsign ||
            liveDraftFields?['callsign'].trim().toUpperCase() !=
                normalizedCallsign) {
          return null;
        }
        var lock = _ownedLiveDraftLocks['callsign'];
        if (lock == null || !lock.expiresAt.isAfter(DateTime.now())) {
          lock = await _acquireLiveDraftFieldInternal('callsign', context);
          _assertLiveDraftContextCurrent(context);
          final refreshedSnapshot = _liveDraftSnapshot;
          if (refreshedSnapshot == null ||
              refreshedSnapshot.draft.draftId != snapshot.draft.draftId ||
              refreshedSnapshot.draft.fields['callsign'] !=
                  normalizedCallsign ||
              liveDraftFields?['callsign'].trim().toUpperCase() !=
                  normalizedCallsign) {
            if (!_dirtyLiveDraftFields.contains('callsign')) {
              await _releaseTemporaryLiveDraftField(
                'callsign',
                lock,
                context,
              );
            }
            return null;
          }
        }
        try {
          final result = await context.api.publishLiveDraftHistoryPreview(
            sessionId: context.binding.sessionId,
            deviceId: context.deviceId,
            leaseId: lock.leaseId,
            draftId: snapshot.draft.draftId,
            callsign: normalizedCallsign,
            candidates: candidates,
          );
          _assertLiveDraftContextCurrent(context);
          final current = _liveDraftSnapshot;
          final currentFields = _localLiveDraftFields;
          if (current == null ||
              currentFields == null ||
              current.draft.draftId != result.draft.draftId ||
              currentFields['callsign'].trim().toUpperCase() !=
                  normalizedCallsign) {
            try {
              await context.api.clearLiveDraftHistoryPreview(
                sessionId: context.binding.sessionId,
                deviceId: context.deviceId,
                previewId: result.historyPreview.previewId,
              );
            } catch (_) {
              // A changed local query must not be blocked by cleanup failure.
            }
            if (!_dirtyLiveDraftFields.contains('callsign')) {
              await _releaseTemporaryLiveDraftField(
                'callsign',
                lock,
                context,
              );
            }
            return null;
          }
          final canonical = current.draft.version > result.draft.version
              ? current.draft
              : result.draft;
          _liveDraftSnapshot = LiveDraftSnapshotDto(
            draft: canonical,
            locks: result.locks,
            currentOrdinal: current.currentOrdinal,
            totalRecords: current.totalRecords,
            previousRecord: current.previousRecord,
          );
          _localLiveDraftFields = LiveDraftFieldsDto({
            for (final field in liveDraftFieldNames)
              field: _dirtyLiveDraftFields.contains(field)
                  ? currentFields[field]
                  : canonical.fields[field],
          });
          _liveDraftHistoryPreview = result.historyPreview;
          _scheduleLiveDraftHistoryPreviewExpiry(result.historyPreview);
          _reconcileOwnedLiveDraftLocks(result.locks);
          _safeNotify();
          return result.historyPreview;
        } on ServerApiException catch (error) {
          if (_isUnsupportedLiveDraftHistoryPreviewError(error)) {
            _liveDraftHistoryPreviewUnavailable = true;
            if (!_dirtyLiveDraftFields.contains('callsign')) {
              await _releaseTemporaryLiveDraftField(
                'callsign',
                lock,
                context,
              );
            }
            return null;
          }
          if (error.code == 'LIVE_DRAFT_HISTORY_PREVIEW_STALE') {
            if (!_dirtyLiveDraftFields.contains('callsign')) {
              await _releaseTemporaryLiveDraftField(
                'callsign',
                lock,
                context,
              );
            }
            return null;
          }
          if (!_dirtyLiveDraftFields.contains('callsign')) {
            await _releaseTemporaryLiveDraftField('callsign', lock, context);
          }
          rethrow;
        } catch (error, stackTrace) {
          if (!_dirtyLiveDraftFields.contains('callsign')) {
            await _releaseTemporaryLiveDraftField('callsign', lock, context);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      });

  Future<void> clearLiveDraftHistoryPreview({String? expectedPreviewId}) =>
      _serializeLiveDraft(() async {
        final preview = _liveDraftHistoryPreview;
        if (preview == null ||
            preview.deviceId != _deviceId ||
            (expectedPreviewId != null &&
                preview.previewId != expectedPreviewId)) {
          return;
        }
        _liveDraftHistoryPreview = null;
        _cancelLiveDraftHistoryPreviewExpiry();
        _safeNotify();
        if (_liveDraftHistoryPreviewUnavailable) return;
        final context = _tryLiveDraftContext(requireEdit: false);
        if (context == null) return;
        try {
          await context.api.clearLiveDraftHistoryPreview(
            sessionId: context.binding.sessionId,
            deviceId: context.deviceId,
            previewId: preview.previewId,
          );
        } on ServerApiException catch (error) {
          if (_isUnsupportedLiveDraftHistoryPreviewError(error)) {
            _liveDraftHistoryPreviewUnavailable = true;
            return;
          }
          if (error.code == 'LIVE_DRAFT_HISTORY_PREVIEW_STALE') return;
          rethrow;
        }
      });

  /// Selects a preview candidate through the server's atomic history-reuse
  /// route. Returns false when an old server or an expired preview requires the
  /// caller to fall back to the legacy optimistic multi-field PATCH.
  Future<bool> selectLiveDraftHistoryCandidate({
    required String previewId,
    required String candidateId,
  }) =>
      _serializeLiveDraft(() async {
        if (_liveDraftHistoryPreviewUnavailable) return false;
        final preview = _liveDraftHistoryPreview;
        if (preview == null ||
            preview.previewId != previewId ||
            preview.deviceId != _deviceId ||
            !preview.candidates.any(
              (candidate) => candidate.candidateId == candidateId,
            )) {
          return false;
        }
        final context = _requireLiveDraftContext(requireEdit: true);
        final lock = _ownedLiveDraftLocks['callsign'];
        final snapshot = _liveDraftSnapshot;
        final localFields = _localLiveDraftFields;
        if (lock == null ||
            !lock.expiresAt.isAfter(DateTime.now()) ||
            snapshot == null ||
            localFields == null ||
            snapshot.draft.draftId != preview.draftId) {
          return false;
        }
        try {
          final mutationId = _uuidV4();
          late LiveDraftHistoryReuseResultDto result;
          for (var attempt = 1;; attempt += 1) {
            try {
              result = await context.api.selectLiveDraftHistoryCandidate(
                sessionId: context.binding.sessionId,
                previewId: previewId,
                deviceId: context.deviceId,
                leaseId: lock.leaseId,
                candidateId: candidateId,
                idempotencyKey: mutationId,
              );
              break;
            } on ServerApiException catch (error) {
              if (!error.retryable || attempt >= 2) rethrow;
              await Future<void>.delayed(const Duration(milliseconds: 120));
              _assertLiveDraftContextCurrent(context);
            }
          }
          _assertLiveDraftContextCurrent(context);
          final projected = applyLiveDraftHistoryReuseProjection(
            projection: LiveDraftControlProjection(
              snapshot: snapshot,
              localFields: localFields,
              dirtyFields: _dirtyLiveDraftFields,
              baseRevisions: _liveDraftBaseRevisions,
              changed: false,
            ),
            canonicalDraft: result.draft,
            historyReuse: result.historyReuse,
            locks: result.locks,
          );
          _liveDraftSnapshot = projected.snapshot;
          _localLiveDraftFields = projected.localFields;
          _dirtyLiveDraftFields = projected.dirtyFields;
          _liveDraftBaseRevisions = projected.baseRevisions;
          _liveDraftHistoryPreview = null;
          _cancelLiveDraftHistoryPreviewExpiry();
          _recordLiveDraftHistoryReuse(result.historyReuse, result.draft);
          _reconcileOwnedLiveDraftLocks(result.locks);
          _clearLiveDraftError();
          _safeNotify();
          await _persistLiveDraftState(_guardFor(context));
          return true;
        } on ServerApiException catch (error) {
          if ({
            'LIVE_DRAFT_HISTORY_PREVIEW_STALE',
            'LIVE_DRAFT_HISTORY_CANDIDATE_NOT_FOUND',
          }.contains(error.code)) {
            _liveDraftHistoryPreview = null;
            _cancelLiveDraftHistoryPreviewExpiry();
            _safeNotify();
            return false;
          }
          if (_isUnsupportedLiveDraftHistoryPreviewError(error)) {
            _liveDraftHistoryPreviewUnavailable = true;
            _liveDraftHistoryPreview = null;
            _cancelLiveDraftHistoryPreviewExpiry();
            _safeNotify();
            return false;
          }
          rethrow;
        }
      });

  /// Applies a version-checked multi-field update exactly once. This is used
  /// for externally generated suggestions: a conflict must return to review
  /// instead of rebasing the same values over a collaborator's newer edit.
  Future<void> updateLiveDraftFieldsStrict(
    Map<String, String> updates, {
    required String expectedDraftId,
    required Map<String, String> expectedValues,
    required Map<String, int> expectedRevisions,
  }) {
    if (!updates.keys.every(expectedValues.containsKey) ||
        !updates.keys.every(expectedRevisions.containsKey)) {
      return Future<void>.error(
        ArgumentError('strict updates require an expected value and revision'),
      );
    }
    return _queueLiveDraftFieldsAtomicUpdate(
      updates,
      retryRevisionConflicts: false,
      expectedDraftId: expectedDraftId,
      expectedValues: Map.unmodifiable(expectedValues),
      expectedRevisions: Map.unmodifiable(expectedRevisions),
    );
  }

  Future<void> _queueLiveDraftFieldsAtomicUpdate(
    Map<String, String> updates, {
    required bool retryRevisionConflicts,
    String? expectedDraftId,
    Map<String, String>? expectedValues,
    Map<String, int>? expectedRevisions,
    bool optimistic = false,
  }) {
    if (updates.isEmpty) return Future<void>.value();
    for (final field in updates.keys) {
      if (!liveDraftFieldNames.contains(field)) {
        return Future<void>.error(ArgumentError.value(field, 'updates'));
      }
    }
    if (!canEditLiveDraft) {
      return Future<void>.error(StateError('LIVE_DRAFT_READ_ONLY'));
    }
    if (_operationInProgress) {
      return Future<void>.error(
        StateError('COLLABORATION_OPERATION_IN_PROGRESS'),
      );
    }
    final requested = Map<String, String>.unmodifiable({
      for (final entry in updates.entries)
        entry.key: optimistic && entry.key == 'time'
            ? _normalizeLiveDraftTime(entry.value)
            : entry.value,
    });
    _OptimisticLiveDraftRollback? rollback;
    if (optimistic) {
      final snapshot = _liveDraftSnapshot;
      final local = _localLiveDraftFields;
      if (snapshot == null || local == null) {
        return Future<void>.error(StateError('LIVE_DRAFT_NOT_LOADED'));
      }
      final beforeDirtyFields = Set<String>.of(_dirtyLiveDraftFields);
      final beforeBaseRevisions = Map<String, int>.of(
        _liveDraftBaseRevisions,
      );
      final staged = stageOptimisticLiveDraftAtomicPatch(
        canonicalDraft: snapshot.draft,
        localFields: local,
        dirtyFields: beforeDirtyFields,
        baseRevisions: beforeBaseRevisions,
        updates: requested,
      );
      rollback = _OptimisticLiveDraftRollback(
        draftId: snapshot.draft.draftId,
        beforeLocalFields: local,
        beforeDirtyFields: beforeDirtyFields,
        beforeBaseRevisions: beforeBaseRevisions,
        stagedValues: requested,
      );
      _localLiveDraftFields = staged.localFields;
      _dirtyLiveDraftFields = staged.dirtyFields;
      _liveDraftBaseRevisions = staged.baseRevisions;
      _markLiveDraftLocalFieldsEdited(requested.keys);
      _safeNotify();
    }
    return _serializeLiveDraft(
      () async {
        try {
          await _updateLiveDraftFieldsAtomically(
            requested,
            retryRevisionConflicts: retryRevisionConflicts,
            expectedDraftId: expectedDraftId,
            expectedValues: expectedValues,
            expectedRevisions: expectedRevisions,
          );
        } catch (error, stackTrace) {
          if (rollback != null) {
            await _rollbackOptimisticLiveDraftUpdate(rollback);
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
    );
  }

  Future<void> _rollbackOptimisticLiveDraftUpdate(
    _OptimisticLiveDraftRollback rollback,
  ) async {
    final snapshot = _liveDraftSnapshot;
    final local = _localLiveDraftFields;
    if (snapshot == null ||
        local == null ||
        snapshot.draft.draftId != rollback.draftId) {
      return;
    }
    final hasUnchangedStagedValue = rollback.stagedValues.entries.any(
      (entry) => local[entry.key] == entry.value,
    );
    if (!hasUnchangedStagedValue) return;
    final restored = rollbackOptimisticLiveDraftAtomicPatch(
      canonicalDraft: snapshot.draft,
      beforeLocalFields: rollback.beforeLocalFields,
      beforeDirtyFields: rollback.beforeDirtyFields,
      beforeBaseRevisions: rollback.beforeBaseRevisions,
      currentLocalFields: local,
      currentDirtyFields: _dirtyLiveDraftFields,
      currentBaseRevisions: _liveDraftBaseRevisions,
      stagedValues: rollback.stagedValues,
    );
    _localLiveDraftFields = restored.localFields;
    _dirtyLiveDraftFields = restored.dirtyFields;
    _liveDraftBaseRevisions = restored.baseRevisions;
    _safeNotify();
    final context = _tryLiveDraftContext(requireEdit: false);
    if (context == null) return;
    try {
      await _persistLiveDraftState(_guardFor(context));
    } catch (_) {
      // The original synchronization error remains the actionable failure.
    }
  }

  void beginAutomaticLiveDraftTime(String value) {
    final snapshot = liveDraftSnapshot;
    final displayMinute = formatLogTimeForDisplay(value);
    if (snapshot == null || displayMinute.isEmpty) {
      cancelAutomaticLiveDraftTime();
      return;
    }
    _automaticLiveDraftTime = _AutomaticLiveDraftTimeMarker(
      draftId: snapshot.draft.draftId,
      displayMinute: displayMinute,
      maxTimeRevision: snapshot.draft.fieldRevisions['time'] ?? 0,
    );
    _safeNotify();
    _scheduleAutomaticLiveDraftTimePersistence();
  }

  void confirmAutomaticLiveDraftTime() {
    final marker = _automaticLiveDraftTime;
    final snapshot = liveDraftSnapshot;
    final fields = liveDraftFields;
    if (marker == null ||
        snapshot == null ||
        fields == null ||
        marker.draftId != snapshot.draft.draftId ||
        marker.displayMinute != formatLogTimeForDisplay(fields['time'])) {
      return;
    }
    _automaticLiveDraftTime = _AutomaticLiveDraftTimeMarker(
      draftId: marker.draftId,
      displayMinute: marker.displayMinute,
      maxTimeRevision: max(
        marker.maxTimeRevision,
        snapshot.draft.fieldRevisions['time'] ?? 0,
      ),
    );
    _safeNotify();
    _scheduleAutomaticLiveDraftTimePersistence();
  }

  void completeAutomaticLiveDraftTime(
    LiveDraftCommitDisposition disposition,
  ) {
    if (_automaticLiveDraftTime == null ||
        disposition == LiveDraftCommitDisposition.queuedOffline) {
      return;
    }
    // A committed record creates a new generation. Its revision-zero time is
    // already projected as empty for legacy servers; carrying the old
    // generation marker forward could hide a legitimate same-minute edit.
    _automaticLiveDraftTime = null;
    _safeNotify();
    _scheduleAutomaticLiveDraftTimePersistence();
  }

  void cancelAutomaticLiveDraftTime() {
    if (_automaticLiveDraftTime == null) return;
    _automaticLiveDraftTime = null;
    _safeNotify();
    _scheduleAutomaticLiveDraftTimePersistence();
  }

  void _scheduleAutomaticLiveDraftTimePersistence() {
    _runLiveDraftInBackground(
      _serializeLiveDraft(() async {
        final guard = _tryLiveDraftGuard();
        if (guard == null) return;
        await _persistLiveDraftState(guard);
      }),
    );
  }

  Future<LiveDraftCommitDisposition> commitCurrentLiveDraft() =>
      _serializeLiveDraft(() async {
        final context = _requireLiveDraftContext(requireEdit: true);
        final initialSnapshot = _liveDraftSnapshot;
        final initialFields = liveDraftFields;
        if (initialSnapshot == null || initialFields == null) {
          throw StateError('LIVE_DRAFT_NOT_LOADED');
        }
        final mutationId = _uuidV4();
        try {
          await _flushDirtyLiveDraftFields();
          _assertLiveDraftContextCurrent(context);
        } on ServerApiException catch (error) {
          await _releaseOwnedLiveDraftFieldsAfterFailure(
            _ownedLiveDraftLocks.keys.toList(growable: false),
            context,
          );
          _assertLiveDraftContextCurrent(context);
          if (!error.retryable) rethrow;
          final queued = await _queueOfflineRecord(
            context,
            mutationId: mutationId,
            snapshot: initialSnapshot,
            fields: initialFields,
          );
          _offlineRecords = [..._offlineRecords, queued];
          _localLiveDraftFields =
              resetLiveDraftFieldsAfterCommit(initialFields);
          _dirtyLiveDraftFields = {
            for (final field in liveDraftFieldNames)
              if (_localLiveDraftFields![field] !=
                  initialSnapshot.draft.fields[field])
                field,
          };
          _liveDraftBaseRevisions = {
            for (final field in _dirtyLiveDraftFields)
              field: initialSnapshot.draft.fieldRevisions[field] ?? 0,
          };
          _clearOwnedLiveDraftLocks();
          _setLiveDraftError(
            'OFFLINE_RECORD_QUEUED',
            '网络不可用，记录已保存到本机，恢复连接后将检查是否可安全提交',
          );
          _safeNotify();
          await _persistLiveDraftState(_guardFor(context));
          return LiveDraftCommitDisposition.queuedOffline;
        } catch (error, stackTrace) {
          await _releaseOwnedLiveDraftFieldsAfterFailure(
            _ownedLiveDraftLocks.keys.toList(growable: false),
            context,
          );
          Error.throwWithStackTrace(error, stackTrace);
        }
        final loadedCanonical = _liveDraftSnapshot;
        final loadedFields = liveDraftFields;
        if (loadedCanonical == null || loadedFields == null) {
          throw StateError('LIVE_DRAFT_NOT_LOADED');
        }
        var canonical = loadedCanonical;
        var fields = loadedFields;
        final required = ['time', 'controller', 'callsign']
            .where((field) => fields[field].trim().isEmpty)
            .toList(growable: false);
        if (required.isNotEmpty) {
          await _releaseOwnedLiveDraftFieldsAfterFailure(
            _ownedLiveDraftLocks.keys.toList(growable: false),
            context,
          );
          throw StateError('LIVE_DRAFT_INCOMPLETE:${required.join(',')}');
        }
        try {
          final logs = _logs;
          if (logs != null &&
              logs.currentSessionId != context.binding.sessionId) {
            await logs.reloadForSession(
              context.binding.sessionId,
              propagateErrors: true,
            );
            _assertLiveDraftContextCurrent(context);
            if (logs.currentSessionId != context.binding.sessionId) {
              throw StateError('LIVE_DRAFT_LOG_CONTEXT_CHANGED');
            }
          }
          final committed = await executeLiveDraftCommitWithRaceRecovery(
            attempt: (_) => context.api.commitLiveDraft(
              sessionId: context.binding.sessionId,
              deviceId: context.deviceId,
              expectedDraftVersion: canonical.draft.version,
              syncId: mutationId,
              idempotencyKey: mutationId,
            ),
            recover: (error, attempt) async {
              // A delayed WebSocket control can leave an otherwise idle
              // device one version behind at the instant Save is pressed. A
              // collaborator's final field PATCH can also arrive just before
              // its lease-release request on a high-RTT link. Give that short
              // release window time to settle, then rebase and retry the same
              // idempotent commit instead of making the user press Save again.
              if (error.code == 'LIVE_DRAFT_BUSY') {
                await Future<void>.delayed(
                  Duration(milliseconds: 250 * attempt),
                );
              }
              await _rebaseLiveDraftForAtomicRetry(
                liveDraftFieldNames.toSet(),
                context,
                conflict: error,
              );
              await _flushDirtyLiveDraftFields();
              _assertLiveDraftContextCurrent(context);
              final refreshedCanonical = _liveDraftSnapshot;
              final refreshedFields = liveDraftFields;
              if (refreshedCanonical == null || refreshedFields == null) {
                throw StateError('LIVE_DRAFT_NOT_LOADED');
              }
              canonical = refreshedCanonical;
              fields = refreshedFields;
              final missing = ['time', 'controller', 'callsign']
                  .where((field) => fields[field].trim().isEmpty)
                  .toList(growable: false);
              if (missing.isNotEmpty) {
                throw StateError(
                  'LIVE_DRAFT_INCOMPLETE:${missing.join(',')}',
                );
              }
            },
          );
          _assertLiveDraftContextCurrent(context);
          // The server has durably accepted the record. Publish it to the
          // table before waiting on draft-cache persistence or event catch-up;
          // either of those can be slow or fail independently of the commit.
          _stageCommittedLiveDraftLog(committed.record, committed.event);
          _liveDraftSnapshot = LiveDraftSnapshotDto(
            draft: committed.nextDraft,
            locks: const [],
            currentOrdinal: committed.currentOrdinal,
            totalRecords: committed.totalRecords,
            previousRecord: committed.record,
          );
          _localLiveDraftFields = committed.nextDraft.fields;
          _dirtyLiveDraftFields = const {};
          _liveDraftBaseRevisions = const {};
          _liveDraftHistoryPreview = null;
          _cancelLiveDraftHistoryPreviewExpiry();
          _clearOwnedLiveDraftLocks();
          _clearLiveDraftError();
          // Expose both the new table row and the reset draft immediately.
          // Cache persistence and event catch-up are durability work and must
          // not hold the visible form on the previous record.
          _safeNotify();
          await _persistLiveDraftState(_guardFor(context));
          await _refreshLogsAfterLiveDraftCommit(
            context: context,
            event: committed.event,
            syncId: committed.record.syncId,
          );
          _assertLiveDraftContextCurrent(context);
          _safeNotify();
          return LiveDraftCommitDisposition.committed;
        } on ServerApiException catch (error, stackTrace) {
          await _releaseOwnedLiveDraftFieldsAfterFailure(
            _ownedLiveDraftLocks.keys.toList(growable: false),
            context,
          );
          _assertLiveDraftContextCurrent(context);
          if (!error.retryable) {
            if ({
              'LIVE_DRAFT_VERSION_CONFLICT',
              'LIVE_DRAFT_BUSY',
            }.contains(error.code)) {
              AppLogger.instance.log(
                AppLogLevel.warning,
                'Live-draft commit still conflicted after bounded retries',
                source: 'CollaborationProvider',
                error: error,
                stackTrace: stackTrace,
              );
            }
            _setLiveDraftError(error.code, error.message);
            if ({
              'LIVE_DRAFT_ALREADY_COMMITTED',
              'LIVE_DRAFT_VERSION_CONFLICT',
              'LIVE_DRAFT_BUSY',
            }.contains(error.code)) {
              _runLiveDraftInBackground(refreshLiveDraft());
            }
            rethrow;
          }
          final queued = await _queueOfflineRecord(
            context,
            mutationId: mutationId,
            snapshot: canonical,
            fields: fields,
          );
          _offlineRecords = [..._offlineRecords, queued];
          _localLiveDraftFields = resetLiveDraftFieldsAfterCommit(fields);
          _dirtyLiveDraftFields = {
            for (final field in liveDraftFieldNames)
              if (_localLiveDraftFields![field] !=
                  canonical.draft.fields[field])
                field,
          };
          _liveDraftBaseRevisions = {
            for (final field in _dirtyLiveDraftFields)
              field: canonical.draft.fieldRevisions[field] ?? 0,
          };
          _clearOwnedLiveDraftLocks();
          _setLiveDraftError(
            'OFFLINE_RECORD_QUEUED',
            '网络不可用，记录已保存到本机，恢复连接后将检查是否可安全提交',
          );
          _safeNotify();
          await _persistLiveDraftState(_guardFor(context));
          return LiveDraftCommitDisposition.queuedOffline;
        } catch (error, stackTrace) {
          await _releaseOwnedLiveDraftFieldsAfterFailure(
            _ownedLiveDraftLocks.keys.toList(growable: false),
            context,
          );
          Error.throwWithStackTrace(error, stackTrace);
        }
      });

  Future<void> discardCurrentLiveDraft() => _serializeLiveDraft(() async {
        final context = _requireLiveDraftContext(requireEdit: true);
        final snapshot = _liveDraftSnapshot;
        if (snapshot == null) throw StateError('LIVE_DRAFT_NOT_LOADED');
        late final LiveDraftDiscardResultDto discarded;
        try {
          discarded = await context.api.discardLiveDraft(
            sessionId: context.binding.sessionId,
            deviceId: context.deviceId,
            expectedDraftVersion: snapshot.draft.version,
            idempotencyKey: _uuidV4(),
          );
          _assertLiveDraftContextCurrent(context);
        } on ServerApiException catch (error) {
          _assertLiveDraftContextCurrent(context);
          _setLiveDraftError(error.code, error.message);
          if ({'LIVE_DRAFT_VERSION_CONFLICT', 'LIVE_DRAFT_BUSY'}
              .contains(error.code)) {
            _runLiveDraftInBackground(refreshLiveDraft());
          }
          rethrow;
        }
        _liveDraftSnapshot = LiveDraftSnapshotDto(
          draft: discarded.nextDraft,
          locks: const [],
          currentOrdinal: discarded.currentOrdinal,
          totalRecords: discarded.totalRecords,
          previousRecord: snapshot.previousRecord,
        );
        _localLiveDraftFields = discarded.nextDraft.fields;
        _dirtyLiveDraftFields = const {};
        _liveDraftBaseRevisions = const {};
        _liveDraftHistoryPreview = null;
        _cancelLiveDraftHistoryPreviewExpiry();
        _clearOwnedLiveDraftLocks();
        _clearLiveDraftError();
        _safeNotify();
        await _persistLiveDraftState(_guardFor(context));
      });

  Future<void> resolveOfflineRecord(
    String mutationId,
    OfflineRecordResolution resolution,
  ) =>
      _serializeLiveDraft(() async {
        LocalOfflineRecordDto? record;
        for (final candidate in _offlineRecords) {
          if (candidate.mutationId == mutationId) {
            record = candidate;
            break;
          }
        }
        if (record == null) throw StateError('OFFLINE_RECORD_NOT_FOUND');
        final localGuard = _tryLiveDraftGuard();
        if (localGuard == null) {
          throw StateError('LIVE_DRAFT_CONTEXT_CHANGED');
        }
        if (resolution == OfflineRecordResolution.discard) {
          await _updateOfflineRecord(
            record,
            state: OfflineRecordState.discarded,
            resolution: resolution,
            guard: localGuard,
          );
          return;
        }
        final context = _requireLiveDraftContext(requireEdit: true);
        await _copyOfflineRecordIntoCurrentDraft(record, context);
        _assertLiveDraftContextCurrent(context);
        if (resolution == OfflineRecordResolution.submitAsDuplicate) {
          final snapshot = _liveDraftSnapshot!;
          final committed = await context.api.commitLiveDraft(
            sessionId: context.binding.sessionId,
            deviceId: context.deviceId,
            expectedDraftVersion: snapshot.draft.version,
            syncId: record.mutationId,
            idempotencyKey: record.mutationId,
          );
          _assertLiveDraftContextCurrent(context);
          _stageCommittedLiveDraftLog(committed.record, committed.event);
          _liveDraftSnapshot = LiveDraftSnapshotDto(
            draft: committed.nextDraft,
            locks: const [],
            currentOrdinal: committed.currentOrdinal,
            totalRecords: committed.totalRecords,
            previousRecord: committed.record,
          );
          _localLiveDraftFields = committed.nextDraft.fields;
          _dirtyLiveDraftFields = const {};
          _liveDraftBaseRevisions = const {};
          _liveDraftHistoryPreview = null;
          _cancelLiveDraftHistoryPreviewExpiry();
          _clearOwnedLiveDraftLocks();
          _safeNotify();
          await _refreshLogsAfterLiveDraftCommit(
            context: context,
            event: committed.event,
            syncId: committed.record.syncId,
          );
          _assertLiveDraftContextCurrent(context);
        }
        await _updateOfflineRecord(
          record,
          state: OfflineRecordState.resolved,
          resolution: resolution,
          guard: _guardFor(context),
        );
        await _persistLiveDraftState(_guardFor(context));
        _safeNotify();
      });

  Future<void> refreshManagement() async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _memberManagementFeatures);
      _assertOperationCurrent(context);
      await _refreshManagementForOperation(context, binding);
    });
  }

  Future<CollaborationInviteDto> createInvite({
    required InviteRole role,
    int expiresInHours = 24,
    int maxUses = 1,
  }) async {
    late CollaborationInviteDto created;
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _inviteManagementFeatures);
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'createInvite',
        {
          'role': role.toJson(),
          'expiresInHours': expiresInHours,
          'maxUses': maxUses,
        },
      );
      _assertOperationCurrent(context);
      created = await context.api.createInvite(
        sessionId: binding.sessionId,
        request: CreateInviteRequestDto(
          role: role,
          expiresInHours: expiresInHours,
          maxUses: maxUses,
        ),
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      _lastCreatedInvite = created;
      await _refreshManagementBestEffort(context, binding);
    });
    return created;
  }

  Future<void> revokeInvite(String inviteId) async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _inviteManagementFeatures);
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'revokeInvite',
        {'inviteId': inviteId},
      );
      _assertOperationCurrent(context);
      final revoked = await context.api.revokeInvite(
        sessionId: binding.sessionId,
        inviteId: inviteId,
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      _invites = [
        for (final invite in _invites)
          if (invite.inviteId == revoked.inviteId) revoked else invite,
      ];
      await _refreshManagementBestEffort(context, binding);
    });
  }

  Future<void> leaveCurrentSession() async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: false);
      if (effectiveRole == SessionRole.owner) {
        throw StateError('OWNER_TRANSFER_REQUIRED');
      }
      await _ensureServerCapabilities(context, _memberManagementFeatures);
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'leaveSession',
        const {},
      );
      _assertOperationCurrent(context);
      final result = await context.api.leaveSession(
        sessionId: binding.sessionId,
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      await RustApi.markCollaborationRevoked(
        serverInstanceId: binding.serverInstanceId,
        accountId: binding.accountId,
        sessionId: binding.sessionId,
      );
      if (!_isOperationCurrent(context)) return;
      _membership = result.membership;
      _members = const [];
      _invites = const [];
      _state = CollaborationState.revoked;
      context.logs.setCollaborationReadOnly(binding.sessionId, true);
    });
  }

  /// Forks the materialized collaboration Session into a writable local-only
  /// Session. This is a device-local disaster-recovery action and deliberately
  /// does not require an account, server capabilities, or network access.
  Future<void> createEditableLocalCopy({required String title}) async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final sourceSessionId = sessions.currentSessionId;
    final sourceBinding = binding;
    if (sourceSessionId == null ||
        sourceBinding == null ||
        sourceBinding.sessionId != sourceSessionId) {
      throw StateError('LOCAL_COLLABORATION_REQUIRED');
    }

    _operationInProgress = true;
    _stateEpoch += 1;
    _refreshGeneration += 1;
    _clearError();
    _stopSynchronization();
    _safeNotify();
    try {
      final local = await sessions.copyCurrentCollaborationSessionToLocal(
        title: title,
      );
      _publishingSessionId = null;
      _clearScopedState();
      // Keep the preserved server replica read-only, while the newly selected
      // local fork must not inherit that session-scoped permission marker.
      logs.setCollaborationReadOnly(sourceSessionId, true);
      logs.setCollaborationReadOnly(local.sessionId, false);
      if (sessions.currentSessionId != local.sessionId) {
        // The copy is durable, but a concurrent history action selected
        // another session. Preserve that selection instead of moving only the
        // log projection to the new copy.
        return;
      }
      await logs.reloadForSession(local.sessionId, propagateErrors: true);
      _state = CollaborationState.localOnly;
    } catch (error) {
      _setError(_localErrorCode(error), error.toString());
      rethrow;
    } finally {
      _operationInProgress = false;
      _safeNotify();
      _scheduleRefresh();
    }
  }

  /// Stops synchronization on this device and atomically replaces the bound
  /// replica with an independent local Session. The server Session,
  /// membership, and other devices are deliberately left untouched.
  Future<void> convertCurrentSessionToLocal() async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    if (!canConvertCurrentSessionDirectly) {
      throw StateError('COLLABORATION_LOCAL_CONVERSION_NOT_READY');
    }
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final sourceSessionId = sessions.currentSessionId;
    final sourceBinding = binding;
    if (sourceSessionId == null ||
        sourceBinding == null ||
        sourceBinding.sessionId != sourceSessionId) {
      throw StateError('LOCAL_COLLABORATION_REQUIRED');
    }

    _operationInProgress = true;
    _stateEpoch += 1;
    _refreshGeneration += 1;
    _clearError();
    final quiescence = _suspendForDeviceLocalMutation();
    _safeNotify();
    try {
      await waitForCollaborationLocalQuiescence([
        quiescence.liveDraft,
        quiescence.synchronization,
      ]);
      final local = await sessions.convertCurrentCollaborationSessionToLocal();
      await _finishCommittedLocalReplacement(
        sessions: sessions,
        logs: logs,
        sourceSessionId: sourceSessionId,
        localSessionId: local.sessionId,
      );
    } catch (error) {
      _setError(_localErrorCode(error), error.toString());
      rethrow;
    } finally {
      _operationInProgress = false;
      _safeNotify();
      _scheduleRefresh();
    }
  }

  /// Stops this device's collaboration replica even when the server cannot be
  /// reached. Saved, materialized rows become an independent local session;
  /// pending synchronization metadata and draft-only state are discarded.
  /// Nothing is sent to or changed on the server.
  Future<void> stopCurrentSessionLocally() async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final sourceSessionId = sessions.currentSessionId;
    final sourceBinding = binding;
    if (sourceSessionId == null ||
        sourceBinding == null ||
        sourceBinding.sessionId != sourceSessionId) {
      throw StateError('LOCAL_COLLABORATION_REQUIRED');
    }

    _operationInProgress = true;
    _stateEpoch += 1;
    _refreshGeneration += 1;
    _clearError();
    final quiescence = _suspendForDeviceLocalMutation();
    _safeNotify();
    try {
      await waitForCollaborationLocalQuiescence([
        quiescence.liveDraft,
        quiescence.synchronization,
      ]);
      final local = await sessions.stopCurrentCollaborationSessionLocally();
      await _finishCommittedLocalReplacement(
        sessions: sessions,
        logs: logs,
        sourceSessionId: sourceSessionId,
        localSessionId: local.sessionId,
      );
    } catch (error) {
      _setError(_localErrorCode(error), error.toString());
      rethrow;
    } finally {
      _operationInProgress = false;
      _safeNotify();
      _scheduleRefresh();
    }
  }

  /// Stops synchronization and keeps the materialized replica as a closed,
  /// read-only local history session. The shared server session is not closed.
  Future<void> closeCurrentSessionLocally() async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final sourceSessionId = sessions.currentSessionId;
    final sourceBinding = binding;
    if (sourceSessionId == null ||
        sourceBinding == null ||
        sourceBinding.sessionId != sourceSessionId) {
      throw StateError('LOCAL_COLLABORATION_REQUIRED');
    }

    _operationInProgress = true;
    _stateEpoch += 1;
    _refreshGeneration += 1;
    _clearError();
    final quiescence = _suspendForDeviceLocalMutation();
    _safeNotify();
    try {
      await waitForCollaborationLocalQuiescence([
        quiescence.liveDraft,
        quiescence.synchronization,
      ]);
      final local = await sessions.closeSessionLocally(sourceSessionId);
      await _finishCommittedLocalReplacement(
        sessions: sessions,
        logs: logs,
        sourceSessionId: sourceSessionId,
        localSessionId: local.sessionId,
      );
    } catch (error) {
      _setError(_localErrorCode(error), error.toString());
      rethrow;
    } finally {
      _operationInProgress = false;
      _safeNotify();
      _scheduleRefresh();
    }
  }

  /// Permanently removes the current replica and all of its local data. This is
  /// a device-only action and never deletes or closes the server session.
  Future<void> deleteCurrentSessionLocally() async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final sourceSessionId = sessions.currentSessionId;
    final sourceBinding = binding;
    if (sourceSessionId == null ||
        sourceBinding == null ||
        sourceBinding.sessionId != sourceSessionId) {
      throw StateError('LOCAL_COLLABORATION_REQUIRED');
    }

    _operationInProgress = true;
    _stateEpoch += 1;
    _refreshGeneration += 1;
    _clearError();
    final quiescence = _suspendForDeviceLocalMutation();
    _safeNotify();
    try {
      await waitForCollaborationLocalQuiescence([
        quiescence.liveDraft,
        quiescence.synchronization,
      ]);
      await sessions.deleteSessionLocally(sourceSessionId);
      _publishingSessionId = null;
      _clearScopedState();
      logs.setCollaborationReadOnly(sourceSessionId, false);
      _state = CollaborationState.localOnly;
      try {
        await logs.forgetDeletedSession(sourceSessionId);
      } catch (error, stackTrace) {
        // The database deletion is already committed. Keep the successful
        // action successful and expose a recoverable projection warning.
        debugPrint(
          '[Collaboration] deleted local replica but failed to refresh logs: '
          '$error\n$stackTrace',
        );
        _setError('LOCAL_SESSION_RELOAD_FAILED', error.toString());
      }
    } catch (error) {
      _setError(_localErrorCode(error), error.toString());
      rethrow;
    } finally {
      _operationInProgress = false;
      _safeNotify();
      _scheduleRefresh();
    }
  }

  /// Suspends all collaboration writers around a destructive local database
  /// operation. The operation owns the database mutation itself; this wrapper
  /// serializes it with live-draft and sync work and then rebuilds provider
  /// state from the resulting database.
  Future<T> runLocalDatabaseMaintenance<T>(
    Future<T> Function() operation,
  ) async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    final sessions = _requireSessions();
    final logs = _requireLogs();
    _operationInProgress = true;
    _stateEpoch += 1;
    _refreshGeneration += 1;
    _clearError();
    final quiescence = _suspendForDeviceLocalMutation();
    _safeNotify();
    var replacementPreparedByThisRun = false;
    var operationCommitted = false;
    try {
      await waitForCollaborationLocalQuiescence([
        quiescence.liveDraft,
        quiescence.synchronization,
      ]);
      replacementPreparedByThisRun =
          await sessions.prepareForDatabaseReplacement();
      final result = await operation();
      operationCommitted = true;
      _publishingSessionId = null;
      _clearScopedState();
      await sessions.reloadAfterDatabaseReplacement();
      await logs.reloadAfterDatabaseReplacement(sessions.currentSessionId);
      // The crash sentinel is removed strictly after the replacement revision
      // and both provider projections have been rebuilt successfully.
      await sessions.acknowledgeDatabaseReplacement();
      return result;
    } catch (error, stackTrace) {
      if (replacementPreparedByThisRun && !operationCommitted) {
        try {
          // A throwing database transaction is required to have rolled back,
          // so this is the only failure path where clearing the sentinel is
          // safe. Reload/persistence failures after a commit keep it raised.
          await sessions.rollbackFailedDatabaseReplacement();
        } catch (sentinelError, sentinelStackTrace) {
          debugPrint(
            '[Collaboration] failed to clear rolled-back database '
            'replacement sentinel: $sentinelError\n$sentinelStackTrace',
          );
        }
      }
      _setError(_localErrorCode(error), error.toString());
      debugPrint(
        '[Collaboration] local database maintenance failed: '
        '$error\n$stackTrace',
      );
      rethrow;
    } finally {
      _operationInProgress = false;
      _safeNotify();
      // A failed operation normally leaves the old database intact; on
      // success this reloads an imported collaboration binding, if any.
      _scheduleRefresh();
    }
  }

  Future<void> _finishCommittedLocalReplacement({
    required SessionProvider sessions,
    required LogProvider logs,
    required String sourceSessionId,
    required String localSessionId,
  }) async {
    // Rust and SessionProvider have already committed the replacement and
    // selected it. From here onward failures are projection-refresh failures,
    // not operation failures; reporting the conversion as failed would invite
    // a destructive retry against a source row that no longer exists.
    _publishingSessionId = null;
    _clearScopedState();
    logs.setCollaborationReadOnly(sourceSessionId, false);
    logs.setCollaborationReadOnly(localSessionId, false);
    _state = CollaborationState.localOnly;
    if (sessions.currentSessionId != localSessionId) {
      // The durable replacement succeeded, but a concurrent history action
      // selected another session while Rust was committing. Preserve that
      // newer selection and only retire caches belonging to the removed source.
      try {
        await logs.forgetDeletedSession(sourceSessionId);
      } catch (error, stackTrace) {
        debugPrint(
          '[Collaboration] local replacement committed after selection '
          'changed; source cache cleanup failed: $error\n$stackTrace',
        );
      }
      return;
    }
    try {
      await logs.reloadForSession(localSessionId, propagateErrors: true);
      await logs.forgetDeletedSession(sourceSessionId);
    } catch (error, stackTrace) {
      debugPrint(
        '[Collaboration] local replacement committed but log refresh failed: '
        '$error\n$stackTrace',
      );
      _setError('LOCAL_SESSION_RELOAD_FAILED', error.toString());
      // Keep a recoverable empty projection tied to the committed replacement;
      // opening history or restarting the app will load the same durable rows.
      try {
        await logs.forgetDeletedSession(sourceSessionId);
      } catch (_) {
        // Best-effort cache cleanup only; the source row is already gone.
      }
    }
  }

  Future<void> refreshPublicShares() async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _publicShareFeatures);
      _assertOperationCurrent(context);
      final shares = <PublicShareDto>[];
      String? cursor;
      do {
        final page = await context.api.listPublicShares(
          sessionId: binding.sessionId,
          after: cursor,
        );
        _assertOperationCurrent(context);
        shares.addAll(page.publicShares);
        cursor = page.nextCursor;
      } while (cursor != null);
      _publicShares = List.unmodifiable(shares);
    }, refreshAfter: false);
  }

  Future<PublicShareDto> createPublicShare({
    int expiresInHours = 24,
  }) async {
    late PublicShareDto created;
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _publicShareFeatures);
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'createPublicShare',
        {'expiresInHours': expiresInHours},
      );
      _assertOperationCurrent(context);
      created = await context.api.createPublicShare(
        sessionId: binding.sessionId,
        expiresInHours: expiresInHours,
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      _lastCreatedPublicShare = created;
      _publicShares = [
        created,
        ..._publicShares.where(
          (share) => share.publicShareId != created.publicShareId,
        ),
      ];
    }, refreshAfter: false);
    return created;
  }

  Uri publicSharePageUri(PublicShareDto share) =>
      _requireServer().api.publicSharePageUri(share);

  Future<void> revokePublicShare(String publicShareId) async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _publicShareFeatures);
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'revokePublicShare',
        {'publicShareId': publicShareId},
      );
      _assertOperationCurrent(context);
      final revoked = await context.api.revokePublicShare(
        sessionId: binding.sessionId,
        publicShareId: publicShareId,
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      _publicShares = [
        for (final share in _publicShares)
          if (share.publicShareId == publicShareId) revoked else share,
      ];
      if (_lastCreatedPublicShare?.publicShareId == publicShareId) {
        _lastCreatedPublicShare = null;
      }
    }, refreshAfter: false);
  }

  Future<void> removeMember(String userId) async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _memberManagementFeatures);
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'removeMember',
        {'userId': userId},
      );
      _assertOperationCurrent(context);
      await context.api.removeMember(
        sessionId: binding.sessionId,
        userId: userId,
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      _members = _members.where((member) => member.userId != userId).toList();
      await _refreshManagementBestEffort(context, binding);
    });
  }

  Future<void> updateMemberRole(String userId, InviteRole role) async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, _memberManagementFeatures);
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'updateMemberRole',
        {'userId': userId, 'role': role.toJson()},
      );
      _assertOperationCurrent(context);
      final updated = await context.api.updateMemberRole(
        sessionId: binding.sessionId,
        userId: userId,
        role: role,
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      _members = [
        for (final member in _members)
          if (member.userId == updated.userId) updated else member,
      ];
      await _refreshManagementBestEffort(context, binding);
    });
  }

  Future<void> transferOwnership(String userId) async {
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: true);
      await _ensureServerCapabilities(context, {
        ..._memberManagementFeatures,
        'sessionSnapshots',
        'sessionSnapshotTombstones',
      });
      _assertOperationCurrent(context);
      final pending = await _pendingMutationId(
        context,
        binding,
        'transferOwnership',
        {'newOwnerUserId': userId},
      );
      _assertOperationCurrent(context);
      final transfer = await context.api.transferOwnership(
        sessionId: binding.sessionId,
        newOwnerUserId: userId,
        idempotencyKey: pending.id,
      );
      await _confirmPendingMutation(pending.storageKey);
      if (!_isOperationCurrent(context)) return;
      _membership = transfer.previousOwner;
      _members = const [];
      _invites = const [];
      _lastCreatedInvite = null;
      try {
        final snapshot = await context.api.getSessionSnapshot(
          binding.sessionId,
          includeDeleted: includeDeletedLogsForSnapshotInstall(
            CollaborationSnapshotInstallTarget.existingReplica,
          ),
        );
        _assertOperationCurrent(context);
        final bindingJson = await RustApi.installCollaborationSnapshot(
          requestJson: jsonEncode({
            'mode': 'join',
            'serverInstanceId': binding.serverInstanceId,
            'serverOrigin': context.serverUrl,
            'accountId': context.accountId,
            'membership': transfer.previousOwner.toJson(),
            'snapshot': snapshot.toJson(),
          }),
        );
        if (!_isOperationCurrent(context)) return;
        _binding = LocalCollaborationBinding.fromJson(
          jsonDecode(bindingJson),
        );
      } catch (error) {
        if (_isOperationCurrent(context)) {
          _setError(
            'OWNERSHIP_TRANSFERRED_REFRESH_FAILED',
            '所有权已经转移，但本地权限快照刷新失败：$error',
          );
        }
      }
    });
  }

  Future<void> renameCurrentSession(String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty || normalized.length > 200) {
      throw ArgumentError('会话标题长度应为 1–200 个字符');
    }
    await _runOperation((context) async {
      final binding = _requireSynchronizedOwner(context);
      await RustApi.updateCollaborationSessionTitle(
        sessionId: binding.sessionId,
        title: normalized,
      );
      _assertOperationCurrent(context);
      await context.sessions.reloadCurrentSession();
      _assertOperationCurrent(context);
      _syncCoordinator?.wake();
    }, refreshAfter: false);
  }

  Future<void> closeCurrentSession() async {
    await _runOperation((context) async {
      final binding = _requireSynchronizedOwner(context);
      if (supportsLiveDraft) {
        final snapshot = await context.api.getLiveDraft(binding.sessionId);
        _assertOperationCurrent(context);
        if (_liveDraftHasActualContent(snapshot.draft.fields)) {
          throw StateError(
            'LIVE_DRAFT_NOT_EMPTY: 请先提交或明确丢弃当前点名草稿',
          );
        }
        if (snapshot.locks.isNotEmpty) {
          throw StateError(
            'LIVE_DRAFT_BUSY: 请先结束所有草稿字段编辑后再关闭会话',
          );
        }
      }
      await RustApi.closeSession(sessionId: binding.sessionId);
      _assertOperationCurrent(context);
      // Lock writes before any async UI reload or network round trip. Rust has
      // committed the local status + outbox atomically at this point.
      _syncCoordinator?.markSessionLocallyClosed();
      context.logs.setCollaborationReadOnly(binding.sessionId, true);
      await context.sessions.reloadCurrentSession();
      _assertOperationCurrent(context);
    }, refreshAfter: false);
  }

  Future<void> reopenCurrentSession() async {
    await _runOperation((context) async {
      final binding = _requireSynchronizedOwner(context);
      await RustApi.reopenCollaborationSession(sessionId: binding.sessionId);
      _assertOperationCurrent(context);
      await context.sessions.reloadCurrentSession();
      _assertOperationCurrent(context);
      // Keep the local close guard until session.reopened is applied. This
      // avoids reporting writable state if the server resolves the operation
      // as a conflict or rejection.
      context.logs.setCollaborationReadOnly(binding.sessionId, true);
      _syncCoordinator?.markSessionLocallyReopened();
    }, refreshAfter: false);
  }

  Future<void> refreshOpenConflicts() async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    final identity = _currentConflictIdentity();
    if (identity == null) {
      throw StateError('COLLABORATION_CONFLICT_CONTEXT_MISMATCH');
    }
    await _loadOpenConflicts(identity, rethrowError: true);
  }

  Future<void> useRemoteForConflict(String conflictId) => _resolveConflict(
        conflictId,
        CollaborationConflictResolution.useRemote,
      );

  Future<void> keepLocalForConflict(String conflictId) => _resolveConflict(
        conflictId,
        CollaborationConflictResolution.keepLocal,
      );

  Future<void> copyLocalAsNewForConflict(String conflictId) => _resolveConflict(
        conflictId,
        CollaborationConflictResolution.copyLocalAsNew,
      );

  Future<void> _resolveConflict(
    String conflictId,
    CollaborationConflictResolution resolution,
  ) async {
    if (conflictId.trim().isEmpty) {
      throw ArgumentError.value(conflictId, 'conflictId', 'must not be empty');
    }
    await _runOperation((context) async {
      final binding = _requireBoundSession(context, requireOwner: false);
      final identity = _currentConflictIdentity();
      if (identity == null ||
          identity.serverInstanceId != binding.serverInstanceId ||
          identity.accountId != binding.accountId ||
          identity.sessionId != binding.sessionId) {
        throw StateError('COLLABORATION_CONFLICT_CONTEXT_MISMATCH');
      }
      CollaborationConflict? conflict;
      for (final candidate in _openConflicts) {
        if (candidate.conflictId == conflictId) {
          conflict = candidate;
          break;
        }
      }
      if (conflict == null || conflict.sessionId != identity.sessionId) {
        throw StateError('COLLABORATION_CONFLICT_NOT_FOUND');
      }
      if (!conflict.allowedResolutions.contains(resolution)) {
        throw StateError('CONFLICT_RESOLUTION_NOT_ALLOWED');
      }
      if (_resolvingConflictId != null) {
        throw StateError('COLLABORATION_CONFLICT_OPERATION_IN_PROGRESS');
      }

      _resolvingConflictId = conflictId;
      _conflictRequestGeneration += 1;
      _safeNotify();
      try {
        final result = await _conflictPort.resolveConflict(
          identity,
          conflictId,
          resolution,
          expectedRemoteVersion: conflict.remoteVersion,
        );
        _assertOperationCurrent(context);
        if (_currentConflictIdentity() != identity ||
            result.resolution != resolution) {
          throw const _OperationContextChanged();
        }

        // The local resolution transaction is durable at this point. Wake the
        // coordinator before UI reloads so a keep-local replacement mutation
        // is not delayed by rendering work.
        _syncCoordinator?.wake();
        await context.sessions.reloadCurrentSession();
        _assertOperationCurrent(context);
        await context.logs.reloadForSession(
          binding.sessionId,
          propagateErrors: true,
        );
        _assertOperationCurrent(context);
        await _loadOpenConflicts(identity, rethrowError: true);
        _assertOperationCurrent(context);
      } catch (error) {
        // A remote-version precondition or a permission change means the
        // choice the user confirmed is stale. Keep the operation error
        // visible, but best-effort refresh the list before returning it.
        if (_isOperationCurrent(context) &&
            _currentConflictIdentity() == identity) {
          await _loadOpenConflicts(identity, rethrowError: false);
        }
        if (_localErrorCode(error) == 'CONFLICT_REMOTE_ADVANCED') {
          throw StateError(
            'CONFLICT_REMOTE_ADVANCED: 远端内容已更新，'
            '请检查刷新后的冲突内容并重新确认',
          );
        }
        rethrow;
      } finally {
        if (_isOperationCurrent(context) &&
            _resolvingConflictId == conflictId) {
          _resolvingConflictId = null;
          _safeNotify();
        }
      }
    }, refreshAfter: false);
  }

  Future<void> _loadOpenConflicts(
    CollaborationSyncIdentity identity, {
    required bool rethrowError,
  }) async {
    final requestGeneration = ++_conflictRequestGeneration;
    final invalidationGeneration = _conflictInvalidationGeneration;
    _conflictsLoading = true;
    _safeNotify();
    try {
      final conflicts = await _conflictPort.listOpenConflicts(identity);
      if (!_isConflictRequestCurrent(requestGeneration, identity)) return;
      final ids = <String>{};
      if (conflicts.any(
        (conflict) =>
            conflict.sessionId != identity.sessionId ||
            !ids.add(conflict.conflictId),
      )) {
        throw const FormatException(
          'Conflict list contains another session or duplicate IDs',
        );
      }
      _openConflicts = List.unmodifiable(conflicts);
      _conflictsLoaded = true;
      if (_conflictInvalidationGeneration == invalidationGeneration) {
        _conflictsNeedRefresh = false;
      }
      if (_errorCode == 'CONFLICT_LIST_FAILED') _clearError();
    } catch (error) {
      if (_isConflictRequestCurrent(requestGeneration, identity)) {
        _setError('CONFLICT_LIST_FAILED', error.toString());
      }
      if (rethrowError) rethrow;
    } finally {
      if (requestGeneration == _conflictRequestGeneration) {
        _conflictsLoading = false;
        _safeNotify();
        if (_conflictsNeedRefresh &&
            _conflictInvalidationGeneration != invalidationGeneration) {
          _scheduleOpenConflictReload(identity);
        }
      }
    }
  }

  void _invalidateOpenConflicts(CollaborationSyncIdentity identity) {
    if ((_syncState?.conflictCount ?? 0) <= 0 && _openConflicts.isEmpty) {
      return;
    }
    _conflictInvalidationGeneration += 1;
    _conflictsNeedRefresh = true;
    _scheduleOpenConflictReload(identity);
  }

  void _scheduleOpenConflictReload(CollaborationSyncIdentity identity) {
    if (_conflictReloadScheduled ||
        _conflictsLoading ||
        _currentConflictIdentity() != identity) {
      return;
    }
    _conflictReloadScheduled = true;
    scheduleMicrotask(() {
      _conflictReloadScheduled = false;
      if (_conflictsLoading ||
          _currentConflictIdentity() != identity ||
          ((_syncState?.conflictCount ?? 0) <= 0 && _openConflicts.isEmpty)) {
        return;
      }
      unawaited(_loadOpenConflicts(identity, rethrowError: false));
    });
  }

  Future<void> _runOperation(
    Future<void> Function(_OperationContext context) operation, {
    bool refreshAfter = true,
  }) async {
    if (_operationInProgress) {
      throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
    }
    final server = _requireServer();
    final sessions = _requireSessions();
    final logs = _requireLogs();
    final accountId = _requireAccountId(server);
    _stateEpoch += 1;
    final context = _OperationContext(
      server: server,
      api: server.api,
      sessions: sessions,
      logs: logs,
      serverContextRevision: server.contextRevision,
      serverUrl: server.serverUrl,
      accountId: accountId,
      sessionId: sessions.currentSessionId,
      epoch: _stateEpoch,
    );
    _operationInProgress = true;
    _clearError();
    _safeNotify();
    try {
      await operation(context);
      AppLogger.instance.log(
        AppLogLevel.debug,
        'Collaboration operation completed for session '
        '${context.sessionId ?? '(none)'}',
        source: 'CollaborationProvider',
      );
    } on ServerApiException catch (error, stackTrace) {
      if (_isOperationCurrent(context)) {
        _setError(error.code, error.message);
      }
      AppLogger.instance.log(
        AppLogLevel.error,
        'Collaboration operation failed with ${error.code} for session '
        '${context.sessionId ?? '(none)'}',
        source: 'CollaborationProvider',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_isOperationCurrent(context)) {
        _setError(_localErrorCode(error), error.toString());
      }
      AppLogger.instance.log(
        AppLogLevel.error,
        'Local collaboration operation failed for session '
        '${context.sessionId ?? '(none)'}',
        source: 'CollaborationProvider',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _operationInProgress = false;
      _safeNotify();
      if (refreshAfter) _scheduleRefresh();
    }
  }

  Future<ServerInfoDto> _ensureServerCapabilities(
    _OperationContext context,
    Set<String> required,
  ) async {
    _assertOperationCurrent(context);
    final info =
        context.server.serverInfo ?? await context.server.checkServer();
    _assertOperationCurrent(context);
    _requireFeatures(info, required);
    final binding = _binding;
    if (binding != null &&
        binding.sessionId == context.sessionId &&
        info.serverInstanceId != binding.serverInstanceId) {
      throw StateError('SERVER_IDENTITY_MISMATCH');
    }
    return info;
  }

  void _requireFeatures(ServerInfoDto info, Set<String> required) {
    if (info.protocolMin > 1 || info.protocolMax < 1) {
      throw StateError('服务器不支持协作协议 v1');
    }
    final missing = required.difference(info.features.toSet());
    if (missing.isNotEmpty) {
      throw StateError('服务器缺少协作能力: ${missing.join(', ')}');
    }
  }

  Future<void> _refreshManagementForOperation(
    _OperationContext context,
    LocalCollaborationBinding binding,
  ) async {
    final info = await _ensureServerCapabilities(
      context,
      _memberManagementFeatures,
    );
    _assertOperationCurrent(context);
    final supportsInvites = info.features.contains('collaborationInvites');
    final results = await Future.wait<Object>([
      context.api.listMembers(binding.sessionId),
      if (supportsInvites) context.api.listInvites(binding.sessionId),
    ]);
    _assertOperationCurrent(context);
    _members = results[0] as List<MembershipDto>;
    _invites =
        supportsInvites ? results[1] as List<CollaborationInviteDto> : const [];
    _safeNotify();
  }

  Future<void> _refreshManagementBestEffort(
    _OperationContext context,
    LocalCollaborationBinding binding,
  ) async {
    try {
      await _refreshManagementForOperation(context, binding);
    } catch (error) {
      if (_isOperationCurrent(context)) {
        _setError(
          'MANAGEMENT_REFRESH_FAILED',
          '服务器变更已经确认，但成员列表刷新失败：$error',
        );
      }
    }
  }

  BootstrapLogDto _bootstrapLogFromJson(Object? value) {
    final map = Map<String, Object?>.from(value! as Map);
    String? optional(String key) {
      final raw = map[key] as String?;
      return raw == null || raw.trim().isEmpty ? null : raw;
    }

    return BootstrapLogDto(
      syncId: (map['syncId']! as String).trim(),
      time: DateTime.parse(map['time']! as String),
      controller: (map['controller']! as String).trim().toUpperCase(),
      callsign: (map['callsign']! as String).trim().toUpperCase(),
      rstSent: optional('rstSent'),
      rstRcvd: optional('rstRcvd'),
      qth: optional('qth'),
      device: optional('device'),
      power: optional('power'),
      antenna: optional('antenna'),
      height: optional('height'),
      remarks: optional('remarks'),
    );
  }

  Future<({String id, String storageKey})> _pendingJoinRequestId({
    required String serverInstanceId,
    required String accountId,
    required String credentialKind,
    required String credentialValue,
  }) async {
    final prefs = await openKeyValueStore();
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'serverInstanceId': serverInstanceId,
              'accountId': accountId,
              'credentialKind': credentialKind,
              'credentialValue': credentialValue,
            }),
          ),
        )
        .toString();
    final storageKey = '$_pendingJoinPrefix$fingerprint';
    final storedId = await prefs.getString(storageKey);
    if (storedId != null &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(storedId)) {
      return (id: storedId, storageKey: storageKey);
    }
    final legacyFingerprint =
        await prefs.getString(_legacyPendingJoinFingerprintKey);
    final legacyId = await prefs.getString(_legacyPendingJoinIdKey);
    final validLegacyId = legacyId != null &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(legacyId);
    final id = legacyFingerprint == fingerprint && validLegacyId
        ? legacyId
        : _uuidV4();
    if (!await prefs.setString(storageKey, id)) {
      throw StateError('PENDING_JOIN_PERSIST_FAILED');
    }
    // Clean the pre-scoped Stage 1 draft keys without making the new request
    // depend on that best-effort migration.
    await prefs.remove(_legacyPendingJoinFingerprintKey);
    await prefs.remove(_legacyPendingJoinIdKey);
    return (id: id, storageKey: storageKey);
  }

  Future<void> _clearPendingJoin(String storageKey) async {
    final prefs = await openKeyValueStore();
    final removed = await prefs.remove(storageKey);
    if (!removed && await prefs.containsKey(storageKey)) {
      throw StateError('PENDING_JOIN_CLEAR_FAILED');
    }
  }

  Future<({String id, String storageKey})> _pendingMutationId(
    _OperationContext context,
    LocalCollaborationBinding binding,
    String kind,
    Object payload,
  ) async {
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'serverInstanceId': binding.serverInstanceId,
              'accountId': context.accountId,
              'sessionId': binding.sessionId,
              'kind': kind,
              'payload': payload,
            }),
          ),
        )
        .toString();
    final storageKey = '$_pendingMutationPrefix$fingerprint';
    final prefs = await openKeyValueStore();
    final stored = await prefs.getString(storageKey);
    if (stored != null &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(stored)) {
      return (id: stored, storageKey: storageKey);
    }
    final id = _uuidV4();
    if (!await prefs.setString(storageKey, id)) {
      throw StateError('PENDING_MUTATION_PERSIST_FAILED');
    }
    return (id: id, storageKey: storageKey);
  }

  Future<void> _confirmPendingMutation(String storageKey) async {
    final prefs = await openKeyValueStore();
    final removed = await prefs.remove(storageKey);
    if (!removed && await prefs.containsKey(storageKey)) {
      throw StateError('PENDING_MUTATION_CLEAR_FAILED');
    }
  }

  LocalCollaborationBinding _requireBoundSession(
    _OperationContext context, {
    required bool requireOwner,
  }) {
    _assertOperationCurrent(context);
    final binding = _binding;
    final membership = _membership;
    if (binding == null || membership == null) {
      throw StateError('当前会话尚未绑定服务器');
    }
    if (_state != CollaborationState.ready ||
        binding.replicaState != 'ready' ||
        binding.sessionId != context.sessionId ||
        binding.sessionId != _sessions?.currentSessionId ||
        binding.accountId != context.accountId ||
        membership.membershipId != binding.membershipId ||
        membership.sessionId != binding.sessionId ||
        membership.userId != context.accountId ||
        membership.removedAt != null ||
        (requireOwner && effectiveRole != SessionRole.owner)) {
      throw StateError('COLLABORATION_CONTEXT_MISMATCH');
    }
    final serverInstanceId = context.server.serverInfo?.serverInstanceId;
    if (serverInstanceId != null &&
        serverInstanceId != binding.serverInstanceId) {
      throw StateError('SERVER_IDENTITY_MISMATCH');
    }
    return binding;
  }

  LocalCollaborationBinding _requireSynchronizedOwner(
    _OperationContext context,
  ) {
    final binding = _requireBoundSession(context, requireOwner: true);
    final sync = _syncState;
    if (sync == null ||
        sync.replicaPhase != CollaborationReplicaPhase.ready ||
        sync.identity?.serverInstanceId != binding.serverInstanceId ||
        sync.identity?.accountId != binding.accountId ||
        sync.identity?.sessionId != binding.sessionId ||
        sync.role != SessionRole.owner) {
      throw StateError('COLLABORATION_SYNC_NOT_READY');
    }
    return binding;
  }

  bool _isServerIdentityCurrent(_OperationContext context) =>
      !_disposed &&
      identical(_server, context.server) &&
      context.server.contextRevision == context.serverContextRevision &&
      context.server.serverUrl == context.serverUrl &&
      context.server.accountId == context.accountId;

  bool _isOperationCurrent(_OperationContext context) =>
      _isServerIdentityCurrent(context) &&
      _operationInProgress &&
      context.epoch == _stateEpoch &&
      identical(_sessions, context.sessions) &&
      identical(_logs, context.logs) &&
      _sessions?.currentSessionId == context.sessionId;

  void _assertOperationCurrent(_OperationContext context) {
    if (!_isOperationCurrent(context)) {
      throw const _OperationContextChanged();
    }
  }

  void _adoptOperationSession(
    _OperationContext context,
    String sessionId,
  ) {
    if (!_isServerIdentityCurrent(context) ||
        _sessions?.currentSessionId != sessionId) {
      throw const _OperationContextChanged();
    }
    _stateEpoch += 1;
    context.epoch = _stateEpoch;
    context.sessionId = sessionId;
    _dependencyKey = '${context.server.contextRevision}|'
        '${context.serverUrl}|${context.accountId}|$sessionId';
    _clearScopedState();
  }

  Future<T> _serializeLiveDraft<T>(Future<T> Function() action) {
    if (_operationInProgress) {
      return Future<T>.error(
        StateError('COLLABORATION_OPERATION_IN_PROGRESS'),
      );
    }
    final queuedEpoch = _stateEpoch;
    return _liveDraftSerial.run(() async {
      if (_operationInProgress || queuedEpoch != _stateEpoch) {
        throw StateError('COLLABORATION_OPERATION_IN_PROGRESS');
      }
      return action();
    });
  }

  void _runLiveDraftInBackground(Future<void> operation) {
    unawaited(() async {
      try {
        await operation;
      } catch (_) {
        // Background refresh, persistence, and lease renewal are best effort.
        // In particular, a device-local destructive action intentionally
        // rejects work queued after its operation barrier was raised.
      }
    }());
  }

  _LiveDraftContext _requireLiveDraftContext({required bool requireEdit}) {
    final context = _tryLiveDraftContext(requireEdit: requireEdit);
    if (context == null) {
      throw StateError(
        requireEdit ? 'LIVE_DRAFT_READ_ONLY' : 'LIVE_DRAFT_CONTEXT_MISMATCH',
      );
    }
    return context;
  }

  _LiveDraftContext? _tryLiveDraftContext({required bool requireEdit}) {
    final server = _server;
    final binding = _binding;
    final deviceId = _deviceId;
    if (server == null ||
        binding == null ||
        deviceId == null ||
        !canViewLiveDraft ||
        (requireEdit && !canEditLiveDraft)) {
      return null;
    }
    return (
      api: server.api,
      binding: binding,
      deviceId: deviceId,
      epoch: _stateEpoch,
    );
  }

  _LiveDraftGuard _guardFor(_LiveDraftContext context) => (
        binding: context.binding,
        epoch: context.epoch,
      );

  _LiveDraftGuard? _tryLiveDraftGuard() {
    final binding = _binding;
    if (_operationInProgress ||
        binding == null ||
        binding.sessionId != _sessions?.currentSessionId) {
      return null;
    }
    return (binding: binding, epoch: _stateEpoch);
  }

  bool _isLiveDraftGuardCurrent(_LiveDraftGuard guard) {
    return isLiveDraftResultContextCurrent(
      disposed: _disposed,
      operationInProgress: _operationInProgress,
      expectedEpoch: guard.epoch,
      currentEpoch: _stateEpoch,
      expectedBinding: guard.binding,
      currentBinding: _binding,
      currentSessionId: _sessions?.currentSessionId,
    );
  }

  void _assertLiveDraftGuardCurrent(_LiveDraftGuard guard) {
    if (!_isLiveDraftGuardCurrent(guard)) {
      throw StateError('LIVE_DRAFT_CONTEXT_CHANGED');
    }
  }

  bool _isLiveDraftContextCurrent(_LiveDraftContext context) {
    return _isLiveDraftGuardCurrent(_guardFor(context));
  }

  void _assertLiveDraftContextCurrent(_LiveDraftContext context) {
    if (!_isLiveDraftContextCurrent(context)) {
      throw StateError('LIVE_DRAFT_CONTEXT_CHANGED');
    }
  }

  Future<void> _refreshLogsAfterLiveDraftCommit({
    required _LiveDraftContext context,
    required CollaborationEventDto event,
    required String syncId,
  }) async {
    bool contextIsCurrent() => _isLiveDraftContextCurrent(context);

    if (!contextIsCurrent()) return;
    final coordinator = _syncCoordinator;
    if (coordinator != null) {
      try {
        final synchronized = await coordinator.synchronizeNow(
          targetSeq: event.seq,
          timeout: const Duration(seconds: 1),
        );
        if (synchronized && contextIsCurrent()) {
          await _logs?.reconcileStagedCanonicalLog(syncId);
          return;
        }
        if (!contextIsCurrent()) return;
      } catch (error, stackTrace) {
        if (!contextIsCurrent()) return;
        debugPrint(
          '[Collaboration] awaited live-draft refresh failed: '
          '$error\n$stackTrace',
        );
      }
    }
    if (!contextIsCurrent()) return;
    coordinator?.wake();
  }

  void _stageCommittedLiveDraftLog(
    CollaborationLogDto canonical,
    CollaborationEventDto event,
  ) {
    _recordLogAuthorshipFromEvent(event);
    _logs?.stageCanonicalLog(
      LogEntry(
        id: canonical.syncId,
        sessionId: canonical.sessionId,
        time: canonical.time.toUtc().toIso8601String(),
        controller: canonical.controller,
        callsign: canonical.callsign,
        report: canonical.rstSent ?? '',
        rstRcvd: canonical.rstRcvd ?? '',
        qth: canonical.qth ?? '',
        device: canonical.device ?? '',
        power: canonical.power ?? '',
        antenna: canonical.antenna ?? '',
        height: canonical.height ?? '',
        remarks: canonical.remarks ?? '',
        createdAt: canonical.createdAt.toUtc().toIso8601String(),
        updatedAt: canonical.updatedAt.toUtc().toIso8601String(),
        deletedAt: canonical.deletedAt?.toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> _hydrateLiveDraftCacheIfEmpty(
    LocalCollaborationBinding binding,
    bool Function() isCurrent,
  ) async {
    if (_liveDraftSnapshot != null || _localLiveDraftFields != null) return;
    try {
      final cachedJson = await RustApi.getCollaborationLiveDraftCache(
        serverInstanceId: binding.serverInstanceId,
        accountId: binding.accountId,
        sessionId: binding.sessionId,
      );
      if (!isCurrent() || cachedJson == null) return;
      final cached = Map<String, Object?>.from(
        jsonDecode(cachedJson) as Map,
      );
      final remote = cached['remote'];
      if (remote != null) {
        _liveDraftSnapshot = LiveDraftSnapshotDto.fromJson(remote);
        if (remote is Map) {
          final remoteValues = Map<String, Object?>.from(remote);
          final cachedAutomaticTime =
              remoteValues['_clientAutomaticTimeSuppression'];
          if (cachedAutomaticTime is Map) {
            final value = Map<String, Object?>.from(cachedAutomaticTime);
            final draftId = value['draftId'];
            final displayMinute = value['displayMinute'];
            final maxTimeRevision = value['maxTimeRevision'];
            if (draftId is String &&
                displayMinute is String &&
                maxTimeRevision is int &&
                draftId == _liveDraftSnapshot?.draft.draftId) {
              _automaticLiveDraftTime = _AutomaticLiveDraftTimeMarker(
                draftId: draftId,
                displayMinute: displayMinute,
                maxTimeRevision: maxTimeRevision,
              );
            }
          }
        }
      }
      _localLiveDraftFields = LiveDraftFieldsDto.fromJson(
        cached['localFields'],
      );
      _dirtyLiveDraftFields = {
        for (final value in List<Object?>.from(
          cached['dirtyFields'] as List? ?? const [],
        ))
          if (liveDraftFieldNames.contains(value.toString())) value.toString(),
      };
      final cachedRevisions = cached['fieldRevisions'];
      if (cachedRevisions is Map) {
        final values = Map<String, Object?>.from(cachedRevisions);
        _liveDraftBaseRevisions = {
          for (final field in _dirtyLiveDraftFields)
            if (values[field] is int) field: values[field]! as int,
        };
      } else {
        _liveDraftBaseRevisions = const {};
      }
      final cachedClientSeq = cached['clientSeq'] as int? ?? 0;
      _liveDraftClientSeq = max(_liveDraftClientSeq, cachedClientSeq);
      _safeNotify();
    } catch (_) {
      // A corrupt or old cache is non-authoritative; the server snapshot
      // remains the source of truth.
    }
  }

  Future<void> _loadLiveDraftOfflineRecords(
    LocalCollaborationBinding binding,
    bool Function() isCurrent,
  ) async {
    final offlineJson = await RustApi.listCollaborationOfflineRecords(
      serverInstanceId: binding.serverInstanceId,
      accountId: binding.accountId,
      sessionId: binding.sessionId,
    );
    if (!isCurrent()) return;
    final offlineValues = jsonDecode(offlineJson);
    if (offlineValues is! List) {
      throw const FormatException('offline record list must be an array');
    }
    _offlineRecords = List.unmodifiable(
      offlineValues.map(LocalOfflineRecordDto.fromJson),
    );
  }

  Future<void> _refreshLiveDraftForBinding(
    LocalCollaborationBinding binding, {
    required int requestGeneration,
    required bool hydrateCache,
  }) async {
    final server = _server;
    final deviceId = _deviceId;
    if (server == null || deviceId == null) {
      if (requestGeneration == _liveDraftGeneration) {
        _liveDraftLoading = false;
        _safeNotify();
      }
      return;
    }
    final context = (
      api: server.api,
      binding: binding,
      deviceId: deviceId,
      epoch: _stateEpoch,
    );
    bool isCurrent() =>
        requestGeneration == _liveDraftGeneration &&
        _isLiveDraftContextCurrent(context);

    _liveDraftLoading = true;
    _safeNotify();
    try {
      if (hydrateCache) {
        await _hydrateLiveDraftCacheIfEmpty(binding, isCurrent);
      }

      if (!isCurrent()) return;
      await _loadLiveDraftOfflineRecords(binding, isCurrent);
      if (!isCurrent()) return;
      final previousSnapshot = _liveDraftSnapshot;
      final incomingSnapshot =
          await context.api.getLiveDraft(binding.sessionId);
      if (!isCurrent()) return;
      final snapshot = previousSnapshot == null
          ? incomingSnapshot
          : selectLiveDraftSnapshotAfterRefresh(
              current: previousSnapshot,
              incoming: incomingSnapshot,
            );
      final previousDraftId = previousSnapshot?.draft.draftId;
      var displacedLocalDraft = false;
      final previousLocalFields = _localLiveDraftFields;
      if (previousSnapshot != null &&
          previousLocalFields != null &&
          previousDraftId != snapshot.draft.draftId) {
        displacedLocalDraft =
            await _preserveCurrentDisplacedLiveDraftUntilStable(
          context: context,
          snapshot: previousSnapshot,
        );
        if (!isCurrent()) return;
      }
      final preserveLocal = previousDraftId == snapshot.draft.draftId &&
          _localLiveDraftFields != null &&
          _dirtyLiveDraftFields.isNotEmpty;
      if (previousDraftId != null &&
          previousDraftId != snapshot.draft.draftId) {
        _clearOwnedLiveDraftLocks();
      }
      final canAdoptIncomingPreview = previousSnapshot == null ||
          incomingSnapshot.draft.draftId != previousSnapshot.draft.draftId ||
          incomingSnapshot.draft.version >= previousSnapshot.draft.version;
      if (canAdoptIncomingPreview) {
        final preview = incomingSnapshot.historyPreview;
        _liveDraftHistoryPreview = preview != null &&
                preview.draftId == snapshot.draft.draftId &&
                preview.callsign == snapshot.draft.fields['callsign'] &&
                preview.expiresAt.isAfter(DateTime.now())
            ? preview
            : null;
        final adoptedPreview = _liveDraftHistoryPreview;
        if (adoptedPreview == null) {
          _cancelLiveDraftHistoryPreviewExpiry();
        } else {
          _scheduleLiveDraftHistoryPreviewExpiry(adoptedPreview);
        }
      }
      _liveDraftSnapshot = snapshot;
      _reconcileOwnedLiveDraftLocks(snapshot.locks);
      if (!preserveLocal) {
        _localLiveDraftFields = snapshot.draft.fields;
        _dirtyLiveDraftFields = const {};
        _liveDraftBaseRevisions = const {};
      } else {
        final local = _localLiveDraftFields!;
        _localLiveDraftFields = LiveDraftFieldsDto({
          for (final field in liveDraftFieldNames)
            field: _dirtyLiveDraftFields.contains(field)
                ? local[field]
                : snapshot.draft.fields[field],
        });
        _liveDraftBaseRevisions = {
          for (final field in _dirtyLiveDraftFields)
            field: _liveDraftBaseRevisions[field] ??
                previousSnapshot?.draft.fieldRevisions[field] ??
                0,
        };
      }
      _clearLiveDraftError();
      await _reconcilePendingOfflineRecords(context, isCurrent);
      if (!isCurrent()) return;
      await _persistLiveDraftState(_guardFor(context));
      if (displacedLocalDraft) _setDisplacedLiveDraftWarning();
    } on ServerApiException catch (error) {
      if (isCurrent()) _setLiveDraftError(error.code, error.message);
    } catch (error) {
      if (isCurrent()) {
        _setLiveDraftError('LIVE_DRAFT_REFRESH_FAILED', error.toString());
      }
    } finally {
      if (requestGeneration == _liveDraftGeneration) {
        _liveDraftLoading = false;
        _safeNotify();
      }
    }
  }

  Future<LiveDraftLockDto> _acquireLiveDraftFieldInternal(
    String field,
    _LiveDraftContext context,
  ) async {
    final current = _ownedLiveDraftLocks[field];
    if (current != null && current.expiresAt.isAfter(DateTime.now())) {
      return current;
    }
    final acquisition = await context.api.acquireLiveDraftLockWithDraft(
      sessionId: context.binding.sessionId,
      field: field,
      deviceId: context.deviceId,
    );
    _assertLiveDraftContextCurrent(context);
    final lock = acquisition.lock;
    late final ({bool revisionConflict, bool displacedLocalDraft}) adoption;
    try {
      adoption = await _adoptLiveDraftAtLockAcquisition(
        field,
        acquisition.draft,
        context,
      );
    } catch (error, stackTrace) {
      await _releaseTemporaryLiveDraftField(field, lock, context);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _ownedLiveDraftLocks = {..._ownedLiveDraftLocks, field: lock};
    _replaceLiveDraftLock(lock);
    if (adoption.revisionConflict) {
      await _releaseTemporaryLiveDraftField(field, lock, context);
      throw _liveDraftLockAcquisitionConflict(field, acquisition.draft!);
    }
    _ensureLiveDraftRenewalTimer();
    if (adoption.displacedLocalDraft) _setDisplacedLiveDraftWarning();
    return lock;
  }

  Future<LiveDraftPatchResultDto> _sendLiveDraftPatchWithControlAck({
    required _LiveDraftContext context,
    required int clientSeq,
    required List<LiveDraftPatchUpdateDto> updates,
  }) async {
    final draft = _liveDraftSnapshot?.draft;
    if (draft == null) throw StateError('LIVE_DRAFT_NOT_LOADED');
    final pending = _PendingLiveDraftPatchAck(
      sessionId: context.binding.sessionId,
      deviceId: context.deviceId,
      clientSeq: clientSeq,
      draftId: draft.draftId,
      expectedValues: Map<String, String>.unmodifiable({
        for (final update in updates)
          update.field: canonicalLiveDraftPatchAckValue(
            update.field,
            update.value,
          ),
      }),
      expectedRevisions: Map<String, int>.unmodifiable({
        for (final update in updates) update.field: update.expectedRevision,
      }),
    );
    _pendingLiveDraftPatchAcks[clientSeq] = pending;
    Future<LiveDraftPatchResultDto> resultFromControl() async {
      final acknowledgement = await pending.completer.future;
      _assertLiveDraftContextCurrent(context);
      return LiveDraftPatchResultDto(
        draft: acknowledgement.draft,
        appliedClientSeq: clientSeq,
        replayed: false,
        releasedLeases: acknowledgement.releasedLeases,
      );
    }

    final controlResult = resultFromControl();
    final httpResult = context.api.updateLiveDraft(
      sessionId: context.binding.sessionId,
      deviceId: context.deviceId,
      clientSeq: clientSeq,
      updates: updates,
    );
    try {
      // A precise member control proves the same durable mutation as the HTTP
      // body. Racing them avoids waiting for the full request timeout when a
      // proxy drops only the response after the server already committed.
      return await Future.any<LiveDraftPatchResultDto>([
        httpResult,
        controlResult,
      ]);
    } on ServerApiException catch (error, stackTrace) {
      if (!error.retryable) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      try {
        return await controlResult.timeout(
          const Duration(milliseconds: 1200),
        );
      } on TimeoutException {
        Error.throwWithStackTrace(error, stackTrace);
      }
    } finally {
      if (identical(_pendingLiveDraftPatchAcks[clientSeq], pending)) {
        _pendingLiveDraftPatchAcks.remove(clientSeq);
      }
    }
  }

  Future<({bool revisionConflict, bool displacedLocalDraft})>
      _adoptLiveDraftAtLockAcquisition(
    String acquiredField,
    LiveDraftDto? incoming,
    _LiveDraftContext context,
  ) async {
    if (incoming == null) {
      return (revisionConflict: false, displacedLocalDraft: false);
    }
    final snapshot = _liveDraftSnapshot;
    final local = _localLiveDraftFields;
    if (snapshot == null || local == null) {
      return (revisionConflict: false, displacedLocalDraft: false);
    }
    final projection = projectLiveDraftLockAcquisition(
      acquiredField: acquiredField,
      currentDraft: snapshot.draft,
      incomingDraft: incoming,
      localFields: local,
      dirtyFields: _dirtyLiveDraftFields,
      baseRevisions: _liveDraftBaseRevisions,
    );
    var displacedLocalDraft = false;
    if (projection.generationChanged) {
      // A commit or discard may have advanced the generation while the lock
      // request crossed the network. The acquired lease belongs to the new
      // generation; preserve old local edits before adopting it.
      displacedLocalDraft = await _preserveCurrentDisplacedLiveDraftUntilStable(
        context: context,
        snapshot: snapshot,
      );
      _assertLiveDraftContextCurrent(context);
      _clearOwnedLiveDraftLocks();
      _automaticLiveDraftTime = null;
    }
    _liveDraftSnapshot = LiveDraftSnapshotDto(
      draft: projection.canonicalDraft,
      locks: projection.generationChanged
          ? const <LiveDraftLockDto>[]
          : snapshot.locks,
      currentOrdinal: snapshot.currentOrdinal,
      totalRecords: snapshot.totalRecords,
      previousRecord: snapshot.previousRecord,
    );
    _localLiveDraftFields = projection.localFields;
    _dirtyLiveDraftFields = projection.dirtyFields;
    _liveDraftBaseRevisions = projection.baseRevisions;
    return (
      revisionConflict: projection.conflictedFields.contains(acquiredField),
      displacedLocalDraft: displacedLocalDraft,
    );
  }

  ServerApiException _liveDraftLockAcquisitionConflict(
    String field,
    LiveDraftDto canonical,
  ) =>
      ServerApiException(
        error: ApiErrorDto(
          code: 'LIVE_DRAFT_FIELD_CONFLICT',
          message: 'The live draft field changed while acquiring its lock',
          requestId: 'client-lock-acquisition',
          details: {
            'field': field,
            'currentRevision': canonical.fieldRevisions[field] ?? 0,
            'draftVersion': canonical.version,
            'draftId': canonical.draftId,
            'draft': canonical.toJson(),
          },
        ),
        statusCode: 409,
        retryable: false,
      );

  void _adoptReleasedLiveDraftLeases(
    Iterable<LiveDraftReleasedLeaseDto> leases,
  ) {
    final released = leases.map((lease) => lease.leaseId).toSet();
    if (released.isEmpty) return;
    _ownedLiveDraftLocks = Map<String, LiveDraftLockDto>.unmodifiable({
      for (final entry in _ownedLiveDraftLocks.entries)
        if (!released.contains(entry.value.leaseId)) entry.key: entry.value,
    });
    final snapshot = _liveDraftSnapshot;
    if (snapshot != null) {
      _liveDraftSnapshot = LiveDraftSnapshotDto(
        draft: snapshot.draft,
        locks: List<LiveDraftLockDto>.unmodifiable(
          snapshot.locks.where(
            (lock) => !released.contains(lock.leaseId),
          ),
        ),
        currentOrdinal: snapshot.currentOrdinal,
        totalRecords: snapshot.totalRecords,
        previousRecord: snapshot.previousRecord,
      );
    }
    if (_ownedLiveDraftLocks.isEmpty) {
      _liveDraftRenewalTimer?.cancel();
      _liveDraftRenewalTimer = null;
    }
  }

  Future<void> _releaseLiveDraftLockWithBoundedRetry(
    LiveDraftLockDto lock,
    _LiveDraftContext context, {
    int maxAttempts = 2,
  }) async {
    for (var attempt = 1;; attempt += 1) {
      try {
        await context.api
            .releaseLiveDraftLock(
              sessionId: context.binding.sessionId,
              leaseId: lock.leaseId,
              deviceId: context.deviceId,
            )
            .timeout(const Duration(milliseconds: 1200));
        return;
      } on ServerApiException catch (error) {
        if ({'LIVE_DRAFT_LOCK_NOT_FOUND', 'LIVE_DRAFT_LOCK_EXPIRED'}
            .contains(error.code)) {
          return;
        }
        if (!error.retryable || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
      } on TimeoutException {
        if (attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
  }

  Future<void> _releaseOwnedLiveDraftFieldsAfterFailure(
    Iterable<String> fields,
    _LiveDraftContext context,
  ) async {
    final requested = fields.toSet();
    final locks = <LiveDraftLockDto>[
      for (final entry in _ownedLiveDraftLocks.entries)
        if (requested.contains(entry.key) &&
            entry.value.sessionId == context.binding.sessionId &&
            entry.value.deviceId == context.deviceId)
          entry.value,
    ];
    if (locks.isEmpty) return;
    final releasedIds = locks.map((lock) => lock.leaseId).toSet();
    _ownedLiveDraftLocks = Map<String, LiveDraftLockDto>.unmodifiable({
      for (final entry in _ownedLiveDraftLocks.entries)
        if (!releasedIds.contains(entry.value.leaseId)) entry.key: entry.value,
    });
    for (final leaseId in releasedIds) {
      _removeLiveDraftLock(leaseId);
    }
    if (_ownedLiveDraftLocks.isEmpty) {
      _liveDraftRenewalTimer?.cancel();
      _liveDraftRenewalTimer = null;
    }
    _safeNotify();
    for (final lock in locks) {
      try {
        await _releaseLiveDraftLockWithBoundedRetry(lock, context);
      } catch (_) {
        // Mutation failure remains primary. Local renewal has already stopped,
        // and a failed bounded cleanup expires naturally on the server.
      }
    }
  }

  Future<void> _releaseTemporaryLiveDraftField(
    String field,
    LiveDraftLockDto lock,
    _LiveDraftContext context,
  ) async {
    final current = _ownedLiveDraftLocks[field];
    if (current?.leaseId == lock.leaseId) {
      _ownedLiveDraftLocks = Map.of(_ownedLiveDraftLocks)..remove(field);
      _removeLiveDraftLock(lock.leaseId);
      if (_ownedLiveDraftLocks.isEmpty) {
        _liveDraftRenewalTimer?.cancel();
        _liveDraftRenewalTimer = null;
      }
    }
    try {
      await _releaseLiveDraftLockWithBoundedRetry(lock, context);
    } on ServerApiException catch (error) {
      if (!_isLiveDraftContextCurrent(context)) return;
      if (!{'LIVE_DRAFT_LOCK_NOT_FOUND', 'LIVE_DRAFT_LOCK_EXPIRED'}
          .contains(error.code)) {
        // This operation no longer depends on the temporary lease. A failed
        // cleanup is bounded by the server lease expiry and must not turn an
        // already atomic PATCH into an apparent mutation failure.
      }
    }
  }

  Future<void> _updateLiveDraftFieldsAtomically(
    Map<String, String> updates, {
    required bool retryRevisionConflicts,
    String? expectedDraftId,
    Map<String, String>? expectedValues,
    Map<String, int>? expectedRevisions,
  }) async {
    final context = _requireLiveDraftContext(requireEdit: true);
    try {
      if (retryRevisionConflicts) {
        await executeLiveDraftAtomicPatchWithRebaseRetry<void>(
          attempt: () => _updateLiveDraftFieldsAtomicAttempt(updates, context),
          rebase: (conflict) => _rebaseLiveDraftForAtomicRetry(
            updates.keys.toSet(),
            context,
            conflict: conflict,
          ),
        );
      } else {
        await _updateLiveDraftFieldsAtomicAttempt(
          updates,
          context,
          expectedDraftId: expectedDraftId,
          expectedValues: expectedValues,
          expectedRevisions: expectedRevisions,
        );
      }
    } on ServerApiException catch (error, stackTrace) {
      await _releaseOwnedLiveDraftFieldsAfterFailure(
        updates.keys,
        context,
      );
      if ({
        'LIVE_DRAFT_FIELD_CONFLICT',
        'LIVE_DRAFT_VERSION_CONFLICT',
      }.contains(error.code)) {
        AppLogger.instance.log(
          AppLogLevel.warning,
          'Atomic live-draft update still conflicted after bounded retries',
          source: 'CollaborationProvider',
          error: error,
          stackTrace: stackTrace,
        );
      }
      _setLiveDraftError(error.code, error.message);
      if (error.code == 'LIVE_DRAFT_LOCK_REQUIRED') {
        final details = error.details;
        final field = details is Map ? details['field'] : null;
        if (field is String) {
          final stale = _ownedLiveDraftLocks[field];
          _ownedLiveDraftLocks = Map.of(_ownedLiveDraftLocks)..remove(field);
          if (stale != null) _removeLiveDraftLock(stale.leaseId);
        }
      }
      if ({
        'LIVE_DRAFT_FIELD_CONFLICT',
        'LIVE_DRAFT_VERSION_CONFLICT',
        'LIVE_DRAFT_FIELD_LOCKED',
        'LIVE_DRAFT_LOCK_REQUIRED',
        'LIVE_DRAFT_CLIENT_SEQ_GAP',
        'LIVE_DRAFT_CLIENT_SEQ_REUSED',
      }.contains(error.code)) {
        _runLiveDraftInBackground(refreshLiveDraft());
      }
      await _persistLiveDraftState(_guardFor(context));
      rethrow;
    } catch (error, stackTrace) {
      await _releaseOwnedLiveDraftFieldsAfterFailure(
        updates.keys,
        context,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _updateLiveDraftFieldsAtomicAttempt(
    Map<String, String> updates,
    _LiveDraftContext context, {
    String? expectedDraftId,
    Map<String, String>? expectedValues,
    Map<String, int>? expectedRevisions,
  }) async {
    final snapshot = _liveDraftSnapshot;
    final local = _localLiveDraftFields;
    if (snapshot == null || local == null) {
      throw StateError('LIVE_DRAFT_NOT_LOADED');
    }
    if (expectedDraftId != null) {
      if (snapshot.draft.draftId != expectedDraftId) {
        throw StateError('LIVE_DRAFT_SUGGESTION_STALE');
      }
      for (final field in updates.keys) {
        if (local[field] != expectedValues?[field] ||
            snapshot.draft.fieldRevisions[field] != expectedRevisions?[field]) {
          throw StateError('LIVE_DRAFT_SUGGESTION_STALE');
        }
      }
    }

    final beforeDirtyFields = Set<String>.of(_dirtyLiveDraftFields);
    final beforeBaseRevisions = Map<String, int>.of(_liveDraftBaseRevisions);
    final targetFields = <String>{};
    final desiredValues = <String, String>{};
    final pendingFields = <String>[];
    for (final field in liveDraftFieldNames) {
      if (!updates.containsKey(field)) continue;
      final rawValue = updates[field]!;
      final value =
          field == 'time' ? _normalizeLiveDraftTime(rawValue) : rawValue;
      final localNeedsChange = local[field] != value;
      final remoteNeedsChange = snapshot.draft.fields[field] != value;
      if (!localNeedsChange &&
          !remoteNeedsChange &&
          !beforeDirtyFields.contains(field)) {
        continue;
      }
      targetFields.add(field);
      desiredValues[field] = value;
      if (remoteNeedsChange) pendingFields.add(field);
    }
    if (targetFields.isEmpty) return;

    final sentValues = {
      for (final field in pendingFields) field: desiredValues[field]!,
    };
    final sentRevisions = {
      for (final field in pendingFields)
        field: beforeDirtyFields.contains(field)
            ? (beforeBaseRevisions[field] ??
                snapshot.draft.fieldRevisions[field] ??
                0)
            : (snapshot.draft.fieldRevisions[field] ?? 0),
    };
    LiveDraftDto acceptedDraft = snapshot.draft;
    if (sentValues.isNotEmpty) {
      final execution = await executeLiveDraftAtomicPatch(
        values: sentValues,
        expectedRevisions: sentRevisions,
        ownedLocks: Map<String, LiveDraftLockDto>.of(_ownedLiveDraftLocks),
        nextClientSeq: _liveDraftClientSeq + 1,
        acquireLock: (field) async {
          final lock = await _acquireLiveDraftFieldInternal(field, context);
          if (_liveDraftSnapshot?.draft.draftId != snapshot.draft.draftId) {
            await _releaseTemporaryLiveDraftField(field, lock, context);
            throw StateError('LIVE_DRAFT_GENERATION_CHANGED');
          }
          if (expectedDraftId != null) {
            final canonical = _liveDraftSnapshot?.draft;
            if (canonical == null ||
                canonical.draftId != expectedDraftId ||
                canonical.fields[field] != expectedValues?[field] ||
                canonical.fieldRevisions[field] != expectedRevisions?[field]) {
              await _releaseTemporaryLiveDraftField(field, lock, context);
              throw StateError('LIVE_DRAFT_SUGGESTION_STALE');
            }
          }
          sentRevisions[field] = _liveDraftBaseRevisions[field] ??
              _liveDraftSnapshot?.draft.fieldRevisions[field] ??
              sentRevisions[field]!;
          return lock;
        },
        sendPatch: (clientSeq, updates) => _sendLiveDraftPatchWithControlAck(
          context: context,
          clientSeq: clientSeq,
          updates: updates,
        ),
        releaseLock: (field, lock) =>
            _releaseTemporaryLiveDraftField(field, lock, context),
        onClientSeqChanged: (value) => _liveDraftClientSeq = value,
        assertCurrent: () => _assertLiveDraftContextCurrent(context),
      );
      _assertLiveDraftContextCurrent(context);
      _adoptReleasedLiveDraftLeases(execution.result.releasedLeases);
      acceptedDraft = execution.result.draft;
    }

    final currentSnapshot = _liveDraftSnapshot;
    final currentLocal = _localLiveDraftFields;
    if (currentSnapshot == null || currentLocal == null) return;
    final currentDraft = currentSnapshot.draft;
    final canonicalDraft = selectLiveDraftCanonicalAfterAtomicPatch(
      current: currentDraft,
      accepted: acceptedDraft,
    );
    final merged = mergeAcceptedLiveDraftAtomicPatch(
      targetFields: targetFields,
      beforeLocalFields: local,
      beforeDirtyFields: beforeDirtyFields,
      beforeBaseRevisions: beforeBaseRevisions,
      currentLocalFields: currentLocal,
      currentDirtyFields: _dirtyLiveDraftFields,
      currentBaseRevisions: _liveDraftBaseRevisions,
      canonicalDraft: canonicalDraft,
    );
    _dirtyLiveDraftFields = merged.dirtyFields;
    _liveDraftBaseRevisions = merged.baseRevisions;
    _localLiveDraftFields = merged.localFields;
    if (!identical(canonicalDraft, currentDraft)) {
      _liveDraftSnapshot = LiveDraftSnapshotDto(
        draft: canonicalDraft,
        locks: currentSnapshot.locks,
        currentOrdinal: currentSnapshot.currentOrdinal,
        totalRecords: currentSnapshot.totalRecords,
        previousRecord: currentSnapshot.previousRecord,
      );
    }
    _clearLiveDraftError();
    await _persistLiveDraftState(_guardFor(context));
    _safeNotify();
  }

  Future<void> _rebaseLiveDraftForAtomicRetry(
    Set<String> targetFields,
    _LiveDraftContext context, {
    ServerApiException? conflict,
  }) async {
    final currentBeforeRead = _liveDraftSnapshot;
    final conflictDraft = conflict == null
        ? null
        : liveDraftCanonicalFromConflict(
            conflict,
            sessionId: context.binding.sessionId,
          );
    final incoming = conflictDraft == null
        ? await context.api.getLiveDraft(context.binding.sessionId)
        : LiveDraftSnapshotDto(
            draft: conflictDraft,
            locks: currentBeforeRead?.locks ?? const <LiveDraftLockDto>[],
            currentOrdinal: currentBeforeRead?.currentOrdinal ?? 1,
            totalRecords: currentBeforeRead?.totalRecords ?? 0,
            previousRecord: currentBeforeRead?.previousRecord,
          );
    _assertLiveDraftContextCurrent(context);
    final current = _liveDraftSnapshot;
    final local = _localLiveDraftFields;
    if (current == null || local == null) {
      throw StateError('LIVE_DRAFT_NOT_LOADED');
    }
    final rebased = selectLiveDraftSnapshotAfterRefresh(
      current: current,
      incoming: incoming,
    );
    if (current.draft.draftId != rebased.draft.draftId) {
      final displacedLocalDraft =
          await _preserveCurrentDisplacedLiveDraftUntilStable(
        context: context,
        snapshot: current,
      );
      _assertLiveDraftContextCurrent(context);
      _clearOwnedLiveDraftLocks();
      _liveDraftSnapshot = rebased;
      _localLiveDraftFields = rebased.draft.fields;
      _dirtyLiveDraftFields = const {};
      _liveDraftBaseRevisions = const {};
      if (displacedLocalDraft) _setDisplacedLiveDraftWarning();
      return;
    }

    final dirtyFields = Set<String>.of(_dirtyLiveDraftFields);
    final baseRevisions = Map<String, int>.of(_liveDraftBaseRevisions);
    final conflictedTargetFields = <String>{};
    for (final field in List<String>.from(dirtyFields)) {
      if (local[field] == rebased.draft.fields[field]) {
        dirtyFields.remove(field);
        baseRevisions.remove(field);
      } else if (targetFields.contains(field)) {
        final previousRevision =
            baseRevisions[field] ?? current.draft.fieldRevisions[field] ?? 0;
        final incomingRevision = rebased.draft.fieldRevisions[field] ?? 0;
        if (incomingRevision != previousRevision) {
          // A retry may absorb an unrelated version bump, but it must never
          // turn a same-field conflict into last-writer-wins.
          conflictedTargetFields.add(field);
          baseRevisions[field] = previousRevision;
        } else {
          baseRevisions[field] = incomingRevision;
        }
      }
    }
    _liveDraftSnapshot = rebased;
    _dirtyLiveDraftFields = Set<String>.unmodifiable(dirtyFields);
    _liveDraftBaseRevisions = Map<String, int>.unmodifiable(baseRevisions);
    _localLiveDraftFields = LiveDraftFieldsDto({
      for (final field in liveDraftFieldNames)
        field: dirtyFields.contains(field)
            ? local[field]
            : rebased.draft.fields[field],
    });
    if (conflict != null && conflictedTargetFields.isNotEmpty) {
      throw conflict;
    }
  }

  Future<void> _flushLiveDraftField(
    String field, {
    int remainingRevisionConflictRetries = 3,
  }) async {
    final context = _requireLiveDraftContext(requireEdit: true);
    final snapshot = _liveDraftSnapshot;
    final local = _localLiveDraftFields;
    if (snapshot == null || local == null) {
      throw StateError('LIVE_DRAFT_NOT_LOADED');
    }
    if (!_dirtyLiveDraftFields.contains(field)) return;
    if (local[field] == snapshot.draft.fields[field]) {
      _dirtyLiveDraftFields = Set.of(_dirtyLiveDraftFields)..remove(field);
      _liveDraftBaseRevisions = Map.of(_liveDraftBaseRevisions)..remove(field);
      await _persistLiveDraftState(_guardFor(context));
      return;
    }
    final beforeDirtyFields = Set<String>.of(_dirtyLiveDraftFields);
    final beforeBaseRevisions = Map<String, int>.of(_liveDraftBaseRevisions);
    final sentValue = local[field];
    final sentRevision =
        beforeBaseRevisions[field] ?? snapshot.draft.fieldRevisions[field] ?? 0;
    final sentRevisions = <String, int>{field: sentRevision};
    try {
      // Use the same lease lifecycle as a multi-field patch. In particular,
      // an implicit write such as an auto-generated time must release the
      // temporary lock it acquired instead of leaving other devices blocked.
      final execution = await executeLiveDraftAtomicPatch(
        values: {field: sentValue},
        expectedRevisions: sentRevisions,
        ownedLocks: Map<String, LiveDraftLockDto>.of(_ownedLiveDraftLocks),
        nextClientSeq: _liveDraftClientSeq + 1,
        acquireLock: (field) async {
          final lock = await _acquireLiveDraftFieldInternal(field, context);
          if (_liveDraftSnapshot?.draft.draftId != snapshot.draft.draftId) {
            await _releaseTemporaryLiveDraftField(field, lock, context);
            throw StateError('LIVE_DRAFT_GENERATION_CHANGED');
          }
          sentRevisions[field] = _liveDraftBaseRevisions[field] ??
              _liveDraftSnapshot?.draft.fieldRevisions[field] ??
              sentRevisions[field]!;
          return lock;
        },
        sendPatch: (clientSeq, updates) => _sendLiveDraftPatchWithControlAck(
          context: context,
          clientSeq: clientSeq,
          updates: updates,
        ),
        releaseLock: (field, lock) =>
            _releaseTemporaryLiveDraftField(field, lock, context),
        onClientSeqChanged: (value) => _liveDraftClientSeq = value,
        assertCurrent: () => _assertLiveDraftContextCurrent(context),
      );
      _assertLiveDraftContextCurrent(context);
      _adoptReleasedLiveDraftLeases(execution.result.releasedLeases);
      final currentSnapshot = _liveDraftSnapshot;
      final currentLocal = _localLiveDraftFields;
      if (currentSnapshot == null || currentLocal == null) return;
      final currentDraft = currentSnapshot.draft;
      final canonicalDraft = selectLiveDraftCanonicalAfterAtomicPatch(
        current: currentDraft,
        accepted: execution.result.draft,
      );
      final merged = mergeAcceptedLiveDraftAtomicPatch(
        targetFields: {field},
        beforeLocalFields: local,
        beforeDirtyFields: beforeDirtyFields,
        beforeBaseRevisions: beforeBaseRevisions,
        currentLocalFields: currentLocal,
        currentDirtyFields: _dirtyLiveDraftFields,
        currentBaseRevisions: _liveDraftBaseRevisions,
        canonicalDraft: canonicalDraft,
      );
      _dirtyLiveDraftFields = merged.dirtyFields;
      _liveDraftBaseRevisions = merged.baseRevisions;
      _localLiveDraftFields = merged.localFields;
      if (!identical(canonicalDraft, currentDraft)) {
        _liveDraftSnapshot = LiveDraftSnapshotDto(
          draft: canonicalDraft,
          locks: currentSnapshot.locks,
          currentOrdinal: currentSnapshot.currentOrdinal,
          totalRecords: currentSnapshot.totalRecords,
          previousRecord: currentSnapshot.previousRecord,
        );
      }
      _clearLiveDraftError();
      await _persistLiveDraftState(_guardFor(context));
      _safeNotify();
    } on ServerApiException catch (error, stackTrace) {
      if (remainingRevisionConflictRetries > 0 &&
          {
            'LIVE_DRAFT_FIELD_CONFLICT',
            'LIVE_DRAFT_VERSION_CONFLICT',
          }.contains(error.code)) {
        try {
          await _rebaseLiveDraftForAtomicRetry(
            {field},
            context,
            conflict: error,
          );
          _assertLiveDraftContextCurrent(context);
        } on ServerApiException catch (rebaseError) {
          await _releaseOwnedLiveDraftFieldsAfterFailure(
            {field},
            context,
          );
          _setLiveDraftError(rebaseError.code, rebaseError.message);
          await _persistLiveDraftState(_guardFor(context));
          rethrow;
        }
        await _flushLiveDraftField(
          field,
          remainingRevisionConflictRetries:
              remainingRevisionConflictRetries - 1,
        );
        return;
      }
      await _releaseOwnedLiveDraftFieldsAfterFailure({field}, context);
      if ({
        'LIVE_DRAFT_FIELD_CONFLICT',
        'LIVE_DRAFT_VERSION_CONFLICT',
      }.contains(error.code)) {
        AppLogger.instance.log(
          AppLogLevel.warning,
          'Live-draft field $field still conflicted after bounded retries',
          source: 'CollaborationProvider',
          error: error,
          stackTrace: stackTrace,
        );
      }
      _setLiveDraftError(error.code, error.message);
      if (error.code == 'LIVE_DRAFT_LOCK_REQUIRED') {
        final stale = _ownedLiveDraftLocks[field];
        _ownedLiveDraftLocks = Map.of(_ownedLiveDraftLocks)..remove(field);
        if (stale != null) _removeLiveDraftLock(stale.leaseId);
      }
      if ({
        'LIVE_DRAFT_FIELD_CONFLICT',
        'LIVE_DRAFT_VERSION_CONFLICT',
        'LIVE_DRAFT_FIELD_LOCKED',
        'LIVE_DRAFT_LOCK_REQUIRED',
        'LIVE_DRAFT_CLIENT_SEQ_GAP',
        'LIVE_DRAFT_CLIENT_SEQ_REUSED',
      }.contains(error.code)) {
        _runLiveDraftInBackground(refreshLiveDraft());
      }
      await _persistLiveDraftState(_guardFor(context));
      rethrow;
    } catch (error, stackTrace) {
      await _releaseOwnedLiveDraftFieldsAfterFailure({field}, context);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _flushDirtyLiveDraftFields() async {
    for (final field in List<String>.from(_dirtyLiveDraftFields)) {
      await _flushLiveDraftField(field);
    }
  }

  Future<void> _copyOfflineRecordIntoCurrentDraft(
    LocalOfflineRecordDto record,
    _LiveDraftContext context,
  ) async {
    final snapshot = _liveDraftSnapshot;
    if (snapshot == null) throw StateError('LIVE_DRAFT_NOT_LOADED');
    _localLiveDraftFields = record.record;
    _dirtyLiveDraftFields = {
      for (final field in liveDraftFieldNames)
        if (record.record[field] != snapshot.draft.fields[field]) field,
    };
    _liveDraftBaseRevisions = {
      for (final field in _dirtyLiveDraftFields)
        field: snapshot.draft.fieldRevisions[field] ?? 0,
    };
    for (final field in List<String>.from(_dirtyLiveDraftFields)) {
      await _flushLiveDraftField(field);
    }
  }

  Future<bool> _preserveDisplacedLiveDraft({
    required _LiveDraftContext context,
    required LiveDraftSnapshotDto snapshot,
    required LiveDraftFieldsDto localFields,
    required Set<String> dirtyFields,
    LiveDraftFieldsDto? acceptedFields,
  }) async {
    if (!hasUnpreservedLiveDraftChanges(
      currentDraft: snapshot.draft,
      localFields: localFields,
      dirtyFields: dirtyFields,
      acceptedFields: acceptedFields,
    )) {
      return false;
    }

    final existing = _offlineRecords.any(
      (record) =>
          record.draftId == snapshot.draft.draftId &&
          record.state != OfflineRecordState.resolved &&
          record.state != OfflineRecordState.discarded &&
          liveDraftFieldNames.every(
            (field) =>
                canonicalLiveDraftPatchAckValue(
                  field,
                  record.record[field],
                ) ==
                canonicalLiveDraftPatchAckValue(
                  field,
                  localFields[field],
                ),
          ),
    );
    if (existing) return true;

    final queued = await _queueOfflineRecord(
      context,
      mutationId: _uuidV4(),
      snapshot: snapshot,
      fields: localFields,
    );
    _offlineRecords = List<LocalOfflineRecordDto>.unmodifiable([
      for (final candidate in _offlineRecords)
        if (candidate.mutationId != queued.mutationId) candidate,
      queued,
    ]);

    // This copy belongs to the previous draft generation and must never be
    // submitted automatically into the new one. Mark it for explicit review;
    // if that secondary write fails, keeping the durable pending copy is still
    // safer and the next refresh will classify it from the generation mismatch.
    try {
      await _updateOfflineRecord(
        queued,
        state: OfflineRecordState.reviewing,
        resolution: null,
        lastErrorCode: 'OFFLINE_RECORD_OVERLAPS_SERVER_PROGRESS',
        guard: _guardFor(context),
      );
    } catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        'Saved displaced live draft but could not mark it for review',
        source: 'CollaborationProvider',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  /// Local keystrokes are projected synchronously and intentionally bypass the
  /// network serial queue. Keep sampling until no keystroke occurred while the
  /// recovery copy was being written, so adopting a new generation cannot
  /// overwrite a value that arrived during that await.
  Future<bool> _preserveCurrentDisplacedLiveDraftUntilStable({
    required _LiveDraftContext context,
    required LiveDraftSnapshotDto snapshot,
    LiveDraftFieldsDto? acceptedFields,
  }) async {
    var displaced = false;
    while (true) {
      _assertLiveDraftContextCurrent(context);
      final localFields = _localLiveDraftFields;
      if (localFields == null ||
          _liveDraftSnapshot?.draft.draftId != snapshot.draft.draftId) {
        return displaced;
      }
      final localEditRevision = _liveDraftLocalEditRevision;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      _assertLiveDraftContextCurrent(context);
      if (_liveDraftLocalEditRevision != localEditRevision) continue;
      displaced = await _preserveDisplacedLiveDraft(
            context: context,
            snapshot: snapshot,
            localFields: localFields,
            dirtyFields: Set<String>.of(_dirtyLiveDraftFields),
            acceptedFields: acceptedFields,
          ) ||
          displaced;
      _assertLiveDraftContextCurrent(context);
      if (_liveDraftLocalEditRevision == localEditRevision) return displaced;
    }
  }

  void _setDisplacedLiveDraftWarning() {
    _setLiveDraftError(
      'LIVE_DRAFT_GENERATION_CHANGED_LOCAL_COPY_QUEUED',
      '点名草稿已切换到下一位；本机尚未同步完成的输入已保存到待恢复记录，请确认后再处理。',
    );
  }

  Future<LocalOfflineRecordDto> _queueOfflineRecord(
    _LiveDraftContext context, {
    required String mutationId,
    required LiveDraftSnapshotDto snapshot,
    required LiveDraftFieldsDto fields,
  }) async {
    final encoded = await RustApi.queueCollaborationOfflineRecord(
      requestJson: jsonEncode({
        'serverInstanceId': context.binding.serverInstanceId,
        'accountId': context.binding.accountId,
        'sessionId': context.binding.sessionId,
        'mutationId': mutationId,
        'draftId': snapshot.draft.draftId,
        'expectedDraftVersion': snapshot.draft.version,
        'provisionalOrdinal': snapshot.currentOrdinal,
        'record': fields.toJson(),
      }),
    );
    _assertLiveDraftContextCurrent(context);
    return LocalOfflineRecordDto.fromJson(jsonDecode(encoded));
  }

  Future<void> _updateOfflineRecord(
    LocalOfflineRecordDto record, {
    required OfflineRecordState state,
    required OfflineRecordResolution? resolution,
    required _LiveDraftGuard guard,
    String? lastErrorCode,
  }) async {
    _assertLiveDraftGuardCurrent(guard);
    final encoded = await RustApi.updateCollaborationOfflineRecord(
      requestJson: jsonEncode({
        'mutationId': record.mutationId,
        'state': state.name,
        'resolution': resolution?.name,
        'lastErrorCode': lastErrorCode,
      }),
    );
    _assertLiveDraftGuardCurrent(guard);
    final updated = LocalOfflineRecordDto.fromJson(jsonDecode(encoded));
    _offlineRecords = List.unmodifiable([
      for (final candidate in _offlineRecords)
        if (candidate.mutationId != updated.mutationId) candidate,
      if (state != OfflineRecordState.resolved &&
          state != OfflineRecordState.discarded)
        updated,
    ]);
    _safeNotify();
  }

  Future<void> _reconcilePendingOfflineRecords(
    _LiveDraftContext context,
    bool Function() isCurrent,
  ) async {
    final membership = _membership;
    if (membership == null ||
        membership.removedAt != null ||
        membership.role == SessionRole.viewer) {
      return;
    }
    final binding = context.binding;
    final guard = _guardFor(context);
    bool contextIsCurrent() =>
        isCurrent() && _isLiveDraftContextCurrent(context);
    for (final record in List<LocalOfflineRecordDto>.from(_offlineRecords)) {
      if (!contextIsCurrent()) break;
      if (record.state != OfflineRecordState.pending &&
          record.state != OfflineRecordState.submitting) {
        continue;
      }
      final snapshot = _liveDraftSnapshot;
      if (snapshot == null) break;
      final serverUnchanged = record.draftId == snapshot.draft.draftId &&
          record.expectedDraftVersion == snapshot.draft.version;
      if (!serverUnchanged) {
        await _updateOfflineRecord(
          record,
          state: OfflineRecordState.reviewing,
          resolution: null,
          lastErrorCode: 'OFFLINE_RECORD_OVERLAPS_SERVER_PROGRESS',
          guard: guard,
        );
        if (!contextIsCurrent()) return;
        continue;
      }
      var continuation =
          _dirtyLiveDraftFields.isEmpty ? null : _localLiveDraftFields;
      var continuationEditRevisions =
          Map<String, int>.of(_liveDraftLocalFieldEditRevisions);
      var replacedFormWithOfflineRecord = false;
      LiveDraftFieldsDto mergedContinuation(
        LiveDraftFieldsDto canonicalFields,
      ) {
        final latestFields = _localLiveDraftFields;
        return LiveDraftFieldsDto({
          for (final field in liveDraftFieldNames)
            field: (_liveDraftLocalFieldEditRevisions[field] ?? 0) >
                        (continuationEditRevisions[field] ?? 0) &&
                    latestFields != null
                ? latestFields[field]
                : continuation?[field] ?? canonicalFields[field],
        });
      }

      void adoptContinuation(LiveDraftDto canonicalDraft) {
        final merged = mergedContinuation(canonicalDraft.fields);
        _localLiveDraftFields = merged;
        _dirtyLiveDraftFields = {
          for (final field in liveDraftFieldNames)
            if (merged[field] != canonicalDraft.fields[field]) field,
        };
        _liveDraftBaseRevisions = {
          for (final field in _dirtyLiveDraftFields)
            field: canonicalDraft.fieldRevisions[field] ?? 0,
        };
      }

      void restoreContinuation() {
        if (!replacedFormWithOfflineRecord) return;
        final canonical = _liveDraftSnapshot;
        if (canonical == null) return;
        adoptContinuation(canonical.draft);
        _safeNotify();
      }

      try {
        await _updateOfflineRecord(
          record,
          state: OfflineRecordState.submitting,
          resolution: null,
          guard: guard,
        );
        if (!contextIsCurrent()) return;
        // Any keystroke made while the state marker was persisted still
        // belongs to the continuation. Capture it before temporarily showing
        // the queued record itself.
        continuation =
            _dirtyLiveDraftFields.isEmpty ? null : _localLiveDraftFields;
        continuationEditRevisions =
            Map<String, int>.of(_liveDraftLocalFieldEditRevisions);
        replacedFormWithOfflineRecord = true;
        await _copyOfflineRecordIntoCurrentDraft(
          record,
          context,
        );
        if (!contextIsCurrent()) return;
        final canonical = _liveDraftSnapshot;
        if (canonical == null) throw StateError('LIVE_DRAFT_NOT_LOADED');
        final committed = await context.api.commitLiveDraft(
          sessionId: binding.sessionId,
          deviceId: context.deviceId,
          expectedDraftVersion: canonical.draft.version,
          syncId: record.mutationId,
          idempotencyKey: record.mutationId,
        );
        if (!contextIsCurrent()) return;
        _stageCommittedLiveDraftLog(committed.record, committed.event);
        _liveDraftSnapshot = LiveDraftSnapshotDto(
          draft: committed.nextDraft,
          locks: const [],
          currentOrdinal: committed.currentOrdinal,
          totalRecords: committed.totalRecords,
          previousRecord: committed.record,
        );
        _clearOwnedLiveDraftLocks();
        adoptContinuation(committed.nextDraft);
        await _updateOfflineRecord(
          record,
          state: OfflineRecordState.resolved,
          resolution: OfflineRecordResolution.submitAsDuplicate,
          guard: guard,
        );
        if (!contextIsCurrent()) return;
        await _refreshLogsAfterLiveDraftCommit(
          context: context,
          event: committed.event,
          syncId: committed.record.syncId,
        );
        if (!contextIsCurrent()) return;
      } on ServerApiException catch (error) {
        if (!contextIsCurrent()) return;
        restoreContinuation();
        if (error.retryable) {
          await _updateOfflineRecord(
            record,
            state: OfflineRecordState.pending,
            resolution: null,
            lastErrorCode: error.code,
            guard: guard,
          );
          return;
        }
        await _updateOfflineRecord(
          record,
          state: OfflineRecordState.reviewing,
          resolution: null,
          lastErrorCode: error.code,
          guard: guard,
        );
        if (!contextIsCurrent()) return;
      } catch (error, stackTrace) {
        if (contextIsCurrent()) restoreContinuation();
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  String _normalizeLiveDraftTime(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null && normalized.contains('T')) {
      return parsed.toUtc().toIso8601String();
    }
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(normalized);
    if (match == null) return normalized;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final second = int.parse(match.group(3) ?? '0');
    if (hour > 23 || minute > 59 || second > 59) return normalized;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, second)
        .toUtc()
        .toIso8601String();
  }

  bool _liveDraftHasActualContent(LiveDraftFieldsDto fields) {
    bool hasText(String field) => fields[field].trim().isNotEmpty;
    bool hasNonDefaultReport(String field) {
      final value = fields[field].trim();
      return value.isNotEmpty && value != '59';
    }

    return const [
          'callsign',
          'qth',
          'device',
          'power',
          'antenna',
          'height',
          'remarks',
        ].any(hasText) ||
        hasNonDefaultReport('rstSent') ||
        hasNonDefaultReport('rstRcvd');
  }

  Future<void> _persistLiveDraftState(_LiveDraftGuard guard) async {
    _assertLiveDraftGuardCurrent(guard);
    final binding = _binding;
    final snapshot = _liveDraftSnapshot;
    final local = _localLiveDraftFields;
    if (binding == null || snapshot == null || local == null) return;
    final remoteCache = Map<String, Object?>.from(snapshot.toJson());
    final automaticTime = _automaticLiveDraftTime;
    if (automaticTime != null) {
      remoteCache['_clientAutomaticTimeSuppression'] = {
        'draftId': automaticTime.draftId,
        'displayMinute': automaticTime.displayMinute,
        'maxTimeRevision': automaticTime.maxTimeRevision,
      };
    }
    try {
      await RustApi.saveCollaborationLiveDraftCache(
        requestJson: jsonEncode({
          'serverInstanceId': binding.serverInstanceId,
          'accountId': binding.accountId,
          'sessionId': binding.sessionId,
          'draftId': snapshot.draft.draftId,
          'draftVersion': snapshot.draft.version,
          'remote': remoteCache,
          'localFields': local.toJson(),
          'fieldRevisions': {
            for (final field in liveDraftFieldNames)
              field: _dirtyLiveDraftFields.contains(field)
                  ? (_liveDraftBaseRevisions[field] ??
                      snapshot.draft.fieldRevisions[field] ??
                      0)
                  : (snapshot.draft.fieldRevisions[field] ?? 0),
          },
          'dirtyFields': _dirtyLiveDraftFields.toList(growable: false),
          'clientSeq': _liveDraftClientSeq,
          'remoteUpdatedAt':
              snapshot.draft.lastUpdatedAt.toUtc().toIso8601String(),
        }),
      );
      _assertLiveDraftGuardCurrent(guard);
    } catch (error) {
      if (!_isLiveDraftGuardCurrent(guard)) {
        throw StateError('LIVE_DRAFT_CONTEXT_CHANGED');
      }
      _setLiveDraftError('LIVE_DRAFT_CACHE_FAILED', error.toString());
    }
  }

  void _replaceLiveDraftLock(LiveDraftLockDto lock) {
    final snapshot = _liveDraftSnapshot;
    if (snapshot == null) return;
    _liveDraftSnapshot = LiveDraftSnapshotDto(
      draft: snapshot.draft,
      locks: List.unmodifiable([
        for (final candidate in snapshot.locks)
          if (candidate.field != lock.field &&
              candidate.leaseId != lock.leaseId)
            candidate,
        lock,
      ]),
      currentOrdinal: snapshot.currentOrdinal,
      totalRecords: snapshot.totalRecords,
      previousRecord: snapshot.previousRecord,
    );
  }

  void _removeLiveDraftLock(String leaseId) {
    final snapshot = _liveDraftSnapshot;
    if (snapshot == null) return;
    _liveDraftSnapshot = LiveDraftSnapshotDto(
      draft: snapshot.draft,
      locks: List.unmodifiable(
        snapshot.locks.where((lock) => lock.leaseId != leaseId),
      ),
      currentOrdinal: snapshot.currentOrdinal,
      totalRecords: snapshot.totalRecords,
      previousRecord: snapshot.previousRecord,
    );
  }

  void _reconcileOwnedLiveDraftLocks(List<LiveDraftLockDto> canonicalLocks) {
    _ownedLiveDraftLocks = reconcileOwnedLiveDraftLocks(
      owned: _ownedLiveDraftLocks,
      canonical: canonicalLocks,
    );
    if (_ownedLiveDraftLocks.isEmpty) {
      _liveDraftRenewalTimer?.cancel();
      _liveDraftRenewalTimer = null;
    }
  }

  void _ensureLiveDraftRenewalTimer() {
    _liveDraftRenewalTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _runLiveDraftInBackground(
        _serializeLiveDraft(_renewOwnedLiveDraftLocks),
      ),
    );
  }

  Future<void> _renewOwnedLiveDraftLocks() async {
    final context = _tryLiveDraftContext(requireEdit: true);
    if (context == null) {
      _clearOwnedLiveDraftLocks();
      return;
    }
    for (final entry in List<MapEntry<String, LiveDraftLockDto>>.from(
      _ownedLiveDraftLocks.entries,
    )) {
      try {
        final renewed = await context.api.renewLiveDraftLock(
          sessionId: context.binding.sessionId,
          leaseId: entry.value.leaseId,
          deviceId: context.deviceId,
        );
        _assertLiveDraftContextCurrent(context);
        _ownedLiveDraftLocks = {..._ownedLiveDraftLocks, entry.key: renewed};
        _replaceLiveDraftLock(renewed);
      } on ServerApiException catch (error) {
        _ownedLiveDraftLocks = Map.of(_ownedLiveDraftLocks)..remove(entry.key);
        _removeLiveDraftLock(entry.value.leaseId);
        _setLiveDraftError(error.code, error.message);
      }
    }
    if (_ownedLiveDraftLocks.isEmpty) {
      _liveDraftRenewalTimer?.cancel();
      _liveDraftRenewalTimer = null;
    }
    _safeNotify();
  }

  void _clearOwnedLiveDraftLocks() {
    _liveDraftRenewalTimer?.cancel();
    _liveDraftRenewalTimer = null;
    _ownedLiveDraftLocks = const {};
  }

  void _setLiveDraftError(String code, String message) {
    _liveDraftErrorCode = code;
    _liveDraftErrorMessage = message;
    _safeNotify();
  }

  void _clearLiveDraftError() {
    _liveDraftErrorCode = null;
    _liveDraftErrorMessage = null;
  }

  void _startSynchronization(
    LocalCollaborationBinding binding,
    MembershipDto membership, {
    required bool sessionClosed,
  }) {
    final server = _server;
    final sessions = _sessions;
    final logs = _logs;
    final deviceId = _deviceId;
    if (server == null ||
        sessions == null ||
        logs == null ||
        deviceId == null ||
        sessions.currentSessionId != binding.sessionId ||
        server.accountId != binding.accountId ||
        server.serverInfo?.serverInstanceId != binding.serverInstanceId) {
      logs?.setCollaborationReadOnly(binding.sessionId, true);
      return;
    }

    _stopSynchronization();
    final generation = ++_syncGeneration;
    final identity = CollaborationSyncIdentity(
      serverInstanceId: binding.serverInstanceId,
      serverOrigin: binding.serverOrigin,
      accountId: binding.accountId,
      sessionId: binding.sessionId,
      deviceId: deviceId,
    );
    AppLogger.instance.log(
      AppLogLevel.info,
      'Starting collaboration synchronization for session '
      '${binding.sessionId} as ${membership.role.name}',
      source: 'CollaborationProvider',
    );
    late final CollaborationSyncCoordinator coordinator;
    Future<void> reloadReplicaProjection() async {
      if (!_isSyncCurrent(generation, identity, coordinator)) return;
      await sessions.reloadCurrentSession();
      if (!_isSyncCurrent(generation, identity, coordinator)) return;
      await logs.reloadForSession(
        binding.sessionId,
        propagateErrors: true,
      );
    }

    Future<void> reloadExternallyAdvancedProjection() async {
      await reloadReplicaProjection();
      if (!_isSyncCurrent(generation, identity, coordinator)) return;
      final snapshot = await server.api.getSessionSnapshot(binding.sessionId);
      if (!_isSyncCurrent(generation, identity, coordinator)) return;
      _adoptLogAuthorship(snapshot.logs);
      _invalidateOpenConflicts(identity);
    }

    coordinator = CollaborationSyncCoordinator(
      transport: ServerApiCollaborationSyncTransport(server.api),
      replica: _replica,
      sockets: _sockets,
      onStateChanged: (state) {
        if (!_isSyncCurrent(generation, identity, coordinator)) return;
        final previousRole = _syncState?.role ?? _membership?.role;
        final previousConflictCount = _syncState?.conflictCount;
        final previousTransport = _syncState?.transportPhase;
        final previousReplica = _syncState?.replicaPhase;
        final previousErrorCode = _syncState?.lastErrorCode;
        _syncState = state;
        switch (state.replicaPhase) {
          case CollaborationReplicaPhase.catchingUp:
            _state = CollaborationState.catchingUp;
          case CollaborationReplicaPhase.ready:
            _state = CollaborationState.ready;
          case CollaborationReplicaPhase.resyncing:
            _state = CollaborationState.resyncing;
          case CollaborationReplicaPhase.revoked:
            _state = CollaborationState.revoked;
            _membership = null;
            _members = const [];
            _invites = const [];
            _lastCreatedInvite = null;
          case CollaborationReplicaPhase.failed:
            _state = CollaborationState.failed;
          case CollaborationReplicaPhase.localOnly:
            _state = CollaborationState.localOnly;
        }
        logs.setCollaborationReadOnly(binding.sessionId, !state.canEdit);
        if (previousTransport != state.transportPhase ||
            previousReplica != state.replicaPhase ||
            previousErrorCode != state.lastErrorCode) {
          final level = state.replicaPhase ==
                      CollaborationReplicaPhase.failed ||
                  state.transportPhase ==
                      CollaborationTransportPhase.incompatible
              ? AppLogLevel.error
              : state.transportPhase ==
                          CollaborationTransportPhase.backingOff ||
                      state.transportPhase ==
                          CollaborationTransportPhase.authRequired ||
                      state.replicaPhase == CollaborationReplicaPhase.revoked
                  ? AppLogLevel.warning
                  : AppLogLevel.info;
          AppLogger.instance.log(
            level,
            'Sync state session=${binding.sessionId} '
            'transport=${state.transportPhase.name} '
            'replica=${state.replicaPhase.name} '
            'cursor=${state.lastAppliedSeq}/${state.serverHeadSeq} '
            'pending=${state.pendingCount} conflicts=${state.conflictCount}'
            '${state.lastErrorCode == null ? '' : ' error=${state.lastErrorCode}'}',
            source: 'CollaborationSync',
          );
        }
        _safeNotify();
        if (state.conflictCount == 0) {
          if (_openConflicts.isNotEmpty ||
              !_conflictsLoaded ||
              _conflictsLoading ||
              _conflictsNeedRefresh ||
              _conflictReloadScheduled) {
            _conflictRequestGeneration += 1;
            _conflictInvalidationGeneration += 1;
            _openConflicts = const [];
            _conflictsLoaded = true;
            _conflictsLoading = false;
            _conflictsNeedRefresh = false;
            _conflictReloadScheduled = false;
            _safeNotify();
          }
        } else if (state.replicaPhase == CollaborationReplicaPhase.ready &&
            !_conflictsLoading &&
            (!_conflictsLoaded ||
                _openConflicts.length != state.conflictCount ||
                previousConflictCount != state.conflictCount ||
                _conflictsNeedRefresh)) {
          _scheduleOpenConflictReload(identity);
        }
        if (state.role != null && state.role != previousRole) {
          _invalidateOpenConflicts(identity);
          _scheduleRefresh();
        }
        if (shouldRefreshLiveDraftAfterTransportTransition(
          previousTransport,
          state.transportPhase,
        )) {
          // Member controls are intentionally not replayed. One canonical GET
          // after each initial connection/reconnection closes that gap without
          // multiplying reads for every keystroke and lock notification.
          _runLiveDraftInBackground(refreshLiveDraft());
        }
      },
      onEventApplied: (event) async {
        if (!_isSyncCurrent(generation, identity, coordinator)) return;
        final terminalClear = terminalLiveDraftClearControlFromEvent(event);
        if (terminalClear != null) {
          await _applyLiveDraftControl(terminalClear);
          if (!_isSyncCurrent(generation, identity, coordinator)) return;
        }
        _recordLogAuthorshipFromEvent(event);
        if (collaborationEventMayAffectOpenConflicts(
          event: event,
          openConflicts: _openConflicts,
          reportedConflictCount: _syncState?.conflictCount ?? 0,
        )) {
          _invalidateOpenConflicts(identity);
        }
        await reloadReplicaProjection();
      },
      onSnapshotInstalled: (snapshot) async {
        if (!_isSyncCurrent(generation, identity, coordinator)) return;
        _adoptLogAuthorship(snapshot.logs);
        _invalidateOpenConflicts(identity);
        await reloadReplicaProjection();
      },
      onReplicaChanged: reloadExternallyAdvancedProjection,
      onControlMessage: (message) async {
        if (!_isSyncCurrent(generation, identity, coordinator)) return;
        // Observe our own mutation before entering the serialized projection
        // queue. A PATCH whose HTTP response was lost is still acknowledged by
        // this control; waiting for _applyLiveDraftControl here would deadlock
        // behind the in-flight PATCH operation itself.
        _observeLiveDraftPatchControlAck(message);
        await _applyLiveDraftControl(message);
      },
      onLocalCloseRejected: (mutation, result) async {
        if (!_isSyncCurrent(generation, identity, coordinator)) return false;
        try {
          // The server remains active when it rejects a close because the live
          // draft is non-empty or locked. Reopening locally removes the
          // rejected close chain and restores the materialized Session from its
          // canonical active shadow without emitting a spurious remote reopen.
          await RustApi.reopenCollaborationSession(
            sessionId: binding.sessionId,
          );
          if (!_isSyncCurrent(generation, identity, coordinator)) return false;
          await sessions.reloadCurrentSession();
          if (!_isSyncCurrent(generation, identity, coordinator)) return false;
          _setError(
            result.code ?? 'LIVE_DRAFT_CLOSE_REJECTED',
            result.message ?? '草稿尚未清空，关闭请求已撤销',
          );
          return true;
        } catch (error) {
          if (_isSyncCurrent(generation, identity, coordinator)) {
            _setError(
              'LOCAL_CLOSE_ROLLBACK_FAILED',
              '服务器拒绝关闭会话，本地状态恢复失败：$error',
            );
            _safeNotify();
          }
          return false;
        }
      },
    );
    _syncCoordinator = coordinator;
    logs.setOnDataChanged(() async {
      if (_isSyncCurrent(generation, identity, coordinator)) {
        _markUnpublishedLocalLogsOwned(logs, identity.accountId);
        coordinator.wake();
      }
    });
    coordinator.start(
      identity: identity,
      role: membership.role,
      sessionClosed: sessionClosed,
    );
  }

  bool _isSyncCurrent(
    int generation,
    CollaborationSyncIdentity identity,
    CollaborationSyncCoordinator coordinator,
  ) {
    final server = _server;
    return !_disposed &&
        generation == _syncGeneration &&
        identical(_syncCoordinator, coordinator) &&
        _binding?.serverInstanceId == identity.serverInstanceId &&
        _binding?.serverOrigin == identity.serverOrigin &&
        _binding?.accountId == identity.accountId &&
        _binding?.sessionId == identity.sessionId &&
        server?.accountId == identity.accountId &&
        server?.serverUrl == identity.serverOrigin &&
        server?.serverInfo?.serverInstanceId == identity.serverInstanceId &&
        _sessions?.currentSessionId == identity.sessionId;
  }

  CollaborationSyncIdentity? _currentConflictIdentity() {
    final identity = _syncState?.identity;
    final binding = _binding;
    final membership = _membership;
    final server = _server;
    if (_disposed ||
        identity == null ||
        binding == null ||
        membership == null ||
        _syncState?.replicaPhase != CollaborationReplicaPhase.ready ||
        binding.replicaState != 'ready' ||
        binding.serverInstanceId != identity.serverInstanceId ||
        binding.serverOrigin != identity.serverOrigin ||
        binding.accountId != identity.accountId ||
        binding.sessionId != identity.sessionId ||
        membership.membershipId != binding.membershipId ||
        membership.sessionId != identity.sessionId ||
        membership.userId != identity.accountId ||
        membership.removedAt != null ||
        server?.serverUrl != identity.serverOrigin ||
        server?.accountId != identity.accountId ||
        server?.serverInfo?.serverInstanceId != identity.serverInstanceId ||
        _sessions?.currentSessionId != identity.sessionId) {
      return null;
    }
    return identity;
  }

  bool _isConflictRequestCurrent(
    int requestGeneration,
    CollaborationSyncIdentity identity,
  ) =>
      requestGeneration == _conflictRequestGeneration &&
      _currentConflictIdentity() == identity;

  void _resetConflictState() {
    _conflictRequestGeneration += 1;
    _conflictInvalidationGeneration += 1;
    _openConflicts = const [];
    _conflictsLoaded = false;
    _conflictsLoading = false;
    _conflictsNeedRefresh = false;
    _conflictReloadScheduled = false;
    _resolvingConflictId = null;
  }

  CollaborationSyncCoordinator? _detachSynchronization() {
    _syncGeneration += 1;
    _resetConflictState();
    final binding = _binding;
    if (binding != null) {
      _logs?.setCollaborationReadOnly(binding.sessionId, true);
    }
    _logs?.setOnDataChanged(null);
    final coordinator = _syncCoordinator;
    _syncCoordinator = null;
    _syncState = null;
    return coordinator;
  }

  ({Future<void> liveDraft, Future<void> synchronization})
      _suspendForDeviceLocalMutation() {
    // The caller has already raised _operationInProgress and advanced the state
    // epoch, so queued draft work cannot begin after this snapshot.
    final liveDraft = _liveDraftSerial.detach();
    final suspensionEpoch = _stateEpoch;
    final suspensionBinding = _binding;
    _liveDraftGeneration += 1;
    final suspensionGeneration = _liveDraftGeneration;
    _clearOwnedLiveDraftLocks();
    final coordinator = _detachSynchronization();
    final synchronization = coordinator?.dispose() ?? Future<void>.value();
    _clearStaleLiveDraftAfterSettled(
      liveDraft,
      suspensionEpoch: suspensionEpoch,
      suspensionGeneration: suspensionGeneration,
      suspensionBinding: suspensionBinding,
    );
    return (liveDraft: liveDraft, synchronization: synchronization);
  }

  void _clearStaleLiveDraftAfterSettled(
    Future<void> pending, {
    required int suspensionEpoch,
    required int suspensionGeneration,
    required LocalCollaborationBinding? suspensionBinding,
  }) {
    unawaited(() async {
      try {
        await pending;
      } catch (_) {
        // The original caller already owns the operation error.
      }
      if (_disposed) return;
      // A later refresh, rejoin, or draft request owns its own projection.
      // Never let the detached chain erase that newer state when it eventually
      // settles.
      if (_stateEpoch != suspensionEpoch) return;
      final currentBinding = _binding;
      // A completed local replacement has no binding, so a late stale
      // projection can always be cleared even though _clearScopedState already
      // advanced the generation once. A restored/refreshed collaboration owns
      // its newer generation and must be left intact.
      if (currentBinding != null &&
          (_liveDraftGeneration != suspensionGeneration ||
              suspensionBinding == null ||
              currentBinding.serverInstanceId !=
                  suspensionBinding.serverInstanceId ||
              currentBinding.accountId != suspensionBinding.accountId ||
              currentBinding.sessionId != suspensionBinding.sessionId)) {
        return;
      }
      // An in-flight response may have projected stale draft data after the
      // source replica was removed. Clear that projection a second time once
      // the pre-detach serial queue has actually settled.
      _clearLiveDraftProjection();
      _safeNotify();
    }());
  }

  void _stopSynchronization() {
    final coordinator = _detachSynchronization();
    if (coordinator != null) unawaited(coordinator.dispose());
  }

  void _adoptLogAuthorship(Iterable<CollaborationLogDto> logs) {
    _logCreatedBy
      ..clear()
      ..addEntries(
        logs.map((log) => MapEntry(log.syncId, log.createdBy)),
      );
    _logs?.refreshMutationPermissions();
  }

  void _recordLogAuthorshipFromEvent(CollaborationEventDto event) {
    if (event.entityType != 'log') return;
    final payload = event.payload;
    final createdBy = payload['createdBy'];
    _logCreatedBy[event.entityId] =
        createdBy is String && createdBy.isNotEmpty ? createdBy : null;
  }

  void _markUnpublishedLocalLogsOwned(LogProvider logs, String? accountId) {
    if (accountId == null) return;
    var changed = false;
    for (final log in logs.logs) {
      if (!_logCreatedBy.containsKey(log.id)) {
        _logCreatedBy[log.id] = accountId;
        changed = true;
      }
    }
    if (changed) logs.refreshMutationPermissions();
  }

  void _clearScopedState() {
    _stopSynchronization();
    _clearLiveDraftProjection();
    _publicShares = const [];
    _lastCreatedPublicShare = null;
    _logCreatedBy.clear();
    _logs?.refreshMutationPermissions();
    _binding = null;
    _membership = null;
    _members = const [];
    _invites = const [];
    _lastCreatedInvite = null;
    _failedOperation = null;
    _progressLabel = '';
    _progress = null;
    _clearError();
    _state = _publishingSessionId != null &&
            _publishingSessionId == _sessions?.currentSessionId
        ? CollaborationState.publishing
        : CollaborationState.localOnly;
  }

  bool _isUnsupportedLiveDraftHistoryPreviewError(ServerApiException error) {
    return error.statusCode == 404 ||
        const {
          'NOT_FOUND',
          'ROUTE_NOT_FOUND',
          'METHOD_NOT_ALLOWED',
        }.contains(error.code);
  }

  void _cancelLiveDraftHistoryPreviewExpiry() {
    _liveDraftHistoryPreviewExpiryTimer?.cancel();
    _liveDraftHistoryPreviewExpiryTimer = null;
  }

  void _scheduleLiveDraftHistoryPreviewExpiry(
    LiveDraftHistoryPreviewDto preview,
  ) {
    _cancelLiveDraftHistoryPreviewExpiry();
    if (preview.deviceId != _deviceId) return;
    final remaining = preview.expiresAt.difference(DateTime.now());
    _liveDraftHistoryPreviewExpiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () {
        _liveDraftHistoryPreviewExpiryTimer = null;
        _runLiveDraftInBackground(
          _serializeLiveDraft(() async {
            final current = _liveDraftHistoryPreview;
            if (current?.previewId != preview.previewId ||
                current?.deviceId != _deviceId) {
              return;
            }
            _liveDraftHistoryPreview = null;
            final context = _tryLiveDraftContext(requireEdit: false);
            final lock = _ownedLiveDraftLocks['callsign'];
            if (context != null &&
                lock != null &&
                !_dirtyLiveDraftFields.contains('callsign')) {
              final release =
                  _releaseTemporaryLiveDraftField('callsign', lock, context);
              _safeNotify();
              await release;
              return;
            }
            _safeNotify();
          }),
        );
      },
    );
  }

  void _recordLiveDraftHistoryReuse(
    LiveDraftHistoryReuseDto historyReuse,
    LiveDraftDto draft,
  ) {
    final token = '${draft.sessionId}:${draft.draftId}:${draft.version}:'
        '${historyReuse.previewId}:${historyReuse.candidateId}';
    if (_lastLiveDraftHistoryReuseToken == token) return;
    _lastLiveDraftHistoryReuseToken = token;
    _liveDraftHistoryReuseAffectedFields =
        Set<String>.unmodifiable(historyReuse.affectedFields);
    _liveDraftHistoryReuseEpoch += 1;
  }

  void _clearLiveDraftProjection() {
    _liveDraftGeneration += 1;
    _clearOwnedLiveDraftLocks();
    _liveDraftSnapshot = null;
    _localLiveDraftFields = null;
    _automaticLiveDraftTime = null;
    _dirtyLiveDraftFields = const {};
    _liveDraftBaseRevisions = const {};
    _offlineRecords = const [];
    _liveDraftHistoryPreview = null;
    _cancelLiveDraftHistoryPreviewExpiry();
    _liveDraftHistoryReuseAffectedFields = const {};
    _lastLiveDraftHistoryReuseToken = null;
    _liveDraftHistoryPreviewUnavailable = false;
    _liveDraftClientSeq = 0;
    _liveDraftLoading = false;
    _clearLiveDraftError();
  }

  ServerProvider _requireServer() {
    final server = _server;
    if (server == null) throw StateError('服务器尚未初始化');
    return server;
  }

  SessionProvider _requireSessions() {
    final sessions = _sessions;
    if (sessions == null) throw StateError('会话尚未初始化');
    return sessions;
  }

  LogProvider _requireLogs() {
    final logs = _logs;
    if (logs == null) throw StateError('日志尚未初始化');
    return logs;
  }

  String _requireAccountId(ServerProvider server) {
    final accountId = server.accountId;
    if (accountId == null) throw StateError('请先登录服务器');
    return accountId;
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    scheduleMicrotask(() async {
      _refreshScheduled = false;
      final epoch = _stateEpoch;
      final refreshGeneration = _refreshGeneration + 1;
      try {
        await refreshCurrentSession();
      } catch (error) {
        if (epoch == _stateEpoch &&
            refreshGeneration == _refreshGeneration &&
            !_operationInProgress) {
          _setError(_localErrorCode(error), error.toString());
          _safeNotify();
        }
      }
    });
  }

  void _setProgress(String label, double value) {
    _progressLabel = label;
    _progress = value < 0 ? 0 : (value > 1 ? 1 : value);
    _safeNotify();
  }

  void _setError(String code, String message) {
    _errorCode = code;
    _errorMessage = message;
  }

  void _clearError() {
    _errorCode = null;
    _errorMessage = null;
  }

  String _localErrorCode(Object error) {
    final text = error.toString();
    final match = RegExp(r'([A-Z][A-Z0-9_]{3,})').firstMatch(text);
    return match?.group(1) ?? 'COLLABORATION_FAILED';
  }

  CollaborationState _stateFromReplica(String value) => switch (value) {
        'publishing' => CollaborationState.publishing,
        'joining' => CollaborationState.joining,
        'snapshotting' => CollaborationState.snapshotting,
        'catchingUp' => CollaborationState.catchingUp,
        'ready' => CollaborationState.ready,
        'resyncing' => CollaborationState.resyncing,
        'revoked' => CollaborationState.revoked,
        'failed' => CollaborationState.failed,
        _ => CollaborationState.failed,
      };

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _stopSynchronization();
    _liveDraftRenewalTimer?.cancel();
    _liveDraftRenewalTimer = null;
    _cancelLiveDraftHistoryPreviewExpiry();
    _pendingLiveDraftPatchAcks.clear();
    _catalogTimer?.cancel();
    _logs?.setLogMutationGuard(null);
    _disposed = true;
    super.dispose();
  }
}
