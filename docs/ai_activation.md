# CashPilot AI — Firebase AI Logic Activation

This document is the release runbook for the official Firebase AI Logic
provider. The app keeps Firebase AI behind `AiProviderDataSource` and
`AiRepository`; widgets never construct a Gemini provider.

## Safety contract

- Firebase AI only prepares structured drafts. It cannot execute a transaction,
  transfer, budget, goal, category, or contribution.
- Every data-changing AI action must carry `requiresConfirmation: true` and
  still passes the local validator and explicit confirmation UI.
- Destructive requests are blocked before provider invocation.
- A failed provider, invalid JSON, or unsupported schema falls back to the local
  financial command parser.
- The provider receives the user's current request plus a small allowlist:
  locale, supported currency codes, sanitized account aliases, payment-method
  aliases, and category names. It does not receive user IDs, email addresses,
  balances, account IDs, transaction history, payee aliases, sync payloads, or
  tool messages. The Firebase boundary is intentionally stateless: earlier
  user/assistant messages kept for on-screen conversation rendering are not
  sent again on a later request.
- Do not add a Gemini Developer API key to Flutter code. The normal Firebase
  client API key in generated FlutterFire options is not a Gemini API key.

## 1. Register production Firebase apps

Before enabling production traffic, replace the example Android/iOS identifiers
and configure every platform that will ship.

1. Choose the final Android package name and iOS bundle ID.
2. Register the Android, iOS, and (if shipped) Web apps in Firebase Console.
3. Add the Play App Signing/release SHA-256 certificate to the Android app.
4. Run FlutterFire configuration for the selected platforms and review the
   generated files:

```powershell
dart pub global run flutterfire_cli:flutterfire configure `
  --project=cashpilot-ai-a6b49 `
  --platforms=android,ios,web `
  --out=lib/firebase_options.dart
```

At the time of this readiness pass, `lib/firebase_options.dart` contains only
Android options. iOS and Web are manual release blockers until they are
registered and regenerated. A successful Web compile alone does not prove that
Firebase can initialize in a browser.

### Verified local platform state

- Android is internally aligned to Firebase project `cashpilot-ai-a6b49` and
  package `com.example.cashpilot_ai`: `android/app/google-services.json`,
  `lib/firebase_options.dart`, and `firebase.json` contain the same Android app
  mapping, and the Google Services Gradle plugin is declared and applied.
- The current package is suitable only for the registered development app. The
  release build still needs a final owned package name, production signing, the
  Play App Signing SHA-256, and a newly registered matching Firebase app before
  store release.
- iOS has no generated FlutterFire option or `GoogleService-Info.plist`; Web has
  no generated FlutterFire option. Both fail Firebase initialization at runtime
  until `flutterfire configure` succeeds for their registered apps.
- macOS, Windows, and Linux are also not Firebase-configured. Do not list them
  as supported Firebase targets without an explicit configuration and App Check
  review. A Windows release fails closed because the current Flutter App Check
  SDK exposes only a Windows debug provider; Windows production is unsupported
  until a production attestation provider is available and integrated.

## 2. Enable Firebase AI Logic

1. Open Firebase Console > **AI Logic** > **Get started**.
2. Select the **Gemini Developer API** backend for this application.
3. Confirm the Firebase AI Logic API is enabled in the linked Google Cloud
   project.
4. Confirm the configured stable model is supported by Firebase AI Logic.
5. Do not copy a Gemini API key into Dart, Android resources, Web assets, or CI
   arguments.

Official setup: <https://firebase.google.com/docs/ai-logic/get-started>

## 3. Runtime provider selection

Provider selection is compile-time configuration through `--dart-define`:

| Mode | Value | Intended use |
| --- | --- | --- |
| Mock | `mock` | Deterministic tests and UI development |
| Local parser only | `localParserOnly` | Default debug/test mode; no remote AI call |
| Firebase Gemini | `firebaseGemini` | Staging and production |

Examples:

```powershell
flutter run --dart-define=CASH_PILOT_AI_PROVIDER=localParserOnly

