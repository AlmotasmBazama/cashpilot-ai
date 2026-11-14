import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../budgets/application/providers/budgets_providers.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/domain/entities/budget_progress.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../goals/application/providers/goals_providers.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/entities/goal_progress.dart';
import '../../../insights/domain/usecases/calculate_monthly_comparison.dart';
import '../../../insights/domain/usecases/detect_cash_flow_trend.dart';
import '../../../insights/domain/usecases/detect_recurring_transactions.dart';
import '../../../exchange_rates/application/base_currency_provider.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../providers/ai_agent_scope_providers.dart';
import 'financial_agent_tools.dart';

typedef FinancialMoneyConverter =
    Future<AppResult<Money>> Function(Money money, String toCurrencyCode);
typedef LatestExchangeRateReader =
    Future<AppResult<ExchangeRate?>> Function(String from, String to);
typedef FinancialTransactionSearch =
    Future<AppResult<List<Transaction>>> Function(String query);

/// Immutable financial readers captured while a trusted owner binding is
/// current. The captured use cases retain that owner's scoped database session;
/// they never resolve a replacement owner's providers after an await.
final class FinancialAgentOwnerBoundData {
  const FinancialAgentOwnerBoundData({
    required this.loadDashboardSnapshot,
    required this.loadBudgetSummary,
    required this.loadBudgetProgress,
    required this.loadGoalSummary,
    required this.loadGoalProgress,
    required this.convertMoney,
    required this.getLatestExchangeRate,
    required this.searchTransactions,
  });

  factory FinancialAgentOwnerBoundData.capture(Ref ref) {
    final getAccounts = ref.watch(getAccountsUseCaseProvider);
    final getTransactions = ref.watch(getTransactionsUseCaseProvider);
    final getCategories = ref.watch(getCategoriesUseCaseProvider);
    final baseCurrencyCode = ref.watch(effectiveBaseCurrencyCodeProvider);
    final dashboardExchangeRates = ref.watch(dashboardExchangeRateProvider);
    final watchBudgets = ref.watch(watchBudgetsUseCaseProvider);
    final calculateBudgetProgress = ref.watch(
      calculateBudgetProgressUseCaseProvider,
    );
    final watchGoals = ref.watch(watchGoalsUseCaseProvider);
    final goalProgressCalculator = ref.watch(goalProgressCalculatorProvider);
    final convertMoney = ref.watch(convertMoneyUseCaseProvider).call;
    final getLatestExchangeRate = ref
        .watch(getLatestExchangeRateUseCaseProvider)
        .call;
    final searchTransactions = ref
        .watch(searchTransactionsUseCaseProvider)
        .call;

    Future<AppResult<DashboardSnapshot>> loadDashboardSnapshot() async {
      final accountsResult = await getAccounts();
      final transactionsResult = await getTransactions();
      final categoriesResult = await getCategories();
      switch ((accountsResult, transactionsResult, categoriesResult)) {
        case (AppFailure<List<Account>>(:final failure), _, _):
          return AppResult.failure(failure);
        case (_, AppFailure<List<Transaction>>(:final failure), _):
          return AppResult.failure(failure);
        case (_, _, AppFailure<List<Category>>(:final failure)):
          return AppResult.failure(failure);
        case (
          AppSuccess<List<Account>>(data: final accounts),
          AppSuccess<List<Transaction>>(data: final transactions),
          AppSuccess<List<Category>>(data: final categories),
        ):
          return AppResult.success(
            await DashboardSnapshot.from(
              accounts: accounts,
              transactions: transactions,
              categories: categories,
              baseCurrencyCode: baseCurrencyCode,
              exchangeRateProvider: dashboardExchangeRates,
              now: DateTime.now().toUtc(),
            ),
          );
      }
    }

    Future<AppResult<List<BudgetProgress>>> loadBudgetProgress() async {
      final budgetsResult = await watchBudgets().first;
      final transactionsResult = await getTransactions();
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
              await calculateBudgetProgress(
                budget: budget,
                transactions: transactions,
                now: DateTime.now().toUtc(),
              ),
            );
          }
          return AppResult.success(values);
      }
    }

    Future<AppResult<BudgetSummary>> loadBudgetSummary() async {
      final result = await loadBudgetProgress();
      return switch (result) {
        AppSuccess<List<BudgetProgress>>(:final data) => AppResult.success(
          BudgetSummary.from(data),
        ),
        AppFailure<List<BudgetProgress>>(:final failure) => AppResult.failure(
          failure,
        ),
      };
    }

    Future<AppResult<List<GoalProgress>>> loadGoalProgressFor({
      required bool includeArchived,
    }) async {
      final result = await watchGoals(includeArchived: includeArchived).first;
      return switch (result) {
        AppSuccess<List<Goal>>(:final data) => AppResult.success(
          data
              .map(
                (goal) => goalProgressCalculator.calculate(
                  goal,
                  now: DateTime.now().toUtc(),
                ),
              )
              .toList(growable: false),
        ),
        AppFailure<List<Goal>>(:final failure) => AppResult.failure(failure),
      };
    }

    Future<AppResult<List<GoalProgress>>> loadGoalProgress() =>
        loadGoalProgressFor(includeArchived: false);

    Future<AppResult<GoalSummary>> loadGoalSummary() async {
      final result = await loadGoalProgressFor(includeArchived: true);
      return switch (result) {
        AppSuccess<List<GoalProgress>>(:final data) => AppResult.success(
          GoalSummary.from(data),
        ),
        AppFailure<List<GoalProgress>>(:final failure) => AppResult.failure(
          failure,
        ),
      };
    }

    return FinancialAgentOwnerBoundData(
      loadDashboardSnapshot: loadDashboardSnapshot,
      loadBudgetSummary: loadBudgetSummary,
      loadBudgetProgress: loadBudgetProgress,
      loadGoalSummary: loadGoalSummary,
      loadGoalProgress: loadGoalProgress,
      convertMoney: convertMoney,
      getLatestExchangeRate: getLatestExchangeRate,
      searchTransactions: searchTransactions,
    );
  }

  final Future<AppResult<DashboardSnapshot>> Function() loadDashboardSnapshot;
  final Future<AppResult<BudgetSummary>> Function() loadBudgetSummary;
  final Future<AppResult<List<BudgetProgress>>> Function() loadBudgetProgress;
  final Future<AppResult<GoalSummary>> Function() loadGoalSummary;
  final Future<AppResult<List<GoalProgress>>> Function() loadGoalProgress;
  final FinancialMoneyConverter convertMoney;
  final LatestExchangeRateReader getLatestExchangeRate;
  final FinancialTransactionSearch searchTransactions;
}

