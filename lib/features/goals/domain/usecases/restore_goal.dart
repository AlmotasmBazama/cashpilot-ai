import '../../../../core/error/result.dart';
import '../entities/goal.dart';
import '../repositories/goal_repository.dart';

class RestoreGoalUseCase {
  const RestoreGoalUseCase(this._repository);
  final GoalRepository _repository;
  Future<AppResult<Goal>> call(String id) => _repository.restoreGoal(id);
}
