import type { AccountDeletionRecoveryEnvelope } from "./auth_session_commitment.js";

export interface RecursiveAccountDeletionResult {
  readonly deletedDocuments: number;
  readonly verifiedEmpty: boolean;
}

export interface RecursiveAccountDeletionStore {
  deleteAndVerify(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<RecursiveAccountDeletionResult>;
}

export interface AccountAuthDeletionResult {
  readonly alreadyDeleted: boolean;
}

export interface AccountAuthDeletionStore {
  deleteAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
    recentAuthenticationSatisfied: boolean,
  ): Promise<AccountAuthDeletionResult>;

  confirmAlreadyDeletedAfterCloudCompletion(
    uid: string,
    operationId: string,
    authSessionCommitment: string,
  ): Promise<AccountAuthDeletionResult>;

  confirmAlreadyDeletedByAttestation(
    operationId: string,
    ownerScopeCommitment: string,
    deletionSessionProof: string,
  ): Promise<AccountAuthDeletionResult>;
}

export class AccountDeletionOperationConflict extends Error {
  constructor() {
    super("A different account deletion operation already owns the lock.");
    this.name = "AccountDeletionOperationConflict";
  }
}

export class AccountDeletionNotReady extends Error {
  constructor() {
    super("Verified recursive account deletion has not completed.");
    this.name = "AccountDeletionNotReady";
  }
}

export class AccountDeletionContinuationExpired extends Error {
  constructor() {
    super("The account-deletion continuation requires fresh authentication.");
    this.name = "AccountDeletionContinuationExpired";
  }
}

export type AccountDeletionProviderFailureCode =
  | "permissionDenied"
  | "providerUnavailable"
  | "cloudDeleteTimedOut"
  | "cloudDeletePartial"
  | "cloudVerificationFailed";

export class AccountDeletionProviderFailure extends Error {
  constructor(
    readonly code: AccountDeletionProviderFailureCode,
    readonly safeErrorClass: string,
    readonly retryable: boolean,
  ) {
    super(`Account deletion provider failed (${code}).`);
    this.name = "AccountDeletionProviderFailure";
  }
}
