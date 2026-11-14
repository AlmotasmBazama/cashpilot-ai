// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExchangeRate _$ExchangeRateFromJson(Map<String, dynamic> json) =>
    _ExchangeRate(
      fromCurrencyCode: json['fromCurrencyCode'] as String,
      toCurrencyCode: json['toCurrencyCode'] as String,
      rate: const DecimalConverter().fromJson(json['rate'] as String),
      asOf: json['asOf'] == null
          ? null
          : DateTime.parse(json['asOf'] as String),
    );

Map<String, dynamic> _$ExchangeRateToJson(_ExchangeRate instance) =>
    <String, dynamic>{
      'fromCurrencyCode': instance.fromCurrencyCode,
      'toCurrencyCode': instance.toCurrencyCode,
      'rate': const DecimalConverter().toJson(instance.rate),
      'asOf': instance.asOf?.toIso8601String(),
    };
