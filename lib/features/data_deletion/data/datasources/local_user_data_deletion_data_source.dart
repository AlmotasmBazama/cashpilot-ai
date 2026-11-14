import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../domain/entities/data_deletion_operation_context.dart';
import 'receipt_file_deletion_journal.dart';

abstract interface class LocalUserDataDeletionDataSource {
  String get ownerScopeValue;

  Future<bool> hasUnresolvedLegacyFinancialData(
    DataDeletionOperationContext context,
  );

  Future<int> deleteLocalDatabase(DataDeletionOperationContext context);

  Future<int> deleteReceiptFiles(DataDeletionOperationContext context);

  Future<bool> verifyLocalDatabaseEmpty(DataDeletionOperationContext context);
}

class DriftLocalUserDataDeletionDataSource
    implements LocalUserDataDeletionDataSource {
  const DriftLocalUserDataDeletionDataSource(
    this._session, {
    required ReceiptFileDeletionJournal receiptFileJournal,
  }) : _receiptFileJournal = receiptFileJournal;

  final ScopedAppDatabaseSession _session;
  String get _scope => _session.ownerScopeValue;
  final ReceiptFileDeletionJournal _receiptFileJournal;

  @override
  String get ownerScopeValue => _scope;

  @override
  Future<bool> hasUnresolvedLegacyFinancialData(
    DataDeletionOperationContext context,
  ) async {
    _assertScope(context);
    // Legacy ownership is read only after the exact deletion operation has
    // rejoined and drained its durable quarantine. Ordinary scoped reads are
    // intentionally rejected while fenced, so this narrow read must prove the
    // matching operation just like destructive deletion reads do.
    final database = _session.deletionDatabase(
      operationId: context.operationId,
    );
    final row = await database.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM accounts WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM categories
          WHERE owner_scope_id IS NULL AND is_default = 0) +
        (SELECT COUNT(*) FROM payees WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM transactions WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM exchange_rates WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM budgets WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM goals WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM goal_contributions WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM receipts WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM receipt_line_items WHERE owner_scope_id IS NULL) +
        (SELECT COUNT(*) FROM transaction_splits WHERE owner_scope_id IS NULL)
        AS value
    ''').getSingle();
    return row.read<int>('value') > 0;
  }

  @override
  Future<int> deleteLocalDatabase(DataDeletionOperationContext context) async {
    _assertScope(context);
    final database = _session.deletionDatabase(
      operationId: context.operationId,
    );
    final receiptRows = await (database.select(
      database.receipts,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    final protectedLegacyReferences = await _protectedLegacyReceiptReferences(
      database,
    );
    await _receiptFileJournal.stage(
      context,
      receiptRows.map((row) => row.localImageReference),
      protectedLegacyReferences: protectedLegacyReferences,
    );
    return database.transaction(() async {
      var deleted = 0;
      deleted += await _deleteScoped(database, 'ai_agent_plan_steps');
      deleted += await _deleteScoped(database, 'ai_agent_plans');
      deleted += await _deleteScoped(database, 'ai_agent_confirmation_proofs');
      deleted += await _deleteScoped(database, 'ai_agent_execution_results');
      deleted += await _deleteScoped(database, 'ai_agent_execution_attempts');
      deleted += await _deleteScoped(database, 'ai_agent_business_operations');
      deleted += await _deleteScoped(database, 'ai_agent_idempotency_records');
      deleted += await _deleteScoped(database, 'ai_agent_previews');
      deleted += await _deleteScoped(database, 'ai_agent_audit_events');
      deleted += await _deleteScoped(database, 'ai_agent_commands');
      deleted += await _deleteScoped(database, 'transaction_splits');
      deleted += await _deleteScoped(database, 'receipt_line_items');
      deleted += await _deleteScoped(database, 'receipts');
      deleted += await database.deleteTransactionsForOwnerDataDeletion(
        ownerScopeId: _scope,
        operationId: context.operationId,
      );
      deleted += await _deleteScoped(database, 'goal_contributions');
      deleted += await _deleteScoped(database, 'goals');
      deleted += await _deleteScoped(database, 'budgets');
      deleted += await _deleteScoped(database, 'exchange_rates');
      deleted += await _deleteScoped(database, 'payees');
      deleted += await _deleteScoped(database, 'categories');
      deleted += await database.deleteAccountsForOwnerDataDeletion(
        ownerScopeId: _scope,
        operationId: context.operationId,
      );
      deleted += await _deleteSyncQueue(
        database,
        immutableFirebaseUid: context.identity.userId,
      );
      deleted += await _deleteScoped(database, 'owner_scope_migration_audits');
      return deleted;
    });
  }

  @override
  Future<int> deleteReceiptFiles(DataDeletionOperationContext context) async {
    _assertScope(context);
    final database = _session.deletionDatabase(
      operationId: context.operationId,
    );
    await _receiptFileJournal.stage(
      context,
      const <String?>[],
      protectedLegacyReferences: await _protectedLegacyReceiptReferences(
        database,
      ),
    );
    return _receiptFileJournal.drain(context);
  }

  @override
  Future<bool> verifyLocalDatabaseEmpty(
    DataDeletionOperationContext context,
  ) async {
    _assertScope(context);
    final database = _session.deletionDatabase(
      operationId: context.operationId,
    );
    for (final table in _scopedDeletionTables) {
      if (table == 'sync_queue') {
        final row = await database
            .customSelect(
              '''SELECT COUNT(*) AS count FROM sync_queue
             WHERE owner_scope_id = ? OR
               (owner_scope_id IS NULL AND owner_user_id = ?)''',
              variables: <Variable<Object>>[
                Variable<String>(_scope),
                Variable<String>(context.identity.userId),
              ],
            )
            .getSingle();
        if (row.read<int>('count') != 0) {
          return false;
        }
        continue;
      }
      final row = await database
          .customSelect(
            'SELECT COUNT(*) AS count FROM $table WHERE owner_scope_id = ?',
            variables: <Variable<Object>>[Variable<String>(_scope)],
          )
          .getSingle();
      if (row.read<int>('count') != 0) {
        return false;
      }
    }
    return true;
  }

  void _assertScope(DataDeletionOperationContext context) {
    final immutableUidScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
      context.identity.userId,
    ).id.value;
    if (context.identity.ownerScope.id.value != _scope ||
        immutableUidScope != _scope) {
      throw StateError(
        'Deletion context does not match the local owner scope.',
      );
    }
  }

  Future<int> _deleteScoped(AppDatabase database, String tableName) {
    if (!_scopedDeletionTables.contains(tableName)) {
      throw StateError('Unapproved scoped deletion table.');
    }
    return database.customUpdate(
      'DELETE FROM $tableName WHERE owner_scope_id = ?',
      variables: <Variable<Object>>[Variable<String>(_scope)],
    );
  }

  Future<int> _deleteSyncQueue(
    AppDatabase database, {
    required String immutableFirebaseUid,
  }) {
    return database.customUpdate(
      '''DELETE FROM sync_queue
         WHERE owner_scope_id = ? OR
           (owner_scope_id IS NULL AND owner_user_id = ?)''',
      variables: <Variable<Object>>[
        Variable<String>(_scope),
        Variable<String>(immutableFirebaseUid.trim()),
      ],
      updates: <TableInfo<Table, Object?>>{database.syncQueue},
    );
  }

  Future<List<String?>> _protectedLegacyReceiptReferences(
    AppDatabase database,
  ) async {
    final rows = await database
        .customSelect(
          '''SELECT local_image_reference FROM receipts
         WHERE owner_scope_id IS NULL OR owner_scope_id <> ?''',
          variables: <Variable<Object>>[Variable<String>(_scope)],
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            database.receipts,
          },
        )
        .get();
    return rows
        .map((row) => row.readNullable<String>('local_image_reference'))
        .toList(growable: false);
  }

  static const _scopedDeletionTables = <String>{
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
  };
}
