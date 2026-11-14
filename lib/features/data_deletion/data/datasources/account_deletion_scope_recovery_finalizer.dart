import 'package:drift/drift.dart';
import 'package:hive/hive.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../../../core/storage/settings_keys.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../../auth/auth_contracts.dart';
import '../../../receipts/receipt_cleanup.dart';
import '../../application/account_deletion_startup_recovery_coordinator.dart';
import '../../domain/entities/data_deletion_operation_context.dart';
import 'data_deletion_operation_state_store.dart';

typedef AccountDeletionRecoveryReceiptImageStoreFactory =
    ReceiptImageCleanupPort Function(String ownerScopeValue);

/// Production UID-free local finalizer for a proof-bound, server-confirmed
/// account deletion recovery.
///
/// [AccountDeletionRecoveryTarget.ownerScopeValue] is an opaque commitment,
/// not a Firebase UID. Every mutation is scoped by that commitment and is
/// allowed only while the exact recovery operation owns a drained writer
/// fence.
final class UidFreeAccountDeletionScopeRecoveryFinalizer
    implements AccountDeletionScopeRecoveryFinalizer {
  const UidFreeAccountDeletionScopeRecoveryFinalizer({
    required AppDatabase database,
    required BackupOperationFence operationFence,
    required Box<dynamic> settingsBox,
    required AccountDeletionCompletionOverlay completedDeletionOverlay,
    required DataDeletionOperationStateStore operationStateStore,
    required AccountDeletionRecoveryReceiptImageStoreFactory
    receiptImageStoreFactory,
  }) : _database = database,
       _operationFence = operationFence,
       _settingsBox = settingsBox,
       _completedDeletionOverlay = completedDeletionOverlay,
       _operationStateStore = operationStateStore,
       _receiptImageStoreFactory = receiptImageStoreFactory;

  final AppDatabase _database;
  final BackupOperationFence _operationFence;
  final Box<dynamic> _settingsBox;
  final AccountDeletionCompletionOverlay _completedDeletionOverlay;
  final DataDeletionOperationStateStore _operationStateStore;
  final AccountDeletionRecoveryReceiptImageStoreFactory
  _receiptImageStoreFactory;

  @override
  Future<void> deleteLocalRows(AccountDeletionRecoveryTarget target) async {
    _assertDrained(target);
    await _database.transaction(() async {
      _assertDrained(target);
      for (final table in _orderedScopedDeletionTables) {
        if (table == 'transactions') {
          await _database.deleteTransactionsForOwnerDataDeletion(
            ownerScopeId: target.ownerScopeValue,
            operationId: target.operationId,
          );
          continue;
        }
        if (table == 'accounts') {
          await _database.deleteAccountsForOwnerDataDeletion(
            ownerScopeId: target.ownerScopeValue,
            operationId: target.operationId,
          );
          continue;
        }
        await _database.customUpdate(
          'DELETE FROM $table WHERE owner_scope_id = ?',
          variables: <Variable<Object>>[
            Variable<String>(target.ownerScopeValue),
          ],
        );
      }
      _assertDrained(target);
    });
  }

  @override
  Future<bool> verifyLocalRowsEmpty(
    AccountDeletionRecoveryTarget target,
  ) async {
    _assertDrained(target);
    for (final table in _orderedScopedDeletionTables) {
      final result = await _database
          .customSelect(
            'SELECT COUNT(*) AS count FROM $table WHERE owner_scope_id = ?',
            variables: <Variable<Object>>[
              Variable<String>(target.ownerScopeValue),
            ],
          )
          .getSingle();
      if (result.read<int>('count') != 0) return false;
    }
    _assertDrained(target);
    return true;
  }

  @override
  Future<void> deleteReceiptFiles(AccountDeletionRecoveryTarget target) async {
    _assertDrained(target);
    final imageStore = _receiptImageStoreFactory(target.ownerScopeValue);
    await imageStore.deleteAll();
    if (!await imageStore.isEmpty) {
      throw StateError('Scoped receipt image deletion was not verified.');
    }

    final journalKey = _storageKeys(
      target,
    ).receiptFileDeletionJournal(target.operationId);
    final chunkPrefix = '$journalKey:chunk:';
    final journalKeys = _settingsBox.keys
        .whereType<String>()
        .where((key) => key == journalKey || key.startsWith(chunkPrefix))
        .toList(growable: false);
    if (journalKeys.isNotEmpty) {
      await _settingsBox.deleteAll(journalKeys);
    }
    final journalRemains = _settingsBox.keys.whereType<String>().any(
      (key) => key == journalKey || key.startsWith(chunkPrefix),
    );
    if (journalRemains) {
      throw StateError('Scoped receipt deletion journal was not cleared.');
    }
    _assertDrained(target);
  }

  @override
  Future<void> clearPreferences(AccountDeletionRecoveryTarget target) async {
    _assertDrained(target);
    final keys = _preferenceKeys(target);
    await _settingsBox.deleteAll(keys);
    if (keys.any(_settingsBox.containsKey)) {
      throw StateError('Owner-scoped deletion preferences were not cleared.');
    }
    _assertDrained(target);
  }

  @override
  Future<void> markCompletionOverlay(
    AccountDeletionRecoveryTarget target,
  ) async {
    _assertDrained(target);
    final ownerScope =
        OwnerScopeDerivation.fromTrustedDeletionRecoveryCommitment(
          target.ownerScopeValue,
        );
    await _completedDeletionOverlay.markCompleted(
      ownerScope: ownerScope,
      capturedAuthGeneration: -1,
      operationId: target.operationId,
    );
    if (!_completedDeletionOverlay.hasTrustedCompletion(
      operationId: target.operationId,
      ownerScope: ownerScope,
      capturedAuthGeneration: -1,
    )) {
      throw StateError('Account deletion completion was not recorded.');
    }
    _assertDrained(target);
  }

  @override
  Future<void> clearOperationState(AccountDeletionRecoveryTarget target) async {
    _assertDrained(target);
    await _operationStateStore.clearRecovery(target);
    if (_settingsBox.containsKey(
      _storageKeys(target).dataDeletionOperationState,
    )) {
      throw StateError('Account deletion operation state was not cleared.');
    }
    _assertDrained(target);
  }

  OwnerScopedStorageKeys _storageKeys(AccountDeletionRecoveryTarget target) =>
      OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
        target.ownerScopeValue,
      );

  List<String> _preferenceKeys(AccountDeletionRecoveryTarget target) {
    final scope = target.ownerScopeValue;
    final keys = _storageKeys(target);
    return <String>[
      '${SettingsKeys.backupEnabled}_$scope',
      '${SettingsKeys.lastBackupAt}_$scope',
      '${SettingsKeys.backupConsentGeneration}_$scope',
      '${SettingsKeys.backupInitialSnapshotComplete}_$scope',
      ...keys.values,
    ];
  }

  void _assertDrained(AccountDeletionRecoveryTarget target) {
    _operationFence.assertDrained(
      ownerScopeValue: target.ownerScopeValue,
      operationId: target.operationId,
    );
  }

  // This must remain in lockstep with the production authenticated deletion
  // data source. Ordering removes dependants before their parent rows. The
  // legacy raw-identity column is intentionally never consulted.
  static const _orderedScopedDeletionTables = <String>[
    'ai_agent_plan_steps',
    'ai_agent_plans',
    'ai_agent_confirmation_proofs',
    'ai_agent_execution_results',
    'ai_agent_execution_attempts',
    'ai_agent_business_operations',
    'ai_agent_idempotency_records',
    'ai_agent_previews',
    'ai_agent_audit_events',
    'ai_agent_commands',
    'transaction_splits',
    'receipt_line_items',
    'receipts',
    'transactions',
    'goal_contributions',
    'goals',
    'budgets',
    'exchange_rates',
    'payees',
    'categories',
    'accounts',
    'sync_queue',
    'owner_scope_migration_audits',
  ];
}
