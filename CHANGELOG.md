# Changelog

## Unreleased

### Added
- Governed app-control policy foundation with account-scoped consent,
  conservative rollout gates, a canonical provider-independent capability
  catalog, typed previews/confirmations, bounded plans, scoped audit contracts,
  and fail-closed provider composition. Financial rollout remains blocked
  until local owner isolation and a durable command ledger exist.
- Governed Firebase financial agent with an SDK-independent orchestrator,
  centralized allowlisted tool registry, strict permissions/schemas, bounded
  function-calling loop, safe local fallback, and evidence-aware responses.
- Read-only dashboard, comparison, category, budget, goal, cash-flow,
  recurring, account, transaction-search, exchange-rate, and insight tools;
  pure Decimal scenario tools; review-only draft tools; and allowlisted
  navigation tools.
- Privacy-conscious local multi-turn memory with bounded compaction, session
  expiry, clear/new conversation controls, optional local persistence, and
  account-deletion cleanup.
- Conservative agent feature flags, financial-guidance/sensitive-request
  policies, agent UI progress/evidence/follow-ups, focused governance tests,
  safe Firebase agent smoke test, and agent operations documentation.
- Receipt and invoice capture from camera or user-selected images with explicit
  privacy consent, local metadata-stripping image preparation, and app-private
  retention controls.
- Firebase AI Logic multimodal receipt extraction with a strict JSON schema,
  Decimal-only money parsing, bounded retries/timeouts, App Check failure
  mapping, sanitized allowlisted context, and no AI-side database mutation.
- Editable receipt review, line-item category resolution, exact category
  splits, invoice/refund/payment-confirmation semantics, cross-currency
  requirements, duplicate detection, and idempotent explicit confirmation.
- Drift schema v14 receipt, line-item, and transaction-split persistence,
  complete local deletion, English/Arabic UI copy, feature flagging, entry
  points from Transactions and AI Assistant, and focused receipt tests/docs.
- Income-source intelligence for AI-created income drafts, including typed
  source metadata, loan-proceeds reporting rules, expanded income categories,
  schema v13 migration, review UI, and domain/provider coverage.
- Selectable AI runtime modes (`mock`, `localParserOnly`, and
  `firebaseGemini`) with centralized economical model configuration.
- Firebase AI Logic JSON-schema output, typed provider failures, App Check
  readiness diagnostics, localized AI errors, and safe connection testing.
- AI send debounce/in-flight/duplicate-prompt cost guardrails and expanded
  provider, privacy, fallback, configuration, and diagnostic tests.
- Firebase AI Logic activation, App Check, quota, model, and production
  runbook in `docs/ai_activation.md`.
- Complete Firebase Authentication module with email/password, Google Sign-In, Apple Sign-In-ready nonce flow, anonymous guest mode, forgot password, email verification, remember me, auto-login auth state listening, logout, delete account, and password reauthentication support.
- Auth Clean Architecture feature with domain user entity, auth repository contract, auth failure model, use cases, Firebase datasource, DTO/mapper, repository implementation, and Riverpod providers/controller.
- Secure auth routing with splash, onboarding, welcome, login, register, forgot password, email verification, profile completion, and guest mode information screens before the app shell.
- Firestore `users/{uid}` document preparation with uid, name, email, photoURL, currency, language, country, timezone, createdAt, updatedAt, and lastLogin fields.
- Account management surfaces in Settings and Profile for current session status, guest visibility, logout, profile completion, and delete account.
- Firebase setup instructions in `docs/firebase_setup.md` and future cloud synchronization TODOs in `docs/cloud_sync_todo.md`.
- Production UI navigation shell with adaptive bottom navigation, navigation rail, and desktop sidebar.
- Full route tree for Dashboard, Accounts, Account Details, Transactions, Transaction Details, Categories, Payees, Payee Details, Reports, Budgets, Goals, AI Assistant, Transfer, Settings, and Profile.
- Dashboard UI with greeting, current date, net worth by currency, monthly income, monthly expenses, monthly savings, cash-flow chart, accounts preview, recent transactions, spending summary, planning cards, quick actions, and floating AI assistant action.
- Improved Accounts UI integration with animated balances and a full Account Details screen showing balance, currency, transaction history, income, expense, transfer totals, statistics, edit action, and archive action.
- Transactions UI with search, filters, sorting, date groups, modern transaction cards, transaction details, delete dialog, and add expense/income bottom sheets wired to the existing use cases and Finance Engine path.
- Transfer UI surface prepared for a future atomic transfer use case without performing unsafe paired writes.
- Categories UI with list filters, nested category display, create/edit bottom sheets, and archive action using existing category use cases.
- Payees UI derived from real transaction payee references, including search and payee details.
- Reports UI with monthly, yearly, category, and cash-flow report tabs using local account and transaction data.
- Budgets and Goals UI shells with premium empty states and metric surfaces prepared for backend integration.
- AI Assistant UI with suggested prompts, insight cards, voice input affordance, composer, and integration-ready empty conversation state.
- Settings UI wired to existing persisted theme and language controllers, plus integration-ready currency, backup, security, and biometric sections.
- Profile UI connected to the authentication/profile backend surface.
- Expanded English and Arabic localization for the full production UI and authentication layers.

### Changed
- Redesigned the Dashboard into a premium financial cockpit with greeting/date/profile avatar, AI insight hero, net worth, monthly summary, quick actions, account preview, recent transactions, budget/goal progress, compact spending chart, and animated AI floating action.
- Upgraded shared card surfaces with richer hierarchy, subtle elevation, semantic accent borders, safer scaling for long financial values, and improved card rhythm across feature screens.
- Replaced stock bottom navigation with a custom premium navigation bar, animated active state, stable labels, and constrained mobile layout.
- Reworked empty states with composed illustrations, friendlier hierarchy, better action spacing, and responsive max widths.
- Replaced plain loading with an AI-styled pulse and skeleton-line loading treatment.
- Improved finance metric cards, info cards, mini charts, section headers, account balance trailing text, and report money formatting to reduce overflow risk and improve visual rhythm.
- Refined product copy across AI, budgets, goals, transfer, settings, and profile surfaces to remove internal implementation language.

### TODO: Backend Integration
- Add atomic transfer use case/repository API so the Transfer screen can create paired transfer transactions transactionally.
- Add budgets domain/data/application layers for budget creation, limits, rollover, progress, and alerts.
- Add goals domain/data/application layers for savings targets, funding sources, and milestones.
- Expose Payees repository/providers for real payee names, metadata, and management.
- Add AI chat, voice, and insight APIs; connect the AI Assistant conversation UI to real streaming responses.
- Add cloud sync and backup infrastructure for the Settings backup section.
- Add base-currency and exchange-rate settings for accurate multi-currency consolidated reports.
- Add biometric platform integration for Android, iOS, and desktop where supported.
