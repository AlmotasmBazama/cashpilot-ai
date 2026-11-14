import '../../../../core/error/result.dart';
import '../entities/budget.dart';

abstract interface class BudgetRepository {
  Stream<AppResult<List<Budget>>> watchBudgets({bool includeArchived = false});
  Future<AppResult<Budget?>> getBudgetById(String id);
  Future<AppResult<Budget>> createBudget(Budget budget);
  Future<AppResult<Budget>> updateBudget(Budget budget);
  Future<AppResult<Budget>> archiveBudget(String id);
  Future<AppResult<Budget>> restoreBudget(String id);
  Future<AppResult<List<Budget>>> getActiveBudgetsForPeriod(
    DateTime from,
    DateTime to,
  );
}
