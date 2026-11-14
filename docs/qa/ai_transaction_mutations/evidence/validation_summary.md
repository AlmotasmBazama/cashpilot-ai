# Validation evidence summary

Captured: 2026-08-19 (Africa/Tripoli)

This file contains only command-level outcomes. It contains no prompts,
provider responses, credentials, user identifiers, database identifiers, or
real financial data.

| Gate | Outcome |
|---|---|
| `flutter analyze --no-pub` | PASS — No issues found (20.0 s final run) |
| `flutter test --no-pub -r expanded` | PASS — 1676 tests, 0 failures (2 m 12 s) |
| focused mutation/controller/UI suite | PASS — 172 tests, 0 failures |
| `flutter build apk --debug --no-pub` | PASS — debug APK built (99.7 s) |
| `flutter build web --no-pub` | PASS — `build/web` built (140.2 s); non-fatal existing Cupertino font warning |
| `npm.cmd run test:tools` | PASS — 160 tests, 0 failures |
| standard Firestore emulator command | ENV BLOCK — pre-existing listener occupied 127.0.0.1:8180 |
| isolated Firebase emulator run on 8181/9200 | PASS — 42 Firestore tests + 2 account-deletion tests |
| scoped sprint Dart formatting | PASS — all sprint Dart files formatted |
| repository-wide `dart format --output=none --set-exit-if-changed ...` | PRE-EXISTING FAIL — seven out-of-scope files reported; no writes made by the check |
| `flutter devices` | BLOCKED — no Android target; Windows/Chrome/Edge only |
| Android SDK `adb devices -l` | BLOCKED — empty device list |
| secret-shaped value scan on sprint reports/config | PASS — no matches |
| `git diff --check` on tracked sprint paths | PASS — no whitespace errors; line-ending notices only |

The isolated Firebase run used `firebase.ai_transaction_mutations.test.json`,
the demo project `demo-cashpilot-ai`, and local-only emulators. No production
Firebase service was addressed.