/// Lazily captures dependencies for exactly one trusted owner/session binding.
/// A stale gateway cannot use this family to resolve a replacement owner.
final financialAgentOwnerBoundDataProvider =
    Provider.family<FinancialAgentOwnerBoundData, AiToolOwnerScopeBinding>((
      ref,
      expectedOwnerScope,
    ) {
      if (ref.watch(aiToolOwnerScopeBindingProvider) != expectedOwnerScope) {
        throw const AiToolFailure(
          code: 'account_scope_changed',
          safeMessage:
              'The active account changed. The tool was stopped safely.',
        );
      }
      return FinancialAgentOwnerBoundData.capture(ref);
    }, name: 'financialAgentOwnerBoundDataProvider');

final class _OwnerBoundDataLease {
  _OwnerBoundDataLease(this._capture);

  final FinancialAgentOwnerBoundData Function() _capture;
  FinancialAgentOwnerBoundData? _captured;

  FinancialAgentOwnerBoundData get value => _captured ??= _capture();
}

class RiverpodFinancialAgentDataGateway implements FinancialAgentDataGateway {
  const RiverpodFinancialAgentDataGateway(
    this._ref, {
    required AiToolOwnerScopeBinding? boundOwnerScope,
    required AiToolOwnerScopeReader currentOwnerScope,
  }) : _boundOwnerScope = boundOwnerScope,
       _currentOwnerScope = currentOwnerScope;

  final Ref _ref;
  final AiToolOwnerScopeBinding? _boundOwnerScope;
  final AiToolOwnerScopeReader _currentOwnerScope;

