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

test("structured lifecycle logs contain all stages and no private values", async () => {
  const logs = new MemoryLogSink();
  const app = createAccountDeletionApp({
    config: testConfig,
    verifier: new AllowingVerifier(),
    rateLimiter: new NoopRateLimiter(),
    accountDeletion: new RecordingRecursiveStore(),
    accountAuthDeletion: new RecordingAuthStore(),
    logSink: logs,
    serviceRevision: "test-revision",
  });
  await request(app)
    .post("/v1/account-deletion/recursive")
    .set("Authorization", "Bearer private-auth-token")
    .set("X-Firebase-AppCheck", "private-app-check-token")
    .set("X-Cashpilot-Deletion-Session", deletionProof)
    .send({
      operationId,
      targetOwnerScope: deriveOwnerScopeCommitment(principal.uid),
    })
    .expect(200);
  const stages = logs.events.map((event) => event.stage);
  assert.deepEqual(stages, [
    "requestReceived",
    "authVerified",
    "appCheckVerified",
    "proofVerified",
    "deletionStarted",
    "recursiveDeleteCompleted",
    "verificationStarted",
    "verificationCompleted",
    "responseSent",
  ]);
  const serialized = JSON.stringify(logs.events);
  for (const forbidden of [
    principal.uid,
    deriveOwnerScopeCommitment(principal.uid),
    deletionProof,
    "private-auth-token",
    "private-app-check-token",
    "example.com",
    "financial",
  ]) {
    assert.equal(serialized.includes(forbidden), false);
  }
});
