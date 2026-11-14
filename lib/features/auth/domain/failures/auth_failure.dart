enum AuthFailureType {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  network,
  userCancelled,
  unsupportedProvider,
  requiresRecentLogin,
  userNotFound,
  firebaseNotConfigured,
  unknown,
}

class AuthFailure {
  const AuthFailure({
    required this.message,
    this.code,
    this.type = AuthFailureType.unknown,
  });

  final String message;
  final String? code;
  final AuthFailureType type;

  bool get requiresRecentLogin => type == AuthFailureType.requiresRecentLogin;
}
