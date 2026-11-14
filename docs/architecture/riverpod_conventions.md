# Riverpod Conventions

## Provider roles

- Configuration providers expose immutable runtime/config values.
- Adapter providers construct one concrete implementation from narrower ports.
- Use-case/controller providers compose behavior; they do not duplicate domain
  rules inside provider callbacks.
- Derived providers calculate cheap presentation-ready state from typed inputs.
- `Notifier`/`AsyncNotifier` classes own cancellable user workflows and explicit
  state transitions.

Provider declarations are dependency wiring, not a service locator. Do not read
the global container from domain/data code.

## Naming and identity

Use descriptive `<capability>Provider` names and set Riverpod's `name` when the
surrounding subsystem already does so. Existing public provider variables are
compatibility contracts for overrides and tests; preserve them during file
splits by re-exporting or moving all callers in one controlled batch.

## Lifetimes

Use `autoDispose` for request-scoped clients, transient forms and screen-owned
work. Keep stores/controllers alive only when their durable or app-scoped role
requires it. Close HTTP clients, streams, subscriptions and timers through
`ref.onDispose`.

Never create duplicate Drift watchers or remote requests merely to make a
provider graph simpler. Derived providers should reuse an existing canonical
stream/state source.

## Owner transitions

Any state that can reveal user data must be keyed by or watch the current owner
scope. Asynchronous work records the scope/generation at start and discards a
result if the owner changes. Sign-out and user A→B transitions must invalidate
scoped repositories, caches, AI memory, receipt drafts and pending UI state.

Auth coordination uses the public Auth ports. Firebase implementations remain
under Auth data. Presentation never imports Firebase Auth or App Check provider
implementations directly.

## Errors and state

Expose typed loading/success/failure state. Do not pass raw Firebase, Drift,
Hive, HTTP or provider exceptions to widgets. Retain stable error codes and
retryability. Cancellation and stale results are distinct from user-visible
failure.

## Testing providers

Use `ProviderContainer` with explicit overrides for ports and clocks. Cover:

- initial/loading/success/failure;
- retry and cancellation;
- disposal and listener cleanup;
- owner switch and stale-result fencing;
- provider preference and feature-flag combinations;
- exactly-once controller behavior.

Dispose every test container. Prefer overriding a narrow port over mocking a
large repository or Firebase singleton.
