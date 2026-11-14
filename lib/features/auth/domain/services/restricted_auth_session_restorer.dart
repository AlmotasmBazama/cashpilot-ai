import '../entities/auth_user.dart';

typedef AuthSessionAcceptancePolicy =
    bool Function(AuthSessionIdentity identity);

/// Restores a freshly authenticated session while allowing the caller to
/// reject and clear any identity outside its bounded recovery scope.
abstract interface class RestrictedAuthSessionRestorer {
  Future<AuthSessionIdentity?> signInWithEmail({
    required String email,
    required String password,
    required AuthSessionAcceptancePolicy acceptIdentity,
  });

  Future<AuthSessionIdentity?> signInWithGoogle({
    required AuthSessionAcceptancePolicy acceptIdentity,
  });

  Future<AuthSessionIdentity?> signInWithApple({
    required AuthSessionAcceptancePolicy acceptIdentity,
  });
}
