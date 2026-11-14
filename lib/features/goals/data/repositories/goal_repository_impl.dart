import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_contribution.dart';
import '../../domain/entities/goal_progress.dart';
import '../../domain/enums/goal_status.dart';
import '../../domain/failures/goal_failure_codes.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/services/goal_progress_calculator.dart';
import '../datasources/local/goals_local_data_source.dart';
import '../mappers/goal_contribution_mapper.dart';
import '../mappers/goal_mapper.dart';

class GoalRepositoryImpl implements GoalRepository {
  const GoalRepositoryImpl({
    required GoalsLocalDataSource localDataSource,
    required AppLogger logger,
    GoalProgressCalculator progressCalculator = const GoalProgressCalculator(),
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _logger = logger,
       _progressCalculator = progressCalculator,
       _syncQueue = syncQueue;

  final GoalsLocalDataSource _localDataSource;
  final AppLogger _logger;
  final GoalProgressCalculator _progressCalculator;
  final SyncMutationQueue? _syncQueue;

  @override
  Stream<AppResult<List<Goal>>> watchGoals({
    bool includeArchived = false,
  }) async* {
    try {
      await for (final rows in _localDataSource.watchGoals(
        includeArchived: includeArchived,
      )) {
        yield AppResult.success(
          rows.map((row) => row.toDomain()).toList(growable: false),
        );
      }
    } on Object catch (error, stackTrace) {
      yield _failure('Unable to watch goals.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Goal?>> getGoalById(String id) async {
    try {
      return AppResult.success(
        (await _localDataSource.getGoalById(id))?.toDomain(),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load goal.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Goal>> createGoal(Goal goal) async {
    try {
      final result = (await _localDataSource.createGoal(
        goal.toDto(),
      )).toDomain();
      await _queueGoal(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to create goal.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Goal>> updateGoal(Goal goal) async {
    try {
      final normalized = _validatedCopy(
        goal,
        updatedAt: DateTime.now().toUtc(),
      );
      final result = (await _localDataSource.updateGoal(
        normalized.toDto(),
      )).toDomain();
      await _queueGoal(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to update goal.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Goal>> archiveGoal(String id) => _setArchived(id, true);

  @override
  Future<AppResult<Goal>> restoreGoal(String id) => _setArchived(id, false);

  @override
  Future<AppResult<GoalContribution>> addContribution(
    GoalContribution contribution,
  ) async {
    try {
      final result = (await _localDataSource.addContribution(
        contribution.toDto(),
      )).toDomain();
      await _queueGoalSnapshot(result.goalId);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to add goal contribution.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<GoalContribution>> reverseContribution(String id) async {
    try {
      final result = (await _localDataSource.reverseContribution(
        id,
      )).toDomain();
      await _queueGoalSnapshot(result.goalId);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure(
        'Unable to reverse goal contribution.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Stream<AppResult<List<GoalContribution>>> watchGoalContributions(
    String goalId,
  ) async* {
    try {
      await for (final rows in _localDataSource.watchGoalContributions(
        goalId,
      )) {
        yield AppResult.success(
          rows.map((row) => row.toDomain()).toList(growable: false),
        );
      }
    } on Object catch (error, stackTrace) {
      yield _failure('Unable to watch goal contributions.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<GoalProgress>> calculateGoalProgress(
    String goalId, {
    DateTime? now,
  }) async {
    final result = await getGoalById(goalId);
    return switch (result) {
      AppSuccess<Goal?>(data: final goal?) => AppResult.success(
        _progressCalculator.calculate(goal, now: now ?? DateTime.now().toUtc()),
      ),
      AppSuccess<Goal?>(data: null) => const AppResult.failure(
        Failure(message: 'Goal not found.', code: GoalFailureCodes.notFound),
      ),
      AppFailure<Goal?>(:final failure) => AppResult.failure(failure),
    };
  }

  Future<AppResult<Goal>> _setArchived(String id, bool archived) async {
    try {
      final existing = await _localDataSource.getGoalById(id);
      if (existing == null) {
        throw const GoalValidationException(
          code: GoalFailureCodes.notFound,
          message: 'Goal not found.',
        );
      }
      final goal = existing.toDomain();
      final now = DateTime.now().toUtc();
      final updated = goal.copyWith(
        status: archived
            ? GoalStatus.archived
            : goal.currentAmount == goal.targetAmount
            ? GoalStatus.completed
            : GoalStatus.active,
        archivedAt: archived ? now : null,
        updatedAt: now,
      );
      final result = (await _localDataSource.updateGoal(
        updated.toDto(),
      )).toDomain();
      await _queueGoal(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure(
        'Unable to update goal archive state.',
        error,
        stackTrace,
      );
    }
  }

  Goal _validatedCopy(Goal goal, {required DateTime updatedAt}) => Goal.create(
    id: goal.id,
    title: goal.title,
    description: goal.description,
    type: goal.type,
    targetAmount: goal.targetAmount,
    currentAmount: goal.currentAmount,
    currency: goal.currency,
    linkedAccountId: goal.linkedAccountId,
    targetDate: goal.targetDate,
    icon: goal.icon,
    color: goal.color,
    status: goal.status,
    createdAt: goal.createdAt,
    updatedAt: updatedAt,
    archivedAt: goal.archivedAt,
    completedAt: goal.completedAt,
  );

  AppResult<T> _failure<T>(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(message, error, stackTrace);
    return switch (error) {
      GoalValidationException(:final code, :final message) => AppResult.failure(
        Failure(message: message, code: code),
      ),
      AppException(:final code, :final message) => AppResult.failure(
        Failure(message: message, code: code),
      ),
      _ => AppResult.failure(Failure(message: message)),
    };
  }

  Future<void> _queueGoal(Goal goal, {List<GoalContribution>? contributions}) {
    final payload = Map<String, dynamic>.from(goal.toJson());
    if (contributions != null) {
      payload['contributions'] = contributions
          .map((contribution) => contribution.toJson())
          .toList(growable: false);
    }
    return enqueueSyncUpsertBestEffort(
      queue: _syncQueue,
      entityType: SyncEntityType.goal,
      entityId: goal.id,
      payload: payload,
      logger: _logger,
    );
  }

  Future<void> _queueGoalSnapshot(String goalId) async {
    if (_syncQueue == null) {
      return;
    }
    try {
      final goal = (await _localDataSource.getGoalById(goalId))?.toDomain();
      if (goal == null) {
        return;
      }
      final contributions =
          (await _localDataSource.watchGoalContributions(goalId).first)
              .map((item) => item.toDomain())
              .toList(growable: false);
      await _queueGoal(goal, contributions: contributions);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Goal changed locally, but its backup snapshot was not queued.',
        error,
        stackTrace,
      );
    }
  }
}
