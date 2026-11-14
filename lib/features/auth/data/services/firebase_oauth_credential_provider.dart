import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../domain/services/auth_oauth_credential_provider.dart';
import 'firebase_auth_operation_coordinator.dart';

final class FirebaseOAuthCredentialResult
    extends AuthOAuthCredentialResult<firebase_auth.AuthCredential> {
  const FirebaseOAuthCredentialResult({
    required super.credential,
    super.displayName,
  });
}

/// Acquires third-party credentials without mutating the global Firebase Auth
/// session. Callers must perform the native Firebase sign-in/reauthentication
/// later, inside [FirebaseAuthOperationCoordinator] with adjacent guards.
abstract interface class FirebaseOAuthCredentialProvider
    implements AuthOAuthCredentialProvider<firebase_auth.AuthCredential> {
  @override
  Future<FirebaseOAuthCredentialResult> acquireGoogleCredential();

  @override
  Future<FirebaseOAuthCredentialResult> acquireAppleCredential({
    required bool requestFullName,
  });

  @override
  Future<void> signOutGoogle();
}

final class InteractiveFirebaseOAuthCredentialProviderFactory
    implements
        AuthOAuthCredentialProviderFactory<firebase_auth.AuthCredential> {
  const InteractiveFirebaseOAuthCredentialProviderFactory({
    required GoogleSignIn googleSignIn,
  }) : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;

  @override
  FirebaseOAuthCredentialProvider create() =>
      InteractiveFirebaseOAuthCredentialProvider(googleSignIn: _googleSignIn);
}

final class InteractiveFirebaseOAuthCredentialProvider
    implements FirebaseOAuthCredentialProvider {
  InteractiveFirebaseOAuthCredentialProvider({
    required GoogleSignIn googleSignIn,
  }) : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;
  var _googleInitialized = false;

  @override
  Future<FirebaseOAuthCredentialResult> acquireGoogleCredential() async {
    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate(
      scopeHint: const ['email', 'profile'],
    );
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw firebase_auth.FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }
    return FirebaseOAuthCredentialResult(
      credential: firebase_auth.GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<FirebaseOAuthCredentialResult> acquireAppleCredential({
    required bool requestFullName,
  }) async {
    if (!await SignInWithApple.isAvailable()) {
      throw UnsupportedError('Sign in with Apple is not available.');
    }
    final rawNonce = _generateNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: <AppleIDAuthorizationScopes>[
        AppleIDAuthorizationScopes.email,
        if (requestFullName) AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    final identityToken = appleCredential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw firebase_auth.FirebaseAuthException(
        code: 'missing-apple-id-token',
        message: 'Apple did not return an identity token.',
      );
    }
    return FirebaseOAuthCredentialResult(
      credential: firebase_auth.OAuthProvider(
        'apple.com',
      ).credential(idToken: identityToken, rawNonce: rawNonce),
      displayName: _displayName(
        appleCredential.givenName,
        appleCredential.familyName,
      ),
    );
  }

  @override
  Future<void> signOutGoogle() async {
    await _ensureGoogleInitialized();
    await _googleSignIn.signOut();
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }
    await _googleSignIn.initialize(
      clientId: _environmentValue('GOOGLE_CLIENT_ID'),
      serverClientId: _environmentValue('GOOGLE_SERVER_CLIENT_ID'),
    );
    _googleInitialized = true;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String? _environmentValue(String key) {
    const values = {
      'GOOGLE_CLIENT_ID': String.fromEnvironment('GOOGLE_CLIENT_ID'),
      'GOOGLE_SERVER_CLIENT_ID': String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
      ),
    };
    final value = values[key];
    return value == null || value.isEmpty ? null : value;
  }

  String? _displayName(String? givenName, String? familyName) {
    final parts = <String>[
      if (givenName?.trim().isNotEmpty == true) givenName!.trim(),
      if (familyName?.trim().isNotEmpty == true) familyName!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }
}
