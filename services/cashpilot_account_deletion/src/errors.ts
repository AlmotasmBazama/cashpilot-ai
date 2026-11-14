export type AccountDeletionFailureCode =
  | "authenticationRequired"
  | "appCheckUnavailable"
  | "deletionProofInvalid"
  | "permissionDenied"
  | "providerUnavailable"
  | "cloudDeleteTimedOut"
  | "cloudDeletePartial"
  | "cloudVerificationFailed"
  | "unknownTemporaryFailure"
  | "gatewayRequestInvalid"
  | "requestTooLarge"
  | "rateLimited"
  | "configurationFailure"
  | "operationConflict"
  | "deletionReauthenticationRequired"
  | "deletionNotReady";

const defaultStatus: Record<AccountDeletionFailureCode, number> = {
  authenticationRequired: 401,
  appCheckUnavailable: 401,
  deletionProofInvalid: 401,
  permissionDenied: 503,
  providerUnavailable: 503,
  cloudDeleteTimedOut: 504,
  cloudDeletePartial: 503,
  cloudVerificationFailed: 503,
  unknownTemporaryFailure: 503,
  gatewayRequestInvalid: 400,
  requestTooLarge: 413,
  rateLimited: 429,
  configurationFailure: 503,
  operationConflict: 409,
  deletionReauthenticationRequired: 401,
  deletionNotReady: 409,
};

export class GatewayFailure extends Error {
  readonly code: AccountDeletionFailureCode;
  readonly status: number;
  readonly retryAfterSeconds?: number;
  readonly retryable: boolean;
  readonly safeErrorClass?: string;

  constructor(
    code: AccountDeletionFailureCode,
    safeMessage: string,
    options: {
      status?: number;
      retryAfterSeconds?: number;
      retryable?: boolean;
      safeErrorClass?: string;
    } = {},
  ) {
    super(safeMessage);
    this.name = "GatewayFailure";
    this.code = code;
    this.status = options.status ?? defaultStatus[code];
    this.retryable = options.retryable ?? this.status >= 500;
    if (options.retryAfterSeconds !== undefined) {
      this.retryAfterSeconds = options.retryAfterSeconds;
    }
    if (options.safeErrorClass !== undefined) {
      this.safeErrorClass = options.safeErrorClass;
    }
  }
}

export function asGatewayFailure(error: unknown): GatewayFailure {
  if (error instanceof GatewayFailure) {
    return error;
  }
  return new GatewayFailure(
    "unknownTemporaryFailure",
    "Account deletion is temporarily unavailable.",
    { safeErrorClass: "unclassifiedServerFailure" },
  );
}