flutter run `
  --dart-define=CASH_PILOT_AI_PROVIDER=firebaseGemini `
  --dart-define=FIREBASE_APP_CHECK_DEBUG_TOKEN=<registered-debug-token>

flutter build web --release `
  --dart-define=CASH_PILOT_AI_PROVIDER=firebaseGemini `
  --dart-define=FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY=<site-key>
```

With no override, debug/test selects `localParserOnly`; profile/release selects
`firebaseGemini`. Unknown values fail closed to the local parser in debug.
AI diagnostics are enabled outside release by default and can be explicitly
controlled with `CASH_PILOT_AI_DIAGNOSTICS=true|false`.

For a live debug device, prefer an ignored local dart-define file so the debug
token is not copied into source, documentation, CI logs, or shell history. The
root `.gitignore` excludes `.dart-define*.json`:

```json
{
  "CASH_PILOT_AI_PROVIDER": "firebaseGemini",
  "FIREBASE_APP_CHECK_DEBUG_TOKEN": "<registered-debug-token>"
}
```

Save it as `.dart-define.appcheck.json`, keep it only on the trusted test
machine, and run:

```powershell
flutter run -d <device-id> `
  --dart-define-from-file=.dart-define.appcheck.json
```

### Stable local Web debug startup

Do not launch remote-AI Web staging directly with only
`config/groq_staging.json`. Without an explicit debug token, the Firebase Web
SDK stores an automatically generated token per browser origin. Flutter's
random localhost port changes that origin and can therefore generate a new,
unregistered token on a later run.

Use the VS Code **CashPilot Web — Staging** profile. Its pre-launch task merges
the public staging configuration with the ignored token from
`.dart-define.appcheck.json`, writes the ignored
`.dart-define.groq-staging.local.json`, validates the stable token against the
registered Web Firebase app, and registers or repairs only its own managed
debug-token entry when needed. The task never prints the debug token.

The equivalent terminal commands are:

```powershell
npm.cmd run prepare:web-app-check
flutter run -d chrome `
  --dart-define-from-file=.dart-define.groq-staging.local.json
```

## 4. Model configuration

All defaults live in
`lib/features/ai_assistant/data/config/ai_runtime_config.dart`:

- Model: `gemini-3.1-flash-lite` (stable, fast, economical).
- Temperature: `0.1` for deterministic financial parsing.
- Maximum output: `512` tokens.
- Structured output: enabled for financial actions.
- Streaming: off by default; the architecture keeps it optional.
- Request timeout: 20 seconds.

Supported overrides:

```text
CASH_PILOT_AI_MODEL
CASH_PILOT_AI_TEMPERATURE
CASH_PILOT_AI_MAX_OUTPUT_TOKENS
CASH_PILOT_AI_STREAMING
```

Only the model in the configured allowlist can be requested. Validate model
changes in staging before release. Prefer a stable Flash or Flash-Lite model;
do not default command parsing to Pro, preview, experimental, or
reasoning-heavy models.

Current model list: <https://firebase.google.com/docs/ai-logic/models>

## 5. Structured output contract

Financial requests use Firebase `GenerationConfig` with MIME type
`application/json` and a response schema. Supported intents are:

```text
create_expense
create_income
create_transfer
create_category
create_budget
create_goal
add_goal_contribution
ask_financial_question
unknown
```

Amounts remain strings. Data-changing intents must set
`requiresConfirmation` to `true`. Transfer rates or destination amounts are
accepted only when explicitly supplied by the user. JSON is parsed and checked
again locally; invalid or unsupported responses are discarded and the local
parser is used.

Official structured output guidance:
<https://firebase.google.com/docs/ai-logic/generate-structured-output>

## 6. App Check

### Debug devices

The CashPilot logger and diagnostics must never print a debug token or token
prefix. There are two distinct setup paths:

1. **Existing registered token (preferred):** retrieve it from the approved
   local/CI secret store, put it in the ignored `.dart-define.appcheck.json`
   file shown above, and start the debug build with
   `--dart-define-from-file`. Do not echo it in a script or CI log.
2. **First-device bootstrap:** omit `FIREBASE_APP_CHECK_DEBUG_TOKEN` and run a
   debug build once. The official Firebase App Check debug provider itself
   emits a one-time local debug secret to Logcat, Xcode output, or the browser
   developer console. This SDK-only line is expected for initial registration;
   it is not a CashPilot application log. Copy it privately, register it, then
   stop the bootstrap run and use the ignored dart-define file thereafter.

Register the token in Firebase Console > **Security** > **App Check** >
**Apps** > the matching app > **Manage debug tokens**. Give it a device-specific
label, never commit/share/screenshot it, and revoke it immediately if exposed.
Do not distribute debug builds to untrusted testers.

Exact Android debug-device flow:

```powershell
flutter devices

