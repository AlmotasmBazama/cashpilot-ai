import assert from "node:assert/strict";
import { test } from "node:test";
import type { App } from "firebase-admin/app";
import type { VerifyAppCheckTokenResponse } from "firebase-admin/app-check";
import type { DecodedIdToken } from "firebase-admin/auth";
import request from "supertest";
import {
  OfficialFirebaseRequestVerifier,
  type FirebaseRequestVerificationBackend,
} from "../src/auth/request_verifier.js";
import { GatewayFailure } from "../src/errors.js";
import { createAccountDeletionApp } from "../src/app.js";
import { deriveOwnerScopeCommitment } from "../src/account_deletion/owner_scope_commitment.js";
import { AccountDeletionProviderFailure } from "../src/account_deletion/account_deletion_ports.js";
import {
  deletionProof,
  MemoryLogSink,
  NoopRateLimiter,
  operationId,
  principal,
  RecordingAuthStore,
  RecordingRecursiveStore,
  testConfig,
} from "./test_support.js";

class FakeVerificationBackend implements FirebaseRequestVerificationBackend {
  authFailure?: Error;
  appCheckFailure?: Error;
  audience = "cashpilot-ai-a6b49";
  uid = principal.uid;
  authCalls: boolean[] = [];
  appCheckCalls = 0;

  async verifyIdToken(
    _token: string,
    checkRevoked: boolean,
  ): Promise<DecodedIdToken> {
    this.authCalls.push(checkRevoked);
    if (this.authFailure !== undefined) {
      throw this.authFailure;
    }
    return {
      aud: this.audience,
      uid: this.uid,
      sub: this.uid,
      auth_time: Math.floor(Date.now() / 1000),
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 3600,
      iss: `https://securetoken.google.com/${this.audience}`,
      firebase: {
        identities: {},
        sign_in_provider: "password",
      },
    } as DecodedIdToken;
  }

  async verifyAppCheckToken(
    _token: string,
  ): Promise<VerifyAppCheckTokenResponse> {
    this.appCheckCalls += 1;
    if (this.appCheckFailure !== undefined) {
      throw this.appCheckFailure;
    }
    return {
      appId: "1:123:android:abcdef",
      token: {
        app_id: "1:123:android:abcdef",
        aud: ["projects/123"],
        exp: Math.floor(Date.now() / 1000) + 3600,
        iat: Math.floor(Date.now() / 1000),
        iss: "https://firebaseappcheck.googleapis.com/123",
        sub: "1:123:android:abcdef",
      },
    };
  }
}

function headerRequest(headers: Record<string, string>) {
  const normalized = new Map(
    Object.entries(headers).map(([key, value]) => [key.toLowerCase(), value]),
  );
  return { header: (name: string) => normalized.get(name.toLowerCase()) };
}

test("missing and invalid Auth are rejected without App Check fallback", async () => {
  const backend = new FakeVerificationBackend();
  const verifier = new OfficialFirebaseRequestVerifier(
    "cashpilot-ai-a6b49",
    {} as App,
    backend,
  );
  await assert.rejects(
    verifier.verify(headerRequest({ "X-Firebase-AppCheck": "check" })),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "authenticationRequired",
  );
  backend.authFailure = new Error("raw-token-value");
  await assert.rejects(
    verifier.verify(
      headerRequest({
        Authorization: "Bearer invalid",
        "X-Firebase-AppCheck": "check",
      }),
    ),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "authenticationRequired" &&
      !error.message.includes("raw-token-value"),
  );
});

test("revoked Auth and wrong Firebase audience are rejected", async () => {
  const backend = new FakeVerificationBackend();
  const verifier = new OfficialFirebaseRequestVerifier(
    "cashpilot-ai-a6b49",
    {} as App,
    backend,
  );
  backend.authFailure = new Error("revoked");
  await assert.rejects(
    verifier.verify(
      headerRequest({
        Authorization: "Bearer revoked",
        "X-Firebase-AppCheck": "check",
      }),
    ),
    GatewayFailure,
  );
  delete backend.authFailure;
  backend.audience = "wrong-project";
  await assert.rejects(
    verifier.verify(
      headerRequest({
        Authorization: "Bearer valid",
        "X-Firebase-AppCheck": "check",
      }),
    ),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "authenticationRequired",
  );
  assert.deepEqual(backend.authCalls, [true, true]);
});

