import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/collaboration_conflict.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/services/collaboration_sync.dart';
import 'package:openlogtool/services/server_api.dart';

void main() {
  group('log authorship permissions', () {
    test('local sessions are not restricted by collaboration authorship', () {
      expect(
        collaborationLogMutationBlockReason(
          collaborationBound: false,
          canEditSession: true,
          sharedEditingSupported: false,
          accountId: 'user-1',
          authorshipKnown: false,
          createdBy: null,
        ),
        isNull,
      );
    });

    test('viewer, unknown author, and another author remain read-only', () {
      expect(
        collaborationLogMutationBlockReason(
          collaborationBound: true,
          canEditSession: false,
          sharedEditingSupported: false,
          accountId: 'user-1',
          authorshipKnown: true,
          createdBy: 'user-1',
        ),
        'COLLABORATION_SESSION_READ_ONLY',
      );
      expect(
        collaborationLogMutationBlockReason(
          collaborationBound: true,
          canEditSession: true,
          sharedEditingSupported: false,
          accountId: 'user-1',
          authorshipKnown: true,
          createdBy: null,
        ),
        'COLLABORATION_LOG_AUTHOR_UNKNOWN',
      );
      expect(
        collaborationLogMutationBlockReason(
          collaborationBound: true,
          canEditSession: true,
          sharedEditingSupported: false,
          accountId: 'user-1',
          authorshipKnown: true,
          createdBy: 'user-2',
        ),
        'COLLABORATION_LOG_NOT_OWNED',
      );
    });

    test('owner or editor can mutate a log only when authorship matches', () {
      expect(
        collaborationLogMutationBlockReason(
          collaborationBound: true,
          canEditSession: true,
          sharedEditingSupported: false,
          accountId: 'user-1',
          authorshipKnown: true,
          createdBy: 'user-1',
        ),
        isNull,
      );
    });

    test('shared editing lets owners and editors mutate every session log', () {
      for (final authorship in <({bool known, String? createdBy})>[
        (known: false, createdBy: null),
        (known: true, createdBy: null),
        (known: true, createdBy: 'user-2'),
      ]) {
        expect(
          collaborationLogMutationBlockReason(
            collaborationBound: true,
            canEditSession: true,
            sharedEditingSupported: true,
            accountId: 'user-1',
            authorshipKnown: authorship.known,
            createdBy: authorship.createdBy,
          ),
          isNull,
        );
      }
    });

    test('shared editing does not grant write access to read-only members', () {
      expect(
        collaborationLogMutationBlockReason(
          collaborationBound: true,
          canEditSession: false,
          sharedEditingSupported: true,
          accountId: 'user-1',
          authorshipKnown: true,
          createdBy: 'user-1',
        ),
        'COLLABORATION_SESSION_READ_ONLY',
      );
    });
  });

  test('conflict invalidation follows entity and session event scope', () {
    final conflicts = [_logConflict()];

    expect(
      collaborationEventMayAffectOpenConflicts(
        event: _event(entityType: 'log', entityId: 'log-1'),
        openConflicts: conflicts,
        reportedConflictCount: 1,
      ),
      isTrue,
    );
    expect(
      collaborationEventMayAffectOpenConflicts(
        event: _event(entityType: 'log', entityId: 'log-other'),
        openConflicts: conflicts,
        reportedConflictCount: 1,
      ),
      isFalse,
    );
    expect(
      collaborationEventMayAffectOpenConflicts(
        event: _event(entityType: 'session', entityId: 'session-1'),
        openConflicts: conflicts,
        reportedConflictCount: 1,
      ),
      isTrue,
    );
  });

  test('pending initial conflict list invalidates conservatively', () {
    expect(
      collaborationEventMayAffectOpenConflicts(
        event: _event(entityType: 'log', entityId: 'log-other'),
        openConflicts: const [],
        reportedConflictCount: 1,
      ),
      isTrue,
    );
    expect(
      collaborationEventMayAffectOpenConflicts(
        event: _event(entityType: 'session', entityId: 'session-1'),
        openConflicts: const [],
        reportedConflictCount: 0,
      ),
      isFalse,
    );
  });

  group('atomic live-draft updates', () {
    test('uses field order, one PATCH, and releases only new locks', () async {
      final acquired = <String>[];
      final released = <String>[];
      final patchFields = <String>[];
      var patchCount = 0;
      final existingQth = _lock('qth', 'existing-qth');

      final execution = await executeLiveDraftAtomicPatch(
        values: const {
          'antenna': 'Yagi',
          'device': 'IC-705',
          'qth': 'Shanghai',
        },
        expectedRevisions: const {
          'antenna': 2,
          'device': 3,
          'qth': 4,
        },
        ownedLocks: {'qth': existingQth},
        nextClientSeq: 5,
        now: DateTime.utc(2026, 7, 13),
        acquireLock: (field) async {
          acquired.add(field);
          return _lock(field, 'new-$field');
        },
        sendPatch: (clientSeq, updates) async {
          patchCount += 1;
          expect(clientSeq, 5);
          patchFields.addAll(updates.map((update) => update.field));
          expect(
            updates.map((update) => update.expectedRevision),
            orderedEquals([4, 3, 2]),
          );
          expect(updates.first.leaseId, existingQth.leaseId);
          return _patchResult(clientSeq);
        },
        releaseLock: (field, _) async => released.add(field),
        onClientSeqChanged: (_) {},
      );

      expect(execution.appliedClientSeq, 5);
      expect(acquired, ['device', 'antenna']);
      expect(patchCount, 1);
      expect(patchFields, ['qth', 'device', 'antenna']);
      expect(released, ['antenna', 'device']);
    });

    test('an acquisition failure sends no PATCH and unwinds new locks',
        () async {
      final acquired = <String>[];
      final released = <String>[];
      var patchCount = 0;

      await expectLater(
        executeLiveDraftAtomicPatch(
          values: const {
            'qth': 'Shanghai',
            'device': 'IC-705',
            'antenna': 'Yagi',
          },
          expectedRevisions: const {
            'qth': 0,
            'device': 0,
            'antenna': 0,
          },
          ownedLocks: const {},
          nextClientSeq: 1,
          acquireLock: (field) async {
            acquired.add(field);
            if (field == 'device') {
              throw _serverError('LIVE_DRAFT_FIELD_LOCKED');
            }
            return _lock(field, 'new-$field');
          },
          sendPatch: (_, __) async {
            patchCount += 1;
            return _patchResult(1);
          },
          releaseLock: (field, _) async => released.add(field),
          onClientSeqChanged: (_) {},
        ),
        throwsA(
          isA<ServerApiException>().having(
            (error) => error.code,
            'code',
            'LIVE_DRAFT_FIELD_LOCKED',
          ),
        ),
      );

      expect(acquired, ['qth', 'device']);
      expect(patchCount, 0);
      expect(released, ['qth']);
    });

    test('local-exit invalidation after a stalled lock prevents PATCH',
        () async {
      final acquireStarted = Completer<void>();
      final acquireResult = Completer<LiveDraftLockDto>();
      final released = <String>[];
      var current = true;
      var patchCount = 0;

      final operation = executeLiveDraftAtomicPatch(
        values: const {'callsign': 'BG5CRL'},
        expectedRevisions: const {'callsign': 1},
        ownedLocks: const {},
        nextClientSeq: 1,
        acquireLock: (_) {
          acquireStarted.complete();
          return acquireResult.future;
        },
        sendPatch: (_, __) async {
          patchCount += 1;
          return _patchResult(1);
        },
        releaseLock: (field, _) async => released.add(field),
        onClientSeqChanged: (_) {},
        assertCurrent: () {
          if (!current) throw StateError('LIVE_DRAFT_CONTEXT_CHANGED');
        },
      );
      await acquireStarted.future;

      current = false;
      acquireResult.complete(_lock('callsign', 'stale-lock'));

      await expectLater(
        operation,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'LIVE_DRAFT_CONTEXT_CHANGED',
          ),
        ),
      );
      expect(patchCount, 0);
      expect(released, ['callsign']);
    });

    test('server-consumed leases skip redundant DELETE round trips', () async {
      final released = <String>[];

      final execution = await executeLiveDraftAtomicPatch(
        values: const {'device': 'IC-705', 'antenna': 'Yagi'},
        expectedRevisions: const {'device': 0, 'antenna': 0},
        ownedLocks: const {},
        nextClientSeq: 1,
        acquireLock: (field) async => _lock(field, 'new-$field'),
        sendPatch: (clientSeq, _) async => _patchResult(
          clientSeq,
          releasedLeases: const [
            LiveDraftReleasedLeaseDto(
              field: 'device',
              leaseId: 'new-device',
            ),
            LiveDraftReleasedLeaseDto(
              field: 'antenna',
              leaseId: 'new-antenna',
            ),
          ],
        ),
        releaseLock: (field, _) async => released.add(field),
        onClientSeqChanged: (_) {},
      );

      expect(execution.result.releasedLeases, hasLength(2));
      expect(released, isEmpty);
    });

    test('a later dirty value reacquires after the prior lease was consumed',
        () async {
      final acquired = <String>[];
      final released = <String>[];
      var seq = 0;

      Future<void> patch(String value) async {
        await executeLiveDraftAtomicPatch(
          values: {'qth': value},
          expectedRevisions: {'qth': seq},
          ownedLocks: const {},
          nextClientSeq: seq + 1,
          acquireLock: (field) async {
            acquired.add(field);
            return _lock(field, 'lease-${seq + 1}');
          },
          sendPatch: (clientSeq, _) async => _patchResult(
            clientSeq,
            releasedLeases: [
              LiveDraftReleasedLeaseDto(
                field: 'qth',
                leaseId: 'lease-$clientSeq',
              ),
            ],
          ),
          releaseLock: (field, _) async => released.add(field),
          onClientSeqChanged: (value) => seq = value,
        );
      }

      await patch('A');
      await patch('B');

      expect(acquired, ['qth', 'qth']);
      expect(seq, 2);
      expect(released, isEmpty);
    });

    test('a PATCH failure releases every lock acquired by the batch', () async {
      final released = <String>[];
      var patchCount = 0;

      await expectLater(
        executeLiveDraftAtomicPatch(
          values: const {'qth': 'Shanghai', 'device': 'IC-705'},
          expectedRevisions: const {'qth': 0, 'device': 0},
          ownedLocks: const {},
          nextClientSeq: 1,
          acquireLock: (field) async => _lock(field, 'new-$field'),
          sendPatch: (_, __) async {
            patchCount += 1;
            throw _serverError('LIVE_DRAFT_FIELD_CONFLICT');
          },
          releaseLock: (field, _) async => released.add(field),
          onClientSeqChanged: (_) {},
        ),
        throwsA(
          isA<ServerApiException>().having(
            (error) => error.code,
            'code',
            'LIVE_DRAFT_FIELD_CONFLICT',
          ),
        ),
      );

      expect(patchCount, 1);
      expect(released, ['device', 'qth']);
    });

    test('retries a client sequence gap with the server expected value',
        () async {
      final attempts = <int>[];
      final sequenceChanges = <int>[];

      final execution = await executeLiveDraftAtomicPatch(
        values: const {'qth': 'Shanghai'},
        expectedRevisions: const {'qth': 0},
        ownedLocks: const {},
        nextClientSeq: 2,
        acquireLock: (field) async => _lock(field, 'new-$field'),
        sendPatch: (clientSeq, _) async {
          attempts.add(clientSeq);
          if (attempts.length == 1) {
            throw _serverError(
              'LIVE_DRAFT_CLIENT_SEQ_GAP',
              details: const {'expectedClientSeq': 7},
            );
          }
          return _patchResult(clientSeq);
        },
        releaseLock: (_, __) async {},
        onClientSeqChanged: sequenceChanges.add,
      );

      expect(execution.appliedClientSeq, 7);
      expect(attempts, [2, 7]);
      expect(sequenceChanges, [6, 7]);
    });

    test('advances once after a reused client sequence', () async {
      final attempts = <int>[];
      final sequenceChanges = <int>[];

      final execution = await executeLiveDraftAtomicPatch(
        values: const {'qth': 'Shanghai'},
        expectedRevisions: const {'qth': 0},
        ownedLocks: const {},
        nextClientSeq: 2,
        acquireLock: (field) async => _lock(field, 'new-$field'),
        sendPatch: (clientSeq, _) async {
          attempts.add(clientSeq);
          if (attempts.length == 1) {
            throw _serverError('LIVE_DRAFT_CLIENT_SEQ_REUSED');
          }
          return _patchResult(clientSeq);
        },
        releaseLock: (_, __) async {},
        onClientSeqChanged: sequenceChanges.add,
      );

      expect(execution.appliedClientSeq, 3);
      expect(attempts, [2, 3]);
      expect(sequenceChanges, [2, 3]);
    });

    test('optimistic atomic staging is visible and keeps revision baselines',
        () {
      final canonical = _draft(
        version: 3,
        values: const {
          'qth': 'remote-qth',
          'device': 'remote-radio',
          'remarks': 'remote-remarks',
        },
        revisions: const {'qth': 4, 'device': 5, 'remarks': 8},
      );
      final staged = stageOptimisticLiveDraftAtomicPatch(
        canonicalDraft: canonical,
        localFields: _fields({
          'qth': 'remote-qth',
          'device': 'local-radio',
          'remarks': 'local-remarks',
        }),
        dirtyFields: const {'device', 'remarks'},
        baseRevisions: const {'device': 2, 'remarks': 7},
        updates: const {
          'qth': 'Shanghai',
          'device': 'IC-705',
        },
      );

      expect(staged.localFields['qth'], 'Shanghai');
      expect(staged.localFields['device'], 'IC-705');
      expect(staged.localFields['remarks'], 'local-remarks');
      expect(staged.dirtyFields, {'qth', 'device', 'remarks'});
      expect(staged.baseRevisions, {
        'qth': 4,
        'device': 2,
        'remarks': 7,
      });
    });

    test('optimistic staging clears dirty state when returning to canonical',
        () {
      final canonical = _draft(
        version: 3,
        values: const {'qth': 'remote-qth'},
        revisions: const {'qth': 4},
      );
      final staged = stageOptimisticLiveDraftAtomicPatch(
        canonicalDraft: canonical,
        localFields: _fields({'qth': 'local-qth'}),
        dirtyFields: const {'qth'},
        baseRevisions: const {'qth': 2},
        updates: const {'qth': 'remote-qth'},
      );

      expect(staged.localFields['qth'], 'remote-qth');
      expect(staged.dirtyFields, isNot(contains('qth')));
      expect(staged.baseRevisions, isNot(contains('qth')));
    });

    test('optimistic rollback preserves a newer edit and unrelated dirty state',
        () {
      final canonical = _draft(
        version: 4,
        values: const {
          'qth': 'new-remote-qth',
          'device': 'remote-radio',
          'remarks': 'remote-remarks',
        },
        revisions: const {'qth': 5, 'device': 6, 'remarks': 8},
      );
      final restored = rollbackOptimisticLiveDraftAtomicPatch(
        canonicalDraft: canonical,
        beforeLocalFields: _fields({
          'qth': 'old-remote-qth',
          'device': 'old-local-radio',
          'remarks': 'local-remarks',
        }),
        beforeDirtyFields: const {'device', 'remarks'},
        beforeBaseRevisions: const {'device': 2, 'remarks': 7},
        currentLocalFields: _fields({
          'qth': 'Shanghai',
          'device': 'newer-manual-radio',
          'remarks': 'local-remarks',
        }),
        currentDirtyFields: const {'qth', 'device', 'remarks'},
        currentBaseRevisions: const {
          'qth': 5,
          'device': 2,
          'remarks': 7,
        },
        stagedValues: const {
          'qth': 'Shanghai',
          'device': 'IC-705',
        },
      );

      expect(restored.localFields['qth'], 'new-remote-qth');
      expect(restored.localFields['device'], 'newer-manual-radio');
      expect(restored.localFields['remarks'], 'local-remarks');
      expect(restored.dirtyFields, {'device', 'remarks'});
      expect(restored.baseRevisions, {'device': 2, 'remarks': 7});
    });

    test('success merge preserves unrelated dirty state', () {
      final before = _fields({
        'qth': 'old-qth',
        'device': 'old-radio',
        'remarks': 'local-remarks',
      });
      final canonical = _draft(
        version: 3,
        values: const {
          'qth': 'new-qth',
          'device': 'new-radio',
          'remarks': 'remote-remarks',
        },
        revisions: const {'qth': 1, 'device': 1, 'remarks': 8},
      );

      final merged = mergeAcceptedLiveDraftAtomicPatch(
        targetFields: const {'qth', 'device'},
        beforeLocalFields: before,
        beforeDirtyFields: const {'remarks'},
        beforeBaseRevisions: const {'remarks': 7},
        currentLocalFields: before,
        currentDirtyFields: const {'remarks'},
        currentBaseRevisions: const {'remarks': 7},
        canonicalDraft: canonical,
      );

      expect(merged.localFields['qth'], 'new-qth');
      expect(merged.localFields['device'], 'new-radio');
      expect(merged.localFields['remarks'], 'local-remarks');
      expect(merged.dirtyFields, {'remarks'});
      expect(merged.baseRevisions, {'remarks': 7});
    });

    test('success merge retains a newer edit made while PATCH is pending', () {
      final before = _fields({'qth': 'old-qth', 'remarks': 'local-remarks'});
      final current = _fields({
        'qth': 'newer-local-qth',
        'remarks': 'local-remarks',
      });
      final canonical = _draft(
        version: 3,
        values: const {'qth': 'batch-qth', 'remarks': 'remote-remarks'},
        revisions: const {'qth': 4, 'remarks': 8},
      );

      final merged = mergeAcceptedLiveDraftAtomicPatch(
        targetFields: const {'qth'},
        beforeLocalFields: before,
        beforeDirtyFields: const {'remarks'},
        beforeBaseRevisions: const {'remarks': 7},
        currentLocalFields: current,
        currentDirtyFields: const {'qth', 'remarks'},
        currentBaseRevisions: const {'qth': 2, 'remarks': 7},
        canonicalDraft: canonical,
      );

      expect(merged.localFields['qth'], 'newer-local-qth');
      expect(merged.localFields['remarks'], 'local-remarks');
      expect(merged.dirtyFields, {'qth', 'remarks'});
      expect(merged.baseRevisions, {'qth': 4, 'remarks': 7});
    });

    test(
        'single-field response keeps every field edited while PATCH is pending',
        () {
      for (final field in liveDraftFieldNames) {
        final sentValue = 'sent-$field';
        final currentValue = 'current-$field';
        final sent = _fields({field: sentValue});
        final current = _fields({field: currentValue});
        final accepted = _draft(
          version: 2,
          values: {field: sentValue},
          revisions: {field: 1},
        );

        final merged = mergeAcceptedLiveDraftAtomicPatch(
          targetFields: {field},
          beforeLocalFields: sent,
          beforeDirtyFields: {field},
          beforeBaseRevisions: {field: 0},
          currentLocalFields: current,
          currentDirtyFields: {field},
          currentBaseRevisions: {field: 0},
          canonicalDraft: accepted,
        );

        expect(merged.localFields[field], currentValue, reason: field);
        expect(merged.dirtyFields, {field}, reason: field);
        expect(merged.baseRevisions, {field: 1}, reason: field);
      }
    });

    test('an older PATCH response cannot replace a newer live snapshot', () {
      final accepted = _draft(version: 3, values: const {'qth': 'accepted'});
      final newer = _draft(version: 4, values: const {'qth': 'newer'});
      final nextGeneration = _draft(
        draftId: 'draft-2',
        version: 1,
        values: const {'qth': 'next'},
      );

      expect(
        selectLiveDraftCanonicalAfterAtomicPatch(
          current: newer,
          accepted: accepted,
        ),
        same(newer),
      );
      expect(
        selectLiveDraftCanonicalAfterAtomicPatch(
          current: nextGeneration,
          accepted: accepted,
        ),
        same(nextGeneration),
      );
    });

    test('refresh keeps a newer same-generation draft but adopts new locks',
        () {
      final current = _snapshot(
        draft: _draft(version: 4, values: const {'callsign': 'BG5CRL'}),
        locks: [_lock('callsign', 'old-lock')],
      );
      final stale = _snapshot(
        draft: _draft(version: 3, values: const {'callsign': 'B'}),
        locks: [_lock('qth', 'fresh-lock')],
      );

      final selected = selectLiveDraftSnapshotAfterRefresh(
        current: current,
        incoming: stale,
      );

      expect(selected.draft, same(current.draft));
      expect(selected.locks.single.leaseId, 'fresh-lock');
      expect(selected.currentOrdinal, current.currentOrdinal);
    });

    test('refresh accepts a newer version and a new draft generation', () {
      final current = _snapshot(draft: _draft(version: 4));
      final newer = _snapshot(draft: _draft(version: 5));
      final nextGeneration = _snapshot(
        draft: _draft(draftId: 'draft-2', version: 1),
        currentOrdinal: 9,
        totalRecords: 8,
      );

      expect(
        selectLiveDraftSnapshotAfterRefresh(
          current: current,
          incoming: newer,
        ),
        same(newer),
      );
      expect(
        selectLiveDraftSnapshotAfterRefresh(
          current: current,
          incoming: nextGeneration,
        ),
        same(nextGeneration),
      );
    });

    test('refresh does not replace a newer generation with a stale GET', () {
      final current = _snapshot(
        draft: _draft(draftId: 'draft-2', version: 1),
        currentOrdinal: 9,
        totalRecords: 8,
      );
      final stalePrevious = _snapshot(
        draft: _draft(draftId: 'draft-1', version: 4),
        locks: [_lock('qth', 'stale-lock')],
        currentOrdinal: 8,
        totalRecords: 7,
      );

      final selected = selectLiveDraftSnapshotAfterRefresh(
        current: current,
        incoming: stalePrevious,
      );

      expect(selected.draft, same(current.draft));
      expect(selected.currentOrdinal, 9);
      expect(selected.totalRecords, 8);
      expect(selected.locks, isEmpty);
    });

    test('refresh keeps a discarded generation when ordinal is unchanged', () {
      final current = _snapshot(
        draft: _draft(
          draftId: 'draft-2',
          version: 1,
          createdAt: DateTime.utc(2026, 7, 13, 12, 1),
        ),
      );
      final stalePrevious = _snapshot(
        draft: _draft(
          draftId: 'draft-1',
          version: 6,
          createdAt: DateTime.utc(2026, 7, 13, 12),
        ),
      );

      final selected = selectLiveDraftSnapshotAfterRefresh(
        current: current,
        incoming: stalePrevious,
      );

      expect(selected.draft, same(current.draft));
      expect(selected.currentOrdinal, current.currentOrdinal);
    });

    test('lock acquisition rebases only the acquired dirty field', () {
      final current = _draft(
        version: 4,
        values: const {
          'callsign': 'BA4AAA',
          'qth': 'old-remote-qth',
          'remarks': 'old-remote-remarks',
        },
        revisions: const {'callsign': 2, 'qth': 7, 'remarks': 3},
      );
      final incoming = _draft(
        version: 5,
        values: const {
          'callsign': 'BA4BBB',
          'qth': 'new-remote-qth',
          'remarks': 'new-remote-remarks',
        },
        revisions: const {'callsign': 3, 'qth': 8, 'remarks': 4},
      );

      final projection = projectLiveDraftLockAcquisition(
        acquiredField: 'qth',
        currentDraft: current,
        incomingDraft: incoming,
        localFields: current.fields
            .withField('qth', 'local-qth')
            .withField('remarks', 'local-remarks'),
        dirtyFields: const {'qth', 'remarks'},
        baseRevisions: const {'qth': 7, 'remarks': 3},
      );

      expect(projection.canonicalDraft, same(incoming));
      expect(projection.localFields['callsign'], 'BA4BBB');
      expect(projection.localFields['qth'], 'local-qth');
      expect(projection.localFields['remarks'], 'local-remarks');
      expect(projection.dirtyFields, {'qth', 'remarks'});
      expect(projection.baseRevisions, {'qth': 7, 'remarks': 3});
      expect(projection.conflictedFields, {'qth'});
      expect(projection.generationChanged, isFalse);
    });

    test('lock acquisition drops old local state after a generation change',
        () {
      final current = _draft(version: 4);
      final incoming = _draft(
        draftId: 'draft-2',
        version: 1,
        values: const {'callsign': 'BA4NEW'},
      );

      final projection = projectLiveDraftLockAcquisition(
        acquiredField: 'callsign',
        currentDraft: current,
        incomingDraft: incoming,
        localFields: current.fields.withField('callsign', 'BA4LOCAL'),
        dirtyFields: const {'callsign'},
        baseRevisions: const {'callsign': 2},
      );

      expect(projection.canonicalDraft, same(incoming));
      expect(projection.localFields['callsign'], 'BA4NEW');
      expect(projection.dirtyFields, isEmpty);
      expect(projection.baseRevisions, isEmpty);
      expect(projection.conflictedFields, isEmpty);
      expect(projection.generationChanged, isTrue);
    });

    test('idle release is rejected after a new edit or lease replacement', () {
      final lock = _lock('qth', 'lease-old');
      expect(
        canReleaseIdleLiveDraftLease(
          fieldDirty: false,
          currentLock: lock,
          expectedLeaseId: 'lease-old',
        ),
        isTrue,
      );
      expect(
        canReleaseIdleLiveDraftLease(
          fieldDirty: true,
          currentLock: lock,
          expectedLeaseId: 'lease-old',
        ),
        isFalse,
      );
      expect(
        canReleaseIdleLiveDraftLease(
          fieldDirty: false,
          currentLock: _lock('qth', 'lease-new'),
          expectedLeaseId: 'lease-old',
        ),
        isFalse,
      );
    });

    test('field and version conflicts recover after one rebase', () async {
      for (final code in const [
        'LIVE_DRAFT_FIELD_CONFLICT',
        'LIVE_DRAFT_VERSION_CONFLICT',
      ]) {
        var attempts = 0;
        var rebases = 0;
        final result = await executeLiveDraftAtomicPatchWithRebaseRetry<int>(
          attempt: () async {
            attempts += 1;
            if (attempts == 1) throw _serverError(code);
            return 7;
          },
          rebase: (_) async => rebases += 1,
        );

        expect(result, 7, reason: code);
        expect(attempts, 2, reason: code);
        expect(rebases, 1, reason: code);
      }
    });

    test('atomic conflicts retry to the bounded attempt limit', () async {
      var attempts = 0;
      var rebases = 0;

      await expectLater(
        executeLiveDraftAtomicPatchWithRebaseRetry<void>(
          attempt: () async {
            attempts += 1;
            throw _serverError('LIVE_DRAFT_FIELD_CONFLICT');
          },
          rebase: (_) async => rebases += 1,
        ),
        throwsA(
          isA<ServerApiException>().having(
            (error) => error.code,
            'code',
            'LIVE_DRAFT_FIELD_CONFLICT',
          ),
        ),
      );

      expect(attempts, 4);
      expect(rebases, 3);
    });

    test('uses the canonical draft embedded in a field conflict', () {
      final canonical = _draft(
        version: 9,
        values: const {'callsign': 'BG5CRL'},
        revisions: const {'callsign': 8},
      );
      final extracted = liveDraftCanonicalFromConflict(
        _serverError(
          'LIVE_DRAFT_FIELD_CONFLICT',
          details: {'draft': canonical.toJson()},
        ),
        sessionId: 'session-1',
      );

      expect(extracted?.version, 9);
      expect(extracted?.fieldRevisions['callsign'], 8);
      expect(
        liveDraftCanonicalFromConflict(
          _serverError(
            'LIVE_DRAFT_FIELD_CONFLICT',
            details: {
              'draft': _draft(
                version: 9,
                sessionId: 'another-session',
              ).toJson(),
            },
          ),
          sessionId: 'session-1',
        ),
        isNull,
      );
    });
  });

  group('live-draft commit race recovery', () {
    test('recovers version and busy races before the fourth attempt', () async {
      final attempts = <int>[];
      final recoveries = <({String code, int attempt})>[];

      final result = await executeLiveDraftCommitWithRaceRecovery<int>(
        attempt: (attempt) async {
          attempts.add(attempt);
          if (attempt == 1) {
            throw _serverError('LIVE_DRAFT_VERSION_CONFLICT');
          }
          if (attempt == 2) throw _serverError('LIVE_DRAFT_BUSY');
          return 17;
        },
        recover: (error, attempt) async {
          recoveries.add((code: error.code, attempt: attempt));
        },
      );

      expect(result, 17);
      expect(attempts, [1, 2, 3]);
      expect(recoveries, [
        (code: 'LIVE_DRAFT_VERSION_CONFLICT', attempt: 1),
        (code: 'LIVE_DRAFT_BUSY', attempt: 2),
      ]);
    });

    test('returns the fourth recoverable conflict without another recovery',
        () async {
      var attempts = 0;
      var recoveries = 0;

      await expectLater(
        executeLiveDraftCommitWithRaceRecovery<void>(
          attempt: (_) async {
            attempts += 1;
            throw _serverError('LIVE_DRAFT_BUSY');
          },
          recover: (_, __) async => recoveries += 1,
        ),
        throwsA(
          isA<ServerApiException>().having(
            (error) => error.code,
            'code',
            'LIVE_DRAFT_BUSY',
          ),
        ),
      );

      expect(attempts, 4);
      expect(recoveries, 3);
    });

    test('does not retry a non-recoverable commit rejection', () async {
      var attempts = 0;
      var recoveries = 0;

      await expectLater(
        executeLiveDraftCommitWithRaceRecovery<void>(
          attempt: (_) async {
            attempts += 1;
            throw _serverError('LIVE_DRAFT_INCOMPLETE');
          },
          recover: (_, __) async => recoveries += 1,
        ),
        throwsA(
          isA<ServerApiException>().having(
            (error) => error.code,
            'code',
            'LIVE_DRAFT_INCOMPLETE',
          ),
        ),
      );

      expect(attempts, 1);
      expect(recoveries, 0);
    });
  });

  test('device-local quiescence wait is bounded for stuck transports',
      () async {
    final never = Completer<void>();
    final stopwatch = Stopwatch()..start();

    await waitForCollaborationLocalQuiescence(
      [never.future],
      timeout: const Duration(milliseconds: 5),
    );

    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('detaching a stalled draft chain lets a new collaboration proceed',
      () async {
    final executor = ResettableLiveDraftSerialExecutor();
    final stalled = Completer<void>();
    final firstStarted = Completer<void>();
    final first = executor.run(() async {
      firstStarted.complete();
      await stalled.future;
      return 1;
    });
    await firstStarted.future;

    var oldQueuedRan = false;
    final oldQueued = executor.run(() async {
      oldQueuedRan = true;
      return 2;
    });
    final detached = executor.detach();

    expect(await executor.run(() async => 3), 3);
    expect(oldQueuedRan, isFalse);

    stalled.complete();
    expect(await first, 1);
    expect(await oldQueued, 2);
    await detached;
  });

  test('an imported same-identity binding rejects an old draft epoch', () {
    const binding = LocalCollaborationBinding(
      serverInstanceId: 'server-1',
      serverOrigin: 'https://example.test',
      accountId: 'user-1',
      sessionId: 'session-1',
      membershipId: 'membership-1',
      membershipVersion: 1,
      role: SessionRole.owner,
      replicaState: 'ready',
      lastAppliedSeq: 4,
      lastSeenHeadSeq: 4,
      revokedAt: null,
    );

    expect(
      isLiveDraftResultContextCurrent(
        disposed: false,
        operationInProgress: false,
        expectedEpoch: 7,
        currentEpoch: 7,
        expectedBinding: binding,
        currentBinding: binding,
        currentSessionId: binding.sessionId,
      ),
      isTrue,
    );
    expect(
      isLiveDraftResultContextCurrent(
        disposed: false,
        operationInProgress: false,
        expectedEpoch: 7,
        currentEpoch: 8,
        expectedBinding: binding,
        currentBinding: binding,
        currentSessionId: binding.sessionId,
      ),
      isFalse,
    );
  });

  test('a clean closed replica can still become an active local recorder', () {
    const sync = CollaborationSyncState(
      identity: CollaborationSyncIdentity(
        serverInstanceId: 'server-1',
        serverOrigin: 'https://example.test',
        accountId: 'user-1',
        sessionId: 'session-1',
        deviceId: 'device-1',
      ),
      role: SessionRole.owner,
      transportPhase: CollaborationTransportPhase.online,
      replicaPhase: CollaborationReplicaPhase.ready,
      lastAppliedSeq: 8,
      serverHeadSeq: 8,
      pendingCount: 0,
      conflictCount: 0,
      rejectedCount: 0,
      sessionClosed: true,
      writeSuspended: true,
      lastSuccessfulSyncAt: null,
      lastErrorCode: null,
      lastErrorMessage: null,
      nextRetryAt: null,
      remoteCommitPendingLocalApply: false,
    );

    expect(
      canSafelyConvertCollaborationSessionToLocal(
        hasCurrentBinding: true,
        operationInProgress: false,
        state: CollaborationState.ready,
        syncState: sync,
        hasOfflineRecords: false,
      ),
      isTrue,
    );
  });

  test('offline commit starts the next record with an empty time', () {
    final next = resetLiveDraftFieldsAfterCommit(
      _fields({
        'time': '2026-07-14T12:34:00Z',
        'controller': 'BG5CRL',
        'callsign': 'BA4AAA',
        'rstSent': '58',
        'rstRcvd': '47',
        'qth': 'Shanghai',
      }),
    );

    expect(next['time'], isEmpty);
    expect(next['controller'], 'BG5CRL');
    expect(next['callsign'], isEmpty);
    expect(next['rstSent'], '59');
    expect(next['rstRcvd'], '59');
    expect(next['qth'], isEmpty);
  });

  group('live-draft time display projection', () {
    test('hides a legacy revision-zero default time', () {
      final displayTime = projectLiveDraftTimeForDisplay(
        value: '08:15',
        revision: 0,
        locallyDirty: false,
        draftId: 'legacy-draft',
      );

      expect(displayTime, isEmpty);
    });

    test('keeps an explicitly revised user time visible', () {
      final displayTime = projectLiveDraftTimeForDisplay(
        value: '08:15',
        revision: 1,
        locallyDirty: false,
        draftId: 'draft-1',
      );

      expect(displayTime, '08:15');
    });

    test('hides an automatic acknowledgement but reveals a later edit', () {
      const draftId = 'draft-1';
      const automaticTime = '08:15';

      expect(
        projectLiveDraftTimeForDisplay(
          value: automaticTime,
          revision: 0,
          locallyDirty: false,
          draftId: draftId,
          automaticDraftId: draftId,
          automaticDisplayMinute: automaticTime,
          automaticMaxRevision: 1,
        ),
        isEmpty,
      );
      expect(
        projectLiveDraftTimeForDisplay(
          value: automaticTime,
          revision: 1,
          locallyDirty: false,
          draftId: draftId,
          automaticDraftId: draftId,
          automaticDisplayMinute: automaticTime,
          automaticMaxRevision: 1,
        ),
        isEmpty,
        reason: 'the acknowledgement of the automatic value stays hidden',
      );
      expect(
        projectLiveDraftTimeForDisplay(
          value: automaticTime,
          revision: 2,
          locallyDirty: false,
          draftId: draftId,
          automaticDraftId: draftId,
          automaticDisplayMinute: automaticTime,
          automaticMaxRevision: 1,
        ),
        automaticTime,
        reason: 'a later explicit edit must remain visible',
      );
    });
  });

  group('live-draft realtime controls', () {
    test('self acknowledgement values mirror server normalization', () {
      expect(
        canonicalLiveDraftPatchAckValue('callsign', ' bg5crl '),
        'BG5CRL',
      );
      expect(
        canonicalLiveDraftPatchAckValue('controller', ' bg5crl '),
        'BG5CRL',
      );
      expect(
        canonicalLiveDraftPatchAckValue('device', ' IC-705 '),
        'IC-705',
      );
      expect(canonicalLiveDraftPatchAckValue('qth', '   '), '');
      expect(canonicalLiveDraftPatchAckValue('remarks', null), '');
    });

    test('generation recovery keeps only input absent from accepted state', () {
      final current = _draft(
        version: 4,
        values: const {'callsign': '', 'qth': '杭州'},
      );

      expect(
        hasUnpreservedLiveDraftChanges(
          currentDraft: current,
          localFields: current.fields.withField('qth', '杭州'),
          dirtyFields: const {'qth'},
        ),
        isFalse,
      );
      expect(
        hasUnpreservedLiveDraftChanges(
          currentDraft: current,
          localFields: current.fields
              .withField('callsign', ' bg5crl ')
              .withField('qth', '萧山'),
          dirtyFields: const {'callsign', 'qth'},
          acceptedFields: LiveDraftFieldsDto.empty()
              .withField('callsign', 'BG5CRL')
              .withField('qth', '杭州'),
        ),
        isTrue,
        reason: 'QTH is still absent even though the callsign was accepted',
      );
      expect(
        hasUnpreservedLiveDraftChanges(
          currentDraft: current,
          localFields: current.fields.withField('callsign', ' bg5crl '),
          dirtyFields: const {'callsign'},
          acceptedFields:
              LiveDraftFieldsDto.empty().withField('callsign', 'BG5CRL'),
        ),
        isFalse,
      );
    });

    test('own updated control precisely acknowledges a lost HTTP response', () {
      final incoming = _draft(
        version: 5,
        values: const {'qth': '杭州'},
        revisions: const {'qth': 8},
      );
      final acknowledgement = matchLiveDraftPatchControlAck(
        message: {
          'type': 'liveDraft.updated',
          'sessionId': 'session-1',
          'deviceId': 'device-1',
          'clientSeq': 12,
          'updatedFields': ['qth'],
          'releasedLeases': [
            {'field': 'qth', 'leaseId': 'lease-qth'},
          ],
          'draft': incoming.toJson(),
        },
        sessionId: 'session-1',
        deviceId: 'device-1',
        clientSeq: 12,
        draftId: 'draft-1',
        expectedValues: const {'qth': '杭州'},
        expectedRevisions: const {'qth': 7},
      );

      expect(acknowledgement?.draft.toJson(), incoming.toJson());
      expect(acknowledgement?.releasedLeases.single.field, 'qth');
      expect(
        acknowledgement?.releasedLeases.single.leaseId,
        'lease-qth',
      );
    });

    test('self acknowledgement rejects the wrong fields, value, or sequence',
        () {
      final baseMessage = <String, Object?>{
        'type': 'liveDraft.updated',
        'sessionId': 'session-1',
        'deviceId': 'device-1',
        'clientSeq': 12,
        'updatedFields': ['callsign'],
        'draft': _draft(
          version: 5,
          values: const {'qth': '杭州'},
          revisions: const {'qth': 8},
        ).toJson(),
      };

      LiveDraftPatchControlAcknowledgement? match(
        Map<String, Object?> message,
      ) =>
          matchLiveDraftPatchControlAck(
            message: message,
            sessionId: 'session-1',
            deviceId: 'device-1',
            clientSeq: 12,
            draftId: 'draft-1',
            expectedValues: const {'qth': '杭州'},
            expectedRevisions: const {'qth': 7},
          );

      expect(match(baseMessage), isNull, reason: 'field list must match');
      expect(
        match({...baseMessage, 'clientSeq': 11}),
        isNull,
        reason: 'client sequence must match',
      );
      expect(
        match({
          ...baseMessage,
          'updatedFields': ['qth'],
          'draft': _draft(
            version: 5,
            values: const {'qth': '宁波'},
            revisions: const {'qth': 8},
          ).toJson(),
        }),
        isNull,
        reason: 'canonical value must match',
      );
    });

    test('legacy own control can acknowledge by exact value and revision', () {
      final acknowledgement = matchLiveDraftPatchControlAck(
        message: {
          'type': 'liveDraft.updated',
          'sessionId': 'session-1',
          'deviceId': 'device-1',
          'clientSeq': 2,
          'draft': _draft(
            version: 2,
            values: const {'callsign': 'BG5CRL'},
            revisions: const {'callsign': 1},
          ).toJson(),
        },
        sessionId: 'session-1',
        deviceId: 'device-1',
        clientSeq: 2,
        draftId: 'draft-1',
        expectedValues: const {'callsign': 'BG5CRL'},
        expectedRevisions: const {'callsign': 0},
      );

      expect(acknowledgement, isNotNull);
      expect(acknowledgement!.releasedLeases, isEmpty);
    });

    test('updated payload projects every supported field without a GET', () {
      final current = _snapshot(draft: _draft(version: 1));
      final values = {
        for (final field in liveDraftFieldNames) field: 'value-$field',
      };
      final incoming = _draft(version: 2, values: values);

      final projection = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: current.draft.fields,
        currentDirtyFields: const {},
        currentBaseRevisions: const {},
        message: {
          'type': 'liveDraft.updated',
          'sessionId': 'session-1',
          'draft': incoming.toJson(),
        },
      );

      expect(projection.changed, isTrue);
      for (final field in liveDraftFieldNames) {
        expect(projection.snapshot.draft.fields[field], values[field],
            reason: field);
        expect(projection.localFields[field], values[field], reason: field);
      }
    });

    test('older updated payload is ignored', () {
      final current = _snapshot(
        draft: _draft(version: 4, values: const {'callsign': 'BG5CRL'}),
      );

      final projection = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: current.draft.fields,
        currentDirtyFields: const {},
        currentBaseRevisions: const {},
        message: {
          'type': 'liveDraft.updated',
          'sessionId': 'session-1',
          'draft': _draft(
            version: 3,
            values: const {'callsign': 'B'},
          ).toJson(),
        },
      );

      expect(projection.changed, isFalse);
      expect(projection.snapshot, same(current));
      expect(projection.localFields['callsign'], 'BG5CRL');
    });

    test('updated payload cannot switch draft generations', () {
      final current = _snapshot(draft: _draft(version: 4));

      expect(
        () => applyLiveDraftControlMessage(
          currentSnapshot: current,
          currentLocalFields: current.draft.fields,
          currentDirtyFields: const {},
          currentBaseRevisions: const {},
          message: {
            'type': 'liveDraft.updated',
            'sessionId': 'session-1',
            'draft': _draft(
              draftId: 'unproven-generation',
              version: 1,
            ).toJson(),
          },
        ),
        throwsFormatException,
      );
    });

    test('newer updated payload preserves local dirty fields', () {
      final current = _snapshot(
        draft: _draft(
          version: 4,
          values: const {'callsign': 'BA4AAA', 'qth': 'old-remote'},
          revisions: const {'callsign': 2, 'qth': 7},
        ),
      );
      final local = current.draft.fields.withField('qth', 'local-edit');

      final projection = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: local,
        currentDirtyFields: const {'qth'},
        currentBaseRevisions: const {'qth': 7},
        message: {
          'type': 'liveDraft.updated',
          'sessionId': 'session-1',
          'draft': _draft(
            version: 5,
            values: const {'callsign': 'BA4BBB', 'qth': 'new-remote'},
            revisions: const {'callsign': 3, 'qth': 8},
          ).toJson(),
        },
      );

      expect(projection.snapshot.draft.fields['qth'], 'new-remote');
      expect(projection.localFields['qth'], 'local-edit');
      expect(projection.localFields['callsign'], 'BA4BBB');
      expect(projection.dirtyFields, {'qth'});
      expect(projection.baseRevisions, {'qth': 7});
    });

    test('history reuse replaces only affected dirty station fields', () {
      final current = _snapshot(
        draft: _draft(
          version: 4,
          values: const {
            'callsign': 'BA4AAA',
            'qth': 'old-qth',
            'device': 'old-device',
            'remarks': 'old-remarks',
          },
          revisions: const {'callsign': 2, 'qth': 7, 'device': 2},
        ),
        locks: [_lock('device', 'device-lock')],
      );
      final local = LiveDraftFieldsDto({
        for (final field in liveDraftFieldNames)
          field: current.draft.fields[field],
        'qth': 'uncommitted-qth',
        'device': 'uncommitted-device',
        'remarks': 'keep-my-remarks',
      });
      final canonical = _draft(
        version: 5,
        values: const {
          'callsign': 'BA4AAA',
          'qth': 'history-qth',
          'device': 'history-device',
          'remarks': 'remote-remarks',
        },
        revisions: const {'callsign': 2, 'qth': 8, 'device': 3},
      );
      final ordinary = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: local,
        currentDirtyFields: const {'qth', 'device', 'remarks'},
        currentBaseRevisions: const {'qth': 7, 'device': 2, 'remarks': 0},
        message: {
          'type': 'liveDraft.updated',
          'sessionId': 'session-1',
          'draft': canonical.toJson(),
          'locks': const <Object?>[],
        },
      );
      final reused = applyLiveDraftHistoryReuseProjection(
        projection: ordinary,
        canonicalDraft: canonical,
        historyReuse: const LiveDraftHistoryReuseDto(
          previewId: 'preview-1',
          candidateId: 'history-1',
          affectedFields: {'qth', 'device'},
        ),
        locks: const [],
      );

      expect(reused.localFields['qth'], 'history-qth');
      expect(reused.localFields['device'], 'history-device');
      expect(reused.localFields['remarks'], 'keep-my-remarks');
      expect(reused.dirtyFields, {'remarks'});
      expect(reused.baseRevisions, {'remarks': 0});
      expect(reused.snapshot.locks, isEmpty);
    });

    test('cleared and committed controls replace the draft generation', () {
      final previous = _log('previous-log', callsign: 'BA4AAA');
      final current = _snapshot(
        draft: _draft(version: 4, values: const {'qth': 'local'}),
        locks: [_lock('qth', 'qth-lock')],
        previousRecord: previous,
      );
      final nextAfterClear = _draft(
        draftId: 'draft-2',
        version: 1,
        values: const {'controller': 'BG5CRL'},
      );

      final cleared = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: current.draft.fields.withField('qth', 'dirty'),
        currentDirtyFields: const {'qth'},
        currentBaseRevisions: const {'qth': 0},
        message: {
          'type': 'liveDraft.cleared',
          'sessionId': 'session-1',
          'discardedDraftId': 'draft-1',
          'nextDraft': nextAfterClear.toJson(),
        },
      );

      expect(cleared.snapshot.draft.draftId, 'draft-2');
      expect(cleared.snapshot.locks, isEmpty);
      expect(cleared.snapshot.previousRecord, same(previous));
      expect(cleared.localFields['controller'], 'BG5CRL');
      expect(cleared.dirtyFields, isEmpty);

      final committedRecord = _log('committed-log', callsign: 'BA4BBB');
      final committed = applyLiveDraftControlMessage(
        currentSnapshot: cleared.snapshot,
        currentLocalFields: cleared.localFields,
        currentDirtyFields: cleared.dirtyFields,
        currentBaseRevisions: cleared.baseRevisions,
        message: {
          'type': 'liveDraft.committed',
          'sessionId': 'session-1',
          'committedDraftId': 'draft-2',
          'nextDraft': _draft(
            draftId: 'draft-3',
            version: 1,
          ).toJson(),
          'record': committedRecord.toJson(),
          'currentOrdinal': 9,
          'totalRecords': 8,
        },
      );

      expect(committed.snapshot.draft.draftId, 'draft-3');
      expect(committed.snapshot.currentOrdinal, 9);
      expect(committed.snapshot.totalRecords, 8);
      expect(committed.snapshot.previousRecord?.syncId, 'committed-log');
      expect(committed.snapshot.previousRecord?.callsign, 'BA4BBB');
      expect(committed.snapshot.locks, isEmpty);

      final repeated = applyLiveDraftControlMessage(
        currentSnapshot: committed.snapshot,
        currentLocalFields: committed.localFields,
        currentDirtyFields: committed.dirtyFields,
        currentBaseRevisions: committed.baseRevisions,
        message: {
          'type': 'liveDraft.committed',
          'sessionId': 'session-1',
          'committedDraftId': 'draft-2',
          'nextDraft': _draft(
            draftId: 'draft-3',
            version: 1,
          ).toJson(),
          'record': committedRecord.toJson(),
          'currentOrdinal': 9,
          'totalRecords': 8,
        },
      );
      expect(repeated.changed, isFalse);
      expect(repeated.snapshot, same(committed.snapshot));
    });

    test(
        'terminal clear adopts a complete cross-generation draft and drops local state',
        () {
      final current = _snapshot(
        draft: _draft(
          draftId: 'draft-current',
          version: 7,
          values: const {'callsign': 'BG5LOCAL', 'qth': 'local-qth'},
          revisions: const {'callsign': 5, 'qth': 3},
        ),
        locks: [_lock('callsign', 'callsign-lock')],
      );
      final terminalDraft = _draft(
        draftId: 'draft-terminal',
        version: 4,
        values: const {'controller': 'BG5CRL'},
      );

      final projection = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields:
            current.draft.fields.withField('callsign', 'BG5DIRTY'),
        currentDirtyFields: const {'callsign'},
        currentBaseRevisions: const {'callsign': 5},
        message: {
          'type': 'liveDraft.cleared',
          'sessionId': 'session-1',
          'terminal': true,
          'discardedDraftId': 'draft-predecessor-missed-by-this-client',
          'nextDraft': terminalDraft.toJson(),
        },
      );

      expect(projection.changed, isTrue);
      expect(projection.snapshot.draft.draftId, 'draft-terminal');
      expect(projection.snapshot.draft.version, 4);
      expect(projection.snapshot.locks, isEmpty);
      expect(projection.localFields['controller'], 'BG5CRL');
      expect(projection.localFields['callsign'], isEmpty);
      expect(projection.dirtyFields, isEmpty);
      expect(projection.baseRevisions, isEmpty);
    });

    test('non-terminal reset controls reject an unrelated predecessor', () {
      final current = _snapshot(
        draft: _draft(draftId: 'draft-current', version: 2),
      );
      final next = _draft(draftId: 'draft-next', version: 1);

      expect(
        () => applyLiveDraftControlMessage(
          currentSnapshot: current,
          currentLocalFields: current.draft.fields,
          currentDirtyFields: const {},
          currentBaseRevisions: const {},
          message: {
            'type': 'liveDraft.cleared',
            'sessionId': 'session-1',
            'discardedDraftId': 'draft-unrelated',
            'nextDraft': next.toJson(),
          },
        ),
        throwsFormatException,
      );
      expect(
        () => applyLiveDraftControlMessage(
          currentSnapshot: current,
          currentLocalFields: current.draft.fields,
          currentDirtyFields: const {},
          currentBaseRevisions: const {},
          message: {
            'type': 'liveDraft.committed',
            'sessionId': 'session-1',
            'committedDraftId': 'draft-unrelated',
            'nextDraft': next.toJson(),
            'record': _log('log-1', callsign: 'BA4AAA').toJson(),
            'currentOrdinal': 2,
            'totalRecords': 1,
          },
        ),
        throwsFormatException,
      );
    });

    test('a durable forced-close marker reuses the terminal clear projection',
        () {
      final nextDraft = _draft(
        draftId: 'draft-after-forced-close',
        version: 8,
      );
      final event = CollaborationEventDto(
        protocolVersion: 1,
        eventId: 'event-forced-close',
        sessionId: 'session-1',
        seq: 9,
        type: 'session.closed',
        entityType: 'session',
        entityId: 'session-1',
        entityVersion: 3,
        occurredAt: DateTime.utc(2026, 7, 18),
        payload: {
          'sessionId': 'session-1',
          'status': 'closed',
          'liveDraftCleared': {
            'terminal': true,
            'discardedDraftId': 'draft-before-forced-close',
            'discardedDraftVersion': 7,
            'discardedDeviceStateCount': 2,
            'nextDraft': nextDraft.toJson(),
          },
        },
      );

      final control = terminalLiveDraftClearControlFromEvent(event);
      expect(control, isNotNull);
      expect(control!['type'], 'liveDraft.cleared');
      expect(control['sessionId'], 'session-1');
      expect(control['terminal'], isTrue);

      final current = _snapshot(
        draft: _draft(draftId: 'unrelated-cached-draft', version: 2),
        locks: [_lock('qth', 'stale-lock')],
      );
      final projection = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: current.draft.fields.withField('qth', 'dirty'),
        currentDirtyFields: const {'qth'},
        currentBaseRevisions: const {'qth': 0},
        message: control,
      );
      expect(projection.snapshot.draft.draftId, 'draft-after-forced-close');
      expect(projection.snapshot.locks, isEmpty);
      expect(projection.dirtyFields, isEmpty);

      final ordinaryClose = CollaborationEventDto(
        protocolVersion: 1,
        eventId: 'event-ordinary-close',
        sessionId: 'session-1',
        seq: 10,
        type: 'session.closed',
        entityType: 'session',
        entityId: 'session-1',
        entityVersion: 4,
        occurredAt: DateTime.utc(2026, 7, 18),
        payload: const {'sessionId': 'session-1', 'status': 'closed'},
      );
      expect(terminalLiveDraftClearControlFromEvent(ordinaryClose), isNull);
    });

    test('lock controls update, release, and replace the canonical lock list',
        () {
      final current = _snapshot(
        draft: _draft(version: 1),
        locks: [_lock('callsign', 'callsign-lock')],
      );
      final acquired = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: current.draft.fields,
        currentDirtyFields: const {},
        currentBaseRevisions: const {},
        message: {
          'type': 'liveDraft.lockChanged',
          'sessionId': 'session-1',
          'occurredAt': '2026-07-13T01:00:00.000Z',
          'action': 'acquired',
          'lock': _lock('qth', 'qth-lock').toJson(),
        },
      );
      expect(
        acquired.snapshot.locks.map((lock) => lock.field),
        orderedEquals(['callsign', 'qth']),
      );

      final released = applyLiveDraftControlMessage(
        currentSnapshot: acquired.snapshot,
        currentLocalFields: acquired.localFields,
        currentDirtyFields: acquired.dirtyFields,
        currentBaseRevisions: acquired.baseRevisions,
        message: const {
          'type': 'liveDraft.lockChanged',
          'sessionId': 'session-1',
          'occurredAt': '2026-07-13T01:00:00.000Z',
          'action': 'released',
          'field': 'callsign',
          'leaseId': 'callsign-lock',
        },
      );
      expect(released.snapshot.locks.single.field, 'qth');

      final membershipChanged = applyLiveDraftControlMessage(
        currentSnapshot: released.snapshot,
        currentLocalFields: released.localFields,
        currentDirtyFields: released.dirtyFields,
        currentBaseRevisions: released.baseRevisions,
        message: const {
          'type': 'liveDraft.lockChanged',
          'sessionId': 'session-1',
          'occurredAt': '2026-07-13T01:00:00.000Z',
          'action': 'membershipChanged',
          'fields': <Object?>['qth'],
        },
      );
      expect(membershipChanged.snapshot.locks, isEmpty);

      final closed = applyLiveDraftControlMessage(
        currentSnapshot: membershipChanged.snapshot,
        currentLocalFields: membershipChanged.localFields,
        currentDirtyFields: membershipChanged.dirtyFields,
        currentBaseRevisions: membershipChanged.baseRevisions,
        message: const {
          'type': 'liveDraft.lockChanged',
          'sessionId': 'session-1',
          'occurredAt': '2026-07-13T01:00:00.000Z',
          'action': 'ownershipTransferred',
          'locks': <Object?>[],
        },
      );
      expect(closed.snapshot.locks, isEmpty);
    });

    test('an old-generation lock control cannot revive a reset lock', () {
      final current = _snapshot(
        draft: _draft(draftId: 'draft-2', version: 1),
      );
      final stale = applyLiveDraftControlMessage(
        currentSnapshot: current,
        currentLocalFields: current.draft.fields,
        currentDirtyFields: const {},
        currentBaseRevisions: const {},
        message: {
          'type': 'liveDraft.lockChanged',
          'sessionId': 'session-1',
          'occurredAt': '2026-07-12T23:59:59.999Z',
          'action': 'acquired',
          'lock': _lock('callsign', 'stale-lock').toJson(),
        },
      );

      expect(stale.changed, isFalse);
      expect(stale.snapshot, same(current));
      expect(stale.snapshot.locks, isEmpty);
    });

    test('a same-millisecond lock control requires canonical recovery', () {
      final current = _snapshot(draft: _draft(version: 1));

      expect(
        () => applyLiveDraftControlMessage(
          currentSnapshot: current,
          currentLocalFields: current.draft.fields,
          currentDirtyFields: const {},
          currentBaseRevisions: const {},
          message: {
            'type': 'liveDraft.lockChanged',
            'sessionId': 'session-1',
            'occurredAt': '2026-07-13T00:00:00.000Z',
            'action': 'acquired',
            'lock': _lock('callsign', 'ambiguous-lock').toJson(),
          },
        ),
        throwsFormatException,
      );
    });

    test('canonical locks remove expired owned leases and adopt renewals', () {
      final owned = {
        'callsign': _lock('callsign', 'expired-lock'),
        'qth': _lock('qth', 'renewed-lock'),
      };
      final renewed = _lock(
        'qth',
        'renewed-lock',
        expiresAt: DateTime.utc(2026, 7, 15),
      );

      final reconciled = reconcileOwnedLiveDraftLocks(
        owned: owned,
        canonical: [renewed],
      );

      expect(reconciled.keys, ['qth']);
      expect(reconciled['qth'], same(renewed));
      expect(reconciled['qth']?.expiresAt, DateTime.utc(2026, 7, 15));
    });

    test('initial connect and one reconnect each request one fallback refresh',
        () {
      CollaborationTransportPhase? previous;
      var refreshes = 0;
      for (final current in const [
        CollaborationTransportPhase.connecting,
        CollaborationTransportPhase.online,
        CollaborationTransportPhase.online,
        CollaborationTransportPhase.backingOff,
        CollaborationTransportPhase.connecting,
        CollaborationTransportPhase.online,
        CollaborationTransportPhase.online,
      ]) {
        if (shouldRefreshLiveDraftAfterTransportTransition(previous, current)) {
          refreshes += 1;
        }
        previous = current;
      }

      expect(refreshes, 2);
    });
  });
}

