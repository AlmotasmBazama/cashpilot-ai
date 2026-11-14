import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/serialization/decimal_converter.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../enums/budget_period_type.dart';
import '../failures/budget_failure_codes.dart';

part 'budget.freezed.dart';
part 'budget.g.dart';

@freezed
abstract class Budget with _$Budget {
  const Budget._();

  const factory Budget({
    required String id,
    required String name,
    required String categoryId,
    @DecimalConverter() required Decimal amount,
    required String currency,
    required BudgetPeriodType periodType,
    required DateTime startDate,
    required DateTime endDate,
    required int alertThresholdPercent,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) = _Budget;

  factory Budget.create({
    required String name,
    required String categoryId,
    required Decimal amount,
    required String currency,
    required DateTime startDate,
    required DateTime endDate,
    String? id,
    BudgetPeriodType periodType = BudgetPeriodType.monthly,
    int alertThresholdPercent = 80,
    bool isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const BudgetValidationException(
        code: BudgetFailureCodes.invalidName,
        message: 'Budget name is required.',
      );
    }
    final normalizedCategoryId = categoryId.trim();
    if (normalizedCategoryId.isEmpty) {
      throw const BudgetValidationException(
        code: BudgetFailureCodes.invalidCategory,
        message: 'Budget category is required.',
      );
    }
    if (amount <= Decimal.zero) {
      throw const BudgetValidationException(
        code: BudgetFailureCodes.invalidAmount,
        message: 'Budget amount must be greater than zero.',
      );
    }
    final normalizedCurrency = currency.trim().toUpperCase();
    if (CurrencyCatalog.findByCode(normalizedCurrency) == null) {
      throw const BudgetValidationException(
        code: BudgetFailureCodes.invalidCurrency,
        message: 'Budget currency is not supported.',
      );
    }
    if (alertThresholdPercent < 0 || alertThresholdPercent > 100) {
      throw const BudgetValidationException(
        code: BudgetFailureCodes.invalidThreshold,
        message: 'Budget threshold must be between 0 and 100.',
      );
    }
    final normalizedStart = startDate.toUtc();
    final normalizedEnd = endDate.toUtc();
    if (!normalizedStart.isBefore(normalizedEnd)) {
      throw const BudgetValidationException(
        code: BudgetFailureCodes.invalidPeriod,
        message: 'Budget start date must be before its end date.',
      );
    }

    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = (createdAt ?? now).toUtc();
    return Budget(
      id: id ?? const Uuid().v7(),
      name: normalizedName,
      categoryId: normalizedCategoryId,
      amount: amount,
      currency: normalizedCurrency,
      periodType: periodType,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      alertThresholdPercent: alertThresholdPercent,
      isActive: isActive,
      createdAt: resolvedCreatedAt,
      updatedAt: (updatedAt ?? resolvedCreatedAt).toUtc(),
      archivedAt: archivedAt?.toUtc(),
    );
  }

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);

  bool get isArchived => archivedAt != null;
}
