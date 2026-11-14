import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_source.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/transaction_row_domain_mapper.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Drift transaction row mapping preserves every domain-facing field', () {
    final transactionDate = DateTime.utc(2026, 7, 8, 9, 10, 11);
    final rateAsOf = DateTime.utc(2026, 7, 7, 6, 5, 4);
    final createdAt = DateTime.utc(2026, 7, 8, 1, 2, 3);
    final updatedAt = DateTime.utc(2026, 7, 9, 4, 5, 6);
    final row = TransactionRow(
      id: 'transaction-id',
      ownerScopeId: 'owner-is-intentionally-persistence-only',
      accountId: 'account-id',
      categoryId: 'category-id',
      payeeId: 'payee-id',
      amount: '1234567890.123456789',
      currencyCode: 'USD',
      type: 'income',
      paymentMethod: 'digitalWallet',
      source: 'aiGenerated',
      status: 'pending',
      incomeSourceType: 'business_revenue',
      transferGroupId: 'transfer-group-id',
      transferPayloadFingerprint: 'persistence-only-fingerprint',
      exchangeRateFromCurrencyCode: 'USD',
      exchangeRateToCurrencyCode: 'LYD',
      exchangeRate: '4.875000000001',
      exchangeRateAsOf: rateAsOf,
      note: 'characterization note',
      transactionDate: transactionDate,
      location: 'Tripoli',
      attachmentCount: 3,
      aiConfidence: 87,
      needsReview: true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    const TransactionRowDomainMapper mapper = DriftTransactionRowDomainMapper();
    final transaction = mapper.map(row);

    expect(transaction.id, 'transaction-id');
    expect(transaction.accountId, 'account-id');
    expect(transaction.categoryId, 'category-id');
    expect(transaction.payeeId, 'payee-id');
    expect(transaction.amount.amount, Decimal.parse('1234567890.123456789'));
    expect(transaction.amount.currencyCode, 'USD');
    expect(transaction.type, TransactionType.income);
    expect(transaction.paymentMethod, PaymentMethod.digitalWallet);
    expect(transaction.source, TransactionSource.aiGenerated);
    expect(transaction.status, TransactionStatus.pending);
    expect(transaction.incomeSourceType, IncomeSourceType.businessRevenue);
    expect(transaction.transferGroupId, 'transfer-group-id');
    expect(transaction.exchangeRate?.fromCurrencyCode, 'USD');
    expect(transaction.exchangeRate?.toCurrencyCode, 'LYD');
    expect(transaction.exchangeRate?.rate, Decimal.parse('4.875000000001'));
    expect(transaction.exchangeRate?.asOf, rateAsOf);
    expect(transaction.note, 'characterization note');
    expect(transaction.transactionDate, transactionDate);
    expect(transaction.location, 'Tripoli');
    expect(transaction.attachmentCount, 3);
    expect(transaction.aiConfidence, 87);
    expect(transaction.needsReview, isTrue);
    expect(transaction.createdAt, createdAt);
    expect(transaction.updatedAt, updatedAt);
  });
}
