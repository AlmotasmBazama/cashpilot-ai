# CashPilot AI app capability inventory

This inventory is the Phase 0 authority for the governed app agent. It records
what CashPilot can do through its current application and domain layers, not
what a model could theoretically request.

"Safe for AI exposure" means that a model may select a bounded declaration or
prepare a draft. It never means the model may execute a mutation. CashPilot's
local permission policy, confirmation controller, validator, use case, and
verified-result path remain authoritative.

## Release-blocking boundaries

1. **Local financial rows are not owner-scoped.** The accounts, transactions,
   categories, payees, budgets, goals, exchange-rate, receipt, and split tables
   do not contain an owner or user-scope column. Only the sync queue has
   `ownerUserId`. A command can carry an account scope, but the current local
   repositories cannot independently prove that a resolved financial row
   belongs to that scope. Cross-account isolation on a shared device is
   therefore not established. Account-specific detail and mutation tools must
   remain deferred until local workspace ownership/isolation is implemented
   and tested.
2. **Reference integrity is application-managed.** Financial tables store IDs
   as text without foreign-key constraints. Existing hard deletes can orphan
   transactions, budgets, payee defaults, receipts, or splits.
3. **Generic updates are not stale-safe.** Most update use cases accept a full
   entity and do not accept an expected revision, last-seen timestamp, or
   preview fingerprint. A future command executor must resolve the entity
   again and reject stale previews.
4. **General command idempotency is not durable.** Entity creates use UUIDs,
   but repeating a create with the same ID normally fails rather than returning
   a verified prior result. `AiActionExecutor` has only an in-memory executed
   map. Receipt confirmation has the strongest existing durable behavior
   because it reserves a transaction ID and checks for an existing transaction.
5. **Several read use cases are not storage-bounded.** The current AI adapter
   minimizes and caps results after local loading, but transaction, account,
   category, payee, budget, goal, and rate repositories can first load the
   complete local collection. New detail/search tools need limits at the use
   case/data-source boundary.

Until these boundaries are addressed, rollout is limited to already-minimized
reads, pure calculations, review-only drafts supported by existing typed
flows, and fixed top-level navigation.

## Confirmation levels

| Level | Meaning |
| --- | --- |
| None | Bounded read, pure calculation, or explicit fixed navigation. |
| Normal | One explicit confirmation after a complete preview. |
| Detailed | One explicit confirmation showing current and proposed values, affected entities, and financial effect. |
| Elevated | Detailed preview plus a second acknowledgement or protected native workflow. |
| Prohibited | The model cannot request or draft the operation. |

## Capability matrix

