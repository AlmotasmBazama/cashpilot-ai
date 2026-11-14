import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { test } from "node:test";
import type { Request, Response as ExpressResponse } from "express";
import request from "supertest";
import {
  fixedModels,
  gatewayServiceVersion,
  loadGatewayConfig,
  type GatewayConfig,
} from "../src/config.js";
import { GatewayFailure } from "../src/errors.js";
import {
  GroqChatCompletionsClient,
  type GroqCompletionRequest,
  type GroqTransport,
} from "../src/groq/groq_client.js";
import { withSingleTransientRetry } from "../src/groq/model_router.js";
import { createGatewayApp } from "../src/index.js";
import type {
  RequestVerifier,
  VerifiedPrincipal,
} from "../src/auth/request_verifier.js";
import { PerUserSlidingWindowRateLimiter } from "../src/security/rate_limit.js";
import { verifyGroqModels } from "../scripts/verify-groq-models.js";
import { boundedAbortController } from "../src/routes/shared.js";

class AcceptingVerifier implements RequestVerifier {
  async verify(_request: Request): Promise<VerifiedPrincipal> {
    return {
      uid: "completion-test-user",
      authTimeSeconds: 1,
      issuedAtSeconds: 1,
      signInProvider: "password",
      tenantIdentityPresent: false,
    };
  }
}

class CountingGroq implements GroqTransport {
  calls = 0;

  async complete(): Promise<string> {
    this.calls += 1;
    return "Safe response.";
  }

  async stream(
    _request: GroqCompletionRequest,
    onDelta: (delta: string) => void,
  ): Promise<void> {
    this.calls += 1;
    onDelta("Safe response.");
  }

  async availableModelIds(): Promise<ReadonlySet<string>> {
    this.calls += 1;
    return new Set(Object.values(fixedModels));
  }
}

function config(overrides: Partial<GatewayConfig> = {}): GatewayConfig {
  return {
    environment: "test",
    port: 8080,
    firebaseProjectId: "project",
    groqApiKey: "unit-test-placeholder",
    groqBaseUrl: "https://provider.invalid/v1",
    allowedOrigins: new Set<string>(),
    maxBodyBytes: 32 * 1024,
    maxRequestsPerMinute: 20,
    providerTimeoutMs: 2_000,
    maxStreamMs: 3_000,
    modelDiagnosticsEnabled: false,
    toolSelectionEnabled: false,
    supportedClientVersion: "1.0.0",
    ...overrides,
  };
}

function body(
  mode: "generalConversation" | "governedToolSelection" =
    "generalConversation",
): Record<string, unknown> {
  return {
    requestId: "completion_12345",
    mode,
    locale: "en",
    sanitizedMessages: [{ role: "user", content: "Explain this." }],
    ...(mode === "governedToolSelection"
      ? { allowedToolIds: ["get_dashboard_summary"] }
      : {}),
    timeoutClass: mode === "generalConversation" ? "interactive" : "analysis",
    clientVersion: "1.0.0",
  };
}

function appWith(
  gatewayConfig: GatewayConfig,
  groq: GroqTransport = new CountingGroq(),
) {
  return createGatewayApp({
    config: gatewayConfig,
    verifier: new AcceptingVerifier(),
    groq,
    rateLimiter: new PerUserSlidingWindowRateLimiter(20),
    safeStreamLog: () => undefined,
  });
}

test("CASH_PILOT_ENVIRONMENT and supported version drive safe health", async () => {
  const loaded = loadGatewayConfig({
    FIREBASE_PROJECT_ID: "private-project-value",
    GROQ_API_KEY: "",
    CASH_PILOT_ENVIRONMENT: "staging",
    CASH_PILOT_ALLOWED_ORIGINS: "https://allowed.example",
    CASH_PILOT_CLIENT_VERSION: "1.0.0",
  });
  assert.equal(loaded.environment, "staging");
  assert.equal(loaded.toolSelectionEnabled, false);

  const response = await request(appWith(loaded)).get("/health");
  assert.equal(response.status, 200);
  assert.equal(response.body.serviceVersion, gatewayServiceVersion);
  assert.equal(response.body.environment, "staging");
  assert.equal(response.body.supportedClientVersion, "1.0.0");
  assert.equal(response.body.readiness.ready, false);
  assert.equal(response.body.readiness.groq, "notConfigured");
  assert.doesNotMatch(response.text, /private-project-value/);
});

test("client version mismatch and disabled tool selection fail closed", async () => {
  const groq = new CountingGroq();
  const app = appWith(config(), groq);
  const mismatch = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send({ ...body(), clientVersion: "2.0.0" });
  assert.equal(mismatch.status, 400);
  assert.equal(mismatch.body.failure.code, "gatewayRequestInvalid");

  const disabled = await request(app)
    .post("/v1/ai/tool-selection")
    .set("Content-Type", "application/json")
    .send(body("governedToolSelection"));
  assert.equal(disabled.status, 503);
  assert.equal(disabled.body.failure.code, "gatewayUnavailable");
  assert.equal(groq.calls, 0);
});

