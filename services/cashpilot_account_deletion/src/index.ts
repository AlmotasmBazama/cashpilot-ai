import { AdminAccountAuthDeletionStore } from "./account_deletion/account_auth_deletion_store.js";
import { AdminRecursiveAccountDeletionStore } from "./account_deletion/recursive_account_deletion_store.js";
import { OfficialFirebaseRequestVerifier } from "./auth/request_verifier.js";
import { loadAccountDeletionConfig } from "./config.js";
import { getOrInitializeFirebaseAdminApp } from "./firebase/firebase_admin_app.js";
import {
  ConsoleSafeAccountDeletionLogSink,
  safeServiceRevision,
} from "./observability.js";
import { PerUserSlidingWindowRateLimiter } from "./security/rate_limit.js";
import type { AccountDeletionAppDependencies } from "./app.js";

export { createAccountDeletionApp } from "./app.js";
export type { AccountDeletionAppDependencies } from "./app.js";
export { GatewayFailure } from "./errors.js";

export function productionDependencies(): AccountDeletionAppDependencies {
  const config = loadAccountDeletionConfig();
  const firebaseAdminApp = getOrInitializeFirebaseAdminApp(
    config.firebaseProjectId,
  );
  return {
    config,
    verifier: new OfficialFirebaseRequestVerifier(
      config.firebaseProjectId,
      firebaseAdminApp,
    ),
    rateLimiter: new PerUserSlidingWindowRateLimiter(
      config.maxRequestsPerMinute,
    ),
    accountDeletion: new AdminRecursiveAccountDeletionStore(
      firebaseAdminApp,
      {
        maxDeleteAttempts: config.maxDeleteAttempts,
        operationTimeoutMs: config.operationTimeoutMs,
      },
    ),
    accountAuthDeletion: new AdminAccountAuthDeletionStore(firebaseAdminApp),
    logSink: new ConsoleSafeAccountDeletionLogSink(),
    serviceRevision: safeServiceRevision(),
  };
}
