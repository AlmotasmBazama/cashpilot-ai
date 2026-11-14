class AuthUser {
  const AuthUser({
    required this.uid,
    required this.emailVerified,
    required this.isAnonymous,
    this.authSessionGeneration = 0,
    this.tenantId,
    this.email,
    this.displayName,
    this.photoUrl,
    this.currency,
    this.language,
    this.country,
    this.timezone,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final bool isAnonymous;
  final int authSessionGeneration;
  final String? tenantId;
  final String? currency;
  final String? language;
  final String? country;
  final String? timezone;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;

  bool get needsEmailVerification {
    return !isAnonymous && email != null && !emailVerified;
  }

  bool get isProfileComplete {
    return _hasText(displayName) &&
        _hasText(currency) &&
        _hasText(language) &&
        _hasText(country) &&
        _hasText(timezone);
  }

  AuthSessionIdentity get sessionIdentity => AuthSessionIdentity(
    uid: uid,
    isAnonymous: isAnonymous,
    authSessionGeneration: authSessionGeneration,
    tenantId: tenantId,
  );

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    bool? isAnonymous,
    int? authSessionGeneration,
    String? tenantId,
    String? currency,
    String? language,
    String? country,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      authSessionGeneration:
          authSessionGeneration ?? this.authSessionGeneration,
      tenantId: tenantId ?? this.tenantId,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

final class AuthSessionIdentity {
  const AuthSessionIdentity({
    required this.uid,
    required this.isAnonymous,
    required this.authSessionGeneration,
    required this.tenantId,
  });

  final String uid;
  final bool isAnonymous;
  final int authSessionGeneration;
  final String? tenantId;

  bool matches(AuthUser? user) =>
      user != null &&
      user.uid == uid &&
      user.isAnonymous == isAnonymous &&
      user.authSessionGeneration == authSessionGeneration &&
      user.tenantId == tenantId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSessionIdentity &&
          uid == other.uid &&
          isAnonymous == other.isAnonymous &&
          authSessionGeneration == other.authSessionGeneration &&
          tenantId == other.tenantId;

  @override
  int get hashCode =>
      Object.hash(uid, isAnonymous, authSessionGeneration, tenantId);
}
