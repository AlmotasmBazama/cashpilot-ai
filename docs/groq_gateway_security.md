# Groq Gateway Security

## Hosting decision

The gateway targets Node.js 24 on Cloud Run. This choice allows the official
Firebase Admin SDK to perform Firebase Authentication and App Check
verification. A Cloudflare Worker was not forced into the design because an
incomplete custom JWT verifier or App Check bypass would violate the fail-
closed requirement.

## Trust boundaries

The Flutter client is untrusted. It may request a capability, send a bounded
locale/history/context, and propose locally allowed read/calculation tool IDs.
It cannot supply a UID, provider key, upstream URL, model name, system prompt,
or mutation authority.

The gateway verifies the Firebase ID token with revocation checking, verifies
the App Check token, checks the Firebase audience/project, and retains only the
verified UID for rate limiting. Both tokens are consumed at the gateway and
are never forwarded upstream. Verification exceptions produce safe codes and
fail closed.

Groq is trusted only to produce advisory text or a candidate selection from a
strict allowlist. It has no database, Drift, repository, Firestore, balance,
receipt, filesystem, or mutation access.

## Request controls

- AI endpoints are POST-only and require `application/json`.
- Schemas are strict and mode-specific.
- Body, message, history, financial-context, tool-count, argument, output, and
  time limits are bounded.
- CORS uses exact configured web origins; wildcard origins are rejected.
- Per-verified-user rate limits are applied before provider use.
- Responses are private and carry no-store headers.
- Request bodies containing token-like, email, filesystem, storage, model, UID,
  or raw-transaction fields are rejected.
- No prompts, responses, tokens, identities, upstream headers, or secrets are
  logged.

## Financial and tool safety

Financial explanation receives deterministic aggregates only. The gateway
rejects unsupported figures and performs at most one same-model correction.
It also rejects language that claims CashPilot changed data.

Tool selection intersects the client list with the server allowlist. Every
selection and argument is validated again after generation. Only read-only
financial data tools and deterministic calculators are available. Flutter
still applies registry, permission, argument, and relevance validation and
performs any permitted read/calculation locally. Write-like behavior remains
draft-only elsewhere in CashPilot.

## Secret handling

`GROQ_API_KEY` is a server environment secret only. It is not a Flutter define,
asset, Android resource, iOS plist value, Remote Config value, log field,
snapshot, or committed environment file. Local `.dev.vars`, `.env*`, and
`.secrets/` paths are ignored. The automated scan checks Flutter and mobile
trees for provider configuration and scans tracked text for credential-shaped
values without printing matched secret material.

## Incident response

If exposure or abuse is suspected:

1. Disable all Groq Flutter flags and keep the Firebase/local fallbacks.
2. Disable or restrict the Cloud Run service and preserve safe request IDs and
   aggregate operational metrics.
3. Revoke and rotate the provider secret in Secret Manager.
4. Review IAM, deployment revisions, App Check enforcement, authentication
   failures, rate-limit aggregates, and source history.
5. Redeploy a new revision referencing the rotated secret; do not copy the
   value into commands, tickets, or logs.
6. Re-run the secret scan and staging acceptance suite before re-enabling any
   traffic.
