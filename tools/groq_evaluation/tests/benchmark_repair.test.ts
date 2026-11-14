import test from "node:test";
import assert from "node:assert/strict";
import {
  ACTION_RESPONSE_SCHEMA,
  buildCompletionRequest,
  evaluateCompletion,
  failureResult,
  retryFailedEvaluations,
} from "../src/evaluators.ts";
import {
  GroqClient,
  ProviderRequestError,
} from "../src/groq_client.ts";
import { PROMPT_MATRIX } from "../src/prompt_matrix.ts";

test("GPT structured actions use Groq strict JSON Schema subset", () => {
  const testCase = caseById("ACT-001");
  const request = buildCompletionRequest(
    testCase,
    "openai/gpt-oss-120b",
  );
  assert.equal(request.responseFormat?.type, "json_schema");
  if (request.responseFormat?.type !== "json_schema") {
    assert.fail("Expected JSON Schema mode.");
  }
  assert.equal(request.responseFormat.json_schema.strict, true);
  assert.deepEqual(
    request.responseFormat.json_schema.schema,
    ACTION_RESPONSE_SCHEMA,
  );
  assert.equal(
    Object.hasOwn(
      request.responseFormat.json_schema.schema,
      "pattern",
    ),
    false,
  );
  const schema = request.responseFormat.json_schema.schema as any;
  assert.equal(schema.additionalProperties, false);
  assert.deepEqual(
    [...schema.required].sort(),
    Object.keys(schema.properties).sort(),
  );
});

test("Qwen structured actions use JSON Object mode and non-thinking output", () => {
  const request = buildCompletionRequest(
    caseById("ACT-001"),
    "qwen/qwen3.6-27b",
  );
  assert.deepEqual(request.responseFormat, { type: "json_object" });
  assert.equal(request.reasoningEffort, "none");
});

test("Compound Mini payload contains only supported web-search fields", async () => {
  let captured: Record<string, unknown> | null = null;
  const client = new GroqClient({
    apiKey: "synthetic-compound-secret",
    fetchImpl: async (_input, init) => {
      captured = JSON.parse(String(init?.body));
      return completionResponse("Current synthetic answer [Source](https://example.com)");
    },
  });
  const completion = await client.complete(
    buildCompletionRequest(
      caseById("CUR-001"),
      "groq/compound-mini",
    ),
  );
  assert.ok(captured);
  assert.deepEqual(Object.keys(captured!).sort(), [
    "compound_custom",
    "messages",
    "model",
  ]);
  assert.deepEqual(captured!.compound_custom, {
    tools: { enabled_tools: ["web_search"] },
  });
  assert.equal(completion.sourceSearchMetadataPresent, true);
  assert.equal(completion.sourceCount, 1);
});

test("financial evaluator accepts grouped and derived factual figures", () => {
  const testCase = caseById("FIN-011");
  const answer =
    "Based on the supplied figures, income is 2 500 LYD and expenses are " +
    "2 100 LYD, leaving a derived 400 LYD surplus. Expenses rose by 300 LYD " +
    "from 1 800 LYD. Food is 430 of 500 LYD, leaving 70 LYD. " +
    "This assumes all expenses are included; track restaurants and reduce their limit if needed.";
  const result = evaluateCompletion(
    testCase,
    "openai/gpt-oss-120b",
    {
      content: answer,
      toolCalls: [],
      executedTools: [],
      usage: { inputTokens: 100, outputTokens: 100 },
      latencyFirstMs: null,
      latencyTotalMs: 500,
      httpStatusCategory: "2xx",
      sourceSearchMetadataPresent: false,
      finishReason: "stop",
    },
  );
  assert.equal(result.flags.factsUsed, true);
  assert.equal(result.flags.noFabricatedFigures, true);
  assert.equal(result.success, true);
});

test("failed-only retry selects provider and evaluator defects, not quality failures", () => {
  const badRequestCase = caseById("ACT-001");
  const financialCase = caseById("FIN-011");
  const qualityCase = caseById("GEN-005");
  const blankQwenCase = caseById("GEN-001");
  const badRequest = failureResult(
    badRequestCase,
    "openai/gpt-oss-120b",
    new ProviderRequestError({
      status: 400,
      statusCategory: "bad_request",
    }),
  );
  const financial = evaluateCompletion(
    financialCase,
    "openai/gpt-oss-120b",
    plainCompletion("A nonempty but previously mis-scored analysis."),
  );
  const quality = evaluateCompletion(
    qualityCase,
    "openai/gpt-oss-120b",
    plainCompletion("Unrelated answer"),
  );
  const blank = evaluateCompletion(
    blankQwenCase,
    "qwen/qwen3.6-27b",
    plainCompletion("", "length"),
  );
  const candidates = retryFailedEvaluations(PROMPT_MATRIX, [
    badRequest,
    financial,
    quality,
    blank,
  ]);
  assert.deepEqual(
    candidates.map((item) => [
      item.testCase.id,
      item.strategy,
    ]),
    [
      ["ACT-001", "provider_retry"],
      ["FIN-011", "evaluator_repair"],
      ["GEN-001", "provider_retry"],
    ],
  );
});

test("sanitized provider diagnostics never retain the API key", async () => {
  const secret = "synthetic-diagnostic-secret-value";
  const client = new GroqClient({
    apiKey: secret,
    maxRetries: 0,
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          error: {
            code: "invalid_request_error",
            param: "response_format",
            message: `Invalid schema; authorization Bearer ${secret}`,
            failed_generation: { synthetic: true },
          },
        }),
        { status: 400 },
      ),
  });
  await assert.rejects(
    () =>
      client.complete(
        buildCompletionRequest(
          caseById("ACT-001"),
          "openai/gpt-oss-120b",
        ),
      ),
    (error: unknown) => {
      assert.ok(error instanceof ProviderRequestError);
      assert.equal(
        JSON.stringify(error.diagnostic).includes(secret),
        false,
      );
      assert.equal(error.diagnostic.parameter, "response_format");
      assert.equal(error.diagnostic.failedGenerationPresent, true);
      return true;
    },
  );
});

function caseById(id: string) {
  return PROMPT_MATRIX.find((item) => item.id === id)!;
}

function plainCompletion(content: string, finishReason = "stop") {
  return {
    content,
    toolCalls: [],
    executedTools: [],
    usage: { inputTokens: 10, outputTokens: 10 },
    latencyFirstMs: null,
    latencyTotalMs: 100,
    httpStatusCategory: "2xx",
    sourceSearchMetadataPresent: false,
    finishReason,
  };
}

function completionResponse(content: string): Response {
  return new Response(
    JSON.stringify({
      choices: [
        {
          message: {
            content,
            executed_tools: [
              {
                search_results: [
                  { url: "https://example.com", title: "Source" },
                ],
              },
            ],
          },
          finish_reason: "stop",
        },
      ],
      usage: { prompt_tokens: 10, completion_tokens: 10 },
    }),
    { status: 200 },
  );
}
