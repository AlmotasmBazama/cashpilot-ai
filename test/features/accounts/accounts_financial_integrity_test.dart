import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/features/accounts/data/datasources/local/accounts_local_data_source.dart';
import 'package:cashpilot_ai/features/accounts/data/mappers/account_mapper.dart';
import 'package:cashpilot_ai/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:cashpilot_ai/features/accounts/application/services/transactions_opening_balance_ledger.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/accounts/domain/failures/account_failure_codes.dart';
import 'package:cashpilot_ai/features/accounts/domain/repositories/opening_balance_ledger.dart';
import 'package:cashpilot_ai/features/categories/data/datasources/local/categories_local_data_source.dart';
import 'package:cashpilot_ai/features/categories/data/repositories/categories_repository_impl.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/repositories/categories_repository.dart';
import 'package:cashpilot_ai/features/categories/domain/usecases/get_default_categories.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/entities/account_balance_state.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/balance_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/finance_validation_service.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transaction_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transfer_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_account_balance_repository.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_source.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  group('account ledger integrity', () {
    late AppDatabase database;
    late ScopedAppDatabaseSession session;
    late DriftAccountsLocalDataSource localDataSource;
    late CategoriesRepository categoriesRepository;
    late TransactionsRepository transactionsRepository;
    late DriftAccountBalanceRepository balanceRepository;
    late OpeningBalanceLedger openingBalanceLedger;
    late AccountsRepositoryImpl repository;
    late String ownerScope;

    setUp(() async {
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      session = scopedTestSession(database);
      ownerScope = session.ownerScopeValue;
      localDataSource = DriftAccountsLocalDataSource(session);
      categoriesRepository = CategoriesRepositoryImpl(
        localDataSource: DriftCategoriesLocalDataSource(session),
        logger: AppLogger.instance,
      );
      final transactionManager = DriftFinanceTransactionManager(session);
      balanceRepository = DriftAccountBalanceRepository(session);
      transactionsRepository = TransactionsRepositoryImpl(
        localDataSource: DriftTransactionsLocalDataSource(session),
        transactionProcessor: TransactionProcessor(
          accountBalanceRepository: balanceRepository,
          transactionManager: transactionManager,
          balanceCalculator: const BalanceCalculator(),
          validationService: const FinanceValidationService(),
        ),
        transferProcessor: TransferProcessor(
          accountBalanceRepository: balanceRepository,
          transactionManager: transactionManager,
          balanceCalculator: const BalanceCalculator(),
          validationService: const FinanceValidationService(),
          exchangeRateProvider: const _UnusedExchangeRateProvider(),
        ),
        logger: AppLogger.instance,
      );
      openingBalanceLedger = TransactionsOpeningBalanceLedger(
        createTransaction: CreateTransaction(transactionsRepository),
        getDefaultCategories: GetDefaultCategories(categoriesRepository),
      );
      repository = AccountsRepositoryImpl(
        localDataSource: localDataSource,
        openingBalanceLedger: openingBalanceLedger,
        logger: AppLogger.instance,
      );
    });

    tearDown(() => database.close());

    Future<void> insertRawAccount({required String id, String balance = '0'}) {
      return database.customStatement(
        '''
        INSERT INTO accounts (
          id, owner_scope_id, name, type, currency_code, balance, icon, color,
          created_at, updated_at
        ) VALUES (?, ?, 'Account', 'cash', 'USD', ?, 'wallet', 1, ?, ?)
        ''',
        <Object?>[
          id,
          ownerScope,
          balance,
          DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
          DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
        ],
      );
    }

    Future<void> setProjectedBalance(String id, String balance) {
      return balanceRepository.save(
        AccountBalanceState(
          accountId: id,
          currencyCode: 'USD',
          balance: Decimal.parse(balance),
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      );
    }

    Future<void> insertDependency(
      _AccountDependency dependency,
      String accountId,
    ) async {
      await categoriesRepository.getDefaultCategories();
      switch (dependency) {
        case _AccountDependency.transaction:
          await database.customStatement(
            '''
            INSERT INTO transactions (
              id, owner_scope_id, account_id, category_id, amount,
              currency_code, type, payment_method, source, status,
              transaction_date, created_at, updated_at
            ) VALUES (?, ?, ?, '01900000-0000-7000-8000-000000000001',
              '1', 'USD', 'expense', 'cash', 'manual', 'pending', ?, ?, ?)
            ''',
            <Object?>['tx-$accountId', ownerScope, accountId, 1, 1, 1],
          );
        case _AccountDependency.payeeDefault:
          await database.customStatement(
            '''
            INSERT INTO payees (
              id, owner_scope_id, name, normalized_name, default_account_id,
              created_at, updated_at
            ) VALUES (?, ?, 'Payee', 'payee', ?, ?, ?)
            ''',
            <Object?>['payee-$accountId', ownerScope, accountId, 1, 1],
          );
        case _AccountDependency.goal:
          await database.customStatement(
            '''
            INSERT INTO goals (
              id, owner_scope_id, title, type, target_amount, current_amount,
              currency, linked_account_id, icon, color, status, created_at,
              updated_at
            ) VALUES (?, ?, 'Goal', 'savings', '100', '0', 'USD', ?,
              'target', 1, 'active', ?, ?)
            ''',
            <Object?>['goal-$accountId', ownerScope, accountId, 1, 1],
          );
      }
    }

    Future<int> dependencyCount(
      _AccountDependency dependency,
      String accountId,
    ) async {
      final (table, column) = switch (dependency) {
        _AccountDependency.transaction => ('transactions', 'account_id'),
        _AccountDependency.payeeDefault => ('payees', 'default_account_id'),
        _AccountDependency.goal => ('goals', 'linked_account_id'),
      };
      final row = await database
          .customSelect(
            'SELECT COUNT(*) AS value FROM $table '
            'WHERE owner_scope_id = ? AND $column = ?',
            variables: <Variable<Object>>[
              Variable<String>(ownerScope),
              Variable<String>(accountId),
            ],
          )
          .getSingle();
      return row.read<int>('value');
    }

    test(
      'OF-002 creates zero first and posts exactly one atomic opening entry',
      () async {
        var observedZeroBeforePosting = false;
        final inspectedRepository = AccountsRepositoryImpl(
          localDataSource: localDataSource,
          openingBalanceLedger: _InspectingOpeningBalanceLedger(
            delegate: openingBalanceLedger,
            beforePost: (accountId) async {
              final staged = await localDataSource.getAccountById(accountId);
              observedZeroBeforePosting = staged?.balance == '0';
            },
          ),
          logger: AppLogger.instance,
        );

        final result = await inspectedRepository.createAccount(
          _account(id: 'opening-account', balance: '100.25'),
        );

        expect(result, isA<AppSuccess<Account>>());
        expect(observedZeroBeforePosting, isTrue);
        final account = (result as AppSuccess<Account>).data;
        expect(account.balance, Decimal.parse('100.25'));

        final accountRow = await localDataSource.getAccountById(account.id);
        expect(accountRow?.balance, '100.25');
        final transactions = await transactionsRepository.getTransactions(
          accountId: account.id,
        );
        expect(transactions, isA<AppSuccess>());
        final entries = (transactions as AppSuccess).data as List<dynamic>;
        expect(entries, hasLength(1));
        final entry = entries.single;
        expect(entry.amount.amount, Decimal.parse('100.25'));
        expect(entry.amount.currencyCode, 'USD');
        expect(entry.type, TransactionType.income);
        expect(entry.status, TransactionStatus.posted);
        expect(entry.source, TransactionSource.system);
        expect(entry.note, TransactionsOpeningBalanceLedger.entryNote);
      },
    );

    test('OF-002 rolls the account back when opening entry fails', () async {
      await categoriesRepository.getDefaultCategories();
      await insertRawAccount(id: 'collision-anchor');
      final collisionTransactionId =
          TransactionsOpeningBalanceLedger.transactionIdForAccount(
            'rolled-back-account',
          );
      await database.customStatement(
        '''
        INSERT INTO transactions (
          id, owner_scope_id, account_id, category_id, amount, currency_code,
          type, payment_method, source, status, transaction_date, created_at,
          updated_at
        ) VALUES (?, ?, 'collision-anchor',
          '01900000-0000-7000-8000-000000000001', '1', 'USD', 'expense',
          'cash', 'manual', 'pending', 1, 1, 1)
        ''',
        <Object?>[collisionTransactionId, ownerScope],
      );
      final failing = AccountsRepositoryImpl(
        localDataSource: localDataSource,
        openingBalanceLedger: openingBalanceLedger,
        logger: AppLogger.instance,
      );

      final result = await failing.createAccount(
        _account(id: 'rolled-back-account', balance: '25'),
      );

      expect(result, isA<AppFailure<Account>>());
      expect(
        await localDataSource.getAccountById('rolled-back-account'),
        isNull,
      );
      expect(
        await transactionsRepository.getTransactions(
          accountId: 'rolled-back-account',
        ),
        isA<AppSuccess>(),
      );
      final collisionRows = await database
          .customSelect(
            'SELECT COUNT(*) AS value FROM transactions WHERE id = ?',
            variables: <Variable<Object>>[
              Variable<String>(collisionTransactionId),
            ],
          )
          .getSingle();
      expect(collisionRows.read<int>('value'), 1);
    });

    test('OF-002 direct storage cannot insert an unledgered balance', () async {
      await expectLater(
        localDataSource.createAccount(
          _account(id: 'bypass', balance: '1').toDto(),
        ),
        throwsA(anything),
      );
      expect(await localDataSource.getAccountById('bypass'), isNull);
    });

    test(
      'OF-002 database guard rejects a raw nonzero account insert',
      () async {
        for (final (suffix, balance) in <(String, String)>[
          ('nonzero', '0.01'),
          ('scaled-zero', '0.00'),
          ('spaced-zero', ' 0 '),
          ('negative-zero', '-0'),
        ]) {
          final accountId = 'raw-bypass-$suffix';
          await expectLater(
            insertRawAccount(id: accountId, balance: balance),
            throwsA(anything),
            reason: balance,
          );
          expect(await localDataSource.getAccountById(accountId), isNull);
        }
      },
    );

    test('OF-002 database guard rejects account row replacement', () async {
      await insertRawAccount(id: 'replace-bypass');

      await expectLater(
        database.customStatement(
          '''INSERT OR REPLACE INTO accounts (
               id, owner_scope_id, name, type, currency_code, balance, icon,
               color, created_at, updated_at
             ) VALUES (?, ?, 'Replacement', 'cash', 'USD', '0', 'wallet',
               1, ?, ?)''',
          <Object?>[
            'replace-bypass',
            ownerScope,
            DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
            DateTime.utc(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
          ],
        ),
        throwsA(anything),
      );
      expect(
        (await localDataSource.getAccountById('replace-bypass'))?.name,
        'Account',
      );
    });

    test('OF-002 zero opening creates no synthetic ledger entry', () async {
      final result = await repository.createAccount(
        _account(id: 'zero-opening', balance: '0'),
      );

      expect(result, isA<AppSuccess<Account>>());
      final entries = await transactionsRepository.getTransactions(
        accountId: 'zero-opening',
      );
      expect(entries, isA<AppSuccess>());
      expect((entries as AppSuccess).data, isEmpty);
      expect(
        (await localDataSource.getAccountById('zero-opening'))?.balance,
        '0',
      );
    });

    for (final type in AccountType.values) {
      test('OF-033 rejects a negative ${type.name} opening', () async {
        final accountId = 'negative-${type.name}';
        final result = await repository.createAccount(
          _account(id: accountId, balance: '-0.01', type: type),
        );

        expect(result, isA<AppFailure<Account>>());
        expect(
          (result as AppFailure<Account>).failure.code,
          AccountFailureCodes.negativeOpeningBalance,
        );
        expect(await localDataSource.getAccountById(accountId), isNull);
      });
    }

    test(
      'OF-033 a positive credit can repair a legacy negative account',
      () async {
        const accountId = 'legacy-negative-repair';
        await repository.createAccount(_account(id: accountId, balance: '0'));
        await setProjectedBalance(accountId, '-100');
        final categories = await categoriesRepository.getDefaultCategories();
        final incomeCategory = (categories as AppSuccess).data.firstWhere(
          (category) => category.type == CategoryType.income,
        );

        final result = await transactionsRepository.createTransaction(
          Transaction.create(
            id: 'legacy-repair-credit',
            accountId: accountId,
            categoryId: incomeCategory.id,
            amount: Money(amount: Decimal.parse('25'), currencyCode: 'USD'),
            type: TransactionType.income,
            source: TransactionSource.manual,
            status: TransactionStatus.posted,
            transactionDate: DateTime.utc(2026, 1, 3),
            createdAt: DateTime.utc(2026, 1, 3),
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
        );

        expect(result, isA<AppSuccess<Transaction>>());
        expect(
          (await localDataSource.getAccountById(accountId))?.balance,
          '-75',
        );
      },
    );

    test(
      'OF-002 opening replay across concurrency and restart affects balance once',
      () async {
        await repository.createAccount(
          _account(id: 'opening-replay', balance: '0'),
        );
        await categoriesRepository.getDefaultCategories();

        final outcomes = await Future.wait<bool>([
          openingBalanceLedger
              .postOpeningBalance(
                accountId: 'opening-replay',
                amount: Decimal.parse('12.34'),
                currencyCode: 'USD',
                occurredAt: DateTime.utc(2026, 1, 1),
              )
              .then((_) => true, onError: (_) => false),
          openingBalanceLedger
              .postOpeningBalance(
                accountId: 'opening-replay',
                amount: Decimal.parse('12.34'),
                currencyCode: 'USD',
                occurredAt: DateTime.utc(2026, 1, 1),
              )
              .then((_) => true, onError: (_) => false),
        ]);
        expect(outcomes.where((succeeded) => succeeded), hasLength(1));

        final restartedLedger = TransactionsOpeningBalanceLedger(
          createTransaction: CreateTransaction(transactionsRepository),
          getDefaultCategories: GetDefaultCategories(categoriesRepository),
        );
        await expectLater(
          restartedLedger.postOpeningBalance(
            accountId: 'opening-replay',
            amount: Decimal.parse('12.34'),
            currencyCode: 'USD',
            occurredAt: DateTime.utc(2026, 1, 1),
          ),
          throwsA(anything),
        );

        expect(
          (await localDataSource.getAccountById('opening-replay'))?.balance,
          '12.34',
        );
        final entries = await transactionsRepository.getTransactions(
          accountId: 'opening-replay',
        );
        expect(entries, isA<AppSuccess>());
        expect((entries as AppSuccess).data, hasLength(1));
      },
    );

    test('OF-002 stale scoped session cannot post an opening entry', () async {
      await repository.createAccount(
        _account(id: 'stale-opening', balance: '0'),
      );
      session.invalidate();

      await expectLater(
        openingBalanceLedger.postOpeningBalance(
          accountId: 'stale-opening',
          amount: Decimal.one,
          currencyCode: 'USD',
          occurredAt: DateTime.utc(2026, 1, 1),
        ),
        throwsA(anything),
      );
      final row = await (database.select(
        database.accounts,
      )..where((account) => account.id.equals('stale-opening'))).getSingle();
      expect(row.balance, '0');
    });

    test(
      'OF-003 malicious protected-field update is rejected atomically',
      () async {
        final created =
            (await repository.createAccount(
                      _account(id: 'protected', balance: '75'),
                    )
                    as AppSuccess<Account>)
                .data;

        final result = await repository.updateAccount(
          created.copyWith(
            name: 'Renamed',
            balance: Decimal.parse('999999'),
            currencyCode: 'EUR',
            type: AccountType.bank,
            createdAt: DateTime.utc(1999),
          ),
        );

        expect(result, isA<AppFailure<Account>>());
        expect(
          (result as AppFailure<Account>).failure.code,
          AccountFailureCodes.protectedFieldMutation,
        );
        final stored = await localDataSource.getAccountById(created.id);
        expect(stored?.name, created.name);
        expect(stored?.balance, '75');
        expect(stored?.currencyCode, 'USD');
        expect(stored?.type, AccountType.cash.storageValue);
        expect(stored?.createdAt, created.createdAt);
      },
    );

    test(
      'OF-003 database guard rejects raw protected account updates',
      () async {
        final cases = <(String, String)>[
          ('balance', "balance = '999'"),
          ('currency', "currency_code = 'EUR'"),
          ('type', "type = 'creditCard'"),
          ('createdAt', 'created_at = 1'),
          ('id', "id = 'changed-id'"),
        ];

        for (final (label, assignment) in cases) {
          final accountId = 'raw-protected-$label';
          await insertRawAccount(id: accountId);
          await expectLater(
            database.customStatement(
              'UPDATE accounts SET $assignment WHERE id = ?',
              <Object?>[accountId],
            ),
            throwsA(anything),
            reason: label,
          );
        }
      },
    );

    test('OF-001 rejects hard delete of a non-zero account', () async {
      await insertRawAccount(id: 'non-zero');
      await setProjectedBalance('non-zero', '0.01');

      final result = await repository.deleteAccount('non-zero');

      expect(result, isA<AppFailure<void>>());
      expect(
        (result as AppFailure<void>).failure.code,
        AccountFailureCodes.nonZeroBalance,
      );
      expect(await localDataSource.getAccountById('non-zero'), isNotNull);
    });

    for (final dependency in _AccountDependency.values) {
      test(
        'OF-001 rejects hard delete with ${dependency.name} dependency',
        () async {
          final accountId = 'delete-${dependency.name}';
          await insertRawAccount(id: accountId);
          await insertDependency(dependency, accountId);

          final result = await repository.deleteAccount(accountId);

          expect(result, isA<AppFailure<void>>());
          expect(
            (result as AppFailure<void>).failure.code,
            AccountFailureCodes.hasDependencies,
          );
          expect(await localDataSource.getAccountById(accountId), isNotNull);
          expect(await dependencyCount(dependency, accountId), 1);
        },
      );

      test(
        'OF-001 rejects archive with ${dependency.name} dependency',
        () async {
          final accountId = 'archive-${dependency.name}';
          await insertRawAccount(id: accountId);
          await insertDependency(dependency, accountId);
          final account = (await localDataSource.getAccountById(
            accountId,
          ))!.toDomain();

          final result = await repository.updateAccount(
            account.copyWith(isArchived: true),
          );

          expect(result, isA<AppFailure<Account>>());
          expect(
            (result as AppFailure<Account>).failure.code,
            AccountFailureCodes.hasDependencies,
          );
          expect(
            (await localDataSource.getAccountById(accountId))?.isArchived,
            isFalse,
          );
        },
      );
    }

    test('OF-001 rejects archive of a non-zero account', () async {
      await insertRawAccount(id: 'archive-non-zero');
      await setProjectedBalance('archive-non-zero', '1');
      final account = (await localDataSource.getAccountById(
        'archive-non-zero',
      ))!.toDomain();

      final result = await repository.updateAccount(
        account.copyWith(isArchived: true),
      );

      expect(result, isA<AppFailure<Account>>());
      expect(
        (result as AppFailure<Account>).failure.code,
        AccountFailureCodes.nonZeroBalance,
      );
    });

    test('OF-001 database guard rejects raw close of nonzero account', () async {
      await insertRawAccount(id: 'raw-close-nonzero');
      await setProjectedBalance('raw-close-nonzero', '0.01');

      await expectLater(
        database.customStatement(
          "UPDATE accounts SET is_archived = 1 WHERE id = 'raw-close-nonzero'",
        ),
        throwsA(anything),
      );
      await expectLater(
        database.customStatement(
          "DELETE FROM accounts WHERE id = 'raw-close-nonzero'",
        ),
        throwsA(anything),
      );
    });

    for (final dependency in _AccountDependency.values) {
      test(
        'OF-001 database guard rejects raw close with ${dependency.name}',
        () async {
          final accountId = 'raw-close-${dependency.name}';
          await insertRawAccount(id: accountId);
          await insertDependency(dependency, accountId);

          await expectLater(
            database.customStatement(
              'UPDATE accounts SET is_archived = 1 WHERE id = ?',
              <Object?>[accountId],
            ),
            throwsA(anything),
          );
          await expectLater(
            database.customStatement(
              'DELETE FROM accounts WHERE id = ?',
              <Object?>[accountId],
            ),
            throwsA(anything),
          );
        },
      );
    }

    test('OF-001 safe hard delete leaves zero account references', () async {
      const accountId = 'safe-delete';
      await insertRawAccount(id: accountId);

      final result = await repository.deleteAccount(accountId);

      expect(result, isA<AppSuccess<void>>());
      expect(await localDataSource.getAccountById(accountId), isNull);
      for (final dependency in _AccountDependency.values) {
        expect(await dependencyCount(dependency, accountId), 0);
      }
    });
  });
}

Account _account({
  required String id,
  required String balance,
  AccountType type = AccountType.cash,
}) {
  return Account.create(
    id: id,
    name: 'Cash',
    type: type,
    currencyCode: 'USD',
    balance: Decimal.parse(balance),
    icon: 'wallet',
    color: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

enum _AccountDependency { transaction, payeeDefault, goal }

class _InspectingOpeningBalanceLedger implements OpeningBalanceLedger {
  const _InspectingOpeningBalanceLedger({
    required this.delegate,
    required this.beforePost,
  });

  final OpeningBalanceLedger delegate;
  final Future<void> Function(String accountId) beforePost;

  @override
  Future<void> postOpeningBalance({
    required String accountId,
    required Decimal amount,
    required String currencyCode,
    required DateTime occurredAt,
  }) async {
    await beforePost(accountId);
    await delegate.postOpeningBalance(
      accountId: accountId,
      amount: amount,
      currencyCode: currencyCode,
      occurredAt: occurredAt,
    );
  }
}

class _UnusedExchangeRateProvider implements ExchangeRateProvider {
  const _UnusedExchangeRateProvider();

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) {
    throw StateError('Transfers are outside this test.');
  }
}
