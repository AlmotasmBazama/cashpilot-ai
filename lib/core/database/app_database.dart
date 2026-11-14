import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:decimal/decimal.dart';

import '../error/app_exception.dart';
import '../../features/ai_assistant/data/app_agent/tables/ai_agent_tables.dart';
import '../../features/accounts/data/datasources/local/tables/accounts_table.dart';
import '../../features/budgets/data/datasources/local/tables/budgets_table.dart';
import '../../features/categories/domain/defaults/default_category_definitions.dart';
import '../../features/categories/data/datasources/local/tables/categories_table.dart';
import '../../features/exchange_rates/data/datasources/local/tables/exchange_rates_table.dart';
import '../../features/goals/data/datasources/local/tables/goal_contributions_table.dart';
import '../../features/goals/data/datasources/local/tables/goals_table.dart';
import '../../features/payees/data/datasources/local/tables/payees_table.dart';
import '../../features/receipts/data/datasources/local/tables/receipt_line_items_table.dart';
import '../../features/receipts/data/datasources/local/tables/receipts_table.dart';
import '../../features/receipts/data/datasources/local/tables/transaction_splits_table.dart';
import '../../features/transactions/data/datasources/local/tables/transactions_table.dart';
import '../sync/data/tables/sync_queue_table.dart';
import '../sync/data/legacy_sync_queue_migration.dart';
import '../owner_scope/data/tables/owner_scope_migration_audits_table.dart';

