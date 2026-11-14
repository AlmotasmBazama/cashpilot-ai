import 'dart:convert';

import 'package:crypto/crypto.dart';

enum OwnerScopeStatus {
  unavailable,
  unauthenticated,
  initializing,
  legacyDataUnclaimed,
  migrating,
  safe,
  corrupted,
  crossScopeViolation,
}

enum OwnerScopeFailure {
  authUnavailable,
  authNotConfirmed,
  schemaUnsupported,
  legacyDataRequiresClaim,
  legacyDataAlreadyClaimed,
  migrationInProgress,
  integrityCheckFailed,
  scopedSessionUnavailable,
  durableAgentSchemaUnavailable,
  activeScopeChanged,
  deletionQuarantined,
}

/// An opaque, domain-separated local owner identifier. It is intentionally
/// not constructible from a route, model argument, widget value, or repository
/// parameter.
final class OwnerScopeId {
  const OwnerScopeId._(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OwnerScopeId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'OwnerScopeId(redacted)';
}

final class ConfirmedOwnerScope {
  const ConfirmedOwnerScope._({required this.id, required this.confirmedAt});

  final OwnerScopeId id;
  final DateTime confirmedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConfirmedOwnerScope && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ConfirmedOwnerScope(redacted)';
}

/// The only production derivation entry point. Callers must pass the UID read
/// directly from the confirmed Firebase Auth session; derived values are never
/// sent back to Firebase or to an AI provider.
abstract final class OwnerScopeDerivation {
  static const _domain = 'cashpilot.local-owner-scope.v1';

  static ConfirmedOwnerScope fromConfirmedFirebaseUid(
    String firebaseUid, {
    DateTime? confirmedAt,
  }) {
    if (firebaseUid.isEmpty || firebaseUid != firebaseUid.trim()) {
      throw ArgumentError.value(
        '<redacted>',
        'firebaseUid',
        'A non-empty canonical Firebase identity is required.',
      );
    }
    final bytes = utf8.encode('$_domain\u0000$firebaseUid');
    return ConfirmedOwnerScope._(
      id: OwnerScopeId._(sha256.convert(bytes).toString()),
      confirmedAt: (confirmedAt ?? DateTime.now()).toUtc(),
    );
  }

  /// Rehydrates an already-derived commitment only after a proof-bound server
  /// receipt has authorized UID-free terminal deletion recovery. This must not
  /// be used for ordinary reads, writes, routing, or authenticated sessions.
  static ConfirmedOwnerScope fromTrustedDeletionRecoveryCommitment(
    String ownerScopeValue, {
    DateTime? confirmedAt,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(ownerScopeValue)) {
      throw ArgumentError.value(
        '<redacted>',
        'ownerScopeValue',
        'A canonical opaque owner-scope commitment is required.',
      );
    }
    return ConfirmedOwnerScope._(
      id: OwnerScopeId._(ownerScopeValue),
      confirmedAt: (confirmedAt ?? DateTime.now()).toUtc(),
    );
  }
}

final class OwnerScopeSnapshot {
  const OwnerScopeSnapshot({
    required this.status,
    this.scope,
    this.failure,
    this.authSessionGeneration,
  });

  const OwnerScopeSnapshot.initializing()
    : status = OwnerScopeStatus.initializing,
      scope = null,
      failure = null,
      authSessionGeneration = null;

  final OwnerScopeStatus status;
  final ConfirmedOwnerScope? scope;
  final OwnerScopeFailure? failure;
  final int? authSessionGeneration;

  bool get hasConfirmedScope => scope != null;
}

final class OwnerScopeHealth {
  const OwnerScopeHealth({
    required this.status,
    this.failure,
    this.safeDetails = const <String, bool>{},
  });

  final OwnerScopeStatus status;
  final OwnerScopeFailure? failure;
  final Map<String, bool> safeDetails;

  bool get isSafe => status == OwnerScopeStatus.safe;
}

class OwnerScopeException implements Exception {
  const OwnerScopeException(this.failure);

  final OwnerScopeFailure failure;

  @override
  String toString() => 'OwnerScopeException(${failure.name})';
}
