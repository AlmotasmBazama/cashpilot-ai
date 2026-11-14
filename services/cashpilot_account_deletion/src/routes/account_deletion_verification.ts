import type { Request } from "express";
import {
  UnsupportedFirebaseTenantFailure,
  type VerifiedPrincipal,
} from "../auth/request_verifier_port.js";
import { GatewayFailure } from "../errors.js";
import type { AccountDeletionVerificationDependencies } from "./dependencies.js";

export type AuthDeletionVerification =
  | {
      readonly mode: "verified";
      readonly principal: VerifiedPrincipal;
      readonly recentAuthenticationSatisfied: boolean;
    }
  | {
      readonly mode: "signedRecovery";
      readonly principal: VerifiedPrincipal;
    }
  | { readonly mode: "attestation" };

function assertSupportedPrincipal(principal: VerifiedPrincipal): void {
  if (principal.tenantIdentityPresent) {
    throw new UnsupportedFirebaseTenantFailure();
  }
}

function hasRecentAuthentication(principal: VerifiedPrincipal): boolean {
  const freshnessTimestamp =
    principal.signInProvider === "anonymous"
      ? principal.issuedAtSeconds
      : principal.authTimeSeconds;
  const authenticationAgeSeconds =
    Math.floor(Date.now() / 1000) - freshnessTimestamp;
  return !(
    !Number.isSafeInteger(freshnessTimestamp) ||
    authenticationAgeSeconds < -60 ||
    authenticationAgeSeconds > 5 * 60
  );
}

function assertRecentAuthentication(principal: VerifiedPrincipal): void {
  if (hasRecentAuthentication(principal)) {
    return;
  }
  throw new GatewayFailure(
    "authenticationRequired",
    "Recent account authentication is required for deletion.",
  );
}

function isRecoverableAuthenticationFailure(error: unknown): boolean {
  return (
    error instanceof GatewayFailure &&
    error.code === "authenticationRequired" &&
    !(error instanceof UnsupportedFirebaseTenantFailure)
  );
}

export async function verifyRecentAccountDeletionPrincipal(
  request: Request,
  dependencies: AccountDeletionVerificationDependencies,
  rateLimitBucket: "recursive" | "auth",
): Promise<VerifiedPrincipal> {
  const principal = await dependencies.verifier.verify(request);
  assertSupportedPrincipal(principal);
  assertRecentAuthentication(principal);
  dependencies.rateLimiter.consume(
    `account-deletion:${rateLimitBucket}:${principal.uid}`,
  );
  return principal;
}

export async function verifyAccountAuthDeletionRequest(
  request: Request,
  dependencies: AccountDeletionVerificationDependencies,
): Promise<AuthDeletionVerification> {
  try {
    const principal = await dependencies.verifier.verify(request);
    assertSupportedPrincipal(principal);
    dependencies.rateLimiter.consume(
      `account-deletion:auth:${principal.uid}`,
    );
    return {
      mode: "verified",
      principal,
      recentAuthenticationSatisfied: hasRecentAuthentication(principal),
    };
  } catch (error) {
    if (!isRecoverableAuthenticationFailure(error)) {
      throw error;
    }
  }

  const retryVerifier = dependencies.verifier.verifyAccountDeletionRetry;
  if (retryVerifier !== undefined) {
    try {
      const principal = await retryVerifier.call(
        dependencies.verifier,
        request,
      );
      assertSupportedPrincipal(principal);
      dependencies.rateLimiter.consume(
        `account-deletion:auth:${principal.uid}`,
      );
      return { mode: "signedRecovery", principal };
    } catch (error) {
      if (!isRecoverableAuthenticationFailure(error)) {
        throw error;
      }
    }
  }

  const attestationVerifier =
    dependencies.verifier.verifyAccountDeletionAttestation;
  if (attestationVerifier === undefined) {
    throw new GatewayFailure(
      "authenticationRequired",
      "Firebase authentication verification failed.",
    );
  }
  await attestationVerifier.call(dependencies.verifier, request);
  return { mode: "attestation" };
}
