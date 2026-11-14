import '../entities/budget.dart';
import '../enums/budget_period_type.dart';

class BudgetPeriod {
  const BudgetPeriod({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

class BudgetPeriodResolver {
  const BudgetPeriodResolver();

  BudgetPeriod resolve(Budget budget, DateTime now) {
    final at = now.toUtc();
    return switch (budget.periodType) {
      BudgetPeriodType.weekly => _week(at),
      BudgetPeriodType.monthly => _month(at),
      BudgetPeriodType.yearly => _year(at),
      BudgetPeriodType.custom => BudgetPeriod(
        start: budget.startDate.toUtc(),
        end: budget.endDate.toUtc(),
      ),
    };
  }

  BudgetPeriod _week(DateTime at) {
    final day = DateTime.utc(at.year, at.month, at.day);
    final start = day.subtract(Duration(days: at.weekday - DateTime.monday));
    return BudgetPeriod(start: start, end: start.add(const Duration(days: 7)));
  }

  BudgetPeriod _month(DateTime at) {
    final start = DateTime.utc(at.year, at.month);
    return BudgetPeriod(start: start, end: DateTime.utc(at.year, at.month + 1));
  }

  BudgetPeriod _year(DateTime at) {
    return BudgetPeriod(
      start: DateTime.utc(at.year),
      end: DateTime.utc(at.year + 1),
    );
  }
}
