import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/sync/application/backup_consent_lifecycle.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/sync_manager.dart';
import 'package:cashpilot_ai/core/sync/application/sync_providers.dart';
import 'package:cashpilot_ai/core/sync/data/firestore_sync_data_source.dart';
import 'package:cashpilot_ai/core/sync/data/sync_preferences_local_data_source.dart';
import 'package:cashpilot_ai/core/sync/data/sync_queue_repository.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_queue_item.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_types.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  const uid = 'synthetic-backup-owner';
  final now = DateTime.utc(2026, 8, 10, 12);
  late AppDatabase database;
  late ScopedAppDatabaseSession ownerSession;
  late DriftSyncQueueRepository repository;
  late BackupOperationFence fence;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    fence = BackupOperationFence();
    ownerSession = scopedTestSession(
      database,
      syntheticFirebaseUid: uid,
      operationFence: fence,
    );
    repository = DriftSyncQueueRepository(ownerSession);
    await _seedAccount(database, repository.ownerScopeValue, now);
  });

  tearDown(() => database.close());

  test('initial opt-in snapshot is scoped, complete, and idempotent', () async {
    await _seedSupportedFixture(database, repository.ownerScopeValue, now);
    final lifecycle = BackupConsentLifecycleCoordinator(
      queueRepository: repository,
      operationFence: fence,
      clock: () => now,
    );

    final first = await lifecycle.apply(
      userId: uid,
      enabled: true,
      generation: 1,
    );
    final second = await lifecycle.apply(
      userId: uid,
      enabled: true,
      generation: 1,
    );
    final pending = await repository.getPending();

    expect(first.snapshotPrepared, isTrue);
    expect(second.snapshotPrepared, isTrue);
    expect(pending, hasLength(SyncEntityType.values.length));
    expect(pending.map((item) => item.entityType).toSet(), {
      SyncEntityType.account,
      SyncEntityType.transaction,
      SyncEntityType.category,
      SyncEntityType.payee,
      SyncEntityType.budget,
      SyncEntityType.goal,
      SyncEntityType.exchangeRate,
      SyncEntityType.settings,
    });
  });

  test(
    'prepared snapshot uploads every supported document exactly once',
    () async {
      await _seedMatureSupportedFixture(
        database,
        repository.ownerScopeValue,
        now,
      );
      final consent = _ConsentState(enabled: true, generation: 1);
      final remote = _RecordingRemote();
      final lifecycle = BackupConsentLifecycleCoordinator(
        queueRepository: repository,
        operationFence: fence,
        readSettingsSnapshot: (_) => <String, dynamic>{
          'baseCurrencyCode': 'LYD',
          'privateSetting': 'must-not-be-backed-up',
        },
        clock: () => now,
      );
      await lifecycle.apply(userId: uid, enabled: true, generation: 1);
      final manager = _manager(
        repository: repository,
        remote: remote,
        fence: fence,
        consent: consent,
      );

      final first = await manager.synchronize(
        userId: uid,
        deviceId: 'opaque-device',
      );
      final second = await manager.synchronize(
        userId: uid,
        deviceId: 'opaque-device',
      );
      final expectedDocumentKeys = <String>{
        'account/account-1',
        'account/account-2',
        'transaction/transaction-1',
        'transaction/transaction-2',
        'category/category-1',
        'category/category-2',
        'payee/payee-1',
        'payee/payee-2',
        'budget/budget-1',
        'budget/budget-2',
        'goal/goal-1',
        'goal/goal-2',
        'exchangeRate/rate-1',
        'exchangeRate/rate-2',
        'settings/main',
      };
      final uploadedDocumentKeys = remote.uploadedItems
          .map((item) => '${item.entityType.name}/${item.entityId}')
          .toList(growable: false);
      final settingsPayload =
          jsonDecode(
                remote.uploadedItems
                    .singleWhere(
                      (item) => item.entityType == SyncEntityType.settings,
                    )
                    .payloadJson,
              )
              as Map<String, dynamic>;
      final goalPayload =
          jsonDecode(
                remote.uploadedItems
                    .singleWhere((item) => item.entityId == 'goal-2')
                    .payloadJson,
              )
              as Map<String, dynamic>;

      expect(first.attemptedCount, expectedDocumentKeys.length);
      expect(second.attemptedCount, 0);
      expect(uploadedDocumentKeys.toSet(), expectedDocumentKeys);
      expect(uploadedDocumentKeys, hasLength(expectedDocumentKeys.length));
      for (final key in expectedDocumentKeys) {
        expect(uploadedDocumentKeys.where((uploaded) => uploaded == key), [
          key,
        ]);
      }
      expect(uploadedDocumentKeys, isNot(contains('account/other-account')));
      expect(settingsPayload, containsPair('baseCurrencyCode', 'LYD'));
      expect(settingsPayload, isNot(contains('privateSetting')));
      expect(
        goalPayload['contributions'],
        contains(
          isA<Map<String, dynamic>>().having(
            (value) => value['id'],
            'id',
            'contribution-2',
          ),
        ),
      );
      expect(remote.uploads, expectedDocumentKeys.length);
      expect(remote.lastSnapshotComplete, isTrue);
      expect(remote.lastSnapshotVersion, SyncManager.snapshotVersion);
      expect(consent.snapshotComplete, isTrue);
    },
  );

  test('reconciliation repairs a missed upsert and a missed delete', () async {
    var result = await repository.reconcileDirtyState(
      forceFull: false,
      reconciledAt: now,
    );
    expect(result.queuedUpserts, 1);
    var pending = await repository.getPending();
    final repairAttempt = await repository.markAttempt(pending.single, now);
    await repository.markCompleted(repairAttempt!);

    await (database.delete(
      database.accounts,
    )..where((row) => row.id.equals('account-1'))).go();
    result = await repository.reconcileDirtyState(
      forceFull: false,
      reconciledAt: now.add(const Duration(minutes: 1)),
    );
    pending = await repository.getPending();

    expect(result.queuedDeletes, 1);
    expect(pending.single.operation, SyncOperationType.delete);

    final consent = _ConsentState(enabled: true, generation: 1);
    final remote = _RecordingRemote();
    final manager = _manager(
      repository: repository,
      remote: remote,
      fence: fence,
      consent: consent,
    );
    final syncResult = await manager.synchronize(
      userId: uid,
      deviceId: 'opaque-device',
    );
    expect(syncResult.deletedCount, 1);
    expect(remote.uploadedItems.single.operation, SyncOperationType.delete);
    expect(await repository.getPending(), isEmpty);
  });

  test(
    'Drift queue stores opaque ownership and no financial payload',
    () async {
      await repository.enqueue(
        SyncQueueItem(
          id: 'privacy-item',
          ownerScopeId: repository.ownerScopeValue,
          entityType: SyncEntityType.account,
          entityId: 'account-1',
          operation: SyncOperationType.upsert,
          payloadJson: jsonEncode({
            'id': 'account-1',
            'balance': '999.99',
            'note': 'sensitive-local-note',
          }),
          status: SyncStatus.pending,
          attemptCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final row = await (database.select(
        database.syncQueue,
      )..where((item) => item.id.equals('privacy-item'))).getSingle();
      expect(row.ownerUserId, repository.ownerScopeValue);
      expect(row.ownerUserId, isNot(uid));
      expect(row.payloadJson, isNot(contains('999.99')));
      expect(row.payloadJson, isNot(contains('sensitive-local-note')));

      final attempt = await repository.markAttempt(
        (await repository.getPending()).single,
        now,
      );
      final uploadItem = attempt!.uploadItem;
      expect(jsonDecode(uploadItem.payloadJson), containsPair('balance', '25'));

      await repository.markCompleted(attempt);
      final completed = await (database.select(
        database.syncQueue,
      )..where((item) => item.id.equals('privacy-item'))).getSingle();
      final manifest =
          jsonDecode(completed.payloadJson) as Map<String, dynamic>;
      expect(manifest.keys, {'fingerprint', 'version'});
      expect(manifest['fingerprint'], matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(completed.payloadJson, isNot(contains('999.99')));
      expect(completed.payloadJson, isNot(contains('sensitive-local-note')));
    },
  );

  test('failed rows retain only bounded non-sensitive diagnostics', () async {
    await repository.enqueue(
      SyncQueueItem(
        id: 'failed-privacy-item',
        ownerScopeId: repository.ownerScopeValue,
        entityType: SyncEntityType.account,
        entityId: 'account-1',
        operation: SyncOperationType.upsert,
        payloadJson: jsonEncode(<String, dynamic>{
          'balance': '999.99',
          'note': 'must-not-survive-a-failure',
        }),
        status: SyncStatus.pending,
        attemptCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final attempt = await repository.markAttempt(
      (await repository.getPending()).single,
      now,
    );
    await repository.markFailed(
      attempt!,
      'remote echoed 999.99 and must-not-survive-a-failure',
      now,
    );

    final failed = await (database.select(
      database.syncQueue,
    )..where((row) => row.id.equals('failed-privacy-item'))).getSingle();
    expect(failed.ownerUserId, repository.ownerScopeValue);
    expect(failed.ownerUserId, isNot(uid));
    expect(failed.payloadJson, '{}');
    expect(failed.lastError, 'sync_upload_failed');
    expect(jsonEncode(failed.toJson()), isNot(contains('999.99')));
    expect(
      jsonEncode(failed.toJson()),
      isNot(contains('must-not-survive-a-failure')),
    );
  });

  test(
    'disable drains a captured writer, purges queue, and writes nothing',
    () async {
      final consent = _ConsentState(enabled: true, generation: 7);
      final remote = _RecordingRemote();
      final blockingRepository = _BlockingPendingRepository(repository);
      final manager = _manager(
        repository: blockingRepository,
        remote: remote,
        fence: fence,
        consent: consent,
      );
      final lifecycle = BackupConsentLifecycleCoordinator(
        queueRepository: repository,
        operationFence: fence,
        clock: () => now,
      );

      final sync = manager.synchronize(userId: uid, deviceId: 'opaque-device');
      await blockingRepository.pendingReadStarted.future;
      consent
        ..enabled = false
        ..generation += 1;
      final disable = lifecycle.apply(
        userId: uid,
        enabled: false,
        generation: consent.generation,
      );
      blockingRepository.releasePendingRead.complete();

      final result = await sync;
      await disable;
      expect(result.blocked, isTrue);
      expect(remote.uploads, 0);
      expect(remote.metadataWrites, 0);
      expect(await database.select(database.syncQueue).get(), isEmpty);
    },
  );

  test(
    'old consent generation cannot write after disable and re-enable',
    () async {
      final consent = _ConsentState(enabled: true, generation: 11);
      final remote = _RecordingRemote();
      final blockingRepository = _BlockingPendingRepository(repository);
      final manager = _manager(
        repository: blockingRepository,
        remote: remote,
        fence: fence,
        consent: consent,
      );

      final sync = manager.synchronize(userId: uid, deviceId: 'opaque-device');
      await blockingRepository.pendingReadStarted.future;
      consent.generation += 2;
      blockingRepository.releasePendingRead.complete();
      final result = await sync;

      expect(result.blocked, isTrue);
      expect(remote.uploads, 0);
      expect(remote.metadataWrites, 0);
    },
  );

  test('disabled consent blocks sync before any remote call', () async {
    final consent = _ConsentState(enabled: false, generation: 13);
    final remote = _RecordingRemote();
    final manager = _manager(
      repository: repository,
      remote: remote,
      fence: fence,
      consent: consent,
    );

    final result = await manager.synchronize(
      userId: uid,
      deviceId: 'opaque-device',
    );

    expect(result.blocked, isTrue);
    expect(result.failures.single.code, 'sync_backup_disabled');
    expect(remote.uploads, 0);
    expect(remote.metadataWrites, 0);
  });

  test(
    'revocation drains an acknowledged call and permits no later writes',
    () async {
      await _seedSupportedFixture(database, repository.ownerScopeValue, now);
      final consent = _ConsentState(enabled: true, generation: 17);
      final remote = _BlockingFirstAcknowledgementRemote();
      final lifecycle = BackupConsentLifecycleCoordinator(
        queueRepository: repository,
        operationFence: fence,
        clock: () => now,
      );
      await lifecycle.apply(userId: uid, enabled: true, generation: 17);
      final manager = _manager(
        repository: repository,
        remote: remote,
        fence: fence,
        consent: consent,
      );

      final sync = manager.synchronize(userId: uid, deviceId: 'opaque-device');
      await remote.firstAcknowledgementPending.future;
      expect(remote.uploads, 1);
      consent
        ..enabled = false
        ..generation += 1;
      var revocationFinished = false;
      final revocation = lifecycle
          .apply(userId: uid, enabled: false, generation: consent.generation)
          .then((result) {
            revocationFinished = true;
            return result;
          });
      await pumpEventQueue();
      expect(revocationFinished, isFalse);

      remote.releaseAcknowledgement.complete();
      final result = await sync;
      final revocationResult = await revocation;

      expect(result.blocked, isTrue);
      expect(revocationResult.queuePurged, isTrue);
      expect(remote.uploads, 1);
      expect(remote.metadataWrites, 0);
      expect(await database.select(database.syncQueue).get(), isEmpty);
    },
  );

  test(
    'an in-flight sync cannot survive a same-UID owner session epoch change',
    () async {
      final consent = _ConsentState(enabled: true, generation: 19);
      final remote = _RecordingRemote();
      final blockingRepository = _BlockingPendingRepository(repository);
      final manager = _manager(
        repository: blockingRepository,
        remote: remote,
        fence: fence,
        consent: consent,
      );

      final sync = manager.synchronize(userId: uid, deviceId: 'opaque-device');
      await blockingRepository.pendingReadStarted.future;
      ownerSession.invalidate();
      final replacementRepository = DriftSyncQueueRepository(
        scopedTestSession(
          database,
          syntheticFirebaseUid: uid,
          operationFence: fence,
        ),
      );
      expect(repository.isActiveForConfirmedRemoteOwner(uid), isFalse);
      expect(
        replacementRepository.isActiveForConfirmedRemoteOwner(uid),
        isTrue,
      );
      blockingRepository.releasePendingRead.complete();

      final result = await sync;
      expect(result.blocked, isTrue);
      expect(result.failures.single.code, 'sync_owner_scope_mismatch');
      expect(remote.uploads, 0);
      expect(remote.metadataWrites, 0);
    },
  );

  test('queue stats fail closed for a stale owner family argument', () async {
    await repository.reconcileDirtyState(forceFull: true, reconciledAt: now);
    final container = ProviderContainer(
      overrides: [syncQueueRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final staleProvider = syncQueueStatsProvider('different-owner');
    final currentProvider = syncQueueStatsProvider(uid);
    final staleSubscription = container.listen(staleProvider, (_, _) {});
    final currentSubscription = container.listen(currentProvider, (_, _) {});
    addTearDown(staleSubscription.close);
    addTearDown(currentSubscription.close);

    final stale = await container.read(staleProvider.future);
    final current = await container.read(currentProvider.future);

    expect(stale.pendingCount, 0);
    expect(stale.failedCount, 0);
    expect(current.pendingCount, greaterThan(0));
  });

  test('remote delete plan is a hard delete with no tombstone payload', () {
    final plan = DefaultFirestoreSyncDataSource.writePlan(
      uid,
      SyncQueueItem(
        id: 'delete-item',
        ownerScopeId: repository.ownerScopeValue,
        entityType: SyncEntityType.transaction,
        entityId: 'transaction-1',
        operation: SyncOperationType.delete,
        payloadJson: jsonEncode({'amount': '500', 'note': 'must-not-survive'}),
        status: SyncStatus.pending,
        attemptCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
      now: now,
    );

    expect(plan.deleteDocument, isTrue);
    expect(plan.payload, isEmpty);
    expect(plan.merge, isFalse);
  });

  test('successful deletes purge their local queue record', () async {
    await repository.enqueue(
      SyncQueueItem(
        id: 'delete-item',
        ownerScopeId: repository.ownerScopeValue,
        entityType: SyncEntityType.account,
        entityId: 'account-1',
        operation: SyncOperationType.delete,
        payloadJson: '{"id":"account-1"}',
        status: SyncStatus.pending,
        attemptCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final attempt = await repository.markAttempt(
      (await repository.getPending()).single,
      now,
    );
    await repository.markCompleted(attempt!);

    expect(await database.select(database.syncQueue).get(), isEmpty);
  });

  test(
    'preferences persist opaque keys and advance consent generation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-backup-consent-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('backup-consent-test');
      final changes = <BackupConsentChange>[];
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });
      final preferences = SyncPreferencesLocalDataSource(
        box,
        operationFence: fence,
        onBackupConsentChanged: (change) async {
          changes.add(change);
          return change.enabled
              ? const BackupConsentLifecycleResult.snapshotPrepared()
              : const BackupConsentLifecycleResult.purged();
        },
      );

      await preferences.saveBackupEnabled(uid, true);
      expect(preferences.readBackupEnabled(uid), isTrue);
      expect(preferences.readConsentGeneration(uid), 1);
      expect(preferences.readInitialSnapshotComplete(uid), isFalse);
      await preferences.saveInitialSnapshotComplete(uid, true);
      expect(preferences.readInitialSnapshotComplete(uid), isTrue);

      await preferences.saveBackupEnabled(uid, false);
      expect(preferences.readBackupEnabled(uid), isFalse);
      expect(preferences.readConsentGeneration(uid), 2);
      expect(preferences.readInitialSnapshotComplete(uid), isFalse);
      expect(changes.map((change) => change.enabled), [true, false]);
      expect(
        box.keys
            .map((key) => key.toString())
            .every((key) => !key.contains(uid)),
        isTrue,
      );
    },
  );

  test('opt-in remains closed until its initial snapshot is durable', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-backup-ordering-',
    );
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('backup-ordering-test');
    final lifecycleStarted = Completer<void>();
    final releaseLifecycle = Completer<void>();
    late SyncPreferencesLocalDataSource preferences;
    addTearDown(() async {
      await box.close();
      await directory.delete(recursive: true);
    });
    preferences = SyncPreferencesLocalDataSource(
      box,
      operationFence: fence,
      onBackupConsentChanged: (change) async {
        expect(change.enabled, isTrue);
        expect(preferences.readBackupEnabled(uid), isFalse);
        expect(preferences.readConsentGeneration(uid), 1);
        expect(preferences.readInitialSnapshotComplete(uid), isFalse);
        lifecycleStarted.complete();
        await releaseLifecycle.future;
        return const BackupConsentLifecycleResult.snapshotPrepared();
      },
    );

    final enabling = preferences.saveBackupEnabled(uid, true);
    await lifecycleStarted.future;
    expect(preferences.readBackupEnabled(uid), isFalse);
    releaseLifecycle.complete();
    await enabling;

    expect(preferences.readBackupEnabled(uid), isTrue);
  });

  test(
    'startup repair purges a disabled owner queue under the fence',
    () async {
      await repository.enqueue(
        SyncQueueItem(
          id: 'startup-orphan',
          ownerScopeId: repository.ownerScopeValue,
          entityType: SyncEntityType.account,
          entityId: 'account-1',
          operation: SyncOperationType.upsert,
          payloadJson: '{}',
          status: SyncStatus.pending,
          attemptCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-backup-startup-repair-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('backup-startup-repair-test');
      final lifecycle = BackupConsentLifecycleCoordinator(
        queueRepository: repository,
        operationFence: fence,
        clock: () => now,
      );
      final preferences = SyncPreferencesLocalDataSource(
        box,
        operationFence: fence,
        onBackupConsentChanged: (change) => lifecycle.apply(
          userId: change.userId,
          enabled: change.enabled,
          generation: change.generation,
        ),
      );
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });

      expect(preferences.readBackupEnabled(uid), isFalse);
      await preferences.repairAfterStartup(uid);

      expect(await repository.getPending(), isEmpty);
      expect(preferences.readBackupEnabled(uid), isFalse);
      expect(fence.isFenced(repository.ownerScopeValue), isFalse);
    },
  );

  test(
    'deletion drains opt-in through the final Hive consent commit',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-backup-final-commit-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('backup-final-commit-test');
      final lifecycleFinished = Completer<void>();
      final finalCommitStarted = Completer<void>();
      final releaseFinalCommit = Completer<void>();
      final preferences = SyncPreferencesLocalDataSource(
        box,
        operationFence: fence,
        onBackupConsentChanged: (_) async {
          lifecycleFinished.complete();
          return const BackupConsentLifecycleResult.snapshotPrepared();
        },
        beforeEnableCommit: () async {
          finalCommitStarted.complete();
          await releaseFinalCommit.future;
        },
      );
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });

      final enabling = preferences.saveBackupEnabled(uid, true);
      final enablingExpectation = expectLater(
        enabling,
        throwsA(isA<BackupWriterCancelledException>()),
      );
      await lifecycleFinished.future;
      await finalCommitStarted.future;
      var deletionDrained = false;
      final deletion = fence
          .fenceAndDrain(
            ownerScopeValue: repository.ownerScopeValue,
            operationId: 'delete-after-backup-lifecycle',
          )
          .then((lease) {
            deletionDrained = true;
            return lease;
          });
      await pumpEventQueue();
      expect(deletionDrained, isFalse);

      releaseFinalCommit.complete();
      await enablingExpectation;
      final deletionLease = await deletion;
      expect(preferences.readBackupEnabled(uid), isFalse);
      deletionLease.release();
    },
  );

  test('last-backup metadata cannot outlive deletion fencing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-last-backup-fence-',
    );
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('last-backup-fence-test');
    final writeStarted = Completer<void>();
    final releaseWrite = Completer<void>();
    final preferences = SyncPreferencesLocalDataSource(
      box,
      operationFence: fence,
      beforeOwnerWrite: () async {
        writeStarted.complete();
        await releaseWrite.future;
      },
    );
    addTearDown(() async {
      await box.close();
      await directory.delete(recursive: true);
    });

    final saving = preferences.saveLastBackupAt(uid, now);
    final savingExpectation = expectLater(
      saving,
      throwsA(isA<BackupWriterCancelledException>()),
    );
    await writeStarted.future;
    final deletion = fence.fenceAndDrain(
      ownerScopeValue: repository.ownerScopeValue,
      operationId: 'delete-before-last-backup-write',
    );
    releaseWrite.complete();
    await savingExpectation;
    final deletionLease = await deletion;
    expect(preferences.readLastBackupAt(uid), isNull);
    deletionLease.release();
  });
}

