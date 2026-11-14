# AI tool permission policy

CashPilot, not a model or provider, is the authority for permissions,
validation, confirmation, execution, persistence, and audit. A model may
understand a request and propose an allowlisted tool call, but that proposal is
untrusted input.

## Permission model

Every canonical tool has exactly one `AgentPermission`:

| Permission | Allowed effect | Model availability |
| --- | --- | --- |
| `readFinancialData` | Read a bounded, minimized financial view through an approved application use case | Allowlisted only after the financial-data scope gate is satisfied |
| `readAppConfiguration` | Read a bounded non-secret application setting | Allowlisted when a dedicated bounded adapter exists |
| `calculate` | Run deterministic local `Decimal` calculations | Allowlisted |
| `navigate` | Select one route from the fixed local route allowlist | Allowlisted when navigation rollout is enabled |
| `createDraft` | Prepare a typed create draft and preview; never save it | Deterministic-first; model assistance is not currently exposed |
| `updateDraft` | Prepare a typed update draft showing old and new values | Deferred until a bounded update use case and stale-preview support exist |
| `archiveDraft` | Prepare an archive, pause, resume, or cancel draft | Deferred until a bounded status-transition use case exists |
| `bulkDraft` | Prepare one bounded multi-item draft and combined preview | Deferred |
| `exportDraft` | Prepare a bounded export request for a protected local workflow | Not model-callable in the current catalog |
| `executeConfirmedAction` | Execute a locally confirmed command | Local confirmation/executor authority only; never model-callable |

The model may request only `readFinancialData`, `readAppConfiguration`,
`calculate`, `navigate`, `createDraft`, `updateDraft`, `archiveDraft`, or
`bulkDraft`, and only when the exact tool is present in the declared subset.
It never possesses `executeConfirmedAction`. The current safe catalog is more
restrictive than this maximum permission surface.

## Risk and confirmation model

Every tool and command also has one `AgentActionRisk`:

| Risk | Local behavior | Confirmation |
| --- | --- | --- |
| `readOnly` | Bounded read, calculation, or allowlisted navigation | None |
| `low` | Reversible or narrowly bounded draft | Normal explicit confirmation |
| `medium` | Material change or transfer-like workflow | Detailed preview and explicit confirmation |
| `high` | Bulk or destructive-impact workflow | Two explicit confirmations, or delegation to a protected native workflow |
| `prohibited` | Capability is unavailable to the assistant | Rejected; a protected native workflow may be shown when one exists |

`AppAgentPolicy.confirmationLevelFor` is authoritative. User settings cannot
remove confirmation: `requireConfirmationForEveryChange` is policy-locked to
`true`, including under "Full governed control."

## Enforcement

The effective permission is the intersection of:

```text
compiled rollout flag
AND account-scoped user opt-in
AND authenticated local scope
AND verified local financial-data ownership (for financial reads/drafts)
AND canonical tool declaration
AND permission and risk policy
AND local argument validation
```

The policy rejects unknown tools and arguments, missing required values, wrong
types, unsupported enum values, non-finite values, strings over 256 characters,
lists beyond their configured bound, excessive nesting, secret/raw-data
argument names, and money or exchange-rate fields that are not decimal
strings. Opaque temporary references are resolved locally; a model never
supplies database IDs.

Firebase Authentication, Firebase App Check, gateway request validation,
provider quotas, and Firebase rules remain mandatory. Client allowlists are
defense in depth, not server authorization.

## Command and confirmation authority

The model may advance a proposal only as far as `readyForPreview`. A write
then follows this local-only path:

```text
model or deterministic parser proposes bounded intent
  -> local entity resolution and argument normalization
  -> typed command and state-fingerprinted preview
  -> awaitingConfirmation
  -> AppAgentConfirmationController issues a one-time local proof
  -> confirmed
  -> AppAgentCommandExecutor revalidates scope, expiry, policy, entities,
     handler permission/risk, and preview freshness
  -> existing application use case
  -> locally verified result
  -> safe audit event
```

The one-time confirmation proof is never included in model context, logs,
audit events, or UI messages. The executor never accepts a model claim that an
operation was confirmed or succeeded.

## Required rollout flags

| Flag | Conservative default |
| --- | --- |
| `CASH_PILOT_AI_APP_CONTROL_ENABLED` | `false` |
| `CASH_PILOT_AI_READ_TOOLS_ENABLED` | `true` only when `CASH_PILOT_ENVIRONMENT=staging`; otherwise `false` |
| `CASH_PILOT_AI_NAVIGATION_TOOLS_ENABLED` | `false` |
| `CASH_PILOT_AI_CREATE_DRAFTS_ENABLED` | `false` |
| `CASH_PILOT_AI_CONFIRMED_EXECUTION_ENABLED` | `false`; enable only after draft-only and reconciliation acceptance |
| `CASH_PILOT_AI_TRANSFER_EXECUTION_ENABLED` | `false`; enable only after the other five confirmed creates pass restart acceptance |
| `CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED` | `false` |
| `CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED` | `false` |
| `CASH_PILOT_AI_MULTI_STEP_PLANS_ENABLED` | `false` |
| `CASH_PILOT_AI_AGENT_AUDIT_ENABLED` | `true` |
| `CASH_PILOT_AI_LOCAL_DATASET_SCOPE_VERIFIED` | `false` |

An absent account policy resolves to `Off`; all analysis, navigation, draft,
recurring, and multi-step toggles resolve to `false`. General conversation is
separate from the app-control master flag.

## Production rollout boundary

**Financial read and write rollout remains disabled by default.** The current
local Drift data and action stores are authenticated-owner-scoped and durable,
and their migration/isolation/restart boundaries have deterministic coverage.
That closes the former storage prerequisite but not production rollout. Do not
set `CASH_PILOT_AI_LOCAL_DATASET_SCOPE_VERIFIED=true` until the target build has
completed controlled live policy, consent, bounded-context, App Check, and
manual financial-accuracy acceptance.

Until then, the governed app-control policy must fail closed for financial
reads and drafts. General conversation and separately flagged allowlisted
navigation may continue without granting financial mutation authority.

## Privacy and session history

Only task-specific bounded context may leave the device. Never send UID,
email, phone, authentication tokens, database IDs, Firestore paths, filesystem
paths, raw unrestricted transactions, receipt images, full notes, secrets, or
unrelated history. Conversation persistence remains opt-in and account-scoped;
session-only memory is the default. Authentication-scope changes must cancel
active work and clear local confirmation proofs, controller state, and model
sessions before another account can use the assistant.
