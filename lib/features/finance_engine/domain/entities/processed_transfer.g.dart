// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processed_transfer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProcessedTransfer _$ProcessedTransferFromJson(
  Map<String, dynamic> json,
) => _ProcessedTransfer(
  sourceAccountId: json['sourceAccountId'] as String,
  targetAccountId: json['targetAccountId'] as String,
  sourceAmount: Money.fromJson(json['sourceAmount'] as Map<String, dynamic>),
  targetAmount: Money.fromJson(json['targetAmount'] as Map<String, dynamic>),
  sourcePreviousBalance: Money.fromJson(
    json['sourcePreviousBalance'] as Map<String, dynamic>,
  ),
  sourceNewBalance: Money.fromJson(
    json['sourceNewBalance'] as Map<String, dynamic>,
  ),
  targetPreviousBalance: Money.fromJson(
    json['targetPreviousBalance'] as Map<String, dynamic>,
  ),
  targetNewBalance: Money.fromJson(
    json['targetNewBalance'] as Map<String, dynamic>,
  ),
  exchangeRate: ExchangeRate.fromJson(
    json['exchangeRate'] as Map<String, dynamic>,
  ),
  processedAt: DateTime.parse(json['processedAt'] as String),
);

Map<String, dynamic> _$ProcessedTransferToJson(_ProcessedTransfer instance) =>
    <String, dynamic>{
      'sourceAccountId': instance.sourceAccountId,
      'targetAccountId': instance.targetAccountId,
      'sourceAmount': instance.sourceAmount,
      'targetAmount': instance.targetAmount,
      'sourcePreviousBalance': instance.sourcePreviousBalance,
      'sourceNewBalance': instance.sourceNewBalance,
      'targetPreviousBalance': instance.targetPreviousBalance,
      'targetNewBalance': instance.targetNewBalance,
      'exchangeRate': instance.exchangeRate,
      'processedAt': instance.processedAt.toIso8601String(),
    };
