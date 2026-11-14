import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/dashboard/data/expense_analytics_read_model.dart';
import 'package:cashpilot_ai/features/dashboard/domain/entities/expense_analytics.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  late AppDatabase database;
  late String ownerScope;
  late DriftExpenseAnalyticsReadModel readModel;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    final session = scopedTestSession(database);
    ownerScope = session.ownerScopeValue;
    readModel = DriftExpenseAnalyticsReadModel(session);
  });

  tearDown(() => database.close());

  test('discards an in-flight projection after owner invalidation', () async {
    final session = scopedTestSession(database);
    final pending = DriftExpenseAnalyticsReadModel(
      session,
    ).load(_monthlyQuery());
    session.invalidate();

    expect(await pending, isA<AppFailure<ExpenseAnalyticsSnapshot>>());
  });

  test(
    'includes the current stored second below a fractional cutoff',
    () async {
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'current-second',
        categoryId: 'food',
        amount: '12.125',
        date: DateTime.utc(2026, 8, 23, 12),
      );
      final query = _monthlyQuery();
      final snapshot = await _load(
        readModel,
        ExpenseAnalyticsQuery(
          baseCurrencyCode: query.baseCurrencyCode,
          ranges: ExpenseAnalyticsRanges(
            period: query.ranges.period,
            timeZoneName: query.ranges.timeZoneName,
            previous: query.ranges.previous,
            current: ExpenseAnalyticsDateRange(
              start: query.ranges.current.start,
              end: DateTime.utc(2026, 8, 23, 12, 0, 0, 500),
            ),
          ),
        ),
      );
      expect(snapshot.totalExpense, Decimal.parse('12.125'));
    },
  );

  test(
    'includes only posted owner expenses inside current and previous bounds',
    () async {
      await _insertCategory(database, ownerScope, 'food', 'Food', 'food');
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'current-posted',
        categoryId: 'food',
        amount: '10.125',
        date: DateTime.utc(2026, 8, 10),
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'current-boundary',
        categoryId: 'food',
        amount: '5',
        date: DateTime.utc(2026, 8),
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'previous-posted',
        categoryId: 'food',
        amount: '10',
        date: DateTime.utc(2026, 7, 10),
      );
      for (final excluded in <({String id, String type, String status})>[
        (id: 'pending', type: 'expense', status: 'pending'),
        (id: 'cancelled', type: 'expense', status: 'cancelled'),
        (id: 'income', type: 'income', status: 'posted'),
        (id: 'transfer', type: 'transferOut', status: 'posted'),
      ]) {
        await _insertTransaction(
          database,
          ownerScope: ownerScope,
          id: excluded.id,
          categoryId: 'food',
          amount: '500',
          date: DateTime.utc(2026, 8, 12),
          type: excluded.type,
          status: excluded.status,
        );
      }
      await _insertTransaction(
        database,
        ownerScope: 'another-owner',
        id: 'another-owner',
        categoryId: 'food',
        amount: '500',
        date: DateTime.utc(2026, 8, 12),
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'at-exclusive-end',
        categoryId: 'food',
        amount: '500',
        date: DateTime.utc(2026, 8, 23),
      );

      final snapshot = await _load(readModel, _monthlyQuery());

      expect(snapshot.totalExpense, Decimal.parse('15.125'));
      expect(snapshot.previousTotalExpense, Decimal.parse('10'));
      expect(snapshot.percentageChange, Decimal.parse('51.25'));
      expect(
        snapshot.comparisonDirection,
        ExpenseComparisonDirection.increased,
      );
      expect(snapshot.topCategories.single.amount, Decimal.parse('15.125'));
      expect(snapshot.metrics.sourceRowCount, 3);
    },
  );

  test('previous zero is safe and never produces a percentage', () async {
    await _insertTransaction(
      database,
      ownerScope: ownerScope,
      id: 'current',
      categoryId: 'food',
      amount: '9.999',
      date: DateTime.utc(2026, 8, 10),
    );
    await _insertTransaction(
      database,
      ownerScope: ownerScope,
      id: 'previous-zero',
      categoryId: 'food',
      amount: '0',
      date: DateTime.utc(2026, 7, 10),
    );

    final snapshot = await _load(readModel, _monthlyQuery());

    expect(snapshot.percentageChange, isNull);
    expect(
      snapshot.comparisonDirection,
      ExpenseComparisonDirection.noPreviousData,
    );
  });

  test(
    'returns top five and combines all remaining categories into Other',
    () async {
      for (var index = 0; index < 7; index++) {
        final categoryId = 'category-$index';
        await _insertCategory(
          database,
          ownerScope,
          categoryId,
          'Category $index',
          'shopping',
        );
        await _insertTransaction(
          database,
          ownerScope: ownerScope,
          id: 'expense-$index',
          categoryId: categoryId,
          amount: '${70 - (index * 10)}',
          date: DateTime.utc(2026, 8, 10),
        );
      }

      final snapshot = await _load(readModel, _monthlyQuery());
      final visualPercentageTotal =
          snapshot.topCategories.fold<Decimal>(
            Decimal.zero,
            (sum, item) => sum + item.percentage,
          ) +
          snapshot.otherPercentage;

      expect(snapshot.topCategories, hasLength(5));
      expect(snapshot.topCategories.first.amount, Decimal.parse('70'));
      expect(snapshot.topCategories.last.amount, Decimal.parse('30'));
      expect(snapshot.otherTotal, Decimal.parse('30'));
      expect(
        (visualPercentageTotal - Decimal.fromInt(100)).abs(),
        lessThan(Decimal.parse('0.000001')),
      );
    },
  );

  test(
    'preserves historical FX and exposes missing rates as partial data',
    () async {
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'lyd',
        categoryId: 'food',
        amount: '20.125',
        date: DateTime.utc(2026, 8, 10),
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'usd-missing',
        categoryId: 'food',
        amount: '10',
        currency: 'USD',
        date: DateTime.utc(2026, 8, 10),
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'eur-direct',
        categoryId: 'food',
        amount: '5',
        currency: 'EUR',
        fxFrom: 'EUR',
        fxTo: 'LYD',
        fxRate: '2',
        date: DateTime.utc(2026, 8, 10),
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'gbp-inverse',
        categoryId: 'food',
        amount: '4',
        currency: 'GBP',
        fxFrom: 'LYD',
        fxTo: 'GBP',
        fxRate: '0.2',
        date: DateTime.utc(2026, 8, 10),
      );

      final snapshot = await _load(readModel, _monthlyQuery());

      expect(snapshot.totalExpense, Decimal.parse('50.125'));
      expect(snapshot.isPartial, isTrue);
      expect(snapshot.warnings.single.fromCurrencyCode, 'USD');
      expect(snapshot.warnings.single.toCurrencyCode, 'LYD');
      expect(
        snapshot.comparisonDirection,
        ExpenseComparisonDirection.unavailable,
      );
    },
  );

  test(
    'monthly and category totals match the existing Reports snapshot',
    () async {
      await _insertCategory(database, ownerScope, 'food', 'Food', 'food');
      await _insertCategory(
        database,
        ownerScope,
        'transport',
        'Transport',
        'transport',
      );
      final at = DateTime.utc(2026, 8, 10);
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'lyd-food',
        categoryId: 'food',
        amount: '12.125',
        date: at,
      );
      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'usd-transport',
        categoryId: 'transport',
        amount: '5',
        currency: 'USD',
        fxFrom: 'USD',
        fxTo: 'LYD',
        fxRate: '2',
        date: at,
      );
      final categories = <Category>[
        _domainCategory('food', 'Food', 'food'),
        _domainCategory('transport', 'Transport', 'transport'),
      ];
      final transactions = <Transaction>[
        _domainExpense(
          id: 'lyd-food',
          categoryId: 'food',
          amount: '12.125',
          currency: 'LYD',
          date: at,
        ),
        _domainExpense(
          id: 'usd-transport',
          categoryId: 'transport',
          amount: '5',
          currency: 'USD',
          date: at,
          exchangeRate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'LYD',
            rate: Decimal.parse('2'),
            asOf: at,
          ),
        ),
      ];

      final analytics = await _load(readModel, _monthlyQuery());
      final reports = await DashboardSnapshot.from(
        accounts: const [],
        transactions: transactions,
        categories: categories,
        baseCurrencyCode: 'LYD',
        exchangeRateProvider: const SameCurrencyExchangeRateProvider(),
        now: DateTime.utc(2026, 8, 23),
      );

      expect(
        analytics.totalExpense,
        reports.monthlyExpenseByCurrency.single.amount,
      );
      expect(
        {
          for (final item in analytics.topCategories)
            item.categoryId: item.amount,
        },
        {
          for (final item in reports.spendingByCategory)
            item.categoryId: item.amount,
        },
      );
      expect(reports.netWorthInBaseCurrency.amount, Decimal.zero);
    },
  );

  test(
    'watched projection refreshes after transaction and rate mutations',
    () async {
      final iterator = StreamIterator(readModel.watch(_monthlyQuery()));
      addTearDown(iterator.cancel);

      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current as AppSuccess<ExpenseAnalyticsSnapshot>)
            .data
            .totalExpense,
        Decimal.zero,
      );

      await _insertTransaction(
        database,
        ownerScope: ownerScope,
        id: 'new-expense',
        categoryId: 'food',
        amount: '12',
        date: DateTime.utc(2026, 8, 10),
      );
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current as AppSuccess<ExpenseAnalyticsSnapshot>)
            .data
            .totalExpense,
        Decimal.parse('12'),
      );

      final at = DateTime.utc(2026, 8, 10);
      await database
          .into(database.exchangeRates)
          .insert(
            ExchangeRatesCompanion(
              id: const Value('rate'),
              ownerScopeId: Value(ownerScope),
              baseCurrency: const Value('LYD'),
              quoteCurrency: const Value('USD'),
              rate: const Value('0.2'),
              source: const Value('manual'),
              fetchedAt: Value(at),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      expect(await iterator.moveNext(), isTrue);
      expect(
        (iterator.current as AppSuccess<ExpenseAnalyticsSnapshot>)
            .data
            .totalExpense,
        Decimal.parse('12'),
        reason: 'Latest mutable FX must not rewrite historical transaction FX.',
      );
    },
  );

  test('10k mixed rows remain one bounded aggregate projection', () async {
    final at = DateTime.utc(2026, 8, 10);
    await database.batch((batch) {
      for (var index = 0; index < 10000; index++) {
        final variant = index % 10;
        final status = switch (variant) {
          1 => 'pending',
          2 => 'cancelled',
          _ => 'posted',
        };
        final type = switch (variant) {
          3 => 'income',
          4 => 'transferOut',
          _ => 'expense',
        };
        final currency = variant == 5 || variant == 6 ? 'USD' : 'LYD';
        final hasFx = variant == 6;
        final date = index.isEven ? at : DateTime.utc(2026, 7, 10);
        batch.insert(
          database.transactions,
          TransactionsCompanion(
            id: Value('bulk-$index'),
            ownerScopeId: Value(ownerScope),
            accountId: const Value('account'),
            categoryId: Value('category-${index % 7}'),
            amount: Value('${(index % 5) + 1}.125'),
            currencyCode: Value(currency),
            type: Value(type),
            paymentMethod: const Value('cash'),
            source: const Value('manual'),
            status: Value(status),
            exchangeRateFromCurrencyCode: Value(hasFx ? 'USD' : null),
            exchangeRateToCurrencyCode: Value(hasFx ? 'LYD' : null),
            exchangeRate: Value(hasFx ? '2' : null),
            transactionDate: Value(date),
            createdAt: Value(date),
            updatedAt: Value(date),
          ),
        );
      }
    });

    final stopwatch = Stopwatch()..start();
    final snapshot = await _load(readModel, _monthlyQuery());
    stopwatch.stop();

    expect(snapshot.metrics.sourceRowCount, 6000);
    expect(snapshot.metrics.aggregateRowCount, lessThan(500));
    expect(snapshot.isPartial, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    // ignore: avoid_print
    print(
      'expense_analytics_10k: source_rows=${snapshot.metrics.sourceRowCount} '
      'aggregate_rows=${snapshot.metrics.aggregateRowCount} '
      'duration_us=${stopwatch.elapsedMicroseconds}',
    );
  });
}

