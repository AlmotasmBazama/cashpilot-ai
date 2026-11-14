# CashPilot AI Project Audit

Date: 2026-08-18. Repository: `<REPOSITORY_ROOT>`. Branch created for
this transformation: `codex/production-transformation`.

## Repository validation

Identity is confirmed by `pubspec.yaml` (`name: cashpilot_ai`), README product
scope, localized CashPilot screens, finance schema, Firebase project config,
and the protected gateway README. The starting worktree already contained a
large uncommitted hardening effort: 514 changed/untracked status entries and a
tracked diff of roughly 41,347 insertions/8,051 deletions. This audit preserves
that work and treats it as current product state.

## System inventory

| Area | Evidence and current implementation |
|---|---|
| Client | Flutter 3.41.9 / Dart 3.11.5; Android, iOS, Web, Windows, macOS, Linux targets; `lib/app` bootstrap/router and `lib/features` feature modules. |
| State/navigation | Riverpod 3; go_router 17; one auth stream plus owner-scoped providers. |
| Persistence | Drift/SQLite schema v17 in `lib/core/database/app_database.dart`; Hive/settings and secure storage; decimal text columns rather than binary floating point. |
| Cloud/auth | Firebase Auth, Firestore opt-in owner backup, App Check; fail-closed Firestore rules under `/users/{uid}` and protected account-deletion locks. |
| AI | Deterministic local parser; Firebase AI and Groq gateway adapters behind interfaces; strict structured output, bounded context, provider egress guard, allowlisted tools, durable commands/confirmation/idempotency/audit tables. |
| Gateway | TypeScript/Express/Zod/Firebase Admin/Groq under `services/cashpilot_ai_gateway`; authenticated and App Check-protected routes; no arbitrary provider proxy or SQL route. |
| Styling/localization | Material 3 CashPilot design system; English/Arabic ARB; RTL, compact, large-text, skeleton/error/empty widgets. |
| Logging/monitoring | Redacting `AppLogger`, navigation/auth safe diagnostics, gateway safe correlation logs. No production crash reporter or product analytics SDK is configured. |
| CI/deployment | Local deterministic gates and extensive QA evidence exist; no repository CI workflow was found. Firebase config and Cloud Run gateway deployment docs exist. Production signing/package/App Check gates remain external. |

## Product inventory

Public routes are defined in `lib/app/router/app_route_paths.dart`:

- Entry/auth: splash, onboarding, welcome, login, register, reset password,
  email verification, guest information, profile completion.
- Primary authenticated destinations: Home, Transactions, AI Assistant,
  Settings.
- Preserved secondary routes: Accounts/details, Categories, Reports, Budgets,
  Goals, Payees/details, Transfer, receipt capture/review, Profile, Privacy,
  Terms, and transaction details.
- Settings now contains a Financial tools section for secondary features.

Financial entities include owner-scoped accounts, categories, payees,
transactions, atomic transfer pairs, budgets, goals/contributions, exchange
rates, receipts/splits, sync queue, AI conversations/drafts/commands,
confirmation proofs, idempotency records, and audit events.

Primary journeys have explicit loading/error/empty states and tests. Manual
expense/income uses `TransactionFormSheet`; transfers use a dedicated screen;
receipt capture requires review; AI read tools use deterministic local data.

## Evidence-based findings

### UX and information architecture

- `AppShellPage._destinations` exposed 6 compact tabs and 10 desktop/rail
  destinations. This made secondary planning/configuration features peers of
  daily entry. It is now four top-level destinations; routes remain intact.
- `DashboardScreen` eagerly watched dashboard, budget, goal, and insight
  providers and rendered planning cards plus a second analytics tier. Home now
  watches the dashboard snapshot only and prioritizes balance/month position,
  immediate entry, recent transactions, and accounts.
- Home's expense/income actions previously navigated to the transaction list;
  they now open the compact form directly.

### Authentication and startup

- Email sign-in/sign-up waited for `_prepareUserDocument` (Firestore get+set)
  and then `_dtoForUser` performed a second sequential Firestore get before the
  operation returned. The prepared profile now feeds the DTO directly, reducing
  that return-path sequence from three Firestore operations to two.
- `AuthPerformanceTrace` now emits correlation/operation/stage/elapsed time
  without UID, email, token, credential, or profile content.
- Session restoration already separates native identity from profile hydration,
  uses epoch guards, deduplicates auth mutations, bounds profile reads at five
  seconds, and fails closed on owner changes.
