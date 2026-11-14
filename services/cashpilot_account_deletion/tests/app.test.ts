import assert from "node:assert/strict";
import { test } from "node:test";
import request from "supertest";
import { createAccountDeletionApp } from "../src/app.js";
import { deriveOwnerScopeCommitment } from "../src/account_deletion/owner_scope_commitment.js";
import {
  AllowingVerifier,
  deletionProof,
  MemoryLogSink,
  NoopRateLimiter,
  operationId,
  principal,
  RecordingAuthStore,
  RecordingRecursiveStore,
  testConfig,
} from "./test_support.js";

function harness() {
  const recursive = new RecordingRecursiveStore();
  const auth = new RecordingAuthStore();
  const logs = new MemoryLogSink();
  const app = createAccountDeletionApp({
    config: testConfig,
    verifier: new AllowingVerifier(),
    rateLimiter: new NoopRateLimiter(),
    accountDeletion: recursive,
    accountAuthDeletion: auth,
    logSink: logs,
    serviceRevision: "test-revision",
  });
  return { app, recursive, auth, logs };
}

function validRequest() {
  return {
    operationId,
    targetOwnerScope: deriveOwnerScopeCommitment(principal.uid),
  };
}

test("health endpoint exposes only stable service metadata", async () => {
  const response = await request(harness().app).get("/health").expect(200);
  assert.deepEqual(response.body, {
    status: "ok",
    service: "cashpilot-account-deletion",
    version: "1.0.0",
    environment: "test",
  });
  assert.equal(response.headers["cache-control"], "no-store");
});

test("valid recursive request uses only the verified principal target", async () => {
  const current = harness();
  const response = await request(current.app)
    .post("/v1/account-deletion/recursive")
    .set("Authorization", "Bearer synthetic-auth-token")
    .set("X-Firebase-AppCheck", "synthetic-app-check")
    .set("X-Cashpilot-Deletion-Session", deletionProof)
    .send(validRequest())
    .expect(200);
  assert.equal(response.body.status, "completed");
  assert.equal(response.body.verifiedEmpty, true);
  assert.deepEqual(current.recursive.targets, [principal.uid]);
});

test("strict request schema rejects every client-supplied UID", async () => {
  const current = harness();
  const response = await request(current.app)
    .post("/v1/account-deletion/recursive")
    .set("Authorization", "Bearer synthetic-auth-token")
    .set("X-Firebase-AppCheck", "synthetic-app-check")
    .set("X-Cashpilot-Deletion-Session", deletionProof)
    .send({ ...validRequest(), uid: "another-user" })
    .expect(400);
  assert.equal(response.body.failure.code, "gatewayRequestInvalid");
  assert.deepEqual(current.recursive.targets, []);
});

test("method and content type are allowlisted", async () => {
  const current = harness();
  await request(current.app)
    .get("/v1/account-deletion/recursive")
    .expect(405);
  await request(current.app)
    .post("/v1/account-deletion/recursive")
    .set("Content-Type", "text/plain")
    .send("not-json")
    .expect(415);
  assert.deepEqual(current.recursive.targets, []);
});
