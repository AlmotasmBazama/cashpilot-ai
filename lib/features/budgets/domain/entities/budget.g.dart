// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Budget _$BudgetFromJson(Map<String, dynamic> json) => _Budget(
  id: json['id'] as String,
  name: json['name'] as String,
  categoryId: json['categoryId'] as String,
  amount: const DecimalConverter().fromJson(json['amount'] as String),
  currency: json['currency'] as String,
  periodType: $enumDecode(_$BudgetPeriodTypeEnumMap, json['periodType']),
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: DateTime.parse(json['endDate'] as String),
  alertThresholdPercent: (json['alertThresholdPercent'] as num).toInt(),
  isActive: json['isActive'] as bool,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  archivedAt: json['archivedAt'] == null
      ? null
      : DateTime.parse(json['archivedAt'] as String),
);

Map<String, dynamic> _$BudgetToJson(_Budget instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'categoryId': instance.categoryId,
  'amount': const DecimalConverter().toJson(instance.amount),
  'currency': instance.currency,
  'periodType': _$BudgetPeriodTypeEnumMap[instance.periodType]!,
  'startDate': instance.startDate.toIso8601String(),
  'endDate': instance.endDate.toIso8601String(),
  'alertThresholdPercent': instance.alertThresholdPercent,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'archivedAt': instance.archivedAt?.toIso8601String(),
};

const _$BudgetPeriodTypeEnumMap = {
  BudgetPeriodType.weekly: 'weekly',
  BudgetPeriodType.monthly: 'monthly',
  BudgetPeriodType.yearly: 'yearly',
  BudgetPeriodType.custom: 'custom',
};
