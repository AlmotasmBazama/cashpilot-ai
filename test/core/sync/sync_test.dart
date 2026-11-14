import 'dart:async';
import 'dart:convert';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/sync_manager.dart';
import 'package:cashpilot_ai/core/sync/application/sync_mutation_queue.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/data/firestore_sync_data_source.dart';
import 'package:cashpilot_ai/core/sync/data/sync_queue_repository.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_queue_item.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_types.dart';
import 'package:cashpilot_ai/features/accounts/data/datasources/local/accounts_local_data_source.dart';
import 'package:cashpilot_ai/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/accounts/domain/repositories/opening_balance_ledger.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/balance_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/finance_validation_service.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transaction_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transfer_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/local_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/receipt_file_deletion_journal.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_account_balance_repository.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_source.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late DriftSyncQueueRepository queueRepository;
  late _FakeFirestoreSyncDataSource remote;
  late SyncManager manager;
  late BackupOperationFence operationFence;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    queueRepository = DriftSyncQueueRepository(
      scopedTestSession(database, syntheticFirebaseUid: 'user-1'),
    );
    remote = _FakeFirestoreSyncDataSource();
    operationFence = BackupOperationFence();
    manager = SyncManager(
      queueRepository: queueRepository,
      remoteDataSource: remote,
      operationFence: operationFence,
      isBackupEnabled: (_) => true,
      readConsentGeneration: (_) => 1,
      isInitialSnapshotComplete: (_) => true,
      saveInitialSnapshotComplete: (_, _) async {},
    );
    await _seedSyncAccount(database, queueRepository.ownerScopeValue);
  });

  tearDown(() => database.close());

  test(
    'successful local mutation creates an owned pending queue item',
    () async {
      final mutationQueue = BestEffortSyncMutationQueue(
        repository: queueRepository,
        currentOwner: () =>
            const SyncOwner(userId: 'user-1', isAnonymous: false),
        isBackupEnabled: (_) => true,
        logger: AppLogger.instance,
        operationFence: operationFence,
      );
      final repository = AccountsRepositoryImpl(
        localDataSource: DriftAccountsLocalDataSource(
          scopedTestSession(database, syntheticFirebaseUid: 'user-1'),
        ),
        openingBalanceLedger: const _UnexpectedOpeningBalanceLedger(),
        logger: AppLogger.instance,
        syncQueue: mutationQueue,
      );
      final account = Account.create(
        id: 'created-account',
        name: 'Cash',
        type: AccountType.cash,
        currencyCode: 'USD',
        balance: Decimal.zero,
        icon: 'wallet',
        color: 0xFF006C67,
      );

      expect(
        await repository.createAccount(account),
        isA<AppSuccess<Account>>(),
      );

      final pending = await queueRepository.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.entityType, SyncEntityType.account);
      expect(pending.single.entityId, 'created-account');
      expect(
        jsonDecode(pending.single.payloadJson),
        isNot(contains('balance')),
      );
    },
  );

  test('successful upload marks queue item synced', () async {
    await queueRepository.enqueue(_item(id: 'queue-success'));

    final result = await manager.synchronize(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    final row = await _row(database, 'queue-success');

    expect(result.isSuccess, isTrue);
    expect(result.syncedCount, 1);
    expect(row.status, SyncStatus.synced.name);
    expect(row.attemptCount, 1);
    expect(
      remote.uploaded.single.ownerScopeId,
      queueRepository.ownerScopeValue,
    );
    expect(remote.uploaded.single.ownerScopeId, isNot('user-1'));
  });

  test('failed upload keeps error and attempt metadata', () async {
    remote.failUploads = true;
    await queueRepository.enqueue(_item(id: 'queue-failure'));

    final result = await manager.synchronize(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    final row = await _row(database, 'queue-failure');

    expect(result.failedCount, 1);
    expect(row.status, SyncStatus.failed.name);
    expect(row.attemptCount, 1);
    expect(row.lastError, 'sync_upload_failed');
    expect(row.lastAttemptAt, isNotNull);
  });

  test('retry requeues failures and increments attempts', () async {
    remote.failUploads = true;
    await queueRepository.enqueue(_item(id: 'queue-retry'));
    await manager.synchronize(userId: 'user-1', deviceId: 'device-1');
    remote.failUploads = false;

    final result = await manager.synchronize(
      userId: 'user-1',
      deviceId: 'device-1',
      retryFailed: true,
    );
    final row = await _row(database, 'queue-retry');

    expect(result.isSuccess, isTrue);
    expect(row.status, SyncStatus.synced.name);
    expect(row.attemptCount, 2);
    expect(row.lastError, isNull);
  });

  test('duplicate upserts compact to one pending manifest', () async {
    final createdAt = DateTime.utc(2026, 7, 14, 10);
    await queueRepository.enqueue(
      _item(
        id: 'queue-first',
        payloadJson: '{"id":"account-1","name":"Old"}',
        createdAt: createdAt,
      ),
    );
    await queueRepository.enqueue(
      _item(
        id: 'queue-second',
        payloadJson: '{"id":"account-1","name":"Latest"}',
        createdAt: createdAt.add(const Duration(minutes: 1)),
      ),
    );

    final pending = await queueRepository.getPending();
    final allRows = await database.select(database.syncQueue).get();

    expect(pending, hasLength(1));
    expect(pending.single.id, 'queue-first');
    expect(jsonDecode(pending.single.payloadJson), isEmpty);
    expect(allRows, hasLength(1));
  });

  test(
    'retry after a lost acknowledgement does not duplicate remote docs',
    () async {
      remote.failAfterWrite = true;
      await queueRepository.enqueue(_item(id: 'queue-lost-ack'));

      await manager.synchronize(userId: 'user-1', deviceId: 'device-1');
      var row = await _row(database, 'queue-lost-ack');
      expect(row.status, SyncStatus.failed.name);
      expect(row.attemptCount, 1);
      expect(row.lastError, 'sync_upload_failed');
      expect(remote.documents, hasLength(1));

      remote.failAfterWrite = false;
      final result = await manager.synchronize(
        userId: 'user-1',
        deviceId: 'device-1',
        retryFailed: true,
      );
      row = await _row(database, 'queue-lost-ack');

      expect(result.isSuccess, isTrue);
      expect(row.status, SyncStatus.synced.name);
      expect(row.attemptCount, 2);
      expect(row.lastError, isNull);
      expect(remote.uploaded, hasLength(2));
      expect(remote.documents, hasLength(1));
      expect(remote.documents, contains('users/user-1/accounts/account-1'));
    },
  );

  test(
    'a tombstone supersedes a pending upsert and finishes deleted',
    () async {
      await queueRepository.enqueue(_item(id: 'queue-upsert'));
      await queueRepository.enqueue(
        _item(
          id: 'queue-delete',
          operation: SyncOperationType.delete,
          payloadJson: '{"id":"account-1"}',
          createdAt: DateTime.utc(2026, 7, 14, 0, 1),
        ),
      );
      await (database.delete(
        database.accounts,
      )..where((row) => row.id.equals('account-1'))).go();

      final pending = await queueRepository.getPending();
      expect(pending, hasLength(1));
      expect(pending.single.id, 'queue-upsert');
      expect(pending.single.operation, SyncOperationType.delete);

      final result = await manager.synchronize(
        userId: 'user-1',
        deviceId: 'device-1',
      );
      final row = await (database.select(
        database.syncQueue,
      )..where((item) => item.id.equals('queue-upsert'))).getSingleOrNull();

      expect(result.deletedCount, 1);
      expect(row, isNull);
      expect(remote.uploaded.single.operation, SyncOperationType.delete);
      expect(remote.documents, hasLength(1));
      expect(
        remote.documents['users/user-1/accounts/account-1']?.operation,
        SyncOperationType.delete,
      );
    },
  );

  test(
    'v14 tombstone is migrated to its opaque owner and hidden from B',
    () async {
      const ownerAUid = 'user-1';
      const ownerBUid = 'user-2';
      const deletedEntityId = 'legacy-remote-account';
      await database.customStatement(
        '''INSERT INTO sync_queue (
             id, owner_scope_id, owner_user_id, entity_type, entity_id,
             operation, payload_json, status, attempt_count, created_at,
             updated_at
           ) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, 0, ?, ?)''',
        <Object?>[
          'legacy-a-delete',
          ownerAUid,
          SyncEntityType.account.name,
          deletedEntityId,
          SyncOperationType.delete.name,
          '{"privateNote":"must be scrubbed"}',
          SyncStatus.pending.name,
          DateTime.utc(2025, 1, 1).millisecondsSinceEpoch ~/ 1000,
          DateTime.utc(2025, 1, 1).millisecondsSinceEpoch ~/ 1000,
        ],
      );

      final ownerBRepository = DriftSyncQueueRepository(
        scopedTestSession(database, syntheticFirebaseUid: ownerBUid),
      );
      await ownerBRepository.reconcileDirtyState(
        forceFull: false,
        reconciledAt: DateTime.utc(2026, 7, 14),
      );

      expect(await ownerBRepository.getPending(), isEmpty);
      final stillOwnedByLegacyA = await _row(database, 'legacy-a-delete');
      expect(stillOwnedByLegacyA.ownerScopeId, isNull);
      expect(stillOwnedByLegacyA.ownerUserId, ownerAUid);

      await queueRepository.reconcileDirtyState(
        forceFull: false,
        reconciledAt: DateTime.utc(2026, 7, 14),
      );
      final migrated = await _row(database, 'legacy-a-delete');
      expect(
        migrated.ownerScopeId,
        OwnerScopeDerivation.fromConfirmedFirebaseUid(ownerAUid).id.value,
      );
      expect(migrated.ownerUserId, migrated.ownerScopeId);
      expect(migrated.ownerUserId, isNot(ownerAUid));
      expect(migrated.payloadJson, '{}');

      final result = await manager.synchronize(
        userId: ownerAUid,
        deviceId: 'device-1',
      );
      final uploadedDelete = remote.uploaded.singleWhere(
        (item) => item.entityId == deletedEntityId,
      );
      expect(result.deletedCount, 1);
      expect(uploadedDelete.operation, SyncOperationType.delete);
      expect(
        remote.documents,
        contains('users/$ownerAUid/accounts/$deletedEntityId'),
      );
    },
  );

  test(
    'legacy migration deletes whitespace UID collision instead of normalizing it',
    () async {
      await _insertLegacyQueueRow(
        database,
        id: 'canonical-owner-row',
        ownerUid: 'user-1',
        operation: SyncOperationType.upsert.name,
      );
      await _insertLegacyQueueRow(
        database,
        id: 'whitespace-owner-row',
        ownerUid: ' user-1',
        operation: SyncOperationType.upsert.name,
      );

      await queueRepository.reconcileDirtyState(
        forceFull: false,
        reconciledAt: DateTime.utc(2026, 7, 14),
      );

      final canonical =
          await (database.select(database.syncQueue)
                ..where((row) => row.id.equals('canonical-owner-row')))
              .getSingleOrNull();
      final collision =
          await (database.select(database.syncQueue)
                ..where((row) => row.id.equals('whitespace-owner-row')))
              .getSingleOrNull();
      expect(canonical?.ownerScopeId, queueRepository.ownerScopeValue);
      expect(collision, isNull);
    },
  );

  test(
    'B reconcile never claims v14 A rows while privileged A deletion runs',
    () async {
      const ownerAUid = 'legacy-owner-a';
      const ownerBUid = 'legacy-owner-b';
      final fence = BackupOperationFence();
      final ownerASession = scopedTestSession(
        database,
        syntheticFirebaseUid: ownerAUid,
        operationFence: fence,
      );
      final ownerBSession = scopedTestSession(
        database,
        syntheticFirebaseUid: ownerBUid,
        operationFence: fence,
      );
      final ownerBRepository = DriftSyncQueueRepository(ownerBSession);
      for (final fixture in <({String id, String uid, String operation})>[
        (id: 'legacy-a-upsert', uid: ownerAUid, operation: 'upsert'),
        (id: 'legacy-a-delete', uid: ownerAUid, operation: 'delete'),
        (id: 'legacy-b-upsert', uid: ownerBUid, operation: 'upsert'),
        (id: 'legacy-b-delete', uid: ownerBUid, operation: 'delete'),
      ]) {
        await _insertLegacyQueueRow(
          database,
          id: fixture.id,
          ownerUid: fixture.uid,
          operation: fixture.operation,
        );
      }

      final operationId = 'delete-legacy-owner-a';
      final deletionLease = await fence.fenceAndDrain(
        ownerScopeValue: ownerASession.ownerScopeValue,
        operationId: operationId,
      );
      addTearDown(deletionLease.release);
      final context = DataDeletionOperationContext.captured(
        operationId: operationId,
        identity: TrustedDeletionIdentity(
          authSessionId: 'legacy-a-session',
          authStateGeneration: 1,
          userId: ownerAUid,
          isAnonymous: false,
          ownerScope: ownerASession.confirmedScope,
        ),
        startedAtUtc: DateTime.utc(2026, 7, 14),
      );
      final localDeletion = DriftLocalUserDataDeletionDataSource(
        ownerASession,
        receiptFileJournal: const _NoopReceiptFileDeletionJournal(),
      );

      await ownerBRepository.reconcileDirtyState(
        forceFull: false,
        reconciledAt: DateTime.utc(2026, 7, 14),
      );
      final aBeforeDeletion =
          await (database.select(database.syncQueue)..where(
                (row) =>
                    row.id.isIn(<String>['legacy-a-upsert', 'legacy-a-delete']),
              ))
              .get();
      expect(aBeforeDeletion, hasLength(2));
      expect(aBeforeDeletion.every((row) => row.ownerScopeId == null), isTrue);
      expect(
        aBeforeDeletion.every((row) => row.ownerUserId == ownerAUid),
        isTrue,
      );

      await Future.wait(<Future<Object?>>[
        ownerBRepository.reconcileDirtyState(
          forceFull: false,
          reconciledAt: DateTime.utc(2026, 7, 14, 0, 1),
        ),
        localDeletion.deleteLocalDatabase(context),
      ]);

      final remaining = await database.select(database.syncQueue).get();
      expect(remaining.where((row) => row.id.startsWith('legacy-a-')), isEmpty);
      final ownerBRows = remaining
          .where((row) => row.id.startsWith('legacy-b-'))
          .toList(growable: false);
      expect(ownerBRows, hasLength(2));
      expect(
        ownerBRows.every(
          (row) =>
              row.ownerScopeId == ownerBSession.ownerScopeValue &&
              row.ownerUserId == ownerBSession.ownerScopeValue,
        ),
        isTrue,
      );
      expect(await localDeletion.verifyLocalDatabaseEmpty(context), isTrue);
    },
  );

  test(
    'V2 coalesced during a paused V1 upload remains pending and reaches remote',
    () async {
      final blockingRemote = _BlockingFirstUploadRemote();
      final blockingManager = SyncManager(
        queueRepository: queueRepository,
        remoteDataSource: blockingRemote,
        operationFence: operationFence,
        isBackupEnabled: (_) => true,
        readConsentGeneration: (_) => 1,
        isInitialSnapshotComplete: (_) => true,
        saveInitialSnapshotComplete: (_, _) async {},
      );
      await queueRepository.enqueue(_item(id: 'queue-v1'));

      final firstSync = blockingManager.synchronize(
        userId: 'user-1',
        deviceId: 'device-1',
      );
      final uploadedV1 = await blockingRemote.firstUploadStarted.future;
      expect(jsonDecode(uploadedV1.payloadJson), containsPair('balance', '25'));

      await (database.update(database.accounts)..where(
            (row) =>
                row.ownerScopeId.equals(queueRepository.ownerScopeValue) &
                row.id.equals('account-1'),
          ))
          .write(
            AccountsCompanion(
              balance: const Value('50'),
              updatedAt: Value(DateTime.utc(2026, 7, 14, 0, 1)),
            ),
          );
      await queueRepository.enqueue(
        _item(id: 'queue-v2', createdAt: DateTime.utc(2026, 7, 14, 0, 1)),
      );
      blockingRemote.releaseFirstUpload.complete();
      final first = await firstSync;

      final afterV1 = await _row(database, 'queue-v1');
      expect(afterV1.status, SyncStatus.pending.name);
      expect(first.syncedCount, 0);
      expect(first.deletedCount, 0);
      expect(first.failedCount, 1);
      expect(first.failures.single.code, 'sync_attempt_superseded');
      expect(first.isSuccess, isFalse);

      final second = await blockingManager.synchronize(
        userId: 'user-1',
        deviceId: 'device-1',
      );
      final remoteDocument =
          blockingRemote.documents['users/user-1/accounts/account-1'];
      expect(second.syncedCount, 1);
      expect(
        jsonDecode(remoteDocument!.payloadJson),
        containsPair('balance', '50'),
      );
      expect(blockingRemote.uploaded, hasLength(2));
    },
  );

  test(
    'attempt snapshots the current row after getPending coalesces settings V2',
    () async {
      await queueRepository.enqueue(
        _item(
          id: 'settings-v1',
          entityType: SyncEntityType.settings,
          entityId: 'main',
          payloadJson: '{"backupMode":"v1"}',
        ),
      );
      final blockingRepository = _BlockingAttemptQueueRepository(
        queueRepository,
      );
      final attemptRemote = _FakeFirestoreSyncDataSource();
      final attemptManager = SyncManager(
        queueRepository: blockingRepository,
        remoteDataSource: attemptRemote,
        operationFence: operationFence,
        isBackupEnabled: (_) => true,
        readConsentGeneration: (_) => 1,
        isInitialSnapshotComplete: (_) => true,
        saveInitialSnapshotComplete: (_, _) async {},
      );

      final sync = attemptManager.synchronize(
        userId: 'user-1',
        deviceId: 'device-1',
      );
      final staleSnapshot = await blockingRepository.attemptStarted.future;
      expect(staleSnapshot.entityType, SyncEntityType.settings);
      expect(
        jsonDecode(staleSnapshot.payloadJson),
        containsPair('backupMode', 'v1'),
      );
      await queueRepository.enqueue(
        _item(
          id: 'settings-v2',
          entityType: SyncEntityType.settings,
          entityId: 'main',
          payloadJson: '{"backupMode":"v2"}',
          createdAt: DateTime.utc(2026, 7, 14, 0, 1),
        ),
      );
      blockingRepository.releaseAttempt.complete();
      await sync;

      final settingsUpload = attemptRemote.uploaded.singleWhere(
        (item) => item.entityType == SyncEntityType.settings,
      );
      expect(
        jsonDecode(settingsUpload.payloadJson),
        containsPair('backupMode', 'v2'),
      );
    },
  );

  test('re-running sync skips completed queue items', () async {
    await queueRepository.enqueue(_item(id: 'queue-idempotent'));

    final first = await manager.synchronize(
      userId: 'user-1',
      deviceId: 'device-1',
    );
    final second = await manager.synchronize(
      userId: 'user-1',
      deviceId: 'device-1',
    );

    expect(first.attemptedCount, 1);
    expect(second.attemptedCount, 0);
    expect(remote.uploaded, hasLength(1));
  });

  test(
    'writer captured before deletion fence cannot upload or resurrect',
    () async {
      await queueRepository.enqueue(_item(id: 'queue-before-fence'));
      final blockingRepository = _BlockingPendingQueueRepository(
        queueRepository,
      );
      final blockedRemote = _FakeFirestoreSyncDataSource();
      final blockedManager = SyncManager(
        queueRepository: blockingRepository,
        remoteDataSource: blockedRemote,
        operationFence: operationFence,
        isBackupEnabled: (_) => true,
        readConsentGeneration: (_) => 1,
        isInitialSnapshotComplete: (_) => true,
        saveInitialSnapshotComplete: (_, _) async {},
      );

      final sync = blockedManager.synchronize(
        userId: 'user-1',
        deviceId: 'device-1',
      );
      await blockingRepository.pendingReadStarted.future;
      final deletion = operationFence.fenceAndDrain(
        ownerScopeValue: queueRepository.ownerScopeValue,
        operationId: 'deletion-operation-1',
      );
      expect(operationFence.isFenced(queueRepository.ownerScopeValue), isTrue);

      blockingRepository.releasePendingRead.complete();
      final deletionLease = await deletion;
      final result = await sync;

      expect(result.blocked, isTrue);
      expect(blockedRemote.uploaded, isEmpty);
      expect(blockedRemote.documents, isEmpty);
      expect(blockedRemote.metadataWrites, 0);
      deletionLease.release();
    },
  );

  test('unauthenticated and guest backup attempts are blocked', () async {
    final signedOut = await manager.synchronize(
      userId: null,
      deviceId: 'device-1',
    );
    final guest = await manager.synchronize(
      userId: 'guest-1',
      deviceId: 'device-1',
      isAnonymous: true,
    );

    expect(signedOut.blocked, isTrue);
    expect(guest.blocked, isTrue);
    expect(remote.uploaded, isEmpty);
    expect(remote.metadataWrites, 0);
  });

  test('noncanonical UID is blocked without normalization', () async {
    final result = await manager.synchronize(
      userId: ' user-1',
      deviceId: 'device-1',
    );

    expect(result.blocked, isTrue);
    expect(remote.uploaded, isEmpty);
    expect(remote.metadataWrites, 0);
  });

  test('Firestore paths are always user scoped', () {
    expect(
      DefaultFirestoreSyncDataSource.documentPath(
        'user-7',
        SyncEntityType.transaction,
        'tx-1',
      ),
      'users/user-7/transactions/tx-1',
    );
    expect(
      DefaultFirestoreSyncDataSource.documentPath(
        'user-7',
        SyncEntityType.settings,
        'ignored',
      ),
      'users/user-7/settings/main',
    );
    expect(
      () => DefaultFirestoreSyncDataSource.documentPath(
        '',
        SyncEntityType.account,
        'account-1',
      ),
      throwsArgumentError,
    );
    for (final invalidUid in const [
      ' user-7',
      'user-7 ',
      'user/7',
      '.',
      '..',
    ]) {
      expect(
        () => DefaultFirestoreSyncDataSource.documentPath(
          invalidUid,
          SyncEntityType.account,
          'account-1',
        ),
        throwsArgumentError,
        reason: invalidUid,
      );
    }
  });

  test(
    'sync hook failure preserves business write and reconciles observably',
    () async {
      await _seedAccount(database);
      final throwingQueue = _RecordingSyncMutationQueue(throwOnEnqueue: true);
      final repository = _transactionsRepository(database, throwingQueue);

      final result = await repository.createTransaction(
        _transaction('tx-safe'),
      );

      expect(result, isA<AppSuccess<Transaction>>());
      final stored = await (database.select(
        database.transactions,
      )..where((row) => row.id.equals('tx-safe'))).getSingleOrNull();
      expect(stored, isNotNull);
      expect(await queueRepository.getPending(), isEmpty);

      final reconciliation = await manager.synchronize(
        userId: 'user-1',
        deviceId: 'device-1',
      );
      final repairedUpload = remote.uploaded.singleWhere(
        (item) =>
            item.entityType == SyncEntityType.transaction &&
            item.entityId == 'tx-safe',
      );
      final repairedManifest =
          await (database.select(database.syncQueue)..where(
                (row) =>
                    row.entityType.equals(SyncEntityType.transaction.name) &
                    row.entityId.equals('tx-safe'),
              ))
              .getSingle();

      expect(reconciliation.isSuccess, isTrue);
      expect(reconciliation.attemptedCount, greaterThanOrEqualTo(1));
      expect(reconciliation.syncedCount, greaterThanOrEqualTo(1));
      expect(
        jsonDecode(repairedUpload.payloadJson),
        containsPair('id', 'tx-safe'),
      );
      expect(repairedManifest.status, SyncStatus.synced.name);
      expect(
        (jsonDecode(repairedManifest.payloadJson) as Map<String, dynamic>).keys,
        {'fingerprint', 'version'},
      );
    },
  );

  test('transaction backup payload contains no balance mutation', () async {
    await _seedAccount(database);
    final recordingQueue = _RecordingSyncMutationQueue();
    final repository = _transactionsRepository(database, recordingQueue);

    await repository.createTransaction(_transaction('tx-payload'));

    expect(recordingQueue.upserts, hasLength(1));
    final payload = recordingQueue.upserts.single.payload;
    expect(payload.keys, isNot(contains('balance')));
    expect(payload.keys, isNot(contains('accountBalance')));
    expect(jsonEncode(payload).toLowerCase(), isNot(contains('balance')));
  });

  test(
    'uploading a transaction never mutates the local account balance',
    () async {
      await _seedAccount(database);
      await queueRepository.enqueue(
        _item(
          id: 'queue-transaction',
          entityType: SyncEntityType.transaction,
          entityId: 'transaction-1',
          payloadJson: '{"id":"transaction-1","amount":"10"}',
        ),
      );
      final before = await (database.select(
        database.accounts,
      )..where((row) => row.id.equals('cash'))).getSingle();

      await manager.synchronize(userId: 'user-1', deviceId: 'device-1');
      final after = await (database.select(
        database.accounts,
      )..where((row) => row.id.equals('cash'))).getSingle();

      expect(before.balance, '100');
      expect(after.balance, before.balance);
    },
  );
}

class _UnexpectedOpeningBalanceLedger implements OpeningBalanceLedger {
  const _UnexpectedOpeningBalanceLedger();

  @override
  Future<void> postOpeningBalance({
    required String accountId,
    required Decimal amount,
    required String currencyCode,
    required DateTime occurredAt,
  }) {
    throw StateError('A zero-balance sync fixture must not post an opening.');
  }
}

SyncQueueItem _item({
  required String id,
  SyncEntityType entityType = SyncEntityType.account,
  String entityId = 'account-1',
  SyncOperationType operation = SyncOperationType.upsert,
  String payloadJson = '{"id":"account-1"}',
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.utc(2026, 7, 14);
  return SyncQueueItem(
    id: id,
    ownerScopeId: OwnerScopeDerivation.fromConfirmedFirebaseUid(
      'user-1',
    ).id.value,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    payloadJson: payloadJson,
    status: SyncStatus.pending,
    attemptCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Future<SyncQueueRow> _row(AppDatabase database, String id) {
  return (database.select(
    database.syncQueue,
  )..where((row) => row.id.equals(id))).getSingle();
}

Future<void> _insertLegacyQueueRow(
  AppDatabase database, {
  required String id,
  required String ownerUid,
  required String operation,
}) {
  return database.customStatement(
    '''INSERT INTO sync_queue (
         id, owner_scope_id, owner_user_id, entity_type, entity_id, operation,
         payload_json, status, attempt_count, created_at, updated_at
       ) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, 0, ?, ?)''',
    <Object?>[
      id,
      ownerUid,
      SyncEntityType.account.name,
      'remote-$id',
      operation,
      '{"private":"must-not-cross-owner"}',
      SyncStatus.pending.name,
      DateTime.utc(2025, 1, 1).millisecondsSinceEpoch ~/ 1000,
      DateTime.utc(2025, 1, 1).millisecondsSinceEpoch ~/ 1000,
    ],
  );
}

final class _NoopReceiptFileDeletionJournal
    implements ReceiptFileDeletionJournal {
  const _NoopReceiptFileDeletionJournal();

  @override
  Future<void> stage(
    DataDeletionOperationContext context,
    Iterable<String?> references, {
    Iterable<String?> protectedLegacyReferences = const <String?>[],
  }) async {}

  @override
  Future<int> drain(DataDeletionOperationContext context) async => 0;
}

class _BlockingPendingQueueRepository implements SyncQueueRepository {
  _BlockingPendingQueueRepository(this.delegate);

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

class _BlockingAttemptQueueRepository implements SyncQueueRepository {
  _BlockingAttemptQueueRepository(this.delegate);

  final SyncQueueRepository delegate;
  final Completer<SyncQueueItem> attemptStarted = Completer<SyncQueueItem>();
  final Completer<void> releaseAttempt = Completer<void>();

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
  Future<List<SyncQueueItem>> getPending() => delegate.getPending();

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
  ) async {
    if (!attemptStarted.isCompleted) {
      attemptStarted.complete(item);
      await releaseAttempt.future;
    }
    return delegate.markAttempt(item, attemptedAt);
  }

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

class _FakeFirestoreSyncDataSource implements FirestoreSyncDataSource {
  bool failUploads = false;
  bool failAfterWrite = false;
  final List<SyncQueueItem> uploaded = [];
  final Map<String, SyncQueueItem> documents = {};
  int metadataWrites = 0;

  @override
  Future<void> uploadItem(String userId, SyncQueueItem item) async {
    if (failUploads) {
      throw StateError('offline');
    }
    final path = DefaultFirestoreSyncDataSource.documentPath(
      userId,
      item.entityType,
      item.entityId,
    );
    documents[path] = item;
    uploaded.add(item);
    if (failAfterWrite) {
      throw StateError('acknowledgement lost');
    }
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
  }
}

class _BlockingFirstUploadRemote extends _FakeFirestoreSyncDataSource {
  final Completer<SyncQueueItem> firstUploadStarted =
      Completer<SyncQueueItem>();
  final Completer<void> releaseFirstUpload = Completer<void>();

  @override
  Future<void> uploadItem(String userId, SyncQueueItem item) async {
    if (!firstUploadStarted.isCompleted) {
      firstUploadStarted.complete(item);
      await releaseFirstUpload.future;
    }
    await super.uploadItem(userId, item);
  }
}

class _RecordingSyncMutationQueue implements SyncMutationQueue {
  _RecordingSyncMutationQueue({this.throwOnEnqueue = false});

  final bool throwOnEnqueue;
  final List<({SyncEntityType type, String id, Map<String, dynamic> payload})>
  upserts = [];

  @override
  Future<void> enqueueDelete(SyncEntityType entityType, String entityId) async {
    if (throwOnEnqueue) {
      throw StateError('cloud queue unavailable');
    }
  }

  @override
  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    if (throwOnEnqueue) {
      throw StateError('cloud queue unavailable');
    }
    upserts.add((type: entityType, id: entityId, payload: payload));
  }
}

TransactionsRepositoryImpl _transactionsRepository(
  AppDatabase database,
  SyncMutationQueue queue,
) {
  final session = scopedTestSession(database, syntheticFirebaseUid: 'user-1');
  final accountRepository = DriftAccountBalanceRepository(session);
  final transactionManager = DriftFinanceTransactionManager(session);
  return TransactionsRepositoryImpl(
    localDataSource: DriftTransactionsLocalDataSource(session),
    transactionProcessor: TransactionProcessor(
      accountBalanceRepository: accountRepository,
      transactionManager: transactionManager,
      balanceCalculator: const BalanceCalculator(),
      validationService: const FinanceValidationService(),
    ),
    transferProcessor: TransferProcessor(
      accountBalanceRepository: accountRepository,
      transactionManager: transactionManager,
      balanceCalculator: const BalanceCalculator(),
      validationService: const FinanceValidationService(),
      exchangeRateProvider: const SameCurrencyExchangeRateProvider(),
    ),
    logger: AppLogger.instance,
    syncQueue: queue,
  );
}

Transaction _transaction(String id) => Transaction.create(
  id: id,
  accountId: 'cash',
  categoryId: 'food',
  amount: Money(amount: Decimal.parse('10'), currencyCode: 'USD'),
  type: TransactionType.expense,
  paymentMethod: PaymentMethod.cash,
  source: TransactionSource.manual,
  status: TransactionStatus.posted,
  transactionDate: DateTime.utc(2026, 7, 14),
  createdAt: DateTime.utc(2026, 7, 14),
  updatedAt: DateTime.utc(2026, 7, 14),
);

Future<void> _seedAccount(AppDatabase database) {
  return database
      .into(database.accounts)
      .insertOnConflictUpdate(
        AccountsCompanion(
          id: const Value('cash'),
          ownerScopeId: Value(
            scopedTestSession(
              database,
              syntheticFirebaseUid: 'user-1',
            ).ownerScopeValue,
          ),
          name: const Value('Cash'),
          type: const Value('cash'),
          currencyCode: const Value('USD'),
          balance: const Value('100'),
          icon: const Value('wallet'),
          color: const Value(0xFF006C67),
          isArchived: const Value(false),
          createdAt: Value(DateTime.utc(2026, 7, 14)),
          updatedAt: Value(DateTime.utc(2026, 7, 14)),
        ),
      );
}

Future<void> _seedSyncAccount(AppDatabase database, String scope) {
  return database
      .into(database.accounts)
      .insertOnConflictUpdate(
        AccountsCompanion(
          id: const Value('account-1'),
          ownerScopeId: Value(scope),
          name: const Value('Sync account'),
          type: const Value('cash'),
          currencyCode: const Value('USD'),
          balance: const Value('25'),
          icon: const Value('wallet'),
          color: const Value(0xFF006C67),
          isArchived: const Value(false),
          createdAt: Value(DateTime.utc(2026, 7, 14)),
          updatedAt: Value(DateTime.utc(2026, 7, 14)),
        ),
      );
}
