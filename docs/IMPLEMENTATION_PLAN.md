# Production Transformation Implementation Plan

## Priorities and acceptance

| Priority | Finding / dependency | Risk | Expected impact | Acceptance | Status |
|---|---|---|---|---|---|
| P0 | Preserve dirty worktree and validate identity | High | Avoid data/code loss | Dedicated branch; no reset/clean/restore | Complete |
| P0 | Auth profile request waterfall | High | Faster login/registration return path | One fewer sequential profile read; safe staged trace; auth regressions green | Implemented |
| P0 | Overloaded navigation/Home | Medium | Lower cognitive load and startup fan-out | Four destinations; secondary routes preserved; direct manual entry | Implemented |
| P0 | Arabic/LYD parsing and withdrawal semantics | High | Correct daily Libyan entry | Three decimals, digit variants, half/quarter, yesterday, withdrawal not expense | Implemented |
| P0 | AI destructive/update/delete coverage | High | Trustworthy edits/deletes | Owner-bound typed tools, exact target, soft delete/undo or confirmation, idempotency | Not implemented; do not enable until bounded use cases exist |
| P1 | Low-risk create + undo policy | High | Faster AI entry | Durable write, reversible undo, no success-before-persistence, retry idempotency | Deferred behind missing undo semantics |
| P1 | Alias update channel | Medium | Correct local names without release | Signed/versioned config, safe fallback, cache and rollback | Seed complete; update channel pending |
| P1 | Release startup profiling | Medium | Useful content faster on mid-range device | Profile/release physical trace, request waterfall and frame data | Blocked by device/release config |
| P1 | Production release gates | High | Deployable artifact | Final ID/signing/SHA, Play Integrity, physical acceptance, Web App Check | External blocker |

## Phases

1. Discovery/safety: repository identity, branch, instructions, baseline, audit,
   architecture/financial/AI/localization rules.
2. Auth/startup: measure source request sequence, remove duplicate sequential
   profile read, add safe stage timing. Validate auth controller/session tests.
3. Product shell: Home/Transactions/AI/Settings; progressive disclosure for
   planning/configuration; direct manual entry; remove eager Home providers.
4. Libya foundation: bank/payment registries, dialect vocabulary, exact Decimal
   parsing, relative dates, transfer-vs-expense protections, 20-case corpus.
5. Verification: format, localization generation, analyzer, Flutter/gateway/
   Firestore tests, builds, secret scan, and documented skipped live gates.
6. Follow-up: implement typed update/delete/undo use cases before relaxing the
   fail-closed AI mutation policy; then run physical profile/release acceptance.

No schema migration is introduced by the completed phases. If phase 6 needs
soft deletion or undo metadata, add a new schema version with v17 upgrade and
recovery tests; never retrofit columns silently.
