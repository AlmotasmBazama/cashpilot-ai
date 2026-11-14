export type GatewayFailureCode =
  | "groqNotConfigured"
  | "groqAuthenticationFailed"
  | "groqModelUnavailable"
  | "groqRateLimited"
  | "groqRequestTimedOut"
  | "groqStreamTimedOut"
  | "groqMalformedResponse"
  | "groqUpstreamUnavailable"
  | "gatewayAuthenticationRequired"
  | "gatewayAppCheckRequired"
  | "gatewayRequestInvalid"
  | "gatewayUnavailable"
  | "unknownTemporaryFailure"
  | "unauthenticated"
  | "deletionReauthenticationRequired"
  | "appCheckRejected"
  | "rateLimited"
  | "providerQuotaExceeded"
  | "providerUnavailable"
  | "timeout"
  | "invalidResponse"
  | "emptyResponse"
  | "malformedSse"
  | "streamEndedWithoutCompleted"
  | "toolSelectionInvalid"
  | "requestTooLarge"
  | "networkFailure"
  | "configurationFailure"
  | "operationConflict"
  | "deletionNotReady";

const defaultStatus: Record<GatewayFailureCode, number> = {
  groqNotConfigured: 503,
  groqAuthenticationFailed: 503,
  groqModelUnavailable: 503,
  groqRateLimited: 429,
  groqRequestTimedOut: 504,
  groqStreamTimedOut: 504,
  groqMalformedResponse: 502,
  groqUpstreamUnavailable: 503,
  gatewayAuthenticationRequired: 401,
  gatewayAppCheckRequired: 401,
  gatewayRequestInvalid: 400,
  gatewayUnavailable: 503,
  unknownTemporaryFailure: 503,
  unauthenticated: 401,
  deletionReauthenticationRequired: 401,
  appCheckRejected: 401,
  rateLimited: 429,
  providerQuotaExceeded: 503,
  providerUnavailable: 503,
  timeout: 504,
  invalidResponse: 502,
  emptyResponse: 502,
  malformedSse: 502,
  streamEndedWithoutCompleted: 502,
  toolSelectionInvalid: 422,
  requestTooLarge: 413,
  networkFailure: 503,
  configurationFailure: 503,
  operationConflict: 409,
  deletionNotReady: 409,
};

export class GatewayFailure extends Error {
  readonly code: GatewayFailureCode;
  readonly status: number;
  readonly retryAfterSeconds?: number;

  constructor(
    code: GatewayFailureCode,
    safeMessage: string,
    options: { status?: number; retryAfterSeconds?: number } = {},
  ) {
    super(safeMessage);
    this.name = "GatewayFailure";
    this.code = code;
    this.status = options.status ?? defaultStatus[code];
    if (options.retryAfterSeconds !== undefined) {
      this.retryAfterSeconds = options.retryAfterSeconds;
    }
  }
}

export function asGatewayFailure(error: unknown): GatewayFailure {
  if (error instanceof GatewayFailure) {
    return error;
  }
  if (error instanceof DOMException && error.name === "AbortError") {
    return new GatewayFailure(
      "unknownTemporaryFailure",
      "The request was interrupted.",
    );
  }
  return new GatewayFailure(
    "unknownTemporaryFailure",
    "The request could not be completed temporarily.",
  );
}

export function isRetryableGroqFailure(error: unknown): boolean {
  const failure = asGatewayFailure(error);
  return (
    failure.code === "groqRateLimited" ||
    failure.code === "groqRequestTimedOut" ||
    failure.code === "groqStreamTimedOut" ||
    failure.code === "groqUpstreamUnavailable" ||
    failure.code === "timeout" ||
    failure.code === "networkFailure"
  );
}