SyncManager _manager({
  required SyncQueueRepository repository,
  required FirestoreSyncDataSource remote,
  required BackupOperationFence fence,
  required _ConsentState consent,
}) {
  return SyncManager(
    queueRepository: repository,
    remoteDataSource: remote,
    operationFence: fence,
    isBackupEnabled: (_) => consent.enabled,
    readConsentGeneration: (_) => consent.generation,
    isInitialSnapshotComplete: (_) => consent.snapshotComplete,
    saveInitialSnapshotComplete: (_, complete) async {
      consent.snapshotComplete = complete;
    },
  );
}

class _ConsentState {
  _ConsentState({required this.enabled, required this.generation});

  bool enabled;
  int generation;
  bool snapshotComplete = false;
}

class _RecordingRemote implements FirestoreSyncDataSource {
  int uploads = 0;
  int metadataWrites = 0;
  bool? lastSnapshotComplete;
  int? lastSnapshotVersion;
  final List<SyncQueueItem> uploadedItems = <SyncQueueItem>[];

  @override
  Future<void> uploadItem(String userId, SyncQueueItem item) async {
    uploads++;
    uploadedItems.add(item);
  }

  @override
  Future<void> updateSyncMetadata({
    required String userId,
    required String deviceId,
    required DateTime syncedAt,
    required int uploadedCount,
    required int failedCount,
    required bool snapshotComplete,
    required int snapshotVersion,
  }) async {
    metadataWrites++;
    lastSnapshotComplete = snapshotComplete;
    lastSnapshotVersion = snapshotVersion;
  }
}

