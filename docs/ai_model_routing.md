# AI assistant and model routing

`AiIntentRouter` is the single pre-route for every assistant message. It emits
one of these targets before any model or tool is selected:

- `directConversation`: greetings, small talk, help, and capabilities answered
  locally.
- `generalConversation`: safe general knowledge with no CashPilot tools.
- `groundedCurrentKnowledge`: current public knowledge with Firebase AI Logic
  Google Search grounding, no CashPilot tools, and no private memory context.
- `personalFinancialAnalysis`: relevant, allowlisted read-only CashPilot tools.
- `financialAction`: the deterministic typed draft and confirmation controller.
- `receiptAction`: the receipt review workflow.
- `blocked`: destructive, secret-seeking, or unsafe requests refused locally.

The SDK-independent model tasks are `localConversation`,
`generalConversation`, `groundedCurrentKnowledge`,
`financialCommandExtraction`, `personalFinancialAnalysis`,
`complexFinancialPlanning`, and `receiptAnalysis`.

Model IDs are centralized in `AiModelConfig`. General conversation, grounded
current knowledge, personal analysis, and complex planning default to
`gemini-3.6-flash`. Deterministic extraction and lightweight fallbacks use
`gemini-3.1-flash-lite`. Deployments can override each task model with
`--dart-define`; no API key or second provider is introduced.

General and grounded routes use Firebase `startChat` and
`sendMessageStream`. Their chat sessions persist across turns and reset on New
conversation or Clear conversation. Personal finance follow-ups additionally
retain only bounded, sanitized CashPilot context. A Search-grounded request
always receives an empty private-memory context.

Google Search grounding is enabled only for `groundedCurrentKnowledge`.
Grounded answers are accepted only when the SDK returns answer text and
validated HTTP(S) sources. The UI then renders source links, response date, and
the SDK-provided Google Search entry-point HTML. If grounding metadata is
missing, the assistant reports that current information is unavailable instead
of presenting model memory as current fact.

Tool declarations are minimized before every model call. General, grounded,
greeting, action, and receipt routes receive zero financial declarations.
Personal analysis receives only the read/calculation tools relevant to the
message and active topic, and every requested call is checked again locally.

Model changes require staging validation for function calling, streaming,
latency, cost, App Check behavior, Search grounding, safety, Arabic/English
quality, and all live smoke tests.