# One-time bootstrap only; inspect local SDK debug output for its token.
flutter run -d <device-id> `
  --dart-define=CASH_PILOT_AI_PROVIDER=firebaseGemini

# After registering the token, use the ignored local define file.
flutter run -d <device-id> `
  --dart-define-from-file=.dart-define.appcheck.json
```

Open Settings > AI configuration > **Test AI connection**. A successful result
must show the live provider, configured model, structured output, and a safe
success status. An unregistered token must produce a localized App Check
blocked status, never a crash or raw SDK error.

Android, Apple, and Web debug providers are selected only in non-release
builds. The Settings **Test AI connection** action requests an App Check token,
sends a fixed harmless structured prompt with empty context, validates the
structured `unknown` response, and reports provider or fallback readiness. It
never invokes the action executor or touches balances, transactions, budgets,
goals, payees, IDs, or user profile data.

Release compilation discards the configured debug-token value, and startup
fails closed if the `FIREBASE_APP_CHECK_DEBUG_TOKEN` environment define was
supplied. Never pass the ignored debug define file to a profile/release build.

### Production providers

- Android: Play Integrity. Use the final package name, Play App Signing
  certificate SHA-256, production signing, a Google Play Console project linked
  to `cashpilot-ai-a6b49`, and a release distributed through the expected
  channel. Do not validate production readiness with the current debug-signed
  release configuration.
- iOS: App Attest with DeviceCheck fallback. Register the final iOS Firebase
  app, generate `GoogleService-Info.plist`, and enable the required Apple
  capability.
- Web, if shipped: reCAPTCHA Enterprise with an allowed-domain/site-key setup.
  The release build requires
  `FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY`.
- Windows: not supported for release while the Flutter App Check SDK offers
  only `WindowsDebugProvider`. Do not ship a Windows Firebase build by treating
  the debug provider as production attestation.

Review App Check metrics before enabling enforcement, then enforce Firebase AI
Logic for production. Do not use debug providers or disable enforcement in a
release build.

Repository inspection can verify provider selection but cannot prove Console
state. In Firebase Console, confirm the matching app is registered and Firebase
AI Logic shows baseline protection as **Enforced**. Review verified/unverified
metrics before release. Replay protection is an optional later hardening step;
enforce it only after the shipped Firebase AI client is configured to request
limited-use tokens and metrics show older clients will not be broken.

Official guidance:
<https://firebase.google.com/docs/ai-logic/app-check> and
<https://firebase.google.com/docs/ai-logic/production-checklist>

## 7. Rate limits and cost controls

The client prevents concurrent sends, debounces rapid sends, and blocks a
normalized identical prompt for five seconds. These controls improve UX and
reduce accidental cost; they are not a security boundary and can be bypassed by
a modified client. App Check enforcement, provider/project quotas, API-key
restrictions, and backend/provider controls are the security and abuse-control
layers.

In Google Cloud Console > Firebase AI Logic API > Quotas & System Limits,
review **Generate content requests per user per region per minute**. Firebase's
documented default is 100 RPM per user, which is high for CashPilot's short
command workflow. Start staging near 10 RPM per user, measure real usage and
error rates, then choose the production value deliberately. Also monitor the
Gemini provider's project RPM/RPD/TPM/TPD limits and billing alerts. A 429 is
shown as a localized friendly error and falls back locally when possible.

In Cloud Billing > **Budgets & alerts**, create staging and production budgets
with multiple notification thresholds and monitored recipients. Budget alerts
notify; they do not automatically cap spend. Review Firebase AI Logic usage,
App Check metrics, error rates, and quota consumption during staging and after
each model/configuration change. Never force paid production traffic merely to
test a 429; use provider fakes in automated tests and a deliberately constrained
staging quota for manual validation.

Official quota guidance: <https://firebase.google.com/docs/ai-logic/quotas>

## 8. Test commands

Local gates:

```powershell
java -version
npm.cmd run test:firestore-rules:emulator
flutter analyze --no-pub
flutter test --no-pub test/features/ai_assistant
flutter test --no-pub
flutter build web --no-pub
```

Run live diagnostics on a configured physical device or emulator:

```powershell
flutter test integration_test/app_check_diagnostics_test.dart -d <device-id> `
  --dart-define-from-file=.dart-define.appcheck.json

flutter test integration_test/firebase_ai_smoke_test.dart -d <device-id> `
  --dart-define-from-file=.dart-define.appcheck.json
