import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/legacy_data_claim_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_health_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/accounts/data/datasources/local/accounts_local_data_source.dart';
import 'package:cashpilot_ai/features/budgets/data/datasources/local/budgets_local_data_source.dart';
import 'package:cashpilot_ai/features/categories/data/datasources/local/categories_local_data_source.dart';
import 'package:cashpilot_ai/features/goals/data/datasources/local/goals_local_data_source.dart';
import 'package:cashpilot_ai/features/payees/data/datasources/local/payees_local_data_source.dart';
import 'package:cashpilot_ai/features/receipts/data/repositories/receipt_repository_impl.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:cashpilot_ai/features/receipts/domain/entities/receipt_analysis_draft.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  group('owner-scoped Drift boundary', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      await database.customSelect('SELECT 1').get();
    });

    tearDown(() => database.close());

    test(
      'two scopes cannot read, fetch, update, delete, or reference',
      () async {
        final scopeA = scopedTestSession(
          database,
          syntheticFirebaseUid: 'synthetic-account-a',
        );
        final scopeB = scopedTestSession(
          database,
          syntheticFirebaseUid: 'synthetic-account-b',
        );
        await _seedScope(database, scopeA.ownerScopeValue, 'a');
        await _seedScope(database, scopeB.ownerScopeValue, 'b');

        final accountsA = DriftAccountsLocalDataSource(scopeA);
        final accountsB = DriftAccountsLocalDataSource(scopeB);
        expect((await accountsA.getAccounts()).map((row) => row.id), [
          'account-a',
        ]);
        expect(await accountsA.getAccountById('account-b'), isNull);
        final accountB = await accountsB.getAccountById('account-b');
        expect(accountB, isNotNull);
        await expectLater(
          accountsA.updateAccount(accountB!),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          accountsA.deleteAccount('account-b'),
          throwsA(isA<Exception>()),
        );

        final categoriesA = DriftCategoriesLocalDataSource(scopeA);
        expect(await categoriesA.getCategoryById('category-b'), isNull);
        expect(
          await categoriesA.getCategoryById(
            '01900000-0000-7000-8000-000000000001',
          ),
          isNotNull,
        );
        expect(
          await DriftPayeesLocalDataSource(scopeA).getPayeeById('payee-b'),
          isNull,
        );
        expect(
          await DriftTransactionsLocalDataSource(scopeA).getTransaction('tx-b'),
          isNull,
        );
        expect(
          await DriftBudgetsLocalDataSource(scopeA).getBudgetById('budget-b'),
          isNull,
        );
        expect(
          await DriftGoalsLocalDataSource(scopeA).getGoalById('goal-b'),
          isNull,
        );
        final receiptA = ReceiptRepositoryImpl(
          session: scopeA,
          imageStore: ReceiptLocalImageStore(
            ownerScopeValue: scopeA.ownerScopeValue,
          ),
        );
        final foreignReceipt = await receiptA.getDraftById('receipt-b');
        expect(foreignReceipt, isA<AppSuccess<ReceiptAnalysisDraft?>>());
        expect(
          (foreignReceipt as AppSuccess<ReceiptAnalysisDraft?>).data,
          isNull,
        );

        await expectLater(
          database.customStatement(
            _transactionSql(
              id: 'forged-account-ref',
              owner: scopeA.ownerScopeValue,
              accountId: 'account-b',
              categoryId: '01900000-0000-7000-8000-000000000001',
            ),
          ),
          throwsA(anything),
        );
        await expectLater(
          database.customStatement('''
          INSERT INTO transaction_splits (
            id, owner_scope_id, receipt_id, category_id, amount
          ) VALUES (
            'forged-receipt-ref', '${scopeA.ownerScopeValue}',
            'receipt-b', '01900000-0000-7000-8000-000000000001', '1'
          )
        '''),
          throwsA(anything),
        );
        await expectLater(
          database.customStatement(
            "UPDATE accounts SET owner_scope_id = '${scopeA.ownerScopeValue}' "
            "WHERE id = 'account-b'",
          ),
          throwsA(anything),
        );
      },
    );

    test(
      'logout invalidates stale A while B and a new A keep isolated rows',
      () async {
        final oldA = scopedTestSession(
          database,
          syntheticFirebaseUid: 'synthetic-account-a',
        );
        final scopeB = scopedTestSession(
          database,
          syntheticFirebaseUid: 'synthetic-account-b',
        );
        await _seedScope(database, oldA.ownerScopeValue, 'a');
        await _seedScope(database, scopeB.ownerScopeValue, 'b');
        final staleAData = DriftAccountsLocalDataSource(oldA);
        expect((await staleAData.getAccounts()).single.id, 'account-a');

        oldA.invalidate();
        await expectLater(
          staleAData.getAccounts(),
          throwsA(isA<OwnerScopeException>()),
        );
        expect(
          (await DriftAccountsLocalDataSource(scopeB).getAccounts()).single.id,
          'account-b',
        );

        final newA = scopedTestSession(
          database,
          syntheticFirebaseUid: 'synthetic-account-a',
        );
        expect(
          (await DriftAccountsLocalDataSource(newA).getAccounts()).single.id,
          'account-a',
        );
      },
    );

    test(
      'legacy rows remain unclaimed, invisible, and claim atomically',
      () async {
        final legacyDatabase = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(legacyDatabase.close);
        await legacyDatabase.customStatement('''
        INSERT INTO accounts (
          id, name, type, currency_code, balance, icon, color,
          created_at, updated_at
        ) VALUES ('legacy-account', 'Legacy', 'cash', 'USD', '10',
          'wallet', 1, 1, 1)
      ''');
        await legacyDatabase.customStatement('''
        INSERT INTO categories (
          id, name, type, icon, color, sort_order, created_at, updated_at
        ) VALUES ('legacy-category', 'Legacy', 'expense', 'food', 1, 0, 1, 1)
      ''');
        await legacyDatabase.customStatement(
          _transactionSql(
            id: 'legacy-tx',
            owner: null,
            accountId: 'legacy-account',
            categoryId: 'legacy-category',
          ),
        );
        final session = scopedTestSession(
          legacyDatabase,
          syntheticFirebaseUid: 'synthetic-claim-owner',
        );
        expect(
          await DriftAccountsLocalDataSource(session).getAccounts(),
          isEmpty,
        );
        final service = LegacyDataClaimService(
          session: session,
          currentConfirmedScope: () => session.confirmedScope,
        );
        expect((await service.inspectBoundedCounts()).total, 3);
        final result = await service.claim(protectedConfirmationAccepted: true);
        expect(result.claimedCount, 3);
        expect(
          (await DriftAccountsLocalDataSource(session).getAccounts()).single.id,
          'legacy-account',
        );
        final ownerRows = await legacyDatabase
            .customSelect(
              '''
        SELECT COUNT(*) AS value FROM (
          SELECT owner_scope_id FROM accounts
          UNION ALL SELECT owner_scope_id FROM categories
          UNION ALL SELECT owner_scope_id FROM transactions
        ) WHERE owner_scope_id = ?
      ''',
              variables: [Variable<String>(session.ownerScopeValue)],
            )
            .getSingle();
        expect(ownerRows.read<int>('value'), 3);

        final other = scopedTestSession(
          legacyDatabase,
          syntheticFirebaseUid: 'synthetic-other-owner',
        );
        await expectLater(
          LegacyDataClaimService(
            session: other,
            currentConfirmedScope: () => other.confirmedScope,
          ).claim(protectedConfirmationAccepted: true),
          throwsA(
            isA<OwnerScopeException>().having(
              (error) => error.failure,
              'failure',
              OwnerScopeFailure.legacyDataAlreadyClaimed,
            ),
          ),
        );
      },
    );

    test('legacy claim requires explicit protected confirmation', () async {
      final legacyDatabase = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(legacyDatabase.close);
      await legacyDatabase.customStatement('''
        INSERT INTO accounts (
          id, name, type, currency_code, balance, icon, color,
          created_at, updated_at
        ) VALUES ('unconfirmed-legacy', 'Legacy', 'cash', 'USD', '10',
          'wallet', 1, 1, 1)
      ''');
      final session = scopedTestSession(
        legacyDatabase,
        syntheticFirebaseUid: 'synthetic-unconfirmed-owner',
      );
      final service = LegacyDataClaimService(
        session: session,
        currentConfirmedScope: () => session.confirmedScope,
      );

      await expectLater(
        service.claim(protectedConfirmationAccepted: false),
        throwsA(
          isA<OwnerScopeException>().having(
            (error) => error.failure,
            'failure',
            OwnerScopeFailure.authNotConfirmed,
          ),
        ),
      );

      final row = await legacyDatabase.customSelect('''
        SELECT owner_scope_id FROM accounts WHERE id = 'unconfirmed-legacy'
      ''').getSingle();
      expect(row.readNullable<String>('owner_scope_id'), isNull);
      expect((await service.inspectBoundedCounts()).total, 1);
      expect(
        await legacyDatabase
            .customSelect(
              'SELECT COUNT(*) AS value FROM owner_scope_migration_audits',
            )
            .map((row) => row.read<int>('value'))
            .getSingle(),
        0,
      );
    });

    test(
      'legacy claim rolls back every row when its audit cannot commit',
      () async {
        final legacyDatabase = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(legacyDatabase.close);
        await legacyDatabase.customStatement('''
        INSERT INTO accounts (
          id, name, type, currency_code, balance, icon, color,
          created_at, updated_at
        ) VALUES ('rollback-legacy', 'Legacy', 'cash', 'USD', '10',
          'wallet', 1, 1, 1)
      ''');
        await legacyDatabase.customStatement('''
        CREATE TRIGGER reject_legacy_claim_audit
        BEFORE INSERT ON owner_scope_migration_audits
        BEGIN SELECT RAISE(ABORT, 'injected_audit_failure'); END
      ''');
        final session = scopedTestSession(
          legacyDatabase,
          syntheticFirebaseUid: 'synthetic-rollback-owner',
        );

        await expectLater(
          LegacyDataClaimService(
            session: session,
            currentConfirmedScope: () => session.confirmedScope,
          ).claim(protectedConfirmationAccepted: true),
          throwsA(anything),
        );

        final row = await legacyDatabase.customSelect('''
        SELECT owner_scope_id FROM accounts WHERE id = 'rollback-legacy'
      ''').getSingle();
        expect(row.readNullable<String>('owner_scope_id'), isNull);
        expect(
          await legacyDatabase
              .customSelect(
                'SELECT COUNT(*) AS value FROM owner_scope_migration_audits',
              )
              .map((row) => row.read<int>('value'))
              .getSingle(),
          0,
        );
      },
    );

    test(
      'owner change after final write checkpoint rolls back legacy claim',
      () async {
        final ownerA = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'synthetic-racing-owner-a',
        );
        final ownerB = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          'synthetic-racing-owner-b',
        );
        var currentScope = ownerA;
        ScopedAppDatabaseSession? session;
        var switched = false;
        final legacyDatabase = AppDatabase(
          executor: NativeDatabase.memory(
            setup: (rawDatabase) {
              rawDatabase.createFunction(
                functionName: 'switch_legacy_claim_owner',
                directOnly: false,
                function: (_) {
                  currentScope = ownerB;
                  session?.invalidate();
                  switched = true;
                  return 0;
                },
              );
            },
          ),
        );
        addTearDown(legacyDatabase.close);
        await legacyDatabase.customStatement('''
          INSERT INTO accounts (
            id, name, type, currency_code, balance, icon, color,
            created_at, updated_at
          ) VALUES ('racing-legacy', 'Legacy', 'cash', 'USD', '10',
            'wallet', 1, 1, 1)
        ''');
        await legacyDatabase.customStatement('''
          CREATE TRIGGER switch_owner_after_claim_audit
          AFTER INSERT ON owner_scope_migration_audits
          BEGIN SELECT switch_legacy_claim_owner(); END
        ''');
        session = ScopedAppDatabaseSession(
          database: legacyDatabase,
          scope: ownerA,
          operationFence: BackupOperationFence(),
        );

        await expectLater(
          LegacyDataClaimService(
            session: session,
            currentConfirmedScope: () => currentScope,
          ).claim(protectedConfirmationAccepted: true),
          throwsA(
            isA<OwnerScopeException>().having(
              (error) => error.failure,
              'failure',
              OwnerScopeFailure.activeScopeChanged,
            ),
          ),
        );

        expect(switched, isTrue);
        final row = await legacyDatabase.customSelect('''
          SELECT owner_scope_id FROM accounts WHERE id = 'racing-legacy'
        ''').getSingle();
        expect(row.readNullable<String>('owner_scope_id'), isNull);
        expect(
          await legacyDatabase
              .customSelect(
                'SELECT COUNT(*) AS value FROM owner_scope_migration_audits',
              )
              .map((row) => row.read<int>('value'))
              .getSingle(),
          0,
        );
      },
    );

    test(
      'invalid current-owner sync upsert rolls back before claim audit',
      () async {
        const ownerUid = 'synthetic-invalid-sync-owner';
        final legacyDatabase = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(legacyDatabase.close);
        await legacyDatabase.customStatement('''
          INSERT INTO sync_queue (
            id, owner_scope_id, owner_user_id, entity_type, entity_id,
            operation, payload_json, status, attempt_count, created_at,
            updated_at
          ) VALUES (
            'legacy-missing-account-upsert', NULL, '$ownerUid', 'account',
            'missing-account', 'upsert', '{"private":"discard"}', 'pending',
            0, 1, 1
          )
        ''');
        final session = ScopedAppDatabaseSession(
          database: legacyDatabase,
          scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(ownerUid),
        );

        await expectLater(
          LegacyDataClaimService(
            session: session,
            currentConfirmedScope: () => session.confirmedScope,
          ).claim(protectedConfirmationAccepted: true),
          throwsA(
            isA<OwnerScopeException>().having(
              (error) => error.failure,
              'failure',
              OwnerScopeFailure.integrityCheckFailed,
            ),
          ),
        );

        final queue = await legacyDatabase.customSelect('''
          SELECT owner_scope_id, owner_user_id, payload_json
          FROM sync_queue WHERE id = 'legacy-missing-account-upsert'
        ''').getSingle();
        expect(queue.readNullable<String>('owner_scope_id'), isNull);
        expect(queue.read<String>('owner_user_id'), ownerUid);
        expect(queue.read<String>('payload_json'), '{"private":"discard"}');
        expect(
          await legacyDatabase
              .customSelect(
                'SELECT COUNT(*) AS value FROM owner_scope_migration_audits',
              )
              .map((row) => row.read<int>('value'))
              .getSingle(),
          0,
        );
      },
    );

    test(
      'runtime health fails closed for legacy rows and becomes safe after claim',
      () async {
        final legacyDatabase = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(legacyDatabase.close);
        await legacyDatabase.customStatement('''
        INSERT INTO accounts (
          id, name, type, currency_code, balance, icon, color,
          created_at, updated_at
        ) VALUES ('legacy', 'Legacy', 'cash', 'USD', '0', 'wallet', 1, 1, 1)
      ''');
        final session = scopedTestSession(legacyDatabase);
        const snapshotStatus = OwnerScopeStatus.safe;
        final snapshot = OwnerScopeSnapshot(
          status: snapshotStatus,
          scope: session.confirmedScope,
        );
        final healthService = OwnerScopeHealthService(legacyDatabase);
        expect(
          (await healthService.evaluate(
            snapshot: snapshot,
            session: session,
          )).status,
          OwnerScopeStatus.legacyDataUnclaimed,
        );
        await LegacyDataClaimService(
          session: session,
          currentConfirmedScope: () => session.confirmedScope,
        ).claim(protectedConfirmationAccepted: true);
        expect(
          (await healthService.evaluate(
            snapshot: snapshot,
            session: session,
          )).status,
          OwnerScopeStatus.safe,
        );
      },
    );
  });
}

