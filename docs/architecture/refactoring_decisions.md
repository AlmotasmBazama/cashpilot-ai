# Refactoring Decisions

This log summarizes architecture decisions implemented during the
behavior-preserving refactor. Detailed batch evidence is in
`docs/qa/architecture_refactor/REFACTORING_LOG_AR.md`.

| ID | Decision | Compatibility mechanism |
|---|---|---|
| ADR-001 | Enforce handwritten Dart layer rules with a local scanner instead of a new dependency. | Generated files and explicit composition roots are excluded; the strict baseline is zero. |
| ADR-002 | Track indirect feature cycles separately from forbidden private/layer imports. | Tarjan SCC scan uses an exact downward-only edge baseline. |
| ADR-003 | Keep domain pure by moving the assistant policy to application and App Check status to a neutral core contract. | Legacy Firebase-prefixed aliases remain available. |
| ADR-004 | Use narrow feature-root presentation facades for legitimately shared widgets/labels. | Use `show` for a subset or re-export one deliberately narrow source module intact; no directory-wide barrel. |
| ADR-005 | Inject a public transaction-row mapper into cross-feature read models. | Existing DTO→domain mapping remains the sole implementation. |
| ADR-006 | Expose Auth session/OAuth/coordination/restoration ports and keep Firebase adapters in Auth data. | Public Auth facade and neutral aliases preserve callers. |
| ADR-007 | Put receipt image cleanup behind a pure public port. | The existing local-image implementation and deletion journal semantics remain unchanged. |
| ADR-008 | Extract transfer creation/replay and transfer-pair lifecycle as two cohesive Transactions workflows. | Repository API/providers, ordinary CRUD/ledger ownership and atomic Drift/Finance behavior remain unchanged; the repository fell 1,190→354 lines. |
| ADR-009 | Split `AppDatabase` through six cohesive static `part` extensions while retaining schema/version and public entrypoints in one library. | The main file fell 2,504→764 lines with no generated schema change, runtime delegate allocation, SQL/DDL reorder or schema-17 change. |
| ADR-010 | Make Gateway `index.ts` the only production composition root and `app.ts` the HTTP factory. | Existing `createGatewayApp`/dependency aliases remain available. |
| ADR-011 | Separate Gateway ports from Firebase/Express/Groq adapters and give routes narrow dependency views. | Adapter modules re-export legacy internal types. |
| ADR-012 | Centralize the repeated AI request lifecycle without centralizing endpoint policy. | Exact SSE headers/events/retry/cleanup are characterized. |
| ADR-013 | Split Groq transport, bounded reads, SSE decoder and Zod response contracts. | `GroqChatCompletionsClient` and compatibility exports remain stable. |
| ADR-014 | Split request, financial, tool and SSE contracts by capability. | `contracts/gateway.ts` is a compatibility barrel. |
| ADR-015 | Derive Zod tool validation and provider JSON Schema from one typed metadata catalog. | Full 26-tool provider schema length and SHA-256 remain exact. |
| ADR-016 | Compose one Firebase Admin app and inject it into Gateway adapters. | Project, credential, collections and deletion order are unchanged. |
| ADR-017 | Keep live Android/tool runners thin and give reusable XML/safe-output, ADB, network/process, Firebase, Settings, Auth, AI-question and device-lifecycle capabilities neutral owners. | The four wrappers are 14/8/8/14 lines; injected deterministic tests preserve CLI parameters, exports, safe markers, timing bounds, exit/cleanup and validate-only behavior without a live run. |
| ADR-018 | Put receipt aggregate persistence, validation and financial confirmation in `ReceiptReviewWorkflow`. | The screen keeps the same widget tree, keys, messages and navigation; Decimal/Money/rate and idempotent confirmation ordering remain exact. |
| ADR-019 | Give each receipt-capture operation a resource lease for cancellation, byte zeroing, image ownership/cleanup and writer release. | The existing provider identity, stage order, owner/generation fences, App Check behavior and strict versus best-effort cleanup semantics remain unchanged. |
| ADR-020 | Keep the legacy AI provider file as the sole composition facade while moving the conversation state machine to an injected controller capability. | `aiAgentControllerProvider`, its zero-argument notifier, state type, overrides and disposal/session cleanup retain identity; the facade fell 1,191→309 lines. |
| ADR-021 | Split AI orchestration into local planning, provider-session/deadline delivery and conversation-response policy collaborators. | The orchestrator retains route/model selection, owner lease and actual tool execution; prompts, timeouts, result order, safe failures and public API remain unchanged while it falls 1,478→513 lines. |
| ADR-022 | Make the assistant screen a rendering/effect host around a framework-free conversation workflow and existing financial, lifecycle and durable-draft coordinators. | `BuildContext`, localization, dialogs, UI controllers, snackbars, route effects and widget keys remain in presentation; provider identity and exactly-once confirmation remain unchanged. |
| ADR-023 | Put cross-feature consumer adaptations in `lib/app/di`, while keeping stable provider capabilities with their provider and narrow projections/ports with their consumer. | Goals owns `GoalLinkedAccountOption`, Insights owns its explanation port, and compatibility facades expose the same provider objects without duplicate state. |
| ADR-024 | Reduce feature cycles only through ownership correction or upward composition, then freeze the residual exact debt. | The Tarjan ratchet moved 13 features/48 edges to 9/31; the strict private/layer baseline remains independently zero and the remaining SCC may only shrink. |
| ADR-025 | Remove `cupertino_icons` only after proving it has no source, lockfile or package-configuration consumer and rebuilding both targets. | Android debug APK and Web still build; no UI asset, route, localization or runtime contract is substituted. |

## Deliberately deferred

- Product defects and permissive configuration behavior found during the audit
  are recorded in `DEFERRED_FUNCTIONAL_FINDINGS.csv`; they are not silently
  changed here.
- The current 9-feature/31-edge cross-feature SCC is guarded but not disguised
  with a global service locator, compatibility facade or `core` dumping ground.
- Dependency version upgrades, Express type-family alignment and transitive
  audit pin changes are separate dependency/security work.
- The two secret-scan findings that existed at baseline remain failures pending
  a focused security review; no broad allowlist weakens that gate.
- The adversarial late-provider-turn behavior after an AI response deadline is
  recorded as `DF-009`; this refactor preserves its single consumer timeout and
  owner fence rather than changing cancellation/lease semantics silently.
- Live provider/device verification depends on external credentials and an
  Android target; deterministic gates do not simulate a successful live run.

## Adding code safely

For a new feature/use case/provider/repository or AI action: define the pure
contract first, keep DTOs and adapters outward, compose through Riverpod/root,
add observable characterization, run architecture tests, and preserve financial
confirmation/owner scope. A new AI action additionally needs a server allowlist
entry, Flutter/Gateway contract parity, permission policy, preview/confirmation,
idempotent execution, reconciliation and safe failure tests.
