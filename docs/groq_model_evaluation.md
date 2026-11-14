# CashPilot AI — Controlled Groq Model Evaluation

Status: repair_complete. This evaluation is isolated from the Flutter production runtime. Scores are deterministic heuristics, not scientific certainty.

Methodology uses Groq's official OpenAI-compatible endpoint and exact requested model IDs. Compound Mini is restricted to public web search. All financial prompts and context are fictional.

## Benchmark repair diagnostics

- FIN: the original requests returned HTTP 2xx. False negatives came from literal number matching that missed grouped digits and from treating derived arithmetic as fabricated. Qwen also produced empty 2xx content under the original reasoning/token budget.
- ACT: the original run used best-effort JSON Object mode for every model. Intermittent GPT 400s and universal Qwen 400s were generated-output/request-mode failures, not local schema-keyword rejection. GPT retries now use strict JSON Schema; Qwen uses JSON Object mode with reasoning disabled.
- CUR: the original Compound requests were over-specified with base-model sampling/output options. Retries now use the documented minimal Compound payload and web_search only.
- Failed cases repaired or retried so far: 133

Sanitized provider diagnostics:

- count=1; code=tool_use_failed; parameter=none; failed_generation=true; message=tool call validation failed: parameters for tool calculateSavingsRate did not match schema: errors: [`/expense`: expected string, but got number, `/income`: expected string, but got number]
- count=1; code=tool_use_failed; parameter=none; failed_generation=true; message=tool call validation failed: parameters for tool simulateBudgetChange did not match schema: errors: [`/currentLimit`: expected string, but got number, `/newLimit`: expected string, but got number]
- count=1; code=tool_use_failed; parameter=none; failed_generation=true; message=tool call validation failed: parameters for tool createBudgetDraft did not match schema: errors: [`/limit`: expected string, but got number, `/requiresConfirmation`: expected boolean, but got string]
- count=1; code=rate_limit_exceeded; parameter=none; failed_generation=false; message=Rate limit reached for model `openai/gpt-oss-120b` in organization `org_01kyjhx6msewqr710zde90z0mb` service tier `on_demand` on tokens per minute (TPM): Limit 8000, Used 4873, Requested 3679. Please try again in 4.14s. Need more tokens? Upgrade to Dev Tier today at https://console.groq.com/settings/billing
- count=1; code=rate_limit_exceeded; parameter=none; failed_generation=false; message=Rate limit reached for model `openai/gpt-oss-120b` in organization `org_01kyjhx6msewqr710zde90z0mb` service tier `on_demand` on tokens per minute (TPM): Limit 8000, Used 6309, Requested 7122. Please try again in 40.7325s. Need more tokens? Upgrade to Dev Tier today at https://console.groq.com/settings/billing
- count=1; code=rate_limit_exceeded; parameter=none; failed_generation=false; message=Rate limit reached for model `openai/gpt-oss-120b` in organization `org_01kyjhx6msewqr710zde90z0mb` service tier `on_demand` on tokens per minute (TPM): Limit 8000, Used 4524, Requested 5770. Please try again in 17.205s. Need more tokens? Upgrade to Dev Tier today at https://console.groq.com/settings/billing
- count=1; code=rate_limit_exceeded; parameter=none; failed_generation=false; message=Rate limit reached for model `openai/gpt-oss-120b` in organization `org_01kyjhx6msewqr710zde90z0mb` service tier `on_demand` on tokens per minute (TPM): Limit 8000, Used 4777, Requested 3656. Please try again in 3.2475s. Need more tokens? Upgrade to Dev Tier today at https://console.groq.com/settings/billing
- count=1; code=request_too_large; parameter=none; failed_generation=false; message=Request Entity Too Large

## 1. Models tested

- openai/gpt-oss-120b
- qwen/qwen3.6-27b
- openai/gpt-oss-20b
- groq/compound-mini

## 2. Models unavailable

None of the requested models were marked unavailable by discovery.

## 3. Number of prompts completed

- Synthetic prompts prepared: 100
- Planned model requests: 280
- Completed model requests: 280
- Total auditable attempts: 413
- Provider retry attempts: 93
- Evaluator-only repair attempts: 40
- Superseded attempts retained: 133
- Remaining model requests: 0

## 4. Rate limits encountered

- Rate-limited requests: 4
- Timeouts: 0
- Stop reason: repair_complete

## 5. General conversation winner

openai/gpt-oss-20b

## 6. Arabic/Libyan winner

openai/gpt-oss-120b

## 7. Financial-analysis winner

openai/gpt-oss-120b

## 8. Structured-action winner

qwen/qwen3.6-27b

## 9. Tool-calling winner

openai/gpt-oss-20b

## 10. Current-information result

groq/compound-mini

## 11. Latency comparison

- openai/gpt-oss-120b / arabic_libyan_financial: 722 ms median
- openai/gpt-oss-20b / arabic_libyan_financial: 515 ms median
- qwen/qwen3.6-27b / arabic_libyan_financial: 1337 ms median
- groq/compound-mini / current_information: 8692 ms median
- openai/gpt-oss-120b / financial_analysis: 1628 ms median
- openai/gpt-oss-20b / financial_analysis: 1037 ms median
- qwen/qwen3.6-27b / financial_analysis: 12874 ms median
- openai/gpt-oss-120b / general_conversation: 634 ms median
- openai/gpt-oss-20b / general_conversation: 464 ms median
- qwen/qwen3.6-27b / general_conversation: 1102 ms median
- openai/gpt-oss-120b / governed_tool: 618 ms median
- openai/gpt-oss-20b / governed_tool: 519 ms median
- qwen/qwen3.6-27b / governed_tool: 1053 ms median
- openai/gpt-oss-120b / safety_boundary: 555 ms median
- openai/gpt-oss-20b / safety_boundary: 500 ms median
- qwen/qwen3.6-27b / safety_boundary: 1157 ms median
- openai/gpt-oss-120b / structured_action: 849 ms median
- openai/gpt-oss-20b / structured_action: 557 ms median
- qwen/qwen3.6-27b / structured_action: 508 ms median