| Entity / capability | Existing read use cases | Existing create use cases | Existing update use cases | Existing archive / cancel use cases | Existing delete behavior | Required validation | Confirmation | Reversibility | Idempotency support | Privacy classification | Safe AI exposure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Accounts** | `GetAccounts`, `GetAccountById` | `CreateAccount` | `UpdateAccount` | None; `isArchived` exists only as a field | `DeleteAccount` physically deletes one row; no dependency check | Current domain use case is pass-through. UI checks non-empty name, a three-character currency, and Decimal balance. A repository caller can still change balance, currency, archive state, IDs, and timestamps. Account references and incompatible activity are not checked. | Read: none. Create or metadata update: detailed. Hard delete: prohibited. | No current governed undo. Hard delete is irreversible. No archive/restore use case exists. | UUID primary key only; duplicate create fails. Update is last-write-wins. | Sensitive personal financial data; names, balances, currencies, and payment-method configuration. | **Safe now:** bounded minimized account summary. **Deferred:** `getAccountDetails`, create/update/archive tools. Add validated create, metadata-only update that preserves balance/currency, dependency-aware archive/restore, and owner-scope enforcement first. |
| **Transactions** | `GetTransactions`, `GetTransaction`, `SearchTransactions`; current repository reads/search are unbounded | `CreateTransaction`; `CreateTransactionWithPayeeUsage` updates payee usage after success | `UpdateTransaction`, `UpdateTransactionStatus` | Status transitions allow pending to posted/cancelled and posted to cancelled | Non-transfer deletion reverses a posted balance then hard-deletes. Pending transfer deletion hard-deletes both records. Posted transfer hard-delete is blocked. Receipt linkage is not checked. | Finance Engine enforces positive amount, account existence, matching currency, and sufficient debit balance. Repository blocks a transfer-shaped record created singly and direct transfer editing. Category/payee existence and activity, archived-account state at execution, receipt linkage, stale preview, and note bounds need revalidation. | Read: none. Create expense/income: normal. Update or cancel: detailed. Generic delete: prohibited. | Balance effects can be reversed internally, but there is no receipt-aware governed undo. Hard-deleted rows are not restored. | Create is not idempotent. Same-status update returns the existing record(s). Repository balance and row writes are transactional. Current AI duplicate guard is in memory only. | Highly sensitive financial history. Notes, locations, attachments, internal IDs, and raw payee IDs are restricted. | **Safe now:** bounded minimized summaries/search and review-only expense/income drafts. **Deferred:** transaction detail, update, cancel, delete, and undo tools until storage-bounded reads, receipt consistency, stale checks, and durable command idempotency exist. |
| **Transfers** | Transfer pair can be read via `GetTransactions(transferGroupId:)`; no dedicated bounded transfer-details use case | `CreateTransfer` | No pair-field update; `UpdateTransactionStatus` changes lifecycle | Pending can be cancelled; posted can be cancelled through an atomic balance reversal | Only a pending pair can be hard-deleted; posted pair deletion is blocked | Source and destination must differ. Source amount and rate must be positive. Account currencies, target amount/rate metadata, balances, pair cardinality, pair statuses, and pair exchange rates are validated. A posted reversal can fail if the destination no longer has sufficient funds. | Create: detailed. Cancel pending: detailed. Cancel posted/reverse: elevated. Delete: prohibited to model. | Cancellation preserves pair history; posted cancellation reverses balances. Naive delete/undo is unsafe. | Pair creation is atomic but not idempotent. Same status is idempotent. Pair status and both balances update transactionally. | Highly sensitive movement between personal accounts. | **Safe now:** review-only transfer draft. **Conditional:** dedicated cancel-pending-transfer draft after current-pair re-resolution. **Deferred:** posted cancellation, editing, deletion, or arbitrary transfer IDs. |
| **Categories** | `GetCategories`, `GetCategoryById`, `GetDefaultCategories` | `CreateCategory` | `UpdateCategory`; `ResetDefaultCategories` is a reset/upsert operation | None; `isArchived` exists but has no use case | Custom category is physically deleted. Default-category deletion is blocked. References are not checked. | Repository forces new categories to non-default and preserves default flag on update. Missing: non-empty/length/duplicate-name validation, parent existence/cycle checks, type-change safety, and transaction/budget/payee/split references. | Read: none. Create/update/archive: normal or detailed when references are affected. Delete/reset: prohibited. | Hard delete is irreversible. No archive/restore inverse exists. Default reset is not an undo mechanism. | Create/update are last-write-wins. Default reset uses conflict update but is not model-safe. | Sensitive financial classification/configuration; names may reveal personal spending categories. | **Safe now:** bounded name/type/category-spending reads. **Deferred:** create, update, archive, reset, delete. Add validated, reference-aware create/update and archive/restore use cases first. |
| **Payees** | `WatchPayees`, `GetPayeeById`, `SearchPayees`, `ResolvePayee` | `CreatePayee` | `UpdatePayee`, `TouchPayeeLastUsed` | `ArchivePayee`, `RestorePayee` | No delete use case | Entity trims and normalizes Arabic/English names, rejects blank name and duplicate aliases. Repository rejects duplicate names/aliases and verifies default account/category existence. AI output must omit notes, IDs, and unrestricted aliases. | Read: none. Create/update/archive: normal; detailed if defaults change. | Archive/restore is reversible. Repeating archive changes timestamps but not the effective state. | Create is UUID/primary-key protected, not idempotent-success. `TouchPayeeLastUsed` is monotonic and safely ignores older timestamps. | Sensitive merchant/payee relationship data; notes are private. | **Safe after bounded adapter:** minimized summaries and local candidate resolution. **Deferred writes:** create/update/archive drafts until opaque references, stale checks, owner scope, and a confirmed executor exist. Never expose notes. |
| **Budgets** | `WatchBudgets`, `GetBudgetById`, `GetActiveBudgets`, `CalculateBudgetProgress`, `WatchBudgetProgress` | `CreateBudget` | `UpdateBudget` accepts the complete budget | `ArchiveBudget`, `RestoreBudget`; no explicit pause/resume/cancel transition | No delete use case | `Budget.create` validates name, category ID presence, positive Decimal amount, supported currency, 0–100 threshold, and start before end. Repository does not verify category existence/activity/type, duplicate/overlapping budgets, or expected revision. Create does not reconstruct through the validating factory. | Read: none. Create: normal. Limit/period update: detailed. Pause/archive/cancel: detailed. | Archive preserves history, but restore always makes the budget active and therefore does not restore a previously inactive state exactly. | Create is not idempotent. Archive/restore has an idempotent effective state but changes timestamps. No stale-write protection. | Sensitive financial plans and limits; user-defined names can be revealing. | **Safe now:** bounded summary/progress and review-only create draft. **Deferred:** details, update, pause/resume/cancel/archive tools until category validation, expected-version checks, and exact status semantics exist. |
| **Goals** | `WatchGoals`, `GetGoalById`, `CalculateGoalProgress` | `CreateGoalUseCase` | `UpdateGoalUseCase` accepts the complete goal, including `currentAmount` | `ArchiveGoalUseCase`, `RestoreGoalUseCase`; no dedicated pause/resume command | No delete use case | `Goal.create` validates title, positive target, non-negative current amount no greater than target, supported currency, and completion state. Linked account existence is not checked. Generic update can rewrite `currentAmount`, violating contribution-history authority. | Read: none. Create: normal. Metadata/target/deadline update: detailed. Archive: detailed. | Archive/restore preserves the row but loses an earlier paused state. Direct current-amount edits have no safe inverse. | UUID create is not idempotent. Archive/restore effective state is repeatable but timestamped. No expected-version protection. | Highly sensitive savings objectives, descriptions, balances, and deadlines. | **Safe now:** bounded summary/progress and review-only goal create draft. **Deferred:** detail/update/archive tools. Add metadata-only update that cannot change `currentAmount`, linked-account validation, stale checks, and prior-status-preserving archive. |
| **Goal contributions** | `WatchGoalContributions`; goal progress reflects credited, non-reversed totals | `AddGoalContributionUseCase` | Historical contribution rows are not silently edited | `ReverseGoalContributionUseCase` is the explicit inverse | No hard delete use case | Positive amount and supported currency; goal must exist and be active; conversion must be available; credited amount cannot overfund. Data source repeats the archive/overfunding checks and updates goal plus contribution atomically. Linked transaction consistency is not managed. | Read: none. Add: normal/detailed with resulting goal progress. Reverse: detailed. | A contribution can be reversed once. Reversal is not the inverse of a separately linked financial transaction. | Contribution ID prevents duplicate insert but repeat fails rather than returns prior success. Reversal rejects an already-reversed contribution. Both operations are transactional. | Highly sensitive savings history; contribution notes and linked transaction IDs are restricted. | **Safe now:** review-only contribution draft through the typed flow. **Conditional:** bounded progress/details and explicit reversal only after opaque references, durable command idempotency, and linked-transaction policy. |
| **Recurring transactions** | `DetectRecurringTransactionsUseCase` derives only a count from posted expenses in a bounded 180-day window; current AI `get_recurring_transactions` returns count and period | None | None | None | None | Detector requires at least three occurrences and 20–40 day intervals, grouped by payee or category/currency/amount. It does not create a recurring contract and cannot identify an authoritative future schedule. | Count read: none. Any future create/update/pause/resume/cancel: detailed. Bulk stop: elevated. | Not applicable; no lifecycle entity exists. Historical transactions must never be rewritten by a future recurring edit. | Pure detection is deterministic for the same dataset and `now`. No mutation idempotency exists. | Sensitive behavioral pattern data. Individual merchant schedules are more sensitive than the count. | **Safe now:** count-only recurring summary. **Deferred:** `getRecurringDetails`, create/update/pause/resume/cancel, and bulk stop. A real recurring entity, bounded item references, future-only semantics, and partial-failure policy are required. |
| **Exchange rates** | `WatchExchangeRates`, `GetExchangeRate`, `GetLatestExchangeRate`, `GetRatesForBaseCurrency`, `ConvertMoney` | `UpsertExchangeRate` creates or updates one pair | `UpsertExchangeRate` | `ArchiveExchangeRate`; no explicit restore | No delete use case | Factory requires two supported, different currencies and a positive Decimal rate. Upsert normalizes and transactionally coalesces an active pair. No provenance trust policy, freshness threshold, expected revision, or explicit restore exists. | Pair read/calculation: none. Manual rate create/update/archive: detailed. | Archived data remains, and same-ID upsert can revive it, but there is no explicit validated restore/undo use case. | Pair upsert coalesces active pair and is effectively idempotent for identical input; timestamps change. | Financial configuration. Manual rates affect every converted report and projection. | **Safe now:** one stored pair read and Decimal conversion only when the rate is resolved locally. **Deferred:** bounded stored-rate list and all rate mutations. Current `convert_currency_amount` accepts a caller-supplied rate and must not be described as “using stored rate.” |
| **Reports** | No report-domain use cases. `ReportsScreen` consumes `DashboardSnapshot`, which derives month/year totals, net worth, top categories, and a six-month trend | None | None | None | None | Posted transactions only; normal-income policy excludes transfers and loan proceeds; conversion uses stored/historical rates and marks missing-rate results partial. Snapshot currently loads complete local collections before aggregation. | None | Read-only | Deterministic for the same snapshot, rates, locale time, and `now`. | Derived sensitive financial data. Aggregates are safer than raw records but remain personal. | **Safe now:** existing bounded dashboard, month/year, category, cash-flow, and net-worth aggregates. **Deferred:** richer report/detail tools until a storage-bounded reporting facade exists. |
| **Insights** | Deterministic monthly comparison, top category, recurring count, cash-flow trend, missing-rate detection, and `GenerateFinancialInsightsUseCase`; `BuildAiInsightSummaryUseCase` produces minimized metrics | None | `ExplainFinancialInsightUseCase` may replace one display sentence but not underlying evidence | None | None | Uses posted transactions, Decimal conversion, bounded periods, missing-rate warnings, and maximum ten generated insights. The safe summary removes internal IDs and user-defined metric names. The existing agent adapter emits title/message/metric, which may contain goal or budget names, so it is not registered in the canonical or provider allowlists. | None | Read-only; generated phrasing falls back to deterministic text | Deterministic evidence; presentation IDs/timestamps and optional phrasing are not stable identifiers. | Derived sensitive financial condition and behavior. | **Deferred:** add a dedicated `BuildAiInsightSummaryUseCase` adapter with a bounded count and no internal or user-defined metric names before registering an agent tool. Do not expose raw evidence objects or mutate data. |
| **Receipts** | `GetDraftById`/`WatchDraft` exist only at repository level; domain use cases cover validation, duplicate detection, category resolution, and reviewed transaction construction. No bounded history/list use case exists. | `CaptureReceiptImageUseCase`, `ImportReceiptImageUseCase`, repository draft create, `AnalyzeReceiptImageUseCase`, and `ConfirmReceiptTransactionUseCase` | `UpdateReceiptDraftUseCase`, recalculation, category resolution, retry analysis | Receipt status lifecycle exists; no archive use case | Repository can delete a draft and local image physically | Image type/size/resolution checks, EXIF stripping, arithmetic tolerance, document/payment classification, category validation, warning acknowledgement, duplicate acknowledgement, cross-currency amount/rate, explicit confirmation, and transaction-ID reservation. Image/privacy consent remains user-controlled. | Capture/import/vision: protected user gesture and privacy consent. Confirm transaction: detailed, with extra acknowledgement for warnings/duplicates. Delete image/draft: elevated native action. | Draft/image deletion is irreversible. Confirmed transaction undo is not receipt-aware. Image retention may intentionally delete the local image after extraction. | Analysis duplicate guards are in memory. Confirmation persists a reserved transaction ID and reuses an existing transaction, providing the strongest restart-safe flow. | **Restricted document data:** images, address, tax ID, receipt/invoice numbers, hashes, local paths, items, and payment hints. | **Safe now:** fixed navigation to receipt scanner; keep image analysis on Firebase Gemini. **Deferred:** receipt transaction summary until a dedicated bounded adapter excludes document identifiers, images, hashes, local references, and raw item descriptions. Never send receipt images to Groq. |
| **Transaction splits** | Hydrated only through a receipt draft; no standalone bounded read use case | `ReceiptSplitAllocator` creates deterministic in-memory splits; repository saves/replaces them as part of receipt flow | Repository `saveSplits` replaces the complete set | None | Deleted with receipt draft; replacement first deletes prior rows | Every item needs category and amount; negative values require refund document; Decimal proportional allocation and final remainder must exactly equal reviewed receipt total. Persisted category activity/reference integrity needs revalidation. | Pure simulation: none. Persisted change: detailed receipt confirmation. | Replacement destroys the previous split set. No standalone undo/version history. | Allocation is deterministic. Save is replace-all, not expected-version safe. Receipt finalization is transactional for receipt status plus splits. | Highly sensitive itemized purchase classification. | **Conditional:** pure split simulation using reviewed/synthetic values. **Deferred:** persisted split read/write tools until receipt-aware bounded use cases, opaque references, and stale checks exist. |
| **Backup and sync** | `backupEnabledProvider`, `lastBackupAtProvider`, owner-scoped queue stats; no safe domain status facade | Best-effort mutation queue enqueues backup upserts/deletes; Settings can enable backup and run upload | Failed queue items can be retried; latest pending operation compacts per owner/entity | No archive; remote writes use deletion tombstones | No general backup delete. Full cloud deletion is only inside protected data deletion. Restore is unimplemented. | Requires signed-in non-anonymous user; queue filters by owner; Firestore path is under authenticated user; queue compacts one active item per entity. Raw payload, queue ID, and error text are restricted. Receipts/splits are not backed up. | Minimized status read: none. Enable/upload/retry: explicit native privacy workflow. Restore/delete: prohibited. | Upload cannot be simply undone. Tombstones preserve deletion intent. No cloud-to-local restore or conflict resolution exists. | Queue compaction is idempotent by owner/entity. Firestore uses merge writes; attempts and failures are tracked. No schema-version or document idempotency token yet. | Sensitive cloud-storage configuration and synchronization metadata; queue payloads contain full entities. | **Safe after facade:** enabled state, pending/failed counts, last successful backup, and `restoreSupported: false`. Prefer fixed navigation to Settings. Do not expose raw queue data, upload/retry execution, restore, or backup deletion to the model. |
| **Settings / app configuration** | Base currency provider plus locale, theme, backup, receipt privacy, AI-memory, and AI diagnostics controllers | Not entity creation | Controllers can change base currency, locale, theme, backup, and AI preferences | None | AI history can be cleared; preferences are removed by protected data deletion | Locale supports only `en`/`ar`. Currency catalog supports a fixed set, but `normalizeCode` silently falls back to LYD for unsupported input. Security/diagnostics/privacy settings require native control and must not be inferred. | Read safe configuration: none. Normal display preferences: normal. Base currency: detailed because reports change. Privacy/security/history deletion: protected native workflow. | Theme/locale/base currency can be changed again; clearing history is irreversible. Backup/privacy effects are not simple undo operations. | Most settings are overwrite/idempotent. Base currency sync is best effort. | App configuration; privacy and diagnostics settings are security-sensitive. | **Safe now:** read base currency and enabled agent capabilities. **Conditional:** locale/theme read. **Deferred:** all setting mutations until strict validated commands exist. **Prohibited:** security, App Check, auth, token, diagnostics, privacy-consent, or clear-history tools. |
| **Profile and authentication** | `GetCurrentUser`, auth-state listener; profile screen reads display name/email/verification | Sign-up and anonymous/social login exist outside agent scope | `CompleteProfile`, verification, reauthentication, sign-in/out | None | `DeleteAuthAccount` and full deletion are protected native operations | Firebase Auth and Firestore enforce current identity. Profile completion currently accepts complete strings and is not a bounded agent update. Email, UID, credentials, provider tokens, and verification state must not enter model context. | Native authenticated workflow; profile mutation detailed. Sign-out/auth/deletion prohibited to model. | Profile fields may be changed again; auth deletion is irreversible. | Remote operations are provider-controlled; no agent command idempotency contract. | Direct identifiers, credentials, authentication and security state. | **No model data access or mutation.** Fixed top-level Profile/Settings navigation may be safe. Never expose identity fields, credentials, sign-in/out, verification, reauthentication, or account deletion tools. |
| **Data deletion** | No model-safe read; native UI can show the protected flow | None | None | None | `DeleteAllUserData` deletes cloud subcollections, local receipt images and rows, user preferences, then Firebase Auth | Explicit checkbox confirmation plus reauthentication. Operation deliberately stops on cloud failure before local deletion. Later-stage failure reports a safe retry state, but the multi-system process is not atomic. | Elevated protected native workflow with recent credentials; prohibited to model | Irreversible. Partial completion may require retry and can leave cloud removed while local/auth cleanup remains. | Not generally idempotent; staged retry behavior is explicit. A second run may observe already-removed data. | Maximum sensitivity: all financial data, documents, cloud data, preferences, and identity. | **Permanently prohibited:** no `deleteAllUserData`, generic delete, bypass-confirmation, or credential tool. Assistant may only explain and direct the user to the existing protected Settings flow. |
| **Navigation routes** | `AssistantNavigationPolicy` classifies an explicit navigation verb and destination; app router defines fixed paths | Not applicable | Not applicable | Not applicable | Not applicable | Tool name and returned path must both match the compile-time allowlist. Current approved routes: Dashboard, Accounts, Transactions, Reports, Budgets, Goals, Payees, Receipt Scanner. General destination mentions without a navigation verb are rejected. | None after an explicit user navigation request | User can navigate back/elsewhere; no financial state changes | Deterministic local classification and fixed tool-to-path mapping | Top-level route choice is low sensitivity. Dynamic entity IDs and detail routes are sensitive internal references. | **Safe now:** current eight fixed top-level routes. **Conditional:** fixed Categories, Settings, Profile, and Backup/Sync destinations. **Deferred:** account/transaction/budget/goal/receipt detail navigation until a local opaque-reference resolver exists. Never accept arbitrary route strings or model-supplied database IDs. |

