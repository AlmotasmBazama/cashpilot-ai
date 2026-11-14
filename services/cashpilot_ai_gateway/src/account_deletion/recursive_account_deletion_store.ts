import type { App } from "firebase-admin/app";
import { createHash } from "node:crypto";
import {
  FieldValue,
  getFirestore,
  Timestamp,
  type Firestore,
} from "firebase-admin/firestore";
import type { AccountDeletionRecoveryEnvelope } from "./auth_session_commitment.js";
import { isFirebaseUserTreeEmpty } from "./firebase_user_tree.js";
import {
  AccountDeletionOperationConflict,
  type RecursiveAccountDeletionResult,
  type RecursiveAccountDeletionStore,
} from "./account_deletion_ports.js";

export { AccountDeletionOperationConflict };
export type {
  RecursiveAccountDeletionResult,
  RecursiveAccountDeletionStore,
} from "./account_deletion_ports.js";

export const accountDeletionContinuationTtlMs = 24 * 60 * 60 * 1_000;

export type AccountDeletionLockAcquireResult =
  | "created"
  | "resumed"
  | "conflict";

export interface AccountDeletionAdminBackend {
  acquireLock(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<AccountDeletionLockAcquireResult>;

  recursiveDeleteUser(uid: string): Promise<void>;

  verifyLock(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<boolean>;

  verifyUserTreeEmpty(uid: string): Promise<boolean>;

  recordVerifiedCloudDeletion(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<boolean>;
}

export function accountDeletionLockDocumentId(uid: string): string {
  return createHash("sha256")
    .update(uid, "utf8")
    .digest("hex")
    .toUpperCase();
}

/// Owns the lock-before-delete protocol independently of Firebase wiring so
/// idempotency and conflict behavior can be tested deterministically.
export class LockedRecursiveAccountDeletionStore
  implements RecursiveAccountDeletionStore
{
  constructor(private readonly backend: AccountDeletionAdminBackend) {}

  async deleteAndVerify(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<RecursiveAccountDeletionResult> {
    const lockDocumentId = accountDeletionLockDocumentId(uid);
    const acquired = await this.backend.acquireLock(
      lockDocumentId,
      operationId,
      authSessionCommitment,
      recoveryEnvelope,
    );
    if (acquired === "conflict") {
      throw new AccountDeletionOperationConflict();
    }

    // The opaque lock intentionally has no TTL. A partially deleted Auth user
    // can refresh tokens indefinitely, so an expiring lock would reopen writes
    // and permit another device to resurrect the recursively deleted tree.
    await this.backend.recursiveDeleteUser(uid);
    const [lockVerified, userTreeEmpty] = await Promise.all([
      this.backend.verifyLock(
        lockDocumentId,
        operationId,
        authSessionCommitment,
        recoveryEnvelope,
      ),
      this.backend.verifyUserTreeEmpty(uid),
    ]);
    const verifiedEmpty = lockVerified && userTreeEmpty;
    const completionRecorded =
      verifiedEmpty &&
      (await this.backend.recordVerifiedCloudDeletion(
        lockDocumentId,
        operationId,
        authSessionCommitment,
      ));
    return {
      // Admin recursiveDelete does not expose an exact document count. The
      // dual lock/tree proof, not a guessed count, is the safety boundary.
      deletedDocuments: 0,
      verifiedEmpty: completionRecorded,
    };
  }
}

export class FirebaseAdminAccountDeletionBackend
  implements AccountDeletionAdminBackend
{
  constructor(private readonly firestore: Firestore) {}

  async acquireLock(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<AccountDeletionLockAcquireResult> {
    const lock = this.firestore
      .collection("accountDeletionLocks")
      .doc(lockDocumentId);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(lock);
      if (!snapshot.exists) {
        transaction.create(lock, {
          version: 1,
          operationId,
          authSessionCommitment,
          recoveryEnvelopeVersion: recoveryEnvelope.version,
          recoveryOwnerScopeCommitment:
            recoveryEnvelope.ownerScopeCommitment,
          recoveryUidNonce: recoveryEnvelope.uidNonce,
          recoveryUidCiphertext: recoveryEnvelope.uidCiphertext,
          recoveryUidAuthenticationTag:
            recoveryEnvelope.uidAuthenticationTag,
          createdAt: FieldValue.serverTimestamp(),
          continuationExpiresAt: Timestamp.fromMillis(
            Date.now() + accountDeletionContinuationTtlMs,
          ),
        });
        return "created";
      }
      return snapshot.get("operationId") === operationId &&
        snapshot.get("authSessionCommitment") === authSessionCommitment &&
        snapshot.get("recoveryEnvelopeVersion") === 1 &&
        snapshot.get("recoveryOwnerScopeCommitment") ===
          recoveryEnvelope.ownerScopeCommitment &&
        typeof snapshot.get("recoveryUidNonce") === "string" &&
        typeof snapshot.get("recoveryUidCiphertext") === "string" &&
        typeof snapshot.get("recoveryUidAuthenticationTag") === "string"
        ? "resumed"
        : "conflict";
    });
  }

  async recursiveDeleteUser(uid: string): Promise<void> {
    await this.firestore.recursiveDelete(
      this.firestore.collection("users").doc(uid),
    );
  }

  async verifyLock(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<boolean> {
    const snapshot = await this.firestore
      .collection("accountDeletionLocks")
      .doc(lockDocumentId)
      .get();
    return (
      snapshot.exists &&
      snapshot.get("operationId") === operationId &&
      snapshot.get("authSessionCommitment") === authSessionCommitment &&
      snapshot.get("recoveryEnvelopeVersion") === 1 &&
      snapshot.get("recoveryOwnerScopeCommitment") ===
        recoveryEnvelope.ownerScopeCommitment
    );
  }

  async verifyUserTreeEmpty(uid: string): Promise<boolean> {
    return isFirebaseUserTreeEmpty(this.firestore, uid);
  }

  async recordVerifiedCloudDeletion(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<boolean> {
    const lock = this.firestore
      .collection("accountDeletionLocks")
      .doc(lockDocumentId);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(lock);
      if (
        !snapshot.exists ||
        snapshot.get("operationId") !== operationId ||
        snapshot.get("authSessionCommitment") !== authSessionCommitment
      ) {
        return false;
      }
      transaction.update(lock, {
        cloudDeletionMarkerVersion: 1,
        cloudDeletionOperationId: operationId,
        cloudDeletionAuthSessionCommitment: authSessionCommitment,
        cloudDeletionStatus: "verifiedEmpty",
        cloudDeletionVerifiedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
  }
}

/// Uses the Admin SDK recursive delete primitive so newly introduced and
/// arbitrarily nested child collections cannot be skipped by a client allowlist.
export class AdminRecursiveAccountDeletionStore
  implements RecursiveAccountDeletionStore
{
  private readonly delegate: LockedRecursiveAccountDeletionStore;

  constructor(app: App) {
    this.delegate = new LockedRecursiveAccountDeletionStore(
      new FirebaseAdminAccountDeletionBackend(getFirestore(app)),
    );
  }

  async deleteAndVerify(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<RecursiveAccountDeletionResult> {
    return this.delegate.deleteAndVerify(
      uid,
      operationId,
      authSessionCommitment,
      recoveryEnvelope,
    );
  }
}
