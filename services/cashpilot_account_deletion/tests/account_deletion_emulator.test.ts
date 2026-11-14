import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { after, before, test } from "node:test";
import { deleteApp, initializeApp, type App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import {
  getFirestore,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";
import {
  AccountDeletionOperationConflict,
  FirebaseAdminAccountDeletionBackend,
  LockedRecursiveAccountDeletionStore,
} from "../src/account_deletion/recursive_account_deletion_store.js";
import {
  AccountDeletionContinuationExpired,
  AccountDeletionNotReady,
  FirebaseAdminAccountAuthDeletionBackend,
  LockedAccountAuthDeletionStore,
} from "../src/account_deletion/account_auth_deletion_store.js";
import {
  deriveAccountDeletionAuthSessionCommitment,
  sealAccountDeletionRecoveryUid,
} from "../src/account_deletion/auth_session_commitment.js";
import { deriveOwnerScopeCommitment } from "../src/account_deletion/owner_scope_commitment.js";

const projectId = "demo-cashpilot-ai";
const appName = `cashpilot-account-deletion-emulator-${randomUUID()}`;

let app: App;
let firestore: Firestore;
let auth: Auth;

before(() => {
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST?.trim();
  if (emulatorHost === undefined || emulatorHost.length === 0) {
    throw new Error(
      "FIRESTORE_EMULATOR_HOST is required; refusing to run against Firestore.",
    );
  }
  const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST?.trim();
  if (authEmulatorHost === undefined || authEmulatorHost.length === 0) {
    throw new Error(
      "FIREBASE_AUTH_EMULATOR_HOST is required; refusing to run against Auth.",
    );
  }
  app = initializeApp({ projectId }, appName);
  firestore = getFirestore(app);
  auth = getAuth(app);
});

after(async () => {
  await firestore?.terminate();
  await deleteApp(app);
});

test("deleted-user emulator token falls through to proof-only recovery", async () => {
  const authEmulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST!;
  const signUpResponse = await fetch(
    `http://${authEmulatorHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  assert.equal(signUpResponse.ok, true);
  const signUp = (await signUpResponse.json()) as {
    localId?: unknown;
    idToken?: unknown;
  };
  assert.equal(typeof signUp.localId, "string");
  assert.equal(typeof signUp.idToken, "string");
  const uid = signUp.localId as string;
  const idToken = signUp.idToken as string;

  assert.equal((await auth.verifyIdToken(idToken, true)).uid, uid);
  await auth.deleteUser(uid);
  await assert.rejects(auth.verifyIdToken(idToken, true));
  // The Auth emulator rejects even checkRevoked=false after user deletion.
  // The route therefore proceeds to its App Check + proof-only, read-only
  // attestation path, covered by the gateway and backend tests.
  await assert.rejects(auth.verifyIdToken(idToken, false));
});

test("real Admin backends enforce cloud proof before deleting Auth", async () => {
  const uid = `emulator-user-${randomUUID()}`;
  const operationId = "01989f80-4e00-7000-8000-000000000101";
  const conflictingOperationId = "01989f80-4e00-7000-8000-000000000102";
  const deletionSessionProof = Buffer.alloc(32, 0).toString("base64url");
  const replacementSessionProof = Buffer.alloc(32, 1).toString("base64url");
  const ownerScopeCommitment = deriveOwnerScopeCommitment(uid);
  const authSessionCommitment =
    deriveAccountDeletionAuthSessionCommitment({
      uid,
      deletionSessionProof,
    });
  const replacementSessionCommitment =
    deriveAccountDeletionAuthSessionCommitment({
      uid,
      deletionSessionProof: replacementSessionProof,
    });
  const recoveryEnvelope = sealAccountDeletionRecoveryUid({
    uid,
    operationId,
    ownerScopeCommitment,
    authSessionCommitment,
    deletionSessionProof,
  });
  const replacementRecoveryEnvelope = sealAccountDeletionRecoveryUid({
    uid,
    operationId,
    ownerScopeCommitment,
    authSessionCommitment: replacementSessionCommitment,
    deletionSessionProof: replacementSessionProof,
  });
  const user = firestore.collection("users").doc(uid);
  const knownDocument = user.collection("accounts").doc("known-account");
  const unknownDocument = user.collection("futureFeature").doc("unknown-root");
  const deeplyNestedDocument = unknownDocument
    .collection("arbitraryNested")
    .doc("middle")
    .collection("anotherUnknownLevel")
    .doc("leaf");

  await Promise.all([
    auth.createUser({ uid }),
    user.set({ state: "seeded" }),
    knownDocument.set({ balance: "12.345" }),
    unknownDocument.set({ private: "unknown" }),
    deeplyNestedDocument.set({ private: "deeply-nested" }),
  ]);

  const store = new LockedRecursiveAccountDeletionStore(
    new FirebaseAdminAccountDeletionBackend(firestore),
  );
  const authStore = new LockedAccountAuthDeletionStore(
    new FirebaseAdminAccountAuthDeletionBackend(firestore, auth),
  );
  await assert.rejects(
    authStore.deleteAfterCloudCompletion(
      uid,
      operationId,
      authSessionCommitment,
      true,
    ),
    AccountDeletionNotReady,
  );
  assert.equal((await auth.getUser(uid)).uid, uid);

  const first = await store.deleteAndVerify(
    uid,
    operationId,
    authSessionCommitment,
    recoveryEnvelope,
  );

  assert.deepEqual(first, { deletedDocuments: 0, verifiedEmpty: true });
  const firstSnapshots = await Promise.all([
    user.get(),
    knownDocument.get(),
    unknownDocument.get(),
    deeplyNestedDocument.get(),
  ]);
  assert.equal(firstSnapshots.every((snapshot) => !snapshot.exists), true);
  assert.deepEqual(await user.listCollections(), []);

  const lockId = createHash("sha256")
    .update(uid, "utf8")
    .digest("hex")
    .toUpperCase();
  const lock = firestore.collection("accountDeletionLocks").doc(lockId);
  const lockSnapshot = await lock.get();
  assert.equal(lockSnapshot.exists, true);
  assert.equal(lockSnapshot.get("operationId"), operationId);
  assert.equal(
    lockSnapshot.get("authSessionCommitment"),
    authSessionCommitment,
  );
  assert.equal(lockSnapshot.get("recoveryEnvelopeVersion"), 1);
  assert.equal(
    lockSnapshot.get("recoveryOwnerScopeCommitment"),
    ownerScopeCommitment,
  );
  assert.equal(
    typeof lockSnapshot.get("continuationExpiresAt")?.toMillis,
    "function",
  );
  const persistedLockJson = JSON.stringify(lockSnapshot.data());
  assert.equal(persistedLockJson.includes(uid), false);
  assert.equal(persistedLockJson.includes(deletionSessionProof), false);
  assert.equal(lockSnapshot.get("cloudDeletionMarkerVersion"), 1);
  assert.equal(
    lockSnapshot.get("cloudDeletionOperationId"),
    operationId,
  );
  assert.equal(
    lockSnapshot.get("cloudDeletionAuthSessionCommitment"),
    authSessionCommitment,
  );
  assert.equal(
    lockSnapshot.get("cloudDeletionStatus"),
    "verifiedEmpty",
  );
  assert.equal(
    typeof lockSnapshot.get("cloudDeletionVerifiedAt")?.toMillis,
    "function",
  );

  // Admin writes bypass rules. Re-seeding proves that the same operation can
  // safely resume and recursively clean an unknown future tree again.
  const resumedUnknownDocument = user
    .collection("futureFeatureV2")
    .doc("unknown-after-first-pass")
    .collection("deep")
    .doc("leaf");
  await resumedUnknownDocument.set({ state: "resume-proof" });
  await assert.rejects(
    authStore.deleteAfterCloudCompletion(
      uid,
      operationId,
      authSessionCommitment,
      true,
    ),
    AccountDeletionNotReady,
  );
  assert.equal((await auth.getUser(uid)).uid, uid);

  const resumed = await store.deleteAndVerify(
    uid,
    operationId,
    authSessionCommitment,
    recoveryEnvelope,
  );
  assert.equal(resumed.verifiedEmpty, true);
  assert.equal((await resumedUnknownDocument.get()).exists, false);
  assert.deepEqual(await user.listCollections(), []);
  const resumedLock = await lock.get();
  assert.equal(resumedLock.get("operationId"), operationId);
  assert.equal(
    resumedLock.get("cloudDeletionOperationId"),
    operationId,
  );
  assert.equal(
    resumedLock.get("cloudDeletionStatus"),
    "verifiedEmpty",
  );

  // A different operation cannot take over the permanent lock or run another
  // recursive deletion after the original operation has claimed this owner.
  const conflictSentinel = user
    .collection("adminOnlyConflictProof")
    .doc("must-remain");
  await conflictSentinel.set({ state: "not-deleted-by-conflicting-operation" });
  await assert.rejects(
    store.deleteAndVerify(
      uid,
      conflictingOperationId,
      authSessionCommitment,
      sealAccountDeletionRecoveryUid({
        uid,
        operationId: conflictingOperationId,
        ownerScopeCommitment,
        authSessionCommitment,
        deletionSessionProof,
      }),
    ),
    AccountDeletionOperationConflict,
  );
  assert.equal((await conflictSentinel.get()).exists, true);
  assert.equal((await lock.get()).get("operationId"), operationId);
  await assert.rejects(
    authStore.deleteAfterCloudCompletion(
      uid,
      conflictingOperationId,
      authSessionCommitment,
      true,
    ),
    AccountDeletionOperationConflict,
  );
  await assert.rejects(
    authStore.deleteAfterCloudCompletion(
      uid,
      operationId,
      authSessionCommitment,
      true,
    ),
    AccountDeletionNotReady,
  );
  assert.equal((await auth.getUser(uid)).uid, uid);

  await assert.rejects(
    store.deleteAndVerify(
      uid,
      operationId,
      replacementSessionCommitment,
      replacementRecoveryEnvelope,
    ),
    AccountDeletionOperationConflict,
  );
  await assert.rejects(
    authStore.deleteAfterCloudCompletion(
      uid,
      operationId,
      replacementSessionCommitment,
      true,
    ),
    AccountDeletionOperationConflict,
  );
  assert.equal((await auth.getUser(uid)).uid, uid);

  const finalCloudPass = await store.deleteAndVerify(
    uid,
    operationId,
    authSessionCommitment,
    recoveryEnvelope,
  );
  assert.equal(finalCloudPass.verifiedEmpty, true);
  assert.equal((await conflictSentinel.get()).exists, false);

  // A proof-only recovery request is strictly read-only and cannot delete a
  // still-existing Auth user.
  await assert.rejects(
    authStore.confirmAlreadyDeletedByAttestation(
      operationId,
      ownerScopeCommitment,
      deletionSessionProof,
    ),
    AccountDeletionNotReady,
  );
  assert.equal((await auth.getUser(uid)).uid, uid);

  await lock.update({
    continuationExpiresAt: Timestamp.fromMillis(Date.now() - 1),
  });
  await assert.rejects(
    authStore.deleteAfterCloudCompletion(
      uid,
      operationId,
      authSessionCommitment,
      false,
    ),
    AccountDeletionContinuationExpired,
  );
  assert.equal((await auth.getUser(uid)).uid, uid);

  const authDeletion = await authStore.deleteAfterCloudCompletion(
    uid,
    operationId,
    authSessionCommitment,
    true,
  );
  assert.deepEqual(authDeletion, { alreadyDeleted: false });
  await assert.rejects(
    auth.getUser(uid),
    (error: unknown) =>
      typeof error === "object" &&
      error !== null &&
      Reflect.get(error, "code") === "auth/user-not-found",
  );

  const idempotentRetry = await authStore.deleteAfterCloudCompletion(
    uid,
    operationId,
    authSessionCommitment,
    true,
  );
  assert.deepEqual(idempotentRetry, { alreadyDeleted: true });
  const lostResponseRecovery =
    await authStore.confirmAlreadyDeletedAfterCloudCompletion(
      uid,
      operationId,
      authSessionCommitment,
    );
  assert.deepEqual(lostResponseRecovery, { alreadyDeleted: true });
  const proofOnlyRecovery =
    await authStore.confirmAlreadyDeletedByAttestation(
      operationId,
      ownerScopeCommitment,
      deletionSessionProof,
    );
  assert.deepEqual(proofOnlyRecovery, { alreadyDeleted: true });
  await assert.rejects(
    authStore.confirmAlreadyDeletedByAttestation(
      operationId,
      ownerScopeCommitment,
      replacementSessionProof,
    ),
    AccountDeletionOperationConflict,
  );

  await firestore.recursiveDelete(user);
});
