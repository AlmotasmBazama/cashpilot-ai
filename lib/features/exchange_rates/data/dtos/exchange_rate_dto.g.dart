// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExchangeRateDto _$ExchangeRateDtoFromJson(Map<String, dynamic> json) =>
    _ExchangeRateDto(
      id: json['id'] as String,
      baseCurrency: json['baseCurrency'] as String,
      quoteCurrency: json['quoteCurrency'] as String,
      rate: json['rate'] as String,
      source: json['source'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
    );

Map<String, dynamic> _$ExchangeRateDtoToJson(_ExchangeRateDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baseCurrency': instance.baseCurrency,
      'quoteCurrency': instance.quoteCurrency,
      'rate': instance.rate,
      'source': instance.source,
      'fetchedAt': instance.fetchedAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'archivedAt': instance.archivedAt?.toIso8601String(),
    };
