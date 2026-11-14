import 'package:drift/drift.dart';
import 'package:decimal/decimal.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/budget.dart';
import '../../domain/enums/budget_period_type.dart';
import '../dtos/budget_dto.dart';

extension BudgetDomainMapper on Budget {
  BudgetDto toDto() => BudgetDto(
    id: id,
    name: name,
    categoryId: categoryId,
    amount: amount,
    currency: currency,
    periodType: periodType,
    startDate: startDate,
    endDate: endDate,
    alertThresholdPercent: alertThresholdPercent,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );
}

extension BudgetDtoMapper on BudgetDto {
  Budget toDomain() => Budget.create(
    id: id,
    name: name,
    categoryId: categoryId,
    amount: amount,
    currency: currency,
    periodType: periodType,
    startDate: startDate,
    endDate: endDate,
    alertThresholdPercent: alertThresholdPercent,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  BudgetsCompanion toCompanion() => BudgetsCompanion(
    id: Value(id),
    name: Value(name),
    categoryId: Value(categoryId),
    amount: Value(amount.toString()),
    currency: Value(currency),
    periodType: Value(periodType.storageValue),
    startDate: Value(startDate),
    endDate: Value(endDate),
    alertThresholdPercent: Value(alertThresholdPercent),
    isActive: Value(isActive),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    archivedAt: Value(archivedAt),
  );
}

extension BudgetRowMapper on BudgetRow {
  BudgetDto toDto() => BudgetDto(
    id: id,
    name: name,
    categoryId: categoryId,
    amount: Decimal.parse(amount),
    currency: currency,
    periodType: BudgetPeriodTypeStorage.fromStorage(periodType),
    startDate: startDate,
    endDate: endDate,
    alertThresholdPercent: alertThresholdPercent,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );
}
