import type { Request } from "express";
import type { App } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { GatewayFailure } from "../errors.js";
import {
  UnsupportedFirebaseTenantFailure,
  type RequestVerifier,
  type VerifiedPrincipal,
} from "./request_verifier_port.js";

export { UnsupportedFirebaseTenantFailure };
export type {
  GatewayHeaderRequest,
  RequestVerifier,
  VerifiedPrincipal,
} from "./request_verifier_port.js";

function bearerToken(request: Request): string {
  const header = request.header("Authorization") ?? "";
  const match = /^Bearer ([^\s]+)$/.exec(header);
  if (match?.[1] === undefined) {
    throw new GatewayFailure(
      "unauthenticated",
      "A valid Firebase authentication token is required.",
    );
  }
  return match[1];
}

function appCheckToken(request: Request): string {
  const token = request.header("X-Firebase-AppCheck")?.trim() ?? "";
  if (token.length === 0) {
    throw new GatewayFailure(
      "appCheckRejected",
      "A valid Firebase App Check token is required.",
    );
  }
  return token;
}

export class OfficialFirebaseRequestVerifier implements RequestVerifier {
  constructor(
    private readonly projectId: string,
    private readonly app: App,
  ) {}

  async verify(request: Request): Promise<VerifiedPrincipal> {
    return this.verifyTokens(request, true);
  }

  async verifyAccountDeletionRetry(
    request: Request,
  ): Promise<VerifiedPrincipal> {
    return this.verifyTokens(request, false);
  }

  async verifyAccountDeletionAttestation(request: Request): Promise<void> {
    await this.verifyAppCheck(request);
  }

  private async verifyAppCheck(request: Request): Promise<void> {
    const checkToken = appCheckToken(request);
    try {
      const decodedCheck = await getAppCheck(this.app).verifyToken(checkToken);
      if (decodedCheck.appId.trim().length === 0) {
        throw new Error("missing app id");
      }
    } catch {
      throw new GatewayFailure(
        "appCheckRejected",
        "Firebase App Check verification failed.",
      );
    }
  }

  private async verifyTokens(
    request: Request,
    checkRevoked: boolean,
  ): Promise<VerifiedPrincipal> {
    const authToken = bearerToken(request);

    let decodedAuth;
    try {
      decodedAuth = await getAuth(this.app).verifyIdToken(
        authToken,
        checkRevoked,
      );
    } catch {
      throw new GatewayFailure(
        "unauthenticated",
        "Firebase authentication verification failed.",
      );
    }
    if (decodedAuth.aud !== this.projectId || decodedAuth.uid.length === 0) {
      throw new GatewayFailure(
        "unauthenticated",
        "The Firebase authentication audience was rejected.",
      );
    }
    const firebaseClaims = decodedAuth.firebase as unknown as Record<
      string,
      unknown
    >;
    const tenantIdentityPresent =
      Object.prototype.hasOwnProperty.call(decodedAuth, "tenant_id") ||
      Object.prototype.hasOwnProperty.call(firebaseClaims, "tenant");

    await this.verifyAppCheck(request);
    if (tenantIdentityPresent) {
      throw new UnsupportedFirebaseTenantFailure();
    }
    return {
      uid: decodedAuth.uid,
      authTimeSeconds: decodedAuth.auth_time,
      issuedAtSeconds: decodedAuth.iat,
      signInProvider: decodedAuth.firebase.sign_in_provider,
      tenantIdentityPresent: false,
    };
  }
}
