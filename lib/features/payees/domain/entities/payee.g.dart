// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payee.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Payee _$PayeeFromJson(Map<String, dynamic> json) => _Payee(
  id: json['id'] as String,
  name: json['name'] as String,
  normalizedName: json['normalizedName'] as String,
  type: $enumDecode(_$PayeeTypeEnumMap, json['type']),
  aliases:
      (json['aliases'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  defaultCategoryId: json['defaultCategoryId'] as String?,
  defaultAccountId: json['defaultAccountId'] as String?,
  notes: json['notes'] as String?,
  lastUsedAt: json['lastUsedAt'] == null
      ? null
      : DateTime.parse(json['lastUsedAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  archivedAt: json['archivedAt'] == null
      ? null
      : DateTime.parse(json['archivedAt'] as String),
);

Map<String, dynamic> _$PayeeToJson(_Payee instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'normalizedName': instance.normalizedName,
  'type': _$PayeeTypeEnumMap[instance.type]!,
  'aliases': instance.aliases,
  'defaultCategoryId': instance.defaultCategoryId,
  'defaultAccountId': instance.defaultAccountId,
  'notes': instance.notes,
  'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'archivedAt': instance.archivedAt?.toIso8601String(),
};

const _$PayeeTypeEnumMap = {
  PayeeType.person: 'person',
  PayeeType.merchant: 'merchant',
  PayeeType.employer: 'employer',
  PayeeType.bank: 'bank',
  PayeeType.paymentService: 'paymentService',
  PayeeType.utility: 'utility',
  PayeeType.school: 'school',
  PayeeType.telecom: 'telecom',
  PayeeType.government: 'government',
  PayeeType.other: 'other',
};
