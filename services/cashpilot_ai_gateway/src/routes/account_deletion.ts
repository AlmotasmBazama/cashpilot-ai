import type { Request, Response } from "express";
import { sealAccountDeletionRecoveryUid } from "../account_deletion/auth_session_commitment.js";
import { GatewayFailure } from "../errors.js";
import {
  throwAccountAuthDeletionFailure,
  throwRecursiveAccountDeletionFailure,
} from "./account_deletion_failure_mapping.js";
import {
  assertAccountDeletionOwnerScope,
  deriveRequestAuthSessionCommitment,
  parseAccountDeletionRequest,
  readAccountDeletionSessionProof,
} from "./account_deletion_request.js";
import {
  verifyAccountAuthDeletionRequest,
  verifyRecentAccountDeletionPrincipal,
} from "./account_deletion_verification.js";
import type {
  AccountAuthDeletionRouteDependencies,
  RecursiveAccountDeletionRouteDependencies,
} from "./dependencies.js";

export function accountDeletionRoute(
  dependencies: RecursiveAccountDeletionRouteDependencies,
) {
  return async (request: Request, response: Response): Promise<void> => {
    const principal = await verifyRecentAccountDeletionPrincipal(
      request,
      dependencies,
      "recursive",
    );
    const deletionRequest = parseAccountDeletionRequest(request);
    assertAccountDeletionOwnerScope(
      principal.uid,
      deletionRequest.targetOwnerScope,
    );
    const deletionSessionProof = readAccountDeletionSessionProof(request);
    const sessionCommitment = deriveRequestAuthSessionCommitment(
      deletionSessionProof,
      principal,
    );
    const recoveryEnvelope = sealAccountDeletionRecoveryUid({
      uid: principal.uid,
      operationId: deletionRequest.operationId,
      ownerScopeCommitment: deletionRequest.targetOwnerScope,
      authSessionCommitment: sessionCommitment,
      deletionSessionProof,
    });
    const store = dependencies.accountDeletion;
    if (store === undefined) {
      throw new GatewayFailure(
        "configurationFailure",
        "Recursive account deletion is not configured.",
      );
    }

    let deletion;
    try {
      deletion = await store.deleteAndVerify(
        principal.uid,
        deletionRequest.operationId,
        sessionCommitment,
        recoveryEnvelope,
      );
    } catch (error) {
      throwRecursiveAccountDeletionFailure(error);
    }
    if (!deletion.verifiedEmpty) {
      throw new GatewayFailure(
        "providerUnavailable",
        "Recursive account deletion could not be verified.",
      );
    }
    response.status(200).json({
      operationId: deletionRequest.operationId,
      status: "completed",
      verifiedEmpty: true,
      deletedDocuments: deletion.deletedDocuments,
    });
  };
}

export function accountAuthDeletionRoute(
  dependencies: AccountAuthDeletionRouteDependencies,
) {
  return async (request: Request, response: Response): Promise<void> => {
    const deletionRequest = parseAccountDeletionRequest(request);
    const deletionSessionProof = readAccountDeletionSessionProof(request);
    const verification = await verifyAccountAuthDeletionRequest(
      request,
      dependencies,
    );
    if (verification.mode === "attestation") {
      dependencies.rateLimiter.consume(
        "account-deletion:auth-recovery:global",
      );
      dependencies.rateLimiter.consume(
        `account-deletion:auth-recovery:${deletionRequest.targetOwnerScope}`,
      );
    } else {
      assertAccountDeletionOwnerScope(
        verification.principal.uid,
        deletionRequest.targetOwnerScope,
      );
    }
    const store = dependencies.accountAuthDeletion;
    if (store === undefined) {
      throw new GatewayFailure(
        "configurationFailure",
        "Account Auth deletion is not configured.",
      );
    }

    let deletion;
    try {
      if (verification.mode === "attestation") {
        deletion = await store.confirmAlreadyDeletedByAttestation(
          deletionRequest.operationId,
          deletionRequest.targetOwnerScope,
          deletionSessionProof,
        );
      } else {
        const sessionCommitment = deriveRequestAuthSessionCommitment(
          deletionSessionProof,
          verification.principal,
        );
        deletion =
          verification.mode === "signedRecovery"
            ? await store.confirmAlreadyDeletedAfterCloudCompletion(
                verification.principal.uid,
                deletionRequest.operationId,
                sessionCommitment,
              )
            : await store.deleteAfterCloudCompletion(
                verification.principal.uid,
                deletionRequest.operationId,
                sessionCommitment,
                verification.recentAuthenticationSatisfied,
              );
      }
    } catch (error) {
      throwAccountAuthDeletionFailure(error);
    }

    response.status(200).json({
      operationId: deletionRequest.operationId,
      status: "completed",
      authDeleted: true,
      alreadyDeleted: deletion.alreadyDeleted,
    });
  };
}
