import 'dart:async';
import 'dart:io';

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
import 'package:cashpilot_ai/features/ai_assistant/presentation/widgets/ai_financial_storage_preview_card.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/balance_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/finance_validation_service.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transaction_processor.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/services/transfer_processor.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_account_balance_repository.dart';
import 'package:cashpilot_ai/features/transactions/data/adapters/drift_finance_transaction_manager.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:cashpilot_ai/features/transactions/transactions.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/helpers/scoped_database_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'synthetic Android preview cancels safely and double confirm persists once',
    (tester) async {
      final temporaryDirectory = await getTemporaryDirectory();
      final databaseFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        'cashpilot_ai_preview_acceptance.sqlite',
      );
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
      addTearDown(() async {
        if (await databaseFile.exists()) {
          await databaseFile.delete();
        }
      });

      var database = AppDatabase(executor: NativeDatabase(databaseFile));
      final fixture = await _seedFixture(database);
      var runtime = _buildRuntime(database);

      final rejected = _expenseDraft(
        fixture.account,
        fixture.category,
        id: 'android-rejected-milk-expense',
      );
      await tester.pumpWidget(
        _AcceptanceApp(
          key: ValueKey(rejected.id),
          draft: rejected,
          onCancel: () => runtime.executor.cancel(rejected),
          onConfirm: () async =>
              runtime.executor.execute(rejected, confirmed: true),
        ),
      );
      await tester.pumpAndSettle();
      final cancel = find.byKey(const Key('ai_financial_preview_cancel'));
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(await _transactions(runtime.repository), isEmpty);
      expect(
        await _balance(database, fixture.account.id),
        Decimal.fromInt(100),
      );

      final confirmed = _expenseDraft(
        fixture.account,
        fixture.category,
        id: 'android-confirmed-milk-expense',
      );
      var confirmInvocations = 0;
      final confirmationComplete =
          Completer<AppResult<AiActionExecutionResult>>();
      await tester.pumpWidget(
        _AcceptanceApp(
          key: ValueKey(confirmed.id),
          draft: confirmed,
          onCancel: () => runtime.executor.cancel(confirmed),
          onConfirm: () async {
            confirmInvocations += 1;
            final result = await runtime.executor.execute(
              confirmed,
              confirmed: true,
            );
            if (!confirmationComplete.isCompleted) {
              confirmationComplete.complete(result);
            }
            return result;
          },
        ),
      );
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('ai_financial_preview_confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump();

      expect(
        await confirmationComplete.future,
        isA<AppSuccess<AiActionExecutionResult>>(),
      );
      await tester.pumpAndSettle();
      expect(confirmInvocations, 1);
      expect(await _transactions(runtime.repository), hasLength(1));
      expect(await _balance(database, fixture.account.id), Decimal.fromInt(95));

      await database.close();
      database = AppDatabase(executor: NativeDatabase(databaseFile));
      runtime = _buildRuntime(database);
      expect(await _transactions(runtime.repository), hasLength(1));
      expect(await _balance(database, fixture.account.id), Decimal.fromInt(95));

      final replay = await runtime.executor.execute(confirmed, confirmed: true);
      expect(replay, isA<AppFailure<AiActionExecutionResult>>());
      expect(await _transactions(runtime.repository), hasLength(1));
      expect(await _balance(database, fixture.account.id), Decimal.fromInt(95));

      debugPrint(
        'AI_PREVIEW_ANDROID_ACCEPTANCE '
        'cancel_balance=100.000 confirm_balance=95.000 '
        'transaction_count=1 confirm_invocations=1 restart_replay=blocked',
      );
      await database.close();
    },
  );
}

class _AcceptanceApp extends StatefulWidget {
  const _AcceptanceApp({
    super.key,
    required this.draft,
    required this.onCancel,
    required this.onConfirm,
  });

  final AiActionDraft draft;
  final VoidCallback onCancel;
  final Future<AppResult<AiActionExecutionResult>> Function() onConfirm;

  @override
  State<_AcceptanceApp> createState() => _AcceptanceAppState();
}

class _AcceptanceAppState extends State<_AcceptanceApp> {
  late AiActionDraft _draft = widget.draft;
  var _confirmStarted = false;
  var _cancelled = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CPTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: _cancelled
                ? const Text('Operation cancelled. Nothing was saved.')
                : AiFinancialStoragePreviewCard(
                    draft: _draft,
                    timeZoneName: 'Africa/Tripoli',
                    onReject: () {
                      widget.onCancel();
                      setState(() => _cancelled = true);
                    },
                    onConfirm: _confirmStarted ? null : _confirm,
                  ),
          ),
        ),
      ),
    );
  }

  void _confirm() {
    if (_confirmStarted) return;
    _confirmStarted = true;
    setState(() {
      _draft = _draft.withStatus(AiActionExecutionStatus.executing);
    });
    unawaited(_completeConfirmation());
  }

  Future<void> _completeConfirmation() async {
    final result = await widget.onConfirm();
    if (!mounted) return;
    setState(() {
      _draft = _draft.withStatus(
        result is AppSuccess<AiActionExecutionResult>
            ? AiActionExecutionStatus.executed
            : AiActionExecutionStatus.failed,
      );
    });
  }
}

class _Fixture {
  const _Fixture({required this.account, required this.category});

  final Account account;
  final Category category;
}

class _Runtime {
  const _Runtime({required this.repository, required this.executor});

  final TransactionsRepository repository;
  final AiActionExecutor executor;
}

Future<_Fixture> _seedFixture(AppDatabase database) async {
  final session = scopedTestSession(
    database,
    syntheticFirebaseUid: 'ai-preview-android-synthetic-owner',
  );
  final timestamp = DateTime.utc(2026, 8, 23, 9);
  final account = Account.create(
    id: 'synthetic-cash',
    name: 'Synthetic Cash',
    type: AccountType.cash,
    currencyCode: 'LYD',
    balance: Decimal.fromInt(100),
    icon: 'wallet',
    color: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  final category = Category.create(
    id: 'synthetic-groceries',
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
  return _Fixture(account: account, category: category);
}

_Runtime _buildRuntime(AppDatabase database) {
  final session = scopedTestSession(
    database,
    syntheticFirebaseUid: 'ai-preview-android-synthetic-owner',
  );
  final accountBalances = DriftAccountBalanceRepository(session);
  final financeTransactions = DriftFinanceTransactionManager(session);
  final repository = TransactionsRepositoryImpl(
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
  return _Runtime(
    repository: repository,
    executor: AiActionExecutor(
      createTransaction: CreateTransaction(repository),
      createTransfer: CreateTransfer(repository),
      validator: const AiActionValidator(),
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
    createdAt: DateTime.utc(2026, 8, 23),
    action: CreateExpenseDraft(
      AiTransactionDraft(
        type: TransactionType.expense,
        amount: Money(amount: Decimal.fromInt(5), currencyCode: 'LYD'),
        account: account,
        category: category,
        paymentMethod: PaymentMethod.cash,
        paymentMethodDefinition: null,
        note: 'milk 5 dinar',
        itemDescription: 'Milk',
        transactionDate: DateTime.utc(2026, 8, 22, 22),
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