```

Live tests consume Firebase services and must target the intended staging
project. The AI smoke test requires `firebaseGemini`, runs only the harmless
structured `AiConnectionDiagnostic`, and logs fixed status booleans rather than
the prompt, response, token, Firebase identifiers, or raw errors. Do not claim
these tests pass without running them on a configured platform. Complete every
row in `docs/manual_qa_checklist.md` after the diagnostics pass.

## 9. Secret and logging audit

The repository text and Git history were reviewed on 2026-07-21 for Gemini/API
keys, App Check debug tokens, auth/bearer/JWT values, private keys, client
secrets, raw AI prompts/responses, and logging of Firebase/user identifiers.
The result was:

- No Gemini Developer API key, registered App Check debug token, auth token,
  private key, client secret, JWT, or bearer token was found in tracked history.
- The generated Android configuration contains the expected Firebase client
  API key in `android/app/google-services.json` and
  `lib/firebase_options.dart`. Firebase client keys identify a Firebase app and
  are not Gemini Developer API keys. They still must be restricted in Google
  Cloud Console to the required Firebase APIs and must not allow the
  **Generative Language API** or unrelated Google APIs.
- No CashPilot code intentionally logs prompts, AI response bodies, token
  values/prefixes, UID, email, phone, balances, raw accounts, transaction
  history, or notes. Live diagnostic tests emit only fixed labels and booleans.
  Automated boundary tests cover ASCII, Arabic-Indic, and Persian phone-number
  digits and verify that repository failure logs contain only fixed labels,
  safe codes, and exception types. The shared logger also redacts common
  credential, UID, email, and phone shapes and replaces arbitrary exception
  values with their runtime type before output.
- `*.log`, `.env*`, local dart-define token files, and common signing/private-key
  files are ignored. Never put a real secret in an example env file.
- Generic SDK exceptions can contain implementation detail. Map provider/auth
  failures to safe codes and do not forward raw exception text to analytics,
  crash metadata, screenshots, issue trackers, or user-visible diagnostics.

Repeat a text scan before release and investigate every hit. The two generated
Firebase client-key locations are expected; a Gemini key or token anywhere is a
release blocker:

```powershell
rg -n --hidden `
  -g '!build/**' -g '!.dart_tool/**' -g '!node_modules/**' -g '!.git/**' `
  -e 'AIza[0-9A-Za-z_-]{20,}' `
  -e 'sk-[0-9A-Za-z_-]{20,}' `
  -e 'FIREBASE_APP_CHECK_DEBUG_TOKEN\s*[=:]\s*[^<\s]' `
  -e 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' .

git grep -n -I -E `
  'sk-[0-9A-Za-z_-]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|access_token|refresh_token|auth_token' `
  HEAD
```

Use an automated secret scanner in CI when available; the grep audit is a
minimum release check, not proof that binary assets or external systems are
clean. If any registered debug token is exposed, revoke it in Firebase Console
before continuing.

## 10. Production checklist

