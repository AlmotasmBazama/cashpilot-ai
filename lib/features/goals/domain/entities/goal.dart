import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/serialization/decimal_converter.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../enums/goal_status.dart';
import '../enums/goal_type.dart';
import '../failures/goal_failure_codes.dart';

part 'goal.freezed.dart';
part 'goal.g.dart';

@freezed
abstract class Goal with _$Goal {
  const Goal._();

  const factory Goal({
    required String id,
    required String title,
    required String description,
    required GoalType type,
    @DecimalConverter() required Decimal targetAmount,
    @DecimalConverter() required Decimal currentAmount,
    required String currency,
    String? linkedAccountId,
    DateTime? targetDate,
    required String icon,
    required int color,
    required GoalStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
    DateTime? completedAt,
  }) = _Goal;

  factory Goal.create({
    required String title,
    required Decimal targetAmount,
    required String currency,
    String description = '',
    GoalType type = GoalType.savings,
    Decimal? currentAmount,
    String? linkedAccountId,
    DateTime? targetDate,
    String icon = 'flag',
    int color = 0xFF17A673,
    GoalStatus status = GoalStatus.active,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    DateTime? completedAt,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidTitle,
        message: 'Goal title is required.',
      );
    }
    if (targetAmount <= Decimal.zero) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidAmount,
        message: 'Goal target amount must be greater than zero.',
      );
    }
    final resolvedCurrentAmount = currentAmount ?? Decimal.zero;
    if (resolvedCurrentAmount < Decimal.zero) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidAmount,
        message: 'Goal current amount cannot be negative.',
      );
    }
    if (resolvedCurrentAmount > targetAmount) {
      throw const GoalValidationException(
        code: GoalFailureCodes.overfunding,
        message: 'Goal current amount cannot exceed its target.',
      );
    }
    final normalizedCurrency = currency.trim().toUpperCase();
    if (CurrencyCatalog.findByCode(normalizedCurrency) == null) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidCurrency,
        message: 'Goal currency is not supported.',
      );
    }

    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = (createdAt ?? now).toUtc();
    final isComplete = resolvedCurrentAmount == targetAmount;
    final isArchived = archivedAt != null || status == GoalStatus.archived;
    final resolvedStatus = isArchived
        ? GoalStatus.archived
        : isComplete
        ? GoalStatus.completed
        : status == GoalStatus.completed
        ? GoalStatus.active
        : status;
    return Goal(
      id: id ?? const Uuid().v7(),
      title: normalizedTitle,
      description: description.trim(),
      type: type,
      targetAmount: targetAmount,
      currentAmount: resolvedCurrentAmount,
      currency: normalizedCurrency,
      linkedAccountId: _trimmedOrNull(linkedAccountId),
      targetDate: targetDate?.toUtc(),
      icon: icon.trim().isEmpty ? 'flag' : icon.trim(),
      color: color,
      status: resolvedStatus,
      createdAt: resolvedCreatedAt,
      updatedAt: (updatedAt ?? resolvedCreatedAt).toUtc(),
      archivedAt: isArchived ? (archivedAt ?? now).toUtc() : null,
      completedAt: isComplete ? (completedAt ?? now).toUtc() : null,
    );
  }

  factory Goal.fromJson(Map<String, dynamic> json) => _$GoalFromJson(json);

  bool get isArchived => status == GoalStatus.archived || archivedAt != null;
}

String? _trimmedOrNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
