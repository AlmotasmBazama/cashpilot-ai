import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/budgets/data/datasources/local/budgets_local_data_source.dart';
import 'package:cashpilot_ai/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget.dart';
import 'package:cashpilot_ai/features/budgets/domain/enums/budget_period_type.dart';
import 'package:cashpilot_ai/features/budgets/domain/enums/budget_status.dart';
import 'package:cashpilot_ai/features/budgets/domain/failures/budget_failure_codes.dart';
import 'package:cashpilot_ai/features/budgets/domain/repositories/budget_repository.dart';
import 'package:cashpilot_ai/features/budgets/domain/services/budget_progress_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  group('Budget domain', () {
    test('creates a valid monthly budget', () {
      final value = budget();

      expect(value.name, 'Groceries');
      expect(value.amount, Decimal.fromInt(500));
      expect(value.periodType, BudgetPeriodType.monthly);
      expect(value.alertThresholdPercent, 80);
      expect(value.isArchived, isFalse);
    });

    test('rejects zero and negative amounts', () {
      for (final amount in <Decimal>[Decimal.zero, Decimal.fromInt(-1)]) {
        expect(
          () => budget(amount: amount),
          throwsA(
            isA<BudgetValidationException>().having(
              (error) => error.code,
              'code',
              BudgetFailureCodes.invalidAmount,
            ),
          ),
        );
      }
    });

    test('rejects invalid period and threshold', () {
      expect(
        () => budget(
          start: DateTime.utc(2026, 8, 1),
          end: DateTime.utc(2026, 7, 1),
        ),
        throwsA(isA<BudgetValidationException>()),
      );
      for (final threshold in <int>[-1, 101]) {
        expect(
          () => budget(threshold: threshold),
          throwsA(
            isA<BudgetValidationException>().having(
              (error) => error.code,
              'code',
              BudgetFailureCodes.invalidThreshold,
            ),
          ),
        );
      }
    });
  });

  group('Budget progress', () {
    const calculator = BudgetProgressCalculator();
    final now = DateTime.utc(2026, 7, 14);

    test('counts only posted category expenses in the active period', () async {
      final original = <Transaction>[
        transaction(amount: '100'),
        transaction(amount: '50', type: TransactionType.income),
        transaction(amount: '50', status: TransactionStatus.cancelled),
        transaction(amount: '50', status: TransactionStatus.pending),
        transaction(amount: '50', categoryId: 'fuel'),
        transaction(amount: '50', date: DateTime.utc(2026, 6, 30)),
        transaction(amount: '10', currency: 'USD'),
      ];
      final before = original.map((item) => item.amount).toList();

      final progress = await calculator.calculate(
        budget: budget(amount: Decimal.fromInt(200)),
        transactions: original,
        now: now,
        convertMoney: (money, to) async => AppResult.success(
          Money(amount: money.amount * Decimal.parse('7.5'), currencyCode: to),
        ),
      );

      expect(progress.spentAmount, Decimal.fromInt(175));
      expect(progress.remainingAmount, Decimal.fromInt(25));
      expect(progress.progressPercent, Decimal.parse('87.500'));
      expect(progress.status, BudgetStatus.warning);
      expect(progress.missingRateWarnings, isEmpty);
      expect(original.map((item) => item.amount), orderedEquals(before));
    });

    test('missing conversion creates a partial warning', () async {
      final progress = await calculator.calculate(
        budget: budget(),
        transactions: <Transaction>[transaction(amount: '10', currency: 'USD')],
        now: now,
        convertMoney: (_, _) async =>
            const AppResult.failure(Failure(message: 'Missing rate.')),
      );

      expect(progress.spentAmount, Decimal.zero);
      expect(progress.isPartial, isTrue);
      expect(progress.status, BudgetStatus.warning);
      expect(progress.missingRateWarnings.single.fromCurrencyCode, 'USD');
      expect(progress.missingRateWarnings.single.toCurrencyCode, 'LYD');
    });

    test('marks a budget exceeded at one hundred percent', () async {
      final progress = await calculator.calculate(
        budget: budget(amount: Decimal.fromInt(100)),
        transactions: <Transaction>[transaction(amount: '110')],
        now: now,
        convertMoney: (_, _) async => throw StateError('not called'),
      );

      expect(progress.status, BudgetStatus.exceeded);
      expect(progress.remainingAmount, Decimal.fromInt(-10));
    });
  });

  group('Budget repository', () {
    late AppDatabase database;
    late BudgetRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = BudgetRepositoryImpl(
        localDataSource: DriftBudgetsLocalDataSource(
          scopedTestSession(database),
        ),
        logger: AppLogger.instance,
      );
    });

    tearDown(() => database.close());

    test('creation revalidates values supplied through copyWith', () async {
      final valid = budget();
      for (final (invalid, code) in [
        (
          valid.copyWith(amount: Decimal.zero),
          BudgetFailureCodes.invalidAmount,
        ),
        (valid.copyWith(name: '  '), BudgetFailureCodes.invalidName),
        (
          valid.copyWith(currency: 'invalid'),
          BudgetFailureCodes.invalidCurrency,
        ),
        (
          valid.copyWith(endDate: valid.startDate),
          BudgetFailureCodes.invalidPeriod,
        ),
        (
          valid.copyWith(alertThresholdPercent: 101),
          BudgetFailureCodes.invalidThreshold,
        ),
      ]) {
        final result = await repository.createBudget(invalid);
        expect(
          result,
          isA<AppFailure<Budget>>().having(
            (result) => result.failure.code,
            'code',
            code,
          ),
        );
      }
      expect(
        (await repository.watchBudgets(includeArchived: true).first)
            .expectSuccess(),
        isEmpty,
      );
    });

    test('creates, updates, watches, archives, and restores', () async {
      final initial = await repository
          .watchBudgets(includeArchived: true)
          .first
          .then((result) => result.expectSuccess());
      final created = (await repository.createBudget(budget())).expectSuccess();
      final watched = await repository
          .watchBudgets(includeArchived: true)
          .first
          .then((result) => result.expectSuccess());
      final updated = (await repository.updateBudget(
        created.copyWith(name: 'Food plan'),
      )).expectSuccess();
      final archived = (await repository.archiveBudget(
        created.id,
      )).expectSuccess();
      final activeAfterArchive = await repository
          .getActiveBudgetsForPeriod(
            DateTime.utc(2026, 7, 1),
            DateTime.utc(2026, 8, 1),
          )
          .then((result) => result.expectSuccess());
      final restored = (await repository.restoreBudget(
        created.id,
      )).expectSuccess();

      expect(initial, isEmpty);
      expect(watched.single.id, created.id);
      expect(updated.name, 'Food plan');
      expect(archived.isArchived, isTrue);
      expect(archived.isActive, isFalse);
      expect(activeAfterArchive, isEmpty);
      expect(restored.isArchived, isFalse);
      expect(restored.isActive, isTrue);
    });
  });
}

Budget budget({
  Decimal? amount,
  int threshold = 80,
  DateTime? start,
  DateTime? end,
}) {
  return Budget.create(
    name: 'Groceries',
    categoryId: 'groceries',
    amount: amount ?? Decimal.fromInt(500),
    currency: 'LYD',
    periodType: BudgetPeriodType.monthly,
    startDate: start ?? DateTime.utc(2026, 7, 1),
    endDate: end ?? DateTime.utc(2026, 8, 1),
    alertThresholdPercent: threshold,
  );
}

Transaction transaction({
  required String amount,
  String categoryId = 'groceries',
  String currency = 'LYD',
  TransactionType type = TransactionType.expense,
  TransactionStatus status = TransactionStatus.posted,
  DateTime? date,
}) {
  return Transaction.create(
    accountId: 'cash',
    categoryId: categoryId,
    amount: Money(amount: Decimal.parse(amount), currencyCode: currency),
    type: type,
    status: status,
    transactionDate: date ?? DateTime.utc(2026, 7, 10),
  );
}

extension _ResultTestX<T> on AppResult<T> {
  T expectSuccess() => switch (this) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => throw TestFailure(failure.message),
  };
}
