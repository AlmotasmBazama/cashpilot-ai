import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/owner_scoped_storage_keys.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/owner_deletion_quarantine_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_auth_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/cloud_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/data_deletion_operation_state_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/deletion_preferences_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/local_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/receipt_file_deletion_journal.dart';
import 'package:cashpilot_ai/features/data_deletion/data/repositories/data_deletion_repository_impl.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_request.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  for (final stage in <DataDeletionStage>[
    DataDeletionStage.captured,
    DataDeletionStage.reauthenticated,
    DataDeletionStage.backupFenced,
    DataDeletionStage.writersVerified,
  ]) {
    test(
      'production restart at ${stage.name} rejoins its durable fence before legacy reads',
      () async {
        final fixture = await _ProductionResumeFixture.create(
          'pre-cloud-${stage.name}',
          stage,
        );
        addTearDown(fixture.dispose);
        await fixture.insertAccount('deleted-a', fixture.scopeA);
        await fixture.insertAccount('preserved-b', fixture.scopeB);

        final result = await fixture.resume();

        expect(result, isA<AppSuccess<DataDeletionReport>>());
        expect(await fixture.accountCount(fixture.scopeA), 0);
        expect(await fixture.accountCount(fixture.scopeB), 1);
        expect(fixture.cloud.operationIds, [fixture.operationId]);
        expect(fixture.quarantineStore.restore(), isEmpty);
      },
    );
  }

  test(
    'B cannot resume or read A through A durable deletion quarantine',
    () async {
      final fixture = await _ProductionResumeFixture.create(
        'wrong-owner',
        DataDeletionStage.reauthenticated,
      );
      addTearDown(fixture.dispose);
      await fixture.insertAccount('preserved-a', fixture.scopeA);
      await fixture.insertAccount('preserved-b', fixture.scopeB);
      fixture.auth.identity = fixture.identityB;

      final result = await fixture.resume();

      expect(result, isA<AppFailure<DataDeletionReport>>());
      expect(await fixture.accountCount(fixture.scopeA), 1);
      expect(await fixture.accountCount(fixture.scopeB), 1);
      expect(fixture.cloud.operationIds, isEmpty);
      expect(fixture.quarantineStore.restore(), <String, String>{
        fixture.scopeA: fixture.operationId,
      });
    },
  );

  test(
    'production-like B provider graph cannot claim exact A continuation',
    () async {
      final fixture = await _ProductionResumeFixture.create(
        'wrong-owner-provider-graph',
        DataDeletionStage.writersVerified,
        runtimeAsOwnerB: true,
      );
      addTearDown(fixture.dispose);
      await fixture.insertAccount('preserved-a', fixture.scopeA);
      await fixture.insertAccount('preserved-b', fixture.scopeB);

      final result = await fixture.resume(
        expectedRecoveryTarget: fixture.recoveryTarget,
      );

      expect(result, isA<AppFailure<DataDeletionReport>>());
      expect(await fixture.stateStore.read(fixture.identityB), equals(null));
      expect(
        (await fixture.stateStore.read(fixture.identityA))?.operationId,
        fixture.operationId,
      );
      expect(await fixture.accountCount(fixture.scopeA), 1);
      expect(await fixture.accountCount(fixture.scopeB), 1);
      expect(fixture.cloud.operationIds, isEmpty);
      expect(fixture.quarantineStore.restore(), <String, String>{
        fixture.scopeA: fixture.operationId,
      });
    },
  );

  test(
    'expected op1 cannot clear a different stored A op2 authority',
    () async {
      final fixture = await _ProductionResumeFixture.create(
        'wrong-operation',
        DataDeletionStage.writersVerified,
      );
      addTearDown(fixture.dispose);
      final wrongTarget = AccountDeletionRecoveryTarget(
        operationId: '01900000-0000-7000-8000-expected-op1',
        ownerScopeValue: fixture.scopeA,
      );

      final result = await fixture.resume(expectedRecoveryTarget: wrongTarget);

      expect(result, isA<AppFailure<DataDeletionReport>>());
      expect(
        (await fixture.stateStore.read(fixture.identityA))?.operationId,
        fixture.operationId,
      );
      expect(fixture.proofStore.cleared, isFalse);
      expect(fixture.quarantineStore.restore(), <String, String>{
        fixture.scopeA: fixture.operationId,
      });
      expect(fixture.cloud.operationIds, isEmpty);
    },
  );

  test(
    'ambiguous pre-cloud replay failure retains authority and later completes',
    () async {
      final fixture = await _ProductionResumeFixture.create(
        'legacy-read-failure',
        DataDeletionStage.writersVerified,
        failLegacyRead: true,
      );
      addTearDown(fixture.dispose);

      final first = await fixture.resume();

      expect(first, isA<AppFailure<DataDeletionReport>>());
      final retained = await fixture.stateStore.read(fixture.identityA);
      expect(retained?.operationId, fixture.operationId);
      expect(fixture.proofStore.cleared, isFalse);
      expect(fixture.quarantineStore.restore(), <String, String>{
        fixture.scopeA: fixture.operationId,
      });
      expect(fixture.cloud.operationIds, isEmpty);

      final second = await fixture.resume();

      expect(second, isA<AppSuccess<DataDeletionReport>>());
      expect(fixture.cloud.operationIds, [fixture.operationId]);
      expect(fixture.proofStore.cleared, isTrue);
      expect(fixture.quarantineStore.restore(), isEmpty);
    },
  );

  test(
    'production restart at localDatabaseDeleted removes residual A row before Auth and preserves B',
    () async {
      final fixture = await _ProductionResumeFixture.create(
        'local-residual',
        DataDeletionStage.localDatabaseDeleted,
      );
      addTearDown(fixture.dispose);
      await fixture.insertAccount('residual-a', fixture.scopeA);
      await fixture.insertAccount('preserved-b', fixture.scopeB);
      fixture.auth.beforeDelete = (_) async {
        fixture.aStateAtAuth = await fixture.accountCount(fixture.scopeA);
        fixture.bStateAtAuth = await fixture.accountCount(fixture.scopeB);
      };

      final result = await fixture.resume();

      expect(result, isA<AppSuccess<DataDeletionReport>>());
      expect(fixture.aStateAtAuth, 0);
      expect(fixture.bStateAtAuth, 1);
      expect(await fixture.accountCount(fixture.scopeA), 0);
      expect(await fixture.accountCount(fixture.scopeB), 1);
      expect(fixture.authDeletion.deleted, isTrue);
      expect(fixture.cloud.operationIds, [fixture.operationId]);
    },
  );

  test(
    'production restart at receiptFilesDeleted drains residual A journal before Auth and preserves B file',
    () async {
      final fixture = await _ProductionResumeFixture.create(
        'receipt-residual',
        DataDeletionStage.receiptFilesDeleted,
      );
      addTearDown(fixture.dispose);
      final imageA = await fixture.imageStoreA.write(
        'residual-receipt-a',
        const <int>[1, 2, 3],
      );
      final imageB = await fixture.imageStoreB.write(
        'preserved-receipt-b',
        const <int>[4, 5, 6],
      );
      await fixture.journal.stage(fixture.seedContext, const <String?>[]);
      fixture.auth.beforeDelete = (_) async {
        fixture.aStateAtAuth = await File(imageA).exists();
        fixture.bStateAtAuth = await File(imageB).exists();
      };

      final result = await fixture.resume();

      expect(result, isA<AppSuccess<DataDeletionReport>>());
      expect(fixture.aStateAtAuth, isFalse);
      expect(fixture.bStateAtAuth, isTrue);
      expect(await File(imageA).exists(), isFalse);
      expect(await File(imageB).exists(), isTrue);
      expect(fixture.authDeletion.deleted, isTrue);
    },
  );

  test(
    'production restart at preferencesDeleted clears residual A Hive key before Auth and preserves B key',
    () async {
      final fixture = await _ProductionResumeFixture.create(
        'preference-residual',
        DataDeletionStage.preferencesDeleted,
      );
      addTearDown(fixture.dispose);
      final keyA = fixture.keysA.receiptAiPrivacyConsent;
      final keyB = fixture.keysB.receiptAiPrivacyConsent;
      await fixture.box.put(keyA, true);
      await fixture.box.put(keyB, true);
      fixture.auth.beforeDelete = (_) async {
        fixture.aStateAtAuth = fixture.box.containsKey(keyA);
        fixture.bStateAtAuth = fixture.box.containsKey(keyB);
      };

      final result = await fixture.resume();

      expect(result, isA<AppSuccess<DataDeletionReport>>());
      expect(fixture.aStateAtAuth, isFalse);
      expect(fixture.bStateAtAuth, isTrue);
      expect(fixture.box.containsKey(keyA), isFalse);
      expect(fixture.box.containsKey(keyB), isTrue);
      expect(fixture.authDeletion.deleted, isTrue);
    },
  );
}

