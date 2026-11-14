import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_operation_coordinator.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_oauth_credential_provider.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';

void main() {
  for (final provider in _OAuthProvider.values) {
    test(
      '${provider.name} stale sign-in intent cannot replace a newer user',
      () async {
        final auth = _TestFirebaseAuth(null);
        final guard = FirebaseAuthSessionEpochGuard(auth);
        final oauth = _PausedOAuthCredentialProvider(provider);
        final overlay = _AllowCompletedDeletionOverlay();
        final source = FirebaseAuthDataSource(
          auth: auth,
          firestore: _NoFirestore(),
          googleSignIn: GoogleSignIn.instance,
          logger: AppLogger.instance,
          completedDeletionOverlay: overlay,
          sessionGuard: guard,
          oauthCredentialProvider: oauth,
        );
        addTearDown(() async {
          await source.dispose();
          await guard.dispose();
          await auth.dispose();
        });
        auth.emitCurrent();

        final signIn = switch (provider) {
          _OAuthProvider.google => source.signInWithGoogle(rememberMe: true),
          _OAuthProvider.apple => source.signInWithApple(rememberMe: true),
        };
        await oauth.acquisitionStarted.future;
        auth.replaceCurrent(_TestUser(uid: 'owner-b'));
        oauth.releaseCredential.complete();

        await expectLater(
          signIn,
          throwsA(
            isA<firebase_auth.FirebaseAuthException>().having(
              (error) => error.code,
              'code',
              'auth-session-changed',
            ),
          ),
        );
        expect(auth.signInWithCredentialCalls, 0);
      },
    );

    test(
      'deletion ${provider.name} prompt stays outside mutex and stale A never reauthenticates',
      () async {
        final userA = _TestUser(
          uid: 'owner-a',
          providerId: switch (provider) {
            _OAuthProvider.google => 'google.com',
            _OAuthProvider.apple => 'apple.com',
          },
        );
        final auth = _TestFirebaseAuth(userA);
        final guard = FirebaseAuthSessionEpochGuard(auth);
        final oauth = _PausedOAuthCredentialProvider(provider);
        final coordinator = FirebaseAuthOperationCoordinator();
        final overlay = _AllowCompletedDeletionOverlay();
        final source = FirebaseAccountDeletionAuthDataSource(
          auth: auth,
          sessionGuard: guard,
          completedDeletionOverlay: overlay,
          operationCoordinator: coordinator,
          oauthCredentialProvider: oauth,
        );
        addTearDown(() async {
          await source.dispose();
          await guard.dispose();
          await auth.dispose();
        });
        auth.emitCurrent();
        final lease = await source.issueConfirmationLease();
        final identity = await source.captureSession(lease);
        final context = DataDeletionOperationContext.captured(
          operationId: 'operation-oauth-race-${provider.name}',
          identity: identity,
          startedAtUtc: DateTime.utc(2026, 8, 10),
        );

        final reauthentication = source.reauthenticate(context);
        await oauth.acquisitionStarted.future;
        var adjacentOperationRan = false;
        await coordinator.run<void>(
          operation: () async => adjacentOperationRan = true,
        );
        expect(adjacentOperationRan, isTrue);

        auth.replaceCurrent(_TestUser(uid: 'owner-b'));
        oauth.releaseCredential.complete();

        await expectLater(
          reauthentication,
          throwsA(isA<AccountDeletionIdentityChangedException>()),
        );
        expect(userA.reauthenticateCalls, 0);
      },
    );
  }

  test(
    'terminal recovery completion suppresses cached A immediately and after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cashpilot-terminal-overlay-',
      );
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      var box = await Hive.openBox<dynamic>('terminal-overlay');
      final auth = _TestFirebaseAuth(_TestUser(uid: 'owner-a'));
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = HiveCompletedAccountDeletionOverlay(
        box: box,
        sessionGuard: guard,
      );
      auth.emitCurrent();

      await overlay.markCompleted(
        ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a'),
        capturedAuthGeneration: -1,
        operationId: 'operation-terminal-recovery',
      );
      expect(overlay.shouldSuppress(auth.currentUser), isTrue);

      await overlay.dispose();
      await guard.dispose();
      await auth.dispose();
      await box.close();

      box = await Hive.openBox<dynamic>('terminal-overlay');
      final restartedAuth = _TestFirebaseAuth(_TestUser(uid: 'owner-a'));
      final restartedGuard = FirebaseAuthSessionEpochGuard(restartedAuth);
      final restartedOverlay = HiveCompletedAccountDeletionOverlay(
        box: box,
        sessionGuard: restartedGuard,
      );
      addTearDown(() async {
        await restartedOverlay.dispose();
        await restartedGuard.dispose();
        await restartedAuth.dispose();
      });
      restartedAuth.emitCurrent();

      expect(
        restartedOverlay.shouldSuppress(restartedAuth.currentUser),
        isTrue,
      );
    },
  );
}

