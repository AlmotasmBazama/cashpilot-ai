import type { Request } from "express";
import { z } from "zod";
import {
  decodeAccountDeletionSessionProof,
  deriveAccountDeletionAuthSessionCommitment,
} from "../account_deletion/auth_session_commitment.js";
import { ownerScopeCommitmentMatches } from "../account_deletion/owner_scope_commitment.js";
import type { VerifiedPrincipal } from "../auth/request_verifier_port.js";
import { GatewayFailure } from "../errors.js";

const AccountDeletionRequestSchema = z
  .object({
    operationId: z
      .string()
      .regex(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      ),
    targetOwnerScope: z.string().regex(/^[0-9a-f]{64}$/),
  })
  .strict();

export interface ParsedAccountDeletionRequest {
  readonly operationId: string;
  readonly targetOwnerScope: string;
}

export function parseAccountDeletionRequest(
  request: Request,
): ParsedAccountDeletionRequest {
  const parsed = AccountDeletionRequestSchema.safeParse(request.body);
  if (!parsed.success) {
    throw new GatewayFailure(
      "invalidResponse",
      "The account deletion request is invalid.",
      { status: 400 },
    );
  }
  return parsed.data;
}

export function assertAccountDeletionOwnerScope(
  principalUid: string,
  targetOwnerScope: string,
): void {
  if (!ownerScopeCommitmentMatches(principalUid, targetOwnerScope)) {
    throw new GatewayFailure(
      "operationConflict",
      "The account deletion target does not match the authenticated owner.",
    );
  }
}

export function readAccountDeletionSessionProof(request: Request): string {
  const proof = request.header("X-Cashpilot-Deletion-Session") ?? "";
  try {
    decodeAccountDeletionSessionProof(proof);
    return proof;
  } catch {
    throw new GatewayFailure(
      "unauthenticated",
      "The account-deletion session proof is invalid.",
    );
  }
}

export function deriveRequestAuthSessionCommitment(
  deletionSessionProof: string,
  principal: VerifiedPrincipal,
): string {
  try {
    return deriveAccountDeletionAuthSessionCommitment({
      uid: principal.uid,
      deletionSessionProof,
    });
  } catch {
    throw new GatewayFailure(
      "unauthenticated",
      "The account-deletion session proof is invalid.",
    );
  }
}
