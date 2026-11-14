import '../../../../core/error/result.dart';
import '../entities/expense_analytics.dart';

abstract interface class ExpenseAnalyticsRepository {
  Stream<AppResult<ExpenseAnalyticsSnapshot>> watch(
    ExpenseAnalyticsQuery query,
  );

  Future<AppResult<ExpenseAnalyticsSnapshot>> load(ExpenseAnalyticsQuery query);
}