ExpenseAnalyticsQuery _monthlyQuery() {
  return ExpenseAnalyticsQuery(
    ranges: ExpenseAnalyticsRanges(
      period: ExpenseAnalyticsPeriod.month,
      current: ExpenseAnalyticsDateRange(
        start: DateTime.utc(2026, 8),
        end: DateTime.utc(2026, 8, 23),
      ),
      previous: ExpenseAnalyticsDateRange(
        start: DateTime.utc(2026, 7),
        end: DateTime.utc(2026, 8),
      ),
      timeZoneName: 'Africa/Tripoli',
    ),
    baseCurrencyCode: 'LYD',
  );
}

Future<ExpenseAnalyticsSnapshot> _load(
  DriftExpenseAnalyticsReadModel readModel,
  ExpenseAnalyticsQuery query,
) async {
  final result = await readModel.load(query);
  expect(result, isA<AppSuccess<ExpenseAnalyticsSnapshot>>());
  return (result as AppSuccess<ExpenseAnalyticsSnapshot>).data;
}

Future<void> _insertCategory(
  AppDatabase database,
  String ownerScope,
  String id,
  String name,
  String icon,
) {
  final at = DateTime.utc(2026);
  return database
      .into(database.categories)
      .insert(
        CategoriesCompanion(
          id: Value(id),
          ownerScopeId: Value(ownerScope),
          name: Value(name),
          type: const Value('expense'),
          icon: Value(icon),
          color: Value(0xFF5B4CF0 + id.length),
          isDefault: const Value(false),
          isArchived: const Value(false),
          sortOrder: const Value(0),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
}

Future<void> _insertTransaction(
  AppDatabase database, {
  required String ownerScope,
  required String id,
  required String categoryId,
  required String amount,
  required DateTime date,
  String currency = 'LYD',
  String type = 'expense',
  String status = 'posted',
  String? fxFrom,
  String? fxTo,
  String? fxRate,
}) {
  return database
      .into(database.transactions)
      .insert(
        TransactionsCompanion(
          id: Value(id),
          ownerScopeId: Value(ownerScope),
          accountId: const Value('account'),
          categoryId: Value(categoryId),
          amount: Value(amount),
          currencyCode: Value(currency),
          type: Value(type),
          paymentMethod: const Value('cash'),
          source: const Value('manual'),
          status: Value(status),
          exchangeRateFromCurrencyCode: Value(fxFrom),
          exchangeRateToCurrencyCode: Value(fxTo),
          exchangeRate: Value(fxRate),
          transactionDate: Value(date),
          createdAt: Value(date),
          updatedAt: Value(date),
        ),
      );
}

Category _domainCategory(String id, String name, String icon) {
  return Category.create(
    id: id,
    name: name,
    type: CategoryType.expense,
    icon: CategoryIcon(key: icon),
    color: const CategoryColor(argb: 0xFF5B4CF0),
  );
}

Transaction _domainExpense({
  required String id,
  required String categoryId,
  required String amount,
  required String currency,
  required DateTime date,
  ExchangeRate? exchangeRate,
}) {
  return Transaction.create(
    id: id,
    accountId: 'account',
    categoryId: categoryId,
    amount: Money(amount: Decimal.parse(amount), currencyCode: currency),
    type: TransactionType.expense,
    exchangeRate: exchangeRate,
    transactionDate: date,
  );
}
