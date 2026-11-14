# Local owner-scope architecture

## Decision

CashPilot uses one Drift database with an opaque `owner_scope_id` on every
user-owned or scope-derived row. A repository is constructed from a
`ScopedAppDatabaseSession`; callers cannot provide an owner string per query.

This was selected over one database file per Firebase account because it keeps
the existing local-first transaction, receipt, Finance Engine, backup queue,
and migration boundaries intact while allowing SQLite to enforce same-scope
references atomically. Per-account files would complicate account switching,
backup discovery, legacy-data ownership, and crash recovery and would duplicate
repository/opening logic. The shared database is safe only while every
user-owned table and every access path remains scoped; this document is the
inventory for that invariant.

The model is never an owner-scope authority. Entity IDs also never authorize a
read or write.

## Trusted scope

`ConfirmedOwnerScopeController` observes the last confirmed Firebase Auth
identity. `OwnerScopeDerivation` computes lowercase SHA-256 over the UTF-8
bytes of `cashpilot.local-owner-scope.v1\0<Firebase UID>`. Only the digest is
stored in Drift. The raw UID is not placed in commands, previews, proofs,
audits, model requests, logs, or UI.

Transient auth loading or token refresh preserves the current confirmed scope.
An actual identity change invalidates the scoped session, cancels pending old
scope commands/plans, deletes their confirmation proofs, and constructs a new
session. Executing attempts remain durable for conservative reconciliation;
they are never blindly retried.

## Drift inventory

| Data | Classification | Scope rule | Index / reference rule | Migration, deletion, sync |
| --- | --- | --- | --- | --- |
| accounts | userOwned | nullable only for staged legacy rows; required for new production writes | scope/active index; immutable scope | legacy stays unclaimed; scoped delete and scoped backup |
| categories | userOwned or globalReference | custom rows scoped; only built-in `is_default=1` rows may be global | scope/type index; scoped refs accept only same-scope custom or explicit global default | global defaults survive scoped deletion and are not claimed |
| payees | userOwned | scoped session | scope/name index; default account/category checked in same scope | scoped claim/delete/backup |
| transactions and transfer groups | userOwned | scoped session | scope/date/account/category/transfer indexes; account/category/payee and transfer-group scope triggers | transfer records stay in one scope; scoped backup queue |
| exchange rates | userOwned | scoped session | scope/pair index; active-pair uniqueness includes scope | scoped claim/delete/backup |
| budgets | userOwned | scoped session | scope/active index; category must be same scope or global default | scoped claim/delete/backup |
| goals | userOwned | scoped session | scope/status index; linked account must match scope | scoped claim/delete/backup |
| goal contributions | scopeDerived | inherits bound repository scope | scope/goal index; goal scope checked | scoped claim/delete; no independent global access |
| receipts | userOwned | scoped session | scope/date index; linked payee and transaction checked | scoped claim/delete; receipt images are ownership-checked and not Groq data |
| receipt line items | scopeDerived | inherits receipt scope | scope/parent index; parent scope checked | claimed and deleted with scoped receipt workflow |
| transaction splits | scopeDerived | inherits receipt scope | scope/parent index; receipt, transaction, and category checked | claimed and deleted with scoped receipt workflow |
| sync queue, failures, delete tombstone payloads | systemInternal + scopeDerived | queue repository is bound once to scope | scope/status index; upsert target must exist in same scope | unclaimed rows never sync; deletion operations retain scoped ownership |
| owner-scope migration audits | systemInternal | non-null opaque scope | bounded counts and safe status only | retained as claim audit; no raw records or UID |
| AI commands, previews, proofs, attempts, results, plans, steps, audits, idempotency | scopeDerived | non-null opaque scope | all primary access indexes begin with scope; child-parent scope triggers | deleted by scoped data deletion; old-account pending state detached on switch |
| AI business operations | systemInternal + scopeDerived | non-null opaque scope | unique scope/command/revision/action correlation; attempt and command scope triggers | exact expected identifiers and UI-delivery acknowledgement support restart reconciliation; scoped deletion only |

