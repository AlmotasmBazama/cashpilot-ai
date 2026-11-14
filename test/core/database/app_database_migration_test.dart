import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh database creates the complete v17 schema and indexes', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    await _expectCurrentSchemaAndIndexes(database);
    expect(await _userVersion(database), 17);
  });

  for (final version in const [8, 9, 10, 11, 12, 13, 14, 15, 16]) {
    test('v$version snapshot migrates to v17 without data loss', () async {
      final snapshot = await _openHistoricalSnapshot(version);
      addTearDown(() async {
        await snapshot.database.close();
        await snapshot.directory.delete(recursive: true);
      });

      await _expectCurrentSchemaAndIndexes(snapshot.database);
      expect(await _userVersion(snapshot.database), 17);
      await _expectCoreDataPreserved(snapshot.database);
      await _expectLegacyRowsRemainUnclaimed(snapshot.database);
      if (version >= 12) {
        final queueRow = await (snapshot.database.select(
          snapshot.database.syncQueue,
        )..where((row) => row.id.equals('queue-1'))).getSingle();
        final expectedScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'user-1',
        ).id.value;
        expect(queueRow.ownerScopeId, expectedScope);
        expect(queueRow.ownerUserId, expectedScope);
        expect(queueRow.ownerUserId, isNot('user-1'));
        expect(queueRow.payloadJson, '{}');
      }
      if (version >= 9) {
        final rate = await (snapshot.database.select(
          snapshot.database.exchangeRates,
        )..where((row) => row.id.equals('rate-1'))).getSingle();
        expect(rate.rate, '4.8');
      }
      if (version >= 10) {
        final budget = await (snapshot.database.select(
          snapshot.database.budgets,
        )..where((row) => row.id.equals('budget-1'))).getSingle();
        expect(budget.amount, '100');
      }
      if (version >= 11) {
        final goal = await (snapshot.database.select(
          snapshot.database.goals,
        )..where((row) => row.id.equals('goal-1'))).getSingle();
        final contribution = await (snapshot.database.select(
          snapshot.database.goalContributions,
        )..where((row) => row.id.equals('contribution-1'))).getSingle();
        expect(goal.currentAmount, '100');
        expect(contribution.creditedAmount, '10');
      }
    });
  }

  test(
    'ownerless v14 device snapshot upgrades without silently claiming data',
    () async {
      final snapshot = await _openHistoricalSnapshot(
        14,
        stripOwnerScopeColumns: true,
      );
      addTearDown(() async {
        await snapshot.database.close();
        await snapshot.directory.delete(recursive: true);
      });

      await _expectCurrentSchemaAndIndexes(snapshot.database);
      expect(await _userVersion(snapshot.database), 17);
      await _expectCoreDataPreserved(snapshot.database);
      await _expectLegacyRowsRemainUnclaimed(snapshot.database);

      for (final table in _legacyFinancialTables) {
        final columns = await snapshot.database
            .customSelect('PRAGMA table_info($table)')
            .map((row) => row.read<String>('name'))
            .get();
        expect(columns, contains('owner_scope_id'), reason: table);
      }
    },
  );

  test(
    'migration adds transfer, rates, budgets, goals, and sync queue schema',
    () async {
      final database = AppDatabase(
        executor: NativeDatabase.memory(
          setup: (database) {
            database
              ..execute('''
              CREATE TABLE transactions (
                id TEXT NOT NULL PRIMARY KEY,
                transfer_group_id TEXT NULL
              )
            ''')
              ..execute(
                "INSERT INTO transactions (id) VALUES ('legacy-transfer')",
              )
              ..execute('PRAGMA user_version = 7');
          },
        ),
      );
      addTearDown(database.close);

      final columns = await database
          .customSelect('PRAGMA table_info(transactions)')
          .map((row) => row.read<String>('name'))
          .get();
      final indexes = await database
          .customSelect('PRAGMA index_list(transactions)')
          .map((row) => row.read<String>('name'))
          .get();
      final legacyRows = await database
          .customSelect(
            "SELECT id, transfer_group_id FROM transactions WHERE id = 'legacy-transfer'",
          )
          .get();
      final exchangeRateColumns = await database
          .customSelect('PRAGMA table_info(exchange_rates)')
          .map((row) => row.read<String>('name'))
          .get();
      final exchangeRateIndexes = await database
          .customSelect('PRAGMA index_list(exchange_rates)')
          .map((row) => row.read<String>('name'))
          .get();
      final budgetColumns = await database
          .customSelect('PRAGMA table_info(budgets)')
          .map((row) => row.read<String>('name'))
          .get();
      final budgetIndexes = await database
          .customSelect('PRAGMA index_list(budgets)')
          .map((row) => row.read<String>('name'))
          .get();
      final goalColumns = await database
          .customSelect('PRAGMA table_info(goals)')
          .map((row) => row.read<String>('name'))
          .get();
      final goalIndexes = await database
          .customSelect('PRAGMA index_list(goals)')
          .map((row) => row.read<String>('name'))
          .get();
      final contributionColumns = await database
          .customSelect('PRAGMA table_info(goal_contributions)')
          .map((row) => row.read<String>('name'))
          .get();
      final contributionIndexes = await database
          .customSelect('PRAGMA index_list(goal_contributions)')
          .map((row) => row.read<String>('name'))
          .get();
      final syncQueueColumns = await database
          .customSelect('PRAGMA table_info(sync_queue)')
          .map((row) => row.read<String>('name'))
          .get();
      final syncQueueIndexes = await database
          .customSelect('PRAGMA index_list(sync_queue)')
          .map((row) => row.read<String>('name'))
          .get();

      expect(
        columns,
        containsAll(<String>[
          'transfer_group_id',
          'exchange_rate_from_currency_code',
          'exchange_rate_to_currency_code',
          'exchange_rate',
          'exchange_rate_as_of',
          'income_source_type',
        ]),
      );
      expect(indexes, contains('transactions_transfer_group_id_idx'));
      expect(legacyRows, hasLength(1));
      expect(
        legacyRows.single.readNullable<String>('transfer_group_id'),
        isNull,
      );
      expect(
        exchangeRateColumns,
        containsAll(<String>[
          'base_currency',
          'quote_currency',
          'rate',
          'fetched_at',
          'archived_at',
        ]),
      );
      expect(
        exchangeRateIndexes,
        containsAll(<String>[
          'exchange_rates_active_pair_idx',
          'exchange_rates_fetched_at_idx',
          'exchange_rates_archived_at_idx',
        ]),
      );
      expect(
        budgetColumns,
        containsAll(<String>[
          'category_id',
          'amount',
          'period_type',
          'alert_threshold_percent',
          'archived_at',
        ]),
      );
      expect(
        budgetIndexes,
        containsAll(<String>[
          'budgets_category_id_idx',
          'budgets_period_type_idx',
          'budgets_archived_at_idx',
          'budgets_is_active_idx',
        ]),
      );
      expect(
        goalColumns,
        containsAll(<String>[
          'target_amount',
          'current_amount',
          'linked_account_id',
          'target_date',
          'status',
          'archived_at',
          'completed_at',
        ]),
      );
      expect(
        goalIndexes,
        containsAll(<String>[
          'goals_status_idx',
          'goals_linked_account_id_idx',
          'goals_archived_at_idx',
        ]),
      );
      expect(
        contributionColumns,
        containsAll(<String>[
          'goal_id',
          'amount',
          'currency',
          'credited_amount',
          'linked_transaction_id',
          'reversed_at',
        ]),
      );
      expect(contributionIndexes, contains('goal_contributions_goal_id_idx'));
      expect(
        syncQueueColumns,
        containsAll(<String>[
          'id',
          'owner_user_id',
          'entity_type',
          'entity_id',
          'operation',
          'payload_json',
          'status',
          'attempt_count',
          'last_error',
          'created_at',
          'updated_at',
          'last_attempt_at',
        ]),
      );
      expect(
        syncQueueIndexes,
        containsAll(<String>[
          'sync_queue_owner_status_idx',
          'sync_queue_entity_idx',
          'sync_queue_created_at_idx',
        ]),
      );
    },
  );

  test(
    'v6 migration preserves transactions and promotes legacy payee ids',
    () async {
      final database = AppDatabase(
        executor: NativeDatabase.memory(
          setup: (database) {
            database
              ..execute('''
                CREATE TABLE payees (
                  id TEXT NOT NULL PRIMARY KEY,
                  name TEXT NOT NULL,
                  normalized_name TEXT NOT NULL,
                  created_at INTEGER NOT NULL,
                  updated_at INTEGER NOT NULL
                )
              ''')
              ..execute('''
                CREATE TABLE transactions (
                  id TEXT NOT NULL PRIMARY KEY,
                  account_id TEXT NOT NULL,
                  category_id TEXT NOT NULL,
                  payee_id TEXT NULL,
                  amount TEXT NOT NULL,
                  currency_code TEXT NOT NULL,
                  type TEXT NOT NULL,
                  payment_method TEXT NOT NULL,
                  source TEXT NOT NULL,
                  status TEXT NOT NULL,
                  transfer_group_id TEXT NULL,
                  note TEXT NULL,
                  transaction_date INTEGER NOT NULL,
                  location TEXT NULL,
                  attachment_count INTEGER NOT NULL DEFAULT 0,
                  ai_confidence INTEGER NULL,
                  needs_review INTEGER NOT NULL DEFAULT 0,
                  created_at INTEGER NOT NULL,
                  updated_at INTEGER NOT NULL
                )
              ''')
              ..execute('''
                INSERT INTO transactions (
                  id, account_id, category_id, payee_id, amount,
                  currency_code, type, payment_method, source, status,
                  transaction_date, created_at, updated_at
                ) VALUES (
                  'legacy-transaction', 'cash', 'food', 'Legacy Merchant',
                  '12.5', 'LYD', 'expense', 'cash', 'manual', 'posted',
                  1767225600, 1767225600, 1767225600
                )
              ''')
              ..execute('''
                INSERT INTO transactions (
                  id, account_id, category_id, payee_id, amount,
                  currency_code, type, payment_method, source, status,
                  transfer_group_id, transaction_date, created_at, updated_at
                ) VALUES (
                  'legacy-unpaired-transfer', 'cash', 'transfer', NULL,
                  '25', 'LYD', 'transferOut', 'bankTransfer', 'manual',
                  'posted', NULL, 1767225600, 1767225600, 1767225600
                )
              ''')
              ..execute('PRAGMA user_version = 6');
          },
        ),
      );
      addTearDown(database.close);

      final transaction = await (database.select(
        database.transactions,
      )..where((row) => row.id.equals('legacy-transaction'))).getSingle();
      final promotedPayee = await (database.select(
        database.payees,
      )..where((row) => row.id.equals('Legacy Merchant'))).getSingle();
      final legacyTransfer = await (database.select(
        database.transactions,
      )..where((row) => row.id.equals('legacy-unpaired-transfer'))).getSingle();
      final payeeIndexes = await database
          .customSelect('PRAGMA index_list(payees)')
          .map((row) => row.read<String>('name'))
          .get();
      final transactionIndexes = await database
          .customSelect('PRAGMA index_list(transactions)')
          .map((row) => row.read<String>('name'))
          .get();

      expect(transaction.payeeId, 'Legacy Merchant');
      expect(transaction.amount, '12.5');
      expect(legacyTransfer.type, 'transferOut');
      expect(legacyTransfer.transferGroupId, isNull);
      expect(legacyTransfer.amount, '25');
      expect(promotedPayee.name, 'Legacy Merchant');
      expect(promotedPayee.normalizedName, 'legacy merchant');
      expect(promotedPayee.type, 'other');
      expect(promotedPayee.aliases, '[]');
      expect(promotedPayee.archivedAt, isNull);
      expect(payeeIndexes, contains('payees_normalized_name_idx'));
      expect(transactionIndexes, contains('transactions_payee_id_idx'));
    },
  );
}

