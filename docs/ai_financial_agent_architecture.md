# CashPilot assistant and governed app-agent architecture

## Current rollout status

General Groq conversation, guarded financial explanations, deterministic local
financial-command parsing, and Firebase receipt vision remain separate product
paths.

Owner-scoped Drift schema v16 now provides the authenticated local owner
boundary, durable agent stores, immutable business-operation correlation, and
startup reconciliation for the six supported financial create handlers.

**Governed financial app-control remains disabled by default and is not yet
live-accepted.** Automated crash and isolation coverage is complete, but two
real staging accounts and a physical Android device must still pass the staged
acceptance matrix before any rollout flag is approved.

`CASH_PILOT_AI_LOCAL_DATASET_SCOPE_VERIFIED` continues to default to `false`.
It may be explicitly enabled only in a controlled staging build after the
staging dataset has passed owner-scope health and account-switching checks.

## Authority boundary

The assistant has a general conversational layer and a governed application
layer. The canonical local intent router selects one route before provider or
tool selection. GPT-OSS or another routed model may understand goals, propose
an allowlisted read/navigation call, organize a bounded plan, request
clarification, or explain a locally verified result. It never receives a
repository, Drift database, Firestore client, balance writer, sync queue,
authentication authority, confirmation proof, or command executor.

The model never holds `executeConfirmedAction`. Only
`AppAgentConfirmationController` can create a short-lived one-time local
confirmation proof, and only `AppAgentCommandExecutor` can consume it.

```text
Assistant UI
  -> local intent and prohibited-request policies
  -> general conversation (no app tools), OR
  -> governed application coordinator
       -> effective build flags + account-scoped user policy
       -> canonical provider-independent tool catalog
       -> bounded model proposal or deterministic financial parser
       -> local entity resolution; no model-provided IDs
       -> AppAgentCommand + state-fingerprinted AppAgentPreview
       -> visible preview and required local confirmation
       -> AppAgentCommandExecutor
            -> scope, expiry, permission, risk, and proof checks
            -> argument and stale-preview revalidation
            -> existing application use case
            -> local result verification
            -> durable command outcome and safe audit event
            -> owner-scoped business-state reconciliation after interruption
       -> verified user-facing result
```

The existing deterministic financial-command parser remains primary for
financial actions. Model assistance is allowed only after deterministic
parsing reports ambiguous or unsupported phrasing, and it can still produce
only a draft proposal.

## Permission and risk policy

`AgentPermission` separates bounded reads, app-configuration reads,
calculations, navigation, create/update/archive/bulk/export drafts, and the
local-only `executeConfirmedAction` authority. `AgentActionRisk` maps to:

- `readOnly`: no confirmation.
- `low`: normal confirmation.
- `medium`: detailed preview and confirmation.
- `high`: double confirmation or protected native workflow.
- `prohibited`: reject; never execute as a generic agent command.

Every mutation requires explicit confirmation regardless of the user's
control level. "Full governed control" widens only the types of drafts the
user may request; it never delegates execution authority to a model.

## Command lifecycle

The provider-independent lifecycle is:

```text
proposed
  -> resolving
      -> needsClarification -> resolving
      -> readyForPreview
          -> awaitingConfirmation
              -> confirmed
                  -> executing
                      -> succeeded | partiallySucceeded | failed
```

Cancellation and expiry are explicit terminal outcomes where allowed by the
state-transition policy. Read-only commands may complete from
`readyForPreview` without entering mutation confirmation. The model may move a
proposal no farther than `readyForPreview`; later transitions are local-only.

An `AppAgentCommand` carries a UUID command ID, conversation ID, local account
scope fingerprint, command/tool type, normalized bounded arguments, permission,
risk, creation/expiry timestamps, status, preview fingerprint, and safe failure
code. Its provider-safe metadata excludes the account scope, entity values,
confirmation state, and execution state.

## Preview and confirmation

Every mutation requires an `AppAgentPreview` containing the entity type,
bounded old/new fields, risk, confirmation level, state fingerprint, creation
time, and, for bulk work, an affected count, bounded item list, omitted count,
and partial-failure behavior.

The confirmation controller verifies scope, expiry, status, and risk. Normal
and detailed actions require the primary confirmation action. High-risk work
requires two explicit high-risk confirmations. Prohibited work is rejected or
redirected to its protected native workflow. A successful confirmation changes
the command to `confirmed` and creates a one-time proof valid for at most two
minutes and never beyond command expiry.

## Local authoritative executor

`AppAgentCommandExecutor` must:

1. Load the command and current authenticated local scope.
2. Reject scope mismatch, expiry, invalid status, replay, or absent proof.
3. Consume the one-time confirmation proof.
4. Match the handler's tool ID, permission, and risk to the command.
5. Apply the local policy to normalized arguments.
6. Require the stored preview and matching fingerprint.
7. Re-resolve current entities through the bounded handler and reject stale
   previews.
8. Atomically claim `confirmed -> executing`.
9. Invoke an existing application use case; never duplicate business logic or
   mutate a balance directly.
10. Verify the actual local result before reporting success.
11. Persist `succeeded`, `partiallySucceeded`, or `failed` and append a safe
    audit event.
12. Acknowledge UI delivery only after the verified result reaches the local
    presentation flow, so an interruption after result persistence can restore
    a safe success notice on restart.

The production runtime uses owner-scoped Drift implementations. In-memory
implementations remain only as unit-test substitutes. Feature flags and runtime
`OwnerScopeHealth.safe` still gate all governed capabilities.

