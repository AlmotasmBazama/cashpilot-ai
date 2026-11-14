# Groq Gateway Architecture

## Provider boundary audit

Before this migration, Firebase Gemini was invoked from three distinct data
boundaries:

1. `FirebaseAiAgentModelGateway` handled general conversation, personal
   financial analysis, governed functions, and grounded Google Search.
2. `FirebaseAiProviderDataSource` supported the older repository-based
   assistant route.
3. `FirebaseReceiptAnalysisProvider` handled receipt and invoice vision.

The assistant screen already separated financial commands from conversational
model turns. Financial commands continue through the local intent router,
deterministic parser, entity/category/account resolution, validator, typed
draft, explicit confirmation, existing use case, and idempotent executor.
Neither Firebase nor Groq is the authority for that path.

## Components

The Flutter domain owns the provider-neutral `AiConversationGateway` contract.
It exposes general streaming, guarded financial explanation, governed tool
selection, a reachability check, typed events, and typed failures. Domain and
application code do not import provider SDK or HTTP response types.

The Flutter data layer obtains fresh Firebase Authentication and App Check
tokens, creates exact gateway requests, parses CashPilot SSE events, and maps
safe failures. The routed agent gateway selects Firebase or the new gateway
from centralized capability flags. Firebase remains available for rollback.

The gateway is stateless. Its public surface contains only CashPilot-specific
routes. It verifies callers, applies limits, selects a fixed server-side model,
uses fixed system instructions, and emits normalized events. It never receives
an executable financial draft and cannot execute a local tool.

## Capability routing

| Capability | Route |
|---|---|
| General conversation | Gateway general endpoint when enabled; Firebase rollback otherwise |
| Arabic/Libyan conversation | Same general endpoint; Arabic specialist flag gates guarded financial turns |
| Personal financial explanation | Gateway financial endpoint after local read/calculation tools produce bounded facts |
| Governed tool selection | Gateway selection endpoint; execution remains in Flutter |
| Financial command extraction | Deterministic local CashPilot path only |
| Current information | Disabled; no gateway web route exists |
| Receipt vision | Existing Firebase Gemini receipt provider |

The gateway fixes general and tool selection to `openai/gpt-oss-20b` and fixes
financial explanation to `openai/gpt-oss-120b`. An eligible transient provider
failure can receive one bounded retry on the same fixed model, and only before
output. Semantic, schema, grounding, and safety failures are not retried as a
different model.

## Streaming

General responses are forwarded as incremental, ordered CashPilot SSE events:
`started`, `textDelta`, optional safe `warning`, and `completed` or `failure`.
Upstream event bodies and headers are never exposed. A retry is permitted only
before content is emitted, preventing duplicate chunks. Disconnect and
duration abort signals terminate upstream work.

Financial text is buffered server-side for figure grounding and a maximum of
one same-model correction before safe chunks are emitted. This deliberately
trades first-token latency for the financial grounding invariant.