const _currentTables = <String>[
  'accounts',
  'categories',
  'payees',
  'transactions',
  'exchange_rates',
  'budgets',
  'goals',
  'goal_contributions',
  'sync_queue',
  'receipts',
  'receipt_line_items',
  'transaction_splits',
  'owner_scope_migration_audits',
  'ai_agent_commands',
  'ai_agent_previews',
  'ai_agent_confirmation_proofs',
  'ai_agent_execution_attempts',
  'ai_agent_execution_results',
  'ai_agent_plans',
  'ai_agent_plan_steps',
  'ai_agent_audit_events',
  'ai_agent_idempotency_records',
  'ai_agent_business_operations',
];

const _currentIndexes = <String>[
  'transactions_transfer_group_id_idx',
  'payees_normalized_name_idx',
  'transactions_payee_id_idx',
  'exchange_rates_active_pair_idx',
  'exchange_rates_fetched_at_idx',
  'exchange_rates_archived_at_idx',
  'budgets_category_id_idx',
  'budgets_period_type_idx',
  'budgets_archived_at_idx',
  'budgets_is_active_idx',
  'goals_status_idx',
  'goals_linked_account_id_idx',
  'goals_archived_at_idx',
  'goal_contributions_goal_id_idx',
  'sync_queue_owner_status_idx',
  'sync_queue_entity_idx',
  'sync_queue_created_at_idx',
  'receipts_purchase_date_idx',
  'receipts_merchant_payee_id_idx',
  'receipts_linked_transaction_id_idx',
  'receipts_receipt_number_idx',
  'receipts_invoice_number_idx',
  'receipts_image_hash_idx',
  'receipt_line_items_receipt_id_idx',
  'transaction_splits_receipt_id_idx',
  'transaction_splits_transaction_id_idx',
  'accounts_owner_scope_active_idx',
  'categories_owner_scope_type_idx',
  'payees_owner_scope_name_idx',
  'transactions_owner_scope_date_idx',
  'budgets_owner_scope_active_idx',
  'goals_owner_scope_status_idx',
  'receipts_owner_scope_date_idx',
  'sync_queue_scope_status_idx',
  'agent_commands_scope_status_idx',
  'agent_idempotency_scope_hash_idx',
  'agent_business_ops_scope_command_idx',
  'agent_business_ops_scope_status_idx',
];

