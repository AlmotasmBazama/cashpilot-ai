import {
  AccountDeletionProviderFailure,
  type AccountDeletionProviderFailureCode,
} from "./account_deletion_ports.js";

type FailureStage = "provider" | "recursiveDelete";

function directCode(error: unknown): string {
  if (typeof error !== "object" || error === null) {
    return "";
  }
  const direct = Reflect.get(error, "code");
  if (typeof direct === "string" || typeof direct === "number") {
    return String(direct).toLowerCase();
  }
  const details = Reflect.get(error, "errorInfo");
  if (typeof details === "object" && details !== null) {
    const nested = Reflect.get(details, "code");
    if (typeof nested === "string" || typeof nested === "number") {
      return String(nested).toLowerCase();
    }
  }
  return "";
}

function classifiedCode(
  code: string,
  stage: FailureStage,
): {
  code: AccountDeletionProviderFailureCode;
  safeErrorClass: string;
  retryable: boolean;
} {
  if (
    code === "7" ||
    code.includes("permission-denied") ||
    code.includes("permission_denied") ||
    code.includes("insufficient-permission")
  ) {
    return {
      code: "permissionDenied",
      safeErrorClass: "firebasePermissionDenied",
      retryable: false,
    };
  }
  if (
    code === "4" ||
    code.includes("deadline-exceeded") ||
    code.includes("timeout")
  ) {
    return {
      code: "cloudDeleteTimedOut",
      safeErrorClass: "firebaseDeadlineExceeded",
      retryable: true,
    };
  }
  if (
    code === "8" ||
    code === "10" ||
    code === "14" ||
    code.includes("resource-exhausted") ||
    code.includes("unavailable") ||
    code.includes("aborted")
  ) {
    return {
      code:
        stage === "recursiveDelete"
          ? "cloudDeletePartial"
          : "providerUnavailable",
      safeErrorClass: "firebaseTransientFailure",
      retryable: true,
    };
  }
  return {
    code:
      stage === "recursiveDelete"
        ? "cloudDeletePartial"
        : "providerUnavailable",
    safeErrorClass: "firebaseAdminFailure",
    retryable: stage === "recursiveDelete",
  };
}

export function classifyFirebaseAdminFailure(
  error: unknown,
  stage: FailureStage = "provider",
): AccountDeletionProviderFailure {
  if (error instanceof AccountDeletionProviderFailure) {
    return error;
  }
  const classified = classifiedCode(directCode(error), stage);
  return new AccountDeletionProviderFailure(
    classified.code,
    classified.safeErrorClass,
    classified.retryable,
  );
}

export function isTransientFirebaseAdminFailure(error: unknown): boolean {
  const code = directCode(error);
  return (
    code === "4" ||
    code === "8" ||
    code === "10" ||
    code === "14" ||
    code.includes("deadline-exceeded") ||
    code.includes("resource-exhausted") ||
    code.includes("aborted") ||
    code.includes("unavailable") ||
    code.includes("timeout")
  );
}
