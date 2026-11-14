# Error Handling

## Boundary rule

Infrastructure exceptions are caught at their adapter boundary and translated
to typed application/domain failures. Raw Drift, SQLite, Firebase, Hive, HTTP,
Groq and file-system exceptions must not reach presentation state.

A typed failure carries a stable code, retryability and only safe metadata.
Preserve existing codes during refactoring. Never collapse distinct financial,
authentication or provider failures into one generic error for convenience.

## Financial operations

Validation and owner/reference failures occur before mutation. Atomic workflows
retain their transaction boundary and distinguish validation failure, conflict,
uncertain commit and retry/reconciliation. A retry must not apply a posted
effect twice. Transfer errors retain pair/fingerprint/replay semantics.

## Auth, App Check and deletion

Authentication, unsupported tenant, App Check rejection, stale/recent-auth,
operation conflict, deletion-not-ready and continuation-expired are distinct
states. Protected deletion preserves its lock, tree-empty proof, cloud marker,
Auth-last order and idempotent user-not-found mapping.

## AI and Gateway

The Flutter client receives closed, stable failure codes with no secrets or raw
provider response. Gateway routes translate boundary failures once. SSE emits a
single safe `failure` event and then ends; retries occur only under the existing
same-model policy and never after downstream text was emitted.

Gateway logs use safe correlation fields. Authorization, UIDs, App Check tokens,
financial context and provider content are never logged. HTTP response bodies
are bounded before parsing; malformed provider DTO/SSE states map to typed
Gateway failures.

## Presentation

Widgets receive typed state and select localized safe messages. They may expose
a retry action when the failure is retryable. They never render stack traces,
raw exceptions, secrets or unredacted provider text. A `BuildContext` used after
an asynchronous gap must be guarded by the relevant mounted/lifecycle fence.

## Adding a new mapping

1. Define or reuse the stable failure at the domain/application boundary.
2. Map the exact infrastructure condition in the adapter.
3. Preserve cause detail only in safe internal diagnostics.
4. Add success, mapped-failure and unexpected-failure tests.
5. Add a presentation test for the localized state when user-visible.
6. For a wire boundary, pin status/code/body or SSE ordering.
