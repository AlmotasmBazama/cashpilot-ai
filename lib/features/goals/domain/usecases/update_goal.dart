import '../../../../core/error/result.dart';
import '../entities/goal.dart';
import '../repositories/goal_repository.dart';

class UpdateGoalUseCase {
  const UpdateGoalUseCase(this._repository);
  final GoalRepository _repository;
  Future<AppResult<Goal>> call(Goal goal) => _repository.updateGoal(goal);
}
