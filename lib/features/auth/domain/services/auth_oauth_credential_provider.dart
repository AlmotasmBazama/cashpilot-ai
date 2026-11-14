/// Framework-independent result of acquiring an OAuth credential.
///
/// The concrete credential type is selected by the infrastructure adapter.
class AuthOAuthCredentialResult<TCredential extends Object> {
  const AuthOAuthCredentialResult({required this.credential, this.displayName});

  final TCredential credential;
  final String? displayName;
}

/// Acquires third-party credentials without mutating the authenticated
/// session. The native sign-in or reauthentication remains the caller's
/// responsibility and must run through [AuthOperationCoordinator].
abstract interface class AuthOAuthCredentialProvider<
  TCredential extends Object
> {
  Future<AuthOAuthCredentialResult<TCredential>> acquireGoogleCredential();

  Future<AuthOAuthCredentialResult<TCredential>> acquireAppleCredential({
    required bool requestFullName,
  });

  Future<void> signOutGoogle();
}

abstract interface class AuthOAuthCredentialProviderFactory<
  TCredential extends Object
> {
  AuthOAuthCredentialProvider<TCredential> create();
}