test("missing and invalid App Check are rejected with a closed code", async () => {
  const backend = new FakeVerificationBackend();
  const verifier = new OfficialFirebaseRequestVerifier(
    "cashpilot-ai-a6b49",
    {} as App,
    backend,
  );
  await assert.rejects(
    verifier.verify(headerRequest({ Authorization: "Bearer valid" })),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "appCheckUnavailable",
  );
  backend.appCheckFailure = new Error("private-app-check-token");
  await assert.rejects(
    verifier.verify(
      headerRequest({
        Authorization: "Bearer valid",
        "X-Firebase-AppCheck": "invalid",
      }),
    ),
    (error: unknown) =>
      error instanceof GatewayFailure &&
      error.code === "appCheckUnavailable" &&
      !error.message.includes("private-app-check-token"),
  );
});

test("missing or invalid deletion proof never reaches the store", async () => {
  const recursive = new RecordingRecursiveStore();
  const app = createAccountDeletionApp({
    config: testConfig,
    verifier: {
      verify: async () => principal,
    },
    rateLimiter: new NoopRateLimiter(),
    accountDeletion: recursive,
    accountAuthDeletion: new RecordingAuthStore(),
    logSink: new MemoryLogSink(),
    serviceRevision: "test-revision",
  });
  const body = {
    operationId,
    targetOwnerScope: deriveOwnerScopeCommitment(principal.uid),
  };
  for (const proof of [undefined, "not-a-proof"]) {
    let pending = request(app)
      .post("/v1/account-deletion/recursive")
      .set("Authorization", "Bearer valid")
      .set("X-Firebase-AppCheck", "valid");
    if (proof !== undefined) {
      pending = pending.set("X-Cashpilot-Deletion-Session", proof);
    }
    const response = await pending.send(body).expect(401);
    assert.equal(response.body.failure.code, "deletionProofInvalid");
  }
  assert.deepEqual(recursive.targets, []);
});

test("mismatched owner commitment cannot target another user", async () => {
  const recursive = new RecordingRecursiveStore();
  const app = createAccountDeletionApp({
    config: testConfig,
    verifier: { verify: async () => principal },
    rateLimiter: new NoopRateLimiter(),
    accountDeletion: recursive,
    accountAuthDeletion: new RecordingAuthStore(),
    logSink: new MemoryLogSink(),
    serviceRevision: "test-revision",
  });
  const response = await request(app)
    .post("/v1/account-deletion/recursive")
    .set("Authorization", "Bearer valid")
    .set("X-Firebase-AppCheck", "valid")
    .set("X-Cashpilot-Deletion-Session", deletionProof)
    .send({
      operationId,
      targetOwnerScope: deriveOwnerScopeCommitment("another-user"),
    })
    .expect(409);
  assert.equal(response.body.failure.code, "operationConflict");
  assert.deepEqual(recursive.targets, []);
});

test("Admin failures return no raw exception or arbitrary path", async () => {
  const recursive = new RecordingRecursiveStore();
  recursive.failure = new AccountDeletionProviderFailure(
    "permissionDenied",
    "firebasePermissionDenied",
    false,
  );
  const app = createAccountDeletionApp({
    config: testConfig,
    verifier: { verify: async () => principal },
    rateLimiter: new NoopRateLimiter(),
    accountDeletion: recursive,
    accountAuthDeletion: new RecordingAuthStore(),
    logSink: new MemoryLogSink(),
    serviceRevision: "test-revision",
  });
  const response = await request(app)
    .post("/v1/account-deletion/recursive")
    .set("Authorization", "Bearer valid")
    .set("X-Firebase-AppCheck", "valid")
    .set("X-Cashpilot-Deletion-Session", deletionProof)
    .send({
      operationId,
      targetOwnerScope: deriveOwnerScopeCommitment(principal.uid),
    })
    .expect(503);
  assert.equal(response.body.failure.code, "permissionDenied");
  const serialized = JSON.stringify(response.body);
  assert.doesNotMatch(serialized, /synthetic-user-a|users\//u);
  assert.doesNotMatch(serialized, /firebasePermissionDenied/u);
});
