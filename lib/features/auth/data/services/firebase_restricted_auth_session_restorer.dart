import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/services/auth_oauth_credential_provider.dart';
import '../../domain/services/restricted_auth_session_restorer.dart';
import 'firebase_auth_operation_coordinator.dart';
import 'firebase_auth_session_guard.dart';

/// Auth-only session restoration. It never reads a Firestore profile and does
/// not construct the normal Auth controller.
final class FirebaseRestrictedAuthSessionRestorer
    implements RestrictedAuthSessionRestorer {
  FirebaseRestrictedAuthSessionRestorer({
    required firebase_auth.FirebaseAuth auth,
    required FirebaseAuthSessionEpochGuard sessionGuard,
    required FirebaseAuthOperationCoordinator operationCoordinator,
    required AuthOAuthCredentialProvider<firebase_auth.AuthCredential>
    oauthCredentialProvider,
  }) : _auth = auth,
       _sessionGuard = sessionGuard,
       _operationCoordinator = operationCoordinator,
       _oauthCredentialProvider = oauthCredentialProvider;

  static const _eventTimeout = Duration(seconds: 10);

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseAuthSessionEpochGuard _sessionGuard;
  final FirebaseAuthOperationCoordinator _operationCoordinator;
  final AuthOAuthCredentialProvider<firebase_auth.AuthCredential>
  _oauthCredentialProvider;

  @override
  Future<AuthSessionIdentity?> signInWithEmail({
    required String email,
    required String password,
    required AuthSessionAcceptancePolicy acceptIdentity,
  }) async {
    final normalizedEmail = email.trim();
    if (!normalizedEmail.contains('@') || password.isEmpty) {
      return null;
    }
    return _restoreSession(
      acceptIdentity: acceptIdentity,
      acquireCredential: () async => null,
      signIn: (_) => _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      ),
    );
  }

  @override
  Future<AuthSessionIdentity?> signInWithGoogle({
    required AuthSessionAcceptancePolicy acceptIdentity,
  }) {
    return _restoreSession(
      acceptIdentity: acceptIdentity,
      acquireCredential: () async =>
          (await _oauthCredentialProvider.acquireGoogleCredential()).credential,
      signIn: (credential) => _auth.signInWithCredential(credential!),
    );
  }

  @override
  Future<AuthSessionIdentity?> signInWithApple({
    required AuthSessionAcceptancePolicy acceptIdentity,
  }) {
    return _restoreSession(
      acceptIdentity: acceptIdentity,
      acquireCredential: () async =>
          (await _oauthCredentialProvider.acquireAppleCredential(
            requestFullName: false,
          )).credential,
      signIn: (credential) => _auth.signInWithCredential(credential!),
    );
  }

  Future<AuthSessionIdentity?> _restoreSession({
    required AuthSessionAcceptancePolicy acceptIdentity,
    required Future<firebase_auth.AuthCredential?> Function() acquireCredential,
    required Future<firebase_auth.UserCredential> Function(
      firebase_auth.AuthCredential? credential,
    )
    signIn,
  }) async {
    final intent = _sessionGuard.currentBoundary();
    if (intent == null) {
      return null;
    }

    // OAuth UI runs outside the native mutation mutex. The captured boundary
    // is rechecked immediately inside the shared coordinator before any global
    // Firebase Auth state can be changed.
    final credential = await acquireCredential();
    if (!_sessionGuard.matchesBoundary(intent)) {
      return null;
    }

    final published = Completer<_FreshRestrictedSession?>();
    late final StreamSubscription<FirebaseAuthSessionEvent> subscription;
    subscription = _sessionGuard.authStateEvents.listen(
      (event) {
        final candidate = _freshSessionFromEvent(event, intent.generation);
        if (candidate != null &&
            acceptIdentity(candidate.identity) &&
            !published.isCompleted) {
          published.complete(candidate);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!published.isCompleted) {
          published.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!published.isCompleted) {
          published.complete(null);
        }
      },
    );

    try {
      final fresh = await _operationCoordinator.run<_FreshRestrictedSession?>(
        assertBefore: () {
          if (!_sessionGuard.matchesBoundary(intent)) {
            throw StateError(
              'The authenticated session changed before account recovery.',
            );
          }
        },
        operation: () async {
          if (_auth.currentUser != null) {
            await _auth.signOut();
            if (_auth.currentUser != null) {
              throw StateError(
                'The previous authenticated session could not be cleared.',
              );
            }
          }
          if (kIsWeb) {
            await _auth.setPersistence(firebase_auth.Persistence.LOCAL);
          }
          final result = await signIn(credential);
          final user = result.user;
          if (user == null || !_isCurrentResultUser(user)) {
            throw StateError('The restored authenticated user is invalid.');
          }
          final snapshot = _sessionGuard.currentSnapshot();
          final candidate = _freshSessionForUser(
            user,
            snapshot,
            afterGeneration: intent.generation,
          );
          if (candidate == null || !acceptIdentity(candidate.identity)) {
            await _clearUnexpectedResult(user);
            return null;
          }
          return candidate;
        },
        assertAfter: (fresh) {
          if (fresh != null && !_sessionGuard.matches(fresh.snapshot)) {
            throw StateError(
              'The restored authenticated session changed unexpectedly.',
            );
          }
        },
      );
      if (fresh == null) {
        return null;
      }

      final alreadyPublished = _freshSessionFromEvent(
        _sessionGuard.currentAuthStateEvent(),
        intent.generation,
      );
      final observed = alreadyPublished?.identity == fresh.identity
          ? alreadyPublished
          : await published.future.timeout(
              _eventTimeout,
              onTimeout: () => null,
            );
      if (observed?.identity != fresh.identity ||
          !_sessionGuard.matches(fresh.snapshot)) {
        return null;
      }
      return fresh.identity;
    } finally {
      await subscription.cancel();
    }
  }

  bool _isCurrentResultUser(firebase_auth.User user) {
    final current = _auth.currentUser;
    return current != null &&
        FirebaseAuthIdentityPolicy.isSupportedUser(user) &&
        FirebaseAuthIdentityPolicy.isSupportedUser(current) &&
        _fingerprintForUser(current) == _fingerprintForUser(user);
  }

  Future<void> _clearUnexpectedResult(firebase_auth.User resultUser) async {
    if (_isCurrentResultUser(resultUser)) {
      await _auth.signOut();
      if (_auth.currentUser != null) {
        throw StateError(
          'An unexpected authenticated account remained active.',
        );
      }
      _sessionGuard.currentBoundary();
    }
  }
}

