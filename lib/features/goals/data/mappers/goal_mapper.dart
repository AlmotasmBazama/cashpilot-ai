import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/goal.dart';
import '../../domain/enums/goal_status.dart';
import '../../domain/enums/goal_type.dart';
import '../dtos/goal_dto.dart';

extension GoalDomainMapper on Goal {
  GoalDto toDto() => GoalDto(
    id: id,
    title: title,
    description: description,
    type: type,
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    currency: currency,
    linkedAccountId: linkedAccountId,
    targetDate: targetDate,
    icon: icon,
    color: color,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    completedAt: completedAt,
  );
}

extension GoalDtoMapper on GoalDto {
  Goal toDomain() => Goal.create(
    id: id,
    title: title,
    description: description,
    type: type,
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    currency: currency,
    linkedAccountId: linkedAccountId,
    targetDate: targetDate,
    icon: icon,
    color: color,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    completedAt: completedAt,
  );

  GoalsCompanion toCompanion() => GoalsCompanion(
    id: Value(id),
    title: Value(title),
    description: Value(description),
    type: Value(type.storageValue),
    targetAmount: Value(targetAmount.toString()),
    currentAmount: Value(currentAmount.toString()),
    currency: Value(currency),
    linkedAccountId: Value(linkedAccountId),
    targetDate: Value(targetDate),
    icon: Value(icon),
    color: Value(color),
    status: Value(status.storageValue),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    archivedAt: Value(archivedAt),
    completedAt: Value(completedAt),
  );
}

extension GoalRowMapper on GoalRow {
  GoalDto toDto() => GoalDto(
    id: id,
    title: title,
    description: description,
    type: GoalTypeStorage.fromStorage(type),
    targetAmount: Decimal.parse(targetAmount),
    currentAmount: Decimal.parse(currentAmount),
    currency: currency,
    linkedAccountId: linkedAccountId,
    targetDate: targetDate,
    icon: icon,
    color: color,
    status: GoalStatusStorage.fromStorage(status),
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    completedAt: completedAt,
  );
}
