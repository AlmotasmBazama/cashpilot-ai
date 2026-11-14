import { loadGatewayConfig } from "./config.js";
import { OfficialFirebaseRequestVerifier } from "./auth/request_verifier.js";
import { GroqChatCompletionsClient } from "./groq/groq_client.js";
import { PerUserSlidingWindowRateLimiter } from "./security/rate_limit.js";
import { AdminRecursiveAccountDeletionStore } from "./account_deletion/recursive_account_deletion_store.js";
import { AdminAccountAuthDeletionStore } from "./account_deletion/account_auth_deletion_store.js";
import { getOrInitializeFirebaseAdminApp } from "./firebase/firebase_admin_app.js";
import type { GatewayDependencies } from "./app.js";

export { createGatewayApp } from "./app.js";
export type { GatewayDependencies } from "./app.js";

export function productionDependencies(
  config = loadGatewayConfig(),
): GatewayDependencies {
  const firebaseAdminApp = getOrInitializeFirebaseAdminApp(
    config.firebaseProjectId,
  );
  return {
    config,
    verifier: new OfficialFirebaseRequestVerifier(
      config.firebaseProjectId,
      firebaseAdminApp,
    ),
    groq: new GroqChatCompletionsClient(config),
    rateLimiter: new PerUserSlidingWindowRateLimiter(
      config.maxRequestsPerMinute,
    ),
    accountDeletion: new AdminRecursiveAccountDeletionStore(
      firebaseAdminApp,
    ),
    accountAuthDeletion: new AdminAccountAuthDeletionStore(
      firebaseAdminApp,
    ),
  };
}

export { GatewayFailure } from "./errors.js";
