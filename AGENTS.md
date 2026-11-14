# CashPilot AI Engineering Guide

## Purpose and platforms

CashPilot AI is an Arabic-first, local-first personal-finance application for
ordinary Libyan users. Flutter targets Android, iOS, Web, Windows, macOS, and
Linux; Android is the currently exercised primary client. The protected AI
gateway is a Node.js/TypeScript Cloud Run service.

## Stack

- Flutter 3.41 / Dart 3.11, Material 3, Riverpod, go_router.
- Drift/SQLite for financial data; Hive and secure storage for preferences and
  protected local state.
- Firebase Authentication, Firestore opt-in backup, App Check, Firebase AI.
- `services/cashpilot_ai_gateway`: Node 20+, TypeScript, Express, Zod, Firebase
  Admin, and a server-side Groq adapter.
- `decimal` and decimal strings for money. Never introduce `double` into a
  financial calculation or persistence path.

## Standard commands

Run from the repository root unless a directory is shown:

```powershell
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub -r expanded
flutter build apk --debug --no-pub
flutter build web --no-pub
npm.cmd run test:tools
npm.cmd run test:firestore-rules:emulator
```

Gateway gates:

```powershell
Set-Location services/cashpilot_ai_gateway
npm.cmd install
npm.cmd test
npm.cmd run lint
npm.cmd run typecheck
npm.cmd run build
npm.cmd run secret-scan
```

Integration tests require an explicitly authorized target and configuration:

```powershell
flutter test integration_test
```

Do not run live Android/Groq/App Check scripts against real accounts or cloud
projects without an explicit synthetic environment and cleanup plan.

## Architecture boundaries

- `lib/features/<feature>/domain` is pure Dart and owns rules/contracts.
- `application` coordinates use cases and providers; `data` implements Drift,
  Hive, Firebase, HTTP, and file adapters; `presentation` renders state.
- UI must not perform persistence, owner authorization, financial arithmetic,
  provider parsing, or arbitrary AI execution.
- Cross-feature dependencies use a narrow public facade or a consumer-owned
  port composed in `lib/app/di`; never import another feature's private data or
  presentation implementation.
- Auth state has one authoritative source. Owner-scoped state must invalidate
  and fence stale results during account transitions.
- Preserve schema names, wire keys, route names, provider IDs, storage keys,
  and failure codes unless a versioned compatibility migration exists.

## Financial invariants

- Store monetary values as decimal strings/`Decimal`; LYD supports up to three
  fractional digits (1 dinar = 1,000 dirhams).
- Posted effects change balances exactly once; pending effects do not.
- Transfers are atomic linked legs and never count as expense or ordinary
  income. Cross-currency transfers require explicit consistent FX terms.
- Mutations are owner-scoped, idempotent where retry is possible, and validated
  before any write. Update/delete must preserve reversal semantics.
- Never invent or silently apply an exchange rate.
- Preserve user data. Schema changes require a versioned forward migration,
  upgrade test, clean-database test, and documented recovery path.

## AI safety

- The model proposes structured plans; it never receives a database handle,
  supplies `userId`, emits SQL, or becomes execution authority.
- Only canonical allowlisted tools may run. Runtime validation, owner scope,
  permission, risk, confirmation, idempotency, transaction, and reconciliation
  checks remain deterministic and local/server controlled.
- Never report success before the durable write succeeds. A recorded transfer
  is not an external money transfer.
- Keep provider credentials server-side. Never log raw prompts, complete
  transaction history, auth/App Check tokens, UIDs, credentials, or financial
  content. Use safe correlation IDs and closed error codes.
- Prompt text and stored descriptions are untrusted input and cannot change
  permissions, confirmation rules, tool allowlists, or result bounds.

## Arabic and Libya localization

- Default locale/currency/timezone: `ar-LY`, `LYD`, `Africa/Tripoli`; preserve
  an explicit user preference.
- Accept Western, Arabic-Indic, and extended Arabic digits plus `.`, `,`, `٫`,
  and `٬` according to strict unambiguous parsing.
- Prefer short natural Arabic labels and correct RTL/touch/large-text behavior.
- Canonical bank/payment names and aliases are separate. Recognition never
  claims bank synchronization or a payment integration.
- Never request OTPs, passwords, full card data, or unnecessary identifiers.

## Generated and sensitive files

Do not manually edit:

- `**/*.g.dart`, `**/*.freezed.dart`.
- `lib/l10n/app_localizations*.dart` (edit ARB files, run `flutter gen-l10n`).
- Flutter generated plugin registrants and generated platform configuration.

Never commit `.secrets`, `.dev.vars`, local dart-define files, service-account
JSON, signing material, App Check debug tokens, provider keys, customer data,
logs containing identifiers, or production credentials.

## Deployment

Android release requires a final application ID, signing, SHA registrations,
Play Integrity/App Check acceptance, and physical-device verification. Web
requires production Firebase options, authorized domains, App Check, and a
successful release build. Gateway deployment/rollback follows
`docs/groq_gateway_deployment.md` and `docs/groq_rollout_and_rollback.md`.
