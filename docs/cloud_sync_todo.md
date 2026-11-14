# Backup and Synchronization Foundation

The current implementation is backup-only and uses the authenticated
`users/{uid}` boundary. Drift remains the source of truth.

## Implemented

- User-scoped Firestore documents for accounts, transactions, categories,
  payees, exchange rates, budgets, goals, settings, and device metadata.
- A user-owned Drift sync queue with pending, synced, failed, and deleted
  states plus attempt and error metadata.
- Transactional compaction keeps one active item per user/entity and preserves
  the latest operation and payload without losing prior attempt counts.
- Best-effort repository hooks that run only after successful local writes.
- Soft-delete tombstones in Firestore. Backup processing never mutates local
  balances or reads cloud data into Drift.
- Opt-in backup controls, queue counts, last-success time, manual backup, and
  retry controls in Settings. Guest and unauthenticated sessions are blocked.
- GitHub Actions runs the Firestore rules and account-deletion emulator suites
  against the local `demo-cashpilot-ai` project.

## Restore Contract

`RestoreService` defines preview and explicitly confirmed restore operations,
but has no implementation. Do not add Firestore-to-Drift writes until conflict
resolution, schema compatibility, ownership validation, rollback, and a
non-destructive preview are designed and tested.

## Remaining Work

- Add bounded exponential backoff for high-volume or unreliable networks.
- Add schema versions and idempotency tokens to backup documents.
- Define guest-data ownership when an anonymous user upgrades an account.
- Require recent authentication for any future destructive cloud operation.
- Add pull pagination and conflict resolution only as part of the restore work.
- Add account-linking flows for anonymous users upgrading to email, Google, or Apple.
- Add a portable data-export flow aligned with privacy requirements.
- Add monitoring for auth failures, sync queue retries, and Firestore rule denials.
