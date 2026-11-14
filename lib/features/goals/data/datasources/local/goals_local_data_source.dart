import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../domain/enums/goal_status.dart';
import '../../../domain/failures/goal_failure_codes.dart';
import '../../dtos/goal_contribution_dto.dart';
import '../../dtos/goal_dto.dart';
import '../../mappers/goal_contribution_mapper.dart';
import '../../mappers/goal_mapper.dart';

abstract interface class GoalsLocalDataSource {
  Stream<List<GoalDto>> watchGoals({bool includeArchived = false});
  Future<GoalDto?> getGoalById(String id);
  Future<GoalDto> createGoal(GoalDto goal);
  Future<GoalDto> updateGoal(GoalDto goal);
  Future<GoalContributionDto> addContribution(GoalContributionDto value);
  Future<GoalContributionDto> reverseContribution(String id);
  Stream<List<GoalContributionDto>> watchGoalContributions(String goalId);
}

class DriftGoalsLocalDataSource implements GoalsLocalDataSource {
  const DriftGoalsLocalDataSource(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Stream<List<GoalDto>> watchGoals({bool includeArchived = false}) {
    final query = _database.select(_database.goals);
    query.where((row) => row.ownerScopeId.equals(_scope));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    query.orderBy([
      (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
    ]);
    return _session
        .guardStream(query.watch())
        .map((rows) => rows.map((row) => row.toDto()).toList(growable: false));
  }

  @override
  Future<GoalDto?> getGoalById(String id) async {
    final row =
        await (_database.select(_database.goals)..where(
              (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
            ))
            .getSingleOrNull();
    return row?.toDto();
  }

  @override
  Future<GoalDto> createGoal(GoalDto goal) async {
    return _session.runGuardedWrite(() async {
      await _database
          .into(_database.goals)
          .insert(goal.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      return goal;
    });
  }

  @override
  Future<GoalDto> updateGoal(GoalDto goal) async {
    return _session.runGuardedWrite(() async {
      final count =
          await (_database.update(_database.goals)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.equals(goal.id),
              ))
              .write(goal.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      if (count == 0) {
        throw const AppException.cache(
          message: 'Goal not found.',
          code: GoalFailureCodes.notFound,
        );
      }
      return goal;
    });
  }

  @override
  Future<GoalContributionDto> addContribution(GoalContributionDto value) {
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        final goal =
            await (_database.select(_database.goals)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(value.goalId),
                ))
                .getSingleOrNull();
        if (goal == null) {
          throw const AppException.cache(
            message: 'Goal not found.',
            code: GoalFailureCodes.notFound,
          );
        }
        if (goal.status == GoalStatus.archived.storageValue ||
            goal.archivedAt != null) {
          throw const AppException.validation(
            message: 'Archived goals cannot receive contributions.',
            code: GoalFailureCodes.archived,
          );
        }
        final current = Decimal.parse(goal.currentAmount);
        final target = Decimal.parse(goal.targetAmount);
        final next = current + value.creditedAmount;
        if (next > target) {
          throw const AppException.validation(
            message: 'This contribution would exceed the goal target.',
            code: GoalFailureCodes.overfunding,
          );
        }
        final now = DateTime.now().toUtc();
        final completed = next == target;
        await _database
            .into(_database.goalContributions)
            .insert(value.toCompanion().copyWith(ownerScopeId: Value(_scope)));
        await (_database.update(_database.goals)..where(
              (row) => row.ownerScopeId.equals(_scope) & row.id.equals(goal.id),
            ))
            .write(
              GoalsCompanion(
                currentAmount: Value(next.toString()),
                status: Value(
                  completed
                      ? GoalStatus.completed.storageValue
                      : goal.status == GoalStatus.paused.storageValue
                      ? GoalStatus.paused.storageValue
                      : GoalStatus.active.storageValue,
                ),
                completedAt: Value(completed ? now : null),
                updatedAt: Value(now),
              ),
            );
        return value;
      }),
    );
  }

  @override
  Future<GoalContributionDto> reverseContribution(String id) {
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        final row =
            await (_database.select(_database.goalContributions)..where(
                  (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
                ))
                .getSingleOrNull();
        if (row == null) {
          throw const AppException.cache(
            message: 'Goal contribution not found.',
            code: GoalFailureCodes.contributionNotFound,
          );
        }
        if (row.reversedAt != null) {
          throw const AppException.validation(
            message: 'Goal contribution was already reversed.',
            code: GoalFailureCodes.contributionAlreadyReversed,
          );
        }
        final goal =
            await (_database.select(_database.goals)..where(
                  (value) =>
                      value.ownerScopeId.equals(_scope) &
                      value.id.equals(row.goalId),
                ))
                .getSingleOrNull();
        if (goal == null) {
          throw const AppException.cache(
            message: 'Goal not found.',
            code: GoalFailureCodes.notFound,
          );
        }
        final next =
            Decimal.parse(goal.currentAmount) -
            Decimal.parse(row.creditedAmount);
        if (next < Decimal.zero) {
          throw const AppException.cache(
            message: 'Contribution history is inconsistent.',
            code: GoalFailureCodes.invalidContribution,
          );
        }
        final now = DateTime.now().toUtc();
        await (_database.update(_database.goalContributions)..where(
              (value) =>
                  value.ownerScopeId.equals(_scope) & value.id.equals(id),
            ))
            .write(
              GoalContributionsCompanion(
                reversedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        final nextStatus = goal.status == GoalStatus.archived.storageValue
            ? GoalStatus.archived
            : goal.status == GoalStatus.paused.storageValue
            ? GoalStatus.paused
            : GoalStatus.active;
        await (_database.update(_database.goals)..where(
              (value) =>
                  value.ownerScopeId.equals(_scope) & value.id.equals(goal.id),
            ))
            .write(
              GoalsCompanion(
                currentAmount: Value(next.toString()),
                status: Value(nextStatus.storageValue),
                completedAt: const Value(null),
                updatedAt: Value(now),
              ),
            );
        return row.toDto().copyWith(updatedAt: now, reversedAt: now);
      }),
    );
  }

  @override
  Stream<List<GoalContributionDto>> watchGoalContributions(String goalId) {
    final query = _database.select(_database.goalContributions)
      ..where(
        (row) => row.ownerScopeId.equals(_scope) & row.goalId.equals(goalId),
      )
      ..orderBy([
        (row) => OrderingTerm(expression: row.date, mode: OrderingMode.desc),
      ]);
    return _session
        .guardStream(query.watch())
        .map((rows) => rows.map((row) => row.toDto()).toList(growable: false));
  }
}
