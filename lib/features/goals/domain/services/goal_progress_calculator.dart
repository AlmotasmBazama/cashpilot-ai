import 'package:decimal/decimal.dart';

import '../entities/goal.dart';
import '../entities/goal_progress.dart';
import '../enums/goal_status.dart';

class GoalProgressCalculator {
  const GoalProgressCalculator();

  GoalProgress calculate(Goal goal, {required DateTime now}) {
    final current = goal.currentAmount;
    final remaining = goal.targetAmount - current;
    final percent =
        (current / goal.targetAmount).toDecimal(scaleOnInfinitePrecision: 8) *
        Decimal.fromInt(100);
    final targetDate = goal.targetDate;
    final daysRemaining = targetDate
        ?.toUtc()
        .difference(now.toUtc())
        .inDays
        .clamp(0, 1 << 31);
    final monthsRemaining = daysRemaining == null
        ? null
        : ((daysRemaining + 29) ~/ 30).clamp(1, 1 << 30);
    final monthlyNeeded = monthsRemaining == null
        ? null
        : (remaining / Decimal.fromInt(monthsRemaining)).toDecimal(
            scaleOnInfinitePrecision: 8,
          );
    final status = goal.isArchived
        ? GoalStatus.archived
        : current == goal.targetAmount
        ? GoalStatus.completed
        : goal.status == GoalStatus.completed
        ? GoalStatus.active
        : goal.status;
    return GoalProgress(
      goal: goal,
      currentAmount: current,
      remainingAmount: remaining,
      progressPercent: percent,
      daysRemaining: daysRemaining,
      monthlyNeeded: monthlyNeeded,
      status: status,
    );
  }
}
