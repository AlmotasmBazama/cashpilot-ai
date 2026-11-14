import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/budgets/data/budget_transactions_read_model.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget.dart';
import 'package:cashpilot_ai/features/budgets/domain/enums/budget_period_type.dart';
import 'package:cashpilot_ai/features/budgets/domain/services/budget_progress_calculator.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/transactions/data/datasources/local/transactions_local_data_source.dart';
import 'package:cashpilot_ai/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late String ownerScope;
  late DriftTransactionsLocalDataSource fullHistorySource;
  late BudgetTransactionsReadModel readModel;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    final session = scopedTestSession(database);
    ownerScope = session.ownerScopeValue;
    fullHistorySource = DriftTransactionsLocalDataSource(session);
    readModel = BudgetTransactionsReadModel(
      session,
      const DriftTransactionRowDomainMapper(),
    );
  });

  tearDown(() => database.close());

  test(
    'budget window keeps posted owner expenses and existing FX semantics',
    () async {
      final budget = _budget();
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'same-currency',
        at: DateTime.utc(2026, 7, 2),
        amount: '10',
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'convertible',
        at: DateTime.utc(2026, 7, 3),
        amount: '5',
        currency: 'USD',
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'missing-rate',
        at: DateTime.utc(2026, 7, 4),
        amount: '7',
        currency: 'EUR',
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'pending',
        at: DateTime.utc(2026, 7, 5),
        amount: '999',
        status: 'pending',
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'income',
        at: DateTime.utc(2026, 7, 6),
        amount: '999',
        type: 'income',
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'end-exclusive',
        at: DateTime.utc(2026, 8, 1),
        amount: '999',
      );
      await _insertTransaction(
        database,
        ownerScope: 'another-owner',
        id: 'other-owner',
        at: DateTime.utc(2026, 7, 7),
        amount: '999',
      );

      final transactions = _expectTransactions(
        await readModel
            .watch(
              BudgetTransactionWindowRequest.fromBudgets(
                budgets: <Budget>[budget],
                now: DateTime.utc(2026, 7, 15),
              ),
            )
            .first,
      );
      expect(
        transactions.map((transaction) => transaction.id).toSet(),
        <String>{'same-currency', 'convertible', 'missing-rate'},
      );

      final progress = await const BudgetProgressCalculator().calculate(
        budget: budget,
        transactions: transactions,
        now: DateTime.utc(2026, 7, 15),
        convertMoney: (money, toCurrency) async {
          if (money.currencyCode == 'USD' && toCurrency == 'LYD') {
            return AppResult.success(
              Money(
                amount: money.amount * Decimal.fromInt(2),
                currencyCode: toCurrency,
              ),
            );
          }
          return const AppResult.failure(
            Failure(message: 'Missing exchange rate.'),
          );
        },
      );
      expect(progress.spentAmount, Decimal.fromInt(20));
      expect(progress.missingRateWarnings, hasLength(1));
      expect(progress.missingRateWarnings.single.fromCurrencyCode, 'EUR');
      expect(progress.missingRateWarnings.single.toCurrencyCode, 'LYD');
    },
  );

  test('budget windows merge only overlapping periods per category', () {
    final request = BudgetTransactionWindowRequest(<BudgetTransactionWindow>[
      BudgetTransactionWindow(
        categoryId: 'food',
        start: DateTime.utc(2026, 1, 1),
        end: DateTime.utc(2026, 2, 1),
      ),
      BudgetTransactionWindow(
        categoryId: 'food',
        start: DateTime.utc(2026, 1, 15),
        end: DateTime.utc(2026, 3, 1),
      ),
      BudgetTransactionWindow(
        categoryId: 'travel',
        start: DateTime.utc(2026, 1, 15),
        end: DateTime.utc(2026, 3, 1),
      ),
    ]);

    expect(request.windows, hasLength(2));
    expect(request.windows.first.categoryId, 'food');
    expect(request.windows.first.start, DateTime.utc(2026, 1, 1));
    expect(request.windows.first.end, DateTime.utc(2026, 3, 1));
    expect(request, BudgetTransactionWindowRequest(request.windows.reversed));
  });

  test('budget window maps only contributing rows from long history', () async {
    final budget = _budget();
    await _seedTransactions(
      database,
      ownerScope: ownerScope,
      prefix: 'historical',
      count: 10000,
      start: DateTime.utc(2020, 1, 1),
    );
    await _seedTransactions(
      database,
      ownerScope: ownerScope,
      prefix: 'current',
      count: 20,
      start: DateTime.utc(2026, 7, 1),
    );
    await _seedTransactions(
      database,
      ownerScope: 'another-owner',
      prefix: 'other',
      count: 10,
      start: DateTime.utc(2026, 7, 1),
    );
    final request = BudgetTransactionWindowRequest.fromBudgets(
      budgets: <Budget>[budget],
      now: DateTime.utc(2026, 7, 15),
    );

    Future<int> loadFullHistory() async {
      final rows = await fullHistorySource.getTransactions();
      return rows.map((row) => row.toDomain()).toList(growable: false).length;
    }

    Future<int> loadWindow() async {
      final result = await readModel.watch(request).first;
      return _expectTransactions(result).length;
    }

    await loadFullHistory();
    await loadWindow();
    const repeatCount = 5;
    final beforeSamples = <int>[];
    final afterSamples = <int>[];
    var beforeRows = 0;
    var afterRows = 0;
    for (var repeat = 0; repeat < repeatCount; repeat++) {
      var stopwatch = Stopwatch()..start();
      beforeRows = await loadFullHistory();
      stopwatch.stop();
      beforeSamples.add(stopwatch.elapsedMicroseconds);

      stopwatch = Stopwatch()..start();
      afterRows = await loadWindow();
      stopwatch.stop();
      afterSamples.add(stopwatch.elapsedMicroseconds);
    }

    expect(beforeRows, 10020);
    expect(afterRows, 20);
    // ignore: avoid_print
    print(
      'budget_window_measurement: method=NativeDatabase.memory warmup=1 '
      'repeats=$repeatCount before_rows=$beforeRows after_rows=$afterRows '
      'before_samples_us=$beforeSamples after_samples_us=$afterSamples '
      'before_median_us=${_median(beforeSamples)} '
      'after_median_us=${_median(afterSamples)}',
    );
  });
}

