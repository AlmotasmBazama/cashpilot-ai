import '../../../../core/error/result.dart';
import '../entities/goal.dart';
import '../entities/goal_contribution.dart';
import '../entities/goal_progress.dart';

abstract interface class GoalRepository {
  Stream<AppResult<List<Goal>>> watchGoals({bool includeArchived = false});
  Future<AppResult<Goal?>> getGoalById(String id);
  Future<AppResult<Goal>> createGoal(Goal goal);
  Future<AppResult<Goal>> updateGoal(Goal goal);
  Future<AppResult<Goal>> archiveGoal(String id);
  Future<AppResult<Goal>> restoreGoal(String id);
  Future<AppResult<GoalContribution>> addContribution(
    GoalContribution contribution,
  );
  Future<AppResult<GoalContribution>> reverseContribution(String id);
  Stream<AppResult<List<GoalContribution>>> watchGoalContributions(
    String goalId,
  );
  Future<AppResult<GoalProgress>> calculateGoalProgress(
    String goalId, {
    DateTime? now,
  });
}
