# Security policy

CashPilot AI handles personal financial records. Owner isolation, deterministic
financial rules, and server-side credential handling are security boundaries.
The repository is under active development; production readiness and supported
platform scope are described in [README.md](README.md#release-status).

## Reporting a vulnerability

**لا تنشر بيانات مالية أو مفاتيح أو رموز دخول في Issues العامة.**

Use the repository's **Security → Report a vulnerability** option when private
vulnerability reporting is enabled. If that option is unavailable, contact the
repository owner through a private channel shown on their GitHub profile. If no
private channel is published, open an issue only to request one, without exploit
details, affected-account identifiers, or sensitive data.

Include the affected commit, affected component, expected versus observed
behavior, and a minimal reproduction using synthetic data. Describe impact
without accessing another person's records or running destructive operations.
Do not attach live tokens, credentials, complete transaction histories, or raw
provider prompts/responses.

## Scope and handling

Relevant issues include cross-owner data access, incorrect financial mutations,
replay/idempotency failures, confirmation bypass, AI tool authorization bypass,
credential exposure, and weaknesses in backup or account deletion.

No response-time commitment or bug-bounty program is currently offered. Fixes
target the active development branch; historical builds are not maintained as
separate supported releases. Coordinate public disclosure with the maintainer
after a fix and regression checks are available.

## Safe development

- Use synthetic data and local `demo-cashpilot-ai` emulators for security tests.
- Keep provider credentials server-side. Firebase client configuration is not a
  service-account credential; access still requires appropriate Auth, rules, API
  restrictions, and App Check.
- Do not expose auth/App Check tokens, UIDs, financial content, or raw prompts
  in logs. Use safe correlation IDs and closed error codes.
- Review both the working tree and Git history before first publication. The
  service `secret-scan` commands are limited pattern checks, not a guarantee.
- If a credential is exposed, revoke or rotate it first, assess access, and
  coordinate repository/history cleanup. Deleting the visible file alone does
  not invalidate a leaked credential.

See [the engineering guide](AGENTS.md), [AI privacy](docs/ai_agent_privacy.md),
[receipt privacy](docs/receipt_privacy.md), and
[gateway security](docs/groq_gateway_security.md) for component-specific rules.