## Existing safe governed surface

The current central registry already applies unique tool names, unknown-tool
rejection, strict declared arguments, a result limit of 1–20, a five-second
timeout, and a 16 KiB encoded result limit.

Safe to retain during the first rollout stage:

- Bounded/minimized reads: dashboard summary, monthly comparison, category
  spending, budget summary/progress, goal summary/progress, cash-flow trend,
  recurring count, income/expense breakdown, net worth, account summaries,
  one stored exchange-rate pair, minimized transaction search, base currency,
  and agent capabilities.
- Pure Decimal calculations whose inputs are explicit and bounded. Stored-rate
  conversion must resolve the rate locally instead of trusting a model-supplied
  rate.
- Review-only drafts currently supported by typed application flows: expense,
  income, transfer, budget, goal, and goal contribution.
- The current fixed, explicit navigation allowlist.

All read output remains personal financial data and should require the user's
enabled read permission. It must omit UID, email, notes, locations, attachment
data, database IDs, sync metadata, receipt document fields, raw model context,
and unrelated records.

## Explicitly deferred tool declarations

Do not register these merely because a repository method exists:

- Account details, account create/update/archive/delete.
- Unbounded transaction summary/details, transaction update/delete/undo, and
  posted-transfer reversal.
- Category create/update/archive/delete/reset.
- Payee details containing notes or IDs; payee mutations until the command
  executor is account-scoped and stale-safe.
