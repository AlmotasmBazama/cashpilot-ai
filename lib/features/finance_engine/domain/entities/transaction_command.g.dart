// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TransactionCommand _$TransactionCommandFromJson(Map<String, dynamic> json) =>
    _TransactionCommand(
      accountId: json['accountId'] as String,
      amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
      direction: $enumDecode(
        _$FinanceTransactionDirectionEnumMap,
        json['direction'],
      ),
      occurredAt: json['occurredAt'] == null
          ? null
          : DateTime.parse(json['occurredAt'] as String),
    );

Map<String, dynamic> _$TransactionCommandToJson(_TransactionCommand instance) =>
    <String, dynamic>{
      'accountId': instance.accountId,
      'amount': instance.amount,
      'direction': _$FinanceTransactionDirectionEnumMap[instance.direction]!,
      'occurredAt': instance.occurredAt?.toIso8601String(),
    };

const _$FinanceTransactionDirectionEnumMap = {
  FinanceTransactionDirection.debit: 'debit',
  FinanceTransactionDirection.credit: 'credit',
};
