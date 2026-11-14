import type { Request, Response } from "express";
import { sealAccountDeletionRecoveryUid } from "../account_deletion/auth_session_commitment.js";
import { GatewayFailure } from "../errors.js";
import type {
  AccountDeletionLogStage,
  SafeAccountDeletionLogEvent,
} from "../observability.js";
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

type DeletionRouteDependencies =
  | RecursiveAccountDeletionRouteDependencies
  | AccountAuthDeletionRouteDependencies;

function logStage(
  _request: Request,
  response: Response,
  dependencies: DeletionRouteDependencies,
  stage: AccountDeletionLogStage,
  operationId: string,
  options: {
    documentCount?: number;
    resultCode?: string;
  } = {},
): void {
  response.locals.operationId = operationId;
  const event: SafeAccountDeletionLogEvent = {
    correlationId: response.locals.correlationId as string,
    operationId,
    serviceRevision: dependencies.serviceRevision,
    stage,
    durationMs: Date.now() - (response.locals.startedAtMs as number),
    attempt: 1,
    ...options,
  };
  dependencies.logSink.write(event);
}

export function accountDeletionRoute(
  dependencies: RecursiveAccountDeletionRouteDependencies,
) {
  return async (request: Request, response: Response): Promise<void> => {
    const deletionRequest = parseAccountDeletionRequest(request);
    logStage(
      request,
      response,
      dependencies,
      "requestReceived",
      deletionRequest.operationId,
    );
    const principal = await verifyRecentAccountDeletionPrincipal(
      request,
      dependencies,
      "recursive",
    );
    logStage(request, response, dependencies, "authVerified", deletionRequest.operationId);
    logStage(request, response, dependencies, "appCheckVerified", deletionRequest.operationId);
    assertAccountDeletionOwnerScope(
      principal.uid,
      deletionRequest.targetOwnerScope,
    );
    const deletionSessionProof = readAccountDeletionSessionProof(request);
    const sessionCommitment = deriveRequestAuthSessionCommitment(
      deletionSessionProof,
      principal,
    );
    logStage(request, response, dependencies, "proofVerified", deletionRequest.operationId);
    const recoveryEnvelope = sealAccountDeletionRecoveryUid({
      uid: principal.uid,
      operationId: deletionRequest.operationId,
      ownerScopeCommitment: deletionRequest.targetOwnerScope,
      authSessionCommitment: sessionCommitment,
      deletionSessionProof,
    });
    let deletion;
    try {
      logStage(request, response, dependencies, "deletionStarted", deletionRequest.operationId);
      deletion = await dependencies.accountDeletion.deleteAndVerify(
        principal.uid,
        deletionRequest.operationId,
        sessionCommitment,
        recoveryEnvelope,
      );
    } catch (error) {
      throwRecursiveAccountDeletionFailure(error);
    }
    logStage(
      request,
      response,
      dependencies,
      "recursiveDeleteCompleted",
      deletionRequest.operationId,
      { documentCount: deletion.deletedDocuments },
    );
    logStage(request, response, dependencies, "verificationStarted", deletionRequest.operationId);
    if (!deletion.verifiedEmpty) {
      logStage(
        request,
        response,
        dependencies,
        "verificationCompleted",
        deletionRequest.operationId,
        { resultCode: "cloudVerificationFailed" },
      );
      throw new GatewayFailure(
        "cloudVerificationFailed",
        "Recursive account deletion could not be verified.",
        { safeErrorClass: "cloudVerificationFailed" },
      );
    }
    logStage(
      request,
      response,
      dependencies,
      "verificationCompleted",
      deletionRequest.operationId,
      { resultCode: "completed" },
    );
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
    logStage(
      request,
      response,
      dependencies,
      "requestReceived",
      deletionRequest.operationId,
    );
    const verification = await verifyAccountAuthDeletionRequest(
      request,
      dependencies,
    );
    if (verification.mode !== "attestation") {
      logStage(request, response, dependencies, "authVerified", deletionRequest.operationId);
    }
    logStage(request, response, dependencies, "appCheckVerified", deletionRequest.operationId);
    const deletionSessionProof = readAccountDeletionSessionProof(request);
    logStage(request, response, dependencies, "proofVerified", deletionRequest.operationId);
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
    let deletion;
    try {
      logStage(request, response, dependencies, "deletionStarted", deletionRequest.operationId);
      if (verification.mode === "attestation") {
        deletion = await dependencies.accountAuthDeletion.confirmAlreadyDeletedByAttestation(
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
            ? await dependencies.accountAuthDeletion.confirmAlreadyDeletedAfterCloudCompletion(
                verification.principal.uid,
                deletionRequest.operationId,
                sessionCommitment,
              )
            : await dependencies.accountAuthDeletion.deleteAfterCloudCompletion(
                verification.principal.uid,
                deletionRequest.operationId,
                sessionCommitment,
                verification.recentAuthenticationSatisfied,
              );
      }
    } catch (error) {
      throwAccountAuthDeletionFailure(error);
    }
    logStage(request, response, dependencies, "verificationStarted", deletionRequest.operationId);
    logStage(
      request,
      response,
      dependencies,
      "verificationCompleted",
      deletionRequest.operationId,
      { resultCode: "completed" },
    );

    response.status(200).json({
      operationId: deletionRequest.operationId,
      status: "completed",
      authDeleted: true,
      alreadyDeleted: deletion.alreadyDeleted,
    });
  };
}
