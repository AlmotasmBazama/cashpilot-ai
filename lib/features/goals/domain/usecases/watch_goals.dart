import '../../../../core/error/result.dart';
import '../entities/goal.dart';
import '../repositories/goal_repository.dart';

class WatchGoalsUseCase {
  const WatchGoalsUseCase(this._repository);
  final GoalRepository _repository;
  Stream<AppResult<List<Goal>>> call({bool includeArchived = false}) =>
      _repository.watchGoals(includeArchived: includeArchived);
}
