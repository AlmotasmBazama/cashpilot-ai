import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import type { Request } from "express";
import request from "supertest";
import type {
  RequestVerifier,
  VerifiedPrincipal,
} from "../src/auth/request_verifier.js";
import type { GatewayConfig } from "../src/config.js";
import { fixedModels } from "../src/config.js";
import { GatewayFailure } from "../src/errors.js";
import type {
  GroqCompletionRequest,
  GroqStreamObserver,
  GroqTransport,
} from "../src/groq/groq_client.js";
import { GroqChatCompletionsClient } from "../src/groq/groq_client.js";
import { createGatewayApp } from "../src/index.js";
import { PerUserSlidingWindowRateLimiter } from "../src/security/rate_limit.js";
import {
  intersectAllowedTools,
  toolSelectionJsonSchema,
} from "../src/tools/allowlist.js";
import type { SafeStreamLogEntry } from "../src/security/safe_stream_trace.js";
import type {
  RecursiveAccountDeletionResult,
  RecursiveAccountDeletionStore,
} from "../src/account_deletion/recursive_account_deletion_store.js";
import { AccountDeletionOperationConflict } from "../src/account_deletion/recursive_account_deletion_store.js";
import {
  AccountDeletionContinuationExpired,
  AccountDeletionNotReady,
  type AccountAuthDeletionResult,
  type AccountAuthDeletionStore,
} from "../src/account_deletion/account_auth_deletion_store.js";

class HeaderVerifier implements RequestVerifier {
  calls = 0;
  retryCalls = 0;
  attestationCalls = 0;
  uid = "verified-test-user";
  authTimeSeconds = Math.floor(Date.now() / 1000);
  issuedAtSeconds = Math.floor(Date.now() / 1000);
  signInProvider = "password";
  tenantIdentityPresent = false;
  strictError: GatewayFailure | undefined;
  allowAccountDeletionRetry = false;

  async verify(incoming: Request): Promise<VerifiedPrincipal> {
    this.calls += 1;
    if (this.strictError !== undefined) {
      throw this.strictError;
    }
    return this.verifyHeaders(incoming);
  }

  async verifyAccountDeletionRetry(
    incoming: Request,
  ): Promise<VerifiedPrincipal> {
    this.retryCalls += 1;
    if (!this.allowAccountDeletionRetry) {
      throw new GatewayFailure(
        "unauthenticated",
        "Firebase authentication verification failed.",
      );
    }
    return this.verifyHeaders(incoming);
  }

  async verifyAccountDeletionAttestation(
    incoming: Request,
  ): Promise<void> {
    this.attestationCalls += 1;
    if (incoming.header("X-Firebase-AppCheck") !== "valid-app-check") {
      throw new GatewayFailure(
        "appCheckRejected",
        "Firebase App Check verification failed.",
      );
    }
  }

  private verifyHeaders(incoming: Request): VerifiedPrincipal {
    if (incoming.header("Authorization") !== "Bearer valid-auth") {
      throw new GatewayFailure(
        "unauthenticated",
        "Firebase authentication verification failed.",
      );
    }
    if (incoming.header("X-Firebase-AppCheck") !== "valid-app-check") {
      throw new GatewayFailure(
        "appCheckRejected",
        "Firebase App Check verification failed.",
      );
    }
    return {
      uid: this.uid,
      authTimeSeconds: this.authTimeSeconds,
      issuedAtSeconds: this.issuedAtSeconds,
      signInProvider: this.signInProvider,
      tenantIdentityPresent: this.tenantIdentityPresent,
    };
  }
}

class FakeGroq implements GroqTransport {
  readonly completionRequests: GroqCompletionRequest[] = [];
  readonly streamRequests: GroqCompletionRequest[] = [];
  completionQueue: Array<string | Error> = [];
  streamText = "Hello from CashPilot.";
  failStreamModels = new Set<string>();

  async complete(requestValue: GroqCompletionRequest): Promise<string> {
    this.completionRequests.push(requestValue);
    const next = this.completionQueue.shift();
    if (next instanceof Error) {
      throw next;
    }
    return next ?? '{"toolSelections":[],"clarification":"Please clarify."}';
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
    if (this.failStreamModels.has(requestValue.model)) {
      this.failStreamModels.delete(requestValue.model);
      throw new GatewayFailure(
        "groqUpstreamUnavailable",
        "The provider is unavailable.",
      );
    }
    onDelta(this.streamText.slice(0, 6));
    onDelta(this.streamText.slice(6));
  }

  async availableModelIds(): Promise<ReadonlySet<string>> {
    return new Set(Object.values(fixedModels));
  }
}

class FakeRecursiveAccountDeletion
  implements RecursiveAccountDeletionStore
{
  constructor(private readonly sessions: Map<string, string>) {}

  readonly calls: Array<{ uid: string; operationId: string }> = [];
  readonly sessionCommitments: string[] = [];
  unknownNestedCollectionExists = true;
  verifiedEmpty = true;
  error: Error | undefined;

  async deleteAndVerify(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<RecursiveAccountDeletionResult> {
    const key = `${uid}\0${operationId}`;
    const existingSession = this.sessions.get(key);
    if (
      existingSession !== undefined &&
      existingSession !== authSessionCommitment
    ) {
      throw new AccountDeletionOperationConflict();
    }
    this.sessions.set(key, authSessionCommitment);
    this.calls.push({ uid, operationId });
    this.sessionCommitments.push(authSessionCommitment);
    if (this.error !== undefined) {
      throw this.error;
    }
    if (this.verifiedEmpty) {
      this.unknownNestedCollectionExists = false;
    }
    return {
      deletedDocuments: 7,
      verifiedEmpty: this.verifiedEmpty,
    };
  }
}

class FakeAccountAuthDeletion implements AccountAuthDeletionStore {
  constructor(private readonly sessions: Map<string, string>) {}

  readonly calls: Array<{ uid: string; operationId: string }> = [];
  readonly retryCalls: Array<{ uid: string; operationId: string }> = [];
  readonly attestationCalls: Array<{
    operationId: string;
    ownerScopeCommitment: string;
  }> = [];
  readonly sessionCommitments: string[] = [];
  readonly recentAuthenticationChecks: boolean[] = [];
  alreadyDeleted = false;
  error: Error | undefined;
  retryError: Error | undefined;

  async deleteAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    recentAuthenticationSatisfied: boolean,
  ): Promise<AccountAuthDeletionResult> {
    this.assertSession(uid, operationId, authSessionCommitment);
    this.calls.push({ uid, operationId });
    this.sessionCommitments.push(authSessionCommitment);
    this.recentAuthenticationChecks.push(recentAuthenticationSatisfied);
    if (this.error !== undefined) {
      throw this.error;
    }
    return { alreadyDeleted: this.alreadyDeleted };
  }

  async confirmAlreadyDeletedAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<AccountAuthDeletionResult> {
    this.assertSession(uid, operationId, authSessionCommitment);
    this.retryCalls.push({ uid, operationId });
    this.sessionCommitments.push(authSessionCommitment);
    if (this.retryError !== undefined) {
      throw this.retryError;
    }
    return { alreadyDeleted: true };
  }

  async confirmAlreadyDeletedByAttestation(
    operationId: string,
    ownerScopeCommitment: string,
    _deletionSessionProof: string,
  ): Promise<AccountAuthDeletionResult> {
    this.attestationCalls.push({ operationId, ownerScopeCommitment });
    if (this.retryError !== undefined) {
      throw this.retryError;
    }
    return { alreadyDeleted: true };
  }

  private assertSession(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
  ): void {
    const existingSession = this.sessions.get(`${uid}\0${operationId}`);
    if (
      existingSession !== undefined &&
      existingSession !== authSessionCommitment
    ) {
      throw new AccountDeletionOperationConflict();
    }
  }
}