final class _ProductionResumeFixture {
  _ProductionResumeFixture._({
    required this.directory,
    required this.box,
    required this.database,
    required this.identityA,
    required this.identityB,
    required this.operationId,
    required this.seedContext,
    required this.imageStoreA,
    required this.imageStoreB,
    required this.journal,
    required this.auth,
    required this.authDeletion,
    required this.cloud,
    required this.quarantineStore,
    required this.stateStore,
    required this.proofStore,
    required this.repository,
  });

  static Future<_ProductionResumeFixture> create(
    String name,
    DataDeletionStage storedStage, {
    bool failLegacyRead = false,
    bool runtimeAsOwnerB = false,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'cashpilot-production-resume-$name-',
    );
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('production-resume-$name');
    final database = AppDatabase(executor: NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    final identityA = _identity('restart-owner-a');
    final identityB = _identity('restart-owner-b');
    final operationId = '01989f80-4e00-7000-8000-resume-$name';
    final stateStore = HiveDataDeletionOperationStateStore(box);
    await stateStore.claim(
      identityA,
      proposedOperationId: operationId,
      proposedStartedAtUtc: DateTime.utc(2026, 8, 10),
    );
    var seedContext = DataDeletionOperationContext.captured(
      operationId: operationId,
      identity: identityA,
      startedAtUtc: DateTime.utc(2026, 8, 10),
      idempotencyState: DataDeletionIdempotencyState.resumed,
    );
    while (seedContext.stage.index < storedStage.index) {
      seedContext = seedContext.advance(
        DataDeletionStage.values[seedContext.stage.index + 1],
      );
    }
    await stateStore.checkpoint(seedContext);

    final quarantineStore = HiveOwnerDeletionQuarantineStore(box);
    final initialFence = BackupOperationFence(quarantineStore: quarantineStore);
    final initialLease = await initialFence.fenceAndDrain(
      ownerScopeValue: identityA.ownerScope.id.value,
      operationId: operationId,
      durable: true,
    );
    initialLease.retainQuarantine();
    final restartedFence = BackupOperationFence(
      quarantineStore: quarantineStore,
    );
    final runtimeIdentity = runtimeAsOwnerB ? identityB : identityA;
    final runtimeSession = ScopedAppDatabaseSession(
      database: database,
      scope: runtimeIdentity.ownerScope,
      operationFence: restartedFence,
    );
    final imageStoreA = ReceiptLocalImageStore(
      ownerScopeValue: identityA.ownerScope.id.value,
      baseDirectory: () async => directory,
    );
    final imageStoreB = ReceiptLocalImageStore(
      ownerScopeValue: identityB.ownerScope.id.value,
      baseDirectory: () async => directory,
    );
    final journal = HiveReceiptFileDeletionJournal(
      box,
      receiptImageStore: runtimeAsOwnerB ? imageStoreB : imageStoreA,
    );
    final auth = _ResumeAuthDataSource(runtimeIdentity);
    final authDeletion = _ResumeAccountAuthDeletionDataSource(auth);
    final cloud = _ResumeCloudDataSource();
    final sessionProofStore = _ResumeSessionProofStore();
    final productionLocalDataSource = DriftLocalUserDataDeletionDataSource(
      runtimeSession,
      receiptFileJournal: journal,
    );
    final repository = DataDeletionRepositoryImpl(
      authDataSource: auth,
      authDeletionDataSource: authDeletion,
      cloudDataSource: cloud,
      localDataSource: failLegacyRead
          ? _FailingLegacyReadLocalDataSource(productionLocalDataSource)
          : productionLocalDataSource,
      preferencesDataSource: HiveDeletionPreferencesDataSource(box),
      operationStateStore: stateStore,
      sessionProofStore: sessionProofStore,
      backupOperationFence: restartedFence,
      logger: AppLogger.instance,
    );
    return _ProductionResumeFixture._(
      directory: directory,
      box: box,
      database: database,
      identityA: identityA,
      identityB: identityB,
      operationId: operationId,
      seedContext: seedContext,
      imageStoreA: imageStoreA,
      imageStoreB: imageStoreB,
      journal: journal,
      auth: auth,
      authDeletion: authDeletion,
      cloud: cloud,
      quarantineStore: quarantineStore,
      stateStore: stateStore,
      proofStore: sessionProofStore,
      repository: repository,
    );
  }

  final Directory directory;
  final Box<dynamic> box;
  final AppDatabase database;
  final TrustedDeletionIdentity identityA;
  final TrustedDeletionIdentity identityB;
  final String operationId;
  final DataDeletionOperationContext seedContext;
  final ReceiptLocalImageStore imageStoreA;
  final ReceiptLocalImageStore imageStoreB;
  final HiveReceiptFileDeletionJournal journal;
  final _ResumeAuthDataSource auth;
  final _ResumeAccountAuthDeletionDataSource authDeletion;
  final _ResumeCloudDataSource cloud;
  final HiveOwnerDeletionQuarantineStore quarantineStore;
  final HiveDataDeletionOperationStateStore stateStore;
  final _ResumeSessionProofStore proofStore;
  final DataDeletionRepositoryImpl repository;
  Object? aStateAtAuth;
  Object? bStateAtAuth;

  String get scopeA => identityA.ownerScope.id.value;
  String get scopeB => identityB.ownerScope.id.value;
  AccountDeletionRecoveryTarget get recoveryTarget =>
      AccountDeletionRecoveryTarget(
        operationId: operationId,
        ownerScopeValue: scopeA,
      );
  OwnerScopedStorageKeys get keysA =>
      OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: identityA.userId,
        ownerScope: identityA.ownerScope,
      );
  OwnerScopedStorageKeys get keysB =>
      OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: identityB.userId,
        ownerScope: identityB.ownerScope,
      );

  Future<AppResult<DataDeletionReport>> resume({
    AccountDeletionRecoveryTarget? expectedRecoveryTarget,
  }) => repository.deleteAllUserData(
    DataDeletionRequest(
      confirmationAccepted: true,
      confirmationLease: const AccountDeletionConfirmationLease(
        opaqueToken: 'production-resume-lease',
        isAnonymous: false,
      ),
      expectedRecoveryTarget: expectedRecoveryTarget,
    ),
  );

  Future<void> insertAccount(String id, String ownerScope) =>
      database.customStatement(
        '''INSERT INTO accounts (
          id, owner_scope_id, name, type, currency_code, balance,
          icon, color, created_at, updated_at
        ) VALUES (?, ?, 'Residual', 'cash', 'USD', '1', 'wallet', 1, 1, 1)''',
        <Object?>[id, ownerScope],
      );

  Future<int> accountCount(String ownerScope) async {
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM accounts WHERE owner_scope_id = ?',
          variables: [Variable<String>(ownerScope)],
        )
        .getSingle();
    return row.read<int>('count');
  }

  Future<void> dispose() async {
    await database.close();
    await box.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class _ResumeSessionProofStore
    implements AccountDeletionSessionProofStore {
  final proof = AccountDeletionSessionProof.parse(
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  );
  var status = AccountDeletionSecureOperationStatus.active;
  var cleared = false;

  @override
  Future<void> clear(DataDeletionOperationContext context) async {
    cleared = true;
  }

  @override
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target) async {
    cleared = true;
  }

  @override
  Future<AccountDeletionSessionProof> createAfterReauthentication(
    DataDeletionOperationContext context,
  ) async => proof;

  @override
  Future<AccountDeletionSessionProof> requireExisting(
    DataDeletionOperationContext context,
  ) async => proof;

  @override
  Future<AccountDeletionSessionProof> requireExistingForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async => proof;

  @override
  Future<void> markAbandonedBeforeRemote(
    DataDeletionOperationContext context,
  ) async {
    status = AccountDeletionSecureOperationStatus.abandonedBeforeRemote;
  }

  @override
  Future<void> markServerConfirmed(DataDeletionOperationContext context) async {
    status = AccountDeletionSecureOperationStatus.serverConfirmed;
  }

  @override
  Future<void> markServerConfirmedForRecovery(
    AccountDeletionRecoveryTarget target,
  ) async {
    status = AccountDeletionSecureOperationStatus.serverConfirmed;
  }

  @override
  Future<AccountDeletionSecureOperationStatus> recoveryStatus(
    AccountDeletionRecoveryTarget target,
  ) async => status;

  @override
  Future<List<AccountDeletionRecoveryTarget>> recoveryTargets() async =>
      const <AccountDeletionRecoveryTarget>[];
}

