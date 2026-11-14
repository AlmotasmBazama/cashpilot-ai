import type { RequestVerifier, VerifiedPrincipal } from "../src/auth/request_verifier_port.js";
import type { AccountDeletionConfig } from "../src/config.js";
import { GatewayFailure } from "../src/errors.js";
import type {
  SafeAccountDeletionLogEvent,
  SafeAccountDeletionLogSink,
} from "../src/observability.js";
import type {
  AccountAuthDeletionResult,
  AccountAuthDeletionStore,
  RecursiveAccountDeletionResult,
  RecursiveAccountDeletionStore,
} from "../src/account_deletion/account_deletion_ports.js";
import type { AccountDeletionRecoveryEnvelope } from "../src/account_deletion/auth_session_commitment.js";
import type { GatewayHeaderRequest } from "../src/auth/request_verifier_port.js";

export const operationId = "01989f80-4e00-7000-8000-000000000001";
export const deletionProof = Buffer.alloc(32, 7).toString("base64url");
export const principal: VerifiedPrincipal = {
  uid: "synthetic-user-a",
  authTimeSeconds: Math.floor(Date.now() / 1000),
  issuedAtSeconds: Math.floor(Date.now() / 1000),
  signInProvider: "password",
  tenantIdentityPresent: false,
};

export const testConfig: AccountDeletionConfig = {
  environment: "test",
  port: 8080,
  firebaseProjectId: "cashpilot-ai-a6b49",
  allowedOrigins: new Set(["https://cashpilot-ai-a6b49.web.app"]),
  maxBodyBytes: 4096,
  maxRequestsPerMinute: 20,
  operationTimeoutMs: 5000,
  maxDeleteAttempts: 2,
};

export class MemoryLogSink implements SafeAccountDeletionLogSink {
  readonly events: SafeAccountDeletionLogEvent[] = [];

  write(event: SafeAccountDeletionLogEvent): void {
    this.events.push(event);
  }
}

export class AllowingVerifier implements RequestVerifier {
  async verify(_request: GatewayHeaderRequest): Promise<VerifiedPrincipal> {
    return principal;
  }

  async verifyAccountDeletionRetry(
    _request: GatewayHeaderRequest,
  ): Promise<VerifiedPrincipal> {
    return principal;
  }

  async verifyAccountDeletionAttestation(
    _request: GatewayHeaderRequest,
  ): Promise<void> {}
}

export class RejectingVerifier implements RequestVerifier {
  constructor(private readonly failure: GatewayFailure) {}

  async verify(_request: GatewayHeaderRequest): Promise<VerifiedPrincipal> {
    throw this.failure;
  }
}

export class RecordingRecursiveStore
  implements RecursiveAccountDeletionStore
{
  readonly targets: string[] = [];
  failure?: Error;

  async deleteAndVerify(
    uid: string,
    _operationId: string,
    _authSessionCommitment: string,
    _recoveryEnvelope: AccountDeletionRecoveryEnvelope,
  ): Promise<RecursiveAccountDeletionResult> {
    this.targets.push(uid);
    if (this.failure !== undefined) {
      throw this.failure;
    }
    return { deletedDocuments: 0, verifiedEmpty: true };
  }
}

export class RecordingAuthStore implements AccountAuthDeletionStore {
  readonly targets: string[] = [];

  async deleteAfterCloudCompletion(
    uid: string,
    _operationId: string,
    _authSessionCommitment: string,
    _recentAuthenticationSatisfied: boolean,
  ): Promise<AccountAuthDeletionResult> {
    this.targets.push(uid);
    return { alreadyDeleted: false };
  }

  async confirmAlreadyDeletedAfterCloudCompletion(
    uid: string,
    _operationId: string,
    _authSessionCommitment: string,
  ): Promise<AccountAuthDeletionResult> {
    this.targets.push(uid);
    return { alreadyDeleted: true };
  }

  async confirmAlreadyDeletedByAttestation(
    _operationId: string,
    _ownerScopeCommitment: string,
    _deletionSessionProof: string,
  ): Promise<AccountAuthDeletionResult> {
    return { alreadyDeleted: true };
  }
}

export class NoopRateLimiter {
  consume(_key: string): void {}
}
