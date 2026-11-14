import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../enums/transaction_source.dart';
import '../enums/transaction_status.dart';
import '../enums/transaction_type.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

@freezed
abstract class Transaction with _$Transaction {
  const Transaction._();

  const factory Transaction({
    required String id,
    required String accountId,
    required String categoryId,
    String? payeeId,
    required Money amount,
    required TransactionType type,
    required PaymentMethod paymentMethod,
    required TransactionSource source,
    required TransactionStatus status,
    IncomeSourceType? incomeSourceType,
    String? transferGroupId,
    ExchangeRate? exchangeRate,
    String? note,
    required DateTime transactionDate,
    String? location,
    required int attachmentCount,
    int? aiConfidence,
    required bool needsReview,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Transaction;

  factory Transaction.create({
    required String accountId,
    required String categoryId,
    String? payeeId,
    required Money amount,
    required TransactionType type,
    PaymentMethod paymentMethod = PaymentMethod.other,
    TransactionSource source = TransactionSource.manual,
    TransactionStatus status = TransactionStatus.posted,
    IncomeSourceType? incomeSourceType,
    String? transferGroupId,
    ExchangeRate? exchangeRate,
    String? note,
    DateTime? transactionDate,
    String? location,
    int attachmentCount = 0,
    int? aiConfidence,
    bool needsReview = false,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = createdAt ?? now;

    return Transaction(
      id: id ?? const Uuid().v7(),
      accountId: accountId,
      categoryId: categoryId,
      payeeId: payeeId,
      amount: amount,
      type: type,
      paymentMethod: paymentMethod,
      source: source,
      status: status,
      incomeSourceType: incomeSourceType,
      transferGroupId: transferGroupId,
      exchangeRate: exchangeRate,
      note: note,
      transactionDate: transactionDate ?? now,
      location: location,
      attachmentCount: attachmentCount,
      aiConfidence: aiConfidence,
      needsReview: needsReview,
      createdAt: resolvedCreatedAt,
      updatedAt: updatedAt ?? resolvedCreatedAt,
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  bool get affectsBalance => status == TransactionStatus.posted;

  bool get isTransfer =>
      type == TransactionType.transferOut || type == TransactionType.transferIn;
}
