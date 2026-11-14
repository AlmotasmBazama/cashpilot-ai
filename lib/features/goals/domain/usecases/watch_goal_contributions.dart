import '../../../../core/error/result.dart';
import '../entities/goal_contribution.dart';
import '../repositories/goal_repository.dart';

class WatchGoalContributionsUseCase {
  const WatchGoalContributionsUseCase(this._repository);
  final GoalRepository _repository;
  Stream<AppResult<List<GoalContribution>>> call(String goalId) =>
      _repository.watchGoalContributions(goalId);
}
