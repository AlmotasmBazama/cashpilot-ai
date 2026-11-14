// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_contribution.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GoalContribution _$GoalContributionFromJson(Map<String, dynamic> json) =>
    _GoalContribution(
      id: json['id'] as String,
      goalId: json['goalId'] as String,
      amount: const DecimalConverter().fromJson(json['amount'] as String),
      currency: json['currency'] as String,
      creditedAmount: _$JsonConverterFromJson<String, Decimal>(
        json['creditedAmount'],
        const DecimalConverter().fromJson,
      ),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String,
      linkedTransactionId: json['linkedTransactionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      reversedAt: json['reversedAt'] == null
          ? null
          : DateTime.parse(json['reversedAt'] as String),
    );

Map<String, dynamic> _$GoalContributionToJson(_GoalContribution instance) =>
    <String, dynamic>{
      'id': instance.id,
      'goalId': instance.goalId,
      'amount': const DecimalConverter().toJson(instance.amount),
      'currency': instance.currency,
      'creditedAmount': _$JsonConverterToJson<String, Decimal>(
        instance.creditedAmount,
        const DecimalConverter().toJson,
      ),
      'date': instance.date.toIso8601String(),
      'note': instance.note,
      'linkedTransactionId': instance.linkedTransactionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'reversedAt': instance.reversedAt?.toIso8601String(),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
