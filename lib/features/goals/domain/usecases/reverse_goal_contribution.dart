import '../../../../core/error/result.dart';
import '../entities/goal_contribution.dart';
import '../repositories/goal_repository.dart';

class ReverseGoalContributionUseCase {
  const ReverseGoalContributionUseCase(this._repository);
  final GoalRepository _repository;
  Future<AppResult<GoalContribution>> call(String id) =>
      _repository.reverseContribution(id);
}
