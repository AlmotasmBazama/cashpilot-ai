import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../domain/entities/expense_analytics.dart';
import '../domain/repositories/expense_analytics_repository.dart';

/// Owner-scoped, exact-decimal projection for the Home expense card.
///
/// SQLite groups identical decimal-string/FX/category values and returns their
/// counts. Dart then performs the financial arithmetic with [Decimal]. This
/// avoids loading full transaction entities without ever casting money to a
/// SQLite floating-point type.
final class DriftExpenseAnalyticsReadModel
    implements ExpenseAnalyticsRepository {
  const DriftExpenseAnalyticsReadModel(this._session);

  final ScopedAppDatabaseSession _session;

  @override
  Stream<AppResult<ExpenseAnalyticsSnapshot>> watch(
    ExpenseAnalyticsQuery query,
  ) async* {
    try {
      final select = _select(query);
      await for (final rows in _session.guardStream(select.watch())) {
        final stopwatch = Stopwatch()..start();
        yield AppResult.success(_buildSnapshot(rows, query, stopwatch));
      }
    } on Object {
      yield const AppResult.failure(
        Failure(
          message: 'Unable to load expense analytics.',
          code: 'expense-analytics-load-failed',
        ),
      );
    }
  }

  @override
  Future<AppResult<ExpenseAnalyticsSnapshot>> load(
    ExpenseAnalyticsQuery query,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final rows = await _select(query).get();
      _session.assertActive();
      return AppResult.success(_buildSnapshot(rows, query, stopwatch));
    } on Object {
      return const AppResult.failure(
        Failure(
          message: 'Unable to load expense analytics.',
          code: 'expense-analytics-load-failed',
        ),
      );
    }
  }

  Selectable<QueryRow> _select(ExpenseAnalyticsQuery query) {
    final database = _session.database;
    final ownerScope = _session.ownerScopeValue;
    return database.customSelect(
      '''
        SELECT
          CASE WHEN t.transaction_date >= ? THEN 0 ELSE 1 END AS period_index,
          t.category_id AS category_id,
          COALESCE(c.name, t.category_id) AS category_name,
          COALESCE(c.icon, 'other') AS category_icon,
          c.color AS category_color,
          COALESCE(c.is_default, 0) AS category_is_default,
          t.amount AS amount,
          UPPER(t.currency_code) AS currency_code,
          t.exchange_rate_from_currency_code AS fx_from,
          t.exchange_rate_to_currency_code AS fx_to,
          t.exchange_rate AS fx_rate,
          COUNT(*) AS row_count
        FROM transactions AS t
        LEFT JOIN categories AS c
          ON c.id = t.category_id
          AND (c.owner_scope_id IS NULL OR c.owner_scope_id = ?)
        WHERE t.owner_scope_id = ?
          AND t.type = 'expense'
          AND t.status = 'posted'
          AND t.transaction_date >= ?
          AND t.transaction_date < ?
        GROUP BY
          period_index,
          t.category_id,
          category_name,
          category_icon,
          category_color,
          category_is_default,
          t.amount,
          currency_code,
          fx_from,
          fx_to,
          fx_rate
        ORDER BY period_index, t.category_id
      ''',
      variables: <Variable<Object>>[
        Variable<DateTime>(query.ranges.current.start.toUtc()),
        Variable<String>(ownerScope),
        Variable<String>(ownerScope),
        Variable<DateTime>(query.ranges.previous.start.toUtc()),
        // Drift stores DateTime as whole Unix seconds. Rounding the exclusive
        // upper bound down would omit expenses in the current partial second.
        Variable<int>(
          (query.ranges.current.end.toUtc().microsecondsSinceEpoch /
                  Duration.microsecondsPerSecond)
              .ceil(),
        ),
      ],
      readsFrom: <ResultSetImplementation<Table, Object?>>{
        database.transactions,
        database.categories,
        // Reports intentionally use persisted transaction FX. Watching this
        // table still refreshes partial-state diagnostics after rate edits.
        database.exchangeRates,
      },
    );
  }

  ExpenseAnalyticsSnapshot _buildSnapshot(
    List<QueryRow> rows,
    ExpenseAnalyticsQuery query,
    Stopwatch stopwatch,
  ) {
    final baseCurrencyCode = query.baseCurrencyCode.trim().toUpperCase();
    final categoryTotals = <String, _CategoryAccumulator>{};
    final warnings = <String, ExpenseAnalyticsWarning>{};
    var currentTotal = Decimal.zero;
    var previousTotal = Decimal.zero;
    var currentSourceRowCount = 0;
    var previousSourceRowCount = 0;

    for (final row in rows) {
      final periodIndex = row.read<int>('period_index');
      final rowCount = row.read<int>('row_count');
      if (periodIndex == 0) {
        currentSourceRowCount += rowCount;
      } else {
        previousSourceRowCount += rowCount;
      }

      final conversion = _convertGroup(
        row,
        rowCount: rowCount,
        baseCurrencyCode: baseCurrencyCode,
      );
      final warning = conversion.warning;
      if (warning != null) {
        warnings[warning.key] = warning;
      }
      final convertedAmount = conversion.amount;
      if (convertedAmount == null) {
        continue;
      }

      if (periodIndex == 0) {
        currentTotal += convertedAmount;
        final categoryId = row.read<String>('category_id');
        final category = categoryTotals.putIfAbsent(
          categoryId,
          () => _CategoryAccumulator(
            categoryId: categoryId,
            categoryName: row.read<String>('category_name'),
            categoryIconKey: row.read<String>('category_icon'),
            categoryColorArgb:
                row.readNullable<int>('category_color') ??
                _fallbackCategoryColor(categoryId),
            isDefaultCategory: row.read<int>('category_is_default') == 1,
          ),
        );
        category.amount += convertedAmount;
      } else {
        previousTotal += convertedAmount;
      }
    }

    final sortedCategories = categoryTotals.values.toList(growable: false)
      ..sort((left, right) {
        final byAmount = right.amount.compareTo(left.amount);
        return byAmount != 0
            ? byAmount
            : left.categoryId.compareTo(right.categoryId);
      });
    final leadingCategories = sortedCategories.take(5).toList(growable: false);
    final otherTotal = sortedCategories
        .skip(5)
        .fold(Decimal.zero, (sum, category) => sum + category.amount);
    final topCategories = leadingCategories
        .map(
          (category) => ExpenseCategoryAnalytics(
            categoryId: category.categoryId,
            categoryName: category.categoryName,
            categoryIconKey: category.categoryIconKey,
            categoryColorArgb: category.categoryColorArgb,
            isDefaultCategory: category.isDefaultCategory,
            amount: category.amount,
            percentage: _percentage(category.amount, currentTotal),
          ),
        )
        .toList(growable: false);
    final comparison = _comparison(
      currentTotal: currentTotal,
      previousTotal: previousTotal,
      previousSourceRowCount: previousSourceRowCount,
      isPartial: warnings.isNotEmpty,
    );
    stopwatch.stop();

    return ExpenseAnalyticsSnapshot(
      selectedPeriod: query.ranges.period,
      currentDateRange: query.ranges.current,
      previousDateRange: query.ranges.previous,
      totalExpense: currentTotal,
      previousTotalExpense: previousTotal,
      percentageChange: comparison.percentageChange,
      comparisonDirection: comparison.direction,
      topCategories: topCategories,
      otherTotal: otherTotal,
      otherPercentage: _percentage(otherTotal, currentTotal),
      currencyCode: baseCurrencyCode,
      isPartial: warnings.isNotEmpty,
      warnings: warnings.values.toList(growable: false),
      hasCurrentExpenses: currentSourceRowCount > 0,
      metrics: ExpenseAnalyticsQueryMetrics(
        sourceRowCount: currentSourceRowCount + previousSourceRowCount,
        aggregateRowCount: rows.length,
        processingDuration: stopwatch.elapsed,
      ),
    );
  }

  ({Decimal? amount, ExpenseAnalyticsWarning? warning}) _convertGroup(
    QueryRow row, {
    required int rowCount,
    required String baseCurrencyCode,
  }) {
    final sourceCurrency = row.read<String>('currency_code').toUpperCase();
    final unitAmount = Decimal.parse(row.read<String>('amount'));
    final count = Decimal.fromInt(rowCount);
    if (sourceCurrency == baseCurrencyCode) {
      return (amount: unitAmount * count, warning: null);
    }

    final fxFrom = row.readNullable<String>('fx_from')?.toUpperCase();
    final fxTo = row.readNullable<String>('fx_to')?.toUpperCase();
    final fxRateText = row.readNullable<String>('fx_rate');
    final fxRate = fxRateText == null ? null : Decimal.tryParse(fxRateText);
    if (fxRate == null || fxRate <= Decimal.zero) {
      return (
        amount: null,
        warning: ExpenseAnalyticsWarning(
          fromCurrencyCode: sourceCurrency,
          toCurrencyCode: baseCurrencyCode,
        ),
      );
    }
    if (fxFrom == sourceCurrency && fxTo == baseCurrencyCode) {
      return (amount: unitAmount * fxRate * count, warning: null);
    }
    if (fxTo == sourceCurrency && fxFrom == baseCurrencyCode) {
      final convertedUnit = (unitAmount / fxRate).toDecimal(
        scaleOnInfinitePrecision: 12,
      );
      return (amount: convertedUnit * count, warning: null);
    }
    return (
      amount: null,
      warning: ExpenseAnalyticsWarning(
        fromCurrencyCode: sourceCurrency,
        toCurrencyCode: baseCurrencyCode,
      ),
    );
  }

  Decimal _percentage(Decimal amount, Decimal total) {
    if (total == Decimal.zero) {
      return Decimal.zero;
    }
    return ((amount * Decimal.fromInt(100)) / total).toDecimal(
      scaleOnInfinitePrecision: 12,
    );
  }

  ({ExpenseComparisonDirection direction, Decimal? percentageChange})
  _comparison({
    required Decimal currentTotal,
    required Decimal previousTotal,
    required int previousSourceRowCount,
    required bool isPartial,
  }) {
    if (isPartial) {
      return (
        direction: ExpenseComparisonDirection.unavailable,
        percentageChange: null,
      );
    }
    if (previousSourceRowCount == 0 || previousTotal == Decimal.zero) {
      return (
        direction: ExpenseComparisonDirection.noPreviousData,
        percentageChange: null,
      );
    }
    final change =
        (((currentTotal - previousTotal) * Decimal.fromInt(100)) /
                previousTotal)
            .toDecimal(scaleOnInfinitePrecision: 12);
    final direction = switch (change.compareTo(Decimal.zero)) {
      > 0 => ExpenseComparisonDirection.increased,
      < 0 => ExpenseComparisonDirection.decreased,
      _ => ExpenseComparisonDirection.unchanged,
    };
    return (direction: direction, percentageChange: change);
  }
}

final class _CategoryAccumulator {
  _CategoryAccumulator({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIconKey,
    required this.categoryColorArgb,
    required this.isDefaultCategory,
  });

  final String categoryId;
  final String categoryName;
  final String categoryIconKey;
  final int categoryColorArgb;
  final bool isDefaultCategory;
  Decimal amount = Decimal.zero;
}

int _fallbackCategoryColor(String categoryId) {
  const colors = <int>[
    0xFF5B4CF0,
    0xFF14B8A6,
    0xFF3B82F6,
    0xFFF59E0B,
    0xFFEC4899,
    0xFF7C3AED,
  ];
  final seed = categoryId.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return colors[seed % colors.length];
}
