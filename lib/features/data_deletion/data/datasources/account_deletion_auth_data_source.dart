import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:uuid/uuid.dart';

import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../auth/auth_contracts.dart';
import '../../domain/entities/data_deletion_operation_context.dart';
import '../../domain/entities/data_deletion_request.dart';

final class AccountDeletionIdentityChangedException implements Exception {
  const AccountDeletionIdentityChangedException();

  @override
  String toString() => 'Authenticated identity changed during deletion.';
}

abstract interface class AccountDeletionAuthDataSource {
  Future<AccountDeletionConfirmationLease> issueConfirmationLease();

  void releaseConfirmationLease(AccountDeletionConfirmationLease lease);

  Future<TrustedDeletionIdentity> captureSession(
    AccountDeletionConfirmationLease lease,
  );

  Future<void> reauthenticate(
    DataDeletionOperationContext context, {
    String? email,
    String? password,
  });

  Future<void> revalidate(DataDeletionOperationContext context);

  /// Requests fresh authorization through the captured session wrapper. Native
  /// SDKs may still resolve a different global session, so the gateway's opaque
  /// owner-scope commitment is the authoritative mutation boundary.
  Future<String> freshIdToken(DataDeletionOperationContext context);

  /// Uses only an already cached token to attest a previously completed
  /// server deletion. This must never be used before the durable local
  /// checkpoint reaches preferencesDeleted.
  Future<String> cachedIdTokenForFinalization(
    DataDeletionOperationContext context,
  );

  /// Synchronous identity fence used immediately before a destructive remote
  /// request is dispatched.
  void assertSessionCurrent(DataDeletionOperationContext context);

  Future<void> markServerDeletionCompleted(
    DataDeletionOperationContext context,
  );

  void releaseSession(TrustedDeletionIdentity identity);
}

