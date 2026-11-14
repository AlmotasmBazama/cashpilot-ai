import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../accounts/application/providers/accounts_providers.dart';
import '../../accounts/domain/entities/account.dart';
import '../../categories/application/providers/categories_providers.dart';
import '../../categories/domain/entities/category.dart';
import '../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../finance_engine/domain/repositories/exchange_rate_provider.dart';
import '../../finance_engine/domain/services/balance_calculator.dart';
import '../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../finance_engine/domain/value_objects/money.dart';
import '../../exchange_rates/application/base_currency_provider.dart';
import '../../transactions/transactions.dart'
    show transactionRowDomainMapperProvider;
import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/domain/enums/transaction_status.dart';
import '../../transactions/domain/enums/transaction_type.dart';
import '../../income_sources/domain/services/income_reporting_policy.dart';
import '../data/dashboard_transactions_read_model.dart';

final dashboardExchangeRateProvider = Provider<ExchangeRateProvider>(
  (ref) => ref.watch(storedExchangeRateProvider),
  name: 'dashboardExchangeRateProvider',
);

final dashboardTransactionsReadModelProvider =
    Provider<DashboardTransactionsReadModel>(
      (ref) => DashboardTransactionsReadModel(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
        ref.watch(transactionRowDomainMapperProvider),
      ),
      name: 'dashboardTransactionsReadModelProvider',
    );

final dashboardTransactionsProvider =
    StreamProvider<AppResult<List<Transaction>>>((ref) {
      return ref
          .watch(dashboardTransactionsReadModelProvider)
          .watch(
            reportingWindowStart: dashboardReportingWindowStart(DateTime.now()),
          );
    }, name: 'dashboardTransactionsProvider');