## 12. Reliability comparison

- openai/gpt-oss-120b / arabic_libyan_financial: 90.00% (20 requests)
- openai/gpt-oss-20b / arabic_libyan_financial: 90.00% (20 requests)
- qwen/qwen3.6-27b / arabic_libyan_financial: 65.00% (20 requests)
- groq/compound-mini / current_information: 30.00% (10 requests)
- openai/gpt-oss-120b / financial_analysis: 53.33% (15 requests)
- openai/gpt-oss-20b / financial_analysis: 46.67% (15 requests)
- qwen/qwen3.6-27b / financial_analysis: 33.33% (15 requests)
- openai/gpt-oss-120b / general_conversation: 100.00% (15 requests)
- openai/gpt-oss-20b / general_conversation: 100.00% (15 requests)
- qwen/qwen3.6-27b / general_conversation: 93.33% (15 requests)
- openai/gpt-oss-120b / governed_tool: 93.33% (15 requests)
- openai/gpt-oss-20b / governed_tool: 100.00% (15 requests)
- qwen/qwen3.6-27b / governed_tool: 73.33% (15 requests)
- openai/gpt-oss-120b / safety_boundary: 100.00% (5 requests)
- openai/gpt-oss-20b / safety_boundary: 100.00% (5 requests)
- qwen/qwen3.6-27b / safety_boundary: 100.00% (5 requests)
- openai/gpt-oss-120b / structured_action: 25.00% (20 requests)
- openai/gpt-oss-20b / structured_action: 35.00% (20 requests)
- qwen/qwen3.6-27b / structured_action: 25.00% (20 requests)

## 13. Privacy/security observations

- The API key is read only from the process environment.
- Authorization and response headers are never logged or persisted.
- Reports are rejected if they contain the exact in-memory key.
- Only prompts marked synthetic pass preflight validation.
- No Firebase UID, authentication token, App Check token, contact detail, real balance, transaction, receipt, or local file path is included in provider requests.
- Compound Mini receives public current-information prompts only and no CashPilot financial context.

## 14. Recommended primary model

openai/gpt-oss-120b

## 15. Recommended Arabic fallback

openai/gpt-oss-120b

## 16. Recommended extraction model

qwen/qwen3.6-27b

## 17. Recommended current-information model

groq/compound-mini

## 18. Models not recommended

None based on the completed sample.

## 19. Production risks

- Live quality, quota, preview-model stability, latency, and structured-output consistency must be reviewed before integration.
- Model availability is account-specific and may change.
- Compound search must never receive private CashPilot context.
- Tool calls must remain locally validated and writes must remain review-only drafts with explicit confirmation.
- Receipt vision was intentionally not evaluated in this text-only sprint.

## 20. Proposed CashPilot routing table

- General conversation: openai/gpt-oss-20b
- Arabic/Libyan conversation: openai/gpt-oss-120b
- Personal financial analysis: openai/gpt-oss-120b
- Structured action extraction: qwen/qwen3.6-27b
- Current web information: groq/compound-mini
- Fast fallback: openai/gpt-oss-20b
- Receipt vision: Existing Firebase Gemini receipt path (not evaluated; no production change)
- Final local fallback: Existing deterministic CashPilot parser and governed local tools

## Objective score summary

| Model | Category | Score / 100 | Success rate | Median latency (ms) |
|---|---|---:|---:|---:|
| openai/gpt-oss-120b | arabic_libyan_financial | 97.00 | 90.00% | 722 |
| openai/gpt-oss-20b | arabic_libyan_financial | 96.99 | 90.00% | 515 |
| qwen/qwen3.6-27b | arabic_libyan_financial | 89.45 | 65.00% | 1337 |
| groq/compound-mini | current_information | 45.13 | 30.00% | 8692 |
| openai/gpt-oss-120b | financial_analysis | 82.33 | 53.33% | 1628 |
| openai/gpt-oss-20b | financial_analysis | 77.33 | 46.67% | 1037 |
| qwen/qwen3.6-27b | financial_analysis | 56.00 | 33.33% | 12874 |
| openai/gpt-oss-120b | general_conversation | 99.99 | 100.00% | 634 |
| openai/gpt-oss-20b | general_conversation | 100.00 | 100.00% | 464 |
| qwen/qwen3.6-27b | general_conversation | 97.94 | 93.33% | 1102 |
| openai/gpt-oss-120b | governed_tool | 96.00 | 93.33% | 618 |
| openai/gpt-oss-20b | governed_tool | 100.00 | 100.00% | 519 |
| qwen/qwen3.6-27b | governed_tool | 76.00 | 73.33% | 1053 |
| openai/gpt-oss-120b | safety_boundary | 100.00 | 100.00% | 555 |
| openai/gpt-oss-20b | safety_boundary | 100.00 | 100.00% | 500 |
| qwen/qwen3.6-27b | safety_boundary | 99.97 | 100.00% | 1157 |
| openai/gpt-oss-120b | structured_action | 71.88 | 25.00% | 849 |
| openai/gpt-oss-20b | structured_action | 76.50 | 35.00% | 557 |
| qwen/qwen3.6-27b | structured_action | 77.75 | 25.00% | 508 |

Scores are provisional deterministic heuristics over objective flags and are not scientific or a substitute for the manual-review notes.

## Resume command

`npm.cmd --prefix tools/groq_evaluation run benchmark -- --resume`
