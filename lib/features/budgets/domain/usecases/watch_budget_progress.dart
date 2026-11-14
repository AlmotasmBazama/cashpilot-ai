import '../../../../core/error/result.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../entities/budget.dart';
import '../entities/budget_progress.dart';
import '../repositories/budget_repository.dart';
import 'calculate_budget_progress.dart';

class WatchBudgetProgress {
  const WatchBudgetProgress({
    required BudgetRepository repository,
    required CalculateBudgetProgress calculateProgress,
  }) : _repository = repository,
       _calculateProgress = calculateProgress;

  final BudgetRepository _repository;
  final CalculateBudgetProgress _calculateProgress;

  Stream<AppResult<List<BudgetProgress>>> call({
    required List<Transaction> transactions,
    required DateTime now,
    bool includeArchived = false,
  }) async* {
    await for (final result in _repository.watchBudgets(
      includeArchived: includeArchived,
    )) {
      switch (result) {
        case AppSuccess<List<Budget>>(:final data):
          final progress = <BudgetProgress>[];
          for (final budget in data) {
            progress.add(
              await _calculateProgress(
                budget: budget,
                transactions: transactions,
                now: now,
              ),
            );
          }
          yield AppResult.success(progress);
        case AppFailure<List<Budget>>(:final failure):
          yield AppResult.failure(failure);
      }
    }
  }
}