final class _ResumeAuthDataSource implements AccountDeletionAuthDataSource {
  _ResumeAuthDataSource(this.identity);

  TrustedDeletionIdentity identity;
  Future<void> Function(DataDeletionOperationContext context)? beforeDelete;
  @override
  Future<AccountDeletionConfirmationLease> issueConfirmationLease() async =>
      const AccountDeletionConfirmationLease(
        opaqueToken: 'production-resume-lease',
        isAnonymous: false,
      );

  @override
  void releaseConfirmationLease(AccountDeletionConfirmationLease lease) {}

  @override
  Future<TrustedDeletionIdentity> captureSession(
    AccountDeletionConfirmationLease lease,
  ) async => identity;

  @override
  Future<void> reauthenticate(
    DataDeletionOperationContext context, {
    String? email,
    String? password,
  }) async {}

  @override
  Future<void> revalidate(DataDeletionOperationContext context) async {
    assertSessionCurrent(context);
  }

  @override
  Future<String> freshIdToken(DataDeletionOperationContext context) async {
    assertSessionCurrent(context);
    return 'captured-id-token';
  }

  @override
  Future<String> cachedIdTokenForFinalization(
    DataDeletionOperationContext context,
  ) => freshIdToken(context);

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) {
    if (context.identity.authSessionId != identity.authSessionId ||
        context.identity.ownerScope != identity.ownerScope) {
      throw const AccountDeletionIdentityChangedException();
    }
  }

  @override
  Future<void> markServerDeletionCompleted(
    DataDeletionOperationContext context,
  ) async {
    assertSessionCurrent(context);
  }

  @override
  void releaseSession(TrustedDeletionIdentity identity) {}
}