part 'app_database.g.dart';
part 'app_database_account_balance_projection.dart';
part 'app_database_account_lifecycle_guards.dart';
part 'app_database_owner_data_deletion.dart';
part 'app_database_owner_scope_guard_ddl.dart';
part 'app_database_transfer_pair_capability.dart';
part 'app_database_transfer_guard_ddl.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Payees,
    Transactions,
    ExchangeRates,
    Budgets,
    Goals,
    GoalContributions,
    SyncQueue,
    Receipts,
    ReceiptLineItems,
    TransactionSplits,
    OwnerScopeMigrationAudits,
    AiAgentCommands,
    AiAgentPreviews,
    AiAgentConfirmationProofs,
    AiAgentExecutionAttempts,
    AiAgentExecutionResults,
    AiAgentPlans,
    AiAgentPlanSteps,
    AiAgentAuditEvents,
    AiAgentIdempotencyRecords,
    AiAgentBusinessOperations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({
    QueryExecutor? executor,
    bool? enforceOwnerScopeGuards,
    bool? enforceFinancialIntegrityGuards,
  }) : _enforceOwnerScopeGuards = enforceOwnerScopeGuards ?? executor == null,
       _enforceFinancialIntegrityGuards =
           enforceFinancialIntegrityGuards ??
           enforceOwnerScopeGuards ??
           executor == null,
       super(executor ?? _openConnection());

  /// Custom executors are used by historical migration fixtures. Production
  /// always uses the default connection and therefore always enables guards.
  final bool _enforceOwnerScopeGuards;

  /// Historical migration fixtures can explicitly opt out. Production and
  /// guards-on tests keep the account ledger projection protected in SQLite.
  final bool _enforceFinancialIntegrityGuards;

  @override
  int get schemaVersion => 17;

  /// Inserts the two authoritative transfer legs under one connection-local
  /// capability. Raw callers cannot commit an orphan, duplicate role, or
  /// third leg; the outer financial transaction still owns balance mutation.
  Future<void> insertTransferPair({
    required String ownerScopeId,
    required String payloadFingerprint,
    required TransactionsCompanion outgoing,
    required TransactionsCompanion incoming,
  }) => _insertTransferPair(
    ownerScopeId: ownerScopeId,
    payloadFingerprint: payloadFingerprint,
    outgoing: outgoing,
    incoming: incoming,
  );

  Future<void> updateTransferPair({
    required String ownerScopeId,
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
    required String targetStatus,
    required TransactionsCompanion outgoing,
    required TransactionsCompanion incoming,
  }) => _updateTransferPair(
    ownerScopeId: ownerScopeId,
    transferGroupId: transferGroupId,
    outgoingTransactionId: outgoingTransactionId,
    incomingTransactionId: incomingTransactionId,
    targetStatus: targetStatus,
    outgoing: outgoing,
    incoming: incoming,
  );

  Future<void> deleteTransferPair({
    required String ownerScopeId,
    required String transferGroupId,
    required String outgoingTransactionId,
    required String incomingTransactionId,
  }) => _deleteTransferPair(
    ownerScopeId: ownerScopeId,
    transferGroupId: transferGroupId,
    outgoingTransactionId: outgoingTransactionId,
    incomingTransactionId: incomingTransactionId,
  );

  Future<int> deleteTransactionsForOwnerDataDeletion({
    required String ownerScopeId,
    required String operationId,
  }) => _deleteOwnerTransactions(
    ownerScopeId: ownerScopeId,
    operationId: operationId,
  );

  /// Claims only structurally valid legacy transaction sets. The capability
  /// is connection-local and permits NULL -> exact confirmed scope only.
  Future<int> claimLegacyTransactions({required String ownerScopeId}) =>
      _claimLegacyTransactions(ownerScopeId: ownerScopeId);

  /// Re-audits durable transfer rows for one owner. Corruption remains the
  /// durable quarantine marker: callers must not infer missing fingerprints,
  /// delete ambiguous legs, or guess a balance repair.
  Future<bool> hasMalformedTransferGroupsForOwner(String ownerScopeId) =>
      _hasMalformedTransferGroupsForOwner(ownerScopeId);

  /// The only application-level projection writer for a stored account
  /// balance. SQLite receives a one-shot, exact old/new permit in the same
  /// transaction, so a raw or over-broad account update cannot reuse it.
  Future<int> updateAccountBalanceProjection({
    required String ownerScopeId,
    required String accountId,
    required String balance,
    required DateTime updatedAt,
  }) => _updateAccountBalanceProjection(
    ownerScopeId: ownerScopeId,
    accountId: accountId,
    balance: balance,
    updatedAt: updatedAt,
  );

  /// Privacy deletion is the sole exception to the zero-balance close rule.
  /// The caller has already proven the deletion operation against the scoped
  /// writer fence; the marker exists only inside this transaction. Reference
  /// guards still reject deletion until all dependent rows are gone.
  Future<int> deleteAccountsForOwnerDataDeletion({
    required String ownerScopeId,
    required String operationId,
  }) => _deleteOwnerAccounts(
    ownerScopeId: ownerScopeId,
    operationId: operationId,
  );

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(accounts);
        }

        if (from < 3) {
          await migrator.createTable(categories);
        }

        if (from < 4) {
          await migrator.createTable(payees);
          await migrator.createTable(transactions);
        }

        if (from >= 2 && from < 5) {
          await migrator.addColumn(accounts, accounts.paymentMethodIds);
        }

        // Versions older than 4 create the current transactions table above,
        // so only databases that already had that table need this column add.
        if (from >= 4 && from < 6) {
          await migrator.addColumn(transactions, transactions.transferGroupId);
        }

        // Older databases already have the compact payees table. Databases
        // created before v4 receive the current table from createTable above.
        if (from >= 4 && from < 7) {
          await migrator.addColumn(payees, payees.type);
          await migrator.addColumn(payees, payees.aliases);
          await migrator.addColumn(payees, payees.defaultCategoryId);
          await migrator.addColumn(payees, payees.defaultAccountId);
          await migrator.addColumn(payees, payees.notes);
          await migrator.addColumn(payees, payees.lastUsedAt);
          await migrator.addColumn(payees, payees.archivedAt);
          // Preserve legacy transaction references by promoting distinct text
          // payee ids into minimal first-class payees when no row exists.
          await customStatement('''
            INSERT OR IGNORE INTO payees (
              id, name, normalized_name, type, aliases, created_at, updated_at
            )
            SELECT
              payee_id,
              TRIM(payee_id),
              LOWER(TRIM(payee_id)),
              'other',
              '[]',
              MIN(created_at),
              MAX(updated_at)
            FROM transactions
            WHERE payee_id IS NOT NULL AND TRIM(payee_id) <> ''
            GROUP BY payee_id
          ''');
        }

        if (from < 8) {
          await _addMissingTransferMetadataColumns(migrator);
        }

        if (from < 9) {
          await migrator.createTable(exchangeRates);
        }

        if (from < 10) {
          await migrator.createTable(budgets);
        }

        if (from < 11) {
          await migrator.createTable(goals);
          await migrator.createTable(goalContributions);
        }

        if (from < 12) {
          await migrator.createTable(syncQueue);
        }

        if (from < 13) {
          await _addMissingIncomeSourceTypeColumn(migrator);
        }

        if (from < 14) {
          await _createReceiptTablesIfMissing(migrator);
        }

        if (from < 15) {
          await _upgradeToOwnerScopedV15(migrator);
        }
        if (from < 16) {
          await _upgradeToReconciliationV16(migrator);
        }
        if (from < 17) {
          await _addMissingTransferPayloadFingerprintColumn(migrator);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await LegacySyncQueueMigration.runGlobally(
          this,
          syncQueueTable: syncQueue,
        );
        await customStatement('''
          CREATE INDEX IF NOT EXISTS transactions_transfer_group_id_idx
          ON transactions (transfer_group_id)
        ''');
        await _createPayeeIndexes();
        await _createExchangeRateIndexes();
        await _createBudgetIndexes();
        await _createGoalIndexes();
        await _createSyncQueueIndexes();
        await _createReceiptIndexes();
        await _createOwnerScopeIndexes();
        if (_enforceOwnerScopeGuards) {
          await _createOwnerScopeWriteGuards();
          await _createOwnerScopeReferenceGuards();
          await _createOwnerScopeExtendedGuards();
        }
        if (_enforceFinancialIntegrityGuards) {
          await _createAccountFinancialIntegrityGuards();
          await _createTransferFinancialIntegrityGuards();
        }
      },
    );
  }

  Future<void> _addMissingTransferMetadataColumns(Migrator migrator) async {
    final tableInfo = await customSelect(
      'PRAGMA table_info(transactions)',
    ).get();
    final columnNames = tableInfo
        .map((row) => row.read<String>('name'))
        .toSet();

    if (!columnNames.contains('transfer_group_id')) {
      await migrator.addColumn(transactions, transactions.transferGroupId);
    }
    if (!columnNames.contains('exchange_rate_from_currency_code')) {
      await migrator.addColumn(
        transactions,
        transactions.exchangeRateFromCurrencyCode,
      );
    }
    if (!columnNames.contains('exchange_rate_to_currency_code')) {
      await migrator.addColumn(
        transactions,
        transactions.exchangeRateToCurrencyCode,
      );
    }
    if (!columnNames.contains('exchange_rate')) {
      await migrator.addColumn(transactions, transactions.exchangeRate);
    }
    if (!columnNames.contains('exchange_rate_as_of')) {
      await migrator.addColumn(transactions, transactions.exchangeRateAsOf);
    }
  }

  Future<void> _addMissingTransferPayloadFingerprintColumn(
    Migrator migrator,
  ) async {
    final columns = await customSelect('PRAGMA table_info(transactions)').get();
    if (columns.any(
      (row) => row.read<String>('name') == 'transfer_payload_fingerprint',
    )) {
      return;
    }
    await migrator.addColumn(
      transactions,
      transactions.transferPayloadFingerprint,
    );
  }

  Future<void> _addMissingIncomeSourceTypeColumn(Migrator migrator) async {
    final tableInfo = await customSelect(
      'PRAGMA table_info(transactions)',
    ).get();
    final columnNames = tableInfo
        .map((row) => row.read<String>('name'))
        .toSet();
    if (!columnNames.contains('income_source_type')) {
      await migrator.addColumn(transactions, transactions.incomeSourceType);
    }
  }

  Future<void> _createReceiptTablesIfMissing(Migrator migrator) async {
    final existing = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get()).map((row) => row.read<String>('name')).toSet();
    if (!existing.contains('receipts')) {
      await migrator.createTable(receipts);
    }
    if (!existing.contains('receipt_line_items')) {
      await migrator.createTable(receiptLineItems);
    }
    if (!existing.contains('transaction_splits')) {
      await migrator.createTable(transactionSplits);
    }
  }

  Future<void> _createReceiptIndexes() async {
    final columns = await customSelect('PRAGMA table_info(receipts)').get();
    if (columns.isEmpty) {
      return;
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS receipts_purchase_date_idx
      ON receipts (purchase_date)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS receipts_merchant_payee_id_idx
      ON receipts (merchant_payee_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS receipts_linked_transaction_id_idx
      ON receipts (linked_transaction_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS receipts_receipt_number_idx
      ON receipts (receipt_number)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS receipts_invoice_number_idx
      ON receipts (invoice_number)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS receipts_image_hash_idx
      ON receipts (image_hash)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS receipt_line_items_receipt_id_idx
      ON receipt_line_items (receipt_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS transaction_splits_receipt_id_idx
      ON transaction_splits (receipt_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS transaction_splits_transaction_id_idx
      ON transaction_splits (transaction_id)
    ''');
  }

  Future<void> _createPayeeIndexes() async {
    final payeeColumns = await customSelect('PRAGMA table_info(payees)').get();
    if (payeeColumns.any(
      (row) => row.read<String>('name') == 'normalized_name',
    )) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS payees_normalized_name_idx
        ON payees (normalized_name)
      ''');
    }

    final transactionColumns = await customSelect(
      'PRAGMA table_info(transactions)',
    ).get();
    if (transactionColumns.any(
      (row) => row.read<String>('name') == 'payee_id',
    )) {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS transactions_payee_id_idx
        ON transactions (payee_id)
      ''');
    }
  }

  Future<void> _createExchangeRateIndexes() async {
    final columns = await customSelect(
      'PRAGMA table_info(exchange_rates)',
    ).get();
    if (columns.isEmpty) {
      return;
    }
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS exchange_rates_active_pair_idx
      ON exchange_rates (base_currency, quote_currency)
      WHERE archived_at IS NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS exchange_rates_fetched_at_idx
      ON exchange_rates (fetched_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS exchange_rates_archived_at_idx
      ON exchange_rates (archived_at)
    ''');
  }

  Future<void> _createBudgetIndexes() async {
    final columns = await customSelect('PRAGMA table_info(budgets)').get();
    if (columns.isEmpty) {
      return;
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS budgets_category_id_idx
      ON budgets (category_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS budgets_period_type_idx
      ON budgets (period_type)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS budgets_archived_at_idx
      ON budgets (archived_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS budgets_is_active_idx
      ON budgets (is_active)
    ''');
  }

  Future<void> _createGoalIndexes() async {
    final goalColumns = await customSelect('PRAGMA table_info(goals)').get();
    if (goalColumns.isEmpty) {
      return;
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS goals_status_idx
      ON goals (status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS goals_linked_account_id_idx
      ON goals (linked_account_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS goals_archived_at_idx
      ON goals (archived_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS goal_contributions_goal_id_idx
      ON goal_contributions (goal_id)
    ''');
  }

  Future<void> _createSyncQueueIndexes() async {
    final columns = await customSelect('PRAGMA table_info(sync_queue)').get();
    if (columns.isEmpty) {
      return;
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS sync_queue_owner_status_idx
      ON sync_queue (owner_user_id, status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS sync_queue_entity_idx
      ON sync_queue (owner_user_id, entity_type, entity_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS sync_queue_created_at_idx
      ON sync_queue (created_at)
    ''');
  }

  Future<void> _upgradeToOwnerScopedV15(Migrator migrator) async {
    final baseTables = <(String, TableInfo<Table, Object?>)>[
      ('accounts', accounts),
      ('categories', categories),
      ('payees', payees),
      ('transactions', transactions),
      ('exchange_rates', exchangeRates),
      ('budgets', budgets),
      ('goals', goals),
      ('goal_contributions', goalContributions),
      ('receipts', receipts),
      ('receipt_line_items', receiptLineItems),
      ('transaction_splits', transactionSplits),
      ('sync_queue', syncQueue),
    ];
    final existingBaseTables = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get()).map((row) => row.read<String>('name')).toSet();
    for (final entry in baseTables) {
      if (!existingBaseTables.contains(entry.$1)) {
        await migrator.createTable(entry.$2);
      }
    }

    await _addColumnIfMissing(
      'accounts',
      accounts,
      accounts.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing(
      'categories',
      categories,
      categories.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing('payees', payees, payees.ownerScopeId, migrator);
    await _addColumnIfMissing(
      'transactions',
      transactions,
      transactions.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing(
      'exchange_rates',
      exchangeRates,
      exchangeRates.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing(
      'budgets',
      budgets,
      budgets.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing('goals', goals, goals.ownerScopeId, migrator);
    await _addColumnIfMissing(
      'goal_contributions',
      goalContributions,
      goalContributions.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing(
      'receipts',
      receipts,
      receipts.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing(
      'receipt_line_items',
      receiptLineItems,
      receiptLineItems.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing(
      'transaction_splits',
      transactionSplits,
      transactionSplits.ownerScopeId,
      migrator,
    );
    await _addColumnIfMissing(
      'sync_queue',
      syncQueue,
      syncQueue.ownerScopeId,
      migrator,
    );

    final existing = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get()).map((row) => row.read<String>('name')).toSet();
    final newTables = <(String, TableInfo<Table, Object?>)>[
      ('owner_scope_migration_audits', ownerScopeMigrationAudits),
      ('ai_agent_commands', aiAgentCommands),
      ('ai_agent_previews', aiAgentPreviews),
      ('ai_agent_confirmation_proofs', aiAgentConfirmationProofs),
      ('ai_agent_execution_attempts', aiAgentExecutionAttempts),
      ('ai_agent_execution_results', aiAgentExecutionResults),
      ('ai_agent_plans', aiAgentPlans),
      ('ai_agent_plan_steps', aiAgentPlanSteps),
      ('ai_agent_audit_events', aiAgentAuditEvents),
      ('ai_agent_idempotency_records', aiAgentIdempotencyRecords),
    ];
    for (final entry in newTables) {
      if (!existing.contains(entry.$1)) {
        await migrator.createTable(entry.$2);
      }
    }
  }

  Future<void> _upgradeToReconciliationV16(Migrator migrator) async {
    final existing = (await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get()).map((row) => row.read<String>('name')).toSet();
    if (!existing.contains('ai_agent_business_operations')) {
      await migrator.createTable(aiAgentBusinessOperations);
    }
  }

  Future<void> _addColumnIfMissing(
    String tableName,
    TableInfo table,
    GeneratedColumn<Object> column,
    Migrator migrator,
  ) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    if (columns.any((row) => row.read<String>('name') == 'owner_scope_id')) {
      return;
    }
    await migrator.addColumn(table, column);
  }

  Future<void> _createOwnerScopeIndexes() async {
    const statements = <String>[
      'CREATE INDEX IF NOT EXISTS accounts_owner_scope_active_idx '
          'ON accounts (owner_scope_id, is_archived, created_at)',
      'CREATE INDEX IF NOT EXISTS categories_owner_scope_type_idx '
          'ON categories (owner_scope_id, type, is_archived, sort_order)',
      'CREATE INDEX IF NOT EXISTS payees_owner_scope_name_idx '
          'ON payees (owner_scope_id, normalized_name, archived_at)',
      'CREATE INDEX IF NOT EXISTS transactions_owner_scope_date_idx '
          'ON transactions (owner_scope_id, transaction_date, created_at)',
      'CREATE INDEX IF NOT EXISTS transactions_owner_scope_account_idx '
          'ON transactions (owner_scope_id, account_id, transaction_date)',
      'CREATE INDEX IF NOT EXISTS transactions_owner_scope_category_idx '
          'ON transactions (owner_scope_id, category_id, transaction_date)',
      'CREATE INDEX IF NOT EXISTS transactions_owner_scope_transfer_idx '
          'ON transactions (owner_scope_id, transfer_group_id)',
      'CREATE INDEX IF NOT EXISTS exchange_rates_owner_scope_pair_idx '
          'ON exchange_rates (owner_scope_id, base_currency, quote_currency)',
      'CREATE INDEX IF NOT EXISTS budgets_owner_scope_active_idx '
          'ON budgets (owner_scope_id, archived_at, is_active)',
      'CREATE INDEX IF NOT EXISTS goals_owner_scope_status_idx '
          'ON goals (owner_scope_id, status, archived_at)',
      'CREATE INDEX IF NOT EXISTS goal_contributions_owner_scope_goal_idx '
          'ON goal_contributions (owner_scope_id, goal_id, date)',
      'CREATE INDEX IF NOT EXISTS receipts_owner_scope_date_idx '
          'ON receipts (owner_scope_id, purchase_date)',
      'CREATE INDEX IF NOT EXISTS receipt_items_owner_scope_parent_idx '
          'ON receipt_line_items (owner_scope_id, receipt_id, sort_order)',
      'CREATE INDEX IF NOT EXISTS transaction_splits_owner_scope_parent_idx '
          'ON transaction_splits (owner_scope_id, receipt_id)',
      'CREATE INDEX IF NOT EXISTS sync_queue_scope_status_idx '
          'ON sync_queue (owner_scope_id, status, created_at)',
      'CREATE INDEX IF NOT EXISTS agent_commands_scope_status_idx '
          'ON ai_agent_commands (owner_scope_id, status, updated_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS agent_previews_scope_command_revision_idx '
          'ON ai_agent_previews (owner_scope_id, command_id, revision)',
      'CREATE INDEX IF NOT EXISTS agent_proofs_scope_command_idx '
          'ON ai_agent_confirmation_proofs '
          '(owner_scope_id, command_id, status, expires_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS agent_attempts_scope_idempotency_idx '
          'ON ai_agent_execution_attempts (owner_scope_id, idempotency_key)',
      'CREATE UNIQUE INDEX IF NOT EXISTS agent_results_scope_attempt_idx '
          'ON ai_agent_execution_results (owner_scope_id, attempt_id)',
      'CREATE INDEX IF NOT EXISTS agent_plans_scope_status_idx '
          'ON ai_agent_plans (owner_scope_id, status, updated_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS agent_plan_steps_scope_position_idx '
          'ON ai_agent_plan_steps (owner_scope_id, plan_id, position)',
      'CREATE INDEX IF NOT EXISTS agent_audits_scope_created_idx '
          'ON ai_agent_audit_events (owner_scope_id, created_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS agent_idempotency_scope_hash_idx '
          'ON ai_agent_idempotency_records (owner_scope_id, idempotency_hash)',
      'CREATE UNIQUE INDEX IF NOT EXISTS agent_business_ops_scope_command_idx '
          'ON ai_agent_business_operations '
          '(owner_scope_id, command_id, command_revision, action_type)',
      'CREATE INDEX IF NOT EXISTS agent_business_ops_scope_status_idx '
          'ON ai_agent_business_operations (owner_scope_id, status, updated_at)',
    ];
    await customStatement(
      'DROP INDEX IF EXISTS exchange_rates_active_pair_idx',
    );
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS exchange_rates_active_pair_idx
      ON exchange_rates (owner_scope_id, base_currency, quote_currency)
      WHERE archived_at IS NULL AND owner_scope_id IS NOT NULL
    ''');
    final transactionColumns = (await customSelect(
      'PRAGMA table_info(transactions)',
    ).get()).map((row) => row.read<String>('name')).toSet();
    for (final statement in statements) {
      if (statement.contains('transactions_owner_scope_date_idx') &&
          !transactionColumns.containsAll(<String>{
            'owner_scope_id',
            'transaction_date',
            'created_at',
          })) {
        continue;
      }
      if (statement.contains('transactions_owner_scope_account_idx') &&
          !transactionColumns.containsAll(<String>{
            'owner_scope_id',
            'account_id',
            'transaction_date',
          })) {
        continue;
      }
      if (statement.contains('transactions_owner_scope_category_idx') &&
          !transactionColumns.containsAll(<String>{
            'owner_scope_id',
            'category_id',
            'transaction_date',
          })) {
        continue;
      }
      await customStatement(statement);
    }
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'cashpilot_ai',
    native: const DriftNativeOptions(shareAcrossIsolates: true),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
