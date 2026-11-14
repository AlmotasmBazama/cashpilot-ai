import { GatewayFailure } from "./errors.js";

export const accountDeletionServiceVersion = "1.0.0";

export interface AccountDeletionConfig {
  readonly environment: "development" | "staging" | "production" | "test";
  readonly port: number;
  readonly firebaseProjectId: string;
  readonly allowedOrigins: ReadonlySet<string>;
  readonly maxBodyBytes: number;
  readonly maxRequestsPerMinute: number;
  readonly operationTimeoutMs: number;
  readonly maxDeleteAttempts: number;
}

function positiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export function loadAccountDeletionConfig(
  env: NodeJS.ProcessEnv = process.env,
): AccountDeletionConfig {
  const environment = (env.CASH_PILOT_ENVIRONMENT ?? "development")
    .trim()
    .toLowerCase();
  if (!new Set(["development", "staging", "production", "test"]).has(environment)) {
    throw new GatewayFailure(
      "configurationFailure",
      "The account deletion environment is invalid.",
    );
  }
  const projectId = env.FIREBASE_PROJECT_ID?.trim() ?? "";
  if (!/^[a-z][a-z0-9-]{4,29}$/u.test(projectId)) {
    throw new GatewayFailure(
      "configurationFailure",
      "The Firebase project configuration is invalid.",
    );
  }
  const allowedOrigins = new Set(
    (env.CASH_PILOT_ALLOWED_ORIGINS ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
  if (allowedOrigins.has("*")) {
    throw new GatewayFailure(
      "configurationFailure",
      "Wildcard origins are not permitted.",
    );
  }
  if ((environment === "staging" || environment === "production") && allowedOrigins.size === 0) {
    throw new GatewayFailure(
      "configurationFailure",
      "At least one exact web origin is required.",
    );
  }
  return {
    environment: environment as AccountDeletionConfig["environment"],
    port: positiveInt(env.PORT, 8080),
    firebaseProjectId: projectId,
    allowedOrigins,
    maxBodyBytes: Math.min(8 * 1024, positiveInt(env.MAX_DELETION_BODY_BYTES, 4 * 1024)),
    maxRequestsPerMinute: Math.min(20, positiveInt(env.MAX_DELETION_REQUESTS_PER_MINUTE, 6)),
    operationTimeoutMs: Math.min(90_000, positiveInt(env.DELETION_OPERATION_TIMEOUT_MS, 50_000)),
    maxDeleteAttempts: Math.min(3, positiveInt(env.MAX_DELETION_ATTEMPTS, 2)),
  };
}
