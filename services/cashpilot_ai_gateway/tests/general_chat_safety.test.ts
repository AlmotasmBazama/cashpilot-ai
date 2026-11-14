import assert from "node:assert/strict";
import { test } from "node:test";
import express, { type Request } from "express";
import request from "supertest";
import type {
  RequestVerifier,
  VerifiedPrincipal,
} from "../src/auth/request_verifier.js";
import type { GatewayConfig } from "../src/config.js";
import { GatewayFailure } from "../src/errors.js";
import type {
  GroqCompletionRequest,
  GroqStreamObserver,
  GroqTransport,
} from "../src/groq/groq_client.js";
import { generalChatRoute } from "../src/routes/general_chat.js";
import { PerUserSlidingWindowRateLimiter } from "../src/security/rate_limit.js";
import type { SafeStreamLogEntry } from "../src/security/safe_stream_trace.js";

class AcceptingVerifier implements RequestVerifier {
  async verify(_request: Request): Promise<VerifiedPrincipal> {
    return {
      uid: "general-chat-safety-user",
      authTimeSeconds: 1,
      issuedAtSeconds: 1,
      signInProvider: "password",
      tenantIdentityPresent: false,
    };
  }
}

class ChunkedGroq implements GroqTransport {
  constructor(
    readonly chunks: readonly string[],
    readonly failureAfterChunks?: GatewayFailure,
  ) {}

  readonly streamRequests: GroqCompletionRequest[] = [];

  async complete(): Promise<string> {
    throw new Error("complete is not used by general chat");
  }

  async stream(
    requestValue: GroqCompletionRequest,
    onDelta: (delta: string) => void,
    _signal?: AbortSignal,
    observer?: GroqStreamObserver,
  ): Promise<void> {
    this.streamRequests.push(requestValue);
    observer?.onHttpStatus("success");
    observer?.onChunk();
    for (const chunk of this.chunks) {
      onDelta(chunk);
    }
    if (this.failureAfterChunks !== undefined) {
      throw this.failureAfterChunks;
    }
  }

  async availableModelIds(): Promise<ReadonlySet<string>> {
    return new Set<string>();
  }
}

const config: GatewayConfig = {
  environment: "test",
  port: 8080,
  firebaseProjectId: "cashpilot-test",
  groqApiKey: "unit-test-placeholder",
  groqBaseUrl: "https://provider.invalid/v1",
  allowedOrigins: new Set<string>(),
  maxBodyBytes: 32 * 1024,
  maxRequestsPerMinute: 20,
  providerTimeoutMs: 2_000,
  maxStreamMs: 2_000,
  modelDiagnosticsEnabled: false,
  toolSelectionEnabled: false,
  supportedClientVersion: "test",
};

function generalRequest(): Record<string, unknown> {
  return {
    requestId: "general_chat_safety_123",
    mode: "generalConversation",
    locale: "en",
    sanitizedMessages: [
      { role: "user", content: "Tell me whether anything was changed." },
    ],
    timeoutClass: "interactive",
    clientVersion: "test",
  };
}

function harness(groq: ChunkedGroq) {
  const safeLogs: SafeStreamLogEntry[] = [];
  const app = express();
  app.use(express.json());
  app.post(
    "/v1/ai/general-chat",
    generalChatRoute({
      config,
      verifier: new AcceptingVerifier(),
      groq,
      rateLimiter: new PerUserSlidingWindowRateLimiter(20),
      safeStreamLog: (entry) => safeLogs.push(entry),
    }),
  );
  return { app, safeLogs };
}

test("general chat rejects a mutation claim assembled across provider chunks", async () => {
  const groq = new ChunkedGroq(["The expense ", "was sa", "ved."]);
  const { app, safeLogs } = harness(groq);

  const response = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send(generalRequest());

  assert.equal(response.status, 200);
  assert.match(response.text ?? "", /"type":"started"/u);
  assert.match(response.text ?? "", /"code":"groqMalformedResponse"/u);
  assert.doesNotMatch(response.text ?? "", /"type":"textDelta"/u);
  assert.doesNotMatch(response.text ?? "", /"type":"completed"/u);
  assert.equal(groq.streamRequests.length, 1);
  assert.equal(safeLogs.length, 1);
  assert.equal(safeLogs[0]?.requestId, "general_chat_safety_123");
  assert.equal(safeLogs[0]?.route, "/v1/ai/general-chat");
  assert.equal(safeLogs[0]?.selectedModelAlias, "general-primary");
  assert.equal(safeLogs[0]?.selectedModel, "openai/gpt-oss-20b");
  assert.equal(safeLogs[0]?.upstreamHttpStatusCategory, "success");
  assert.deepEqual(safeLogs[0]?.upstreamAttemptStatusCategories, ["success"]);
  assert.equal(safeLogs[0]?.upstreamChunks, 1);
  assert.deepEqual(safeLogs[0]?.normalizedSseEventTypes, [
    "started",
    "failure",
  ]);
  assert.equal(safeLogs[0]?.finalCode, "groqMalformedResponse");
  assert.equal(safeLogs[0]?.typedErrorCode, "groqMalformedResponse");
  assert.equal(safeLogs[0]?.statusCode, 502);
  assert.equal(safeLogs[0]?.retryCount, 0);
});

test("general chat never retries after emitting a downstream text delta", async () => {
  const groq = new ChunkedGroq(
    ["A safe streamed prefix. ".repeat(20)],
    new GatewayFailure(
      "groqUpstreamUnavailable",
      "The provider stopped after a delta.",
    ),
  );
  const { app, safeLogs } = harness(groq);

  const response = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send(generalRequest());

  assert.equal(groq.streamRequests.length, 1);
  assert.match(response.text ?? "", /"code":"groqUpstreamUnavailable"/u);
  assert.doesNotMatch(response.text ?? "", /transientUpstreamRetry/u);
  assert.match(response.text ?? "", /"type":"textDelta"/u);
  assert.doesNotMatch(response.text ?? "", /"type":"completed"/u);
  assert.deepEqual(safeLogs[0]?.normalizedSseEventTypes, [
    "started",
    "textDelta",
    "failure",
  ]);
  assert.equal(safeLogs[0]?.finalCode, "groqUpstreamUnavailable");
});
