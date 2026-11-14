import {
  AccountDeletionContinuationExpired,
  AccountDeletionNotReady,
  AccountDeletionOperationConflict,
} from "../account_deletion/account_deletion_ports.js";
import { GatewayFailure } from "../errors.js";

export function throwRecursiveAccountDeletionFailure(error: unknown): never {
  if (error instanceof AccountDeletionOperationConflict) {
    throw new GatewayFailure(
      "operationConflict",
      "A different account deletion operation is already active.",
    );
  }
  throw new GatewayFailure(
    "providerUnavailable",
    "Recursive account deletion is temporarily unavailable.",
  );
}

export function throwAccountAuthDeletionFailure(error: unknown): never {
  if (error instanceof AccountDeletionOperationConflict) {
    throw new GatewayFailure(
      "operationConflict",
      "A different account deletion operation owns this account.",
    );
  }
  if (error instanceof AccountDeletionNotReady) {
    throw new GatewayFailure(
      "deletionNotReady",
      "Verified recursive account deletion must complete first.",
    );
  }
  if (error instanceof AccountDeletionContinuationExpired) {
    throw new GatewayFailure(
      "deletionReauthenticationRequired",
      "Fresh authentication is required to continue account deletion.",
    );
  }
  throw new GatewayFailure(
    "providerUnavailable",
    "Firebase Auth account deletion is temporarily unavailable.",
  );
}
