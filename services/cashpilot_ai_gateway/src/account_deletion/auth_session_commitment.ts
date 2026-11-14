import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";

const sessionCommitmentDomain =
  "cashpilot.account-deletion-auth-session.v2";
const canonicalProofPattern = /^[A-Za-z0-9_-]{43}$/;
const deletionSessionProofBytes = 32;
const recoveryKeyDomain =
  "cashpilot.account-deletion-recovery-key.v1";
const recoveryAadDomain =
  "cashpilot.account-deletion-recovery-aad.v1";
const lowercaseSha256Pattern = /^[0-9a-f]{64}$/;
const operationIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface AccountDeletionRecoveryEnvelope {
  readonly version: 1;
  readonly ownerScopeCommitment: string;
  readonly uidNonce: string;
  readonly uidCiphertext: string;
  readonly uidAuthenticationTag: string;
}

export interface AccountDeletionAuthSessionClaims {
  readonly uid: string;
  readonly deletionSessionProof: string;
}

/// Accepts only an unpadded, canonical base64url encoding of 256 random bits.
/// The raw proof is transient request material and must never be persisted,
/// logged, or returned to the caller.
export function decodeAccountDeletionSessionProof(
  proof: string,
): Buffer {
  if (!canonicalProofPattern.test(proof)) {
    throw new TypeError(
      "A canonical 256-bit account-deletion session proof is required.",
    );
  }
  const decoded = Buffer.from(proof, "base64url");
  if (
    decoded.length !== deletionSessionProofBytes ||
    decoded.toString("base64url") !== proof
  ) {
    throw new TypeError(
      "A canonical 256-bit account-deletion session proof is required.",
    );
  }
  return decoded;
}

/// Binds an operation to the verified UID and a per-raw-Auth-generation proof.
/// Firebase token timestamps are deliberately excluded: `iat` changes during
/// refresh and `auth_time` changes during legitimate reauthentication of the
/// already-started deletion operation.
export function deriveAccountDeletionAuthSessionCommitment(
  claims: AccountDeletionAuthSessionClaims,
): string {
  if (
    claims.uid.length === 0 ||
    claims.uid.length > 128 ||
    claims.uid !== claims.uid.trim()
  ) {
    throw new TypeError("A canonical Firebase UID is required.");
  }
  const proof = decodeAccountDeletionSessionProof(
    claims.deletionSessionProof,
  );

  const uidLength = Buffer.byteLength(claims.uid, "utf8");
  const hash = createHash("sha256");
  hash.update(`${sessionCommitmentDomain}\0${uidLength}:`, "utf8");
  hash.update(claims.uid, "utf8");
  hash.update(`\0${proof.length}:`, "utf8");
  hash.update(proof);
  return hash.digest("hex");
}

function recoveryAad(
  operationId: string,
  ownerScopeCommitment: string,
  authSessionCommitment: string,
): Buffer {
  if (
    !operationIdPattern.test(operationId) ||
    !lowercaseSha256Pattern.test(ownerScopeCommitment) ||
    !lowercaseSha256Pattern.test(authSessionCommitment)
  ) {
    throw new TypeError("Canonical account-deletion recovery data is required.");
  }
  return Buffer.from(
    `${recoveryAadDomain}\0${operationId.length}:${operationId}\0` +
      `${ownerScopeCommitment.length}:${ownerScopeCommitment}\0` +
      `${authSessionCommitment.length}:${authSessionCommitment}`,
    "utf8",
  );
}

function recoveryKey(deletionSessionProof: string): Buffer {
  const proof = decodeAccountDeletionSessionProof(deletionSessionProof);
  return createHash("sha256")
    .update(`${recoveryKeyDomain}\0`, "utf8")
    .update(proof)
    .digest();
}

function decodeCanonicalBase64Url(
  value: string,
  expectedBytes?: number,
): Buffer {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new TypeError("Canonical account-deletion recovery data is required.");
  }
  const decoded = Buffer.from(value, "base64url");
  if (
    decoded.length === 0 ||
    decoded.toString("base64url") !== value ||
    (expectedBytes !== undefined && decoded.length !== expectedBytes)
  ) {
    throw new TypeError("Canonical account-deletion recovery data is required.");
  }
  return decoded;
}

/// Seals the UID for proof-only, read-only recovery after Firebase Auth has
/// already been deleted. Neither the UID nor the raw proof is persisted.
export function sealAccountDeletionRecoveryUid(input: {
  readonly uid: string;
  readonly operationId: string;
  readonly ownerScopeCommitment: string;
  readonly authSessionCommitment: string;
  readonly deletionSessionProof: string;
}): AccountDeletionRecoveryEnvelope {
  if (
    input.uid.length === 0 ||
    input.uid.length > 128 ||
    input.uid !== input.uid.trim()
  ) {
    throw new TypeError("A canonical Firebase UID is required.");
  }
  const nonce = randomBytes(12);
  const cipher = createCipheriv(
    "aes-256-gcm",
    recoveryKey(input.deletionSessionProof),
    nonce,
  );
  cipher.setAAD(
    recoveryAad(
      input.operationId,
      input.ownerScopeCommitment,
      input.authSessionCommitment,
    ),
  );
  const ciphertext = Buffer.concat([
    cipher.update(input.uid, "utf8"),
    cipher.final(),
  ]);
  return {
    version: 1,
    ownerScopeCommitment: input.ownerScopeCommitment,
    uidNonce: nonce.toString("base64url"),
    uidCiphertext: ciphertext.toString("base64url"),
    uidAuthenticationTag: cipher.getAuthTag().toString("base64url"),
  };
}

export function openAccountDeletionRecoveryUid(input: {
  readonly envelope: AccountDeletionRecoveryEnvelope;
  readonly operationId: string;
  readonly authSessionCommitment: string;
  readonly deletionSessionProof: string;
}): string {
  if (input.envelope.version !== 1) {
    throw new TypeError("Canonical account-deletion recovery data is required.");
  }
  const nonce = decodeCanonicalBase64Url(input.envelope.uidNonce, 12);
  const ciphertext = decodeCanonicalBase64Url(
    input.envelope.uidCiphertext,
  );
  const authenticationTag = decodeCanonicalBase64Url(
    input.envelope.uidAuthenticationTag,
    16,
  );
  const decipher = createDecipheriv(
    "aes-256-gcm",
    recoveryKey(input.deletionSessionProof),
    nonce,
  );
  decipher.setAAD(
    recoveryAad(
      input.operationId,
      input.envelope.ownerScopeCommitment,
      input.authSessionCommitment,
    ),
  );
  decipher.setAuthTag(authenticationTag);
  const uid = Buffer.concat([
    decipher.update(ciphertext),
    decipher.final(),
  ]).toString("utf8");
  if (uid.length === 0 || uid.length > 128 || uid !== uid.trim()) {
    throw new TypeError("Canonical account-deletion recovery data is required.");
  }
  return uid;
}
