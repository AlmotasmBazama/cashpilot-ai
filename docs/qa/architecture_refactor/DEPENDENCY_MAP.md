# CashPilot AI dependency and architecture map

Snapshot: 2026-08-17, before architecture-refactor implementation changes.

## Scope and method

The map was built from the current working tree, not from historical documentation. It inspected every Dart file under `lib`, all test and integration-test files, the gateway and tooling trees, the dependency manifests, and existing QA reports. Imports and exports were resolved at file and feature level; generated files were excluded from handwritten architecture findings.

- Dart files under `lib`: 622.
- Handwritten Dart files: 567 (`app` 9, `core` 46, `shared` 34, `features` 476, plus ARB sources in `l10n`).
- Generated Dart files: 55 (core 6, features 46, localization 3).
- Feature roots: 20.
- Provider declarations: 268.
- Controller classes: 10.
- Repository-contract files: 17.
- Repository-implementation files: 12.
- Use-case files: 94.
- DTO files: 11.
- Drift table files: 13.
- Feature public barrels: 10.
- File-level strongly connected components: none.

Generated `*.g.dart`, `*.freezed.dart`, and generated localization files are not handwritten architecture targets.

## Intended dependency direction

```text
presentation -> application -> domain
data -----------------------> domain
app/composition -> application contracts + concrete adapters
```

`core` is restricted to stable cross-cutting technical concepts and `shared` to genuinely reusable product/UI concepts. Feature-to-feature data implementations and feature-to-feature private presentation helpers are not public integration boundaries.

## Feature inventory

`files` counts handwritten Dart files. Layer counts are `domain/application/data/presentation`.

| Feature | Files | Layers | Main providers | Repository contracts → implementations | Principal use cases / responsibilities |
|---|---:|---|---|---|---|
| accounts | 32 | 11/1/5/14 | `accounts_providers` | `AccountsRepository`, `OpeningBalanceLedger` → `AccountsRepositoryImpl` | create/update/delete/get accounts; opening-balance integration |
| ai_assistant | 103 | 47/27/23/6 | 8 provider modules | `AiRepository` and AI/agent/gateway/app-control ports → local/Firebase/Groq/Drift/Hive adapters | routing, conversation, governed tools, drafts, confirmation, reconciliation, diagnostics |
| app_shell | 2 | 0/0/0/2 | none | none | responsive navigation shell |
| auth | 33 | 15/1/7/10 | `auth_providers` | `AuthRepository` → `AuthRepositoryImpl` | sign-in/up/out, reauth, profile, auth stream |
| budgets | 27 | 17/1/6/2 | `budgets_providers` | `BudgetRepository` → `BudgetRepositoryImpl` | budget CRUD/progress and bounded transaction window |
| categories | 28 | 18/1/5/3 | `categories_providers` | category and correction-rule contracts → `CategoriesRepositoryImpl` | CRUD, defaults, taxonomy, classification |
| dashboard | 3 | 0/1/1/1 | `dashboard_providers` | no explicit feature contract | bounded financial snapshot/read model and UI |
| data_deletion | 21 | 5/4/11/1 | `data_deletion_providers` | `DataDeletionRepository` → `DataDeletionRepositoryImpl` | protected deletion, continuation, recovery, local/cloud cleanup |
| exchange_rates | 22 | 13/1/6/1 | `exchange_rates_providers` | `ExchangeRateRepository` → `ExchangeRateRepositoryImpl` | archive/upsert/watch/resolve/convert |
| finance_engine | 18 | 17/0/0/0 | none | balance/rate/transaction-manager ports | pure money, balance, transaction and transfer processing |
| goals | 30 | 17/1/8/3 | `goals_providers` | `GoalRepository` → `GoalRepositoryImpl` | goal CRUD, progress and contributions |
| income_sources | 6 | 5/0/0/0 | none | no repository | classification, resolution, reporting policy |
| insights | 17 | 14/1/0/1 | `insights_providers` | no repository | pure insight detectors/comparison and insight UI |
| payees | 27 | 16/1/5/4 | `payees_providers` | `PayeesRepository` → `PayeesRepositoryImpl` | resolution, search, archive/restore and usage |
| payment_methods | 2 | 2/0/0/0 | none | no repository | payment-method catalog/domain definitions |
| profile | 1 | 0/0/0/1 | none | none | profile presentation |
| receipts | 54 | 40/2/10/2 | `receipt_providers` | receipt analysis/repository ports → Firebase/local implementations | capture, prepare, analyze, parse, draft, confirm and cleanup |
| reports | 1 | 0/0/0/1 | none | none | report presentation consuming shared financial snapshots/policies |
| settings | 8 | 0/1/0/7 | `base_currency_provider` | no explicit repository | settings UI and persisted/shared configuration |
| transactions | 41 | 19/2/12/7 | `transactions_providers` | `TransactionsRepository` → `TransactionsRepositoryImpl` | transaction CRUD/status/search/pagination and transfer orchestration |

