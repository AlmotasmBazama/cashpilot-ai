import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/exceptions/finance_exception.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/repositories/exchange_rate_provider.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/income_sources/domain/services/income_reporting_policy.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OF-023 exhaustive income reporting policy', () {
    const normalSources = <IncomeSourceType>{
      IncomeSourceType.salary,
      IncomeSourceType.freelance,
      IncomeSourceType.businessRevenue,
      IncomeSourceType.gift,
      IncomeSourceType.allowance,
      IncomeSourceType.sale,
      IncomeSourceType.rentalIncome,
      IncomeSourceType.governmentSupport,
      IncomeSourceType.scholarship,
      IncomeSourceType.investmentReturn,
      IncomeSourceType.prize,
    };
    const refundSources = <IncomeSourceType>{
      IncomeSourceType.refund,
      IncomeSourceType.reimbursement,
    };

    for (final sourceType in <IncomeSourceType?>[
      ...IncomeSourceType.values,
      null,
    ]) {
      test('${sourceType?.name ?? 'null'} has an explicit report result', () {
        final transaction = _income(
          id: sourceType?.name ?? 'unclassified',
          sourceType: sourceType,
        );

        expect(
          IncomeReportingPolicy.isNormalIncome(transaction),
          normalSources.contains(sourceType),
        );
        expect(
          IncomeReportingPolicy.isRefundOrReimbursement(transaction),
          refundSources.contains(sourceType),
        );
        expect(
          IncomeReportingPolicy.isEarnedIncome(transaction),
          normalSources.contains(sourceType) &&
              (sourceType?.isEarnedIncome ?? false),
        );
      });
    }

    test('dashboard total includes only ordinary classified income', () async {
      final transactions = <Transaction>[
        for (final sourceType in <IncomeSourceType?>[
          ...IncomeSourceType.values,
          null,
        ])
          _income(
            id: sourceType?.name ?? 'unclassified',
            sourceType: sourceType,
          ),
      ];

      final snapshot = await DashboardSnapshot.from(
        accounts: const [],
        transactions: transactions,
        categories: const [],
        baseCurrencyCode: 'LYD',
        exchangeRateProvider: const _Rates('99'),
        now: _now,
      );

      expect(
        snapshot.monthlyIncomeByCurrency.single.amount,
        Decimal.parse('110'),
      );
      expect(
        snapshot.yearlyIncomeByCurrency.single.amount,
        Decimal.parse('110'),
      );
      expect(snapshot.isPartial, isFalse);
    });
  });

  group('OF-025 historical report FX', () {
    test(
      'missing persisted transaction FX warns instead of using latest rate',
      () async {
        final transaction = _expense(id: 'historical-without-rate');

        final before = await _snapshot(
          transaction,
          exchangeRateProvider: const _Rates('2'),
        );
        final afterLatestRateChange = await _snapshot(
          transaction,
          exchangeRateProvider: const _Rates('9'),
        );

        expect(before.monthlyExpenseByCurrency.single.amount, Decimal.zero);
        expect(
          afterLatestRateChange.monthlyExpenseByCurrency.single.amount,
          Decimal.zero,
        );
        expect(before.isPartial, isTrue);
        expect(afterLatestRateChange.isPartial, isTrue);
        expect(before.missingExchangeRatePairs.single.fromCurrencyCode, 'USD');
        expect(before.missingExchangeRatePairs.single.toCurrencyCode, 'LYD');
      },
    );

    test('persisted as-of FX keeps historical totals invariant', () async {
      final transaction = _expense(
        id: 'historical-with-rate',
        exchangeRate: ExchangeRate(
          fromCurrencyCode: 'USD',
          toCurrencyCode: 'LYD',
          rate: Decimal.parse('2'),
          asOf: _transactionDate,
        ),
      );

      final before = await _snapshot(
        transaction,
        exchangeRateProvider: const _Rates('7'),
      );
      final afterLatestRateChange = await _snapshot(
        transaction,
        exchangeRateProvider: const _Rates('11'),
      );

      expect(
        before.monthlyExpenseByCurrency.single.amount,
        Decimal.parse('20'),
      );
      expect(
        afterLatestRateChange.monthlyExpenseByCurrency.single.amount,
        Decimal.parse('20'),
      );
      expect(before.isPartial, isFalse);
      expect(afterLatestRateChange.isPartial, isFalse);
    });
  });
}

Future<DashboardSnapshot> _snapshot(
  Transaction transaction, {
  required ExchangeRateProvider exchangeRateProvider,
}) {
  return DashboardSnapshot.from(
    accounts: const [],
    transactions: <Transaction>[transaction],
    categories: const [],
    baseCurrencyCode: 'LYD',
    exchangeRateProvider: exchangeRateProvider,
    now: _now,
  );
}

Transaction _income({
  required String id,
  required IncomeSourceType? sourceType,
}) {
  return Transaction.create(
    id: id,
    accountId: 'account',
    categoryId: 'income-category',
    amount: Money(amount: Decimal.parse('10'), currencyCode: 'LYD'),
    type: TransactionType.income,
    status: TransactionStatus.posted,
    incomeSourceType: sourceType,
    transactionDate: _transactionDate,
  );
}

Transaction _expense({required String id, ExchangeRate? exchangeRate}) {
  return Transaction.create(
    id: id,
    accountId: 'account',
    categoryId: 'expense-category',
    amount: Money(amount: Decimal.parse('10'), currencyCode: 'USD'),
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    exchangeRate: exchangeRate,
    transactionDate: _transactionDate,
  );
}

final _now = DateTime.utc(2026, 7, 20);
final _transactionDate = DateTime.utc(2026, 7, 5);

final class _Rates implements ExchangeRateProvider {
  const _Rates(this.rate);

  final String rate;

  @override
  Future<ExchangeRate> getExchangeRate({
    required String fromCurrencyCode,
    required String toCurrencyCode,
    DateTime? at,
  }) async {
    if (fromCurrencyCode == toCurrencyCode) {
      return ExchangeRate.identity(currencyCode: fromCurrencyCode, asOf: at);
    }
    if (fromCurrencyCode != 'USD' || toCurrencyCode != 'LYD') {
      throw FinanceException.exchangeRateUnavailable(
        fromCurrencyCode: fromCurrencyCode,
        toCurrencyCode: toCurrencyCode,
      );
    }
    return ExchangeRate(
      fromCurrencyCode: fromCurrencyCode,
      toCurrencyCode: toCurrencyCode,
      rate: Decimal.parse(rate),
      asOf: DateTime.utc(2026, 7, 20),
    );
  }
}