Future<void> _expectCurrentSchemaAndIndexes(AppDatabase database) async {
  final tables = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .map((row) => row.read<String>('name'))
      .get();
  final indexes = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .map((row) => row.read<String>('name'))
      .get();

  expect(tables, containsAll(_currentTables));
  expect(indexes, containsAll(_currentIndexes));
}

Future<int> _userVersion(AppDatabase database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<({AppDatabase database, Directory directory})> _openHistoricalSnapshot(
  int version, {
  bool stripOwnerScopeColumns = false,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'cashpilot-v$version-migration-',
  );
  final file = File(
    '${directory.path}${Platform.pathSeparator}cashpilot.sqlite',
  );
  final current = AppDatabase(executor: NativeDatabase(file));
  await _seedCurrentData(current);
  await current.close();

  final futureTables = switch (version) {
    8 => const [
      'exchange_rates',
      'budgets',
      'goals',
      'goal_contributions',
      'sync_queue',
      'receipts',
      'receipt_line_items',
      'transaction_splits',
      ..._v15OnlyTables,
    ],
    9 => const [
      'budgets',
      'goals',
      'goal_contributions',
      'sync_queue',
      'receipts',
      'receipt_line_items',
      'transaction_splits',
      ..._v15OnlyTables,
    ],
    10 => const [
      'goals',
      'goal_contributions',
      'sync_queue',
      'receipts',
      'receipt_line_items',
      'transaction_splits',
      ..._v15OnlyTables,
    ],
    11 => const [
      'sync_queue',
      'receipts',
      'receipt_line_items',
      'transaction_splits',
      ..._v15OnlyTables,
    ],
    12 || 13 => const [
      'receipts',
      'receipt_line_items',
      'transaction_splits',
      ..._v15OnlyTables,
    ],
    14 => const [..._v15OnlyTables, ..._v16OnlyTables],
    15 => _v16OnlyTables,
    16 => const [],
    _ => throw ArgumentError.value(version, 'version'),
  };
  final database = AppDatabase(
    executor: NativeDatabase(
      file,
      setup: (rawDatabase) {
        for (final table in futureTables) {
          rawDatabase.execute('DROP TABLE $table');
        }
        if (stripOwnerScopeColumns) {
          final indexes = rawDatabase.select('''
            SELECT name FROM sqlite_master
            WHERE type = 'index' AND sql LIKE '%owner_scope_id%'
          ''');
          for (final row in indexes) {
            rawDatabase.execute('DROP INDEX "${row['name']}"');
          }
          for (final table in _legacyFinancialTables) {
            rawDatabase.execute(
              'ALTER TABLE $table DROP COLUMN owner_scope_id',
            );
          }
        }
        rawDatabase.execute(
          'ALTER TABLE transactions DROP COLUMN transfer_payload_fingerprint',
        );
        rawDatabase.execute('PRAGMA user_version = $version');
      },
    ),
  );
  return (database: database, directory: directory);
}

const _v15OnlyTables = <String>[
  'owner_scope_migration_audits',
  'ai_agent_commands',
  'ai_agent_previews',
  'ai_agent_confirmation_proofs',
  'ai_agent_execution_attempts',
  'ai_agent_execution_results',
  'ai_agent_plans',
  'ai_agent_plan_steps',
  'ai_agent_audit_events',
  'ai_agent_idempotency_records',
];

const _v16OnlyTables = <String>['ai_agent_business_operations'];

const _legacyFinancialTables = <String>[
  'accounts',
  'categories',
  'payees',
  'transactions',
  'exchange_rates',
  'budgets',
  'goals',
  'goal_contributions',
  'receipts',
  'receipt_line_items',
  'transaction_splits',
  'sync_queue',
];

Future<void> _expectCoreDataPreserved(AppDatabase database) async {
  final account = await (database.select(
    database.accounts,
  )..where((row) => row.id.equals('account-1'))).getSingle();
  final category = await (database.select(
    database.categories,
  )..where((row) => row.id.equals('category-1'))).getSingle();
  final payee = await (database.select(
    database.payees,
  )..where((row) => row.id.equals('payee-1'))).getSingle();
  final transaction = await (database.select(
    database.transactions,
  )..where((row) => row.id.equals('transaction-1'))).getSingle();

  expect(account.balance, '10');
  expect(category.name, 'Food');
  expect(payee.normalizedName, 'shop');
  expect(transaction.amount, '1');
  expect(transaction.transferGroupId, isNull);
  expect(transaction.transferPayloadFingerprint, isNull);
}

Future<void> _expectLegacyRowsRemainUnclaimed(AppDatabase database) async {
  final rows = await database.customSelect('''
    SELECT
      (SELECT COUNT(*) FROM accounts WHERE owner_scope_id IS NULL) +
      (SELECT COUNT(*) FROM categories WHERE owner_scope_id IS NULL) +
      (SELECT COUNT(*) FROM payees WHERE owner_scope_id IS NULL) +
      (SELECT COUNT(*) FROM transactions WHERE owner_scope_id IS NULL)
      AS value
  ''').getSingle();
  expect(rows.read<int>('value'), 4);
  final auditCount = await database
      .customSelect(
        'SELECT COUNT(*) AS value FROM owner_scope_migration_audits',
      )
      .map((row) => row.read<int>('value'))
      .getSingle();
  expect(auditCount, 0);
}

Future<void> _seedCurrentData(AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO accounts (
      id, name, type, currency_code, balance, icon, color, created_at, updated_at
    ) VALUES ('account-1', 'Cash', 'cash', 'USD', '10', 'wallet', 1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO categories (
      id, name, type, icon, color, sort_order, created_at, updated_at
    ) VALUES ('category-1', 'Food', 'expense', 'food', 1, 0, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO payees (
      id, name, normalized_name, created_at, updated_at
    ) VALUES ('payee-1', 'Shop', 'shop', 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO transactions (
      id, account_id, category_id, payee_id, amount, currency_code, type,
      payment_method, source, status, transaction_date, created_at, updated_at
    ) VALUES (
      'transaction-1', 'account-1', 'category-1', 'payee-1', '1', 'USD',
      'expense', 'cash', 'manual', 'posted', 1, 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO exchange_rates (
      id, base_currency, quote_currency, rate, source, fetched_at,
      created_at, updated_at
    ) VALUES ('rate-1', 'USD', 'LYD', '4.8', 'manual', 1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO budgets (
      id, name, category_id, amount, currency, period_type, start_date,
      end_date, alert_threshold_percent, created_at, updated_at
    ) VALUES (
      'budget-1', 'Food', 'category-1', '100', 'USD', 'monthly', 1, 2, 80, 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO goals (
      id, title, type, target_amount, current_amount, currency, icon, color,
      status, created_at, updated_at
    ) VALUES (
      'goal-1', 'Emergency fund', 'savings', '1000', '100', 'USD', 'target',
      1, 'active', 1, 1
    )
  ''');
  await database.customStatement('''
    INSERT INTO goal_contributions (
      id, goal_id, amount, currency, credited_amount, date, created_at,
      updated_at
    ) VALUES ('contribution-1', 'goal-1', '10', 'USD', '10', 1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO sync_queue (
      id, owner_user_id, entity_type, entity_id, operation, payload_json,
      created_at, updated_at
    ) VALUES (
      'queue-1', 'user-1', 'account', 'account-1', 'upsert',
      '{"balance":"private-v14-value"}', 1, 1
    )
  ''');
}