The presentation-only/domain-only shapes are not automatically defects; they describe the current architecture. `dashboard`, `reports`, and `settings` need explicit application/domain seams where logic presently leaks into providers/widgets.

## Core and shared inventory

| Area | Handwritten files | Current responsibility |
|---|---:|---|
| core/config | 2 | app/runtime configuration |
| core/database | 2 | Drift database, schema composition and provider |
| core/di | 1 | compatibility provider barrel |
| core/error | 3 | typed failure/result/exception boundary |
| core/firebase | 6 | initialization, providers, App Check readiness |
| core/owner_scope | 6 | scope value, session, health, legacy claim and providers |
| core/storage | 4 | settings and owner-scoped storage keys |
| core/sync | 15 | backup/sync queue, fences and Firestore adapter |
| remaining core | 7 | localization, logging, responsive, serialization, theme, extensions |
| shared/design_system | 26 | reusable tokens/theme/widgets |
| shared/presentation | 5 | cross-feature formatters/widgets |
| shared/domain | 2 | localized decimal/currency parsing |
| shared/accessibility | 1 | acceptance semantics |

`AppDatabase` centrally imports feature Drift tables; this is recorded as schema composition, not as a feature consuming a sibling feature's private implementation. It remains a coupling hotspot and must retain schema version 17 and exact table/migration behavior.

## Strict import findings

The scanner found 44 unambiguous forbidden import edges. Each edge has an individual `AR-*` row in `REFACTORING_INVENTORY.csv`.

| Rule | Count | Summary |
|---|---:|---|
| Domain purity | 4 | AI domain imports Flutter/localization and a Firebase-coupled core type |
| Cross-feature private data | 15 | accounts/AI/budget/dashboard/deletion consume sibling private adapters/services/mappers |
| Cross-feature private presentation | 23 | shared labels, visuals, cards and deletion UI live inside sibling features |
| Presentation to Firebase infrastructure | 2 | deletion continuation directly uses Firebase Auth/provider composition |
| Total | 44 | no generated files counted |

Three additional handwritten compatibility shims re-export Payees private data from Transactions:

- `transactions/data/datasources/local/tables/payees_table.dart`
- `transactions/data/dtos/payee_dto.dart`
- `transactions/data/mappers/payee_mapper.dart`

These are migration debt and cannot be treated as a stable public boundary.

## Domain-purity details

- `general_assistant_policy.dart` imports Flutter `Locale` and generated `AppLocalizations`; domain policy therefore owns rendering/localization.
- `ai_runtime_status.dart` imports Flutter foundation solely for `@immutable`, and imports Firebase-coupled `FirebaseAppCheckActivationState` into an AI domain snapshot.
- `analyze_receipt_image.dart` imports a core application fence. This reverse layer edge is tracked separately because it is not a framework import but still violates the intended domain direction.

The target design is typed domain decisions/message keys and application/presentation localization, plus an AI-owned readiness value mapped from Firebase at the adapter boundary.

