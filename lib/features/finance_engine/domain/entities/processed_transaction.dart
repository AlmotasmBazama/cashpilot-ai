import 'package:freezed_annotation/freezed_annotation.dart';

import '../enums/finance_transaction_direction.dart';
import '../value_objects/money.dart';

part 'processed_transaction.freezed.dart';
part 'processed_transaction.g.dart';

@freezed
abstract class ProcessedTransaction with _$ProcessedTransaction {
  const factory ProcessedTransaction({
    required String accountId,
    required FinanceTransactionDirection direction,
    required Money amount,
    required Money previousBalance,
    required Money newBalance,
    required DateTime processedAt,
  }) = _ProcessedTransaction;

  factory ProcessedTransaction.fromJson(Map<String, dynamic> json) =>
      _$ProcessedTransactionFromJson(json);
}
