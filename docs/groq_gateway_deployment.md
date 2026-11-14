# Groq Gateway Deployment

## Prerequisites

Use a dedicated staging Google Cloud/Firebase project with Cloud Run, Secret
Manager, Artifact Registry, Firebase Authentication, and App Check configured.
The deployment identity needs only the permissions required to build/deploy
the service and bind the secret. The Cloud Run runtime service account needs
Firebase token verification access and secret accessor access for the single
provider secret.

Do not deploy until all local verification commands pass and the intended
staging project, region, service name, exact web origins, runtime identity, and
App Check registrations have been independently confirmed.

## Secret provisioning

Create or rotate the secret using an input mechanism that does not place the
value in shell history. Bind the latest approved secret version to the runtime
environment name `GROQ_API_KEY`. Do not use a regular Cloud Run environment
variable for the secret and do not place it in an image, source file, build
argument, Flutter define, or deployment manifest.

## Cloud Run configuration

Build the included Dockerfile from `services/cashpilot_ai_gateway`. Configure:

- Node.js 24 runtime from the included container, matching the service's engine
  requirement and CI. Both the build and runtime stages use Node.js 24.
- `GATEWAY_ENVIRONMENT=staging`.
- `FIREBASE_PROJECT_ID` set to the exact staging Firebase project.
- `CASH_PILOT_ALLOWED_ORIGINS` as a comma-separated set of exact HTTPS origins.
- `MODEL_DIAGNOSTICS_ENABLED=false` normally.
- The Secret Manager binding for `GROQ_API_KEY`.
- HTTPS ingress, least-privilege IAM, conservative instance concurrency, and
  platform request timeout above the gateway's bounded stream duration.

The service requires Firebase bearer and App Check tokens at its application
boundary. Cloud Run IAM may add another ingress control but does not replace
those checks.

## Pre-traffic diagnostic

For an authorized staging operator build only, temporarily enable the
authenticated synthetic model-availability diagnostic. Invoke it through a
registered staging client with valid Firebase Auth and App Check. Record only
the safe state labels and request ID, then disable diagnostics and deploy a new
revision before user testing. Never record tokens or raw upstream data.

## Flutter staging configuration

Provide only the HTTPS gateway base URL and capability booleans to Flutter.
There is no provider key or model identifier in Flutter configuration. Begin
with all Groq flags false. Use the rollout stages in
`groq_rollout_and_rollback.md`; do not route production traffic as part of a
staging deployment.

## Key rotation

Add a new Secret Manager version, deploy a revision referencing it, verify
synthetic staging health, shift only staging traffic, and then disable the old
version. If validation fails, route back to the prior healthy revision without
exposing either value.