- Budget details/update/pause/resume/cancel/archive.
- Goal details/update/archive and contribution reversal.
- Recurring details/create/update/pause/resume/cancel/bulk stop.
- Stored-rate listing and exchange-rate mutations.
- Receipt history/details, receipt/split mutation, or any Groq receipt-image
  access.
- Backup execution, retry, restore, export, or raw queue inspection.
- Settings/profile/auth/security/privacy mutation.
- Data deletion, unrestricted delete, direct balance changes, raw database,
  repository, Drift, Firestore, secret/token, arbitrary HTTP/file, arbitrary
  route, and cross-user tools.

## Safe bounded use cases required before later rollout stages

1. Owner-scoped local financial workspace or equivalent repository-enforced
   isolation, including account-switch tests.
2. Durable account-scoped command records with expiry, confirmation evidence,
   expected revision, duplicate execution protection, and a safe audit result.
3. Account metadata update that cannot change balance/currency, plus
   dependency-aware archive/restore.
4. Storage-bounded transaction search/details and receipt-aware
   update/cancel/undo.
5. Validated, reference-aware category create/update/archive/restore.
6. Budget limit update and explicit pause/resume/cancel transitions that
   preserve prior state and reporting history.
7. Goal metadata update that cannot change contribution-derived current
   amount, plus bounded contribution details.
