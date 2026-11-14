# CashPilot AI Gateway

This service is CashPilot's narrow, stateless AI boundary. It is a Node.js
Cloud Run service because the official Firebase Admin SDK can verify both
Firebase Authentication and App Check tokens in this runtime. It is not a
generic provider proxy.

## Exposed routes

- `GET /health` — service version, environment, supported client version, and
  credential-presence readiness only. It never calls an upstream service or
  reveals credential, project, or identity values.
- `POST /v1/ai/general-chat` — server-routed general conversation. The default
  is incremental SSE; trusted clients can request bounded JSON with
  `responseMode: "json"`.
- `POST /v1/ai/financial-explanation` — guarded explanation of bounded,
  deterministic CashPilot facts.
- `POST /v1/ai/tool-selection` — selection from the server allowlist; no tool
  execution. This route is disabled by default.
- `POST /v1/diagnostics` — authenticated, App Check-protected, synthetic model
  availability check, disabled unless explicitly enabled.
- `POST /v1/account-deletion/recursive` — protected, owner-bound recursive
  Firestore deletion with an opaque permanent lock and verified-empty marker.
- `POST /v1/account-deletion/auth` — Auth-last completion or proof-bound,
  read-only lost-response recovery after verified cloud deletion.

There is no arbitrary model route, current-web route, mutation route, database
route, or unrestricted proxy.

## Local verification

Use Node.js 24 or newer (the containers and CI use Node.js 24):

```powershell
npm ci
npm test
npm run lint
npm run typecheck
npm run build
npm run secret-scan
npm audit
npm audit --omit=dev
```

For local development, copy `.dev.vars.example` to the ignored `.dev.vars`
file and populate values locally. Never commit that file and never print any
secret. Application Default Credentials must refer to the intended non-
production Firebase project.

The commands above do not call a live AI provider. Run
`npm run verify-groq-models` separately only for an explicitly authorized
environment. It uses only `GROQ_API_KEY` from the environment, queries the
configured Groq model catalog, prints only required model IDs and safe status
labels, and exits nonzero if either required model is unavailable.

Both Node services use Zod 4 and commit their dependency lockfiles. Security
updates must preserve the gateway's request, failure-code, and tool-schema
contracts; the tests verify strict owner-scoped inputs, decimal strings, and
the exact provider tool schema. Re-run both services' gates and current npm
audits after dependency changes, including explicit overrides.

## Configuration

The service requires `FIREBASE_PROJECT_ID` and the `GROQ_API_KEY` secret. Set
`CASH_PILOT_ENVIRONMENT` to `development`, `staging`, or `production`, and set
`CASH_PILOT_CLIENT_VERSION` to the only client contract version accepted by AI
routes (default `1.0.0`). Exact web origins are supplied through
`CASH_PILOT_ALLOWED_ORIGINS`. Staging and production fail to start if no exact
origin is configured or if a wildcard is used.

Provider model IDs and the upstream URL are fixed in server configuration;
clients cannot choose them. General conversation and governed tool selection
use `openai/gpt-oss-20b`; financial explanation uses
`openai/gpt-oss-120b`. A transient upstream failure can receive at most one
bounded retry on the same model, and only before response content is emitted.
Provider requests default to a 20-second timeout, while the complete request or
stream is bounded to 30 seconds by default. Set
`CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED=true` only when governed tool
selection has been explicitly approved for that environment.

Deployment, rotation, and rollback details are in
`docs/groq_gateway_deployment.md` and `docs/groq_rollout_and_rollback.md`.

## Account-deletion quarantine

Before deleting `/users/{uid}`, the Admin store transactionally creates
`/accountDeletionLocks/{SHA-256(uid)}`. The document contains versioned opaque
operation/session commitments, an encrypted proof-bound recovery envelope,
server timestamps and the continuation deadline; it stores neither the raw UID
nor the raw deletion proof. The same operation and session may resume; a
different operation receives a conflict. After recursive deletion, the Admin
store verifies both the lock and the empty user tree before writing the
verified-cloud-deletion marker. Firestore Rules deny every client write in the
user tree while the lock exists and deny clients all access to the lock itself.
Admin SDK operations continue because server libraries bypass Firestore
Security Rules.

The lock intentionally does not expire. An authentication profile left after
a partial failure can keep refreshing ID tokens indefinitely; any TTL would
eventually reopen writes and allow a second device to recreate deleted data.
Removal therefore requires a future, separately verified safe-finalization
protocol and is not part of recursive deletion.

Registered users must have `auth_time` within five minutes. Anonymous users
have no strong reauthentication mechanism, so the client force-refreshes its
ID token and the gateway requires `iat` within five minutes in addition to App
Check and the permanent deletion lock. Auth deletion is last and rechecks the
live cloud tree. A bounded continuation may accept the same proof-bound session;
after expiry, fresh authentication is required. Proof-only recovery is
rate-limited, App Check-protected, read-only, and succeeds only when Auth is
already absent.
