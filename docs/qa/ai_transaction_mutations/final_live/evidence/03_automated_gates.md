# Sanitized automated gate evidence

Captured: 2026-08-19 (Africa/Tripoli)

| Gate | Result |
|---|---|
| `flutter analyze --no-pub` | PASS; no issues |
| `flutter test --no-pub -r expanded` | PASS; 1687/1687 |
| `flutter build apk --debug --no-pub` | PASS |
| `flutter build web --no-pub` | PASS |
| `npm.cmd run test:tools` | PASS; 160/160 |
| Firestore rules | PASS; 42/42 |
| Account deletion emulator | PASS; 2/2 |

The standard Firestore wrapper could not acquire its configured ports because
an existing isolated emulator owned them. The existing isolated Firestore
emulator was used with a temporary Auth emulator; no pre-existing Java process
was terminated. Gateway source did not change, so Gateway gates were not rerun.