final dashboardSnapshotProvider = FutureProvider<AppResult<DashboardSnapshot>>((
  ref,
) async {
  final accountsResult = await ref.watch(accountsProvider.future);
  final transactionsResult = switch (ref.watch(dashboardTransactionsProvider)) {
    AsyncData(:final value) => value,
    _ => await ref.watch(dashboardTransactionsProvider.future),
  };
  final categoriesResult = await ref.watch(categoriesProvider.future);
  final baseCurrencyCode = ref.watch(effectiveBaseCurrencyCodeProvider);
  final exchangeRateProvider = ref.watch(dashboardExchangeRateProvider);

  switch ((accountsResult, transactionsResult, categoriesResult)) {
    case (AppFailure<List<Account>>(:final failure), _, _):
      return AppResult.failure(failure);
    case (_, AppFailure<List<Transaction>>(:final failure), _):
      return AppResult.failure(failure);
    case (_, _, AppFailure<List<Category>>(:final failure)):
      return AppResult.failure(failure);
    case (
      AppSuccess<List<Account>>(data: final accounts),
      AppSuccess<List<Transaction>>(data: final transactions),
      AppSuccess<List<Category>>(data: final categories),
    ):
      return AppResult.success(
        await DashboardSnapshot.from(
          accounts: accounts,
          transactions: transactions,
          categories: categories,
          baseCurrencyCode: baseCurrencyCode,
          exchangeRateProvider: exchangeRateProvider,
          now: DateTime.now().toUtc(),
          totalTransactionCount: transactions is DashboardTransactionWindow
              ? transactions.totalTransactionCount
              : transactions.length,
        ),
      );
  }
}, name: 'dashboardSnapshotProvider');

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.accounts,
    required this.transactions,
    required this.categories,
    required this.baseCurrencyCode,
    required this.netWorthInBaseCurrency,
    required this.unconvertedNetWorthByCurrency,
    required this.netWorthByCurrency,
    required this.monthlyIncomeByCurrency,
    required this.monthlyExpenseByCurrency,
    required this.monthlySavingsByCurrency,
    required this.yearlyIncomeByCurrency,
    required this.yearlyExpenseByCurrency,
    required this.yearlySavingsByCurrency,
    required this.recentTransactions,
    required this.spendingByCategory,
    required this.monthlyExpenseTrend,
    required this.missingExchangeRatePairs,
    int? totalTransactionCount,
  }) : _totalTransactionCount = totalTransactionCount;

  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Category> categories;
  final String baseCurrencyCode;
  final CurrencyTotal netWorthInBaseCurrency;
  final List<CurrencyTotal> unconvertedNetWorthByCurrency;
  final List<CurrencyTotal> netWorthByCurrency;
  final List<CurrencyTotal> monthlyIncomeByCurrency;
  final List<CurrencyTotal> monthlyExpenseByCurrency;
  final List<CurrencyTotal> monthlySavingsByCurrency;
  final List<CurrencyTotal> yearlyIncomeByCurrency;
  final List<CurrencyTotal> yearlyExpenseByCurrency;
  final List<CurrencyTotal> yearlySavingsByCurrency;
  final List<Transaction> recentTransactions;
  final List<CategorySpendingTotal> spendingByCategory;
  final List<Decimal> monthlyExpenseTrend;
  final List<MissingExchangeRatePair> missingExchangeRatePairs;
  final int? _totalTransactionCount;

  int get totalTransactionCount =>
      _totalTransactionCount ?? transactions.length;

  bool get hasAccounts => accounts.isNotEmpty;
  bool get hasTransactions => totalTransactionCount > 0;
  bool get isPartial => missingExchangeRatePairs.isNotEmpty;

  static Future<DashboardSnapshot> from({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required List<Category> categories,
    required String baseCurrencyCode,
    required ExchangeRateProvider exchangeRateProvider,
    required DateTime now,
    int? totalTransactionCount,
  }) async {
    final normalizedBase = baseCurrencyCode.toUpperCase();
    final resolver = _SnapshotRateResolver(exchangeRateProvider);
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final posted = transactions
        .where((transaction) => transaction.status == TransactionStatus.posted)
        .toList(growable: false);
    final localNow = now.toLocal();
    final currentMonth = posted
        .where((transaction) {
          final date = transaction.transactionDate.toLocal();
          return date.year == localNow.year && date.month == localNow.month;
        })
        .toList(growable: false);
    final currentYear = posted
        .where(
          (transaction) =>
              transaction.transactionDate.toLocal().year == localNow.year,
        )
        .toList(growable: false);

    final monthlyIncomeTransactions = currentMonth
        .where(IncomeReportingPolicy.isNormalIncome)
        .toList(growable: false);
    final monthlyExpenseTransactions = currentMonth
        .where((transaction) => transaction.type == TransactionType.expense)
        .toList(growable: false);
    final yearlyIncomeTransactions = currentYear
        .where(IncomeReportingPolicy.isNormalIncome)
        .toList(growable: false);
    final yearlyExpenseTransactions = currentYear
        .where((transaction) => transaction.type == TransactionType.expense)
        .toList(growable: false);

    final netWorth = _sumAccounts(accounts);
    final netWorthConversion = await _sumAccountsInBaseCurrency(
      accounts: accounts,
      baseCurrencyCode: normalizedBase,
      resolver: resolver,
    );
    final monthlyIncome = await _sumTransactionsInBaseCurrency(
      transactions: monthlyIncomeTransactions,
      baseCurrencyCode: normalizedBase,
      resolver: resolver,
    );
    final monthlyExpense = await _sumTransactionsInBaseCurrency(
      transactions: monthlyExpenseTransactions,
      baseCurrencyCode: normalizedBase,
      resolver: resolver,
    );
    final yearlyIncome = await _sumTransactionsInBaseCurrency(
      transactions: yearlyIncomeTransactions,
      baseCurrencyCode: normalizedBase,
      resolver: resolver,
    );
    final yearlyExpense = await _sumTransactionsInBaseCurrency(
      transactions: yearlyExpenseTransactions,
      baseCurrencyCode: normalizedBase,
      resolver: resolver,
    );
    final categoryResult = await _spendingByCategory(
      transactions: monthlyExpenseTransactions,
      categoryById: categoryById,
      baseCurrencyCode: normalizedBase,
      resolver: resolver,
    );
    final trendResult = await _expenseTrend(
      transactions: posted,
      now: now,
      baseCurrencyCode: normalizedBase,
      resolver: resolver,
    );
    final missingPairs = <String, MissingExchangeRatePair>{};
    for (final result in <_ConversionSummary>[
      netWorthConversion,
      monthlyIncome,
      monthlyExpense,
      yearlyIncome,
      yearlyExpense,
      categoryResult.summary,
      trendResult.summary,
    ]) {
      for (final pair in result.missingPairs) {
        missingPairs[pair.key] = pair;
      }
    }
    final recent = [...transactions]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    return DashboardSnapshot(
      accounts: accounts,
      transactions: transactions,
      categories: categories,
      baseCurrencyCode: normalizedBase,
      netWorthInBaseCurrency: CurrencyTotal(
        currencyCode: normalizedBase,
        amount: netWorthConversion.total,
      ),
      unconvertedNetWorthByCurrency: _totalsFromMap(
        netWorthConversion.unconvertedTotals,
      ),
      netWorthByCurrency: _totalsFromMap(netWorth),
      monthlyIncomeByCurrency: _singleConvertedTotal(
        monthlyIncome,
        hasValues: monthlyIncomeTransactions.isNotEmpty,
        currencyCode: normalizedBase,
      ),
      monthlyExpenseByCurrency: _singleConvertedTotal(
        monthlyExpense,
        hasValues: monthlyExpenseTransactions.isNotEmpty,
        currencyCode: normalizedBase,
      ),
      monthlySavingsByCurrency: _savingsTotal(
        income: monthlyIncome,
        expense: monthlyExpense,
        hasValues:
            monthlyIncomeTransactions.isNotEmpty ||
            monthlyExpenseTransactions.isNotEmpty,
        currencyCode: normalizedBase,
      ),
      yearlyIncomeByCurrency: _singleConvertedTotal(
        yearlyIncome,
        hasValues: yearlyIncomeTransactions.isNotEmpty,
        currencyCode: normalizedBase,
      ),
      yearlyExpenseByCurrency: _singleConvertedTotal(
        yearlyExpense,
        hasValues: yearlyExpenseTransactions.isNotEmpty,
        currencyCode: normalizedBase,
      ),
      yearlySavingsByCurrency: _savingsTotal(
        income: yearlyIncome,
        expense: yearlyExpense,
        hasValues:
            yearlyIncomeTransactions.isNotEmpty ||
            yearlyExpenseTransactions.isNotEmpty,
        currencyCode: normalizedBase,
      ),
      recentTransactions: recent.take(5).toList(growable: false),
      spendingByCategory: categoryResult.items,
      monthlyExpenseTrend: trendResult.values,
      missingExchangeRatePairs: missingPairs.values.toList(growable: false),
      totalTransactionCount: totalTransactionCount,
    );
  }

  static Map<String, Decimal> _sumAccounts(List<Account> accounts) {
    final totals = <String, Decimal>{};
    for (final account in accounts) {
      final currencyCode = account.currencyCode.toUpperCase();
      totals[currencyCode] =
          (totals[currencyCode] ?? Decimal.zero) + account.balance;
    }
    return totals;
  }

  static Future<_ConversionSummary> _sumAccountsInBaseCurrency({
    required List<Account> accounts,
    required String baseCurrencyCode,
    required _SnapshotRateResolver resolver,
  }) async {
    final summary = _ConversionSummary();
    for (final account in accounts) {
      final money = Money(
        amount: account.balance,
        currencyCode: account.currencyCode.toUpperCase(),
      );
      final converted = await resolver.convertMoney(money, baseCurrencyCode);
      summary.add(converted, original: money);
    }
    return summary;
  }

  static Future<_ConversionSummary> _sumTransactionsInBaseCurrency({
    required List<Transaction> transactions,
    required String baseCurrencyCode,
    required _SnapshotRateResolver resolver,
  }) async {
    final summary = _ConversionSummary();
    for (final transaction in transactions) {
      final converted = await resolver.convertTransaction(
        transaction,
        baseCurrencyCode,
      );
      summary.add(converted, original: transaction.amount);
    }
    return summary;
  }

  static Future<_CategoryConversionResult> _spendingByCategory({
    required List<Transaction> transactions,
    required Map<String, Category> categoryById,
    required String baseCurrencyCode,
    required _SnapshotRateResolver resolver,
  }) async {
    final totals = <String, CategorySpendingTotal>{};
    final summary = _ConversionSummary();
    for (final transaction in transactions) {
      final converted = await resolver.convertTransaction(
        transaction,
        baseCurrencyCode,
      );
      summary.add(converted, original: transaction.amount);
      if (converted.amount == null) {
        continue;
      }
      final category = categoryById[transaction.categoryId];
      final existing = totals[transaction.categoryId];
      totals[transaction.categoryId] = CategorySpendingTotal(
        categoryId: transaction.categoryId,
        categoryName: category?.name ?? transaction.categoryId,
        currencyCode: baseCurrencyCode,
        amount: (existing?.amount ?? Decimal.zero) + converted.amount!,
      );
    }
    final items = totals.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return _CategoryConversionResult(
      items: items.take(5).toList(growable: false),
      summary: summary,
    );
  }

  static Future<_TrendConversionResult> _expenseTrend({
    required List<Transaction> transactions,
    required DateTime now,
    required String baseCurrencyCode,
    required _SnapshotRateResolver resolver,
  }) async {
    final values = List<Decimal>.filled(6, Decimal.zero);
    final summary = _ConversionSummary();
    for (var index = 0; index < 6; index++) {
      final month = DateTime.utc(now.year, now.month - (5 - index));
      final matching = transactions.where((transaction) {
        final date = transaction.transactionDate.toUtc();
        return date.year == month.year &&
            date.month == month.month &&
            transaction.type == TransactionType.expense;
      });
      for (final transaction in matching) {
        final converted = await resolver.convertTransaction(
          transaction,
          baseCurrencyCode,
        );
        summary.add(converted, original: transaction.amount);
        if (converted.amount != null) {
          values[index] += converted.amount!;
        }
      }
    }
    return _TrendConversionResult(values: values, summary: summary);
  }

  static List<CurrencyTotal> _totalsFromMap(Map<String, Decimal> totals) {
    final items = totals.entries
        .map(
          (entry) =>
              CurrencyTotal(currencyCode: entry.key, amount: entry.value),
        )
        .toList();
    items.sort((a, b) => a.currencyCode.compareTo(b.currencyCode));
    return items;
  }

  static List<CurrencyTotal> _singleConvertedTotal(
    _ConversionSummary summary, {
    required bool hasValues,
    required String currencyCode,
  }) {
    return hasValues
        ? <CurrencyTotal>[
            CurrencyTotal(currencyCode: currencyCode, amount: summary.total),
          ]
        : const <CurrencyTotal>[];
  }

  static List<CurrencyTotal> _savingsTotal({
    required _ConversionSummary income,
    required _ConversionSummary expense,
    required bool hasValues,
    required String currencyCode,
  }) {
    return hasValues
        ? <CurrencyTotal>[
            CurrencyTotal(
              currencyCode: currencyCode,
              amount: income.total - expense.total,
            ),
          ]
        : const <CurrencyTotal>[];
  }
}