Budget _budget() {
  return Budget.create(
    id: 'food-budget',
    name: 'Food',
    categoryId: 'food',
    amount: Decimal.fromInt(100),
    currency: 'LYD',
    periodType: BudgetPeriodType.custom,
    startDate: DateTime.utc(2026, 7, 1),
    endDate: DateTime.utc(2026, 8, 1),
  );
}

List<Transaction> _expectTransactions(AppResult<List<Transaction>> result) =>
    (result as AppSuccess<List<Transaction>>).data;

int _median(List<int> values) {
  final sorted = values.toList()..sort();
  return sorted[sorted.length ~/ 2];
}

Future<void> _seedTransactions(
  AppDatabase database, {
  required String ownerScope,
  required String prefix,
  required int count,
  required DateTime start,
}) {
  return database.batch((batch) {
    for (var index = 0; index < count; index++) {
      final at = start.add(Duration(minutes: index));
      batch.insert(
        database.transactions,
        _companion(
          ownerScope: ownerScope,
          id: '$prefix-$index',
          at: at,
          amount: '1',
        ),
      );
    }
  });
}

Future<void> _insertTransaction(
  AppDatabase database, {
  required String ownerScope,
  required String id,
  required DateTime at,
  required String amount,
  String currency = 'LYD',
  String type = 'expense',
  String status = 'posted',
}) {
  return database
      .into(database.transactions)
      .insert(
        _companion(
          ownerScope: ownerScope,
          id: id,
          at: at,
          amount: amount,
          currency: currency,
          type: type,
          status: status,
        ),
      );
}

TransactionsCompanion _companion({
  required String ownerScope,
  required String id,
  required DateTime at,
  required String amount,
  String currency = 'LYD',
  String type = 'expense',
  String status = 'posted',
}) {
  return TransactionsCompanion(
    id: Value(id),
    ownerScopeId: Value(ownerScope),
    accountId: const Value('account'),
    categoryId: const Value('food'),
    amount: Value(amount),
    currencyCode: Value(currency),
    type: Value(type),
    paymentMethod: const Value('cash'),
    source: const Value('manual'),
    status: Value(status),
    transactionDate: Value(at),
    createdAt: Value(at),
    updatedAt: Value(at),
  );
}
