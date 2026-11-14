import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../transaction_row_domain_mapper.dart';
import '../../domain/entities/transaction.dart';
import '../../../payment_methods/payment_methods.dart'
    show PaymentMethodMapper, PaymentMethodX;
import '../../domain/enums/transaction_source.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';
import '../dtos/transaction_dto.dart';

final class DriftTransactionRowDomainMapper
    implements TransactionRowDomainMapper {
  const DriftTransactionRowDomainMapper();

  @override
  Transaction map(TransactionRow row) => row.toDto().toDomain();
}

extension TransactionDomainMapper on Transaction {
  TransactionDto toDto() {
    return TransactionDto(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      payeeId: payeeId,
      amount: amount.amount.toString(),
      currencyCode: amount.currencyCode,
      type: type.storageValue,
      paymentMethod: paymentMethod.storageValue,
      source: source.storageValue,
      status: status.storageValue,
      incomeSourceType: incomeSourceType?.storageValue,
      transferGroupId: transferGroupId,
      exchangeRateFromCurrencyCode: exchangeRate?.fromCurrencyCode,
      exchangeRateToCurrencyCode: exchangeRate?.toCurrencyCode,
      exchangeRate: exchangeRate?.rate.toString(),
      exchangeRateAsOf: exchangeRate?.asOf,
      note: note,
      transactionDate: transactionDate,
      location: location,
      attachmentCount: attachmentCount,
      aiConfidence: aiConfidence,
      needsReview: needsReview,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension TransactionDtoMapper on TransactionDto {
  Transaction toDomain() {
    return Transaction(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      payeeId: payeeId,
      amount: Money(amount: Decimal.parse(amount), currencyCode: currencyCode),
      type: TransactionTypeMapper.fromStorage(type),
      paymentMethod: PaymentMethodMapper.fromStorage(paymentMethod),
      source: TransactionSourceMapper.fromStorage(source),
      status: TransactionStatusMapper.fromStorage(status),
      incomeSourceType: IncomeSourceTypeMapper.tryFromStorage(incomeSourceType),
      transferGroupId: transferGroupId,
      exchangeRate: _exchangeRate(),
      note: note,
      transactionDate: transactionDate,
      location: location,
      attachmentCount: attachmentCount,
      aiConfidence: aiConfidence,
      needsReview: needsReview,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  TransactionsCompanion toCompanion() {
    return TransactionsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      categoryId: Value(categoryId),
      payeeId: Value(payeeId),
      amount: Value(amount),
      currencyCode: Value(currencyCode),
      type: Value(type),
      paymentMethod: Value(paymentMethod),
      source: Value(source),
      status: Value(status),
      incomeSourceType: Value(incomeSourceType),
      transferGroupId: Value(transferGroupId),
      exchangeRateFromCurrencyCode: Value(exchangeRateFromCurrencyCode),
      exchangeRateToCurrencyCode: Value(exchangeRateToCurrencyCode),
      exchangeRate: Value(exchangeRate),
      exchangeRateAsOf: Value(exchangeRateAsOf),
      note: Value(note),
      transactionDate: Value(transactionDate),
      location: Value(location),
      attachmentCount: Value(attachmentCount),
      aiConfidence: Value(aiConfidence),
      needsReview: Value(needsReview),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  ExchangeRate? _exchangeRate() {
    final fromCurrencyCode = exchangeRateFromCurrencyCode;
    final toCurrencyCode = exchangeRateToCurrencyCode;
    final rate = exchangeRate;

    if (fromCurrencyCode == null || toCurrencyCode == null || rate == null) {
      return null;
    }

    return ExchangeRate(
      fromCurrencyCode: fromCurrencyCode,
      toCurrencyCode: toCurrencyCode,
      rate: Decimal.parse(rate),
      asOf: exchangeRateAsOf,
    );
  }
}

extension TransactionRowMapper on TransactionRow {
  TransactionDto toDto() {
    return TransactionDto(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      payeeId: payeeId,
      amount: amount,
      currencyCode: currencyCode,
      type: type,
      paymentMethod: paymentMethod,
      source: source,
      status: status,
      incomeSourceType: incomeSourceType,
      transferGroupId: transferGroupId,
      exchangeRateFromCurrencyCode: exchangeRateFromCurrencyCode,
      exchangeRateToCurrencyCode: exchangeRateToCurrencyCode,
      exchangeRate: exchangeRate,
      exchangeRateAsOf: exchangeRateAsOf,
      note: note,
      transactionDate: transactionDate,
      location: location,
      attachmentCount: attachmentCount,
      aiConfidence: aiConfidence,
      needsReview: needsReview,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
