import '../../../../core/error/result.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';

class GetActiveBudgets {
  const GetActiveBudgets(this._repository);
  final BudgetRepository _repository;
  Future<AppResult<List<Budget>>> call(DateTime from, DateTime to) =>
      _repository.getActiveBudgetsForPeriod(from, to);
}