## Feature dependency graph and cycles

There is no Dart file-level import cycle. At feature-module level, one strongly connected component contains 13 features:

```text
accounts, ai_assistant, budgets, dashboard, data_deletion, goals,
income_sources, insights, payees, payment_methods, receipts, settings,
transactions
```

Direct reciprocal pairs:

1. Accounts ↔ Transactions — opening-balance adapter/provider composition.
2. AI Assistant ↔ Insights — financial gateway versus explanation use case/UI.
3. AI Assistant ↔ Receipts — assistant screen/capture workflow versus receipt providers.
4. AI Assistant ↔ Settings — financial gateway/config versus settings UI.
5. Dashboard ↔ Insights — dashboard rendering versus insight provider input.
6. Data Deletion ↔ Settings — continuation dialog versus settings deletion entry point.
7. Income Sources ↔ Transactions — reporting policy versus transaction mapping.
8. Payees ↔ Transactions — payee details/cards/providers versus transaction mapping.
9. Receipts ↔ Transactions — receipt confirmation/providers versus transaction screen entry point.

These are module cycles, not runtime/file cycles. Break them through narrow domain/application contracts, feature façades, and app-level presentation composition; do not introduce a global service locator.

## Application and infrastructure coupling

- Application code has 11 direct Drift/Hive imports. Provider composition is assessed separately, but concrete leaks include `ScopedAppDatabaseSession` exposing `AppDatabase`, `DurableAiActionBridge` requiring a concrete Drift store, `ProductionFinancialCommandHandler` querying `AppDatabase`, and Hive stores located under application.
- Twelve non-provider application files import data-layer files directly. Several targets colocate ports and implementations, including `SyncQueueRepository` and `DriftSyncQueueRepository`.
- Presentation directly reads `receiptRepositoryProvider` and instantiates `ValidateReceiptAnalysisUseCase` in `receipt_review_screen.dart`.
- Presentation performs transfer amount/rate calculations in `transfer_screen.dart` and constructs receipt `Money`/`ExchangeRate` values in the review widget.

These seams require characterization before movement because they touch cancellation, owner scope, confirmation, rate semantics, or exactly-once behavior.

## Size and responsibility hotspots

File/class size is only a signal. The following were classified because their methods span distinct responsibilities:

| Symbol | Approx. lines | Mixed responsibilities |
|---|---:|---|
| `AppDatabase` | 2,420 | schema/migrations, transfer integrity, balance capabilities, owner deletion, legacy claim |
| `_AiAssistantScreenState` | 2,065 | rendering, lifecycle, scope fencing, conversation, permissions, durable execution, draft editing |
| `AiAgentOrchestratorImpl` | 1,447 | routing, provider loop, local plan, tools, memory, persistence, timeouts, fallback |
| `TransactionsRepositoryImpl` | 1,103 | CRUD, transfer pairing, replay/idempotency, reversal/balance, sync queue |
| `AiActionDraftFactory` | 829 | multiple action-family draft parsers/builders |
| `_ReceiptReviewScreenState` | 791 | form/rendering plus validation/resolution/confirmation orchestration |
| `DataDeletionRepositoryImpl` | 790 | durable phases, local/cloud deletion, auth-last and recovery |
| `FirebaseAuthDataSource` | 737 | providers, credential flows, session guards and auth operations |
| `DriftSyncQueueRepository` | 712 | queue persistence, compaction, retries and migration repair |
| `ReceiptRepositoryImpl` | 579 | aggregate persistence, reservation/finalization and mapping |

Provider hotspots are `ai_agent_providers.dart` (28 providers), `ai_assistant_providers.dart` (26), `transactions_providers.dart` (24), `auth_providers.dart` (23), `data_deletion_providers.dart` (21), and `receipt_providers.dart` (15 plus a 423-line controller).

`dashboard_screen.dart` is a 2,101-line organization hotspot containing many mostly small widgets; it is not classified as one god class solely from file size.

## Stable duplication

