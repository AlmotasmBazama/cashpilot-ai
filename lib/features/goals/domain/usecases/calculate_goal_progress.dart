import '../../../../core/error/result.dart';
import '../entities/goal_progress.dart';
import '../repositories/goal_repository.dart';

class CalculateGoalProgressUseCase {
  const CalculateGoalProgressUseCase(this._repository);
  final GoalRepository _repository;
  Future<AppResult<GoalProgress>> call(String goalId, {DateTime? now}) =>
      _repository.calculateGoalProgress(goalId, now: now);
}
