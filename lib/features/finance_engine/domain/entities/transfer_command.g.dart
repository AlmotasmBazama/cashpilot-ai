// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_command.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TransferCommand _$TransferCommandFromJson(Map<String, dynamic> json) =>
    _TransferCommand(
      sourceAccountId: json['sourceAccountId'] as String,
      targetAccountId: json['targetAccountId'] as String,
      sourceAmount: Money.fromJson(
        json['sourceAmount'] as Map<String, dynamic>,
      ),
      targetAmount: json['targetAmount'] == null
          ? null
          : Money.fromJson(json['targetAmount'] as Map<String, dynamic>),
      exchangeRate: json['exchangeRate'] == null
          ? null
          : ExchangeRate.fromJson(json['exchangeRate'] as Map<String, dynamic>),
      occurredAt: json['occurredAt'] == null
          ? null
          : DateTime.parse(json['occurredAt'] as String),
    );

Map<String, dynamic> _$TransferCommandToJson(_TransferCommand instance) =>
    <String, dynamic>{
      'sourceAccountId': instance.sourceAccountId,
      'targetAccountId': instance.targetAccountId,
      'sourceAmount': instance.sourceAmount,
      'targetAmount': instance.targetAmount,
      'exchangeRate': instance.exchangeRate,
      'occurredAt': instance.occurredAt?.toIso8601String(),
    };
