import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/exceptions/finance_exception.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14);

  test('net worth converts accounts without mutating balances', () async {
    final lyd = _account(id: 'lyd', currency: 'LYD', balance: '1000');
    final usd = _account(id: 'usd', currency: 'USD', balance: '100');
    final originalBalances = <Decimal>[lyd.balance, usd.balance];

    final snapshot = await DashboardSnapshot.from(
      accounts: <Account>[lyd, usd],
      transactions: const <Transaction>[],
      categories: const <Category>[],
      baseCurrencyCode: 'LYD',
      exchangeRateProvider: _Rates(<String, String>{'USD->LYD': '7.5'}),
      now: now,
    );

    expect(snapshot.netWorthInBaseCurrency.amount, Decimal.parse('1750'));
    expect(snapshot.netWorthInBaseCurrency.currencyCode, 'LYD');
    expect(snapshot.missingExchangeRatePairs, isEmpty);
    expect(<Decimal>[lyd.balance, usd.balance], originalBalances);
  });

  test(
    'missing rate creates a partial warning and keeps original total',
    () async {
      final snapshot = await DashboardSnapshot.from(
        accounts: <Account>[
          _account(id: 'lyd', currency: 'LYD', balance: '1000'),
          _account(id: 'usd', currency: 'USD', balance: '100'),
        ],
        transactions: const <Transaction>[],
        categories: const <Category>[],
        baseCurrencyCode: 'LYD',
        exchangeRateProvider: const _Rates(<String, String>{}),
        now: now,
      );

      expect(snapshot.netWorthInBaseCurrency.amount, Decimal.parse('1000'));
      expect(
        snapshot.unconvertedNetWorthByCurrency.single.amount,
        Decimal.parse('100'),
      );
      expect(snapshot.isPartial, isTrue);
      expect(snapshot.missingExchangeRatePairs.single.fromCurrencyCode, 'USD');
      expect(snapshot.missingExchangeRatePairs.single.toCurrencyCode, 'LYD');
    },
  );

  test(
    'monthly reports and categories consolidate into base currency',
    () async {
      final category = _category();
      final transactions = <Transaction>[
        _transaction(
          id: 'usd-expense',
          categoryId: category.id,
          amount: '10',
          currency: 'USD',
          date: now,
          exchangeRate: ExchangeRate(
            fromCurrencyCode: 'USD',
            toCurrencyCode: 'LYD',
            rate: Decimal.parse('7.5'),
            asOf: now,
          ),
        ),
        _transaction(
          id: 'lyd-expense',
          categoryId: category.id,
          amount: '20',
          currency: 'LYD',
          date: now,
        ),
        _transaction(
          id: 'cancelled',
          categoryId: category.id,
          amount: '500',
          currency: 'LYD',
          date: now,
          status: TransactionStatus.cancelled,
        ),
      ];

      final snapshot = await DashboardSnapshot.from(
        accounts: const <Account>[],
        transactions: transactions,
        categories: <Category>[category],
        baseCurrencyCode: 'LYD',
        exchangeRateProvider: _Rates(<String, String>{'USD->LYD': '7.5'}),
        now: now,
      );

      expect(
        snapshot.monthlyExpenseByCurrency.single.amount,
        Decimal.parse('95'),
      );
      expect(
        snapshot.yearlyExpenseByCurrency.single.amount,
        Decimal.parse('95'),
      );
      expect(snapshot.spendingByCategory.single.amount, Decimal.parse('95'));
      expect(snapshot.spendingByCategory.single.currencyCode, 'LYD');
      expect(snapshot.monthlyExpenseTrend.last, Decimal.parse('95'));
    },
  );

  test(
    'missing report rate excludes only the unconvertible amount and warns',
    () async {
      final category = _category();
      final snapshot = await DashboardSnapshot.from(
        accounts: const <Account>[],
        transactions: <Transaction>[
          _transaction(
            id: 'usd',
            categoryId: category.id,
            amount: '10',
            currency: 'USD',
            date: now,
          ),
          _transaction(
            id: 'lyd',
            categoryId: category.id,
            amount: '20',
            currency: 'LYD',
            date: now,
          ),
        ],
        categories: <Category>[category],
        baseCurrencyCode: 'LYD',
        exchangeRateProvider: const _Rates(<String, String>{}),
        now: now,
      );

      expect(
        snapshot.monthlyExpenseByCurrency.single.amount,
        Decimal.parse('20'),
      );
      expect(snapshot.spendingByCategory.single.amount, Decimal.parse('20'));
      expect(snapshot.isPartial, isTrue);
    },
  );
}

class _Rates implements ExchangeRateProvider {
  const _Rates(this.rates);

  final Map<String, String> rates;

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) async {
    if (fromCurrencyCode == toCurrencyCode) {
      return ExchangeRate.identity(currencyCode: fromCurrencyCode, asOf: at);
    }
    final value = rates['$fromCurrencyCode->$toCurrencyCode'];
    if (value == null) {
      throw FinanceException.exchangeRateUnavailable(
        fromCurrencyCode: fromCurrencyCode,
        toCurrencyCode: toCurrencyCode,
      );
    }
    return ExchangeRate(
      fromCurrencyCode: fromCurrencyCode,
      toCurrencyCode: toCurrencyCode,
      rate: Decimal.parse(value),
      asOf: at,
    );
  }
}

Account _account({
  required String id,
  required String currency,
  required String balance,
}) {
  return Account.create(
    id: id,
    name: id,
    type: AccountType.bank,
    currencyCode: currency,
    balance: Decimal.parse(balance),
    icon: 'bank',
    color: 0xFF006C67,
  );
}

Category _category() {
  return Category.create(
    id: 'food',
    name: 'Food',
    type: CategoryType.expense,
    icon: const CategoryIcon(key: 'food'),
    color: const CategoryColor(argb: 0xFFEF4444),
  );
}

Transaction _transaction({
  required String id,
  required String categoryId,
  required String amount,
  required String currency,
  required DateTime date,
  TransactionStatus status = TransactionStatus.posted,
  ExchangeRate? exchangeRate,
}) {
  return Transaction.create(
    id: id,
    accountId: 'account',
    categoryId: categoryId,
    amount: Money(amount: Decimal.parse(amount), currencyCode: currency),
    type: TransactionType.expense,
    status: status,
    exchangeRate: exchangeRate,
    transactionDate: date,
  );
}
