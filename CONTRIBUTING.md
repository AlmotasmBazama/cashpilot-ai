# Contributing to CashPilot AI

نرحب بتحسينات الدقة المالية وتجربة العربية وسهولة الاستخدام. اشرح المشكلة
والسلوك المتوقع، واستخدم بيانات اصطناعية في الأمثلة والاختبارات.

Read [AGENTS.md](AGENTS.md) before changing code. Keep each change focused and
preserve existing user data, wire contracts, storage keys, and route names.

## Development environment

Use the versions and setup in [README.md](README.md#getting-started). Install
dependencies from committed lockfiles; update lockfiles deliberately when
changing dependencies. Both services require Node.js 24 or newer; CI and
production containers use Node.js 24. Use a dedicated development Firebase project for live
work. Do not use the repository's development registration as a shared test
account or request production access to run unit tests.

```sh
flutter pub get --enforce-lockfile
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
npm ci
npm --prefix services/cashpilot_ai_gateway ci
npm --prefix services/cashpilot_account_deletion ci
```

## Implementation rules

- Keep domain code pure Dart. Compose cross-feature dependencies in `lib/app/di`
  through a public facade or consumer-owned port.
- Keep amounts as `Decimal`/decimal strings and support LYD's three fractional
  digits. Validate before writing; posted effects change balances exactly once.
- Preserve atomic transfer legs, explicit FX terms, update/delete reversal
  semantics, idempotency, and owner isolation through account transitions.
- Treat AI output and stored text as untrusted. Enforce tool allowlists,
  permissions, confirmation, and reconciliation outside the model.
- Test Arabic and English, RTL, enlarged text, and Western/Arabic digit input
  when changing user-facing flows.
- Change localization in `lib/l10n/*.arb`, then run `flutter gen-l10n`. Generate
  Freezed/Drift/JSON outputs with build_runner; do not edit generated Dart or
  platform registrants manually.
- Schema changes require a forward migration, upgrade and clean-database tests,
  and a documented recovery path. Do not erase data to make a migration pass.

## Verification

Run checks relevant to the change, then the repository gates before proposing
release readiness:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub -r expanded
flutter build apk --debug --no-pub
flutter build web --no-pub
npm run test:tools
```

For each changed Node service, run `npm test`, `npm run lint`,
`npm run typecheck`, `npm run build`, and `npm run secret-scan` in its directory.
The secret scan checks the whole tracked/non-ignored repository, not only the
service. It is a limited pattern check and does not replace reviewing the diff
for personal data or unsupported credential formats.

For the local rules and deletion emulator tests, select JDK 21, install Firebase
CLI `15.22.4`, and run:

```sh
npm run test:firestore-rules:emulator
```

This uses `firebase.test.json` and `demo-cashpilot-ai` with local Auth and
Firestore emulators. It requires dependencies installed in the root and the
account-deletion service. Never substitute a real project for this demo ID.

For offline evaluation-tool tests:

```sh
npm --prefix tools/groq_evaluation ci --ignore-scripts
npm --prefix tools/groq_evaluation test
```

`--ignore-scripts` avoids the package's report-generation lifecycle script;
the test suite itself uses fixtures. Do not run `benchmark`, model discovery,
Android live acceptance, or `flutter test integration_test` without an explicit
target/configuration, synthetic data, and cleanup plan.

## Continuous integration

[The source-validation workflow](.github/workflows/ci.yml) runs on pushes, pull
requests, and manual dispatch. It checks formatting and generated sources,
analyzes/tests Flutter, builds Android Debug and Web, runs both services' gates,
builds their production containers, tests tooling on Ubuntu and Windows, and
runs the local Firebase emulator suites. Service installs enforce dependency
engine requirements. The workflow has read-only
repository permissions and does not deploy or require production secrets.

GitHub-hosted jobs still need to pass on the submitted commit. Local success
does not establish a hosted CI result. Android/iOS signing, physical-device
acceptance, and live provider/App Check verification are separate release gates.

## Pull requests

Describe the concrete problem and resulting behavior, include relevant checks,
and disclose untested platforms or external setup. Add regression tests for
financial, ownership, security, and retry behavior. Use screenshots only when
they help review a UI change and contain verified synthetic data.

Never include keys, auth/App Check tokens, service-account files, local Dart
defines, signing material, user IDs, raw prompts, real receipts, or transaction
history. Report vulnerabilities using [SECURITY.md](SECURITY.md).
