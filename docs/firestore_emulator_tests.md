# Firestore Security Rules Emulator Tests

The security suite runs only against the local Firestore emulator and the
`demo-cashpilot-ai` demo project. It must never target a production project.

## Prerequisites

- Node.js and npm.
- Firebase CLI (`firebase --version`).
- A JDK available on `PATH` (`java -version`). JDK 21 is recommended; JDK 17
  can be used when supported by the installed Firebase emulator version.

## Run on Windows

PowerShell installations that block `.ps1` shims should use the `.cmd`
executables:

```powershell
npm.cmd install
npm.cmd run test:firestore-rules:emulator
```

## Run on macOS or Linux

```bash
npm install
npm run test:firestore-rules:emulator
```

The npm command starts the Firestore emulator on `127.0.0.1:8080`, runs the
Node test suite, and stops the emulator after completion. A successful release
gate must finish with a zero exit code.

## Coverage

The suite verifies all supported paths:

- `accounts/{id}`
- `transactions/{id}`
- `categories/{id}`
- `payees/{id}`
- `exchangeRates/{id}`
- `budgets/{id}`
- `goals/{id}`
- `settings/main`
- `syncMetadata/{deviceId}`

For every backup path it checks owner read/write, cross-user denial,
unauthenticated denial, and anonymous-user denial. It also covers owner and
cross-user update/delete, anonymous access to the user's root profile, invalid
settings document IDs, nested invalid paths, public paths, and the default-deny
fallback.

## Current Workstation Status

On 2026-07-19, `java -version` reported JDK 21.0.11 and the exact command

```powershell
npm.cmd run test:firestore-rules:emulator
```

completed with exit code 0 against Firestore Emulator 1.21.0: 39 tests passed,
0 failed, skipped, or cancelled. Expected `PERMISSION_DENIED` emulator log lines
come from negative authorization assertions. Rerun this gate in release CI;
this dated workstation result is evidence, not a substitute for CI.
