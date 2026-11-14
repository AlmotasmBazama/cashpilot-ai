import '../../../../core/error/result.dart';
import '../entities/goal.dart';
import '../repositories/goal_repository.dart';

class CreateGoalUseCase {
  const CreateGoalUseCase(this._repository);
  final GoalRepository _repository;
  Future<AppResult<Goal>> call(Goal goal) => _repository.createGoal(goal);
}