CollaborationConflict _logConflict() => CollaborationConflict(
      conflictId: 'conflict-1',
      sessionId: 'session-1',
      entityType: CollaborationConflictEntityType.log,
      entityId: 'log-1',
      mutationId: 'mutation-1',
      baseVersion: 1,
      remoteVersion: 2,
      baseEntity: const {'version': 1},
      localEntity: const {'version': 1},
      remoteEntity: const {'version': 2},
      conflictingFields: const ['remarks'],
      allowedResolutions: const [
        CollaborationConflictResolution.useRemote,
      ],
      createdAt: DateTime.utc(2026, 7, 12),
    );

CollaborationEventDto _event({
  required String entityType,
  required String entityId,
}) =>
    CollaborationEventDto(
      protocolVersion: 1,
      eventId: 'event-$entityType-$entityId',
      sessionId: 'session-1',
      seq: 3,
      type: '$entityType.updated',
      entityType: entityType,
      entityId: entityId,
      entityVersion: 3,
      occurredAt: DateTime.utc(2026, 7, 12),
      payload: const {},
    );

LiveDraftLockDto _lock(
  String field,
  String leaseId, {
  DateTime? expiresAt,
}) =>
    LiveDraftLockDto(
      leaseId: leaseId,
      sessionId: 'session-1',
      field: field,
      userId: 'user-1',
      username: 'alice',
      deviceId: 'device-1',
      expiresAt: expiresAt ?? DateTime.utc(2026, 7, 14),
    );

