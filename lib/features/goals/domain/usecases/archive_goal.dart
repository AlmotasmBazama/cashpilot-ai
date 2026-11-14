import '../../../../core/error/result.dart';
import '../entities/goal.dart';
import '../repositories/goal_repository.dart';

class ArchiveGoalUseCase {
  const ArchiveGoalUseCase(this._repository);
  final GoalRepository _repository;
  Future<AppResult<Goal>> call(String id) => _repository.archiveGoal(id);
}