test("deployment model verification prints safe IDs and fails missing models", async () => {
  const secret = "server-secret-marker";
  const lines: string[] = [];
  const missing = await verifyGroqModels({
    env: { GROQ_API_KEY: secret },
    fetcher: async () =>
      new Response(
        JSON.stringify({ data: [{ id: fixedModels.generalConversation }] }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    write: (line) => lines.push(line),
  });
  assert.equal(missing, false);
  assert.match(lines.join("\n"), /openai\/gpt-oss-20b: active/);
  assert.match(lines.join("\n"), /openai\/gpt-oss-120b: missing/);
  assert.doesNotMatch(lines.join("\n"), new RegExp(secret));

  const active = await verifyGroqModels({
    env: { GROQ_API_KEY: secret },
    fetcher: async () =>
      new Response(
        JSON.stringify({
          data: [
            { id: fixedModels.generalConversation },
            { id: fixedModels.financialExplanation },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    write: () => undefined,
  });
  assert.equal(active, true);
});

test("transient retry keeps one model and respects bounded Retry-After", async () => {
  const models: string[] = [];
  const delays: number[] = [];
  const result = await withSingleTransientRetry(
    "generalConversation",
    async (model, attempt) => {
      models.push(model);
      if (attempt === 0) {
        throw new GatewayFailure(
          "groqRateLimited",
          "rate limited",
          { retryAfterSeconds: 1 },
        );
      }
      return "ok";
    },
    {
      sleep: async (delayMs) => {
        delays.push(delayMs);
      },
    },
  );
  assert.equal(result.value, "ok");
  assert.equal(result.retryCount, 1);
  assert.deepEqual(models, [
    fixedModels.generalConversation,
    fixedModels.generalConversation,
  ]);
  assert.deepEqual(delays, [1_000]);

  let attempts = 0;
  await assert.rejects(
    withSingleTransientRetry(
      "generalConversation",
      async () => {
        attempts += 1;
        throw new GatewayFailure(
          "groqModelUnavailable",
          "model unavailable",
        );
      },
    ),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "groqModelUnavailable",
  );
  assert.equal(attempts, 1);
});

test("provider timeouts distinguish completion and stream", async () => {
  const fetcher: typeof fetch = async (_input, init) =>
    new Promise<Response>((_resolve, reject) => {
      const signal = init?.signal;
      if (signal === null || signal === undefined) {
        reject(new Error("missing signal"));
        return;
      }
      signal.addEventListener(
        "abort",
        () => reject(signal.reason),
        { once: true },
      );
    });
  const client = new GroqChatCompletionsClient(
    config({ providerTimeoutMs: 5 }),
    fetcher,
  );
  const requestValue: GroqCompletionRequest = {
    model: fixedModels.generalConversation,
    messages: [{ role: "user", content: "synthetic" }],
    maxOutputTokens: 10,
    temperature: 0,
  };
  await assert.rejects(
    client.complete(requestValue),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "groqRequestTimedOut",
  );
  await assert.rejects(
    client.stream(requestValue, () => undefined),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "groqStreamTimedOut",
  );
});

test("request and response disconnects cancel upstream work", () => {
  for (const source of ["request", "response"] as const) {
    const incoming = new EventEmitter();
    const outgoing = new EventEmitter();
    const bounded = boundedAbortController(
      incoming as unknown as Request,
      outgoing as unknown as ExpressResponse,
      2_000,
      "groqStreamTimedOut",
    );
    assert.equal(incoming.listenerCount("aborted"), 1, source);
    assert.equal(outgoing.listenerCount("close"), 1, source);
    if (source === "request") {
      incoming.emit("aborted");
    } else {
      outgoing.emit("close");
    }
    assert.equal(bounded.controller.signal.aborted, true, source);
    assert.ok(
      bounded.controller.signal.reason instanceof GatewayFailure,
      source,
    );
    assert.equal(
      bounded.controller.signal.reason.code,
      "gatewayUnavailable",
      source,
    );
    bounded.dispose();
    assert.equal(incoming.listenerCount("aborted"), 0, source);
    assert.equal(outgoing.listenerCount("close"), 0, source);
  }
});

test("disconnects during verification cancel upstream work before it starts", () => {
  for (const source of ["request", "response"] as const) {
    const incoming = Object.assign(new EventEmitter(), {
      aborted: source === "request",
    });
    const outgoing = Object.assign(new EventEmitter(), {
      destroyed: source === "response",
      writableEnded: false,
    });
    const bounded = boundedAbortController(
      incoming as unknown as Request,
      outgoing as unknown as ExpressResponse,
      2_000,
      "groqStreamTimedOut",
    );
    try {
      assert.equal(bounded.controller.signal.aborted, true, source);
      assert.equal(bounded.controller.signal.reason.code, "gatewayUnavailable");
    } finally {
      bounded.dispose();
    }
  }
});

test("rejected completion bodies cancel the upstream stream", async () => {
  for (const chunk of [
    new Uint8Array(512 * 1024 + 1),
    new Uint8Array([0xff]),
  ]) {
    let cancelled = false;
    const responseBody = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(chunk);
      },
      cancel() {
        cancelled = true;
      },
    });
    const client = new GroqChatCompletionsClient(
      config(),
      async () => new Response(responseBody),
    );
    await assert.rejects(
      client.complete({
        model: fixedModels.generalConversation,
        messages: [{ role: "user", content: "synthetic" }],
        maxOutputTokens: 10,
        temperature: 0,
      }),
      (error: unknown) =>
        error instanceof GatewayFailure &&
        error.code === "groqMalformedResponse",
    );
    assert.equal(cancelled, true);
    assert.equal(responseBody.locked, false);
  }
});

test("oversized SSE lines fail with a typed malformed response", async () => {
  const oversized = `data: ${"x".repeat(70 * 1024)}\n\n`;
  const client = new GroqChatCompletionsClient(
    config(),
    async () =>
      new Response(
        new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(new TextEncoder().encode(oversized));
            controller.close();
          },
        }),
        { status: 200 },
      ),
  );
  await assert.rejects(
    client.stream(
      {
        model: fixedModels.generalConversation,
        messages: [{ role: "user", content: "synthetic" }],
        maxOutputTokens: 10,
        temperature: 0,
      },
      () => undefined,
    ),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "groqMalformedResponse",
  );
});
