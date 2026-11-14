import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/income_sources/domain/services/income_reporting_policy.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('salary is normal and earned report income', () {
    final salary = _transaction(
      type: TransactionType.income,
      sourceType: IncomeSourceType.salary,
    );

    expect(IncomeReportingPolicy.isNormalIncome(salary), isTrue);
    expect(IncomeReportingPolicy.isEarnedIncome(salary), isTrue);
  });

  test('loan proceeds remain excluded from report income', () {
    final loan = _transaction(
      type: TransactionType.income,
      sourceType: IncomeSourceType.loanProceeds,
    );

    expect(IncomeReportingPolicy.isNormalIncome(loan), isFalse);
    expect(IncomeReportingPolicy.isEarnedIncome(loan), isFalse);
  });

  test('debt repayment remains separate from ordinary report income', () {
    final debtRepayment = _transaction(
      type: TransactionType.income,
      sourceType: IncomeSourceType.debtRepayment,
    );

    expect(IncomeReportingPolicy.isNormalIncome(debtRepayment), isFalse);
    expect(IncomeReportingPolicy.isEarnedIncome(debtRepayment), isFalse);
    expect(
      debtRepayment.incomeSourceType?.reportingBucket,
      IncomeSourceReportingBucket.debtRepayment,
    );
  });

  test('both internal transfer sides remain excluded from report income', () {
    final outgoing = _transaction(type: TransactionType.transferOut);
    final incoming = _transaction(type: TransactionType.transferIn);

    expect(IncomeReportingPolicy.isNormalIncome(outgoing), isFalse);
    expect(IncomeReportingPolicy.isNormalIncome(incoming), isFalse);
  });
}

Transaction _transaction({
  required TransactionType type,
  IncomeSourceType? sourceType,
}) {
  return Transaction.create(
    accountId: 'account',
    categoryId: 'category',
    amount: Money(amount: Decimal.parse('100'), currencyCode: 'LYD'),
    type: type,
    incomeSourceType: sourceType,
    transferGroupId:
        type == TransactionType.transferOut ||
            type == TransactionType.transferIn
        ? 'transfer'
        : null,
    transactionDate: DateTime.utc(2026, 7, 1),
  );
}