- Prior release evidence records Android debug cold startup at 8.1–14.1s; no
  physical/profile release measurement is available, so production startup is
  not claimed.

### AI

- Strong boundaries exist in `CanonicalAppToolCatalog`,
  `GovernedAiToolRegistry`, provider egress guards, Zod/gateway contracts,
  durable command stores, confirmation proofs, and owner-scoped idempotency.
- Read/query/calculation and create-draft flows are real and deterministic.
  Aggregate calculations are local; the model does not sum raw history.
- Gap: canonical update/delete transaction tools are intentionally absent.
  Structured intent safety rejects destructive/bulk attempts, but natural-
  language edit/delete is not end-to-end complete.
- Gap: effective app-control policy is fail-closed and confirmation-based;
  immediate low-risk creation plus undo is not currently enabled by default.

### Data integrity and performance

- Money is `Decimal`/text and transfer legs are atomic with connection-level
  guards. Owner-scope references, transfer fingerprints, idempotency, and
  deletion quarantine have dedicated tests.
- Dashboard, history, and budget reads are bounded. Existing fixtures record
  10k-row improvements of 221.71x (dashboard), about 120x (history), and about
  163x (budget read model).
- Schema v17 migration tests cover v13-v16 and ownerless legacy snapshots.
  No schema change was required in this phase.

### Security/privacy

- Firestore rules scope every user tree read/write to authenticated owner and
  reject tenant principals; permanent deletion locks are Admin-only.
- AI provider keys stay server-side; App Check/Auth are verified at the gateway;
  result sizes and provider bodies are bounded; logs redact sensitive values.
- No arbitrary SQL/model-supplied user ownership path was found.
- Remaining release risks are external configuration, signing, Play Integrity,
  physical-device acceptance, and live production telemetry—not authorization
  bypasses.

### Libya localization

- Existing LYD fixed precision and Arabic digit support were extended for up to
  three decimals, half/quarter phrases, yesterday, Libyan income vocabulary,
  bank abbreviations, and transfer/withdrawal safety.
- The bank seed now matches all 26 names in the Central Bank of Libya commercial
  bank directory checked 2026-08-18. Payment names are recognition-only.
- Gap: catalog overrides are still bundled seed code; a signed remote/local
  update channel for alias-only corrections is not implemented.

## Baseline quality record

| Command | Result before this phase |
|---|---|
| `flutter pub get` | PASS, 21.3s; 69 constrained packages have newer incompatible versions. |
| `flutter analyze --no-pub` | PASS, 0 issues, 345.3s. |
| `flutter test --no-pub -r compact` | PASS, 1,623/1,623, 1m52s. |
| Integration/E2E | Present, but not executed in baseline: requires authorized device/Firebase/App Check/Groq configuration. |
| Android/Web build | Existing QA evidence passes debug APK/Web; fresh final results are recorded in `PERFORMANCE_REPORT.md`. |
| Network/auth timing | No safe live credentials/device supplied. Source-level request sequencing and redacted trace instrumentation are reported; no fabricated latency. |

Expected test logs include redacted failures for negative-path assertions and
Drift warnings from tests that deliberately open multiple database instances on
one executor; the suite still passed.

## Final verification record

| Command | Final result |
|---|---|
| `flutter analyze --no-pub` | PASS, zero issues. |
| `flutter test --no-pub -r compact` | PASS, 1,635/1,635. |
| `npm test` in `services/cashpilot_ai_gateway` | PASS, 133/133. |
| Gateway `lint`, `typecheck`, `build`, `secret-scan` | PASS. |
| Root `npm run test:tools` | PASS, 160/160. |
| Root `npm run test:firestore-rules:emulator` | PASS, 42 rules tests and 2 Admin/Auth deletion tests. |
| `flutter build apk --debug --no-pub` | PASS. |
| `flutter build web --no-pub` | PASS, with a non-fatal unused Cupertino icon font warning. |
| `flutter build windows --debug --no-pub` | BLOCKED because the host has no suitable Visual Studio toolchain. |

No Android device was connected (`flutter devices` exposed Windows, Chrome,
and Edge only), so live registration/login, App Check, provider, physical RTL,
and startup/frame acceptance remain manual release gates. iOS, macOS, and Linux
builds are not available from this Windows host. See `PERFORMANCE_REPORT.md` for
artifact sizes and timing scope.
