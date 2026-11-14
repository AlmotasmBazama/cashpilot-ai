// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processed_transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProcessedTransaction _$ProcessedTransactionFromJson(
  Map<String, dynamic> json,
) => _ProcessedTransaction(
  accountId: json['accountId'] as String,
  direction: $enumDecode(
    _$FinanceTransactionDirectionEnumMap,
    json['direction'],
  ),
  amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
  previousBalance: Money.fromJson(
    json['previousBalance'] as Map<String, dynamic>,
  ),
  newBalance: Money.fromJson(json['newBalance'] as Map<String, dynamic>),
  processedAt: DateTime.parse(json['processedAt'] as String),
);

Map<String, dynamic> _$ProcessedTransactionToJson(
  _ProcessedTransaction instance,
) => <String, dynamic>{
  'accountId': instance.accountId,
  'direction': _$FinanceTransactionDirectionEnumMap[instance.direction]!,
  'amount': instance.amount,
  'previousBalance': instance.previousBalance,
  'newBalance': instance.newBalance,
  'processedAt': instance.processedAt.toIso8601String(),
};

const _$FinanceTransactionDirectionEnumMap = {
  FinanceTransactionDirection.debit: 'debit',
  FinanceTransactionDirection.credit: 'credit',
};
