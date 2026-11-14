import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/serialization/decimal_converter.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../failures/goal_failure_codes.dart';

part 'goal_contribution.freezed.dart';
part 'goal_contribution.g.dart';

@freezed
abstract class GoalContribution with _$GoalContribution {
  const GoalContribution._();

  const factory GoalContribution({
    required String id,
    required String goalId,
    @DecimalConverter() required Decimal amount,
    required String currency,
    @DecimalConverter() Decimal? creditedAmount,
    required DateTime date,
    required String note,
    String? linkedTransactionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? reversedAt,
  }) = _GoalContribution;

  factory GoalContribution.create({
    required String goalId,
    required Decimal amount,
    required String currency,
    Decimal? creditedAmount,
    DateTime? date,
    String note = '',
    String? linkedTransactionId,
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reversedAt,
  }) {
    final normalizedGoalId = goalId.trim();
    if (normalizedGoalId.isEmpty || amount <= Decimal.zero) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidContribution,
        message: 'A positive contribution and goal are required.',
      );
    }
    if (creditedAmount != null && creditedAmount <= Decimal.zero) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidContribution,
        message: 'Credited contribution amount must be positive.',
      );
    }
    final normalizedCurrency = currency.trim().toUpperCase();
    if (CurrencyCatalog.findByCode(normalizedCurrency) == null) {
      throw const GoalValidationException(
        code: GoalFailureCodes.invalidCurrency,
        message: 'Contribution currency is not supported.',
      );
    }
    final now = DateTime.now().toUtc();
    final resolvedCreatedAt = (createdAt ?? now).toUtc();
    return GoalContribution(
      id: id ?? const Uuid().v7(),
      goalId: normalizedGoalId,
      amount: amount,
      currency: normalizedCurrency,
      creditedAmount: creditedAmount,
      date: (date ?? now).toUtc(),
      note: note.trim(),
      linkedTransactionId: _trimmedOrNull(linkedTransactionId),
      createdAt: resolvedCreatedAt,
      updatedAt: (updatedAt ?? resolvedCreatedAt).toUtc(),
      reversedAt: reversedAt?.toUtc(),
    );
  }

  factory GoalContribution.fromJson(Map<String, dynamic> json) =>
      _$GoalContributionFromJson(json);

  bool get isReversed => reversedAt != null;
}

String? _trimmedOrNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
