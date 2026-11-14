import '../../../../core/error/result.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';

class UpdateBudget {
  const UpdateBudget(this._repository);
  final BudgetRepository _repository;
  Future<AppResult<Budget>> call(Budget budget) =>
      _repository.updateBudget(budget);
}
