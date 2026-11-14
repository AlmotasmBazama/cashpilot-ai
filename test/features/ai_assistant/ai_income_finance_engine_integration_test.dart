import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_action_executor.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_validator.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/balance_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/finance_validation_service.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transaction_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transfer_processor.dart';
import 'package:cashpilot_ai/features/income_sources/domain/entities/income_source_suggestion.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_account_balance_repository.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:cashpilot_ai/features/transactions/transactions.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late TransactionsRepository repository;
  late AiActionExecutor executor;
  late Account account;
  late Category category;
  late Category expenseCategory;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    final session = scopedTestSession(database);
    final timestamp = DateTime.utc(2026, 8, 16, 9);
    account = Account.create(
      id: 'income-account',
      name: 'Cash',
      type: AccountType.cash,
      currencyCode: 'LYD',
      balance: Decimal.fromInt(100),
      icon: 'wallet',
      color: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    category = Category.create(
      id: 'income-category',
      name: 'Other Income',
      type: CategoryType.income,
      icon: const CategoryIcon(key: 'tag'),
      color: const CategoryColor(argb: 1),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    expenseCategory = Category.create(
      id: 'expense-category',
      name: 'Groceries',
      type: CategoryType.expense,
      icon: const CategoryIcon(key: 'cart'),
      color: const CategoryColor(argb: 2),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion(
            id: Value(account.id),
            ownerScopeId: Value(session.ownerScopeValue),
            name: Value(account.name),
            type: Value(account.type.name),
            currencyCode: Value(account.currencyCode),
            balance: Value(account.balance.toString()),
            icon: Value(account.icon),
            color: Value(account.color),
            isArchived: Value(account.isArchived),
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
          ),
        );
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion(
            id: Value(expenseCategory.id),
            ownerScopeId: Value(session.ownerScopeValue),
            name: Value(expenseCategory.name),
            type: Value(expenseCategory.type.name),
            icon: Value(expenseCategory.icon.key),
            color: Value(expenseCategory.color.argb),
            isDefault: const Value(false),
            isArchived: const Value(false),
            sortOrder: const Value(1),
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
          ),
        );
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion(
            id: Value(category.id),
            ownerScopeId: Value(session.ownerScopeValue),
            name: Value(category.name),
            type: Value(category.type.name),
            icon: Value(category.icon.key),
            color: Value(category.color.argb),
            isDefault: const Value(false),
            isArchived: const Value(false),
            sortOrder: const Value(0),
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
          ),
        );

    final accountBalances = DriftAccountBalanceRepository(session);
    final financeTransactions = DriftFinanceTransactionManager(session);
    repository = TransactionsRepositoryImpl(
      localDataSource: DriftTransactionsLocalDataSource(session),
      transactionProcessor: TransactionProcessor(
        accountBalanceRepository: accountBalances,
        transactionManager: financeTransactions,
        balanceCalculator: const BalanceCalculator(),
        validationService: const FinanceValidationService(),
      ),
      transferProcessor: TransferProcessor(
        accountBalanceRepository: accountBalances,
        transactionManager: financeTransactions,
        balanceCalculator: const BalanceCalculator(),
        validationService: const FinanceValidationService(),
        exchangeRateProvider: const SameCurrencyExchangeRateProvider(),
      ),
      logger: AppLogger.instance,
    );
    executor = AiActionExecutor(
      createTransaction: CreateTransaction(repository),
      createTransfer: CreateTransfer(repository),
      validator: const AiActionValidator(),
    );
  });

  tearDown(() => database.close());

  test('posted income executes once through the Finance Engine', () async {
    final draft = _incomeDraft(account, category, TransactionStatus.posted);

    final results =
        await Future.wait(<Future<AppResult<AiActionExecutionResult>>>[
          executor.execute(draft, confirmed: true),
          executor.execute(draft, confirmed: true),
        ]);

    expect(
      results.whereType<AppSuccess<AiActionExecutionResult>>(),
      hasLength(1),
    );
    expect(await _transactions(repository), hasLength(1));
    final persisted = (await _transactions(repository)).single;
    expect(persisted.id, draft.id);
    expect(persisted.type, TransactionType.income);
    expect(persisted.status, TransactionStatus.posted);
    expect(persisted.incomeSourceType, IncomeSourceType.debtRepayment);
    expect(persisted.transactionDate.toUtc(), DateTime.utc(2026, 8, 15));
    expect(await _balance(database, account.id), Decimal.fromInt(1100));
  });

  test(
    'confirmed gift uses CreateTransaction and changes the balance exactly once',
    () async {
      final cancelled = _incomeDraft(
        account,
        category,
        TransactionStatus.posted,
        id: 'cancelled-gift-income',
        amount: Decimal.fromInt(150),
        sourceType: IncomeSourceType.gift,
        sourceName: 'My friend',
        note: 'Birthday gift from my friend',
      );
      final gift = _incomeDraft(
        account,
        category,
        TransactionStatus.posted,
        id: 'confirmed-gift-income',
        amount: Decimal.fromInt(150),
        sourceType: IncomeSourceType.gift,
        sourceName: 'My friend',
        note: 'Birthday gift from my friend',
      );

      executor.cancel(cancelled);
      expect(
        await executor.execute(cancelled, confirmed: true),
        isA<AppFailure<AiActionExecutionResult>>(),
      );
      expect(await _transactions(repository), isEmpty);
      expect(await _balance(database, account.id), Decimal.fromInt(100));

      final confirmations =
          await Future.wait(<Future<AppResult<AiActionExecutionResult>>>[
            executor.execute(gift, confirmed: true),
            executor.execute(gift, confirmed: true),
          ]);

      expect(
        confirmations.whereType<AppSuccess<AiActionExecutionResult>>(),
        hasLength(1),
      );
      expect(
        confirmations.whereType<AppFailure<AiActionExecutionResult>>(),
        hasLength(1),
      );
      final transactions = await _transactions(repository);
      expect(transactions, hasLength(1));
      expect(transactions.single.id, gift.id);
      expect(transactions.single.type, TransactionType.income);
      expect(transactions.single.status, TransactionStatus.posted);
      expect(transactions.single.incomeSourceType, IncomeSourceType.gift);
      expect(transactions.single.amount.amount, Decimal.fromInt(150));
      expect(await _balance(database, account.id), Decimal.fromInt(250));
    },
  );

  test(
    'pending income is verified locally but remains balance-neutral',
    () async {
      final draft = _incomeDraft(account, category, TransactionStatus.pending);

      final result = await executor.execute(draft, confirmed: true);

      expect(result, isA<AppSuccess<AiActionExecutionResult>>());
      final persisted = (await _transactions(repository)).single;
      expect(persisted.status, TransactionStatus.pending);
      expect(await _balance(database, account.id), Decimal.fromInt(100));
    },
  );

  test('no confirmation or cancellation creates no local change', () async {
    final unconfirmed = _incomeDraft(
      account,
      category,
      TransactionStatus.posted,
      id: 'unconfirmed-income',
    );
    final cancelled = _incomeDraft(
      account,
      category,
      TransactionStatus.posted,
      id: 'cancelled-income',
    );

    expect(
      await executor.execute(unconfirmed, confirmed: false),
      isA<AppFailure<AiActionExecutionResult>>(),
    );
    executor.cancel(cancelled);
    expect(
      await executor.execute(cancelled, confirmed: true),
      isA<AppFailure<AiActionExecutionResult>>(),
    );

    expect(await _transactions(repository), isEmpty);
    expect(await _balance(database, account.id), Decimal.fromInt(100));
  });

  test(
    'expense reject stays 100, confirm reaches 95 once, and restart cannot replay',
    () async {
      final rejected = _expenseDraft(
        account,
        expenseCategory,
        id: 'rejected-milk-expense',
      );
      executor.cancel(rejected);
      expect(
        await executor.execute(rejected, confirmed: true),
        isA<AppFailure<AiActionExecutionResult>>(),
      );
      expect(await _transactions(repository), isEmpty);
      expect(await _balance(database, account.id), Decimal.fromInt(100));

      final confirmed = _expenseDraft(
        account,
        expenseCategory,
        id: 'confirmed-milk-expense',
      );
      final doubleConfirm =
          await Future.wait(<Future<AppResult<AiActionExecutionResult>>>[
            executor.execute(confirmed, confirmed: true),
            executor.execute(confirmed, confirmed: true),
          ]);
      expect(
        doubleConfirm.whereType<AppSuccess<AiActionExecutionResult>>(),
        hasLength(1),
      );
      expect(await _transactions(repository), hasLength(1));
      expect(await _balance(database, account.id), Decimal.fromInt(95));

      final restartedExecutor = AiActionExecutor(
        createTransaction: CreateTransaction(repository),
        createTransfer: CreateTransfer(repository),
        validator: const AiActionValidator(),
      );
      expect(
        await restartedExecutor.execute(confirmed, confirmed: true),
        isA<AppFailure<AiActionExecutionResult>>(),
      );
      expect(await _transactions(repository), hasLength(1));
      expect(await _balance(database, account.id), Decimal.fromInt(95));
    },
  );
}