const config: GatewayConfig = {
  environment: "test",
  port: 8080,
  firebaseProjectId: "cashpilot-test",
  groqApiKey: "unit-test-placeholder",
  groqBaseUrl: "https://provider.invalid/v1",
  allowedOrigins: new Set(["https://staging.cashpilot.example"]),
  maxBodyBytes: 32 * 1024,
  maxRequestsPerMinute: 20,
  providerTimeoutMs: 2_000,
  maxStreamMs: 2_000,
  modelDiagnosticsEnabled: true,
  toolSelectionEnabled: true,
  supportedClientVersion: "test",
};

function baseRequest(
  mode:
    | "generalConversation"
    | "financialExplanation"
    | "governedToolSelection",
): Record<string, unknown> {
  return {
    requestId: "request_12345",
    mode,
    locale: "en",
    sanitizedMessages: [{ role: "user", content: "Help me understand." }],
    timeoutClass:
      mode === "generalConversation" ? "interactive" : "analysis",
    clientVersion: "test",
  };
}

function harness(options: { maxRequests?: number } = {}) {
  const verifier = new HeaderVerifier();
  const groq = new FakeGroq();
  const accountDeletionSessions = new Map<string, string>();
  const accountDeletion = new FakeRecursiveAccountDeletion(
    accountDeletionSessions,
  );
  const accountAuthDeletion = new FakeAccountAuthDeletion(
    accountDeletionSessions,
  );
  const safeLogs: SafeStreamLogEntry[] = [];
  const app = createGatewayApp({
    config,
    verifier,
    groq,
    rateLimiter: new PerUserSlidingWindowRateLimiter(
      options.maxRequests ?? 20,
    ),
    safeStreamLog: (entry) => safeLogs.push(entry),
    accountDeletion,
    accountAuthDeletion,
  });
  return {
    app,
    verifier,
    groq,
    safeLogs,
    accountDeletion,
    accountAuthDeletion,
  };
}

const deletionSessionProofA = Buffer.alloc(32, 0).toString("base64url");
const deletionSessionProofB = Buffer.alloc(32, 1).toString("base64url");

function authorized(
  post: request.Test,
  deletionSessionProof = deletionSessionProofA,
): request.Test {
  return post
    .set("Authorization", "Bearer valid-auth")
    .set("X-Firebase-AppCheck", "valid-app-check")
    .set("X-Cashpilot-Deletion-Session", deletionSessionProof)
    .set("Content-Type", "application/json");
}

function ownerScope(uid: string): string {
  if (uid.length === 0 || uid !== uid.trim()) {
    throw new TypeError("canonical synthetic uid required");
  }
  return createHash("sha256")
    .update(`cashpilot.local-owner-scope.v1\0${uid}`, "utf8")
    .digest("hex");
}

function deletionBody(
  operationId: string,
  uid = "verified-test-user",
): { operationId: string; targetOwnerScope: string } {
  return { operationId, targetOwnerScope: ownerScope(uid) };
}

test("recursive account deletion uses only verified uid and deletes unknown nested data", async () => {
  const { app, accountDeletion } = harness();
  const operationId = "01989f80-4e00-7000-8000-000000000001";
  const response = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(deletionBody(operationId));

  assert.equal(response.status, 200);
  assert.deepEqual(accountDeletion.calls, [
    { uid: "verified-test-user", operationId },
  ]);
  assert.equal(accountDeletion.unknownNestedCollectionExists, false);
  assert.equal(response.body.operationId, operationId);
  assert.equal(response.body.verifiedEmpty, true);
  assert.doesNotMatch(JSON.stringify(response.body), /verified-test-user/);
});

test("recursive account deletion rejects caller uid and unverified completion", async () => {
  const first = harness();
  const operationId = "01989f80-4e00-7000-8000-000000000002";
  const forged = await authorized(
    request(first.app).post("/v1/account-deletion/recursive"),
  ).send({ ...deletionBody(operationId), uid: "forged-user" });
  assert.equal(forged.status, 400);
  assert.equal(first.accountDeletion.calls.length, 0);

  const second = harness();
  second.accountDeletion.verifiedEmpty = false;
  const unverified = await authorized(
    request(second.app).post("/v1/account-deletion/recursive"),
  ).send(deletionBody(operationId));
  assert.equal(unverified.status, 503);
  assert.equal(unverified.body.failure.code, "providerUnavailable");
});

test("recursive account deletion rejects a stale authenticated session", async () => {
  const { app, verifier, accountDeletion } = harness();
  verifier.authTimeSeconds = Math.floor(Date.now() / 1000) - 301;
  const response = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000003"),
  );

  assert.equal(response.status, 401);
  assert.equal(response.body.failure.code, "unauthenticated");
  assert.equal(accountDeletion.calls.length, 0);
});

test("recursive account deletion exposes a conflicting operation as 409", async () => {
  const { app, accountDeletion } = harness();
  accountDeletion.error = new AccountDeletionOperationConflict();
  const response = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000006"),
  );

  assert.equal(response.status, 409);
  assert.equal(response.body.failure.code, "operationConflict");
});

test("anonymous deletion uses fresh token issue time because strong reauthentication is unavailable", async () => {
  const { app, verifier, accountDeletion } = harness();
  verifier.signInProvider = "anonymous";
  verifier.authTimeSeconds = Math.floor(Date.now() / 1000) - 24 * 60 * 60;
  verifier.issuedAtSeconds = Math.floor(Date.now() / 1000);

  const response = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000004"),
  );

  assert.equal(response.status, 200);
  assert.equal(accountDeletion.calls.length, 1);
});

test("anonymous deletion rejects a stale force-refresh token", async () => {
  const { app, verifier, accountDeletion } = harness();
  verifier.signInProvider = "anonymous";
  verifier.authTimeSeconds = Math.floor(Date.now() / 1000) - 24 * 60 * 60;
  verifier.issuedAtSeconds = Math.floor(Date.now() / 1000) - 301;

  const response = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000005"),
  );

  assert.equal(response.status, 401);
  assert.equal(accountDeletion.calls.length, 0);
});

test("owner commitment rejects a B token before either deletion boundary mutates", async () => {
  const { app, verifier, accountDeletion, accountAuthDeletion } = harness();
  verifier.uid = "user-b";
  const operationId = "01989f80-4e00-7000-8000-000000000021";
  const targetA = deletionBody(operationId, "user-a");

  const cloudResponse = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(targetA);
  const authResponse = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(targetA);

  verifier.uid = " user-a ";
  const collidingCloudResponse = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(targetA);
  const collidingAuthResponse = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(targetA);

  assert.equal(cloudResponse.status, 409);
  assert.equal(cloudResponse.body.failure.code, "operationConflict");
  assert.equal(authResponse.status, 409);
  assert.equal(authResponse.body.failure.code, "operationConflict");
  assert.equal(collidingCloudResponse.status, 409);
  assert.equal(collidingAuthResponse.status, 409);
  assert.equal(accountDeletion.calls.length, 0);
  assert.equal(accountAuthDeletion.calls.length, 0);
});

