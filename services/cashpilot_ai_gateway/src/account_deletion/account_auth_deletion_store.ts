import type { App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { accountDeletionLockDocumentId } from "./recursive_account_deletion_store.js";
import { isFirebaseUserTreeEmpty } from "./firebase_user_tree.js";
import {
  deriveAccountDeletionAuthSessionCommitment,
  openAccountDeletionRecoveryUid,
  type AccountDeletionRecoveryEnvelope,
} from "./auth_session_commitment.js";
import { deriveOwnerScopeCommitment } from "./owner_scope_commitment.js";
import {
  AccountDeletionContinuationExpired,
  AccountDeletionNotReady,
  AccountDeletionOperationConflict,
  type AccountAuthDeletionResult,
  type AccountAuthDeletionStore,
} from "./account_deletion_ports.js";

export {
  AccountDeletionContinuationExpired,
  AccountDeletionNotReady,
};
export type {
  AccountAuthDeletionResult,
  AccountAuthDeletionStore,
} from "./account_deletion_ports.js";

export type CloudDeletionPrerequisite =
  | "ready"
  | "missing"
  | "expired"
  | "conflict";

export type AttestedAccountDeletionSession =
  | {
      readonly status: "ready";
      readonly uid: string;
      readonly authSessionCommitment: string;
    }
  | { readonly status: "missing" | "conflict" };

export type AccountAuthUserDeletionResult = "deleted" | "notFound";

export interface AccountAuthDeletionAdminBackend {
  cloudDeletionPrerequisite(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    allowExpiredContinuation: boolean,
  ): Promise<CloudDeletionPrerequisite>;

  recoverAttestedSession(
    operationId: string,
    ownerScopeCommitment: string,
    deletionSessionProof: string,
  ): Promise<AttestedAccountDeletionSession>;

  verifyUserTreeEmpty(uid: string): Promise<boolean>;

  deleteAuthUser(uid: string): Promise<AccountAuthUserDeletionResult>;

  readAuthUserState(uid: string): Promise<"exists" | "notFound">;
}

/// Requires both the permanent owner lock and the Admin-authored cloud-empty
/// marker before it reaches Firebase Auth. The live empty-tree recheck keeps a
/// privileged late write from turning a previously valid marker into authority
/// to delete Auth while cloud data still exists.
export class LockedAccountAuthDeletionStore
  implements AccountAuthDeletionStore
{
  constructor(private readonly backend: AccountAuthDeletionAdminBackend) {}

  async deleteAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    recentAuthenticationSatisfied: boolean,
  ): Promise<AccountAuthDeletionResult> {
    await this.assertCloudDeletionCompleted(
      uid,
      operationId,
      authSessionCommitment,
      recentAuthenticationSatisfied,
    );
    const result = await this.backend.deleteAuthUser(uid);
    return { alreadyDeleted: result === "notFound" };
  }

  async confirmAlreadyDeletedAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<AccountAuthDeletionResult> {
    await this.assertCloudDeletionCompleted(
      uid,
      operationId,
      authSessionCommitment,
      true,
    );
    if ((await this.backend.readAuthUserState(uid)) !== "notFound") {
      throw new AccountDeletionNotReady();
    }
    return { alreadyDeleted: true };
  }

  async confirmAlreadyDeletedByAttestation(
    operationId: string,
    ownerScopeCommitment: string,
    deletionSessionProof: string,
  ): Promise<AccountAuthDeletionResult> {
    const recovered = await this.backend.recoverAttestedSession(
      operationId,
      ownerScopeCommitment,
      deletionSessionProof,
    );
    if (recovered.status === "conflict") {
      throw new AccountDeletionOperationConflict();
    }
    if (recovered.status !== "ready") {
      throw new AccountDeletionNotReady();
    }
    await this.assertCloudDeletionCompleted(
      recovered.uid,
      operationId,
      recovered.authSessionCommitment,
      true,
    );
    if (
      (await this.backend.readAuthUserState(recovered.uid)) !==
      "notFound"
    ) {
      throw new AccountDeletionNotReady();
    }
    return { alreadyDeleted: true };
  }

  private async assertCloudDeletionCompleted(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    allowExpiredContinuation: boolean,
  ): Promise<void> {
    const lockDocumentId = accountDeletionLockDocumentId(uid);
    const prerequisite = await this.backend.cloudDeletionPrerequisite(
      lockDocumentId,
      operationId,
      authSessionCommitment,
      allowExpiredContinuation,
    );
    if (prerequisite === "conflict") {
      throw new AccountDeletionOperationConflict();
    }
    if (prerequisite === "expired") {
      throw new AccountDeletionContinuationExpired();
    }
    if (prerequisite !== "ready") {
      throw new AccountDeletionNotReady();
    }
    if (!(await this.backend.verifyUserTreeEmpty(uid))) {
      throw new AccountDeletionNotReady();
    }
  }
}

