// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TransactionDto _$TransactionDtoFromJson(Map<String, dynamic> json) =>
    _TransactionDto(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      categoryId: json['categoryId'] as String,
      payeeId: json['payeeId'] as String?,
      amount: json['amount'] as String,
      currencyCode: json['currencyCode'] as String,
      type: json['type'] as String,
      paymentMethod: json['paymentMethod'] as String,
      source: json['source'] as String,
      status: json['status'] as String,
      incomeSourceType: json['incomeSourceType'] as String?,
      transferGroupId: json['transferGroupId'] as String?,
      exchangeRateFromCurrencyCode:
          json['exchangeRateFromCurrencyCode'] as String?,
      exchangeRateToCurrencyCode: json['exchangeRateToCurrencyCode'] as String?,
      exchangeRate: json['exchangeRate'] as String?,
      exchangeRateAsOf: json['exchangeRateAsOf'] == null
          ? null
          : DateTime.parse(json['exchangeRateAsOf'] as String),
      note: json['note'] as String?,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      location: json['location'] as String?,
      attachmentCount: (json['attachmentCount'] as num).toInt(),
      aiConfidence: (json['aiConfidence'] as num?)?.toInt(),
      needsReview: json['needsReview'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$TransactionDtoToJson(_TransactionDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'accountId': instance.accountId,
      'categoryId': instance.categoryId,
      'payeeId': instance.payeeId,
      'amount': instance.amount,
      'currencyCode': instance.currencyCode,
      'type': instance.type,
      'paymentMethod': instance.paymentMethod,
      'source': instance.source,
      'status': instance.status,
      'incomeSourceType': instance.incomeSourceType,
      'transferGroupId': instance.transferGroupId,
      'exchangeRateFromCurrencyCode': instance.exchangeRateFromCurrencyCode,
      'exchangeRateToCurrencyCode': instance.exchangeRateToCurrencyCode,
      'exchangeRate': instance.exchangeRate,
      'exchangeRateAsOf': instance.exchangeRateAsOf?.toIso8601String(),
      'note': instance.note,
      'transactionDate': instance.transactionDate.toIso8601String(),
      'location': instance.location,
      'attachmentCount': instance.attachmentCount,
      'aiConfidence': instance.aiConfidence,
      'needsReview': instance.needsReview,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