  @override
  Future<AiToolResult> executeReadTool(
    String name,
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
  ) async {
    if (name == 'get_agent_capabilities') {
      return _capabilities();
    }
    _assertCurrentOwnerScope(context);
    final ownerBoundData = _OwnerBoundDataLease(
      () => _captureOwnerBoundData(context),
    );
    final result = await switch (name) {
      'get_dashboard_summary' => _dashboardSummary(context, ownerBoundData),
      'get_monthly_comparison' => _monthlyComparison(context, ownerBoundData),
      'get_category_spending' || 'get_top_spending_categories' =>
        _categorySpending(name, arguments, context, ownerBoundData),
      'get_budget_summary' => _budgetSummary(context, ownerBoundData),
      'get_budget_progress' => _budgetProgress(
        arguments,
        context,
        ownerBoundData,
      ),
      'get_goal_summary' => _goalSummary(context, ownerBoundData),
      'get_goal_progress' => _goalProgress(arguments, context, ownerBoundData),
      'get_cash_flow_trend' => _cashFlowTrend(context, ownerBoundData),
      'get_recurring_transactions' => _recurring(context, ownerBoundData),
      'get_income_expense_breakdown' => _incomeExpense(
        arguments,
        context,
        ownerBoundData,
      ),
      'get_net_worth' => _netWorth(context, ownerBoundData),
      'get_accounts_summary' => _accounts(arguments, context, ownerBoundData),
      'get_exchange_rate' => _exchangeRate(arguments, context, ownerBoundData),
      'search_transactions' => _searchTransactions(
        arguments,
        context,
        ownerBoundData,
      ),
      'get_base_currency' => _baseCurrency(context, ownerBoundData),
      _ => throw const AiToolFailure(
        code: 'tool_not_allowed',
        safeMessage: 'That financial data tool is not available.',
      ),
    };
    _assertCurrentOwnerScope(context);
    return result;
  }

  FinancialAgentOwnerBoundData _captureOwnerBoundData(
    AiToolExecutionContext context,
  ) {
    _assertCurrentOwnerScope(context);
    final boundOwnerScope = _boundOwnerScope;
    if (boundOwnerScope == null) {
      throw const AiToolFailure(
        code: 'account_scope_changed',
        safeMessage: 'The active account changed. The tool was stopped safely.',
      );
    }
    final data = _ref.read(
      financialAgentOwnerBoundDataProvider(boundOwnerScope),
    );
    _assertCurrentOwnerScope(context);
    return data;
  }

  Future<DashboardSnapshot> _snapshot(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final result = await _awaitScoped(
      context,
      ownerBoundData.value.loadDashboardSnapshot,
    );
    return switch (result) {
      AppSuccess<DashboardSnapshot>(:final data) => data,
      AppFailure<DashboardSnapshot>() => throw const AiToolFailure(
        code: 'financial_data_unavailable',
        safeMessage: 'Financial data is currently unavailable.',
        retryable: true,
      ),
    };
  }

  Future<AiToolResult> _dashboardSummary(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    final data = <String, Object?>{
      'currency': snapshot.baseCurrencyCode,
      'monthlyIncome': _firstAmount(snapshot.monthlyIncomeByCurrency),
      'monthlyExpense': _firstAmount(snapshot.monthlyExpenseByCurrency),
      'monthlySavings': _firstAmount(snapshot.monthlySavingsByCurrency),
      'netWorth': snapshot.netWorthInBaseCurrency.amount.toString(),
      'accountCount': snapshot.accounts.length,
      'partial': snapshot.isPartial,
    };
    return AiToolResult(
      toolName: 'get_dashboard_summary',
      data: data,
      period: _monthLabel(DateTime.now()),
      isPartial: snapshot.isPartial,
      evidenceSummary:
          'This month: income ${data['monthlyIncome'] ?? '0'}, expenses ${data['monthlyExpense'] ?? '0'}, savings ${data['monthlySavings'] ?? '0'} ${snapshot.baseCurrencyCode}. Net worth is ${data['netWorth']} ${snapshot.baseCurrencyCode}.',
    );
  }