test("tenant principals with a colliding uid cannot reach either deletion store", async () => {
  const { app, verifier, accountDeletion, accountAuthDeletion } = harness({
    maxRequests: 1,
  });
  verifier.uid = "shared-uid";
  verifier.tenantIdentityPresent = true;
  const operationId = "01989f80-4e00-7000-8000-000000000034";
  const body = deletionBody(operationId, "shared-uid");

  const recursive = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(body);
  const auth = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(body);

  assert.equal(recursive.status, 401);
  assert.equal(auth.status, 401);
  assert.equal(accountDeletion.calls.length, 0);
  assert.equal(accountAuthDeletion.calls.length, 0);

  // Rejection happens before quota mutation as well as deletion mutation.
  verifier.tenantIdentityPresent = false;
  const defaultPrincipal = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(body);
  assert.equal(defaultPrincipal.status, 200);
  assert.equal(accountDeletion.calls.length, 1);
});

test("token refresh preserves deletion authority but same-second same-uid relogin does not", async () => {
  const { app, verifier, accountDeletion, accountAuthDeletion } = harness();
  verifier.uid = "session-user";
  const now = Math.floor(Date.now() / 1000);
  verifier.authTimeSeconds = now;
  verifier.issuedAtSeconds = now;
  const operationId = "01989f80-4e00-7000-8000-000000000035";
  const body = deletionBody(operationId, "session-user");

  const cloud = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(body);
  verifier.issuedAtSeconds = now + 1;
  const refreshedAuth = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(body);

  assert.equal(cloud.status, 200);
  assert.equal(refreshedAuth.status, 200);
  assert.equal(
    accountDeletion.sessionCommitments[0],
    accountAuthDeletion.sessionCommitments[0],
  );

  const replacementSession = await authorized(
    request(app).post("/v1/account-deletion/auth"),
    deletionSessionProofB,
  ).send(body);
  assert.equal(replacementSession.status, 409);
  assert.equal(replacementSession.body.failure.code, "operationConflict");
  assert.equal(accountAuthDeletion.calls.length, 1);
});

test("deletion proof is mandatory canonical 256-bit request-only material", async () => {
  const { app, accountDeletion, accountAuthDeletion } = harness();
  const operationId = "01989f80-4e00-7000-8000-000000000036";
  const invalidProofs: Array<string | undefined> = [
    undefined,
    "too-short",
    `${deletionSessionProofA}=`,
    "*".repeat(43),
    `${"A".repeat(42)}B`,
  ];

  for (const path of [
    "/v1/account-deletion/recursive",
    "/v1/account-deletion/auth",
  ]) {
    for (const proof of invalidProofs) {
      let post = request(app)
        .post(path)
        .set("Authorization", "Bearer valid-auth")
        .set("X-Firebase-AppCheck", "valid-app-check")
        .set("Content-Type", "application/json");
      if (proof !== undefined) {
        post = post.set("X-Cashpilot-Deletion-Session", proof);
      }
      const response = await post.send(deletionBody(operationId));
      assert.equal(response.status, 401);
      assert.equal(response.body.failure.code, "unauthenticated");
      if (proof !== undefined) {
        assert.equal(response.text.includes(proof), false);
      }
    }
  }
  assert.equal(accountDeletion.calls.length, 0);
  assert.equal(accountAuthDeletion.calls.length, 0);
  assert.equal(accountAuthDeletion.attestationCalls.length, 0);
});

test("Auth-last accepts a stale refreshed token within proof-bound continuation", async () => {
  const { app, verifier, accountAuthDeletion } = harness();
  verifier.authTimeSeconds = Math.floor(Date.now() / 1000) - 6 * 60;
  verifier.issuedAtSeconds = Math.floor(Date.now() / 1000);
  const response = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000037"),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(accountAuthDeletion.recentAuthenticationChecks, [
    false,
  ]);
});

test("missing or expired Auth can only perform proof-bound read-only recovery", async () => {
  for (const authHeader of [undefined, "Bearer expired-auth"]) {
    const { app, verifier, accountAuthDeletion } = harness();
    verifier.strictError = new GatewayFailure(
      "unauthenticated",
      "The token is unavailable.",
    );
    const operationId = "01989f80-4e00-7000-8000-000000000038";
    let post = request(app)
      .post("/v1/account-deletion/auth")
      .set("X-Firebase-AppCheck", "valid-app-check")
      .set("X-Cashpilot-Deletion-Session", deletionSessionProofA)
      .set("Content-Type", "application/json");
    if (authHeader !== undefined) {
      post = post.set("Authorization", authHeader);
    }
    const response = await post.send(deletionBody(operationId));

    assert.equal(response.status, 200);
    assert.equal(accountAuthDeletion.calls.length, 0);
    assert.equal(accountAuthDeletion.retryCalls.length, 0);
    assert.deepEqual(accountAuthDeletion.attestationCalls, [
      {
        operationId,
        ownerScopeCommitment: ownerScope("verified-test-user"),
      },
    ]);
    assert.equal(verifier.attestationCalls, 1);
  }
});

test("proof-only recovery is rate-limited before reaching the deletion store", async () => {
  const { app, verifier, accountAuthDeletion } = harness({
    maxRequests: 1,
  });
  verifier.strictError = new GatewayFailure(
    "unauthenticated",
    "The token is unavailable.",
  );
  const body = deletionBody(
    "01989f80-4e00-7000-8000-000000000039",
  );
  const recoveryRequest = () =>
    request(app)
      .post("/v1/account-deletion/auth")
      .set("X-Firebase-AppCheck", "valid-app-check")
      .set("X-Cashpilot-Deletion-Session", deletionSessionProofA)
      .set("Content-Type", "application/json")
      .send(body);

  const first = await recoveryRequest();
  const limited = await recoveryRequest();
  assert.equal(first.status, 200);
  assert.equal(limited.status, 429);
  assert.equal(accountAuthDeletion.attestationCalls.length, 1);
  assert.equal(accountAuthDeletion.calls.length, 0);
});

test("proof-only recovery has a global budget across rotated owner scopes", async () => {
  const { app, verifier, accountAuthDeletion } = harness({
    maxRequests: 2,
  });
  verifier.strictError = new GatewayFailure(
    "unauthenticated",
    "The token is unavailable.",
  );
  const recoveryRequest = (
    operationId: string,
    targetOwnerScope: string,
  ) =>
    request(app)
      .post("/v1/account-deletion/auth")
      .set("X-Firebase-AppCheck", "valid-app-check")
      .set("X-Cashpilot-Deletion-Session", deletionSessionProofA)
      .set("Content-Type", "application/json")
      .send({ operationId, targetOwnerScope });

  const first = await recoveryRequest(
    "01989f80-4e00-7000-8000-000000000040",
    ownerScope("rotated-scope-a"),
  );
  const second = await recoveryRequest(
    "01989f80-4e00-7000-8000-000000000041",
    ownerScope("rotated-scope-b"),
  );
  const limited = await recoveryRequest(
    "01989f80-4e00-7000-8000-000000000042",
    ownerScope("rotated-scope-c"),
  );

  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(limited.status, 429);
  assert.deepEqual(
    accountAuthDeletion.attestationCalls.map(
      ({ ownerScopeCommitment }) => ownerScopeCommitment,
    ),
    [ownerScope("rotated-scope-a"), ownerScope("rotated-scope-b")],
  );
  assert.equal(accountAuthDeletion.calls.length, 0);
  assert.equal(accountAuthDeletion.retryCalls.length, 0);
});

