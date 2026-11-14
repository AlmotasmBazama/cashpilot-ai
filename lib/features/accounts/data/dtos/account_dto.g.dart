// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountDto _$AccountDtoFromJson(Map<String, dynamic> json) => _AccountDto(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  currencyCode: json['currencyCode'] as String,
  balance: json['balance'] as String,
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

Map<String, dynamic> _$AccountDtoToJson(_AccountDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'currencyCode': instance.currencyCode,
      'balance': instance.balance,
      'icon': instance.icon,
      'color': instance.color,
      'paymentMethodIds': instance.paymentMethodIds,
      'isArchived': instance.isArchived,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
