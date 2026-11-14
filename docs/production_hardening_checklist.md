# Production Hardening Checklist

This checklist records the Phase 6 audit. It prepares the project for a later
release review; it is not a store-submission checklist.

## Automated Coverage

- Auth shell, unauthenticated redirects, guest mode, email verification, and
  profile completion are covered by widget and domain tests.
- Dashboard loading, empty data, errors, exchange-rate warnings, budgets,
  goals, and local-first insights are covered by provider/widget tests.
- Accounts, transactions, transfer lifecycle, categories, payees, manual
  exchange rates, budgets, and goals have focused repository/domain tests.
- AI actions require validation and explicit confirmation; the assistant and
  confirmation card have narrow RTL smoke coverage.
- Core screens and controls are covered at 320 px in Arabic RTL. Shared layout
  tests also cover phone, tablet, and desktop width classes.
- Drift migrations are tested for fresh, v6, v8, v9, v10, v11, v12, and v13
  databases upgrading to schema version 14 with data and index preservation
  checks.
- Receipt extraction has strict schema, Decimal, arithmetic, mixed-category,
  invoice/refund, duplicate, sanitized-context, retry, persistence,
  idempotency, local-image boundary, and 320 px UI coverage.
- Backup behavior is tested for offline queueing, upload success, failure
  metadata, retry attempts, active-item compaction, idempotent remote paths,
  tombstones, auth blocking, user-scoped paths, and transaction balance safety.
- Firestore rules have an emulator suite covering all supported backup paths,
  owner/cross-user access, unauthenticated and anonymous denial, update/delete,
  invalid paths, and default-deny behavior.
- Full account deletion is staged and tested: reauthentication, Firestore data,
  Drift and queue, account-specific Hive preferences, then Firebase Auth.
- Firebase/App Check diagnostics have explicit configuration guidance and the
  app displays a localized retry screen if required initialization fails.

## Safe Product Surfaces

- Settings exposes draft Privacy Policy and Terms of Use screens in English
  and Arabic.
- The AI assistant displays an accuracy and financial-information disclaimer.
- Privacy copy distinguishes local storage, optional backup, AI processing,
  full account deletion, and the intentionally unavailable restore work.
- Backup Settings states that the current service is upload-only and does not
  restore or merge cloud data into Drift.

## Manual Release Review Still Required

- Exercise email/password, Google, Apple, anonymous upgrade, verification, and
  reauthentication against the intended Firebase project on physical devices.
- Keep the Firestore emulator suite in release CI. The workstation gate passed
  39/39 tests on 2026-07-19 with JDK 21.0.11; see
  `docs/firestore_emulator_tests.md` for the reproducible command.
- Register and verify App Check providers and debug tokens for each platform.
- Perform visual QA on target Android/iOS devices and supported browser/desktop
  combinations, including text scaling and accessibility navigation.
- Run the synthetic receipt matrix in `docs/receipt_scanning.md` on physical
  Android/iOS staging devices and inspect local logs for privacy regressions.
- Obtain legal review and replace the Privacy Policy and Terms placeholders.
- Design, threat-model, and test restore/conflict resolution before enabling
  any Firestore-to-Drift writes.
- Complete the release evidence in `docs/manual_qa_checklist.md` on target
  devices and the staging Firebase project.
