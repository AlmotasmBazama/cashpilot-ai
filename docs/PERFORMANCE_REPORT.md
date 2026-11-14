# Performance Report

Date: 2026-08-18. Measurements are separated into current host results,
source-level request counts, prior repository fixtures, and unavailable live
device data.

## Before and after

| Area | Before | After | Evidence |
|---|---:|---:|---|
| Email login/registration profile operations on the awaited return path | Firestore get + set + second get (3 sequential operations after provider response) | Firestore get + set (2); DTO uses the already prepared profile | `FirebaseAuthDataSource.signIn/signUp/_prepareUserDocument` |
| Home top-level watched feature providers | Dashboard + Budget + Goal + Insights (4) | Dashboard snapshot only (1) | `DashboardScreen.build` |
| Compact/desktop top-level destinations | 6 compact / 10 rail-sidebar | 4 on every form factor | `AppShellPage._destinations` |
| Manual Home expense/income | Navigate to list, then open form | Form opens directly from Home | `_QuickActions._openTransaction` |
| Dashboard 10,020-row fixture | 520,787us; all-row path | 2,349us; 20 mapped | `dashboard_transactions_read_model_test.dart` / prior QA evidence |
| Transaction history 10,000-row fixture | 209,797us | 1,738us for 50-row page | `transaction_history_pagination_test.dart` |
| Budget 10,020-row fixture | 179,125us | 1,100us for contributing window | `budget_transactions_read_model_test.dart` |

The auth request reduction is a deterministic sequence/count improvement, not
a laboratory latency claim. `AuthPerformanceTrace` now records provider,
profile-bootstrap, hydration, completion/failure stages with safe correlation
IDs so real staging percentiles can be collected without financial content.

## Current host baseline

- Dependency resolution: 21.3s.
- Analyzer before changes: 345.3s, zero issues.
- Full Flutter suite before changes: 1m52s, 1,623/1,623.
- Focused changed-area suite: 33/33 in about 5s test time.

## Final closure results

| Gate | Result |
|---|---|
| `flutter analyze --no-pub` | PASS, zero issues, 16.3s final cached run |
| `flutter test --no-pub -r compact` | PASS, 1,635/1,635, 2m10s |
| Gateway `npm test` | PASS, 133/133, 25.7s |
| Gateway lint / typecheck / build / secret scan | PASS |
| Root tooling tests | PASS, 160/160 |
| Firestore/Auth emulator suites | PASS, 42/42 rules + 2/2 Admin/Auth deletion |
| Android debug APK | PASS, 81.7s, 204,464,531 bytes |
| Web build | PASS, 126.0s, 45,001,484 bytes total; `main.dart.js` 6,924,479 bytes |
| Windows debug build | BLOCKED: Visual Studio C++ toolchain is not installed on this host |
| Physical Android integration/E2E | NOT RUN: no Android device was connected |

The APK measurement is a debug artifact and is not a release-size claim. The
Web build completed with a non-fatal Cupertino icon font warning; no
`CupertinoIcons` source reference or `cupertino_icons` dependency is present in
the project. Analyzer duration varies significantly with cache/process state and
is not a user-facing performance metric.

## Live/runtime evidence and limits

Prior repository evidence reports Android debug/emulator cold startup between
8.1 and 14.1 seconds, above the 5-second target. Debug instrumentation and an
emulator are not representative enough for a production percentile, but the
result remains a release blocker. Prior Firebase AI first-content timings were
roughly 3.6–6.6 seconds with bounded completion and retry recovery.

No physical mid-range Android device, signed profile/release build, or safe live
test account was supplied in this run. Therefore auth tap-to-content timing,
warm-cache startup, frame percentiles, soak, DNS/TLS, and production provider
latency are not claimed. Use the new `auth_trace` stages in staging, then record
p50/p95 and request waterfalls without emails, UIDs, tokens, or finance data.
