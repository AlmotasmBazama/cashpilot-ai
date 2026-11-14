import test from "node:test";
import assert from "node:assert/strict";
import {
  GroqClient,
  InvalidProviderResponseError,
  MissingGroqApiKeyError,
} from "../src/groq_client.ts";

test("environment key is required", () => {
  const previous = process.env.GROQ_API_KEY;
  delete process.env.GROQ_API_KEY;
  try {
    assert.throws(
      () => new GroqClient(),
      MissingGroqApiKeyError,
    );
  } finally {
    if (previous === undefined) {
      delete process.env.GROQ_API_KEY;
    } else {
      process.env.GROQ_API_KEY = previous;
    }
  }
});

test("429 Retry-After is honored with a bounded retry", async () => {
  let calls = 0;
  const sleeps: number[] = [];
  const client = new GroqClient({
    apiKey: "synthetic-test-secret",
    maxRetries: 1,
    sleep: async (milliseconds) => {
      sleeps.push(milliseconds);
    },
    fetchImpl: async (_input, init) => {
      calls++;
      const headers = new Headers(init?.headers);
      assert.equal(
        headers.get("Authorization"),
        "Bearer synthetic-test-secret",
      );
      if (calls === 1) {
        return new Response(
          JSON.stringify({
            error: { message: "Rate limit; retry shortly." },
          }),
          {
            status: 429,
            headers: { "Retry-After": "0" },
          },
        );
      }
      return completionResponse();
    },
  });
  const completion = await client.complete({
    model: "openai/gpt-oss-20b",
    messages: [{ role: "user", content: "Synthetic hello" }],
  });
  assert.equal(completion.content, "Synthetic response");
  assert.equal(calls, 2);
  assert.deepEqual(sleeps, [0]);
});

test("invalid provider response is rejected without persisting its body", async () => {
  const client = new GroqClient({
    apiKey: "synthetic-test-secret",
    maxRetries: 0,
    fetchImpl: async () =>
      new Response(JSON.stringify({ unexpected: true }), {
        status: 200,
      }),
  });
  await assert.rejects(
    () =>
      client.complete({
        model: "openai/gpt-oss-20b",
        messages: [{ role: "user", content: "Synthetic hello" }],
      }),
    InvalidProviderResponseError,
  );
});

function completionResponse(): Response {
  return new Response(
    JSON.stringify({
      choices: [
        {
          message: {
            content: "Synthetic response",
            tool_calls: [],
          },
        },
      ],
      usage: {
        prompt_tokens: 4,
        completion_tokens: 2,
      },
    }),
    { status: 200 },
  );
}