  Future<AiToolResult> _monthlyComparison(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    _assertCurrentOwnerScope(context);
    final result = await const CalculateMonthlyComparisonUseCase()(
      transactions: snapshot.transactions,
      baseCurrency: snapshot.baseCurrencyCode,
      now: context.now,
      convertMoney: ownerBoundData.value.convertMoney,
    );
    final data = <String, Object?>{
      'currency': result.currency,
      'currentExpense': result.currentAmount.toString(),
      'previousExpense': result.previousAmount.toString(),
      'expenseChangePercent': result.changePercent?.toString(),
      'partial': result.missingRates.isNotEmpty,
    };
    return AiToolResult(
      toolName: 'get_monthly_comparison',
      data: data,
      period:
          '${_monthLabel(result.currentPeriodStart)} vs ${_monthLabel(DateTime.utc(result.currentPeriodStart.year, result.currentPeriodStart.month - 1))}',
      isPartial: result.missingRates.isNotEmpty,
      evidenceSummary:
          'Expenses are ${data['currentExpense']} ${result.currency} this month versus ${data['previousExpense']} ${result.currency} last month${result.changePercent == null ? '' : ' (${result.changePercent}% change)'}.',
    );
  }

  Future<AiToolResult> _categorySpending(
    String toolName,
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final categoryQuery = toolName == 'get_category_spending'
        ? _requiredCategoryQuery(arguments['category'])
        : null;
    final snapshot = await _snapshot(context, ownerBoundData);
    final limit = _limit(arguments, fallback: 5);
    final period = arguments['period']?.toString() ?? 'current_month';
    final items = snapshot.spendingByCategory
        .where(
          (item) =>
              categoryQuery == null ||
              item.categoryName.toLowerCase().contains(categoryQuery),
        )
        .take(limit)
        .map(
          (item) => <String, Object?>{
            'category': item.categoryName,
            'amount': item.amount.toString(),
            'currency': item.currencyCode,
          },
        )
        .toList(growable: false);
    final requestedUnsupportedPeriod = period != 'current_month';
    return AiToolResult(
      toolName: toolName,
      data: <String, Object?>{
        'period': 'current_month',
        'categories': items,
        'partial': snapshot.isPartial || requestedUnsupportedPeriod,
      },
      period: _monthLabel(DateTime.now()),
      isPartial: snapshot.isPartial || requestedUnsupportedPeriod,
      evidenceSummary: items.isEmpty
          ? 'No matching posted spending was found for the current month.'
          : 'Top current-month category spending: ${items.map((item) => '${item['category']} ${item['amount']} ${item['currency']}').join(', ')}.',
    );
  }

