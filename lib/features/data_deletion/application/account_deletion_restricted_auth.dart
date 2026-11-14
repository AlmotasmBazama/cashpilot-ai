import '../../../core/owner_scope/domain/owner_scope.dart';
import '../../auth/auth_contracts.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../domain/entities/data_deletion_operation_context.dart';

abstract interface class AccountDeletionRestrictedAuth {
  Future<AuthSessionIdentity?> signInWithEmail({
    required String email,
    required String password,
    required List<AccountDeletionRecoveryTarget> targets,
  });

  Future<AuthSessionIdentity?> signInWithGoogle({
    required List<AccountDeletionRecoveryTarget> targets,
  });

  Future<AuthSessionIdentity?> signInWithApple({
    required List<AccountDeletionRecoveryTarget> targets,
  });
}

/// Adapts the public Auth restoration boundary to the exact opaque owner
/// commitments retained by account-deletion startup recovery.
final class AccountDeletionRestrictedAuthAdapter
    implements AccountDeletionRestrictedAuth {
  const AccountDeletionRestrictedAuthAdapter({
    required RestrictedAuthSessionRestorer sessionRestorer,
  }) : _sessionRestorer = sessionRestorer;

  final RestrictedAuthSessionRestorer _sessionRestorer;

  @override
  Future<AuthSessionIdentity?> signInWithEmail({
    required String email,
    required String password,
    required List<AccountDeletionRecoveryTarget> targets,
  }) => _sessionRestorer.signInWithEmail(
    email: email,
    password: password,
    acceptIdentity: (identity) =>
        matchAccountDeletionRecoveryTarget(identity, targets) != null,
  );

  @override
  Future<AuthSessionIdentity?> signInWithGoogle({
    required List<AccountDeletionRecoveryTarget> targets,
  }) => _sessionRestorer.signInWithGoogle(
    acceptIdentity: (identity) =>
        matchAccountDeletionRecoveryTarget(identity, targets) != null,
  );

  @override
  Future<AuthSessionIdentity?> signInWithApple({
    required List<AccountDeletionRecoveryTarget> targets,
  }) => _sessionRestorer.signInWithApple(
    acceptIdentity: (identity) =>
        matchAccountDeletionRecoveryTarget(identity, targets) != null,
  );
}

AccountDeletionRecoveryTarget? matchAccountDeletionRecoveryTarget(
  AuthSessionIdentity? identity,
  List<AccountDeletionRecoveryTarget> targets,
) {
  if (identity == null || identity.tenantId != null) {
    return null;
  }
  try {
    final ownerScopeValue = OwnerScopeDerivation.fromConfirmedFirebaseUid(
      identity.uid,
    ).id.value;
    final matches = targets
        .where((target) => target.ownerScopeValue == ownerScopeValue)
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  } on Object {
    return null;
  }
}
