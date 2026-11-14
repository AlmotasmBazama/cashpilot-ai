import 'app_agent_models.dart';
import 'app_agent_policy.dart';

enum AppAgentToolGroup {
  read,
  calculation,
  createDraft,
  updateDraft,
  archiveDraft,
  navigation,
}

class AppAgentToolDescriptor {
  const AppAgentToolDescriptor({
    required this.id,
    required this.group,
    required this.permission,
    required this.risk,
    required this.providerToolName,
    this.modelCallable = true,
  });

  final String id;
  final AppAgentToolGroup group;
  final AgentPermission permission;
  final AgentActionRisk risk;

  /// Compatibility name used by the current Groq/Firebase function schemas.
  /// The canonical local command identifier remains [id].
  final String providerToolName;
  final bool modelCallable;
}

/// Canonical surface backed by bounded use cases that already exist today.
///
/// Transaction update/delete/undo are local-only and backed by dedicated
/// bounded resolution plus stale-preview semantics. Other update, archive,
/// recurring-management, entity-detail, receipt-history, backup-control, and
/// bulk tools remain deliberately absent.
abstract final class CanonicalAppToolCatalog {
  static const List<AppAgentToolDescriptor> safeTools =
      <AppAgentToolDescriptor>[
        AppAgentToolDescriptor(
          id: 'getDashboardSummary',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_dashboard_summary',
        ),
        AppAgentToolDescriptor(
          id: 'getAccountsSummary',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_accounts_summary',
        ),
        AppAgentToolDescriptor(
          id: 'searchTransactions',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'search_transactions',
        ),
        AppAgentToolDescriptor(
          id: 'getCategorySpending',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_category_spending',
        ),
        AppAgentToolDescriptor(
          id: 'getTopSpendingCategories',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_top_spending_categories',
        ),
        AppAgentToolDescriptor(
          id: 'getMonthlyComparison',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_monthly_comparison',
        ),
        AppAgentToolDescriptor(
          id: 'getIncomeExpenseBreakdown',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_income_expense_breakdown',
        ),
        AppAgentToolDescriptor(
          id: 'getCashFlowSummary',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_cash_flow_trend',
        ),
        AppAgentToolDescriptor(
          id: 'getNetWorthSummary',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_net_worth',
        ),
        AppAgentToolDescriptor(
          id: 'getBudgetSummary',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_budget_summary',
        ),
        AppAgentToolDescriptor(
          id: 'getBudgetProgress',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_budget_progress',
        ),
        AppAgentToolDescriptor(
          id: 'getGoalSummary',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_goal_summary',
        ),
        AppAgentToolDescriptor(
          id: 'getGoalProgress',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_goal_progress',
        ),
        AppAgentToolDescriptor(
          id: 'getRecurringSummary',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_recurring_transactions',
        ),
        AppAgentToolDescriptor(
          id: 'getStoredExchangeRate',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readFinancialData,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_exchange_rate',
        ),
        AppAgentToolDescriptor(
          id: 'getBaseCurrency',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readAppConfiguration,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_base_currency',
        ),
        AppAgentToolDescriptor(
          id: 'getAgentCapabilities',
          group: AppAgentToolGroup.read,
          permission: AgentPermission.readAppConfiguration,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'get_agent_capabilities',
        ),
        AppAgentToolDescriptor(
          id: 'calculateSavingsRate',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'calculate_savings_rate',
        ),
        AppAgentToolDescriptor(
          id: 'calculateSafeSpendingAmount',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'calculate_safe_allowance',
        ),
        AppAgentToolDescriptor(
          id: 'projectMonthEndBalance',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'project_month_end',
        ),
        AppAgentToolDescriptor(
          id: 'simulateBudgetChange',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'simulate_budget_change',
        ),
        AppAgentToolDescriptor(
          id: 'estimateGoalCompletion',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'forecast_goal_completion',
        ),
        AppAgentToolDescriptor(
          id: 'evaluateGoalFeasibility',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'calculate_goal_feasibility',
        ),
        AppAgentToolDescriptor(
          id: 'compareIncomeScenarios',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'simulate_income_change',
        ),
        AppAgentToolDescriptor(
          id: 'compareScenarios',
          group: AppAgentToolGroup.calculation,
          permission: AgentPermission.calculate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'compare_scenarios',
        ),
        AppAgentToolDescriptor(
          id: 'createExpenseDraft',
          group: AppAgentToolGroup.createDraft,
          permission: AgentPermission.createDraft,
          risk: AgentActionRisk.low,
          providerToolName: 'draft_transaction',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'createIncomeDraft',
          group: AppAgentToolGroup.createDraft,
          permission: AgentPermission.createDraft,
          risk: AgentActionRisk.low,
          providerToolName: 'draft_transaction',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'createTransferDraft',
          group: AppAgentToolGroup.createDraft,
          permission: AgentPermission.createDraft,
          risk: AgentActionRisk.medium,
          providerToolName: 'draft_transfer',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'createBudgetDraft',
          group: AppAgentToolGroup.createDraft,
          permission: AgentPermission.createDraft,
          risk: AgentActionRisk.low,
          providerToolName: 'draft_budget',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'createGoalDraft',
          group: AppAgentToolGroup.createDraft,
          permission: AgentPermission.createDraft,
          risk: AgentActionRisk.low,
          providerToolName: 'draft_goal',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'createGoalContributionDraft',
          group: AppAgentToolGroup.createDraft,
          permission: AgentPermission.createDraft,
          risk: AgentActionRisk.low,
          providerToolName: 'draft_goal_contribution',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'updateTransactionDraft',
          group: AppAgentToolGroup.updateDraft,
          permission: AgentPermission.updateDraft,
          risk: AgentActionRisk.medium,
          providerToolName: 'local_update_transaction_draft',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'deleteTransactionDraft',
          group: AppAgentToolGroup.archiveDraft,
          permission: AgentPermission.archiveDraft,
          risk: AgentActionRisk.medium,
          providerToolName: 'local_delete_transaction_draft',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'undoAiAction',
          group: AppAgentToolGroup.updateDraft,
          permission: AgentPermission.updateDraft,
          risk: AgentActionRisk.medium,
          providerToolName: 'local_undo_ai_action',
          modelCallable: false,
        ),
        AppAgentToolDescriptor(
          id: 'openDashboard',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_dashboard',
        ),
        AppAgentToolDescriptor(
          id: 'openAccounts',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_accounts',
        ),
        AppAgentToolDescriptor(
          id: 'openTransactions',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_transactions',
        ),
        AppAgentToolDescriptor(
          id: 'openBudgets',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_budgets',
        ),
        AppAgentToolDescriptor(
          id: 'openGoals',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_goals',
        ),
        AppAgentToolDescriptor(
          id: 'openReports',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_reports',
        ),
        AppAgentToolDescriptor(
          id: 'openReceipts',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_receipt_scanner',
        ),
        AppAgentToolDescriptor(
          id: 'openPayees',
          group: AppAgentToolGroup.navigation,
          permission: AgentPermission.navigate,
          risk: AgentActionRisk.readOnly,
          providerToolName: 'navigate_payees',
        ),
      ];

  static AppAgentToolDescriptor? byId(String id) =>
      safeTools.where((tool) => tool.id == id).firstOrNull;

  static List<AppAgentToolDescriptor> byProviderToolName(String name) =>
      safeTools
          .where((tool) => tool.providerToolName == name)
          .toList(growable: false);

  static void validate() {
    final ids = safeTools.map((tool) => tool.id).toSet();
    final providerNames = safeTools
        .map((tool) => tool.providerToolName)
        .toSet();
    final hasConflictingProviderMetadata = providerNames.any((name) {
      final descriptors = byProviderToolName(name);
      final first = descriptors.first;
      return descriptors.any(
        (tool) =>
            tool.permission != first.permission ||
            tool.risk != first.risk ||
            tool.modelCallable != first.modelCallable,
      );
    });
    if (ids.length != safeTools.length ||
        hasConflictingProviderMetadata ||
        ids.any(AppAgentPolicy.prohibitedToolIds.contains) ||
        safeTools.any(
          (tool) =>
              tool.permission == AgentPermission.executeConfirmedAction ||
              tool.risk == AgentActionRisk.prohibited,
        )) {
      throw StateError('The canonical app tool catalog is not safe.');
    }
  }
}
