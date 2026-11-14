import 'package:decimal/decimal.dart';

class GoalContributionDto {
  const GoalContributionDto({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.currency,
    required this.creditedAmount,
    required this.date,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    this.linkedTransactionId,
    this.reversedAt,
  });

  final String id;
  final String goalId;
  final Decimal amount;
  final String currency;
  final Decimal creditedAmount;
  final DateTime date;
  final String note;
  final String? linkedTransactionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reversedAt;

  GoalContributionDto copyWith({
    Decimal? creditedAmount,
    DateTime? updatedAt,
    DateTime? reversedAt,
  }) {
    return GoalContributionDto(
      id: id,
      goalId: goalId,
      amount: amount,
      currency: currency,
      creditedAmount: creditedAmount ?? this.creditedAmount,
      date: date,
      note: note,
      linkedTransactionId: linkedTransactionId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reversedAt: reversedAt ?? this.reversedAt,
    );
  }
}