class _SnapshotRateResolver {
  _SnapshotRateResolver(this._provider);

  final ExchangeRateProvider _provider;
  final Map<String, Future<ExchangeRate?>> _cache =
      <String, Future<ExchangeRate?>>{};

  Future<_AmountConversion> convertMoney(Money money, String toCurrency) async {
    final from = money.currencyCode.toUpperCase();
    final to = toCurrency.toUpperCase();
    if (from == to) {
      return _AmountConversion(amount: money.amount);
    }
    final rate = await _rate(from, to);
    if (rate == null) {
      return _AmountConversion(missingPair: MissingExchangeRatePair(from, to));
    }
    return _AmountConversion(
      amount: const BalanceCalculator().convert(money, rate).amount,
    );
  }

  Future<_AmountConversion> convertTransaction(
    Transaction transaction,
    String toCurrency,
  ) async {
    final from = transaction.amount.currencyCode.toUpperCase();
    final to = toCurrency.toUpperCase();
    if (from == to) {
      return _AmountConversion(amount: transaction.amount.amount);
    }
    final historical = transaction.exchangeRate;
    if (historical != null && historical.rate > Decimal.zero) {
      final historicalFrom = historical.fromCurrencyCode.toUpperCase();
      final historicalTo = historical.toCurrencyCode.toUpperCase();
      if (historicalFrom == from && historicalTo == to) {
        return _AmountConversion(
          amount: transaction.amount.amount * historical.rate,
        );
      }
      if (historicalTo == from && historicalFrom == to) {
        return _AmountConversion(
          amount: (transaction.amount.amount / historical.rate).toDecimal(
            scaleOnInfinitePrecision: 12,
          ),
        );
      }
    }

    // A mutable latest rate must never rewrite a historical report. Legacy or
    // imported rows without persisted FX remain visibly partial until a dated
    // rate is attached to the transaction.
    return _AmountConversion(missingPair: MissingExchangeRatePair(from, to));
  }

