// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_exchange_rate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StoredExchangeRate _$StoredExchangeRateFromJson(Map<String, dynamic> json) =>
    _StoredExchangeRate(
      id: json['id'] as String,
      baseCurrency: json['baseCurrency'] as String,
      quoteCurrency: json['quoteCurrency'] as String,
      rate: const DecimalConverter().fromJson(json['rate'] as String),
      source: $enumDecode(_$ExchangeRateSourceEnumMap, json['source']),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
    );

Map<String, dynamic> _$StoredExchangeRateToJson(_StoredExchangeRate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baseCurrency': instance.baseCurrency,
      'quoteCurrency': instance.quoteCurrency,
      'rate': const DecimalConverter().toJson(instance.rate),
      'source': _$ExchangeRateSourceEnumMap[instance.source]!,
      'fetchedAt': instance.fetchedAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'archivedAt': instance.archivedAt?.toIso8601String(),
    };

const _$ExchangeRateSourceEnumMap = {
  ExchangeRateSource.manual: 'manual',
  ExchangeRateSource.cached: 'cached',
  ExchangeRateSource.remote: 'remote',
  ExchangeRateSource.system: 'system',
};
