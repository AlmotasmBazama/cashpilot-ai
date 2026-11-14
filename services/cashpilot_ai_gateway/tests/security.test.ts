import assert from "node:assert/strict";
import { test } from "node:test";
import type { Request } from "express";
import request from "supertest";
import type {
  RequestVerifier,
  VerifiedPrincipal,
} from "../src/auth/request_verifier.js";
import type { GatewayConfig } from "../src/config.js";
import type { AiGatewayRequest } from "../src/contracts/gateway.js";
import { GatewayFailure } from "../src/errors.js";
import type {
  GroqCompletionRequest,
  GroqTransport,
} from "../src/groq/groq_client.js";
import { createGatewayApp } from "../src/index.js";
import { PerUserSlidingWindowRateLimiter } from "../src/security/rate_limit.js";
import { assertRequestIsMinimized } from "../src/security/redaction.js";

class AcceptingVerifier implements RequestVerifier {
  async verify(_request: Request): Promise<VerifiedPrincipal> {
    return {
      uid: "verified",
      authTimeSeconds: Math.floor(Date.now() / 1000),
      issuedAtSeconds: Math.floor(Date.now() / 1000),
      signInProvider: "password",
      tenantIdentityPresent: false,
    };
  }
}

class CountingGroq implements GroqTransport {
  calls = 0;
  async complete(_request: GroqCompletionRequest): Promise<string> {
    this.calls += 1;
    return '{"toolSelections":[],"clarification":null}';
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
    return new Set();
  }
}

const config: GatewayConfig = {
  environment: "test",
  port: 8080,
  firebaseProjectId: "project",
  groqApiKey: "unit-test-placeholder",
  groqBaseUrl: "https://provider.invalid/v1",
  allowedOrigins: new Set(["https://allowed.example"]),
  maxBodyBytes: 1_024,
  maxRequestsPerMinute: 20,
  providerTimeoutMs: 2_000,
  maxStreamMs: 2_000,
  modelDiagnosticsEnabled: false,
  toolSelectionEnabled: false,
  supportedClientVersion: "test",
};

function appAndGroq() {
  const groq = new CountingGroq();
  return {
    groq,
    app: createGatewayApp({
      config,
      verifier: new AcceptingVerifier(),
      groq,
      rateLimiter: new PerUserSlidingWindowRateLimiter(20),
      safeStreamLog: () => undefined,
    }),
  };
}

function body(content = "Hello"): Record<string, unknown> {
  return {
    requestId: "security_12345",
    mode: "generalConversation",
    locale: "en",
    sanitizedMessages: [{ role: "user", content }],
    timeoutClass: "interactive",
    clientVersion: "test",
  };
}

test("CORS permits only exact configured origins", async () => {
  const { app } = appAndGroq();
  const blocked = await request(app)
    .post("/v1/ai/general-chat")
    .set("Origin", "https://evil.example")
    .set("Content-Type", "application/json")
    .send(body());
  assert.equal(blocked.status, 403);
  assert.equal(blocked.headers["access-control-allow-origin"], undefined);

  const allowed = await request(app)
    .post("/v1/ai/general-chat")
    .set("Origin", "https://allowed.example")
    .set("Content-Type", "application/json")
    .send(body());
  assert.equal(allowed.status, 200);
  assert.equal(
    allowed.headers["access-control-allow-origin"],
    "https://allowed.example",
  );

  const preflight = await request(app)
    .options("/v1/account-deletion/auth")
    .set("Origin", "https://allowed.example")
    .set(
      "Access-Control-Request-Headers",
      "X-Cashpilot-Deletion-Session",
    );
  assert.equal(preflight.status, 204);
  assert.match(
    preflight.headers["access-control-allow-headers"] ?? "",
    /X-Cashpilot-Deletion-Session/,
  );
});

test("non-JSON and oversized bodies are rejected before provider use", async () => {
  const { app, groq } = appAndGroq();
  const wrongType = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "text/plain")
    .send("hello");
  assert.equal(wrongType.status, 415);

  const oversized = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send(body("a".repeat(2_000)));
  assert.equal(oversized.status, 413);
  assert.equal(groq.calls, 0);
});

test("message count and message length limits are exact", async () => {
  const { app, groq } = appAndGroq();
  const tooMany = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send({
      ...body(),
      sanitizedMessages: Array.from({ length: 9 }, () => ({
        role: "user",
        content: "bounded",
      })),
    });
  assert.equal(tooMany.status, 400);
  assert.equal(groq.calls, 0);
});

test("credential-like and private data are rejected", async () => {
  const { app, groq } = appAndGroq();
  for (const content of [
    "Contact me at person@example.com",
    "Bearer credential-value",
    "Read C:\\Users\\person\\private.txt",
  ]) {
    const response = await request(app)
      .post("/v1/ai/general-chat")
      .set("Content-Type", "application/json")
      .send(body(content));
    assert.equal(response.status, 422);
  }
  assert.equal(groq.calls, 0);
});