final class _ResumeAccountAuthDeletionDataSource
    implements AccountAuthDeletionDataSource {
  _ResumeAccountAuthDeletionDataSource(this.auth);

  final _ResumeAuthDataSource auth;
  var deleted = false;

  @override
  Future<AccountAuthDeletionReceipt> deleteAuthAccount(
    DataDeletionOperationContext context, {
    bool finalizationRecovery = false,
  }) async {
    auth.assertSessionCurrent(context);
    await auth.beforeDelete?.call(context);
    deleted = true;
    return AccountAuthDeletionReceipt(
      operationId: context.operationId,
      authDeleted: true,
      alreadyDeleted: false,
    );
  }
}

final class _ResumeCloudDataSource implements CloudUserDataDeletionDataSource {
  final List<String> operationIds = <String>[];

  @override
  Future<CloudDeletionReceipt> deleteUserData(
    DataDeletionOperationContext context,
  ) async {
    operationIds.add(context.operationId);
    return CloudDeletionReceipt(
      operationId: context.operationId,
      deletedDocuments: 0,
      verifiedEmpty: true,
    );
  }
}

final class _FailingLegacyReadLocalDataSource
    implements LocalUserDataDeletionDataSource {
  _FailingLegacyReadLocalDataSource(this._delegate);

  final LocalUserDataDeletionDataSource _delegate;
  var _failOnce = true;

  @override
  String get ownerScopeValue => _delegate.ownerScopeValue;

  @override
  Future<bool> hasUnresolvedLegacyFinancialData(
    DataDeletionOperationContext context,
  ) {
    if (_failOnce) {
      _failOnce = false;
      throw StateError('simulated legacy ownership read failure');
    }
    return _delegate.hasUnresolvedLegacyFinancialData(context);
  }

  @override
  Future<int> deleteLocalDatabase(DataDeletionOperationContext context) =>
      _delegate.deleteLocalDatabase(context);

  @override
  Future<int> deleteReceiptFiles(DataDeletionOperationContext context) =>
      _delegate.deleteReceiptFiles(context);

  @override
  Future<bool> verifyLocalDatabaseEmpty(DataDeletionOperationContext context) =>
      _delegate.verifyLocalDatabaseEmpty(context);
}

TrustedDeletionIdentity _identity(String uid) => TrustedDeletionIdentity(
  authSessionId: 'restart-session-$uid',
  authStateGeneration: 1,
  userId: uid,
  isAnonymous: false,
  ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(uid),
);
