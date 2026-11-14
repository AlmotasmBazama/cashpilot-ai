import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/sync_providers.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../data/datasources/local/goals_local_data_source.dart';
import '../../data/repositories/goal_repository_impl.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_contribution.dart';
import '../../domain/entities/goal_progress.dart';
import '../../domain/enums/goal_status.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/services/goal_progress_calculator.dart';
import '../../domain/usecases/add_goal_contribution.dart';
import '../../domain/usecases/archive_goal.dart';
import '../../domain/usecases/calculate_goal_progress.dart';
import '../../domain/usecases/create_goal.dart';
import '../../domain/usecases/restore_goal.dart';
import '../../domain/usecases/reverse_goal_contribution.dart';
import '../../domain/usecases/update_goal.dart';
import '../../domain/usecases/watch_goal_contributions.dart';
import '../../domain/usecases/watch_goals.dart';

final goalsLocalDataSourceProvider = Provider<GoalsLocalDataSource>(
  (ref) => DriftGoalsLocalDataSource(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'goalsLocalDataSourceProvider',
);

final goalProgressCalculatorProvider = Provider<GoalProgressCalculator>(
  (_) => const GoalProgressCalculator(),
  name: 'goalProgressCalculatorProvider',
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepositoryImpl(
    localDataSource: ref.watch(goalsLocalDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
    progressCalculator: ref.watch(goalProgressCalculatorProvider),
    syncQueue: ref.watch(syncMutationQueueProvider),
  ),
  name: 'goalRepositoryProvider',
);

final watchGoalsUseCaseProvider = Provider<WatchGoalsUseCase>(
  (ref) => WatchGoalsUseCase(ref.watch(goalRepositoryProvider)),
  name: 'watchGoalsUseCaseProvider',
);
final createGoalUseCaseProvider = Provider<CreateGoalUseCase>(
  (ref) => CreateGoalUseCase(ref.watch(goalRepositoryProvider)),
  name: 'createGoalUseCaseProvider',
);
final updateGoalUseCaseProvider = Provider<UpdateGoalUseCase>(
  (ref) => UpdateGoalUseCase(ref.watch(goalRepositoryProvider)),
  name: 'updateGoalUseCaseProvider',
);
final archiveGoalUseCaseProvider = Provider<ArchiveGoalUseCase>(
  (ref) => ArchiveGoalUseCase(ref.watch(goalRepositoryProvider)),
  name: 'archiveGoalUseCaseProvider',
);
final restoreGoalUseCaseProvider = Provider<RestoreGoalUseCase>(
  (ref) => RestoreGoalUseCase(ref.watch(goalRepositoryProvider)),
  name: 'restoreGoalUseCaseProvider',
);
final addGoalContributionUseCaseProvider = Provider<AddGoalContributionUseCase>(
  (ref) => AddGoalContributionUseCase(
    repository: ref.watch(goalRepositoryProvider),
    convertMoney: ref.watch(convertMoneyUseCaseProvider).call,
  ),
  name: 'addGoalContributionUseCaseProvider',
);
final reverseGoalContributionUseCaseProvider =
    Provider<ReverseGoalContributionUseCase>(
      (ref) =>
          ReverseGoalContributionUseCase(ref.watch(goalRepositoryProvider)),
      name: 'reverseGoalContributionUseCaseProvider',
    );
final watchGoalContributionsUseCaseProvider =
    Provider<WatchGoalContributionsUseCase>(
      (ref) => WatchGoalContributionsUseCase(ref.watch(goalRepositoryProvider)),
      name: 'watchGoalContributionsUseCaseProvider',
    );
final calculateGoalProgressUseCaseProvider =
    Provider<CalculateGoalProgressUseCase>(
      (ref) => CalculateGoalProgressUseCase(ref.watch(goalRepositoryProvider)),
      name: 'calculateGoalProgressUseCaseProvider',
    );

final goalsProvider = StreamProvider<AppResult<List<Goal>>>(
  (ref) => ref.watch(watchGoalsUseCaseProvider)(),
  name: 'goalsProvider',
);
final allGoalsProvider = StreamProvider<AppResult<List<Goal>>>(
  (ref) => ref.watch(watchGoalsUseCaseProvider)(includeArchived: true),
  name: 'allGoalsProvider',
);
final goalByIdProvider = FutureProvider.family<AppResult<Goal?>, String>(
  (ref, id) => ref.watch(goalRepositoryProvider).getGoalById(id),
  name: 'goalByIdProvider',
);
final goalContributionsProvider =
    StreamProvider.family<AppResult<List<GoalContribution>>, String>(
      (ref, id) => ref.watch(watchGoalContributionsUseCaseProvider)(id),
      name: 'goalContributionsProvider',
    );
final goalProgressProvider = FutureProvider<AppResult<List<GoalProgress>>>((
  ref,
) async {
  final result = await ref.watch(goalsProvider.future);
  return switch (result) {
    AppSuccess<List<Goal>>(:final data) => AppResult.success(
      data
          .map(
            (goal) => ref
                .watch(goalProgressCalculatorProvider)
                .calculate(goal, now: DateTime.now().toUtc()),
          )
          .toList(growable: false),
    ),
    AppFailure<List<Goal>>(:final failure) => AppResult.failure(failure),
  };
}, name: 'goalProgressProvider');
final allGoalProgressProvider = FutureProvider<AppResult<List<GoalProgress>>>((
  ref,
) async {
  final result = await ref.watch(allGoalsProvider.future);
  return switch (result) {
    AppSuccess<List<Goal>>(:final data) => AppResult.success(
      data
          .map(
            (goal) => ref
                .watch(goalProgressCalculatorProvider)
                .calculate(goal, now: DateTime.now().toUtc()),
          )
          .toList(growable: false),
    ),
    AppFailure<List<Goal>>(:final failure) => AppResult.failure(failure),
  };
}, name: 'allGoalProgressProvider');
final goalSummaryProvider = FutureProvider<AppResult<GoalSummary>>((ref) async {
  final result = await ref.watch(allGoalProgressProvider.future);
  return switch (result) {
    AppSuccess<List<GoalProgress>>(:final data) => AppResult.success(
      GoalSummary.from(data),
    ),
    AppFailure<List<GoalProgress>>(:final failure) => AppResult.failure(
      failure,
    ),
  };
}, name: 'goalSummaryProvider');

class GoalCurrencyTotal {
  const GoalCurrencyTotal({required this.currency, required this.amount});
  final String currency;
  final Decimal amount;
}

class GoalSummary {
  const GoalSummary({
    required this.activeCount,
    required this.savedTotals,
    required this.nearestTargetDate,
    required this.completedCount,
  });

  final int activeCount;
  final List<GoalCurrencyTotal> savedTotals;
  final DateTime? nearestTargetDate;
  final int completedCount;

  factory GoalSummary.from(List<GoalProgress> values) {
    final totals = <String, Decimal>{};
    DateTime? nearest;
    var activeCount = 0;
    var completedCount = 0;
    for (final progress in values) {
      if (progress.status == GoalStatus.completed) {
        completedCount++;
      }
      if (progress.status != GoalStatus.active &&
          progress.status != GoalStatus.paused) {
        continue;
      }
      activeCount++;
      final goal = progress.goal;
      totals.update(
        goal.currency,
        (amount) => amount + progress.currentAmount,
        ifAbsent: () => progress.currentAmount,
      );
      final date = goal.targetDate;
      if (date != null && (nearest == null || date.isBefore(nearest))) {
        nearest = date;
      }
    }
    return GoalSummary(
      activeCount: activeCount,
      savedTotals: totals.entries
          .map(
            (entry) =>
                GoalCurrencyTotal(currency: entry.key, amount: entry.value),
          )
          .toList(growable: false),
      nearestTargetDate: nearest,
      completedCount: completedCount,
    );
  }
}
