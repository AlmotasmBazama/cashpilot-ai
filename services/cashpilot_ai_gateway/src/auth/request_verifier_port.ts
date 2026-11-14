import { GatewayFailure } from "../errors.js";

/// Minimal request surface needed by authentication adapters. Express
/// requests satisfy this contract structurally, while the port stays free of
/// the HTTP framework.
export interface GatewayHeaderRequest {
  header(name: string): string | undefined;
}

export interface VerifiedPrincipal {
  readonly uid: string;
  readonly authTimeSeconds: number;
  readonly issuedAtSeconds: number;
  readonly signInProvider: string;
  readonly tenantIdentityPresent: boolean;
}

export interface RequestVerifier {
  verify(request: GatewayHeaderRequest): Promise<VerifiedPrincipal>;

  /// Signature-only Auth verification is intentionally exposed only for the
  /// non-mutating recovery path after an Auth user has already been deleted.
  verifyAccountDeletionRetry?(
    request: GatewayHeaderRequest,
  ): Promise<VerifiedPrincipal>;

  /// App Check-only verification is limited to read-only confirmation after
  /// the Auth user and usable ID token are already absent.
  verifyAccountDeletionAttestation?(
    request: GatewayHeaderRequest,
  ): Promise<void>;
}

export class UnsupportedFirebaseTenantFailure extends GatewayFailure {
  constructor() {
    super(
      "unauthenticated",
      "Tenant-scoped Firebase identities are not supported.",
    );
    this.name = "UnsupportedFirebaseTenantFailure";
  }
}