## Durable persistence, correlation, and reconciliation

Drift schema v16 persists account-scoped commands, previews, confirmation
proofs, attempts, results, plans, audits, idempotency records, and authoritative
business-operation correlations. Implemented safeguards include:

- Every lookup and transition includes the current account scope.
- A unique scoped command/idempotency key prevents replay across restarts and
  concurrent executor instances.
- State transitions use compare-and-set semantics.
- Output entity IDs, including both sides and group ID of a transfer, are
  reserved before execution.
- The durable execution claim atomically reserves the operation key and exact
  expected business identifiers before any business use case is called.
- Expense/income IDs and all three transfer IDs are deterministically derived
  from scope, command, revision, action, and entity role. Budget, goal, and
  contribution IDs are the immutable IDs already carried into their use cases.
- Actual business rows remain authoritative. A durable result alone cannot
  prove that a mutation committed.
- A process restart during `executing` enters safe reconciliation; it never
  blindly invokes the use case again.
- Expired drafts cannot execute, and changed entity state invalidates the
  preview.
- Audit contains only command ID, action/entity type, result, timestamp,
  confirmation method, safe failure code, and undo availability.

At startup and confirmed-scope activation, `confirmed`, `executing`,
`partiallySucceeded`, and unacknowledged `succeeded` commands are inspected.
Confirmed commands remain pending and never regain confirmation authority.
Executing commands resolve their scoped receipt and inspect actual transaction,
transfer-pair, budget, goal, or contribution rows. Results are classified as
`verifiedSucceeded`, `verifiedNotExecuted`, `stillInProgress`, `inconsistent`,
or `requiresManualReview`. No reconciliation path calls `executeConfirmed`.

All six enabled creates prohibit automatic retry and automatic resume. A
verified existing business row becomes a durable success; missing state becomes
a safe non-executed failure; partial or inconsistent state requires manual
review and causes no further mutation. Transfer recovery requires both expected
rows, expected roles, group ID, accounts, amounts, currencies, and AI source.

## Account ownership and session cleanup

The open Drift financial dataset is isolated with mandatory owner-scoped rows,
scoped repository sessions, compare-and-set agent transitions, and cross-scope
write triggers. Legacy rows remain unclaimed until the protected native claim
workflow binds them to the active confirmed account. Runtime health fails
closed when schema, session, legacy inventory, or integrity checks are unsafe.

On every authentication-scope transition, production integration must cancel
active runs, clear UI/controller drafts, invalidate scoped providers, clear
confirmation proofs, and clear provider chat sessions. Persisted memory,
commands, and audit history must be keyed by a one-way local scope fingerprint;
another account must receive no rows.

## Bounded understand/read/plan loop

1. Block secret, security-bypass, delete-all, direct-balance, and unrestricted
   data requests locally.
2. Classify the route and build only task-specific sanitized context.
3. Filter the canonical catalog by effective permission and relevance.
4. Validate every model-requested name and argument locally.
5. Execute only a bounded read/calculation/navigation handler or prepare one
   draft plan.
6. Return minimized JSON-compatible evidence to the model when explanation is
   needed.
7. Stop after at most four rounds and twelve tool calls, with no recursive
   model loop.

Unknown, malformed, duplicate, oversized, stale, cross-scope, and timed-out
work fails closed. Provider failure never triggers a financial write or a
semantic mutation retry.

## Privacy and history

Do not send UID, email, phone, tokens, account database IDs, Firestore or file
paths, raw unrestricted transactions, receipt images, full notes, unrelated
history, or hidden reasoning to Groq. Use short-lived opaque references such as
`account_candidate_1` and resolve them locally.

Conversation persistence is opt-in, bounded, account-scoped, and local-only;
session-only memory is the default. Command/audit storage must not contain raw
prompts, provider responses, tool transcripts, secrets, or hidden reasoning.
Clearing user-visible AI activity is scope-specific and must not remove a
still-live minimal replay-prevention tombstone.

## Feature flags and staged rollout

Required defaults are:

- App control: off.
- Read tools: staging-only by default and still blocked unless runtime owner
  scope health is safe.
- Navigation: off.
- Create, update, and archive drafts: off.
- Confirmed financial execution: off behind its own build gate.
- Multi-step plans: off.
- Audit: on.
- Local dataset scope verified: off.

Roll out read-only, draft-only, confirmed creates, and transfer separately. The
current supported confirmed-create set is expense, income, budget, goal, goal
contribution, and finally transfer. Update, archive, delete, recurring, bulk,
and multi-step execution remain disabled. A user setting cannot enable a
compiled-off stage. General Groq chat and Firebase receipt vision remain
independent of these app-control flags.

## Ownership in the codebase

- `domain/agent`: provider-independent conversational contracts and policies.
- `domain/app_agent`: permission, risk, command, preview, plan, audit, settings,
  and canonical catalog contracts.
- `application/agent`: bounded conversational orchestration and current tools.
- `application/app_agent`: local confirmation, command execution, and plan
  runtime.
- `data/agent` and `data/gateway`: provider translation and secure gateway
  transport only.
- `data/app_agent`: account-scoped settings plus durable Drift command, proof,
  attempt, result, audit, idempotency, and business-operation repositories.
- `presentation`: conversation, previews, confirmation, progress, result,
  undo, and safe errors.

Read-only summaries must continue to use existing CashPilot reporting
semantics, including exclusion of internal transfers and loan proceeds from
normal income. Automated recovery acceptance is claimed; two-account Firebase
and physical-device live acceptance is not.