AiActionDraft _incomeDraft(
  Account account,
  Category category,
  TransactionStatus status, {
  String id = 'verified-income',
  Decimal? amount,
  IncomeSourceType sourceType = IncomeSourceType.debtRepayment,
  String sourceName = 'Salem',
  String note = 'Salem repaid a debt',
}) {
  return AiActionDraft.create(
    id: id,
    createdAt: DateTime.utc(2026, 8, 16),
    action: CreateIncomeDraft(
      AiTransactionDraft(
        type: TransactionType.income,
        amount: Money(
          amount: amount ?? Decimal.fromInt(1000),
          currencyCode: 'LYD',
        ),
        account: account,
        category: category,
        paymentMethod: PaymentMethod.cash,
        paymentMethodDefinition: null,
        note: note,
        payeeHint: sourceName,
        incomeSourceSuggestion: IncomeSourceSuggestion(
          sourceType: sourceType,
          sourceNameHint: sourceName,
          confidence: 100,
          source: IncomeSourceSuggestionSource.explicitUserInput,
          requiresClarification: false,
        ),
        transactionDate: DateTime.utc(2026, 8, 15),
        status: status,
      ),
    ),
  );
}

AiActionDraft _expenseDraft(
  Account account,
  Category category, {
  required String id,
}) {
  return AiActionDraft.create(
    id: id,
    createdAt: DateTime.utc(2026, 8, 16),
    action: CreateExpenseDraft(
      AiTransactionDraft(
        type: TransactionType.expense,
        amount: Money(amount: Decimal.fromInt(5), currencyCode: 'LYD'),
        account: account,
        category: category,
        paymentMethod: PaymentMethod.cash,
        paymentMethodDefinition: null,
        note: 'milk 5 dinar',
        itemDescription: 'milk',
        transactionDate: DateTime.utc(2026, 8, 16),
        status: TransactionStatus.posted,
      ),
    ),
  );
}

Future<List<Transaction>> _transactions(
  TransactionsRepository repository,
) async {
  return switch (await repository.getTransactions()) {
    AppSuccess<List<Transaction>>(:final data) => data,
    AppFailure<List<Transaction>>(:final failure) => throw TestFailure(
      'Expected transactions, got ${failure.code}: ${failure.message}',
    ),
  };
}

Future<Decimal> _balance(AppDatabase database, String accountId) async {
  final row = await (database.select(
    database.accounts,
  )..where((candidate) => candidate.id.equals(accountId))).getSingle();
  return Decimal.parse(row.balance);
}