LiveDraftPatchResultDto _patchResult(
  int clientSeq, {
  List<LiveDraftReleasedLeaseDto> releasedLeases = const [],
}) {
  return LiveDraftPatchResultDto(
    draft: _draft(version: 2),
    appliedClientSeq: clientSeq,
    replayed: false,
    releasedLeases: releasedLeases,
  );
}

LiveDraftFieldsDto _fields(Map<String, String> values) =>
    LiveDraftFieldsDto(values);

LiveDraftDto _draft({
  String draftId = 'draft-1',
  String sessionId = 'session-1',
  required int version,
  Map<String, String> values = const {},
  Map<String, int> revisions = const {},
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 7, 13);
  return LiveDraftDto(
    draftId: draftId,
    sessionId: sessionId,
    version: version,
    fields: _fields(values),
    fieldRevisions: {
      for (final field in liveDraftFieldNames) field: revisions[field] ?? 0,
    },
    lastUpdatedBy: null,
    createdAt: timestamp,
    lastUpdatedAt: timestamp,
  );
}

LiveDraftSnapshotDto _snapshot({
  required LiveDraftDto draft,
  List<LiveDraftLockDto> locks = const [],
  int currentOrdinal = 8,
  int totalRecords = 7,
  CollaborationLogDto? previousRecord,
}) =>
    LiveDraftSnapshotDto(
      draft: draft,
      locks: locks,
      currentOrdinal: currentOrdinal,
      totalRecords: totalRecords,
      previousRecord: previousRecord,
    );

CollaborationLogDto _log(String syncId, {required String callsign}) =>
    CollaborationLogDto(
      syncId: syncId,
      sessionId: 'session-1',
      version: 1,
      time: DateTime.utc(2026, 7, 13, 12),
      controller: 'BG5CRL',
      callsign: callsign,
      rstSent: '59',
      rstRcvd: '59',
      qth: null,
      device: null,
      power: null,
      antenna: null,
      height: null,
      remarks: null,
      createdAt: DateTime.utc(2026, 7, 13, 12),
      updatedAt: DateTime.utc(2026, 7, 13, 12),
      deletedAt: null,
    );

ServerApiException _serverError(String code, {Object? details}) =>
    ServerApiException(
      error: ApiErrorDto(
        code: code,
        message: code,
        requestId: 'request-1',
        details: details,
      ),
      statusCode: 409,
      retryable: false,
    );