class _BlockingFirstAcknowledgementRemote extends _RecordingRemote {
  final Completer<void> firstAcknowledgementPending = Completer<void>();
  final Completer<void> releaseAcknowledgement = Completer<void>();

  @override
  Future<void> uploadItem(String userId, SyncQueueItem item) async {
    await super.uploadItem(userId, item);
    if (!firstAcknowledgementPending.isCompleted) {
      firstAcknowledgementPending.complete();
      await releaseAcknowledgement.future;
    }
  }
}

class _BlockingPendingRepository implements SyncQueueRepository {
  _BlockingPendingRepository(this.delegate);

  final SyncQueueRepository delegate;
  final Completer<void> pendingReadStarted = Completer<void>();
  final Completer<void> releasePendingRead = Completer<void>();

  @override
  String get ownerScopeValue => delegate.ownerScopeValue;

  @override
  bool matchesConfirmedRemoteOwner(String firebaseUid) =>
      delegate.matchesConfirmedRemoteOwner(firebaseUid);

  @override
  bool isActiveForConfirmedRemoteOwner(String firebaseUid) =>
      delegate.isActiveForConfirmedRemoteOwner(firebaseUid);

  @override
  Future<void> enqueue(SyncQueueItem item) => delegate.enqueue(item);

  @override
  Future<List<SyncQueueItem>> getPending() async {
    if (!pendingReadStarted.isCompleted) {
      pendingReadStarted.complete();
    }
    await releasePendingRead.future;
    return delegate.getPending();
  }

