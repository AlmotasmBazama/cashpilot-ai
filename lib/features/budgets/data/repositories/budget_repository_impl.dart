import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../domain/entities/budget.dart';
import '../../domain/enums/budget_period_type.dart';
import '../../domain/failures/budget_failure_codes.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/local/budgets_local_data_source.dart';
import '../mappers/budget_mapper.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  const BudgetRepositoryImpl({
    required BudgetsLocalDataSource localDataSource,
    required AppLogger logger,
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _logger = logger,
       _syncQueue = syncQueue;

  final BudgetsLocalDataSource _localDataSource;
  final AppLogger _logger;
  final SyncMutationQueue? _syncQueue;

  @override
  Stream<AppResult<List<Budget>>> watchBudgets({
    bool includeArchived = false,
  }) async* {
    try {
      await for (final rows in _localDataSource.watchBudgets(
        includeArchived: includeArchived,
      )) {
        yield AppResult.success(
          rows.map((row) => row.toDomain()).toList(growable: false),
        );
      }
    } on Object catch (error, stackTrace) {
      yield _failure('Unable to watch budgets.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Budget?>> getBudgetById(String id) async {
    try {
      return AppResult.success(
        (await _localDataSource.getBudgetById(id))?.toDomain(),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load budget.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Budget>> createBudget(Budget budget) async {
    try {
      final normalized = _validatedCopy(budget, updatedAt: budget.updatedAt);
      final result = (await _localDataSource.createBudget(
        normalized.toDto(),
      )).toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to create budget.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Budget>> updateBudget(Budget budget) async {
    try {
      final normalized = _validatedCopy(
        budget,
        updatedAt: DateTime.now().toUtc(),
      );
      final result = (await _localDataSource.updateBudget(
        normalized.toDto(),
      )).toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to update budget.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Budget>> archiveBudget(String id) async {
    return _setArchived(id, archived: true);
  }

  @override
  Future<AppResult<Budget>> restoreBudget(String id) async {
    return _setArchived(id, archived: false);
  }

  @override
  Future<AppResult<List<Budget>>> getActiveBudgetsForPeriod(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final budgets = (await _localDataSource.getBudgets())
          .map((row) => row.toDomain())
          .where((budget) {
            if (!budget.isActive || budget.isArchived) {
              return false;
            }
            if (budget.periodType != BudgetPeriodType.custom) {
              return true;
            }
            return budget.startDate.isBefore(to.toUtc()) &&
                budget.endDate.isAfter(from.toUtc());
          })
          .toList(growable: false);
      return AppResult.success(budgets);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load active budgets.', error, stackTrace);
    }
  }

  Future<AppResult<Budget>> _setArchived(
    String id, {
    required bool archived,
  }) async {
    try {
      final existing = await _localDataSource.getBudgetById(id);
      if (existing == null) {
        throw const BudgetValidationException(
          code: BudgetFailureCodes.notFound,
          message: 'Budget not found.',
        );
      }
      final now = DateTime.now().toUtc();
      final updated = existing.toDomain().copyWith(
        archivedAt: archived ? now : null,
        isActive: !archived,
        updatedAt: now,
      );
      final result = (await _localDataSource.updateBudget(
        updated.toDto(),
      )).toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure(
        'Unable to update budget archive state.',
        error,
        stackTrace,
      );
    }
  }

  Budget _validatedCopy(Budget budget, {required DateTime updatedAt}) {
    return Budget.create(
      id: budget.id,
      name: budget.name,
      categoryId: budget.categoryId,
      amount: budget.amount,
      currency: budget.currency,
      periodType: budget.periodType,
      startDate: budget.startDate,
      endDate: budget.endDate,
      alertThresholdPercent: budget.alertThresholdPercent,
      isActive: budget.isActive,
      createdAt: budget.createdAt,
      updatedAt: updatedAt,
      archivedAt: budget.archivedAt,
    );
  }

  AppResult<T> _failure<T>(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(message, error, stackTrace);
    return switch (error) {
      BudgetValidationException(:final code, :final message) =>
        AppResult.failure(Failure(message: message, code: code)),
      AppException(:final code, :final message) => AppResult.failure(
        Failure(message: message, code: code),
      ),
      _ => AppResult.failure(Failure(message: message)),
    };
  }

  Future<void> _queueUpsert(Budget budget) {
    return enqueueSyncUpsertBestEffort(
      queue: _syncQueue,
      entityType: SyncEntityType.budget,
      entityId: budget.id,
      payload: budget.toJson(),
      logger: _logger,
    );
  }
}
