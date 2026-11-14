import { createHash, timingSafeEqual } from "node:crypto";

const ownerScopeDomain = "cashpilot.local-owner-scope.v1";
const lowercaseSha256 = /^[0-9a-f]{64}$/;

/// Mirrors Flutter's fail-closed OwnerScopeDerivation. Domain separation
/// ensures this local-owner commitment cannot be confused with the distinct
/// permanent Firestore lock document identifier.
export function deriveOwnerScopeCommitment(uid: string): string {
  if (uid.length === 0 || uid.length > 128 || uid !== uid.trim()) {
    throw new TypeError("A canonical Firebase UID is required.");
  }
  return createHash("sha256")
    .update(`${ownerScopeDomain}\0${uid}`, "utf8")
    .digest("hex");
}

export function ownerScopeCommitmentMatches(
  uid: string,
  suppliedCommitment: string,
): boolean {
  if (
    uid.length === 0 ||
    uid.length > 128 ||
    uid !== uid.trim() ||
    !lowercaseSha256.test(suppliedCommitment)
  ) {
    return false;
  }
  const expected = Buffer.from(deriveOwnerScopeCommitment(uid), "hex");
  const supplied = Buffer.from(suppliedCommitment, "hex");
  return (
    supplied.length === expected.length &&
    timingSafeEqual(expected, supplied)
  );
}