export class FirebaseAdminAccountAuthDeletionBackend
  implements AccountAuthDeletionAdminBackend
{
  constructor(
    private readonly firestore: Firestore,
    private readonly auth: Auth,
  ) {}

  async cloudDeletionPrerequisite(
    lockDocumentId: string,
    operationId: string,
    authSessionCommitment: string,
    allowExpiredContinuation: boolean,
  ): Promise<CloudDeletionPrerequisite> {
    const snapshot = await this.firestore
      .collection("accountDeletionLocks")
      .doc(lockDocumentId)
      .get();
    if (!snapshot.exists) {
      return "missing";
    }
    if (snapshot.get("operationId") !== operationId) {
      return "conflict";
    }
    if (snapshot.get("authSessionCommitment") !== authSessionCommitment) {
      return "conflict";
    }

    const markerOperationId = snapshot.get(
      "cloudDeletionOperationId",
    );
    if (
      typeof markerOperationId === "string" &&
      markerOperationId !== operationId
    ) {
      return "conflict";
    }
    const verifiedAt = snapshot.get("cloudDeletionVerifiedAt") as
      | { toMillis?: () => number }
      | undefined;
    const hasServerTimestamp =
      typeof verifiedAt?.toMillis === "function" &&
      Number.isFinite(verifiedAt.toMillis());
    const continuationExpiresAt = snapshot.get(
      "continuationExpiresAt",
    ) as { toMillis?: () => number } | undefined;
    const continuationExpiresAtMillis =
      typeof continuationExpiresAt?.toMillis === "function"
        ? continuationExpiresAt.toMillis()
        : Number.NaN;
    if (
      !allowExpiredContinuation &&
      (!Number.isFinite(continuationExpiresAtMillis) ||
        continuationExpiresAtMillis < Date.now())
    ) {
      return "expired";
    }
    return snapshot.get("cloudDeletionMarkerVersion") === 1 &&
      markerOperationId === operationId &&
      snapshot.get("cloudDeletionAuthSessionCommitment") ===
        authSessionCommitment &&
      snapshot.get("cloudDeletionStatus") === "verifiedEmpty" &&
      hasServerTimestamp
      ? "ready"
      : "missing";
  }

  async recoverAttestedSession(
    operationId: string,
    ownerScopeCommitment: string,
    deletionSessionProof: string,
  ): Promise<AttestedAccountDeletionSession> {
    const locks = await this.firestore
      .collection("accountDeletionLocks")
      .where(
        "recoveryOwnerScopeCommitment",
        "==",
        ownerScopeCommitment,
      )
      .limit(2)
      .get();
    if (locks.empty) {
      return { status: "missing" };
    }
    if (locks.size !== 1) {
      return { status: "conflict" };
    }
    const snapshot = locks.docs[0]!;
    if (
      snapshot.get("operationId") !== operationId ||
      snapshot.get("recoveryEnvelopeVersion") !== 1
    ) {
      return { status: "conflict" };
    }
    const authSessionCommitment = snapshot.get(
      "authSessionCommitment",
    );
    const envelope: AccountDeletionRecoveryEnvelope = {
      version: 1,
      ownerScopeCommitment,
      uidNonce: snapshot.get("recoveryUidNonce"),
      uidCiphertext: snapshot.get("recoveryUidCiphertext"),
      uidAuthenticationTag: snapshot.get(
        "recoveryUidAuthenticationTag",
      ),
    };
    if (typeof authSessionCommitment !== "string") {
      return { status: "conflict" };
    }
    try {
      const uid = openAccountDeletionRecoveryUid({
        envelope,
        operationId,
        authSessionCommitment,
        deletionSessionProof,
      });
      const expectedCommitment =
        deriveAccountDeletionAuthSessionCommitment({
          uid,
          deletionSessionProof,
        });
      if (
        expectedCommitment !== authSessionCommitment ||
        deriveOwnerScopeCommitment(uid) !== ownerScopeCommitment ||
        accountDeletionLockDocumentId(uid) !== snapshot.id
      ) {
        return { status: "conflict" };
      }
      return { status: "ready", uid, authSessionCommitment };
    } catch {
      return { status: "conflict" };
    }
  }

  async verifyUserTreeEmpty(uid: string): Promise<boolean> {
    return isFirebaseUserTreeEmpty(this.firestore, uid);
  }

  async deleteAuthUser(uid: string): Promise<AccountAuthUserDeletionResult> {
    try {
      await this.auth.deleteUser(uid);
      return "deleted";
    } catch (error) {
      if (firebaseAuthErrorCode(error) === "auth/user-not-found") {
        return "notFound";
      }
      throw error;
    }
  }

  async readAuthUserState(uid: string): Promise<"exists" | "notFound"> {
    try {
      await this.auth.getUser(uid);
      return "exists";
    } catch (error) {
      if (firebaseAuthErrorCode(error) === "auth/user-not-found") {
        return "notFound";
      }
      throw error;
    }
  }
}