test("Auth deletion derives its target only from the verified token principal", async () => {
  const { app, verifier, accountAuthDeletion } = harness();
  verifier.uid = "user-a";
  const operationId = "01989f80-4e00-7000-8000-000000000022";
  const response = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId, "user-a"));

  assert.equal(response.status, 200);
  assert.deepEqual(accountAuthDeletion.calls, [
    { uid: "user-a", operationId },
  ]);
  assert.deepEqual(response.body, {
    operationId,
    status: "completed",
    authDeleted: true,
    alreadyDeleted: false,
  });
  assert.doesNotMatch(JSON.stringify(response.body), /user-a/);
});

test("Auth deletion body is strict and never accepts a caller-selected uid", async () => {
  const { app, accountAuthDeletion } = harness();
  const operationId = "01989f80-4e00-7000-8000-000000000023";
  const invalidBodies = [
    { targetOwnerScope: ownerScope("verified-test-user") },
    {
      operationId: "not-a-uuid",
      targetOwnerScope: ownerScope("verified-test-user"),
    },
    {
      ...deletionBody(operationId),
      targetOwnerScope: ownerScope("verified-test-user").toUpperCase(),
    },
    { ...deletionBody(operationId), uid: "forged-target" },
  ];

  for (const body of invalidBodies) {
    const response = await authorized(
      request(app).post("/v1/account-deletion/auth"),
    ).send(body);
    assert.equal(response.status, 400);
  }
  assert.equal(accountAuthDeletion.calls.length, 0);
});

test("Auth deletion fails closed for missing proof, conflict, and Auth failure", async () => {
  const operationId = "01989f80-4e00-7000-8000-000000000024";

  const notReady = harness();
  notReady.accountAuthDeletion.error = new AccountDeletionNotReady();
  const notReadyResponse = await authorized(
    request(notReady.app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId));
  assert.equal(notReadyResponse.status, 409);
  assert.equal(notReadyResponse.body.failure.code, "deletionNotReady");

  const conflict = harness();
  conflict.accountAuthDeletion.error =
    new AccountDeletionOperationConflict();
  const conflictResponse = await authorized(
    request(conflict.app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId));
  assert.equal(conflictResponse.status, 409);
  assert.equal(conflictResponse.body.failure.code, "operationConflict");

  const failed = harness();
  failed.accountAuthDeletion.error = new Error("synthetic Auth outage");
  const failedResponse = await authorized(
    request(failed.app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId));
  assert.equal(failedResponse.status, 503);
  assert.equal(failedResponse.body.failure.code, "providerUnavailable");
});

test("expired deletion continuation has a dedicated reauthentication signal", async () => {
  const { app, accountAuthDeletion } = harness();
  accountAuthDeletion.error = new AccountDeletionContinuationExpired();
  const response = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000043"),
  );

  assert.equal(response.status, 401);
  assert.deepEqual(response.body.failure, {
    code: "deletionReauthenticationRequired",
    message: "Fresh authentication is required to continue account deletion.",
  });
  assert.equal(accountAuthDeletion.calls.length, 1);
  assert.equal(accountAuthDeletion.retryCalls.length, 0);
  assert.equal(accountAuthDeletion.attestationCalls.length, 0);
});

test("Auth deletion idempotently accepts user-not-found only after store proof", async () => {
  const { app, accountAuthDeletion } = harness();
  accountAuthDeletion.alreadyDeleted = true;
  const operationId = "01989f80-4e00-7000-8000-000000000025";

  const response = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId));

  assert.equal(response.status, 200);
  assert.equal(response.body.authDeleted, true);
  assert.equal(response.body.alreadyDeleted, true);
  assert.equal(accountAuthDeletion.calls.length, 1);
});

test("a lost Auth-deletion response is recoverable without another delete", async () => {
  const { app, verifier, accountAuthDeletion } = harness();
  verifier.strictError = new GatewayFailure(
    "unauthenticated",
    "The Auth user is already absent.",
  );
  verifier.allowAccountDeletionRetry = true;
  const operationId = "01989f80-4e00-7000-8000-000000000027";

  const response = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId));

  assert.equal(response.status, 200);
  assert.equal(response.body.alreadyDeleted, true);
  assert.equal(accountAuthDeletion.calls.length, 0);
  assert.deepEqual(accountAuthDeletion.retryCalls, [
    { uid: "verified-test-user", operationId },
  ]);
  assert.equal(verifier.retryCalls, 1);
});

