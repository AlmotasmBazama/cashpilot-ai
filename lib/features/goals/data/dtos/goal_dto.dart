import 'package:decimal/decimal.dart';

import '../../domain/enums/goal_status.dart';
import '../../domain/enums/goal_type.dart';

class GoalDto {
  const GoalDto({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    required this.icon,
    required this.color,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.linkedAccountId,
    this.targetDate,
    this.archivedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;
  final GoalType type;
  final Decimal targetAmount;
  final Decimal currentAmount;
  final String currency;
  final String? linkedAccountId;
  final DateTime? targetDate;
  final String icon;
  final int color;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? completedAt;
}
