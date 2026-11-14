import '../../../../core/error/result.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';

class RestoreBudget {
  const RestoreBudget(this._repository);
  final BudgetRepository _repository;
  Future<AppResult<Budget>> call(String id) => _repository.restoreBudget(id);
}
