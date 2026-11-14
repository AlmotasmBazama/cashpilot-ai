import type { App } from "firebase-admin/app";
import {
  getAppCheck,
  type VerifyAppCheckTokenResponse,
} from "firebase-admin/app-check";
import { getAuth, type DecodedIdToken } from "firebase-admin/auth";
import { GatewayFailure } from "../errors.js";
import {
  UnsupportedFirebaseTenantFailure,
  type GatewayHeaderRequest,
  type RequestVerifier,
  type VerifiedPrincipal,
} from "./request_verifier_port.js";

export { UnsupportedFirebaseTenantFailure };
export type {
  GatewayHeaderRequest,
  RequestVerifier,
  VerifiedPrincipal,
} from "./request_verifier_port.js";

export interface FirebaseRequestVerificationBackend {
  verifyIdToken(token: string, checkRevoked: boolean): Promise<DecodedIdToken>;
  verifyAppCheckToken(token: string): Promise<VerifyAppCheckTokenResponse>;
}

export class FirebaseAdminRequestVerificationBackend
  implements FirebaseRequestVerificationBackend
{
  constructor(private readonly app: App) {}

  verifyIdToken(
    token: string,
    checkRevoked: boolean,
  ): Promise<DecodedIdToken> {
    return getAuth(this.app).verifyIdToken(token, checkRevoked);
  }

  verifyAppCheckToken(token: string): Promise<VerifyAppCheckTokenResponse> {
    return getAppCheck(this.app).verifyToken(token);
  }
}

function bearerToken(request: GatewayHeaderRequest): string {
  const header = request.header("Authorization") ?? "";
  const match = /^Bearer ([^\s]+)$/.exec(header);
  if (match?.[1] === undefined) {
    throw new GatewayFailure(
      "authenticationRequired",
      "A valid Firebase authentication token is required.",
    );
  }
  return match[1];
}

function appCheckToken(request: GatewayHeaderRequest): string {
  const token = request.header("X-Firebase-AppCheck")?.trim() ?? "";
  if (token.length === 0) {
    throw new GatewayFailure(
      "appCheckUnavailable",
      "A valid Firebase App Check token is required.",
    );
  }
  return token;
}

export class OfficialFirebaseRequestVerifier implements RequestVerifier {
  constructor(
    private readonly projectId: string,
    app: App,
    backend?: FirebaseRequestVerificationBackend,
  ) {
    this.backend =
      backend ?? new FirebaseAdminRequestVerificationBackend(app);
  }

  private readonly backend: FirebaseRequestVerificationBackend;

  async verify(request: GatewayHeaderRequest): Promise<VerifiedPrincipal> {
    return this.verifyTokens(request, true);
  }

  async verifyAccountDeletionRetry(
    request: GatewayHeaderRequest,
  ): Promise<VerifiedPrincipal> {
    return this.verifyTokens(request, false);
  }

  async verifyAccountDeletionAttestation(
    request: GatewayHeaderRequest,
  ): Promise<void> {
    await this.verifyAppCheck(request);
  }

  private async verifyAppCheck(request: GatewayHeaderRequest): Promise<void> {
    const checkToken = appCheckToken(request);
    try {
      const decodedCheck = await this.backend.verifyAppCheckToken(checkToken);
      if (decodedCheck.appId.trim().length === 0) {
        throw new Error("missing app id");
      }
    } catch {
      throw new GatewayFailure(
        "appCheckUnavailable",
        "Firebase App Check verification failed.",
      );
    }
  }

  private async verifyTokens(
    request: GatewayHeaderRequest,
    checkRevoked: boolean,
  ): Promise<VerifiedPrincipal> {
    const authToken = bearerToken(request);

    let decodedAuth;
    try {
      decodedAuth = await this.backend.verifyIdToken(authToken, checkRevoked);
    } catch {
      throw new GatewayFailure(
        "authenticationRequired",
        "Firebase authentication verification failed.",
      );
    }
    if (decodedAuth.aud !== this.projectId || decodedAuth.uid.length === 0) {
      throw new GatewayFailure(
        "authenticationRequired",
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
