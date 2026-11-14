import 'package:decimal/decimal.dart';

import 'goal.dart';
import '../enums/goal_status.dart';

class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.currentAmount,
    required this.remainingAmount,
    required this.progressPercent,
    required this.daysRemaining,
    required this.monthlyNeeded,
    required this.status,
  });

  final Goal goal;
  final Decimal currentAmount;
  final Decimal remainingAmount;
  final Decimal progressPercent;
  final int? daysRemaining;
  final Decimal? monthlyNeeded;
  final GoalStatus status;
}
