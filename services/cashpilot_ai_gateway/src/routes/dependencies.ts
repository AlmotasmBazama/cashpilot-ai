import type { GatewayConfig } from "../config.js";
import type { RequestVerifier } from "../auth/request_verifier_port.js";
import type { GroqTransport } from "../groq/groq_transport.js";
import type { RateLimiter } from "../security/rate_limiter.js";
import type { SafeStreamLogSink } from "../security/safe_stream_trace.js";
import type {
  AccountAuthDeletionStore,
  RecursiveAccountDeletionStore,
} from "../account_deletion/account_deletion_ports.js";

export interface RouteDependencies {
  readonly config: GatewayConfig;
  readonly verifier: RequestVerifier;
  readonly groq: GroqTransport;
  readonly rateLimiter: RateLimiter;
  readonly safeStreamLog?: SafeStreamLogSink;
  readonly accountDeletion?: RecursiveAccountDeletionStore;
  readonly accountAuthDeletion?: AccountAuthDeletionStore;
}

type AiRoutePorts = Pick<
  RouteDependencies,
  "verifier" | "groq" | "rateLimiter" | "safeStreamLog"
>;

type AiRequestConfig = Pick<
  GatewayConfig,
  "maxStreamMs" | "supportedClientVersion"
>;

export type GeneralChatRouteDependencies = AiRoutePorts & {
  readonly config: AiRequestConfig;
};

export type FinancialExplanationRouteDependencies =
  GeneralChatRouteDependencies;

export type ToolSelectionRouteDependencies = AiRoutePorts & {
  readonly config: AiRequestConfig &
    Pick<GatewayConfig, "toolSelectionEnabled">;
};

export type DiagnosticsRouteDependencies = AiRoutePorts & {
  readonly config: AiRequestConfig &
    Pick<GatewayConfig, "modelDiagnosticsEnabled">;
};

export type AccountDeletionVerificationDependencies = Pick<
  RouteDependencies,
  "verifier" | "rateLimiter"
>;

export type RecursiveAccountDeletionRouteDependencies =
  AccountDeletionVerificationDependencies &
    Pick<RouteDependencies, "accountDeletion">;

export type AccountAuthDeletionRouteDependencies =
  AccountDeletionVerificationDependencies &
    Pick<RouteDependencies, "accountAuthDeletion">;