- `core/responsive/app_breakpoints.dart` and `shared/design_system/tokens/cp_breakpoints.dart` define the same size classes and thresholds (599/839/1120); `shared/presentation/widgets/adaptive_page.dart` bridges both.
- Gateway AI routes repeat the authenticated/validated/rate-limited/aborted/streamed request lifecycle.
- Gateway Firebase adapters initialize named Admin apps independently and duplicate the empty-user-tree query.
- Gateway Zod tool argument schemas and provider JSON schemas are manually duplicated.
- Android tooling repeats ADB, App Check, Firebase CLI, XML, safe-marker and cleanup primitives across three or more files.
- Dart and TypeScript financial-tool metadata intentionally use defense-in-depth implementations, but lack language-neutral parity fixtures for IDs/shapes/dimensions/error codes.

## Gateway and tooling map

Gateway scope: 30 source TypeScript files / 5,731 lines, 10 test files / 4,498 lines, and 2 scripts. No gateway import cycle was found.

```text
server.ts -> index.ts composition/app factory
index.ts -> auth + security middleware + routes
routes -> request contracts + Groq client + route dependencies
Groq client -> HTTP/completion/SSE/provider parsing
account deletion routes -> auth verification + deletion stores
security -> CORS, limits, redaction, provider-output safety
```

Major gateway debt: ports colocated with adapters, duplicated broad dependency bags, mixed composition/app factory in `index.ts`, repeated AI route lifecycle, oversized Groq client/response parser/account-deletion controller, manually duplicated schemas, and no import-boundary test.

Tooling scope: 22 files / 12,650 lines, including 6 test files with 130 top-level tests. The largest support module is 2,984 lines and combines ADB, UI XML, auth, App Check, build/install, cloud fixture cleanup and scenario orchestration. Live scripts can mutate synthetic cloud/device state and are not routine refactor gates.

## Dependency classification

- Flutter runtime dependencies: 34 of 36 are directly evidenced and required.
- `cupertino_icons`: strongest removal candidate, but removal belongs to a separate dependency batch with all builds.
- `json_annotation`: generated/tooling candidate; generated output prevents text-search-only removal.
- All eight Flutter dev dependencies are evidenced as testing, analyzer or generation tooling.
- Firebase AI and HTTP/Groq are intentional provider capabilities, not duplicate-removal candidates.
- Root Firebase packages are test-only and required by emulator suites.
- All gateway runtime/dev packages are used; Express 4 with `@types/express` 5 is a version-family risk, not an architecture-refactor upgrade.
- Tooling depends on global Firebase CLI internals, ADB, Flutter and PowerShell; document/validate rather than silently changing dependencies.

## Existing guards and gaps

Existing narrow guards protect owner-scoped Drift writers, deletion architecture/secure storage, and authoritative transfer capabilities. No general layer/import scanner exists. There is also no complete route/deep-link matrix, localization key/placeholder parity test, reusable repository contract suite, or Dart↔TypeScript financial-tool parity fixture.

The initial architecture guard will ratchet the 44 explicit edges: it must reject new violations immediately, print the source/import/expected direction/suggested layer, and reduce its baseline allowlist to zero as edges migrate.

## Post-refactor dependency delta

The baseline above is intentionally retained for before/after evidence. The
implemented structure now differs as follows:

- All 44 strict Dart edges were migrated; the exact strict allowlist is empty.
  Domain purity uses a neutral App Check status contract and application-owned
  assistant policy. Auth, Transactions and Receipts expose provider-owned
  public capabilities where they intentionally serve consumers. Conversely,
  Insights owns its optional explanation port and Goals owns its linked-account
  projection because those contracts change with the consumer.
- `lib/app/di` is the outer cross-feature Riverpod composition root. Its
  financial-Insights binding assembles Dashboard/Budget/Goal/FX inputs without
  assigning their snapshots to another feature. Its Goals binding projects the
  unchanged Accounts provider into `GoalLinkedAccountOption`. Compatibility
  facades re-export the same provider objects; they do not create wrappers or
  duplicate state.
