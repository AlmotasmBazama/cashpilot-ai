import { GatewayFailure } from "./errors.js";

export const fixedModels = Object.freeze({
  generalConversation: "openai/gpt-oss-20b",
  financialExplanation: "openai/gpt-oss-120b",
  governedToolSelection: "openai/gpt-oss-20b",
});

export const gatewayServiceVersion = "0.1.0";

export interface GatewayConfig {
  readonly environment: "development" | "staging" | "production" | "test";
  readonly port: number;
  readonly firebaseProjectId: string;
  readonly groqApiKey: string;
  readonly groqBaseUrl: string;
  readonly allowedOrigins: ReadonlySet<string>;
  readonly maxBodyBytes: number;
  readonly maxRequestsPerMinute: number;
  readonly providerTimeoutMs: number;
  readonly maxStreamMs: number;
  readonly modelDiagnosticsEnabled: boolean;
  readonly toolSelectionEnabled: boolean;
  readonly supportedClientVersion: string;
}

function required(
  env: NodeJS.ProcessEnv,
  name: string,
  options: { allowEmpty?: boolean } = {},
): string {
  const value = env[name]?.trim() ?? "";
  if (!options.allowEmpty && value.length === 0) {
    throw new GatewayFailure(
      "configurationFailure",
      `Required gateway configuration ${name} is unavailable.`,
    );
  }
  return value;
}

function positiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function supportedClientVersion(env: NodeJS.ProcessEnv): string {
  const value = env.CASH_PILOT_CLIENT_VERSION?.trim() || "1.0.0";
  if (!/^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$/u.test(value)) {
    throw new GatewayFailure(
      "configurationFailure",
      "The supported client version value is invalid.",
    );
  }
  return value;
}

export function loadGatewayConfig(
  env: NodeJS.ProcessEnv = process.env,
): GatewayConfig {
  const environmentValue = (
    env.CASH_PILOT_ENVIRONMENT ??
    env.GATEWAY_ENVIRONMENT ??
    "development"
  )
    .trim()
    .toLowerCase();
  if (
    environmentValue !== "development" &&
    environmentValue !== "production" &&
    environmentValue !== "staging" &&
    environmentValue !== "test"
  ) {
    throw new GatewayFailure(
      "configurationFailure",
      "The gateway environment value is invalid.",
    );
  }
  const environment = environmentValue;
  const origins = new Set(
    (env.CASH_PILOT_ALLOWED_ORIGINS ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
  if (origins.has("*")) {
    throw new GatewayFailure(
      "configurationFailure",
      "Wildcard CORS origins are not permitted.",
    );
  }
  if (
    (environment === "production" || environment === "staging") &&
    origins.size === 0
  ) {
    throw new GatewayFailure(
      "configurationFailure",
      "At least one exact web origin is required outside development.",
    );
  }

  return {
    environment,
    port: positiveInt(env.PORT, 8080),
    firebaseProjectId: required(env, "FIREBASE_PROJECT_ID"),
    // The process remains reachable when the provider secret is missing so
    // /health can report a safe not-ready state. Protected AI routes fail
    // closed with groqNotConfigured before making an upstream request.
    groqApiKey: required(env, "GROQ_API_KEY", { allowEmpty: true }),
    groqBaseUrl:
      env.GROQ_BASE_URL?.trim() ||
      "https://api.groq.com/openai/v1",
    allowedOrigins: origins,
    maxBodyBytes: positiveInt(env.MAX_AI_BODY_BYTES, 32 * 1024),
    maxRequestsPerMinute: positiveInt(
      env.MAX_AI_REQUESTS_PER_MINUTE,
      20,
    ),
    providerTimeoutMs: positiveInt(env.PROVIDER_TIMEOUT_MS, 20_000),
    maxStreamMs: positiveInt(env.MAX_STREAM_MS, 30_000),
    modelDiagnosticsEnabled:
      env.MODEL_DIAGNOSTICS_ENABLED?.trim().toLowerCase() === "true",
    toolSelectionEnabled:
      env.CASH_PILOT_AI_GROQ_TOOL_SELECTION_ENABLED?.trim().toLowerCase() ===
      "true",
    supportedClientVersion: supportedClientVersion(env),
  };
}
