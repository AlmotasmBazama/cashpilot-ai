import 'dart:convert';

import '../../../../core/owner_scope/domain/owner_scope.dart';

/// Pure identity policy shared by Firebase adapters and consumers of the
/// public Auth boundary.
abstract final class AuthSessionIdentityPolicy {
  static void assertSupportedIdentity({
    required String uid,
    required String? tenantId,
  }) {
    OwnerScopeDerivation.fromConfirmedFirebaseUid(uid);
    if (utf8.encode(uid).length > 128 ||
        uid.contains('/') ||
        uid == '.' ||
        uid == '..') {
      throw StateError(
        'The Firebase identity cannot be represented as a safe user document.',
      );
    }
    if (tenantId != null) {
      throw StateError(
        'Tenant-scoped Firebase identities are not supported safely.',
      );
    }
  }

  static bool isSupportedIdentity({
    required String uid,
    required String? tenantId,
  }) {
    try {
      assertSupportedIdentity(uid: uid, tenantId: tenantId);
      return true;
    } on Object {
      return false;
    }
  }
}

final class FirebaseAuthSessionFingerprint {
  const FirebaseAuthSessionFingerprint({
    required this.uid,
    required this.isAnonymous,
    required this.tenantId,
  });

  final String uid;
  final bool isAnonymous;
  final String? tenantId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebaseAuthSessionFingerprint &&
          uid == other.uid &&
          isAnonymous == other.isAnonymous &&
          tenantId == other.tenantId;

  @override
  int get hashCode => Object.hash(uid, isAnonymous, tenantId);
}

typedef AuthSessionFingerprint = FirebaseAuthSessionFingerprint;

final class FirebaseAuthSessionSnapshot {
  const FirebaseAuthSessionSnapshot({
    required this.fingerprint,
    required this.generation,
  });

  final FirebaseAuthSessionFingerprint fingerprint;
  final int generation;
}

typedef AuthSessionSnapshot = FirebaseAuthSessionSnapshot;

/// A mutation-intent fence for authenticated and confirmed signed-out states.
final class FirebaseAuthSessionBoundary {
  const FirebaseAuthSessionBoundary({
    required this.fingerprint,
    required this.generation,
  });

  final FirebaseAuthSessionFingerprint? fingerprint;
  final int generation;
}

typedef AuthSessionBoundary = FirebaseAuthSessionBoundary;

/// Read-only, framework-independent view of the current native Auth epoch.
abstract interface class AuthSessionEpochReader {
  AuthSessionSnapshot? currentSnapshot();

  AuthSessionBoundary? currentBoundary();

  bool matches(AuthSessionSnapshot expected);

  bool matchesBoundary(AuthSessionBoundary expected);
}
