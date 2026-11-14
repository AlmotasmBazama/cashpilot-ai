import assert from "node:assert/strict";
import { test } from "node:test";
import { GatewayFailure } from "../src/errors.js";
import {
  parseAvailableModelIds,
  parseCompletionContent,
  parseProviderStreamEvent,
} from "../src/groq/groq_response_contracts.js";

test("completion parsing retains the exact first textual choice", () => {
  assert.equal(
    parseCompletionContent(
      JSON.stringify({
        ignored: true,
        choices: [
          { message: { content: " exact answer ", ignored: true } },
          { message: { content: "second" } },
        ],
      }),
    ),
    " exact answer ",
  );
});

test("completion parsing preserves malformed and empty failure messages", () => {
  assert.throws(
    () => parseCompletionContent("{"),
    (error) =>
      error instanceof GatewayFailure &&
      error.code === "groqMalformedResponse" &&
      error.message === "Groq returned malformed JSON.",
  );
  assert.throws(
    () => parseCompletionContent(JSON.stringify({ choices: [] })),
    (error) =>
      error instanceof GatewayFailure &&
      error.code === "groqMalformedResponse" &&
      error.message === "Groq returned an empty or oversized completion.",
  );
});

test("model parsing retains valid IDs and ignores malformed entries", () => {
  assert.deepEqual(
    [...parseAvailableModelIds(
      JSON.stringify({
        data: [{ id: "model-a" }, null, { id: 7 }, { id: "model-b" }],
      }),
    )],
    ["model-a", "model-b"],
  );
});

test("model parsing preserves malformed metadata failures", () => {
  assert.throws(
    () => parseAvailableModelIds("[]"),
    (error) =>
      error instanceof GatewayFailure &&
      error.message === "Groq returned invalid model metadata.",
  );
});

test("stream parsing preserves done, empty, and textual delta states", () => {
  assert.deepEqual(parseProviderStreamEvent(" [DONE] "), {
    done: true,
    delta: "",
  });
  assert.deepEqual(parseProviderStreamEvent("{}"), {
    done: false,
    delta: "",
  });
  assert.deepEqual(
    parseProviderStreamEvent(
      JSON.stringify({ choices: [{ delta: { content: "chunk" } }] }),
    ),
    { done: false, delta: "chunk" },
  );
});

test("stream parsing preserves malformed choices and content failures", () => {
  assert.throws(
    () => parseProviderStreamEvent(JSON.stringify({ choices: {} })),
    (error) =>
      error instanceof GatewayFailure &&
      error.message === "The Groq stream contained malformed choices.",
  );
  assert.throws(
    () =>
      parseProviderStreamEvent(
        JSON.stringify({ choices: [{ delta: { content: 7 } }] }),
      ),
    (error) =>
      error instanceof GatewayFailure &&
      error.message ===
        "The Groq stream contained malformed text content.",
  );
});

test("stream parsing preserves provider failure classification", () => {
  assert.throws(
    () =>
      parseProviderStreamEvent(
        JSON.stringify({ error: { code: "rate_limit_exceeded" } }),
      ),
    (error) =>
      error instanceof GatewayFailure && error.code === "groqRateLimited",
  );
  assert.throws(
    () =>
      parseProviderStreamEvent(
        JSON.stringify({ error: { type: "authentication_error" } }),
      ),
    (error) =>
      error instanceof GatewayFailure &&
      error.code === "groqAuthenticationFailed",
  );
});
