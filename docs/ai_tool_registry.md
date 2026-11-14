# AI tool registry

`CanonicalAppToolCatalog` defines the provider-independent application
capability surface. `GovernedAiToolRegistry` is the compatibility entry point
for currently declared provider functions. Provider names are translations;
the canonical camel-case ID is the local command identity.

Names are unique, unknown names fail closed, schemas and arguments are
validated locally, duplicate calls are rejected, and provider results are
bounded. The catalog contains no executor and no arbitrary route, repository,
database, network, or file handle.

## Current canonical safe catalog

The catalog includes only capabilities with an existing bounded application
path. Presence in this list does not activate a capability: rollout flags,
account-scoped settings, scope verification, route relevance, permission, and
risk checks must also pass.

### Financial reads

| Canonical ID | Provider compatibility name |
| --- | --- |
| `getDashboardSummary` | `get_dashboard_summary` |
| `getAccountsSummary` | `get_accounts_summary` |
| `searchTransactions` | `search_transactions` |
| `getCategorySpending` | `get_category_spending` |
| `getTopSpendingCategories` | `get_top_spending_categories` |
| `getMonthlyComparison` | `get_monthly_comparison` |
| `getIncomeExpenseBreakdown` | `get_income_expense_breakdown` |
| `getCashFlowSummary` | `get_cash_flow_trend` |
| `getNetWorthSummary` | `get_net_worth` |
| `getBudgetSummary` | `get_budget_summary` |
| `getBudgetProgress` | `get_budget_progress` |
| `getGoalSummary` | `get_goal_summary` |
| `getGoalProgress` | `get_goal_progress` |
| `getRecurringSummary` | `get_recurring_transactions` |
| `getStoredExchangeRate` | `get_exchange_rate` |

All use `readFinancialData` with `readOnly` risk. Transaction and entity
collections are bounded. Results omit notes, attachments, internal IDs, user
identity, authentication state, sync payloads, and unrelated records.
Receipt-history and entity-detail reads remain absent until dedicated bounded
use cases and account ownership are available.

Configuration reads `getBaseCurrency` (`get_base_currency`) and
`getAgentCapabilities` (`get_agent_capabilities`) expose only safe local
configuration metadata through `readAppConfiguration`.

### Deterministic calculations

| Canonical ID | Provider compatibility name |
| --- | --- |
| `calculateSavingsRate` | `calculate_savings_rate` |
| `calculateSafeSpendingAmount` | `calculate_safe_allowance` |
| `projectMonthEndBalance` | `project_month_end` |
| `simulateBudgetChange` | `simulate_budget_change` |
| `estimateGoalCompletion` | `forecast_goal_completion` |
| `evaluateGoalFeasibility` | `calculate_goal_feasibility` |
| `compareIncomeScenarios` | `simulate_income_change` |
| `compareScenarios` | `compare_scenarios` |

Calculations use local deterministic `Decimal` code. Money and rates cross
tool boundaries as strings, never binary floating-point money.

### Create drafts

| Canonical ID | Risk | Current model-callable status |
| --- | --- | --- |
| `createExpenseDraft` | low | No; deterministic parser path only |
| `createIncomeDraft` | low | No; deterministic parser path only |
| `createTransferDraft` | medium | No; deterministic parser path only |
| `createBudgetDraft` | low | No; deterministic parser path only |
| `createGoalDraft` | low | No; deterministic parser path only |
| `createGoalContributionDraft` | low | No; deterministic parser path only |

Provider compatibility names are `draft_transaction`, `draft_transfer`,
`draft_budget`, `draft_goal`, and `draft_goal_contribution`. Any compatibility
draft result remains review-only (`reviewRequired: true`,
`executionAllowed: false`). It cannot invoke a financial use case.

### Navigation

| Canonical ID | Provider compatibility name |
| --- | --- |
| `openDashboard` | `navigate_dashboard` |
| `openAccounts` | `navigate_accounts` |
| `openTransactions` | `navigate_transactions` |
| `openBudgets` | `navigate_budgets` |
| `openGoals` | `navigate_goals` |
| `openReports` | `navigate_reports` |
| `openReceipts` | `navigate_receipt_scanner` |
| `openPayees` | `navigate_payees` |

Navigation returns only a route selected from the fixed local allowlist. A
general question does not become navigation, and arbitrary path strings are
never accepted.

## Deferred catalog groups

The following are intentionally not in `safeTools` yet:

- Entity-detail reads, receipt history, payee summaries, backup controls, and
  unrestricted raw transaction reads.
- `getFinancialInsights` (`get_financial_insights`) remains deferred until a
  dedicated adapter returns only the minimized `BuildAiInsightSummaryUseCase`
  shape and proves that titles, messages, metric labels, and user-defined
  entity names cannot cross the provider boundary.
- Currency conversion remains deferred until the tool resolves a stored rate
  locally instead of accepting a model-supplied rate.
- Account, category, payee, recurring, and exchange-rate create drafts.
- All update drafts, including transaction, account, category, payee, budget,
  goal, recurring, and exchange-rate updates.
- Archive, pause, resume, cancel, pending-transfer, bulk, export, and
  multi-step mutation tools.

They may be added only after a bounded existing use case, account-scope check,
typed preview, revalidation/freshness rule, confirmation level, verified
result, audit behavior, and safe partial-failure policy exist.

## Permanently prohibited capabilities

These IDs are rejected and must never be declared:

- `setAccountBalance`
- `modifyBalanceDirectly`
- `runRawSql`
- `accessDrift`
- `accessFirestore`
- `accessRepository`
- `readTokens`
- `readSecrets`
- `changeAuthentication`
- `disableAppCheck`
- `deleteAllUserData`
- `unrestrictedDelete`
- `executeWithoutConfirmation`
- `arbitraryRoute`
- `arbitraryHttpRequest`
- `arbitraryFileAccess`
- `unrestrictedExport`
- `anotherUserDataAccess`

Account deletion stays inside its existing reauthenticated protected native
workflow. Direct balance mutation never becomes a tool; account values change
only through existing transaction and transfer logic.

`CanonicalAppToolCatalog.validate()` rejects duplicate IDs, any prohibited ID,
any `executeConfirmedAction` permission, and any `prohibited`-risk descriptor.

## Rollout boundary

Canonical financial reads and drafts remain **disabled by default for
production rollout**. The current source now has an authenticated owner-scoped
Drift boundary plus durable command, proof, plan, audit, and business-operation
ledgers with isolation/restart regressions. Those code prerequisites do not
enable a tool by themselves: rollout still requires explicit flags, an
effective owner policy, consent, app-control gates, and controlled live
acceptance. The catalog remains an inventory and policy boundary, not evidence
that a tool is enabled in a deployed environment.
