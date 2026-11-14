import type { FinancialFigureDimension } from "./financial_figure_contracts.js";

// Grounding authority is producer-specific: an arbitrary numeric-looking
// context field must not authorize a model figure or change its dimension.
export const financialFieldDimensions: Readonly<
  Record<string, Readonly<Record<string, FinancialFigureDimension>>>
> = {
  get_dashboard_summary: {
    monthlyIncome: "amount",
    monthlyExpense: "amount",
    monthlySavings: "amount",
    netWorth: "amount",
    accountCount: "count",
  },
  get_monthly_comparison: {
    currentExpense: "amount",
    previousExpense: "amount",
    expenseChangePercent: "percent",
  },
  get_category_spending: {
    "categories[].amount": "amount",
  },
  get_top_spending_categories: {
    "categories[].amount": "amount",
  },
  get_budget_summary: {
    activeCount: "count",
    warningCount: "count",
    exceededCount: "count",
  },
  get_budget_progress: {
    "budgets[].spent": "amount",
    "budgets[].limit": "amount",
    "budgets[].remaining": "amount",
    "budgets[].progressPercent": "percent",
  },
  get_goal_summary: {
    activeCount: "count",
    completedCount: "count",
    "savedTotals[].amount": "amount",
    nearestTargetDate: "date",
  },
  get_goal_progress: {
    "goals[].current": "amount",
    "goals[].target": "amount",
    "goals[].remaining": "amount",
    "goals[].progressPercent": "percent",
    "goals[].daysRemaining": "count",
    "goals[].monthlyNeeded": "amount",
  },
  get_cash_flow_trend: {
    currentNet: "amount",
    previousNet: "amount",
  },
  get_recurring_transactions: {
    detectedPatternCount: "count",
    periodStart: "date",
    periodEnd: "date",
  },
  get_income_expense_breakdown: {
    income: "amount",
    expense: "amount",
  },
  get_net_worth: {
    amount: "amount",
  },
  get_accounts_summary: {
    "accounts[].balance": "amount",
  },
  get_exchange_rate: {
    rate: "rate",
    asOf: "date",
  },
  search_transactions: {
    "transactions[].date": "date",
    "transactions[].amount": "amount",
    resultCount: "count",
  },
  calculate_savings_rate: {
    savings: "amount",
    savingsRatePercent: "percent",
  },
  project_month_end: {
    projectedAmount: "amount",
  },
  simulate_budget_change: {
    remaining: "amount",
  },
  calculate_goal_feasibility: {
    monthsNeeded: "count",
  },
  forecast_goal_completion: {
    monthsNeeded: "count",
  },
  calculate_safe_allowance: {
    safeAllowance: "amount",
  },
  simulate_income_change: {
    projectedCashFlow: "amount",
  },
  compare_scenarios: {
    difference: "amount",
  },
  convert_currency_amount: {
    amount: "amount",
  },
};
