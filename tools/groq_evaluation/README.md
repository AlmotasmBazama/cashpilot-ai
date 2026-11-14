# CashPilot Groq Evaluation Harness

This directory is an evaluation-only Node/TypeScript tool. It does not import, configure, or modify the CashPilot Flutter runtime.

It prepares 100 fictional prompts across general conversation, Arabic/Libyan financial language, financial guidance, structured actions, governed tool selection, current public information, and safety boundaries. The matrix expands to 280 exact model/case requests.

## Security

- The live key is read only from `process.env.GROQ_API_KEY`.
- Never pass the key as a command-line argument.
- Authorization and response headers are not logged.
- Reports are checked before writing and rejected if they contain the in-memory key.
- Every case must be marked synthetic and pass contact, credential, long-number, and local-path preflight checks.
- Compound Mini receives only public current-information prompts and is restricted to `web_search`.
- No financial tool is executed; tool calls are evaluated as inert structured output.

## Models

The harness queries `GET https://api.groq.com/openai/v1/models` and checks only these exact IDs:

- `openai/gpt-oss-120b`
- `qwen/qwen3.6-27b`
- `openai/gpt-oss-20b`
- `groq/compound-mini`

No substitution is performed when a model is unavailable.

## Commands

From the repository root:

```powershell
npm.cmd --prefix tools/groq_evaluation test
npm.cmd --prefix tools/groq_evaluation run prepare
npm.cmd --prefix tools/groq_evaluation run benchmark -- --resume
npm.cmd --prefix tools/groq_evaluation run benchmark -- --retry-failed
```

Limit one run while checking quota behavior:

```powershell
npm.cmd --prefix tools/groq_evaluation run benchmark -- --resume --max-requests=1
```

Optional pacing controls:

- `GROQ_EVAL_PAUSE_MS`: pause between sequential requests; default `1100`.
- `GROQ_EVAL_MAX_REQUESTS`: maximum requests for the current invocation.

The checkpoint is written after every request. A terminal daily quota response stops the run cleanly; the same benchmark command resumes remaining model/case pairs later.

`--retry-failed` preserves every original attempt, locally re-evaluates stored
HTTP-success responses affected by evaluator repairs, and sends only eligible
provider failures or empty-output failures back to Groq. Each replacement marks
the prior attempt as superseded without deleting it.

## Generated outputs

- `results/checkpoint.json`
- `results/summary.json`
- `results/objective_results.json`
- `results/manual_review.md`
- `../../docs/groq_model_evaluation.md`

Scores are provisional deterministic heuristics. Review the side-by-side answers manually before making any production model decision.

## API references

- [Groq OpenAI compatibility](https://console.groq.com/docs/openai)
- [Groq API reference](https://console.groq.com/docs/api-reference)
- [Compound built-in tools](https://console.groq.com/docs/compound/built-in-tools)
