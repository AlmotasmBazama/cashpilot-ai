# Groq Rollout and Rollback

All flags default to the safe state: Groq off, current web off, Firebase receipt
vision on. A configured endpoint alone does not activate traffic.

| Stage | Gateway | General | Tools | Financial | Arabic specialist | Current web | Receipt |
|---|---:|---:|---:|---:|---:|---:|---:|
| 0 rollback/default | off | off | off | off | off | off | Firebase on |
| 1 development | on | on | off | off | off | off | Firebase on |
| 2 staging tools | on | on | on | off | off | off | Firebase on |
| 3 synthetic financial staging | on | on | on | on | on after Arabic review | off | Firebase on |
| 4 limited production | on | cohort | cohort | smaller cohort | reviewed cohort | off | Firebase on |

The financial agent route activates only when gateway, tool selection, and
financial explanation are all enabled. This prevents a partially enabled
two-phase turn from returning an incomplete response. Stage 2 tool selection is
validated with synthetic diagnostics and tests while the user-facing financial
route remains on Firebase.

## Rollback

The primary rollback is to disable `CASH_PILOT_AI_GROQ_GATEWAY_ENABLED`.
General and financial conversations then use the retained Firebase gateway
when Firebase is the selected provider. Financial commands remain local in
every stage, current information remains disabled, and receipt vision remains
on Firebase independently.

Rollback triggers include increased invalid responses, authentication or App
Check rejection anomalies, provider quota/unavailability, latency regression,
Arabic quality regression, unsupported financial figures, duplicate stream
chunks, privacy-policy violations, or any secret-handling concern.

Do not retry semantic, schema, safety, or grounding failures. Transport retry
is bounded and permitted only before general text is emitted. The server
performs at most one eligible transient model fallback; it never loops.

Stage advancement requires local automation, safe model availability,
synthetic staging acceptance, Arabic/English human review, receipt regression
checks, action-confirmation regression checks, and privacy/security sign-off.
