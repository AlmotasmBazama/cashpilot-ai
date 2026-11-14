// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CategoryDto _$CategoryDtoFromJson(Map<String, dynamic> json) => _CategoryDto(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  icon: json['icon'] as String,
  color: (json['color'] as num).toInt(),
  parentCategoryId: json['parentCategoryId'] as String?,
  isDefault: json['isDefault'] as bool,
  isArchived: json['isArchived'] as bool,
  sortOrder: (json['sortOrder'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$CategoryDtoToJson(_CategoryDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'icon': instance.icon,
      'color': instance.color,
      'parentCategoryId': instance.parentCategoryId,
      'isDefault': instance.isDefault,
      'isArchived': instance.isArchived,
      'sortOrder': instance.sortOrder,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
