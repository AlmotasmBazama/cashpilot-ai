import 'package:decimal/decimal.dart';

import '../../domain/enums/budget_period_type.dart';

class BudgetDto {
  const BudgetDto({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.amount,
    required this.currency,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.alertThresholdPercent,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String categoryId;
  final Decimal amount;
  final String currency;
  final BudgetPeriodType periodType;
  final DateTime startDate;
  final DateTime endDate;
  final int alertThresholdPercent;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
}
