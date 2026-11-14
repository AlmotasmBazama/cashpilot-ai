# Financial agent staging activation

This runbook is staging-only. Use synthetic financial data and a dedicated
Firebase project. Never place account credentials, Firebase tokens, App Check
tokens, provider keys, or raw records in a dart-define file, test output, or
issue attachment.

All stages require a confirmed Firebase Auth session and runtime
`OwnerScopeHealth.safe`. Build flags cannot override an unsafe scope.

## Stage 1: read-only

Use these non-secret build capabilities:

```json
{
  "CASH_PILOT_ENVIRONMENT": "staging",
  "CASH_PILOT_AI_APP_CONTROL_ENABLED": "true",
  "CASH_PILOT_AI_READ_TOOLS_ENABLED": "true",
  "CASH_PILOT_AI_NAVIGATION_TOOLS_ENABLED": "false",
  "CASH_PILOT_AI_CREATE_DRAFTS_ENABLED": "false",
  "CASH_PILOT_AI_CONFIRMED_EXECUTION_ENABLED": "false",
  "CASH_PILOT_AI_TRANSFER_EXECUTION_ENABLED": "false",
  "CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED": "false",
  "CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED": "false",
  "CASH_PILOT_AI_MULTI_STEP_PLANS_ENABLED": "false",
  "CASH_PILOT_AI_AGENT_AUDIT_ENABLED": "true",
  "CASH_PILOT_AI_LOCAL_DATASET_SCOPE_VERIFIED": "true"
}
```

Set the active account's local control level to read-only and enable financial
analysis. Do not enable draft settings. Verify only bounded summaries are sent
to the gateway and that account switching changes every visible result.

## Stage 2: durable drafts only

Change only `CASH_PILOT_AI_CREATE_DRAFTS_ENABLED` to `true`. Keep confirmed and
transfer execution false. The confirmation card remains visible, but its save
action is disabled by the independent execution gate. Verify that each draft
survives restart and no financial business row exists.

## Stage 3: limited confirmed creates

After Stage 2 and the crash matrix pass, set
`CASH_PILOT_AI_CONFIRMED_EXECUTION_ENABLED=true`. Keep
`CASH_PILOT_AI_TRANSFER_EXECUTION_ENABLED=false`. This permits only the
currently connected expense, income, budget, goal, and goal-contribution
creates after local confirmation. Update, archive, delete, recurring, bulk,
and multi-step handlers remain absent.

## Stage 4: transfer last

Enable `CASH_PILOT_AI_TRANSFER_EXECUTION_ENABLED=true` only after the other five
creates pass confirmation replay, process restart, and account-switching tests.
For every transfer, verify exactly two scoped transactions, opposite transfer
roles, one shared deterministic group ID, atomic balances, and no duplicate
pair after restart.

## Required two-account evidence

For staging accounts A and B, record only pass/fail statuses and bounded counts.
Do not record identifiers. A must not expose any row, memory, draft, result,
audit, operation receipt, or confirmation proof to B. A forged A entity ID used
from B must resolve as absent or be rejected. Switching back to A must restore
only A's pending draft or unacknowledged verified result.

## Current acceptance state

Automated owner-scope, operation-correlation, reconciliation, duplicate, UI
restoration, and crash-point tests pass. Two-account Firebase staging and a
physical Android run remain required; emulator evidence must not be substituted
for either gate.