  Future<ExchangeRate?> _rate(String from, String to) {
    final key = '$from->$to';
    return _cache.putIfAbsent(key, () async {
      try {
        return await _provider.getExchangeRate(
          fromCurrencyCode: from,
          toCurrencyCode: to,
        );
      } on Object {
        return null;
      }
    });
  }
}

class _ConversionSummary {
  Decimal total = Decimal.zero;
  final Map<String, Decimal> unconvertedTotals = <String, Decimal>{};
  final Map<String, MissingExchangeRatePair> _missingPairs =
      <String, MissingExchangeRatePair>{};

  Iterable<MissingExchangeRatePair> get missingPairs => _missingPairs.values;

  void add(_AmountConversion conversion, {required Money original}) {
    final amount = conversion.amount;
    if (amount != null) {
      total += amount;
      return;
    }
    final currency = original.currencyCode.toUpperCase();
    unconvertedTotals[currency] =
        (unconvertedTotals[currency] ?? Decimal.zero) + original.amount;
    final pair = conversion.missingPair;
    if (pair != null) {
      _missingPairs[pair.key] = pair;
    }
  }
}

class _AmountConversion {
  const _AmountConversion({this.amount, this.missingPair});
  final Decimal? amount;
  final MissingExchangeRatePair? missingPair;
}

class _CategoryConversionResult {
  const _CategoryConversionResult({required this.items, required this.summary});
  final List<CategorySpendingTotal> items;
  final _ConversionSummary summary;
}

class _TrendConversionResult {
  const _TrendConversionResult({required this.values, required this.summary});
  final List<Decimal> values;
  final _ConversionSummary summary;
}

class MissingExchangeRatePair {
  const MissingExchangeRatePair(this.fromCurrencyCode, this.toCurrencyCode);

  final String fromCurrencyCode;
  final String toCurrencyCode;

  String get key => '$fromCurrencyCode->$toCurrencyCode';
}

class CurrencyTotal {
  const CurrencyTotal({required this.currencyCode, required this.amount});
  final String currencyCode;
  final Decimal amount;
}

class CategorySpendingTotal {
  const CategorySpendingTotal({
    required this.categoryId,
    required this.categoryName,
    required this.currencyCode,
    required this.amount,
  });

  final String categoryId;
  final String categoryName;
  final String currencyCode;
  final Decimal amount;
}
