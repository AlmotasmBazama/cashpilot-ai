// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Goal _$GoalFromJson(Map<String, dynamic> json) => _Goal(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  type: $enumDecode(_$GoalTypeEnumMap, json['type']),
  targetAmount: const DecimalConverter().fromJson(
    json['targetAmount'] as String,
  ),
  currentAmount: const DecimalConverter().fromJson(
    json['currentAmount'] as String,
  ),
  currency: json['currency'] as String,
  linkedAccountId: json['linkedAccountId'] as String?,
  targetDate: json['targetDate'] == null
      ? null
      : DateTime.parse(json['targetDate'] as String),
  icon: json['icon'] as String,
  color: (json['color'] as num).toInt(),
  status: $enumDecode(_$GoalStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  archivedAt: json['archivedAt'] == null
      ? null
      : DateTime.parse(json['archivedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
);

Map<String, dynamic> _$GoalToJson(_Goal instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'type': _$GoalTypeEnumMap[instance.type]!,
  'targetAmount': const DecimalConverter().toJson(instance.targetAmount),
  'currentAmount': const DecimalConverter().toJson(instance.currentAmount),
  'currency': instance.currency,
  'linkedAccountId': instance.linkedAccountId,
  'targetDate': instance.targetDate?.toIso8601String(),
  'icon': instance.icon,
  'color': instance.color,
  'status': _$GoalStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'archivedAt': instance.archivedAt?.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
};

const _$GoalTypeEnumMap = {
  GoalType.savings: 'savings',
  GoalType.emergencyFund: 'emergencyFund',
  GoalType.debtPayoff: 'debtPayoff',
  GoalType.purchase: 'purchase',
  GoalType.custom: 'custom',
};

const _$GoalStatusEnumMap = {
  GoalStatus.active: 'active',
  GoalStatus.completed: 'completed',
  GoalStatus.paused: 'paused',
  GoalStatus.archived: 'archived',
};
