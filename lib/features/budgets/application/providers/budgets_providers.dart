import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/sync_providers.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../../transactions/transactions.dart'
    show transactionRowDomainMapperProvider;
import '../../../transactions/domain/entities/transaction.dart';
import '../../data/budget_transactions_read_model.dart';
import '../../data/datasources/local/budgets_local_data_source.dart';
import '../../data/repositories/budget_repository_impl.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_progress.dart';
import '../../domain/enums/budget_status.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/services/budget_progress_calculator.dart';
import '../../domain/usecases/archive_budget.dart';
import '../../domain/usecases/calculate_budget_progress.dart';
import '../../domain/usecases/create_budget.dart';
import '../../domain/usecases/get_active_budgets.dart';
import '../../domain/usecases/get_budget_by_id.dart';
import '../../domain/usecases/restore_budget.dart';
import '../../domain/usecases/update_budget.dart';
import '../../domain/usecases/watch_budget_progress.dart';
import '../../domain/usecases/watch_budgets.dart';

final budgetsLocalDataSourceProvider = Provider<BudgetsLocalDataSource>(
  (ref) => DriftBudgetsLocalDataSource(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'budgetsLocalDataSourceProvider',
);

final budgetTransactionsReadModelProvider =
    Provider<BudgetTransactionsReadModel>(
      (ref) => BudgetTransactionsReadModel(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
        ref.watch(transactionRowDomainMapperProvider),
      ),
      name: 'budgetTransactionsReadModelProvider',
    );

final budgetTransactionsWindowProvider = StreamProvider.autoDispose
    .family<AppResult<List<Transaction>>, BudgetTransactionWindowRequest>(
      (ref, request) =>
          ref.watch(budgetTransactionsReadModelProvider).watch(request),
      name: 'budgetTransactionsWindowProvider',
    );

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepositoryImpl(
    localDataSource: ref.watch(budgetsLocalDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
    syncQueue: ref.watch(syncMutationQueueProvider),
  ),
  name: 'budgetRepositoryProvider',
);

final watchBudgetsUseCaseProvider = Provider<WatchBudgets>(
  (ref) => WatchBudgets(ref.watch(budgetRepositoryProvider)),
  name: 'watchBudgetsUseCaseProvider',
);
final createBudgetUseCaseProvider = Provider<CreateBudget>(
  (ref) => CreateBudget(ref.watch(budgetRepositoryProvider)),
  name: 'createBudgetUseCaseProvider',
);
final updateBudgetUseCaseProvider = Provider<UpdateBudget>(
  (ref) => UpdateBudget(ref.watch(budgetRepositoryProvider)),
  name: 'updateBudgetUseCaseProvider',
);
final archiveBudgetUseCaseProvider = Provider<ArchiveBudget>(
  (ref) => ArchiveBudget(ref.watch(budgetRepositoryProvider)),
  name: 'archiveBudgetUseCaseProvider',
);
final restoreBudgetUseCaseProvider = Provider<RestoreBudget>(
  (ref) => RestoreBudget(ref.watch(budgetRepositoryProvider)),
  name: 'restoreBudgetUseCaseProvider',
);
final getBudgetByIdUseCaseProvider = Provider<GetBudgetById>(
  (ref) => GetBudgetById(ref.watch(budgetRepositoryProvider)),
  name: 'getBudgetByIdUseCaseProvider',
);
final getActiveBudgetsUseCaseProvider = Provider<GetActiveBudgets>(
  (ref) => GetActiveBudgets(ref.watch(budgetRepositoryProvider)),
  name: 'getActiveBudgetsUseCaseProvider',
);
final budgetProgressCalculatorProvider = Provider<BudgetProgressCalculator>(
  (_) => const BudgetProgressCalculator(),
  name: 'budgetProgressCalculatorProvider',
);
final calculateBudgetProgressUseCaseProvider =
    Provider<CalculateBudgetProgress>(
      (ref) => CalculateBudgetProgress(
        calculator: ref.watch(budgetProgressCalculatorProvider),
        convertMoney: ref.watch(convertMoneyUseCaseProvider).call,
      ),
      name: 'calculateBudgetProgressUseCaseProvider',
    );
final watchBudgetProgressUseCaseProvider = Provider<WatchBudgetProgress>(
  (ref) => WatchBudgetProgress(
    repository: ref.watch(budgetRepositoryProvider),
    calculateProgress: ref.watch(calculateBudgetProgressUseCaseProvider),
  ),
  name: 'watchBudgetProgressUseCaseProvider',
);

final budgetsProvider = StreamProvider<AppResult<List<Budget>>>(
  (ref) => ref.watch(watchBudgetsUseCaseProvider)(),
  name: 'budgetsProvider',
);

final allBudgetsProvider = StreamProvider<AppResult<List<Budget>>>(
  (ref) => ref.watch(watchBudgetsUseCaseProvider)(includeArchived: true),
  name: 'allBudgetsProvider',
);

final budgetByIdProvider = FutureProvider.family<AppResult<Budget?>, String>(
  (ref, id) => ref.watch(getBudgetByIdUseCaseProvider)(id),
  name: 'budgetByIdProvider',
);

final budgetProgressProvider = FutureProvider<AppResult<List<BudgetProgress>>>((
  ref,
) async {
  final budgetsResult = await ref.watch(budgetsProvider.future);
  if (budgetsResult case AppFailure<List<Budget>>(:final failure)) {
    return AppResult.failure(failure);
  }
  final budgets = (budgetsResult as AppSuccess<List<Budget>>).data;
  final now = DateTime.now().toUtc();
  final request = BudgetTransactionWindowRequest.fromBudgets(
    budgets: budgets,
    now: now,
  );
  final transactionsResult = switch (ref.watch(
    budgetTransactionsWindowProvider(request),
  )) {
    AsyncData(:final value) => value,
    _ => await ref.watch(budgetTransactionsWindowProvider(request).future),
  };
  return _calculateProgress(
    budgetsResult: budgetsResult,
    transactionsResult: transactionsResult,
    now: now,
    calculate: ref.watch(calculateBudgetProgressUseCaseProvider),
  );
}, name: 'budgetProgressProvider');

final allBudgetProgressProvider =
    FutureProvider<AppResult<List<BudgetProgress>>>((ref) async {
      final budgetsResult = await ref.watch(allBudgetsProvider.future);
      if (budgetsResult case AppFailure<List<Budget>>(:final failure)) {
        return AppResult.failure(failure);
      }
      final budgets = (budgetsResult as AppSuccess<List<Budget>>).data;
      final now = DateTime.now().toUtc();
      final request = BudgetTransactionWindowRequest.fromBudgets(
        budgets: budgets,
        now: now,
      );
      final transactionsResult = switch (ref.watch(
        budgetTransactionsWindowProvider(request),
      )) {
        AsyncData(:final value) => value,
        _ => await ref.watch(budgetTransactionsWindowProvider(request).future),
      };
      return _calculateProgress(
        budgetsResult: budgetsResult,
        transactionsResult: transactionsResult,
        now: now,
        calculate: ref.watch(calculateBudgetProgressUseCaseProvider),
      );
    }, name: 'allBudgetProgressProvider');

final budgetSummaryProvider = FutureProvider<AppResult<BudgetSummary>>((
  ref,
) async {
  final result = await ref.watch(budgetProgressProvider.future);
  return switch (result) {
    AppSuccess<List<BudgetProgress>>(:final data) => AppResult.success(
      BudgetSummary.from(data),
    ),
    AppFailure<List<BudgetProgress>>(:final failure) => AppResult.failure(
      failure,
    ),
  };
}, name: 'budgetSummaryProvider');

Future<AppResult<List<BudgetProgress>>> _calculateProgress({
  required AppResult<List<Budget>> budgetsResult,
  required AppResult<List<Transaction>> transactionsResult,
  required DateTime now,
  required CalculateBudgetProgress calculate,
}) async {
  switch ((budgetsResult, transactionsResult)) {
    case (AppFailure<List<Budget>>(:final failure), _):
      return AppResult.failure(failure);
    case (_, AppFailure<List<Transaction>>(:final failure)):
      return AppResult.failure(failure);
    case (
      AppSuccess<List<Budget>>(data: final budgets),
      AppSuccess<List<Transaction>>(data: final transactions),
    ):
      final values = <BudgetProgress>[];
      for (final budget in budgets) {
        values.add(
          await calculate(budget: budget, transactions: transactions, now: now),
        );
      }
      return AppResult.success(values);
  }
}

class BudgetSummary {
  const BudgetSummary({
    required this.activeCount,
    required this.warningCount,
    required this.exceededCount,
    required this.topWarning,
  });

  final int activeCount;
  final int warningCount;
  final int exceededCount;
  final BudgetProgress? topWarning;

  factory BudgetSummary.from(List<BudgetProgress> progress) {
    final active = progress
        .where((item) => item.status != BudgetStatus.inactive)
        .toList(growable: false);
    final alerts =
        active
            .where(
              (item) =>
                  item.status == BudgetStatus.warning ||
                  item.status == BudgetStatus.exceeded,
            )
            .toList(growable: false)
          ..sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
    return BudgetSummary(
      activeCount: active.length,
      warningCount: active
          .where((item) => item.status == BudgetStatus.warning)
          .length,
      exceededCount: active
          .where((item) => item.status == BudgetStatus.exceeded)
          .length,
      topWarning: alerts.firstOrNull,
    );
  }
}
