# Testing Strategy

CashPilot uses a behavior-first test pyramid. Architecture refactoring never
updates expected outputs merely because a moved implementation produces a new
result.

## Layers

1. Pure domain tests cover Decimal rules, state transitions, validation,
   routing and safety policies.
2. Use-case/controller tests cover success, typed failure, cancellation,
   idempotency, owner isolation and exactly-once effects.
3. Repository/Drift tests use in-memory or temporary databases for SQL,
   sorting, pagination, atomicity, migrations and connection-level guards.
4. Riverpod tests use `ProviderContainer` for lifecycle, invalidation and stale
   result behavior.
5. Widget tests cover interaction and rendered states without pinning private
   widget structure. RTL and compact layouts are included where relevant.
6. Emulator/integration tests cover Firebase rules, protected deletion and
   device/provider journeys when prerequisites exist.

## Characterization before movement

For a risky extraction, identify the existing observable test matrix first.
Add a characterization test only for a missing contract. Important fixtures pin
balances, reversal, transfer legs, dashboard/reports/budget/goal totals,
receipt drafts, AI route/policy/confirmation, pagination, localization, routes,
SSE frames and error codes.

Compatibility hashes are appropriate only for true wire contracts. The Gateway
tool-schema test pins all 26 tools and the complete provider JSON Schema; normal
implementation details should not use snapshot hashes.

## Architecture gates

```text
flutter test --no-pub test/architecture
cd services/cashpilot_ai_gateway
npm.cmd test
cd ../..
npm.cmd run test:tools
```

The Dart strict import baseline and Gateway/tool dependency baseline are empty.
Feature-cycle debt has a separate downward-only exact-edge baseline.

## Standard validation

Focused after each batch:

```text
flutter analyze --no-pub
flutter test --no-pub <affected tests>
```

Final deterministic gates:

```text
flutter analyze --no-pub
flutter test --no-pub -r expanded
flutter build apk --debug --no-pub
flutter build web --no-pub
npm.cmd run test:firestore-rules:emulator
```

Gateway final gates are `npm.cmd test`, `npm.cmd run lint`,
`npm.cmd run typecheck`, `npm.cmd run build` and
`npm.cmd run secret-scan` from its service directory.

Live Android/Groq/App Check scripts are not routine unit gates. They may build,
install, change networking, force-stop an app, register debug tokens or create
synthetic cloud state. Run them only with explicit authorization, a safe
synthetic environment and documented cleanup. Use validate-only/dry-run modes
when available.

## Evidence

Sanitized results belong under `docs/qa/architecture_refactor/evidence`.
Evidence must never contain UIDs, owner scopes, authorization/App Check tokens,
Groq keys, prompts, provider bodies, financial records, receipt content or
signing material.