  @override
  Future<SyncReconciliationResult> reconcileDirtyState({
    required bool forceFull,
    required DateTime reconciledAt,
  }) => delegate.reconcileDirtyState(
    forceFull: forceFull,
    reconciledAt: reconciledAt,
  );

  @override
  Future<void> purgeAll({String? fencedOperationId}) =>
      delegate.purgeAll(fencedOperationId: fencedOperationId);

  @override
  Future<SyncUploadAttempt?> markAttempt(
    SyncQueueItem item,
    DateTime attemptedAt,
  ) => delegate.markAttempt(item, attemptedAt);

  @override
  Future<bool> markCompleted(SyncUploadAttempt attempt) =>
      delegate.markCompleted(attempt);

  @override
  Future<bool> markFailed(
    SyncUploadAttempt attempt,
    String error,
    DateTime failedAt,
  ) => delegate.markFailed(attempt, error, failedAt);

  @override
  Future<void> retryFailed(DateTime updatedAt) =>
      delegate.retryFailed(updatedAt);

  @override
  Stream<SyncQueueStats> watchStats() => delegate.watchStats();
}

Future<void> _seedAccount(
  AppDatabase database,
  String scope,
  DateTime now, {
  String id = 'account-1',
  String name = 'Cash',
  String balance = '25',
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          ownerScopeId: Value(scope),
          name: name,
          type: 'cash',
          currencyCode: 'USD',
          balance: balance,
          icon: 'wallet',
          color: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _seedMatureSupportedFixture(
  AppDatabase database,
  String scope,
  DateTime now,
) async {
  await _seedSupportedFixture(database, scope, now);
  await _seedAccount(
    database,
    scope,
    now,
    id: 'account-2',
    name: 'Savings',
    balance: '75',
  );
  await database
      .into(database.categories)
      .insert(
        CategoriesCompanion.insert(
          id: 'category-2',
          ownerScopeId: Value(scope),
          name: 'Travel',
          type: 'expense',
          icon: 'travel',
          color: 4,
          sortOrder: 2,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.payees)
      .insert(
        PayeesCompanion.insert(
          id: 'payee-2',
          ownerScopeId: Value(scope),
          name: 'Airline',
          normalizedName: 'airline',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: 'transaction-2',
          ownerScopeId: Value(scope),
          accountId: 'account-2',
          categoryId: 'category-2',
          payeeId: const Value('payee-2'),
          amount: '15',
          currencyCode: 'USD',
          type: 'expense',
          paymentMethod: 'card',
          source: 'manual',
          status: 'posted',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: 'budget-2',
          ownerScopeId: Value(scope),
          name: 'Travel budget',
          categoryId: 'category-2',
          amount: '300',
          currency: 'USD',
          periodType: 'monthly',
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          alertThresholdPercent: 75,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.goals)
      .insert(
        GoalsCompanion.insert(
          id: 'goal-2',
          ownerScopeId: Value(scope),
          title: 'Trip',
          type: 'savings',
          targetAmount: '500',
          currentAmount: '20',
          currency: 'USD',
          icon: 'plane',
          color: 5,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.goalContributions)
      .insert(
        GoalContributionsCompanion.insert(
          id: 'contribution-2',
          ownerScopeId: Value(scope),
          goalId: 'goal-2',
          amount: '20',
          currency: 'USD',
          creditedAmount: '20',
          date: now,
          linkedTransactionId: const Value('transaction-2'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.exchangeRates)
      .insert(
        ExchangeRatesCompanion.insert(
          id: 'rate-2',
          ownerScopeId: Value(scope),
          baseCurrency: 'USD',
          quoteCurrency: 'LYD',
          rate: '4.8',
          source: 'manual',
          fetchedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

  final otherScope = scopedTestSession(
    database,
    syntheticFirebaseUid: 'other-backup-owner',
  ).ownerScopeValue;
  await _seedAccount(
    database,
    otherScope,
    now,
    id: 'other-account',
    name: 'Other owner account',
    balance: '900',
  );
}

Future<void> _seedSupportedFixture(
  AppDatabase database,
  String scope,
  DateTime now,
) async {
  await database
      .into(database.categories)
      .insert(
        CategoriesCompanion.insert(
          id: 'category-1',
          ownerScopeId: Value(scope),
          name: 'Food',
          type: 'expense',
          icon: 'food',
          color: 2,
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.payees)
      .insert(
        PayeesCompanion.insert(
          id: 'payee-1',
          ownerScopeId: Value(scope),
          name: 'Merchant',
          normalizedName: 'merchant',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: 'transaction-1',
          ownerScopeId: Value(scope),
          accountId: 'account-1',
          categoryId: 'category-1',
          amount: '5',
          currencyCode: 'USD',
          type: 'expense',
          paymentMethod: 'cash',
          source: 'manual',
          status: 'posted',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.budgets)
      .insert(
        BudgetsCompanion.insert(
          id: 'budget-1',
          ownerScopeId: Value(scope),
          name: 'Food budget',
          categoryId: 'category-1',
          amount: '100',
          currency: 'USD',
          periodType: 'monthly',
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          alertThresholdPercent: 80,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.goals)
      .insert(
        GoalsCompanion.insert(
          id: 'goal-1',
          ownerScopeId: Value(scope),
          title: 'Emergency fund',
          type: 'savings',
          targetAmount: '1000',
          currentAmount: '50',
          currency: 'USD',
          icon: 'goal',
          color: 3,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.exchangeRates)
      .insert(
        ExchangeRatesCompanion.insert(
          id: 'rate-1',
          ownerScopeId: Value(scope),
          baseCurrency: 'USD',
          quoteCurrency: 'EUR',
          rate: '0.9',
          source: 'manual',
          fetchedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
}
