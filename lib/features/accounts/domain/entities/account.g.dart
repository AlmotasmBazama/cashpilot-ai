// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Account _$AccountFromJson(Map<String, dynamic> json) => _Account(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$AccountTypeEnumMap, json['type']),
  currencyCode: json['currencyCode'] as String,
  balance: const DecimalConverter().fromJson(json['balance'] as String),
  icon: json['icon'] as String,
  color: (json['color'] as num).toInt(),
  paymentMethodIds:
      (json['paymentMethodIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  isArchived: json['isArchived'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$AccountToJson(_Account instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$AccountTypeEnumMap[instance.type]!,
  'currencyCode': instance.currencyCode,
  'balance': const DecimalConverter().toJson(instance.balance),
  'icon': instance.icon,
  'color': instance.color,
  'paymentMethodIds': instance.paymentMethodIds,
  'isArchived': instance.isArchived,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$AccountTypeEnumMap = {
  AccountType.cash: 'cash',
  AccountType.bank: 'bank',
  AccountType.creditCard: 'creditCard',
  AccountType.debitCard: 'debitCard',
  AccountType.savings: 'savings',
  AccountType.investment: 'investment',
  AccountType.digitalWallet: 'digitalWallet',
  AccountType.crypto: 'crypto',
  AccountType.other: 'other',
};