Future<void> _seedScope(
  AppDatabase database,
  String owner,
  String suffix,
) async {
  await database.customStatement('''
    INSERT OR IGNORE INTO categories (
      id, owner_scope_id, name, type, icon, color, is_default,
      sort_order, created_at, updated_at
    ) VALUES ('01900000-0000-7000-8000-000000000001', NULL, 'Food',
      'expense', 'food', 4293212469, 1, 1010, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO accounts (
      id, owner_scope_id, name, type, currency_code, balance, icon, color,
      created_at, updated_at
    ) VALUES ('account-$suffix', '$owner', 'Account', 'cash', 'USD', '0',
      'wallet', 1, 1, 1)
  ''');
  await database.updateAccountBalanceProjection(
    ownerScopeId: owner,
    accountId: 'account-$suffix',
    balance: '10',
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  await database.customStatement('''
    INSERT INTO categories (
      id, owner_scope_id, name, type, icon, color, sort_order,
      created_at, updated_at
    ) VALUES ('category-$suffix', '$owner', 'Private', 'expense', 'food', 1,
      1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO payees (
      id, owner_scope_id, name, normalized_name, created_at, updated_at
    ) VALUES ('payee-$suffix', '$owner', 'Shop', 'shop', 1, 1)
  ''');
  await database.customStatement(
    _transactionSql(
      id: 'tx-$suffix',
      owner: owner,
      accountId: 'account-$suffix',
      categoryId: '01900000-0000-7000-8000-000000000001',
    ),
  );
  await database.customStatement('''
    INSERT INTO budgets (
      id, owner_scope_id, name, category_id, amount, currency, period_type,
      start_date, end_date, alert_threshold_percent, created_at, updated_at
    ) VALUES ('budget-$suffix', '$owner', 'Budget',
      '01900000-0000-7000-8000-000000000001', '10',
      'USD', 'monthly', 1, 2, 80, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO goals (
      id, owner_scope_id, title, type, target_amount, current_amount,
      currency, icon, color, status, created_at, updated_at
    ) VALUES ('goal-$suffix', '$owner', 'Goal', 'savings', '100', '0',
      'USD', 'target', 1, 'active', 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO receipts (
      id, owner_scope_id, document_type, payment_status, confidence,
      image_retention_choice, status, created_at, updated_at
    ) VALUES ('receipt-$suffix', '$owner', 'purchase_receipt', 'paid', 90,
      'discard', 'review_required', 1, 1)
  ''');
}

String _transactionSql({
  required String id,
  required String? owner,
  required String accountId,
  required String categoryId,
}) {
  final ownerSql = owner == null ? 'NULL' : "'$owner'";
  return '''
    INSERT INTO transactions (
      id, owner_scope_id, account_id, category_id, amount, currency_code,
      type, payment_method, source, status, transaction_date,
      created_at, updated_at
    ) VALUES ('$id', $ownerSql, '$accountId', '$categoryId', '1', 'USD',
      'expense', 'cash', 'manual', 'posted', 1, 1, 1)
  ''';
}
