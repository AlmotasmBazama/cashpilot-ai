import type {
  AccountAuthDeletionStore,
  RecursiveAccountDeletionStore,
} from "../account_deletion/account_deletion_ports.js";
import type { RequestVerifier } from "../auth/request_verifier_port.js";
import type { SafeAccountDeletionLogSink } from "../observability.js";
import type { RateLimiter } from "../security/rate_limiter.js";

export interface AccountDeletionVerificationDependencies {
  readonly verifier: RequestVerifier;
  readonly rateLimiter: RateLimiter;
  readonly logSink: SafeAccountDeletionLogSink;
  readonly serviceRevision: string;
}

export interface RecursiveAccountDeletionRouteDependencies
  extends AccountDeletionVerificationDependencies {
  readonly accountDeletion: RecursiveAccountDeletionStore;
}

export interface AccountAuthDeletionRouteDependencies
  extends AccountDeletionVerificationDependencies {
  readonly accountAuthDeletion: AccountAuthDeletionStore;
}

export interface AccountDeletionDependencies
  extends RecursiveAccountDeletionRouteDependencies,
    AccountAuthDeletionRouteDependencies {}
