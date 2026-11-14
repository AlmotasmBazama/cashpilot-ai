import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class AuthUserDto {
  const AuthUserDto({
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

  factory AuthUserDto.fromFirebaseUser(
    firebase_auth.User user, {
    Map<String, dynamic>? profile,
    int authSessionGeneration = 0,
  }) {
    return AuthUserDto(
      uid: user.uid,
      email: _string(profile?['email']) ?? user.email,
      displayName: _string(profile?['name']) ?? user.displayName,
      photoUrl: _string(profile?['photoURL']) ?? user.photoURL,
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
      authSessionGeneration: authSessionGeneration,
      tenantId: user.tenantId,
      currency: _string(profile?['currency']),
      language: _string(profile?['language']),
      country: _string(profile?['country']),
      timezone: _string(profile?['timezone']),
      createdAt: _date(profile?['createdAt']) ?? user.metadata.creationTime,
      updatedAt: _date(profile?['updatedAt']),
      lastLogin: _date(profile?['lastLogin']) ?? user.metadata.lastSignInTime,
    );
  }

  static String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
