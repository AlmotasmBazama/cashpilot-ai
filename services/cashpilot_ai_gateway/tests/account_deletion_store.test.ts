import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import type { Auth } from "firebase-admin/auth";
import type { Firestore } from "firebase-admin/firestore";
import {
  AccountDeletionOperationConflict,
  LockedRecursiveAccountDeletionStore,
  type AccountDeletionAdminBackend,
  type AccountDeletionLockAcquireResult,
} from "../src/account_deletion/recursive_account_deletion_store.js";
import {
  AccountDeletionContinuationExpired,
  AccountDeletionNotReady,
  FirebaseAdminAccountAuthDeletionBackend,
  LockedAccountAuthDeletionStore,
  type AccountAuthDeletionAdminBackend,
  type AccountAuthUserDeletionResult,
  type AttestedAccountDeletionSession,
  type CloudDeletionPrerequisite,
} from "../src/account_deletion/account_auth_deletion_store.js";
import {
  deriveOwnerScopeCommitment,
  ownerScopeCommitmentMatches,
} from "../src/account_deletion/owner_scope_commitment.js";
import {
  decodeAccountDeletionSessionProof,
  deriveAccountDeletionAuthSessionCommitment,
  openAccountDeletionRecoveryUid,
  sealAccountDeletionRecoveryUid,
  type AccountDeletionRecoveryEnvelope,
} from "../src/account_deletion/auth_session_commitment.js";

const sessionA = "a".repeat(64);
const sessionB = "b".repeat(64);
const deletionSessionProofA = Buffer.alloc(32, 0).toString("base64url");
const deletionSessionProofB = Buffer.alloc(32, 1).toString("base64url");

function recoveryEnvelope(
  uid: string,
  operationId: string,
  authSessionCommitment = sessionA,
  deletionSessionProof = deletionSessionProofA,
): AccountDeletionRecoveryEnvelope {
  return sealAccountDeletionRecoveryUid({
    uid,
    operationId,
    ownerScopeCommitment: deriveOwnerScopeCommitment(uid),
    authSessionCommitment,
    deletionSessionProof,
  });
}