class FirebaseAccountDeletionAuthDataSource
    implements AccountDeletionAuthDataSource {
  FirebaseAccountDeletionAuthDataSource({
    required firebase_auth.FirebaseAuth auth,
    required AuthSessionEpochReader sessionGuard,
    required AccountDeletionCompletionOverlay completedDeletionOverlay,
    required AuthOperationCoordinator operationCoordinator,
    required AuthOAuthCredentialProvider<firebase_auth.AuthCredential>
    oauthCredentialProvider,
  }) : _auth = auth,
       _sessionGuard = sessionGuard,
       _completedDeletionOverlay = completedDeletionOverlay,
       _operationCoordinator = operationCoordinator,
       _oauthCredentialProvider = oauthCredentialProvider;

  final firebase_auth.FirebaseAuth _auth;
  final AuthSessionEpochReader _sessionGuard;
  final AccountDeletionCompletionOverlay _completedDeletionOverlay;
  final AuthOperationCoordinator _operationCoordinator;
  final AuthOAuthCredentialProvider<firebase_auth.AuthCredential>
  _oauthCredentialProvider;
  final Map<String, _CapturedDeletionAuthSession> _sessions =
      <String, _CapturedDeletionAuthSession>{};
  final Map<String, _PendingConfirmationLease> _confirmationLeases =
      <String, _PendingConfirmationLease>{};
  Future<void> dispose() async {}

  @override
  Future<AccountDeletionConfirmationLease> issueConfirmationLease() async {
    final user = _requiredUser();
    final snapshot = _sessionGuard.currentSnapshot();
    if (snapshot == null ||
        snapshot.fingerprint.uid != user.uid ||
        snapshot.fingerprint.isAnonymous != user.isAnonymous ||
        snapshot.fingerprint.tenantId != user.tenantId) {
      throw const AccountDeletionIdentityChangedException();
    }
    final token = const Uuid().v7();
    final lease = AccountDeletionConfirmationLease(
      opaqueToken: token,
      email: user.email,
      isAnonymous: user.isAnonymous,
      ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
        user.uid,
      ).id.value,
      authSessionGeneration: snapshot.generation,
    );
    _confirmationLeases[token] = _PendingConfirmationLease(
      snapshot: snapshot,
      issuedLease: lease,
    );
    return lease;
  }

  @override
  void releaseConfirmationLease(AccountDeletionConfirmationLease lease) {
    _confirmationLeases.remove(lease.opaqueToken);
  }

  @override
  Future<TrustedDeletionIdentity> captureSession(
    AccountDeletionConfirmationLease lease,
  ) async {
    final pending = _confirmationLeases.remove(lease.opaqueToken);
    final user = _requiredUser();
    final snapshot = _sessionGuard.currentSnapshot();
    if (pending == null ||
        pending.issuedLease.opaqueToken != lease.opaqueToken ||
        pending.issuedLease.email != lease.email ||
        pending.issuedLease.isAnonymous != lease.isAnonymous ||
        pending.issuedLease.ownerScopeValue != lease.ownerScopeValue ||
        pending.issuedLease.authSessionGeneration !=
            lease.authSessionGeneration ||
        snapshot == null ||
        snapshot.generation != pending.snapshot.generation ||
        snapshot.fingerprint != pending.snapshot.fingerprint ||
        snapshot.fingerprint.uid != user.uid ||
        snapshot.fingerprint.isAnonymous != user.isAnonymous ||
        snapshot.fingerprint.tenantId != user.tenantId ||
        lease.isAnonymous != snapshot.fingerprint.isAnonymous ||
        lease.authSessionGeneration != snapshot.generation ||
        lease.ownerScopeValue !=
            OwnerScopeDerivation.fromConfirmedFirebaseUid(user.uid).id.value) {
      throw const AccountDeletionIdentityChangedException();
    }
    final identity = TrustedDeletionIdentity(
      authSessionId: const Uuid().v7(),
      authStateGeneration: snapshot.generation,
      userId: user.uid,
      isAnonymous: user.isAnonymous,
      ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(user.uid),
    );
    _sessions[identity.authSessionId] = _CapturedDeletionAuthSession(
      identity: identity,
      user: user,
      snapshot: snapshot,
    );
    return identity;
  }

  @override
  Future<void> reauthenticate(
    DataDeletionOperationContext context, {
    String? email,
    String? password,
  }) async {
    final captured = _requireCapturedSession(context);
    try {
      final credential = await _reauthenticationCredential(
        captured.user,
        email: email,
        password: password,
      );
      if (credential == null) {
        _assertCurrentIdentity(context.identity, captured);
        return;
      }
      await _operationCoordinator.run<void>(
        assertBefore: () => _assertCurrentIdentity(context.identity, captured),
        operation: () => captured.user.reauthenticateWithCredential(credential),
        assertAfter: (_) => _assertCurrentIdentity(context.identity, captured),
      );
    } on Object {
      _sessions.remove(context.identity.authSessionId);
      rethrow;
    }
  }

  @override
  Future<void> revalidate(DataDeletionOperationContext context) async {
    assertSessionCurrent(context);
  }

  @override
  Future<String> freshIdToken(DataDeletionOperationContext context) async {
    final captured = _requireCapturedSession(context);
    final token = await _operationCoordinator.run<String?>(
      assertBefore: () => _assertCurrentIdentity(context.identity, captured),
      operation: () => captured.user.getIdToken(true),
      assertAfter: (_) => _assertCurrentIdentity(context.identity, captured),
    );
    if (!_hasText(token)) {
      throw StateError('Fresh deletion authorization is unavailable.');
    }
    return token!;
  }

  @override
  Future<String> cachedIdTokenForFinalization(
    DataDeletionOperationContext context,
  ) async {
    final captured = _requireCapturedSession(context);
    final token = await _operationCoordinator.run<String?>(
      assertBefore: () => _assertCurrentIdentity(context.identity, captured),
      operation: () => captured.user.getIdToken(false),
      assertAfter: (_) => _assertCurrentIdentity(context.identity, captured),
    );
    if (!_hasText(token)) {
      throw StateError('Cached deletion authorization is unavailable.');
    }
    return token!;
  }

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) {
    final captured = _requireCapturedSession(context);
    _assertCurrentIdentity(context.identity, captured);
  }

  @override
  Future<void> markServerDeletionCompleted(
    DataDeletionOperationContext context,
  ) async {
    final captured = _capturedSessionForContext(context);
    await _completedDeletionOverlay.markCompleted(
      ownerScope: context.identity.ownerScope,
      capturedAuthGeneration: captured.snapshot.generation,
      operationId: context.operationId,
    );
    // The trusted gateway deleted Auth server-side, but FlutterFire may still
    // expose the cached A user until a later token refresh. Detach that exact
    // native session inside the shared Auth mutation boundary and synchronously
    // publish its revocation before terminal cleanup can progress. Never sign
    // out a concurrently installed B session.
    await _operationCoordinator.run<void>(
      operation: () async {
        final current = _auth.currentUser;
        if (current != null &&
            _fingerprintForUser(current) == captured.snapshot.fingerprint) {
          await _auth.signOut();
        }
      },
      assertAfter: (_) {
        final current = _auth.currentUser;
        if (current != null &&
            _fingerprintForUser(current) == captured.snapshot.fingerprint) {
          throw StateError('Deleted authentication session is still attached.');
        }
        // Polling the boundary synchronously advances/publishes the null or B
        // identity even if FlutterFire's auth callback is still queued.
        _sessionGuard.currentBoundary();
      },
    );
  }

  @override
  void releaseSession(TrustedDeletionIdentity identity) {
    _sessions.remove(identity.authSessionId);
  }

  Future<firebase_auth.AuthCredential?> _reauthenticationCredential(
    firebase_auth.User user, {
    String? email,
    String? password,
  }) async {
    if (user.isAnonymous) {
      return null;
    }
    final providers = user.providerData
        .map((provider) => provider.providerId)
        .toSet();

    if (providers.contains('password') &&
        _hasText(email) &&
        _hasText(password)) {
      return firebase_auth.EmailAuthProvider.credential(
        email: email!.trim(),
        password: password!,
      );
    }
    if (providers.contains('google.com')) {
      return (await _oauthCredentialProvider.acquireGoogleCredential())
          .credential;
    }
    if (providers.contains('apple.com')) {
      return (await _oauthCredentialProvider.acquireAppleCredential(
        requestFullName: false,
      )).credential;
    }
    if (providers.contains('password')) {
      throw firebase_auth.FirebaseAuthException(
        code: 'deletion-reauthentication-required',
        message: 'Enter the current password before deleting this account.',
      );
    }
    throw firebase_auth.FirebaseAuthException(
      code: 'deletion-reauthentication-unsupported',
      message: 'This account provider cannot be reauthenticated here.',
    );
  }

  firebase_auth.User _requiredUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionIdentityChangedException();
    }
    try {
      AuthSessionIdentityPolicy.assertSupportedIdentity(
        uid: user.uid,
        tenantId: user.tenantId,
      );
    } on Object {
      throw const AccountDeletionIdentityChangedException();
    }
    return user;
  }

  _CapturedDeletionAuthSession _requireCapturedSession(
    DataDeletionOperationContext context,
  ) {
    final captured = _capturedSessionForContext(context);
    if (!_sessionGuard.matches(captured.snapshot)) {
      throw const AccountDeletionIdentityChangedException();
    }
    return captured;
  }

  _CapturedDeletionAuthSession _capturedSessionForContext(
    DataDeletionOperationContext context,
  ) {
    final captured = _sessions[context.identity.authSessionId];
    if (captured == null ||
        captured.identity.userId != context.identity.userId ||
        captured.identity.isAnonymous != context.identity.isAnonymous ||
        captured.identity.ownerScope != context.identity.ownerScope ||
        captured.identity.authStateGeneration != captured.snapshot.generation) {
      throw const AccountDeletionIdentityChangedException();
    }
    return captured;
  }

  void _assertCurrentIdentity(
    TrustedDeletionIdentity identity,
    _CapturedDeletionAuthSession captured,
  ) {
    final snapshot = _sessionGuard.currentSnapshot();
    if (snapshot == null ||
        snapshot.generation != captured.snapshot.generation ||
        snapshot.fingerprint != captured.snapshot.fingerprint ||
        snapshot.fingerprint.uid != identity.userId ||
        snapshot.fingerprint.isAnonymous != identity.isAnonymous ||
        identity.authStateGeneration != snapshot.generation) {
      throw const AccountDeletionIdentityChangedException();
    }
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

final class _CapturedDeletionAuthSession {
  const _CapturedDeletionAuthSession({
    required this.identity,
    required this.user,
    required this.snapshot,
  });

  final TrustedDeletionIdentity identity;
  final firebase_auth.User user;
  final AuthSessionSnapshot snapshot;
}

final class _PendingConfirmationLease {
  const _PendingConfirmationLease({
    required this.snapshot,
    required this.issuedLease,
  });

  final AuthSessionSnapshot snapshot;
  final AccountDeletionConfirmationLease issuedLease;
}

AuthSessionFingerprint _fingerprintForUser(firebase_auth.User user) =>
    AuthSessionFingerprint(
      uid: user.uid,
      isAnonymous: user.isAnonymous,
      tenantId: user.tenantId,
    );