8. A real recurring-definition domain with bounded details and future-only
   create/update/pause/resume/cancel semantics.
9. Bounded payee/rate/report/receipt-summary adapters using local opaque
   references instead of database IDs.
10. A minimized backup-status facade. Restore remains unavailable until
    ownership, schema compatibility, conflict resolution, rollback, and
    non-destructive preview are implemented.

## Key implementation references

- Accounts: `lib/features/accounts/domain/usecases/`,
  `lib/features/accounts/data/repositories/accounts_repository_impl.dart`
- Transactions/transfers: `lib/features/transactions/domain/usecases/`,
  `lib/features/transactions/data/repositories/transactions_repository_impl.dart`
- Finance validation: `lib/features/finance_engine/domain/services/`
- Categories: `lib/features/categories/domain/usecases/`,
  `lib/features/categories/data/datasources/local/categories_local_data_source.dart`
- Payees: `lib/features/payees/domain/usecases/`,
  `lib/features/payees/data/repositories/payees_repository_impl.dart`
- Budgets: `lib/features/budgets/domain/`,
  `lib/features/budgets/data/repositories/budget_repository_impl.dart`
- Goals/contributions: `lib/features/goals/domain/`,
  `lib/features/goals/data/datasources/local/goals_local_data_source.dart`
- Recurring/insights: `lib/features/insights/domain/usecases/`
- Exchange rates: `lib/features/exchange_rates/domain/`,
  `lib/features/exchange_rates/data/repositories/exchange_rate_repository_impl.dart`
- Receipts/splits: `lib/features/receipts/domain/`,
  `lib/features/receipts/data/repositories/receipt_repository_impl.dart`
- Backup/sync: `lib/core/sync/`
- Settings/profile/deletion: `lib/features/settings/`,
  `lib/features/profile/`, `lib/features/data_deletion/`
- Navigation and current tool policy:
  `lib/features/ai_assistant/domain/agent/assistant_navigation_policy.dart`,
  `lib/features/ai_assistant/application/agent/governed_ai_tool_registry.dart`,
  `lib/features/ai_assistant/application/agent/riverpod_financial_agent_data_gateway.dart`