test("signature-only recovery cannot authorize recursive deletion or another owner", async () => {
  const recursive = harness();
  recursive.verifier.strictError = new GatewayFailure(
    "unauthenticated",
    "Strict token verification failed.",
  );
  recursive.verifier.allowAccountDeletionRetry = true;
  const recursiveResponse = await authorized(
    request(recursive.app).post("/v1/account-deletion/recursive"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000032"),
  );
  assert.equal(recursiveResponse.status, 401);
  assert.equal(recursive.verifier.retryCalls, 0);
  assert.equal(recursive.accountDeletion.calls.length, 0);

  const wrongOwner = harness();
  wrongOwner.verifier.uid = "user-b";
  wrongOwner.verifier.strictError = new GatewayFailure(
    "unauthenticated",
    "Strict token verification failed.",
  );
  wrongOwner.verifier.allowAccountDeletionRetry = true;
  const wrongOwnerResponse = await authorized(
    request(wrongOwner.app).post("/v1/account-deletion/auth"),
  ).send(
    deletionBody(
      "01989f80-4e00-7000-8000-000000000033",
      "user-a",
    ),
  );
  assert.equal(wrongOwnerResponse.status, 409);
  assert.equal(wrongOwner.accountAuthDeletion.calls.length, 0);
  assert.equal(wrongOwner.accountAuthDeletion.retryCalls.length, 0);
});

test("fallback cannot recover before the marker or delete an existing revoked user", async () => {
  for (const retryFailure of [
    new AccountDeletionNotReady(),
    new AccountDeletionOperationConflict(),
  ]) {
    const { app, verifier, accountAuthDeletion } = harness();
    verifier.strictError = new GatewayFailure(
      "unauthenticated",
      "Strict token verification failed.",
    );
    verifier.allowAccountDeletionRetry = true;
    accountAuthDeletion.retryError = retryFailure;

    const response = await authorized(
      request(app).post("/v1/account-deletion/auth"),
    ).send(
      deletionBody("01989f80-4e00-7000-8000-000000000028"),
    );

    assert.equal(response.status, 409);
    assert.equal(accountAuthDeletion.calls.length, 0);
    assert.equal(accountAuthDeletion.retryCalls.length, 1);
  }
});

test("fallback requires App Check and remains read-only for a stale signed token", async () => {
  const invalidCheck = harness();
  invalidCheck.verifier.strictError = new GatewayFailure(
    "unauthenticated",
    "Strict token verification failed.",
  );
  invalidCheck.verifier.allowAccountDeletionRetry = true;
  const invalidCheckResponse = await request(invalidCheck.app)
    .post("/v1/account-deletion/auth")
    .set("Authorization", "Bearer valid-auth")
    .set("X-Firebase-AppCheck", "invalid-app-check")
    .set("X-Cashpilot-Deletion-Session", deletionSessionProofA)
    .set("Content-Type", "application/json")
    .send(
      deletionBody("01989f80-4e00-7000-8000-000000000029"),
    );
  assert.equal(invalidCheckResponse.status, 401);
  assert.equal(
    invalidCheckResponse.body.failure.code,
    "appCheckRejected",
  );
  assert.equal(invalidCheck.accountAuthDeletion.calls.length, 0);
  assert.equal(invalidCheck.accountAuthDeletion.retryCalls.length, 0);

  const stale = harness();
  stale.verifier.strictError = new GatewayFailure(
    "unauthenticated",
    "Strict token verification failed.",
  );
  stale.verifier.allowAccountDeletionRetry = true;
  stale.verifier.authTimeSeconds = Math.floor(Date.now() / 1000) - 301;
  const staleResponse = await authorized(
    request(stale.app).post("/v1/account-deletion/auth"),
  ).send(
    deletionBody("01989f80-4e00-7000-8000-000000000030"),
  );
  assert.equal(staleResponse.status, 200);
  assert.equal(stale.accountAuthDeletion.calls.length, 0);
  assert.equal(stale.accountAuthDeletion.retryCalls.length, 1);
});

test("deletion routes use independent per-owner rate-limit buckets", async () => {
  const { app, accountDeletion, accountAuthDeletion } = harness({
    maxRequests: 1,
  });
  const operationId = "01989f80-4e00-7000-8000-000000000031";

  const cloud = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(deletionBody(operationId));
  const auth = await authorized(
    request(app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId));
  const cloudRetry = await authorized(
    request(app).post("/v1/account-deletion/recursive"),
  ).send(deletionBody(operationId));

  assert.equal(cloud.status, 200);
  assert.equal(auth.status, 200);
  assert.equal(cloudRetry.status, 429);
  assert.equal(accountDeletion.calls.length, 1);
  assert.equal(accountAuthDeletion.calls.length, 1);
});

test("Auth deletion requires App Check and delegates stale-token deadline enforcement", async () => {
  const operationId = "01989f80-4e00-7000-8000-000000000026";

  const missingCheck = harness();
  const missingCheckResponse = await request(missingCheck.app)
    .post("/v1/account-deletion/auth")
    .set("Authorization", "Bearer valid-auth")
    .set("X-Cashpilot-Deletion-Session", deletionSessionProofA)
    .set("Content-Type", "application/json")
    .send(deletionBody(operationId));
  assert.equal(missingCheckResponse.status, 401);
  assert.equal(
    missingCheckResponse.body.failure.code,
    "appCheckRejected",
  );
  assert.equal(missingCheck.accountAuthDeletion.calls.length, 0);

  const stale = harness();
  stale.verifier.authTimeSeconds = Math.floor(Date.now() / 1000) - 301;
  const staleResponse = await authorized(
    request(stale.app).post("/v1/account-deletion/auth"),
  ).send(deletionBody(operationId));
  assert.equal(staleResponse.status, 200);
  assert.equal(stale.accountAuthDeletion.calls.length, 1);
  assert.deepEqual(stale.accountAuthDeletion.recentAuthenticationChecks, [
    false,
  ]);
});

test("missing Auth is rejected before Groq is called", async () => {
  const { app, groq } = harness();
  const response = await request(app)
    .post("/v1/ai/general-chat")
    .set("Content-Type", "application/json")
    .send(baseRequest("generalConversation"));
  assert.equal(response.status, 401);
  assert.equal(response.body.failure.code, "gatewayAuthenticationRequired");
  assert.equal(groq.streamRequests.length, 0);
});

test("invalid Auth is rejected before Groq is called", async () => {
  const { app, groq } = harness();
  const response = await request(app)
    .post("/v1/ai/general-chat")
    .set("Authorization", "Bearer invalid-auth")
    .set("X-Firebase-AppCheck", "valid-app-check")
    .set("Content-Type", "application/json")
    .send(baseRequest("generalConversation"));
  assert.equal(response.status, 401);
  assert.equal(response.body.failure.code, "gatewayAuthenticationRequired");
  assert.equal(groq.streamRequests.length, 0);
});

test("missing App Check is rejected before Groq is called", async () => {
  const { app, groq } = harness();
  const response = await request(app)
    .post("/v1/ai/general-chat")
    .set("Authorization", "Bearer valid-auth")
    .set("Content-Type", "application/json")
    .send(baseRequest("generalConversation"));
  assert.equal(response.status, 401);
  assert.equal(response.body.failure.code, "gatewayAppCheckRequired");
  assert.equal(groq.streamRequests.length, 0);
});

test("invalid App Check is rejected before Groq is called", async () => {
  const { app, groq } = harness();
  const response = await request(app)
    .post("/v1/ai/general-chat")
    .set("Authorization", "Bearer valid-auth")
    .set("X-Firebase-AppCheck", "invalid-app-check")
    .set("Content-Type", "application/json")
    .send(baseRequest("generalConversation"));
  assert.equal(response.status, 401);
  assert.equal(response.body.failure.code, "gatewayAppCheckRequired");
  assert.equal(groq.streamRequests.length, 0);
});

test("every AI boundary maps missing and invalid credentials to gateway codes", async () => {
  const { app, groq } = harness();
  const paths = [
    "/v1/ai/general-chat",
    "/v1/ai/financial-explanation",
    "/v1/ai/tool-selection",
    "/v1/diagnostics",
  ];
  for (const path of paths) {
    const missingAuth = await request(app)
      .post(path)
      .set("Content-Type", "application/json")
      .send({});
    assert.equal(missingAuth.status, 401, path);
    assert.equal(
      missingAuth.body.failure.code,
      "gatewayAuthenticationRequired",
      path,
    );

    const invalidAuth = await request(app)
      .post(path)
      .set("Authorization", "Bearer invalid-auth")
      .set("X-Firebase-AppCheck", "valid-app-check")
      .set("Content-Type", "application/json")
      .send({});
    assert.equal(invalidAuth.status, 401, path);
    assert.equal(
      invalidAuth.body.failure.code,
      "gatewayAuthenticationRequired",
      path,
    );

    const missingAppCheck = await request(app)
      .post(path)
      .set("Authorization", "Bearer valid-auth")
      .set("Content-Type", "application/json")
      .send({});
    assert.equal(missingAppCheck.status, 401, path);
    assert.equal(
      missingAppCheck.body.failure.code,
      "gatewayAppCheckRequired",
      path,
    );

    const invalidAppCheck = await request(app)
      .post(path)
      .set("Authorization", "Bearer valid-auth")
      .set("X-Firebase-AppCheck", "invalid-app-check")
      .set("Content-Type", "application/json")
      .send({});
    assert.equal(invalidAppCheck.status, 401, path);
    assert.equal(
      invalidAppCheck.body.failure.code,
      "gatewayAppCheckRequired",
      path,
    );
  }
  assert.equal(groq.completionRequests.length, 0);
  assert.equal(groq.streamRequests.length, 0);
});

test("general chat streams through the fixed 20B route", async () => {
  const { app, groq } = harness();
  const response = await authorized(
    request(app).post("/v1/ai/general-chat"),
  ).send(baseRequest("generalConversation"));
  assert.equal(response.status, 200);
  assert.equal(
    response.headers["content-type"],
    "text/event-stream; charset=utf-8",
  );
  assert.equal(
    response.headers["cache-control"],
    "no-store, no-cache, must-revalidate",
  );
  assert.equal(response.headers.connection, "keep-alive");
  assert.equal(response.headers["x-accel-buffering"], "no");
  assert.equal(response.headers["x-request-id"], "request_12345");
  const events = (response.text ?? "")
    .trim()
    .split("\n\n")
    .map((frame) => frame.split("\n"));
  assert.deepEqual(
    events.map((frame) => frame[0]),
    ["id: 1", "id: 2", "id: 3"],
  );
  assert.ok(events.every((frame) => frame[1] === "event: cashpilot"));
  assert.deepEqual(
    events.map((frame) =>
      JSON.parse((frame[2] ?? "").replace(/^data: /u, "")),
    ),
    [
      { type: "started", requestId: "request_12345" },
      {
        type: "textDelta",
        requestId: "request_12345",
        delta: "Hello from CashPilot.",
      },
      { type: "completed", requestId: "request_12345" },
    ],
  );
  assert.equal(
    groq.streamRequests[0]?.model,
    fixedModels.generalConversation,
  );
  assert.equal(groq.streamRequests[0]?.reasoningEffort, "low");
  assert.equal(groq.streamRequests[0]?.reasoningFormat, "hidden");
});

test("general chat JSON mode is fixed, no-store, and bounded", async () => {
  const trusted = harness();
  trusted.groq.completionQueue.push("A bounded non-stream answer.");
  const response = await authorized(
    request(trusted.app).post("/v1/ai/general-chat"),
  ).send({
    ...baseRequest("generalConversation"),
    responseMode: "json",
  });

  assert.equal(response.status, 200);
  assert.match(response.headers["content-type"] ?? "", /application\/json/);
  assert.equal(response.headers["cache-control"], "no-store");
  assert.deepEqual(response.body, {
    requestId: "request_12345",
    text: "A bounded non-stream answer.",
  });
  assert.equal(trusted.groq.streamRequests.length, 0);
  assert.equal(trusted.groq.completionRequests.length, 1);
  assert.equal(
    trusted.groq.completionRequests[0]?.model,
    fixedModels.generalConversation,
  );
  assert.equal(trusted.groq.completionRequests[0]?.maxOutputTokens, 700);

  const oversized = harness();
  oversized.groq.completionQueue.push("x".repeat(16 * 1024 + 1));
  const rejected = await authorized(
    request(oversized.app).post("/v1/ai/general-chat"),
  ).send({
    ...baseRequest("generalConversation"),
    responseMode: "json",
  });
  assert.equal(rejected.status, 502);
  assert.equal(rejected.body.failure.code, "groqMalformedResponse");
  assert.equal(rejected.headers["cache-control"], "no-store");
});

test("general stream emits only closed-schema safe correlation data", async () => {
  const { app, safeLogs } = harness();
  const body = {
    ...baseRequest("generalConversation"),
    sanitizedMessages: [
      { role: "user", content: "PRIVATE_PROMPT_MARKER" },
    ],
  };
  const response = await authorized(
    request(app)
      .post("/v1/ai/general-chat")
      .set("X-Request-ID", "request_12345"),
  ).send(body);

  assert.equal(response.status, 200);
  assert.equal(response.headers["x-request-id"], "request_12345");
  assert.equal(safeLogs.length, 1);
  const entry = safeLogs[0]!;
  assert.deepEqual(Object.keys(entry).sort(), [
    "appVersion",
    "completionDurationMs",
    "durationMs",
    "finalCode",
    "kind",
    "normalizedSseEventTypes",
    "platform",
    "rateLimitResult",
    "requestId",
    "retryCount",
    "route",
    "selectedModel",
    "selectedModelAlias",
    "statusCode",
    "timeToFirstContentMs",
    "typedErrorCode",
    "upstreamAttemptStatusCategories",
    "upstreamChunks",
    "upstreamHttpStatusCategory",
  ]);
  assert.equal(entry.requestId, "request_12345");
  assert.equal(entry.route, "/v1/ai/general-chat");
  assert.equal(entry.selectedModelAlias, "general-primary");
  assert.equal(entry.selectedModel, fixedModels.generalConversation);
  assert.equal(entry.appVersion, "test");
  assert.equal(entry.platform, "unknown");
  assert.equal(entry.statusCode, 200);
  assert.equal(entry.typedErrorCode, "none");
  assert.equal(entry.retryCount, 0);
  assert.equal(entry.rateLimitResult, "allowed");
  assert.equal(typeof entry.durationMs, "number");
  assert.equal(typeof entry.timeToFirstContentMs, "number");
  assert.equal(typeof entry.completionDurationMs, "number");
  assert.equal(entry.upstreamHttpStatusCategory, "success");
  assert.equal(entry.upstreamChunks, 1);
  assert.deepEqual(entry.normalizedSseEventTypes, [
    "started",
    "textDelta",
    "completed",
  ]);
  assert.equal(entry.finalCode, "completed");
  const serialized = JSON.stringify(entry);
  assert.doesNotMatch(serialized, /PRIVATE_PROMPT_MARKER/);
  assert.doesNotMatch(serialized, /Hello from CashPilot/);
  assert.doesNotMatch(serialized, /unit-test-placeholder/);
  assert.doesNotMatch(serialized, /verified-test-user/);
  assert.doesNotMatch(serialized, /valid-auth|valid-app-check/);
});

test("protected diagnostic performs a synthetic streamed model call", async () => {
  const { app, groq, safeLogs } = harness();
  const response = await authorized(
    request(app)
      .post("/v1/diagnostics")
      .set("X-Request-ID", "request_12345"),
  ).send({
    requestId: "request_12345",
    check: "modelAvailability",
    synthetic: true,
  });

  assert.equal(response.status, 200);
  assert.equal(response.body.generalModel, "success");
  assert.equal(response.body.generalStream, "success");
  assert.equal(groq.streamRequests.length, 1);
  assert.equal(groq.streamRequests[0]?.model, fixedModels.generalConversation);
  assert.equal(groq.streamRequests[0]?.reasoningEffort, "low");
  assert.equal(groq.streamRequests[0]?.reasoningFormat, "hidden");
  assert.equal(safeLogs[0]?.route, "/v1/diagnostics");
  assert.equal(safeLogs[0]?.finalCode, "completed");
});

test("provider SSE buffers arbitrary UTF-8 chunks and requires DONE", async () => {
  const arabic = "التضخم";
  const providerBody = [
    `data: ${JSON.stringify({
      choices: [{ delta: { reasoning: "hidden" } }],
    })}\r\n\r\n`,
    `data: ${JSON.stringify({
      choices: [{ delta: { content: arabic } }],
    })}\r\n\r\n`,
    "data: [DONE]",
  ].join("");
  const bytes = new TextEncoder().encode(providerBody);
  let capturedBody = "";
  const fetcher: typeof fetch = async (_input, init) => {
    capturedBody = String(init?.body ?? "");
    return byteStreamResponse(
      [...bytes].map((byte) => new Uint8Array([byte])),
    );
  };
  const client = new GroqChatCompletionsClient(config, fetcher);
  const deltas: string[] = [];

  await client.stream(
    {
      model: fixedModels.generalConversation,
      messages: [{ role: "user", content: "synthetic" }],
      maxOutputTokens: 700,
      temperature: 0.2,
      reasoningEffort: "low",
      reasoningFormat: "hidden",
    },
    (delta) => deltas.push(delta),
  );

  assert.deepEqual(deltas, [arabic]);
  const requestBody = JSON.parse(capturedBody) as Record<string, unknown>;
  assert.equal(requestBody.reasoning_effort, "low");
  assert.equal(requestBody.reasoning_format, "hidden");
});

test("provider empty and truncated streams remain distinct", async () => {
  for (const scenario of [
    {
      body:
        `data: ${JSON.stringify({
          choices: [{ delta: { reasoning: "only reasoning" } }],
        })}\n\n` + "data: [DONE]\n\n",
      code: "groqMalformedResponse",
    },
    {
      body: `data: ${JSON.stringify({
        choices: [{ delta: { content: "partial" } }],
      })}\n\n`,
      code: "groqUpstreamUnavailable",
    },
  ] as const) {
    const fetcher: typeof fetch = async () =>
      byteStreamResponse([new TextEncoder().encode(scenario.body)]);
    const client = new GroqChatCompletionsClient(config, fetcher);
    await assert.rejects(
      client.stream(
        {
          model: fixedModels.generalConversation,
          messages: [{ role: "user", content: "synthetic" }],
          maxOutputTokens: 700,
          temperature: 0.2,
        },
        () => undefined,
      ),
      (error: unknown) =>
        error instanceof GatewayFailure && error.code === scenario.code,
    );
  }
});

test("provider HTTP failures distinguish credentials, model, and quota", async () => {
  for (const scenario of [
    {
      status: 401,
      providerType: "authentication_error",
      code: "groqAuthenticationFailed",
    },
    {
      status: 404,
      providerType: "model_not_found",
      code: "groqModelUnavailable",
    },
    {
      status: 400,
      providerType: "invalid_request_error",
      providerMessage: "The model has been decommissioned.",
      code: "groqModelUnavailable",
    },
    {
      status: 429,
      providerType: "rate_limit_exceeded",
      code: "groqRateLimited",
    },
    {
      status: 429,
      providerType: "quota_exceeded",
      code: "groqRateLimited",
    },
  ] as const) {
    const fetcher: typeof fetch = async () =>
      new Response(
        JSON.stringify({
          error: {
            type: scenario.providerType,
            ...("providerMessage" in scenario
              ? { message: scenario.providerMessage }
              : {}),
          },
        }),
        {
          status: scenario.status,
          headers: { "Content-Type": "application/json" },
        },
      );
    const client = new GroqChatCompletionsClient(config, fetcher);
    await assert.rejects(
      client.stream(
        {
          model: fixedModels.generalConversation,
          messages: [{ role: "user", content: "synthetic" }],
          maxOutputTokens: 700,
          temperature: 0.2,
        },
        () => undefined,
      ),
      (error: unknown) =>
        error instanceof GatewayFailure && error.code === scenario.code,
    );
  }
});

function byteStreamResponse(
  chunks: readonly Uint8Array[],
  status = 200,
): Response {
  return new Response(
    new ReadableStream<Uint8Array>({
      start(controller) {
        chunks.forEach((chunk) => controller.enqueue(chunk));
        controller.close();
      },
    }),
    {
      status,
      headers: { "Content-Type": "text/event-stream; charset=utf-8" },
    },
  );
}

test("general chat retries the same fixed model once before content", async () => {
  const { app, groq } = harness();
  groq.failStreamModels.add(fixedModels.generalConversation);
  const response = await authorized(
    request(app).post("/v1/ai/general-chat"),
  ).send(baseRequest("generalConversation"));
  assert.equal(response.status, 200);
  assert.equal(groq.streamRequests.length, 2);
  assert.ok(
    groq.streamRequests.every(
      (item) => item.model === fixedModels.generalConversation,
    ),
  );
  assert.match(response.text ?? "", /transientUpstreamRetry/);
});

test("client-supplied model fields are rejected", async () => {
  const { app, groq } = harness();
  const response = await authorized(
    request(app).post("/v1/ai/general-chat"),
  ).send({
    ...baseRequest("generalConversation"),
    model: "client-selected-model",
  });
  assert.equal(response.status, 400);
  assert.equal(groq.streamRequests.length, 0);
});

test("deferred models and tools cannot be selected by the client", async () => {
  const { app, groq } = harness();
  for (const toolId of [
    "qwen_qwen3_6_27b",
    "groq_compound_mini",
    "get_financial_insights",
    "delete_all_data",
  ]) {
    const response = await authorized(
      request(app).post("/v1/ai/tool-selection"),
    ).send({
      ...baseRequest("governedToolSelection"),
      allowedToolIds: [toolId],
    });
    assert.equal(response.status, 422);
  }
  assert.equal(groq.completionRequests.length, 0);
});

test("tool selection uses 20B and validates arguments locally", async () => {
  const { app, groq } = harness();
  groq.completionQueue.push(
    JSON.stringify({
      toolSelections: [
        { name: "calculate_savings_rate", arguments: {
          income: "2500",
          expense: "1800",
        } },
      ],
      clarification: null,
    }),
  );
  const response = await authorized(
    request(app).post("/v1/ai/tool-selection"),
  ).send({
    ...baseRequest("governedToolSelection"),
    allowedToolIds: ["calculate_savings_rate"],
  });
  assert.equal(response.status, 200);
  assert.match(response.text ?? "", /calculate_savings_rate/);
  assert.equal(
    groq.completionRequests[0]?.model,
    fixedModels.governedToolSelection,
  );
});

test("tool selection schema is strict and keeps money as strings", () => {
  const schema = toolSelectionJsonSchema([
    "calculate_savings_rate",
    "get_top_spending_categories",
  ]) as {
    schema: {
      properties: {
        toolSelections: {
          items: {
            anyOf: Array<{
              properties: {
                name: { enum: string[] };
                arguments: {
                  additionalProperties: boolean;
                  properties: Record<string, unknown>;
                };
              };
            }>;
          };
        };
      };
    };
  };
  const variants =
    schema.schema.properties.toolSelections.items.anyOf;
  const savings = variants.find(
    (item) =>
      item.properties.name.enum[0] === "calculate_savings_rate",
  );
  assert.equal(savings?.properties.arguments.additionalProperties, false);
  assert.deepEqual(
    savings?.properties.arguments.properties.income,
    {
      type: "string",
      pattern: "^-?(?:0|[1-9]\\d*)(?:\\.\\d{1,8})?$",
      maxLength: 40,
    },
  );
});

test("Flutter and gateway bounded read tool contracts stay aligned", () => {
  assert.deepEqual(
    intersectAllowedTools(["get_accounts_summary", "search_transactions"]),
    ["get_accounts_summary", "search_transactions"],
  );
  const schema = toolSelectionJsonSchema([
    "get_category_spending",
    "get_accounts_summary",
    "search_transactions",
  ]) as {
    schema: {
      properties: {
        toolSelections: {
          items: {
            anyOf: Array<{
              properties: {
                name: { enum: string[] };
                arguments: { properties: Record<string, unknown> };
              };
            }>;
          };
        };
      };
    };
  };
  const variants = schema.schema.properties.toolSelections.items.anyOf;
  const category = variants.find(
    (item) => item.properties.name.enum[0] === "get_category_spending",
  );
  const period = category?.properties.arguments.properties.period as {
    anyOf: Array<{ enum?: string[] }>;
  };
  assert.deepEqual(period.anyOf[0]?.enum, [
    "current_month",
    "previous_month",
    "year",
  ]);
});

test("invalid tool argument types fail without semantic retry", async () => {
  const { app, groq } = harness();
  groq.completionQueue.push(
    JSON.stringify({
      toolSelections: [
        {
          name: "calculate_savings_rate",
          arguments: { income: 2500, expense: 1800 },
        },
      ],
      clarification: null,
    }),
  );
  const response = await authorized(
    request(app).post("/v1/ai/tool-selection"),
  ).send({
    ...baseRequest("governedToolSelection"),
    allowedToolIds: ["calculate_savings_rate"],
  });
  assert.equal(response.status, 200);
  assert.match(response.text ?? "", /"code":"toolSelectionInvalid"/);
  assert.equal(groq.completionRequests.length, 1);
});

test("provider timeout retry is bounded to one same-model retry", async () => {
  const { app, groq } = harness();
  groq.completionQueue.push(
    new GatewayFailure("timeout", "Timed out."),
    new GatewayFailure("timeout", "Timed out again."),
  );
  const response = await authorized(
    request(app).post("/v1/ai/tool-selection"),
  ).send({
    ...baseRequest("governedToolSelection"),
    allowedToolIds: ["get_dashboard_summary"],
  });
  assert.equal(response.status, 200);
  assert.match(response.text ?? "", /"code":"timeout"/);
  assert.equal(groq.completionRequests.length, 2);
  assert.ok(
    groq.completionRequests.every(
      (item) => item.model === fixedModels.governedToolSelection,
    ),
  );
});

test("Retry-After quota failures are returned without immediate fallback", async () => {
  const { app, groq } = harness();
  groq.completionQueue.push(
    new GatewayFailure(
      "groqRateLimited",
      "Quota unavailable.",
      { retryAfterSeconds: 7 },
    ),
  );
  const response = await authorized(
    request(app).post("/v1/ai/tool-selection"),
  ).send({
    ...baseRequest("governedToolSelection"),
    allowedToolIds: ["get_dashboard_summary"],
  });
  assert.equal(response.status, 200);
  assert.match(
    response.text ?? "",
    /"code":"groqRateLimited"/,
  );
  assert.match(response.text ?? "", /"retryAfterSeconds":7/);
  assert.equal(groq.completionRequests.length, 1);
});

test("financial explanation uses bounded context and one correction only", async () => {
  const { app, groq } = harness();
  groq.completionQueue.push(
    "Income is 999 LYD.",
    "Income is 100 LYD and no action was performed.",
  );
  const response = await authorized(
    request(app).post("/v1/ai/financial-explanation"),
  ).send({
    ...baseRequest("financialExplanation"),
    sanitizedFinancialContext: {
      currency: "LYD",
      records: [
        {
          toolId: "get_dashboard_summary",
          partial: false,
          values: { monthlyIncome: "100" },
        },
      ],
      assumptions: [],
    },
  });
  assert.equal(response.status, 200);
  assert.match(response.text ?? "", /Income is 100 LYD/);
  assert.equal(groq.completionRequests.length, 2);
  assert.ok(
    groq.completionRequests.every(
      (item) => item.model === fixedModels.financialExplanation,
    ),
  );
});

test("financial correction exhaustion emits zero text deltas before safety", async () => {
  const { app, groq } = harness();
  groq.completionQueue.push(
    "Income is 999 LYD.",
    "Income is still 998 LYD.",
  );
  const response = await authorized(
    request(app).post("/v1/ai/financial-explanation"),
  ).send({
    ...baseRequest("financialExplanation"),
    sanitizedFinancialContext: {
      currency: "LYD",
      records: [
        {
          toolId: "get_dashboard_summary",
          partial: false,
          values: { monthlyIncome: "100" },
        },
      ],
      assumptions: [],
    },
  });

  assert.equal(response.status, 200);
  assert.equal(groq.completionRequests.length, 2);
  assert.match(response.text ?? "", /"code":"groqMalformedResponse"/);
  assert.doesNotMatch(response.text ?? "", /"type":"textDelta"/);
  assert.doesNotMatch(response.text ?? "", /"type":"completed"/);
  assert.doesNotMatch(response.text ?? "", /999|998/);
});

test("financial context rejects numeric money at the gateway boundary", async () => {
  const { app, groq } = harness();
  const response = await authorized(
    request(app).post("/v1/ai/financial-explanation"),
  ).send({
    ...baseRequest("financialExplanation"),
    sanitizedFinancialContext: {
      currency: "LYD",
      records: [
        {
          toolId: "get_dashboard_summary",
          partial: false,
          values: { monthlyIncome: 100 },
        },
      ],
      assumptions: [],
    },
  });
  assert.equal(response.status, 400);
  assert.equal(groq.completionRequests.length, 0);
});

test("financial mutation claims fail without semantic retry", async () => {
  const { app, groq } = harness();
  groq.completionQueue.push("I saved the budget.");
  const response = await authorized(
    request(app).post("/v1/ai/financial-explanation"),
  ).send({
    ...baseRequest("financialExplanation"),
    sanitizedFinancialContext: {
      currency: "LYD",
      records: [
        {
          toolId: "get_budget_summary",
          partial: false,
          values: { activeCount: 1, warningCount: 0, exceededCount: 0 },
        },
      ],
      assumptions: [],
    },
  });
  assert.equal(response.status, 200);
  assert.match(response.text ?? "", /"code":"groqMalformedResponse"/);
  assert.equal(groq.completionRequests.length, 1);
});

test("current information and unrestricted proxy endpoints do not exist", async () => {
  const { app, groq } = harness();
  for (const path of ["/v1/ai/current", "/v1/proxy"]) {
    const response = await authorized(request(app).post(path)).send({
      requestId: "request_12345",
    });
    assert.equal(response.status, 404);
  }
  assert.equal(groq.completionRequests.length, 0);
  assert.equal(groq.streamRequests.length, 0);
});

test("per-user rate limit blocks before a second provider call", async () => {
  const { app, groq, safeLogs } = harness({ maxRequests: 1 });
  const first = await authorized(
    request(app).post("/v1/ai/general-chat"),
  ).send(baseRequest("generalConversation"));
  assert.equal(first.status, 200);
  const second = await authorized(
    request(app).post("/v1/ai/general-chat"),
  ).send(baseRequest("generalConversation"));
  assert.equal(second.status, 429);
  assert.equal(second.body.failure.code, "groqRateLimited");
  assert.equal(typeof second.headers["retry-after"], "string");
  assert.equal(groq.streamRequests.length, 1);
  assert.equal(safeLogs.length, 2);
  assert.equal(safeLogs[1]?.rateLimitResult, "limited");
  assert.equal(safeLogs[1]?.typedErrorCode, "groqRateLimited");
  assert.equal(safeLogs[1]?.statusCode, 429);
  assert.doesNotMatch(JSON.stringify(safeLogs[1]), /verified-test-user/);
});
