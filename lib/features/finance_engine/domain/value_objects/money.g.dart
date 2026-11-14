// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'money.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Money _$MoneyFromJson(Map<String, dynamic> json) => _Money(
  amount: const DecimalConverter().fromJson(json['amount'] as String),
  currencyCode: json['currencyCode'] as String,
);

Map<String, dynamic> _$MoneyToJson(_Money instance) => <String, dynamic>{
  'amount': const DecimalConverter().toJson(instance.amount),
  'currencyCode': instance.currencyCode,
};