function firebaseAuthErrorCode(error: unknown): string | undefined {
  if (typeof error !== "object" || error === null) {
    return undefined;
  }
  const direct = Reflect.get(error, "code");
  if (typeof direct === "string") {
    return direct;
  }
  const errorInfo = Reflect.get(error, "errorInfo");
  if (typeof errorInfo !== "object" || errorInfo === null) {
    return undefined;
  }
  const nested = Reflect.get(errorInfo, "code");
  return typeof nested === "string" ? nested : undefined;
}

export class AdminAccountAuthDeletionStore
  implements AccountAuthDeletionStore
{
  private readonly delegate: LockedAccountAuthDeletionStore;

  constructor(app: App) {
    this.delegate = new LockedAccountAuthDeletionStore(
      new FirebaseAdminAccountAuthDeletionBackend(
        getFirestore(app),
        getAuth(app),
      ),
    );
  }

  async deleteAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    recentAuthenticationSatisfied: boolean,
  ): Promise<AccountAuthDeletionResult> {
    return this.delegate.deleteAfterCloudCompletion(
      uid,
      operationId,
      authSessionCommitment,
      recentAuthenticationSatisfied,
    );
  }

  async confirmAlreadyDeletedAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<AccountAuthDeletionResult> {
    return this.delegate.confirmAlreadyDeletedAfterCloudCompletion(
      uid,
      operationId,
      authSessionCommitment,
    );
  }

  async confirmAlreadyDeletedByAttestation(
    operationId: string,
    ownerScopeCommitment: string,
    deletionSessionProof: string,
  ): Promise<AccountAuthDeletionResult> {
    return this.delegate.confirmAlreadyDeletedByAttestation(
      operationId,
      ownerScopeCommitment,
      deletionSessionProof,
    );
  }
}