- [ ] Final Android package and iOS bundle identifiers replace example IDs.
- [ ] Android release signing and Play App Signing SHA-256 are configured.
- [ ] iOS and Web FlutterFire options are generated if those platforms ship.
- [ ] Firebase AI Logic uses the Gemini Developer API backend.
- [ ] Selected model is stable and supported.
- [ ] App Check production providers are registered and metrics reviewed.
- [ ] Firebase AI Logic App Check enforcement is enabled for production.
- [ ] Debug tokens and ignored dart-define files are absent from release/CI artifacts.
- [ ] Windows release remains disabled until production App Check attestation exists.
- [ ] reCAPTCHA Enterprise site key and domains are configured if Web ships.
- [ ] Per-user quota and billing alerts are set and monitored.
- [ ] Firebase client key restrictions exclude the Generative Language API.
- [ ] Secret/log scan is repeated and produces no unexplained sensitive hits.
- [ ] Privacy policy and terms receive legal review.
- [ ] Live App Check and Firebase AI smoke tests pass on staging devices.
- [ ] Every live prompt/guardrail row in the manual QA checklist is recorded.
- [ ] Analyze, full tests, Firestore emulator rules, and Web build pass.

## 11. Governed financial agent

Firebase function calling is enabled only through the data-layer
`FirebaseAiAgentModelGateway`. Gemini receives declarations from the central
registry and cannot access repositories or databases. The loop is limited to
four rounds, six calls per round, twelve total calls, five seconds per tool,
30 seconds per run, 20 transaction summaries, and 16 KiB per tool result.

General-assistant compatibility flags:

```text
CASH_PILOT_AI_AGENT_ENABLED
CASH_PILOT_AI_READ_ONLY_TOOLS_ENABLED
CASH_PILOT_AI_DRAFT_TOOLS_ENABLED
CASH_PILOT_AI_CONVERSATION_MEMORY_ENABLED
CASH_PILOT_AI_COMPLEX_PLANNING_ENABLED
```

`CASH_PILOT_AI_AGENT_ENABLED` continues to control the conversational
orchestrator. The legacy read/draft values cannot grant application tools and
must not be used to bypass the governed app-control policy.

Governed app-control flags:

```text
CASH_PILOT_AI_APP_CONTROL_ENABLED
CASH_PILOT_AI_READ_TOOLS_ENABLED
CASH_PILOT_AI_NAVIGATION_TOOLS_ENABLED
CASH_PILOT_AI_CREATE_DRAFTS_ENABLED
CASH_PILOT_AI_CONFIRMED_EXECUTION_ENABLED
CASH_PILOT_AI_TRANSFER_EXECUTION_ENABLED
CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED
CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED
CASH_PILOT_AI_MULTI_STEP_PLANS_ENABLED
CASH_PILOT_AI_AGENT_AUDIT_ENABLED
CASH_PILOT_AI_LOCAL_DATASET_SCOPE_VERIFIED
```

App control, navigation, create/update/archive drafts, confirmed execution,
multi-step plans, and local-dataset verification default off. Read tools default on only when
`CASH_PILOT_ENVIRONMENT=staging`; audit defaults on. Build flags are always
intersected with authenticated scope and account-scoped user settings. The
local dataset verification gate additionally blocks financial reads and
drafts. No legacy flag can widen these capabilities.

Owner-scoped Drift schema v16, durable command/audit/idempotency storage, and
business-state reconciliation are implemented. The verification flag still
defaults false and must remain false in normal builds. It may be enabled only
for an authorized staging build after the intended Firebase staging project,
two synthetic test accounts, and runtime `OwnerScopeHealth.safe` are confirmed.
General conversation remains independent. No Remote Config dependency is
required; compile-time local fallback is authoritative.

Live staging command:

```powershell
flutter test integration_test/firebase_ai_agent_smoke_test.dart `
  -d emulator-5554 `
  --dart-define-from-file=.dart-define.appcheck.json
```

Run this test only after the staging identity/device prerequisites are met and
the read-only gates are intentionally enabled. It uses synthetic financial
values, verifies a read tool and follow-up, and checks that an action remains a
draft. Its output contains fixed status booleans only. Passing on an emulator
does not satisfy the separate physical-device acceptance gate.