class FakeAccountDeletionAdminBackend
  implements AccountDeletionAdminBackend
{
  readonly locks = new Map<
    string,
    { operationId: string; authSessionCommitment: string }
  >();
  readonly deletedUsers: string[] = [];
  readonly completedCloudDeletions = new Map<
    string,
    { operationId: string; authSessionCommitment: string }
  >();
  readonly recoveryEnvelopes = new Map<
    string,
    AccountDeletionRecoveryEnvelope
  >();
  userTreeEmpty = true;
  lockVisibleAfterDelete = true;
  completionMarkerWritable = true;

  async acquireLock(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    envelope: AccountDeletionRecoveryEnvelope,
  ): Promise<AccountDeletionLockAcquireResult> {
    const existing = this.locks.get(lockDocumentId);
    if (existing === undefined) {
      this.locks.set(lockDocumentId, {
        operationId,
        authSessionCommitment,
      });
      this.recoveryEnvelopes.set(lockDocumentId, envelope);
      return "created";
    }
    return existing.operationId === operationId &&
      existing.authSessionCommitment === authSessionCommitment &&
      this.recoveryEnvelopes.get(lockDocumentId)
        ?.ownerScopeCommitment === envelope.ownerScopeCommitment
      ? "resumed"
      : "conflict";
  }

  async recursiveDeleteUser(uid: string): Promise<void> {
    this.deletedUsers.push(uid);
  }

  async verifyLock(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    envelope: AccountDeletionRecoveryEnvelope,
  ): Promise<boolean> {
    return (
      this.lockVisibleAfterDelete &&
      this.locks.get(lockDocumentId)?.operationId === operationId &&
      this.locks.get(lockDocumentId)?.authSessionCommitment ===
        authSessionCommitment &&
      this.recoveryEnvelopes.get(lockDocumentId)
        ?.ownerScopeCommitment === envelope.ownerScopeCommitment
    );
  }

  async verifyUserTreeEmpty(_uid: string): Promise<boolean> {
    return this.userTreeEmpty;
  }

  async recordVerifiedCloudDeletion(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<boolean> {
    if (
      !this.completionMarkerWritable ||
      this.locks.get(lockDocumentId)?.operationId !== operationId ||
      this.locks.get(lockDocumentId)?.authSessionCommitment !==
        authSessionCommitment
    ) {
      return false;
    }
    this.completedCloudDeletions.set(lockDocumentId, {
      operationId,
      authSessionCommitment,
    });
    return true;
  }
}

class FakeAccountAuthDeletionAdminBackend
  implements AccountAuthDeletionAdminBackend
{
  prerequisite: CloudDeletionPrerequisite = "ready";
  userTreeEmpty = true;
  deletionQueue: Array<AccountAuthUserDeletionResult | Error> = [
    "deleted",
  ];
  authUserState: "exists" | "notFound" = "exists";
  expectedSessionCommitment = sessionA;
  attestedSession: AttestedAccountDeletionSession = {
    status: "ready",
    uid: "user-a",
    authSessionCommitment: sessionA,
  };
  readonly events: string[] = [];

  async cloudDeletionPrerequisite(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    allowExpiredContinuation: boolean,
  ): Promise<CloudDeletionPrerequisite> {
    this.events.push(`prerequisite:${lockDocumentId}:${operationId}`);
    if (authSessionCommitment !== this.expectedSessionCommitment) {
      return "conflict";
    }
    return this.prerequisite === "expired" && allowExpiredContinuation
      ? "ready"
      : this.prerequisite;
  }

  async recoverAttestedSession(
    operationId: string,
    ownerScopeCommitment: string,
    _deletionSessionProof: string,
  ): Promise<AttestedAccountDeletionSession> {
    this.events.push(
      `attestation:${operationId}:${ownerScopeCommitment}`,
    );
    return this.attestedSession;
  }

  async verifyUserTreeEmpty(uid: string): Promise<boolean> {
    this.events.push(`tree:${uid}`);
    return this.userTreeEmpty;
  }

  async deleteAuthUser(uid: string): Promise<AccountAuthUserDeletionResult> {
    this.events.push(`auth:${uid}`);
    const next = this.deletionQueue.shift() ?? "deleted";
    if (next instanceof Error) {
      throw next;
    }
    return next;
  }

  async readAuthUserState(uid: string): Promise<"exists" | "notFound"> {
    this.events.push(`auth-state:${uid}`);
    return this.authUserState;
  }
}

test("deletion creates an opaque permanent lock before recursive delete", async () => {
  const backend = new FakeAccountDeletionAdminBackend();
  const store = new LockedRecursiveAccountDeletionStore(backend);
  const uid = "private-firebase-uid";
  const operationId = "01989f80-4e00-7000-8000-000000000001";

  const result = await store.deleteAndVerify(
    uid,
    operationId,
    sessionA,
    recoveryEnvelope(uid, operationId),
  );

  const expectedLockId = createHash("sha256")
    .update(uid, "utf8")
    .digest("hex")
    .toUpperCase();
  assert.deepEqual([...backend.locks.entries()], [
    [
      expectedLockId,
      { operationId, authSessionCommitment: sessionA },
    ],
  ]);
  assert.deepEqual(backend.deletedUsers, [uid]);
  assert.equal(result.verifiedEmpty, true);
  assert.deepEqual([...backend.completedCloudDeletions.entries()], [
    [
      expectedLockId,
      { operationId, authSessionCommitment: sessionA },
    ],
  ]);
  assert.doesNotMatch(expectedLockId, /private-firebase-uid/);
});

test("the same operation resumes but a conflicting operation is rejected", async () => {
  const backend = new FakeAccountDeletionAdminBackend();
  const store = new LockedRecursiveAccountDeletionStore(backend);
  const firstOperation = "01989f80-4e00-7000-8000-000000000001";
  const conflictingOperation = "01989f80-4e00-7000-8000-000000000002";

  await store.deleteAndVerify(
    "user-a",
    firstOperation,
    sessionA,
    recoveryEnvelope("user-a", firstOperation),
  );
  await store.deleteAndVerify(
    "user-a",
    firstOperation,
    sessionA,
    recoveryEnvelope("user-a", firstOperation),
  );
  await assert.rejects(
    store.deleteAndVerify(
      "user-a",
      conflictingOperation,
      sessionA,
      recoveryEnvelope("user-a", conflictingOperation),
    ),
    AccountDeletionOperationConflict,
  );

  assert.deepEqual(backend.deletedUsers, ["user-a", "user-a"]);
  assert.equal(backend.locks.size, 1);
});

test("the same uid and operation cannot resume from a replacement Auth session", async () => {
  const backend = new FakeAccountDeletionAdminBackend();
  const store = new LockedRecursiveAccountDeletionStore(backend);
  const operationId = "01989f80-4e00-7000-8000-000000000004";

  await store.deleteAndVerify(
    "user-a",
    operationId,
    sessionA,
    recoveryEnvelope("user-a", operationId),
  );
  await assert.rejects(
    store.deleteAndVerify(
      "user-a",
      operationId,
      sessionB,
      recoveryEnvelope(
        "user-a",
        operationId,
        sessionB,
        deletionSessionProofB,
      ),
    ),
    AccountDeletionOperationConflict,
  );
  assert.deepEqual(backend.deletedUsers, ["user-a"]);

  const authBackend = new FakeAccountAuthDeletionAdminBackend();
  await assert.rejects(
    new LockedAccountAuthDeletionStore(
      authBackend,
    ).deleteAfterCloudCompletion("user-a", operationId, sessionB, true),
    AccountDeletionOperationConflict,
  );
  assert.equal(
    authBackend.events.some((event) => event.startsWith("auth:")),
    false,
  );
});

test("completion is unverified if either lock or user-tree proof is absent", async () => {
  const missingLockBackend = new FakeAccountDeletionAdminBackend();
  missingLockBackend.lockVisibleAfterDelete = false;
  const missingLock = await new LockedRecursiveAccountDeletionStore(
    missingLockBackend,
  ).deleteAndVerify(
    "user-a",
    "01989f80-4e00-7000-8000-000000000001",
    sessionA,
    recoveryEnvelope(
      "user-a",
      "01989f80-4e00-7000-8000-000000000001",
    ),
  );
  assert.equal(missingLock.verifiedEmpty, false);

  const nonEmptyBackend = new FakeAccountDeletionAdminBackend();
  nonEmptyBackend.userTreeEmpty = false;
  const nonEmpty = await new LockedRecursiveAccountDeletionStore(
    nonEmptyBackend,
  ).deleteAndVerify(
    "user-b",
    "01989f80-4e00-7000-8000-000000000002",
    sessionA,
    recoveryEnvelope(
      "user-b",
      "01989f80-4e00-7000-8000-000000000002",
    ),
  );
  assert.equal(nonEmpty.verifiedEmpty, false);
  assert.equal(nonEmptyBackend.completedCloudDeletions.size, 0);

  const missingMarkerBackend = new FakeAccountDeletionAdminBackend();
  missingMarkerBackend.completionMarkerWritable = false;
  const missingMarker = await new LockedRecursiveAccountDeletionStore(
    missingMarkerBackend,
  ).deleteAndVerify(
    "user-c",
    "01989f80-4e00-7000-8000-000000000003",
    sessionA,
    recoveryEnvelope(
      "user-c",
      "01989f80-4e00-7000-8000-000000000003",
    ),
  );
  assert.equal(missingMarker.verifiedEmpty, false);
  assert.equal(missingMarkerBackend.completedCloudDeletions.size, 0);
});

test("Auth deletion requires the same completed cloud operation and an empty tree", async () => {
  const operationId = "01989f80-4e00-7000-8000-000000000011";
  for (const scenario of [
    { prerequisite: "missing" as const, userTreeEmpty: true },
    { prerequisite: "ready" as const, userTreeEmpty: false },
  ]) {
    const backend = new FakeAccountAuthDeletionAdminBackend();
    backend.prerequisite = scenario.prerequisite;
    backend.userTreeEmpty = scenario.userTreeEmpty;

    await assert.rejects(
      new LockedAccountAuthDeletionStore(
        backend,
      ).deleteAfterCloudCompletion(
        "user-a",
        operationId,
        sessionA,
        true,
      ),
      AccountDeletionNotReady,
    );
    assert.equal(
      backend.events.some((event) => event.startsWith("auth:")),
      false,
    );
  }
});

test("a conflicting cloud operation cannot delete Auth", async () => {
  const backend = new FakeAccountAuthDeletionAdminBackend();
  backend.prerequisite = "conflict";

  await assert.rejects(
    new LockedAccountAuthDeletionStore(
      backend,
    ).deleteAfterCloudCompletion(
      "user-a",
      "01989f80-4e00-7000-8000-000000000012",
      sessionA,
      true,
    ),
    AccountDeletionOperationConflict,
  );
  assert.equal(
    backend.events.some((event) => event.startsWith("auth:")),
    false,
  );
});

test("continuation deadline allows stale refresh in-window and requires fresh auth after expiry", async () => {
  const backend = new FakeAccountAuthDeletionAdminBackend();
  backend.prerequisite = "expired";
  const store = new LockedAccountAuthDeletionStore(backend);
  const operationId = "01989f80-4e00-7000-8000-000000000017";

  await assert.rejects(
    store.deleteAfterCloudCompletion(
      "user-a",
      operationId,
      sessionA,
      false,
    ),
    AccountDeletionContinuationExpired,
  );
  assert.equal(
    backend.events.some((event) => event.startsWith("auth:")),
    false,
  );

  const resumed = await store.deleteAfterCloudCompletion(
    "user-a",
    operationId,
    sessionA,
    true,
  );
  assert.deepEqual(resumed, { alreadyDeleted: false });
});

test("Auth deletion is principal-bound, ordered after proof, and idempotent on user-not-found", async () => {
  const backend = new FakeAccountAuthDeletionAdminBackend();
  backend.deletionQueue = [new Error("synthetic Auth outage"), "notFound"];
  const store = new LockedAccountAuthDeletionStore(backend);
  const uid = "private-auth-uid";
  const operationId = "01989f80-4e00-7000-8000-000000000013";

  await assert.rejects(
    store.deleteAfterCloudCompletion(uid, operationId, sessionA, true),
    /synthetic Auth outage/,
  );
  const resumed = await store.deleteAfterCloudCompletion(
    uid,
    operationId,
    sessionA,
    true,
  );

  const expectedLockId = createHash("sha256")
    .update(uid, "utf8")
    .digest("hex")
    .toUpperCase();
  assert.deepEqual(resumed, { alreadyDeleted: true });
  assert.deepEqual(backend.events, [
    `prerequisite:${expectedLockId}:${operationId}`,
    `tree:${uid}`,
    `auth:${uid}`,
    `prerequisite:${expectedLockId}:${operationId}`,
    `tree:${uid}`,
    `auth:${uid}`,
  ]);
  assert.doesNotMatch(expectedLockId, /private-auth-uid/);
});

test("lost-response recovery is read-only and requires an already absent Auth user", async () => {
  const operationId = "01989f80-4e00-7000-8000-000000000014";
  const absent = new FakeAccountAuthDeletionAdminBackend();
  absent.authUserState = "notFound";
  const recovered = await new LockedAccountAuthDeletionStore(
    absent,
  ).confirmAlreadyDeletedAfterCloudCompletion(
    "user-a",
    operationId,
    sessionA,
  );
  assert.deepEqual(recovered, { alreadyDeleted: true });
  assert.equal(
    absent.events.some((event) => event.startsWith("auth:user")),
    false,
  );
  assert.equal(
    absent.events.some((event) => event === "auth-state:user-a"),
    true,
  );

  const existing = new FakeAccountAuthDeletionAdminBackend();
  await assert.rejects(
    new LockedAccountAuthDeletionStore(
      existing,
    ).confirmAlreadyDeletedAfterCloudCompletion(
      "user-a",
      operationId,
      sessionA,
    ),
    AccountDeletionNotReady,
  );
  assert.equal(
    existing.events.some((event) => event.startsWith("auth:user")),
    false,
  );
});

test("proof-only attestation is read-only and requires Auth to be absent", async () => {
  const operationId = "01989f80-4e00-7000-8000-000000000018";
  const ownerScopeCommitment = deriveOwnerScopeCommitment("user-a");
  const absent = new FakeAccountAuthDeletionAdminBackend();
  absent.authUserState = "notFound";
  const recovered = await new LockedAccountAuthDeletionStore(
    absent,
  ).confirmAlreadyDeletedByAttestation(
    operationId,
    ownerScopeCommitment,
    deletionSessionProofA,
  );
  assert.deepEqual(recovered, { alreadyDeleted: true });
  assert.equal(
    absent.events.some((event) => event.startsWith("auth:user")),
    false,
  );

  const existing = new FakeAccountAuthDeletionAdminBackend();
  await assert.rejects(
    new LockedAccountAuthDeletionStore(
      existing,
    ).confirmAlreadyDeletedByAttestation(
      operationId,
      ownerScopeCommitment,
      deletionSessionProofA,
    ),
    AccountDeletionNotReady,
  );
  assert.equal(
    existing.events.some((event) => event.startsWith("auth:user")),
    false,
  );
});

test("an absent Auth user cannot recover before the cloud marker exists", async () => {
  const backend = new FakeAccountAuthDeletionAdminBackend();
  backend.prerequisite = "missing";
  backend.authUserState = "notFound";

  await assert.rejects(
    new LockedAccountAuthDeletionStore(
      backend,
    ).confirmAlreadyDeletedAfterCloudCompletion(
      "user-a",
      "01989f80-4e00-7000-8000-000000000015",
      sessionA,
    ),
    AccountDeletionNotReady,
  );
  assert.equal(
    backend.events.some((event) => event.startsWith("auth-state:")),
    false,
  );
  assert.equal(
    backend.events.some((event) => event.startsWith("auth:")),
    false,
  );
});

test("owner commitment exactly matches the Flutter domain-separated derivation", () => {
  const expected =
    "8a8f267a90a17f57d33d1f4246b0d853f057fa4c6a40270c8fdc99490072cdce";
  assert.equal(deriveOwnerScopeCommitment("user-a"), expected);
  assert.throws(
    () => deriveOwnerScopeCommitment(" user-a "),
    /canonical Firebase UID/,
  );
  assert.equal(ownerScopeCommitmentMatches("user-a", expected), true);
  assert.equal(
    ownerScopeCommitmentMatches("user-b", expected),
    false,
  );
  assert.equal(
    ownerScopeCommitmentMatches("user-a", expected.toUpperCase()),
    false,
  );
  assert.equal(
    ownerScopeCommitmentMatches(" user-a ", expected),
    false,
  );
});

test("Auth session commitment survives refresh and reauth but changes on raw relogin", () => {
  const original = deriveAccountDeletionAuthSessionCommitment({
    uid: "user-a",
    deletionSessionProof: deletionSessionProofA,
  });
  const refreshed = deriveAccountDeletionAuthSessionCommitment({
    uid: "user-a",
    deletionSessionProof: deletionSessionProofA,
  });
  const reauthenticated = deriveAccountDeletionAuthSessionCommitment({
    uid: "user-a",
    deletionSessionProof: deletionSessionProofA,
  });
  const relogged = deriveAccountDeletionAuthSessionCommitment({
    uid: "user-a",
    deletionSessionProof: deletionSessionProofB,
  });
  const differentUid = deriveAccountDeletionAuthSessionCommitment({
    uid: "user-b",
    deletionSessionProof: deletionSessionProofA,
  });

  assert.equal(original, refreshed);
  assert.equal(original, reauthenticated);
  assert.notEqual(original, relogged);
  assert.notEqual(original, differentUid);
  assert.match(original, /^[0-9a-f]{64}$/);
});

test("recovery envelope stores neither raw UID nor raw proof and rejects substitution", () => {
  const uid = "private-recovery-user";
  const operationId = "01989f80-4e00-7000-8000-000000000016";
  const authSessionCommitment =
    deriveAccountDeletionAuthSessionCommitment({
      uid,
      deletionSessionProof: deletionSessionProofA,
    });
  const envelope = sealAccountDeletionRecoveryUid({
    uid,
    operationId,
    ownerScopeCommitment: deriveOwnerScopeCommitment(uid),
    authSessionCommitment,
    deletionSessionProof: deletionSessionProofA,
  });

  assert.equal(JSON.stringify(envelope).includes(uid), false);
  assert.equal(
    JSON.stringify(envelope).includes(deletionSessionProofA),
    false,
  );
  assert.equal(
    openAccountDeletionRecoveryUid({
      envelope,
      operationId,
      authSessionCommitment,
      deletionSessionProof: deletionSessionProofA,
    }),
    uid,
  );
  assert.throws(
    () =>
      openAccountDeletionRecoveryUid({
        envelope,
        operationId,
        authSessionCommitment,
        deletionSessionProof: deletionSessionProofB,
      }),
  );
});

test("deletion proof parser rejects malformed and noncanonical base64url", () => {
  assert.equal(
    decodeAccountDeletionSessionProof(deletionSessionProofA).length,
    32,
  );
  for (const invalid of [
    "",
    "short",
    `${deletionSessionProofA}=`,
    "*".repeat(43),
    `${"A".repeat(42)}B`,
  ]) {
    assert.throws(() => decodeAccountDeletionSessionProof(invalid));
  }
});

test("Firebase Auth backend treats only auth/user-not-found as idempotent", async () => {
  const userNotFound = Object.assign(new Error("absent"), {
    code: "auth/user-not-found",
  });
  const authFailure = Object.assign(new Error("outage"), {
    code: "auth/internal-error",
  });
  let deleteFailure: Error = userNotFound;
  let readFailure: Error = userNotFound;
  const auth = {
    async deleteUser() {
      throw deleteFailure;
    },
    async getUser() {
      throw readFailure;
    },
  } as unknown as Auth;
  const backend = new FirebaseAdminAccountAuthDeletionBackend(
    {} as Firestore,
    auth,
  );

  assert.equal(await backend.deleteAuthUser("user-a"), "notFound");
  assert.equal(await backend.readAuthUserState("user-a"), "notFound");

  deleteFailure = authFailure;
  readFailure = authFailure;
  await assert.rejects(backend.deleteAuthUser("user-a"), authFailure);
  await assert.rejects(backend.readAuthUserState("user-a"), authFailure);
});
