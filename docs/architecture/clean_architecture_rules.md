# CashPilot AI Clean Architecture Rules

This document describes the architecture enforced by the current repository. It
is not a target diagram detached from the implementation.

## Feature layout

Feature code remains under `lib/features/<feature>` and normally uses four
layers:

- `domain`: entities, value objects, pure policies, typed failures, repository
  and service contracts.
- `application`: use-case orchestration, controllers, coordinators and Riverpod
  composition. Application code may coordinate several domain contracts.
- `data`: Drift, Hive, Firebase, HTTP and file-system adapters, DTOs, mappers and
  repository implementations.
- `presentation`: screens, widgets, dialogs, form state and rendering-only view
  models.

Not every feature needs every layer. A new abstraction is justified by a real
boundary, variation point or independently testable policy—not by file count.

## Dependency rules

The normal direction is:

```text
presentation -> application -> domain
data ------------------------> domain
framework adapter -----------> application/domain port
```

Domain code must remain pure Dart. It must not import Flutter, Riverpod, Drift,
Firebase, Hive, HTTP, presentation, DTOs or data implementations. Pure packages
already used by the domain, such as `decimal`, are allowed.

Presentation may watch application providers and call controllers/use cases. It
must not instantiate repository implementations, access Drift/Firebase/Hive, or
perform owner authorization, financial calculations or provider JSON parsing.

Data implements domain/application ports and maps infrastructure failures before
they cross the boundary. Data never imports presentation. Cross-feature code
must use a narrow public facade or contract at the feature root; importing
another feature's private `data/` or `presentation/` path is forbidden.

`core` is limited to stable cross-cutting technical concepts. `shared` contains
proven reusable product/UI concepts. Feature-specific code stays with its owner.

## Composition roots

- `lib/core/database/app_database.dart` is the Drift schema/composition root.
  Its schema version is 17. Schema annotations, persisted names and migration
  behavior are compatibility contracts.
- `lib/app/router/app_router.dart` is the navigation composition root. Public
  route names and paths are protected by route contract tests.
- `lib/app/di` is the outer Riverpod composition root for bindings that must see
  more than one feature. It adapts provider-owned capabilities to
  consumer-owned ports/projections; it must not acquire business rules.
- Feature Riverpod provider files compose adapters owned by that feature.
  Business rules stay in policies, use cases, workflows and controllers.
- `services/cashpilot_ai_gateway/src/index.ts` is the production Node
  composition root; `app.ts` constructs the HTTP application from narrow ports.

## Public compatibility

Purpose-built narrow facades use `show` when they expose only part of a source
library. Feature-root public APIs may instead enumerate stable source libraries,
and compatibility facades may re-export an entire deliberately narrow module
when preserving all of its public names or the identity of a provider object.
Broad directory-style barrels are avoided. A moved internal symbol may keep a
narrow compatibility re-export when existing callers or tests depend on its
path. External JSON keys, SSE events, route names, provider IDs,
Hive/secure-storage keys and Drift columns are never renamed in an architecture
batch.

## Financial and AI invariants

- Financial values use `Decimal` or decimal strings; never introduce `double`
  into financial calculation paths.
- Account effects pass through Finance Engine. Posted effects occur exactly
  once; pending entries have no balance effect; update/delete/cancel preserve
  reversal semantics.
- Transfers remain a two-leg atomic pair with explicit cross-currency rates.
- Owner scope is derived from authenticated state, never from an entity ID or
  model response.
- The AI model is not execution authority. Mutations retain preview,
  confirmation, durable exactly-once execution and reconciliation.
- Firebase ID/App Check tokens never enter Groq payloads. Groq credentials stay
  server-side.
- Receipt confirmation and cleanup remain owner-scoped and idempotent.

Application workflow owners are framework-free wherever UI context is not part
of the capability. In the current implementation, receipt review/capture
resource ownership, AI provider sessions, AI conversation/response policy,
durable draft transitions and the assistant conversation state machine live
behind typed collaborators. Screens remain rendering and effect hosts; they do
not regain repository, provider JSON, owner-authorization or financial workflow
logic.

## Enforcement

Run:

```text
flutter test --no-pub test/architecture
```

`dart_dependency_rules_test.dart` has a zero strict-edge baseline.
`feature_dependency_cycle_test.dart` separately ratchets the current indirect
feature-cycle debt: one 9-feature strongly connected component with 31 exact
directed edges (down from 13/48 when the guard was added). New cycle edges are
forbidden; removing an edge makes the stale baseline fail until the entry is
deleted, and exact component membership/count are checked explicitly.

Gateway/tool boundaries are enforced by
`services/cashpilot_ai_gateway/tests/architecture.test.ts`; its original
20-entry debt baseline is now empty. The final repository closure passed the
20/20 Dart architecture suite, the complete Flutter suite at 1,623/1,623,
Gateway at 133/133 with lint/typecheck/build, and deterministic tool tests at
154/154. Live device runners are deliberately outside these deterministic
commands and require an authorized Android target.
