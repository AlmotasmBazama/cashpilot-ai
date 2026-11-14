import '../../../../core/error/result.dart';
import '../entities/budget.dart';
import '../repositories/budget_repository.dart';

class WatchBudgets {
  const WatchBudgets(this._repository);
  final BudgetRepository _repository;
  Stream<AppResult<List<Budget>>> call({bool includeArchived = false}) =>
      _repository.watchBudgets(includeArchived: includeArchived);
}