enum _OAuthProvider { google, apple }

final class _PausedOAuthCredentialProvider
    implements FirebaseOAuthCredentialProvider {
  _PausedOAuthCredentialProvider(this.expectedProvider);

  final _OAuthProvider expectedProvider;
  final Completer<void> acquisitionStarted = Completer<void>();
  final Completer<void> releaseCredential = Completer<void>();

  @override
  Future<FirebaseOAuthCredentialResult> acquireGoogleCredential() =>
      _acquire(_OAuthProvider.google);

  @override
  Future<FirebaseOAuthCredentialResult> acquireAppleCredential({
    required bool requestFullName,
  }) => _acquire(_OAuthProvider.apple);

  Future<FirebaseOAuthCredentialResult> _acquire(_OAuthProvider actual) async {
    expect(actual, expectedProvider);
    acquisitionStarted.complete();
    await releaseCredential.future;
    return FirebaseOAuthCredentialResult(
      credential: switch (actual) {
        _OAuthProvider.google => firebase_auth.GoogleAuthProvider.credential(
          idToken: 'test-google-id-token',
        ),
        _OAuthProvider.apple => firebase_auth.OAuthProvider(
          'apple.com',
        ).credential(idToken: 'test-apple-id-token', rawNonce: 'test-nonce'),
      },
      displayName: actual == _OAuthProvider.apple ? 'Test User' : null,
    );
  }

  @override
  Future<void> signOutGoogle() async {}
}

final class _TestFirebaseAuth implements firebase_auth.FirebaseAuth {
  _TestFirebaseAuth(this._currentUser);

  firebase_auth.User? _currentUser;
  final StreamController<firebase_auth.User?> _authStates =
      StreamController<firebase_auth.User?>.broadcast(sync: true);
  var signInWithCredentialCalls = 0;

  @override
  firebase_auth.User? get currentUser => _currentUser;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _authStates.stream;

  @override
  Future<firebase_auth.UserCredential> signInWithCredential(
    firebase_auth.AuthCredential credential,
  ) async {
    signInWithCredentialCalls += 1;
    final user = _TestUser(uid: 'oauth-result');
    _currentUser = user;
    _authStates.add(user);
    return _TestUserCredential(user);
  }

  void emitCurrent() => _authStates.add(_currentUser);

  void replaceCurrent(firebase_auth.User? user) {
    _currentUser = user;
    _authStates.add(user);
  }

  Future<void> dispose() => _authStates.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TestUser implements firebase_auth.User {
  _TestUser({required this.uid, String? providerId})
    : _providerData = providerId == null
          ? const <firebase_auth.UserInfo>[]
          : <firebase_auth.UserInfo>[_TestUserInfo(providerId)];

  @override
  final String uid;

  final List<firebase_auth.UserInfo> _providerData;
  var reauthenticateCalls = 0;

  @override
  String? get email => '$uid@example.com';

  @override
  bool get isAnonymous => false;

  @override
  String? get tenantId => null;

  @override
  List<firebase_auth.UserInfo> get providerData => _providerData;

  @override
  Future<firebase_auth.UserCredential> reauthenticateWithCredential(
    firebase_auth.AuthCredential credential,
  ) async {
    reauthenticateCalls += 1;
    return _TestUserCredential(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TestUserInfo implements firebase_auth.UserInfo {
  const _TestUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TestUserCredential implements firebase_auth.UserCredential {
  const _TestUserCredential(this.user);

  @override
  final firebase_auth.User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AllowCompletedDeletionOverlay
    implements CompletedAccountDeletionOverlay {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  bool shouldSuppress(firebase_auth.User? user) => false;

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) => false;

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {}
}

final class _NoFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