  String _requiredCategoryQuery(Object? value) {
    if (value is! String) {
      throw const AiToolFailure(
        code: 'invalid_arguments',
        safeMessage: 'A valid category name is required.',
      );
    }
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > 80 ||
        normalized.contains('\u0000')) {
      throw const AiToolFailure(
        code: 'invalid_arguments',
        safeMessage: 'A valid category name is required.',
      );
    }
    return normalized.toLowerCase();
  }

  Future<AiToolResult> _budgetSummary(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final result = await _awaitScoped(
      context,
      ownerBoundData.value.loadBudgetSummary,
    );
    final summary = switch (result) {
      AppSuccess<BudgetSummary>(:final data) => data,
      AppFailure<BudgetSummary>() => throw const AiToolFailure(
        code: 'budget_data_unavailable',
        safeMessage: 'Budget information is currently unavailable.',
        retryable: true,
      ),
    };
    return AiToolResult(
      toolName: 'get_budget_summary',
      data: <String, Object?>{
        'activeCount': summary.activeCount,
        'warningCount': summary.warningCount,
        'exceededCount': summary.exceededCount,
      },
      evidenceSummary:
          '${summary.activeCount} active budgets; ${summary.warningCount} need attention and ${summary.exceededCount} are exceeded.',
    );
  }

  Future<AiToolResult> _budgetProgress(
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final result = await _awaitScoped(
      context,
      ownerBoundData.value.loadBudgetProgress,
    );
    final progress = switch (result) {
      AppSuccess<List<BudgetProgress>>(:final data) => data,
      AppFailure<List<BudgetProgress>>() => throw const AiToolFailure(
        code: 'budget_data_unavailable',
        safeMessage: 'Budget information is currently unavailable.',
        retryable: true,
      ),
    };
    final items = progress
        .take(_limit(arguments, fallback: 10))
        .map(
          (item) => <String, Object?>{
            'name': item.budget.name,
            'spent': item.spentAmount.toString(),
            'limit': item.budget.amount.toString(),
            'remaining': item.remainingAmount.toString(),
            'currency': item.budget.currency,
            'progressPercent': item.progressPercent.toString(),
            'status': item.status.name,
            'partial': item.isPartial,
          },
        )
        .toList(growable: false);
    return AiToolResult(
      toolName: 'get_budget_progress',
      data: <String, Object?>{'budgets': items},
      isPartial: progress.any((item) => item.isPartial),
      evidenceSummary: items.isEmpty
          ? 'There are no active budgets.'
          : 'Reviewed ${items.length} active budget progress records.',
    );
  }

  Future<AiToolResult> _goalSummary(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final result = await _awaitScoped(
      context,
      ownerBoundData.value.loadGoalSummary,
    );
    final summary = switch (result) {
      AppSuccess<GoalSummary>(:final data) => data,
      AppFailure<GoalSummary>() => throw const AiToolFailure(
        code: 'goal_data_unavailable',
        safeMessage: 'Goal information is currently unavailable.',
        retryable: true,
      ),
    };
    return AiToolResult(
      toolName: 'get_goal_summary',
      data: <String, Object?>{
        'activeCount': summary.activeCount,
        'completedCount': summary.completedCount,
        'savedTotals': summary.savedTotals
            .map(
              (item) => <String, Object?>{
                'amount': item.amount.toString(),
                'currency': item.currency,
              },
            )
            .toList(growable: false),
        'nearestTargetDate': summary.nearestTargetDate
            ?.toUtc()
            .toIso8601String(),
      },
      evidenceSummary:
          '${summary.activeCount} active goals and ${summary.completedCount} completed goals.',
    );
  }

  Future<AiToolResult> _goalProgress(
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final result = await _awaitScoped(
      context,
      ownerBoundData.value.loadGoalProgress,
    );
    final progress = switch (result) {
      AppSuccess<List<GoalProgress>>(:final data) => data,
      AppFailure<List<GoalProgress>>() => throw const AiToolFailure(
        code: 'goal_data_unavailable',
        safeMessage: 'Goal information is currently unavailable.',
        retryable: true,
      ),
    };
    final items = progress
        .take(_limit(arguments, fallback: 10))
        .map(
          (item) => <String, Object?>{
            'title': item.goal.title,
            'current': item.currentAmount.toString(),
            'target': item.goal.targetAmount.toString(),
            'remaining': item.remainingAmount.toString(),
            'currency': item.goal.currency,
            'progressPercent': item.progressPercent.toString(),
            'daysRemaining': item.daysRemaining,
            'monthlyNeeded': item.monthlyNeeded?.toString(),
            'status': item.status.name,
          },
        )
        .toList(growable: false);
    return AiToolResult(
      toolName: 'get_goal_progress',
      data: <String, Object?>{'goals': items},
      evidenceSummary: items.isEmpty
          ? 'There are no active goals.'
          : 'Reviewed ${items.length} active goal progress records.',
    );
  }

  Future<AiToolResult> _cashFlowTrend(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    _assertCurrentOwnerScope(context);
    final result = await const DetectCashFlowTrendUseCase()(
      transactions: snapshot.transactions,
      baseCurrency: snapshot.baseCurrencyCode,
      now: context.now,
      convertMoney: ownerBoundData.value.convertMoney,
    );
    if (result == null) {
      return const AiToolResult(
        toolName: 'get_cash_flow_trend',
        data: <String, Object?>{'hasData': false},
        evidenceSummary: 'No posted income or expense data was found.',
      );
    }
    return AiToolResult(
      toolName: 'get_cash_flow_trend',
      data: <String, Object?>{
        'currentNet': result.currentNet.toString(),
        'previousNet': result.previousNet.toString(),
        'currency': result.currency,
        'partial': result.missingRates.isNotEmpty,
        'sixMonthExpenseTrend': snapshot.monthlyExpenseTrend
            .map((amount) => amount.toString())
            .toList(growable: false),
      },
      period: _monthLabel(context.now),
      isPartial: result.missingRates.isNotEmpty || snapshot.isPartial,
      evidenceSummary:
          'Current net cash flow is ${result.currentNet} ${result.currency}, compared with ${result.previousNet} ${result.currency} last month.',
    );
  }

  Future<AiToolResult> _recurring(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    final result = const DetectRecurringTransactionsUseCase()(
      transactions: snapshot.transactions,
      now: context.now,
    );
    return AiToolResult(
      toolName: 'get_recurring_transactions',
      data: <String, Object?>{
        'detectedPatternCount': result.patternCount,
        'periodStart': result.periodStart.toIso8601String(),
        'periodEnd': result.periodEnd.toIso8601String(),
      },
      period:
          '${result.periodStart.toIso8601String().substring(0, 10)} to ${result.periodEnd.toIso8601String().substring(0, 10)}',
      evidenceSummary:
          '${result.patternCount} recurring expense patterns were detected in the bounded six-month period.',
    );
  }

  Future<AiToolResult> _incomeExpense(
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    final period = arguments['period']?.toString() ?? 'current_month';
    final isYear = period == 'year';
    final income = isYear
        ? snapshot.yearlyIncomeByCurrency
        : snapshot.monthlyIncomeByCurrency;
    final expense = isYear
        ? snapshot.yearlyExpenseByCurrency
        : snapshot.monthlyExpenseByCurrency;
    final requestedUnsupportedPeriod = period == 'previous_month';
    return AiToolResult(
      toolName: 'get_income_expense_breakdown',
      data: <String, Object?>{
        'period': isYear ? 'year' : 'current_month',
        'income': _firstAmount(income),
        'expense': _firstAmount(expense),
        'currency': snapshot.baseCurrencyCode,
        'partial': snapshot.isPartial || requestedUnsupportedPeriod,
      },
      isPartial: snapshot.isPartial || requestedUnsupportedPeriod,
      evidenceSummary:
          '${isYear ? 'Year-to-date' : 'Current-month'} income is ${_firstAmount(income) ?? '0'} and expenses are ${_firstAmount(expense) ?? '0'} ${snapshot.baseCurrencyCode}.',
    );
  }

  Future<AiToolResult> _netWorth(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    return AiToolResult(
      toolName: 'get_net_worth',
      data: <String, Object?>{
        'amount': snapshot.netWorthInBaseCurrency.amount.toString(),
        'currency': snapshot.baseCurrencyCode,
        'partial': snapshot.isPartial,
      },
      isPartial: snapshot.isPartial,
      evidenceSummary:
          'Net worth is ${snapshot.netWorthInBaseCurrency.amount} ${snapshot.baseCurrencyCode}.',
    );
  }

  Future<AiToolResult> _accounts(
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    final items = snapshot.accounts
        .where((account) => !account.isArchived)
        .take(_limit(arguments, fallback: 10))
        .map(
          (account) => <String, Object?>{
            'name': account.name,
            'type': account.type.name,
            'balance': account.balance.toString(),
            'currency': account.currencyCode,
          },
        )
        .toList(growable: false);
    return AiToolResult(
      toolName: 'get_accounts_summary',
      data: <String, Object?>{'accounts': items},
      evidenceSummary:
          '${items.length} active account summaries were reviewed.',
    );
  }

  Future<AiToolResult> _exchangeRate(
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final from = arguments['from'].toString().trim().toUpperCase();
    final to = arguments['to'].toString().trim().toUpperCase();
    if (from.length != 3 || to.length != 3) {
      throw const AiToolFailure(
        code: 'invalid_currency',
        safeMessage: 'A valid three-letter currency code is required.',
      );
    }
    final result = await _awaitScoped(
      context,
      () => ownerBoundData.value.getLatestExchangeRate(from, to),
    );
    final rate = switch (result) {
      AppSuccess(:final data) when data != null => data,
      _ => throw const AiToolFailure(
        code: 'exchange_rate_unavailable',
        safeMessage: 'No stored exchange rate is available for that pair.',
      ),
    };
    return AiToolResult(
      toolName: 'get_exchange_rate',
      data: <String, Object?>{
        'from': from,
        'to': to,
        'rate': rate.rate.toString(),
        'asOf': rate.asOf?.toUtc().toIso8601String(),
      },
      evidenceSummary:
          'The stored $from/$to rate is ${rate.rate}${rate.asOf == null ? '' : ' as of ${rate.asOf!.toIso8601String().substring(0, 10)}'}.',
    );
  }

  Future<AiToolResult> _searchTransactions(
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    final query = arguments['query'].toString().trim().toLowerCase();
    final categoryById = <String, String>{
      for (final category in snapshot.categories) category.id: category.name,
    };
    final accountById = <String, String>{
      for (final account in snapshot.accounts) account.id: account.name,
    };
    final searchResult = await _awaitScoped(
      context,
      () => ownerBoundData.value.searchTransactions(query),
    );
    final matches = switch (searchResult) {
      AppSuccess<List<Transaction>>(:final data) => data,
      AppFailure<List<Transaction>>() => throw const AiToolFailure(
        code: 'transaction_search_unavailable',
        safeMessage: 'Transaction search is currently unavailable.',
        retryable: true,
      ),
    }..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final items = matches
        .take(_limit(arguments, fallback: 10))
        .map(
          (transaction) => _safeTransaction(
            transaction,
            categoryById: categoryById,
            accountById: accountById,
          ),
        )
        .toList(growable: false);
    return AiToolResult(
      toolName: 'search_transactions',
      data: <String, Object?>{
        'transactions': items,
        'resultCount': items.length,
        'bounded': true,
      },
      evidenceSummary:
          '${items.length} bounded transaction summaries matched the search.',
    );
  }

  Map<String, Object?> _safeTransaction(
    Transaction transaction, {
    required Map<String, String> categoryById,
    required Map<String, String> accountById,
  }) => <String, Object?>{
    'date': transaction.transactionDate.toLocal().toIso8601String().substring(
      0,
      10,
    ),
    'type': transaction.type.name,
    'amount': transaction.amount.amount.toString(),
    'currency': transaction.amount.currencyCode,
    'category': categoryById[transaction.categoryId] ?? 'Unknown',
    'account': accountById[transaction.accountId] ?? 'Unknown',
    'status': transaction.status.name,
  };

  Future<AiToolResult> _baseCurrency(
    AiToolExecutionContext context,
    _OwnerBoundDataLease ownerBoundData,
  ) async {
    final snapshot = await _snapshot(context, ownerBoundData);
    return AiToolResult(
      toolName: 'get_base_currency',
      data: <String, Object?>{'currency': snapshot.baseCurrencyCode},
      evidenceSummary:
          'The configured base currency is ${snapshot.baseCurrencyCode}.',
    );
  }

  Future<AiToolResult> _capabilities() async {
    return const AiToolResult(
      toolName: 'get_agent_capabilities',
      data: <String, Object?>{
        'can': <String>[
          'analyze bounded financial summaries',
          'compare periods',
          'calculate safe scenarios',
          'prepare review-only action drafts',
          'navigate to approved CashPilot screens',
        ],
        'cannot': <String>[
          'execute financial actions without confirmation',
          'read raw databases or secrets',
          'change security settings',
          'provide guaranteed financial outcomes',
        ],
      },
    );
  }

  Future<T> _awaitScoped<T>(
    AiToolExecutionContext context,
    Future<T> Function() operation,
  ) async {
    _assertCurrentOwnerScope(context);
    final result = await operation();
    _assertCurrentOwnerScope(context);
    return result;
  }

  void _assertCurrentOwnerScope(AiToolExecutionContext context) {
    final captured = context.ownerScope;
    AiToolOwnerScopeBinding? current;
    try {
      current = _currentOwnerScope();
    } on Object {
      current = null;
    }
    if (captured == null ||
        captured != _boundOwnerScope ||
        captured != current) {
      throw const AiToolFailure(
        code: 'account_scope_changed',
        safeMessage: 'The active account changed. The tool was stopped safely.',
      );
    }
  }

  int _limit(Map<String, Object?> arguments, {required int fallback}) =>
      arguments['limit'] as int? ?? fallback;

  String? _firstAmount(List<CurrencyTotal> totals) =>
      totals.firstOrNull?.amount.toString();

  String _monthLabel(DateTime value) =>
      '${value.toUtc().year.toString().padLeft(4, '0')}-${value.toUtc().month.toString().padLeft(2, '0')}';
}
