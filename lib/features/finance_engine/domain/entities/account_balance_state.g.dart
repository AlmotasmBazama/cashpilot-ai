// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_balance_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountBalanceState _$AccountBalanceStateFromJson(Map<String, dynamic> json) =>
    _AccountBalanceState(
      accountId: json['accountId'] as String,
      currencyCode: json['currencyCode'] as String,
      balance: const DecimalConverter().fromJson(json['balance'] as String),
      allowsNegativeBalance: json['allowsNegativeBalance'] as bool? ?? false,
      creditLimit: _$JsonConverterFromJson<String, Decimal>(
        json['creditLimit'],
        const DecimalConverter().fromJson,
      ),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AccountBalanceStateToJson(
  _AccountBalanceState instance,
) => <String, dynamic>{
  'accountId': instance.accountId,
  'currencyCode': instance.currencyCode,
  'balance': const DecimalConverter().toJson(instance.balance),
  'allowsNegativeBalance': instance.allowsNegativeBalance,
  'creditLimit': _$JsonConverterToJson<String, Decimal>(
    instance.creditLimit,
    const DecimalConverter().toJson,
  ),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
