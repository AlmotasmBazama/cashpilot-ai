// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Category _$CategoryFromJson(Map<String, dynamic> json) => _Category(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$CategoryTypeEnumMap, json['type']),
  icon: CategoryIcon.fromJson(json['icon'] as Map<String, dynamic>),
  color: CategoryColor.fromJson(json['color'] as Map<String, dynamic>),
  parentCategoryId: json['parentCategoryId'] as String?,
  isDefault: json['isDefault'] as bool,
  isArchived: json['isArchived'] as bool,
  sortOrder: (json['sortOrder'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$CategoryToJson(_Category instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$CategoryTypeEnumMap[instance.type]!,
  'icon': instance.icon,
  'color': instance.color,
  'parentCategoryId': instance.parentCategoryId,
  'isDefault': instance.isDefault,
  'isArchived': instance.isArchived,
  'sortOrder': instance.sortOrder,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$CategoryTypeEnumMap = {
  CategoryType.expense: 'expense',
  CategoryType.income: 'income',
  CategoryType.transfer: 'transfer',
};