test("phone-like prompts and memory context are rejected without echo", async () => {
  const { app, groq } = appAndGroq();
  const cases = [
    {
      sensitive: "0912345678",
      payload: body("Call me at 0912345678"),
    },
    {
      sensitive: "+218 91 234 5678",
      payload: {
        ...body("Continue our general discussion."),
        compactMemorySummary: "Contact: +218 91 234 5678",
      },
    },
    {
      sensitive: "٠٩١٢٣٤٥٦٧٨",
      payload: body("رقم التواصل ٠٩١٢٣٤٥٦٧٨"),
    },
  ];

  for (const item of cases) {
    const response = await request(app)
      .post("/v1/ai/general-chat")
      .set("Content-Type", "application/json")
      .send(item.payload);
    assert.equal(response.status, 422);
    assert.equal(response.text.includes(item.sensitive), false);
  }
  assert.equal(groq.calls, 0);
});

test("phone-shaped UUID metadata passes while identical message text fails", async () => {
  const phoneShapedUuid = "01989f80-4e00-7000-8000-000000000001";
  const { app, groq } = appAndGroq();
  const accepted = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send({ ...body(), requestId: phoneShapedUuid });
  assert.equal(accepted.status, 200);
  assert.equal(groq.calls, 1);

  const rejected = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send(body(`Reference ${phoneShapedUuid}`));
  assert.equal(rejected.status, 422);
  assert.equal(rejected.text.includes(phoneShapedUuid), false);
  assert.equal(groq.calls, 1);
});

test("path-aware text scanning still rejects forbidden nested keys", () => {
  const requestValue = {
    ...body(),
    sanitizedMessages: [
      {
        role: "user",
        content: "Safe content.",
        metadata: { token: "synthetic-test-value" },
      },
    ],
  } as unknown as AiGatewayRequest;

  assert.throws(
    () => assertRequestIsMinimized(requestValue),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "gatewayRequestInvalid" &&
      error.status === 422,
  );
});

test("phone-like financial context is rejected before provider use", async () => {
  const sensitive = "0912345678";
  const { app, groq } = appAndGroq();
  const response = await request(app)
    .post("/v1/ai/financial-explanation")
    .set("Content-Type", "application/json")
    .send({
      ...body("Explain the bounded result."),
      mode: "financialExplanation",
      timeoutClass: "analysis",
      sanitizedFinancialContext: {
        currency: "LYD",
        records: [
          {
            toolId: "get_accounts_summary",
            partial: false,
            values: {
              accounts: [
                {
                  name: sensitive,
                  type: "cash",
                  balance: "1",
                  currency: "LYD",
                },
              ],
            },
          },
        ],
        assumptions: [],
      },
    });

  assert.equal(response.status, 422);
  assert.equal(response.text.includes(sensitive), false);
  assert.equal(groq.calls, 0);
});

test("schema-validated financial decimals and dates bypass prose scanning", async () => {
  const { app, groq } = appAndGroq();
  const response = await request(app)
    .post("/v1/ai/financial-explanation")
    .set("Content-Type", "application/json")
    .send({
      ...body("Explain the bounded transaction."),
      mode: "financialExplanation",
      timeoutClass: "analysis",
      sanitizedFinancialContext: {
        currency: "LYD",
        records: [
          {
            toolId: "search_transactions",
            partial: false,
            values: {
              transactions: [
                {
                  date: "2026-08-14T12:34:56Z",
                  amount: "1234567890.25",
                  currency: "LYD",
                  category: "Groceries",
                  account: "Cash",
                  status: "completed",
                },
              ],
              resultCount: 1,
              bounded: true,
            },
          },
        ],
        assumptions: [],
      },
    });

  assert.equal(response.status, 200);
  assert.equal(groq.calls, 1);
});

test("ordinary English and Arabic finance amounts remain allowed", async () => {
  const { app, groq } = appAndGroq();
  for (const content of [
    "I spent 500.25 LYD and saved 100 LYD.",
    "صرفت ٥٠٠٫٢٥ دينار ووفرت ١٠٠ دينار.",
  ]) {
    const response = await request(app)
      .post("/v1/ai/general-chat")
      .set("Content-Type", "application/json")
      .send(body(content));
    assert.equal(response.status, 200);
  }
  assert.equal(groq.calls, 2);
});

test("private responses are never cacheable", async () => {
  const { app } = appAndGroq();
  const response = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send(body());
  assert.match(response.headers["cache-control"] ?? "", /no-store/);
  assert.equal(response.headers["x-powered-by"], undefined);
});