- An additional Tarjan feature-graph guard initially recorded one indirect
  13-feature SCC with 48 exact internal edges. Currency ownership moved from
  Settings to Exchange Rates, the legacy-data dialog moved to owner-scope
  presentation, `PaymentMethod` moved to Payment Methods, Insights/AI ownership
  was inverted through the consumer port, and Goals/Accounts adaptation moved
  upward to `lib/app/di`. Settings, Data Deletion, Payment Methods and Goals
  consequently left the cyclic component without replacement cycle edges;
  Insights remains in the component through its other product dependencies,
  but its AI/Dashboard edges were removed. The remaining exact debt is one
  9-feature SCC with 31 edges. This debt is distinct from the zero private/layer
  violations and may only decrease.
- `TransactionsRepositoryImpl` delegates transfer creation/replay and transfer-
  pair lifecycle/status handling to cohesive workflows. It fell 1,190→656→354
  lines while its public API, ordinary transaction ledger responsibility,
  Drift transaction boundaries and Finance Engine behavior stayed unchanged.
- `AppDatabase` remains the public Drift library and schema/migration owner, but
  six private compile-time `part` extensions own owner deletion, transfer-pair
  capability, balance projection, account lifecycle guards, transfer guard DDL,
  and owner-scope guard DDL. The main file fell 2,504→764 lines; schema 17,
  public methods, SQL/DDL text and order remain exact, and generated schema code
  was not regenerated.
- Receipt review persistence/validation/financial confirmation now belongs to
  `ReceiptReviewWorkflow`; its screen fell 833→774 lines. A separate
  `ReceiptCaptureOperationLease` owns cancellation, byte zeroing, image cleanup
  and writer-lease release; the provider owner fell 742→649 lines. UI trees,
  provider identities, owner fences and idempotent confirmation are unchanged.
- `AiAgentOrchestratorImpl` now composes a local plan executor, provider-session
  loop, response deadline and conversation/response coordinator; it fell
  1,478→513 lines. The legacy AI provider facade fell 1,191→309 lines while the
  single controller provider identity stayed intact and a 615-line injected
  controller capability owns its state machine. The assistant screen fell
  3,119→1,645 nonblank lines after financial-understanding, send-lifecycle, durable-draft
  and conversation-workflow extraction; it is now the rendering/effect host.
- Gateway `index.ts` is production composition, `app.ts` is the HTTP factory,
  and ports are framework-free. AI request lifecycle, route validation/SSE/
  abort handling, account-deletion policy, Groq transport/reader/SSE/contracts,
  response grounding and capability contracts are separate modules. The Groq
  client facade fell 857→268 lines.
- One Firebase Admin app is composed and injected into all Gateway adapters.
  Zod validation and provider JSON Schema for all 26 tools derive from one typed
  metadata catalog while the complete provider schema digest remains exact.
- Gateway/tool architecture debt moved from 20 exact entries to zero. Four
  executable `run_*` files are 14/8/8/14-line wrappers. Neutral owners now hold
  XML/safe output, ADB, network/process, Firebase fixtures, Settings, Auth,
  AI-question and device-lifecycle capabilities; the shared composition owner
  is 577 lines. Live scenario bodies are outside deterministic unit gates.
- `cupertino_icons` was conclusively unused and removed in a separate dependency
  batch. Express 4 runtime/`@types/express` 5 alignment and global Firebase CLI
  tooling remain deferred dependency work.
- Final deterministic closure passed Flutter 1,623/1,623 (including architecture
  20/20), Gateway 133/133 plus lint/typecheck/build, tools 154/154, Firestore
  rules 42/42 and emulator deletion 2/2. Analyzer, Android debug APK and Web
  build passed. No Android target was available for live acceptance; the two
  pre-existing secret-scan findings remain explicitly deferred.

The current rules and how-to guidance are under `docs/architecture/`; the
inventory and Arabic per-batch log are the authoritative status sources.