final class _FreshRestrictedSession {
  const _FreshRestrictedSession({
    required this.identity,
    required this.snapshot,
  });

  final AuthSessionIdentity identity;
  final FirebaseAuthSessionSnapshot snapshot;
}

_FreshRestrictedSession? _freshSessionFromEvent(
  FirebaseAuthSessionEvent event,
  int afterGeneration,
) {
  final user = event.user;
  if (user == null) {
    return null;
  }
  return _freshSessionForUser(
    user,
    event.snapshot,
    afterGeneration: afterGeneration,
  );
}

_FreshRestrictedSession? _freshSessionForUser(
  firebase_auth.User user,
  FirebaseAuthSessionSnapshot? snapshot, {
  required int afterGeneration,
}) {
  if (snapshot == null ||
      snapshot.generation <= afterGeneration ||
      !FirebaseAuthIdentityPolicy.isSupportedUser(user) ||
      snapshot.fingerprint != _fingerprintForUser(user)) {
    return null;
  }
  return _FreshRestrictedSession(
    identity: AuthSessionIdentity(
      uid: snapshot.fingerprint.uid,
      isAnonymous: snapshot.fingerprint.isAnonymous,
      authSessionGeneration: snapshot.generation,
      tenantId: snapshot.fingerprint.tenantId,
    ),
    snapshot: snapshot,
  );
}

FirebaseAuthSessionFingerprint _fingerprintForUser(firebase_auth.User user) =>
    FirebaseAuthSessionFingerprint(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      tenantId: user.tenantId,
    );