There are currently no Drift tables for recurring definitions, insight caches,
backup metadata, or app settings. Recurrence is deterministically derived from
scoped transactions; insights are computed from scoped repositories; settings
and optional AI memory use account-keyed local settings rather than financial
Drift rows. These are not exceptions that permit an unscoped financial query.
If any becomes a Drift table, it must be classified and scoped before release.

## Migration and legacy claim

Schema version 15 added nullable owner columns as a staged migration. Schema
version 16 adds the authoritative financial-agent business-operation ledger.
Existing financial rows remain `NULL` and therefore `legacyUnclaimed`;
migration never assigns them to whichever account happens to sign in first.
Production insert triggers reject new null owners (except explicit global
default categories), while immutable-owner triggers allow only the one-time
null-to-confirmed-scope claim.

The Settings claim workflow is native and model-free. It shows bounded counts,
requires an explicit protected confirmation, revalidates the confirmed scope
before and inside a transaction, verifies references, applies owners in parent
before child order, scopes sync rows, and writes a privacy-safe audit. A second
scope cannot replay a completed claim. SQLite rolls the transaction back on an
interruption; no legacy rows are automatically deleted.

Until the legacy count is zero, `OwnerScopeHealthService` returns
`legacyDataUnclaimed`, and AI financial reads/drafts remain disabled.

## Scoped access and database enforcement

All production financial repositories are created from
`requiredScopedAppDatabaseSessionProvider`. Reads, fetch-by-ID, watches,
inserts, updates, archives, deletes, sync operations, receipt image operations,
and data deletion include the bound scope. The production database additionally
installs owner-required, owner-immutable, and same-scope reference triggers.
Custom executors used for historical migration fixtures may opt out of new-write
guards, but production connections cannot.

Global default categories are the sole explicit global financial reference.
They are read-only shared reference rows; a custom category cannot become
global and a built-in default cannot be claimed by an account.

## Durable app-agent runtime

The durable ledger stores commands, versioned previews, hashed confirmation
proofs, execution attempts, verified results, plans/steps, minimal audit events,
idempotency records, and immutable business-operation correlations. It excludes
raw prompts, provider payloads, hidden reasoning, API keys, auth/App Check
tokens, authorization headers, and reusable plain confirmation tokens.

Command state uses compare-and-set transitions. A preview increments the
command revision, supersedes prior previews, records a fingerprint of locally
resolved entities, and moves to `awaitingConfirmation`. Confirmation is local,
scope/command/revision/method bound, short-lived, salted and SHA-256 hashed,
one-time, and transactionally consumed. Confirmation authority is never
reconstructed after restart.

The durable idempotency digest is domain-separated and bound to owner scope,
command ID, command revision, and action type. Claiming an execution inserts
the attempt/idempotency state and changes `confirmed` to `executing` in one
transaction. Completing persists the verified result and final command state
together. A duplicate receives a verified prior result when present or is
blocked as in-progress. If business work may have committed before result
persistence, the attempt stays `executing`; startup recovery resolves the
business-operation receipt and inspects actual scoped business rows. It never
repeats execution. Unacknowledged verified results are restored once to the UI
and acknowledged only after presentation receives them.

## Production handler boundary

Only these deterministic local create drafts are connected to existing use
cases: expense, income, transfer, budget, goal, and goal contribution. Each
handler reloads referenced entities through scoped repositories, compares the
preview fingerprint immediately before execution, then delegates to the
existing `AiActionExecutor`/Finance Engine use cases. Money is persisted as
decimal strings. A screen edit cancels the old durable command and produces a
new command and preview.

Account/category/payee creation, recurring mutations, update/archive/delete,
bulk, and multi-step execution are not production handlers. Plan tables exist
for future crash-safe work, but multi-step production behavior remains off.

## Runtime gates and rollout

Financial access requires all of: confirmed active scoped session, schema 16,
no unclaimed legacy rows, durable agent tables, no detected cross-scope
reference violation, enabled build capability, and explicit account setting.
`CASH_PILOT_AI_LOCAL_DATASET_SCOPE_VERIFIED` remains only an additional kill
switch; it cannot convert an unsafe runtime health state to safe.

All financial AI flags and the compile-time scope flag remain off by default in
this milestone. General chat and deterministic manual financial flows remain
available. No live safety claim is valid until read and draft tests pass on two
real staging Firebase accounts and account switching is observed on a physical
device.
