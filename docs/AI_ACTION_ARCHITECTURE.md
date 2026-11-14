# AI Action Architecture

## Implemented flow

```text
User text
  -> deterministic Arabic/digit/currency normalization
  -> local intent/amount/date/payment/account parsing
  -> provider adapter only when semantic interpretation is needed
  -> strict structured output validation
  -> owner-scoped entity/context resolution
  -> canonical allowlist + permission/risk policy
  -> durable draft/command + confirmation proof
  -> idempotent application use case / Drift transaction
  -> reconciliation and structured persisted result
  -> localized UI result (never before persistence)
```

Manual and AI creation converge on normal transaction/finance-engine services;
the provider has no database adapter. `userId` is never accepted from model
arguments. Owner scope comes from the authenticated session and is repeated at
repository/database boundaries.

## Boundaries

- Model/provider: interpretation and tool selection only. Firebase/Groq adapters
  implement interfaces. Firebase Auth/App Check tokens do not enter Groq
  prompts; Groq keys remain in the gateway.
- Gateway: verifies Auth/App Check, validates Zod contracts, selects fixed
  server models/allowlists, bounds body/result sizes and deadlines, and exposes
  no arbitrary proxy, mutation, or database route.
- Application: `CanonicalAppToolCatalog`, `GovernedAiToolRegistry`, permission
  resolver, response safety, egress guard, local data gateway, and controllers.
- Persistence: v17 AI command, plan, confirmation-proof, idempotency, attempt,
  result, and audit tables. Confirmation authority is consumable and owner-
  scoped; reconciliation handles uncertain responses without repeating effects.

## Supported coverage

Read/query tools cover dashboard/accounts, bounded transaction search, category
and ranked spending, monthly comparison, income/expense, cash flow, net worth,
budgets, goals, recurring items, stored exchange rates, base currency, and
capabilities. Calculators cover savings rate, safe allowance, month-end,
budget/goal/income scenarios, and currency conversion. Local create-draft flows
cover expense, income, transfer, budget, goal, and goal contribution. Navigation
tools open approved local routes.

Create execution is disabled/fail-closed unless environment capability, owner
scope, user-selected control level, local dataset readiness, permission,
confirmation, and idempotency checks all pass. Provider retries cannot create a
second durable effect.

## Confirmation policy in current code

- Read/query/calculation: immediate, bounded, deterministic result.
- Draft creation: local preview; no model authority.
- Confirmed mutation: durable confirmation proof, exactly-once claim,
  application service, transaction, audit, reconciliation.
- Destructive/bulk/account reset: rejected or held behind stronger existing
  product confirmation; prompt text cannot bypass policy.
- External bank/payment action: not implemented. UI may say “recorded,” never
  “sent money.”

## Known limitations

The canonical safe catalog deliberately excludes transaction update/delete and
undo because bounded stale-preview/target/soft-delete use cases are not yet
present. `AiIntent` recognizes destructive language so it can reject it safely,
but end-to-end natural-language edit/delete is not complete. Clear expense/
income still uses review/confirmation rather than automatic execution+undo.

Do not add provider-callable update/delete names first. Implement owner-bound
use cases, exact-target preview, reversible persistence, idempotency, stale
preview detection, and cross-user/duplicate tests; only then extend the catalog
and policy.
