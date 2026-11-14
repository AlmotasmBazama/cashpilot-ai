// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payee_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PayeeDto _$PayeeDtoFromJson(Map<String, dynamic> json) => _PayeeDto(
  id: json['id'] as String,
  name: json['name'] as String,
  normalizedName: json['normalizedName'] as String,
  type: json['type'] as String,
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

Map<String, dynamic> _$PayeeDtoToJson(_PayeeDto instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'normalizedName': instance.normalizedName,
  'type': instance.type,
  'aliases': instance.aliases,
  'defaultCategoryId': instance.defaultCategoryId,
  'defaultAccountId': instance.defaultAccountId,
  'notes': instance.notes,
  'lastUsedAt': instance.lastUsedAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'archivedAt': instance.archivedAt?.toIso8601String(),
};
