import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/goals/data/datasources/local/goals_local_data_source.dart';
import 'package:cashpilot_ai/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal_contribution.dart';
import 'package:cashpilot_ai/features/goals/domain/enums/goal_status.dart';
import 'package:cashpilot_ai/features/goals/domain/failures/goal_failure_codes.dart';
import 'package:cashpilot_ai/features/goals/domain/repositories/goal_repository.dart';
import 'package:cashpilot_ai/features/goals/domain/services/goal_progress_calculator.dart';
import 'package:cashpilot_ai/features/goals/domain/usecases/add_goal_contribution.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  group('Goal domain', () {
    test('creates a valid goal', () {
      final value = goal();

      expect(value.title, 'Laptop');
      expect(value.targetAmount, Decimal.fromInt(3000));
      expect(value.currentAmount, Decimal.zero);
      expect(value.status, GoalStatus.active);
    });

    test('rejects an invalid target and overfunding', () {
      expect(
        () => goal(target: Decimal.zero),
        throwsA(
          isA<GoalValidationException>().having(
            (error) => error.code,
            'code',
            GoalFailureCodes.invalidAmount,
          ),
        ),
      );
      expect(
        () => goal(target: Decimal.fromInt(100), current: Decimal.fromInt(101)),
        throwsA(
          isA<GoalValidationException>().having(
            (error) => error.code,
            'code',
            GoalFailureCodes.overfunding,
          ),
        ),
      );
    });
  });

  group('Goal progress', () {
    const calculator = GoalProgressCalculator();

    test('calculates remaining, percent, days, and monthly needed', () {
      final progress = calculator.calculate(
        goal(
          target: Decimal.fromInt(1200),
          current: Decimal.fromInt(300),
          targetDate: DateTime.utc(2026, 10, 12),
        ),
        now: DateTime.utc(2026, 7, 14),
      );

      expect(progress.remainingAmount, Decimal.fromInt(900));
      expect(progress.progressPercent, Decimal.fromInt(25));
      expect(progress.daysRemaining, 90);
      expect(progress.monthlyNeeded, Decimal.fromInt(300));
    });
  });

  group('Goal repository and contributions', () {
    late AppDatabase database;
    late GoalRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = GoalRepositoryImpl(
        localDataSource: DriftGoalsLocalDataSource(scopedTestSession(database)),
        logger: AppLogger.instance,
      );
    });

    tearDown(() => database.close());

    test('creates, updates, watches, archives, and restores', () async {
      final initial = await repository
          .watchGoals(includeArchived: true)
          .first
          .then((result) => result.expectSuccess());
      final created = (await repository.createGoal(goal())).expectSuccess();
      final watched = await repository
          .watchGoals(includeArchived: true)
          .first
          .then((result) => result.expectSuccess());
      final updated = (await repository.updateGoal(
        created.copyWith(title: 'Work laptop'),
      )).expectSuccess();
      final archived = (await repository.archiveGoal(
        created.id,
      )).expectSuccess();
      final restored = (await repository.restoreGoal(
        created.id,
      )).expectSuccess();

      expect(initial, isEmpty);
      expect(watched.single.id, created.id);
      expect(updated.title, 'Work laptop');
      expect(archived.status, GoalStatus.archived);
      expect(archived.archivedAt, isNotNull);
      expect(restored.status, GoalStatus.active);
      expect(restored.archivedAt, isNull);
    });

    test(
      'contribution adds progress, completes, and reverses atomically',
      () async {
        final created = (await repository.createGoal(
          goal(target: Decimal.fromInt(100)),
        )).expectSuccess();
        final useCase = AddGoalContributionUseCase(
          repository: repository,
          convertMoney: (_, _) async => throw StateError('not called'),
        );
        final added = (await useCase(
          contribution(created.id, amount: Decimal.fromInt(100)),
        )).expectSuccess();
        final completed = (await repository.getGoalById(
          created.id,
        )).expectSuccess()!;
        final history = await repository
            .watchGoalContributions(created.id)
            .first
            .then((result) => result.expectSuccess());
        final reversed = (await repository.reverseContribution(
          added.id,
        )).expectSuccess();
        final afterReverse = (await repository.getGoalById(
          created.id,
        )).expectSuccess()!;

        expect(completed.currentAmount, Decimal.fromInt(100));
        expect(completed.status, GoalStatus.completed);
        expect(completed.completedAt, isNotNull);
        expect(history.single.creditedAmount, Decimal.fromInt(100));
        expect(reversed.isReversed, isTrue);
        expect(afterReverse.currentAmount, Decimal.zero);
        expect(afterReverse.status, GoalStatus.active);
        expect(afterReverse.completedAt, isNull);
      },
    );

    test(
      'multi-currency contribution converts once and missing rate fails',
      () async {
        final created = (await repository.createGoal(goal())).expectSuccess();
        var conversionCalls = 0;
        final converted = AddGoalContributionUseCase(
          repository: repository,
          convertMoney: (money, currency) async {
            conversionCalls++;
            return AppResult.success(
              Money(
                amount: money.amount * Decimal.parse('7.5'),
                currencyCode: currency,
              ),
            );
          },
        );
        final result = (await converted(
          contribution(
            created.id,
            amount: Decimal.fromInt(10),
            currency: 'USD',
          ),
        )).expectSuccess();

        expect(result.creditedAmount, Decimal.fromInt(75));
        expect(conversionCalls, 1);

        final missing = AddGoalContributionUseCase(
          repository: repository,
          convertMoney: (_, _) async =>
              const AppResult.failure(Failure(message: 'Missing rate.')),
        );
        final failure = await missing(
          contribution(created.id, amount: Decimal.one, currency: 'EUR'),
        );
        expect(
          failure,
          isA<AppFailure<GoalContribution>>().having(
            (value) => value.failure.code,
            'code',
            GoalFailureCodes.missingExchangeRate,
          ),
        );
      },
    );
  });
}

Goal goal({Decimal? target, Decimal? current, DateTime? targetDate}) =>
    Goal.create(
      title: 'Laptop',
      targetAmount: target ?? Decimal.fromInt(3000),
      currentAmount: current,
      currency: 'LYD',
      targetDate: targetDate,
    );

GoalContribution contribution(
  String goalId, {
  required Decimal amount,
  String currency = 'LYD',
}) =>
    GoalContribution.create(goalId: goalId, amount: amount, currency: currency);

extension _ResultTestX<T> on AppResult<T> {
  T expectSuccess() => switch (this) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => throw TestFailure(failure.message),
  };
}
