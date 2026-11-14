import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:hive/hive.dart';

import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../domain/services/account_deletion_completion_overlay.dart';
import '../../domain/services/auth_session_coordination.dart';

export '../../domain/services/account_deletion_completion_overlay.dart';
export '../../domain/services/auth_session_coordination.dart';

abstract final class FirebaseAuthIdentityPolicy {
  static void assertSupportedUser(firebase_auth.User user) {
    AuthSessionIdentityPolicy.assertSupportedIdentity(
      uid: user.uid,
      tenantId: user.tenantId,
    );
  }

  static bool isSupportedUser(firebase_auth.User user) {
    try {
      assertSupportedUser(user);
      return true;
    } on Object {
      return false;
    }
  }
}

FirebaseAuthSessionFingerprint firebaseAuthSessionFingerprintForUser(
  firebase_auth.User user,
) => FirebaseAuthSessionFingerprint(
  uid: user.uid,
  isAnonymous: user.isAnonymous,
  tenantId: user.tenantId,
);

/// An ordered native Auth event paired with the generation assigned to that
/// exact event. Consumers must use this pair instead of independently
/// subscribing to FlutterFire streams and then polling [FirebaseAuth].
final class FirebaseAuthSessionEvent {
  const FirebaseAuthSessionEvent({required this.user, required this.snapshot});

  final firebase_auth.User? user;
  final FirebaseAuthSessionSnapshot? snapshot;
}

/// Tracks real Auth identity transitions without relying on FlutterFire User
/// wrapper identity. Token refresh and newly allocated wrappers for the same
/// session do not advance the generation; UID/anonymous/tenant/null changes do.
final class FirebaseAuthSessionEpochGuard implements AuthSessionEpochReader {
  FirebaseAuthSessionEpochGuard(firebase_auth.FirebaseAuth auth)
    : _auth = auth,
      _currentFingerprint = _fingerprint(auth.currentUser),
      _publishedFingerprint = _fingerprint(auth.currentUser),
      _publishedUser = auth.currentUser {
    _subscription = _auth.authStateChanges().listen(
      _observeAuthState,
      onError: _observeAuthError,
      onDone: _observeAuthDone,
    );
  }

  final firebase_auth.FirebaseAuth _auth;
  late final StreamSubscription<firebase_auth.User?> _subscription;
  FirebaseAuthSessionFingerprint? _currentFingerprint;
  FirebaseAuthSessionFingerprint? _publishedFingerprint;
  firebase_auth.User? _publishedUser;
  var _publishedGeneration = 0;
  FirebaseAuthSessionFingerprint? _pendingPolledFingerprint;
  var _observedInitialAuthState = false;
  var _authStateHealthy = true;
  var _authStateTerminal = false;
  var _generation = 0;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  final StreamController<FirebaseAuthSessionEvent> _authStateEvents =
      StreamController<FirebaseAuthSessionEvent>.broadcast(sync: true);

  Stream<void> get changes => _changes.stream;

  /// The sole ordered identity stream backed by `authStateChanges()`.
  Stream<FirebaseAuthSessionEvent> get authStateEvents =>
      _authStateEvents.stream;

  FirebaseAuthSessionEvent currentAuthStateEvent() {
    final snapshot = currentSnapshot();
    final publishedFingerprint = _publishedFingerprint;
    if (snapshot == null ||
        publishedFingerprint == null ||
        snapshot.fingerprint != publishedFingerprint ||
        snapshot.generation != _publishedGeneration) {
      return const FirebaseAuthSessionEvent(user: null, snapshot: null);
    }
    final liveUser = _auth.currentUser;
    final publishedUser = liveUser ?? _publishedUser;
    if (publishedUser == null ||
        firebaseAuthSessionFingerprintForUser(publishedUser) !=
            publishedFingerprint) {
      return const FirebaseAuthSessionEvent(user: null, snapshot: null);
    }
    return FirebaseAuthSessionEvent(user: publishedUser, snapshot: snapshot);
  }

  @override
  FirebaseAuthSessionSnapshot? currentSnapshot() {
    final boundary = currentBoundary();
    final fingerprint = boundary?.fingerprint;
    if (boundary == null || fingerprint == null) {
      return null;
    }
    return FirebaseAuthSessionSnapshot(
      fingerprint: fingerprint,
      generation: boundary.generation,
    );
  }

  @override
  FirebaseAuthSessionBoundary? currentBoundary() {
    if (!_authStateHealthy || _authStateTerminal) {
      return null;
    }
    _synchronizeCurrentUser(_auth.currentUser);
    return FirebaseAuthSessionBoundary(
      fingerprint: _currentFingerprint,
      generation: _generation,
    );
  }

  @override
  bool matches(FirebaseAuthSessionSnapshot expected) {
    final current = currentSnapshot();
    return current != null &&
        current.generation == expected.generation &&
        current.fingerprint == expected.fingerprint;
  }

  @override
  bool matchesBoundary(FirebaseAuthSessionBoundary expected) {
    final current = currentBoundary();
    return current != null &&
        current.generation == expected.generation &&
        current.fingerprint == expected.fingerprint;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    if (!_authStateEvents.isClosed) {
      await _authStateEvents.close();
    }
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }

  void _observeAuthState(firebase_auth.User? user) {
    final next = _fingerprint(user);
    final live = _fingerprint(_auth.currentUser);
    // Firebase callbacks may already be queued when a newer currentUser is
    // installed. Never let an older queued event roll the ordered identity
    // back from the synchronously observed mutation fence.
    if (next != live) {
      return;
    }
    final recovered = !_authStateHealthy || _authStateTerminal;
    _authStateHealthy = true;
    _authStateTerminal = false;
    if (recovered) {
      _observedInitialAuthState = true;
      _pendingPolledFingerprint = null;
      _currentFingerprint = next;
      _generation += 1;
      _changes.add(null);
      _publishAuthStateEvent(user);
      return;
    }
    if (!_observedInitialAuthState) {
      _observedInitialAuthState = true;
      if (next == _currentFingerprint) {
        if (_pendingPolledFingerprint == next) {
          _pendingPolledFingerprint = null;
        }
        _publishAuthStateEvent(user);
        return;
      }
    }
    if (_pendingPolledFingerprint == next) {
      _pendingPolledFingerprint = null;
      _publishAuthStateEvent(user);
      return;
    }
    _pendingPolledFingerprint = null;
    _currentFingerprint = next;
    _generation += 1;
    _changes.add(null);
    _publishAuthStateEvent(user);
  }

  void _synchronizeCurrentUser(firebase_auth.User? user) {
    if (!_authStateHealthy || _authStateTerminal) {
      return;
    }
    final next = _fingerprint(user);
    if (next == _currentFingerprint) {
      return;
    }
    _currentFingerprint = next;
    _pendingPolledFingerprint = next;
    _generation += 1;
    _changes.add(null);
    _publishRevocation();
  }

  static FirebaseAuthSessionFingerprint? _fingerprint(
    firebase_auth.User? user,
  ) => user == null ? null : firebaseAuthSessionFingerprintForUser(user);

  void _publishAuthStateEvent(firebase_auth.User? user) {
    if (_authStateEvents.isClosed) {
      return;
    }
    final fingerprint = _currentFingerprint;
    _publishedFingerprint = fingerprint;
    _publishedUser = user;
    _publishedGeneration = _generation;
    _authStateEvents.add(
      FirebaseAuthSessionEvent(
        user: user,
        snapshot: fingerprint == null
            ? null
            : FirebaseAuthSessionSnapshot(
                fingerprint: fingerprint,
                generation: _generation,
              ),
      ),
    );
  }

  void _publishRevocation() {
    if (!_authStateEvents.isClosed) {
      _authStateEvents.add(
        const FirebaseAuthSessionEvent(user: null, snapshot: null),
      );
    }
  }

  void _observeAuthError(Object error, StackTrace stackTrace) {
    _authStateHealthy = false;
    _pendingPolledFingerprint = null;
    _changes.add(null);
    if (!_authStateEvents.isClosed) {
      _authStateEvents.addError(error, stackTrace);
    }
  }

  void _observeAuthDone() {
    _authStateHealthy = false;
    _authStateTerminal = true;
    _pendingPolledFingerprint = null;
    _changes.add(null);
    if (!_authStateEvents.isClosed) {
      unawaited(_authStateEvents.close());
    }
  }
}

abstract interface class CompletedAccountDeletionOverlay
    implements AccountDeletionCompletionOverlay {
  @override
  Stream<void> get changes;

  bool shouldSuppress(firebase_auth.User? user);

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  });

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  });
}

/// Effective-auth overlay written only after a verified server Auth deletion.
/// The durable key contains only the opaque owner scope. During this runtime,
/// the captured generation prevents a newly authenticated replacement session
/// from being hidden; after restart the durable tombstone fails closed against
/// a cached deleted token.
final class HiveCompletedAccountDeletionOverlay
    implements CompletedAccountDeletionOverlay {
  HiveCompletedAccountDeletionOverlay({
    required Box<dynamic> box,
    required FirebaseAuthSessionEpochGuard sessionGuard,
  }) : _box = box,
       _sessionGuard = sessionGuard;

  final Box<dynamic> _box;
  final FirebaseAuthSessionEpochGuard _sessionGuard;
  final Map<String, _RuntimeDeletionCompletion> _runtimeCompletions =
      <String, _RuntimeDeletionCompletion>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool shouldSuppress(firebase_auth.User? user) {
    if (user == null) {
      return false;
    }
    try {
      FirebaseAuthIdentityPolicy.assertSupportedUser(user);
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(user.uid);
      final scopeValue = scope.id.value;
      final runtimeCompletion = _runtimeCompletions[scopeValue];
      if (runtimeCompletion != null) {
        // A negative generation is written only by finalization recovery,
        // where the server has already deleted Auth and no trustworthy live
        // generation remains. It is therefore a terminal fail-closed marker,
        // not a session-scoped overlay exception.
        if (runtimeCompletion.authGeneration < 0) {
          return true;
        }
        final current = _sessionGuard.currentSnapshot();
        return current != null &&
            current.generation == runtimeCompletion.authGeneration &&
            current.fingerprint.uid == user.uid &&
            current.fingerprint.isAnonymous == user.isAnonymous &&
            current.fingerprint.tenantId == user.tenantId;
      }
      final value = _box.get(
        OwnerScopedStorageKeys.fromConfirmedOwnerScope(
          scope,
        ).completedAccountDeletion,
      );
      if (value == null) {
        return false;
      }
      if (!_isValidTombstone(value)) {
        return true;
      }
      return true;
    } on Object {
      // Effective Auth must fail closed for unsupported identities and for any
      // corrupt/unavailable local tombstone state. Never leak the raw UID here.
      return true;
    }
  }

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) {
    final completion = _runtimeCompletions[ownerScope.id.value];
    return completion != null &&
        completion.operationId == operationId &&
        completion.authGeneration == capturedAuthGeneration;
  }

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {
    final normalizedOperationId = operationId.trim();
    if (!RegExp(r'^[A-Za-z0-9-]{8,80}$').hasMatch(normalizedOperationId)) {
      throw StateError('Completed account deletion operation is invalid.');
    }
    final key = OwnerScopedStorageKeys.fromConfirmedOwnerScope(
      ownerScope,
    ).completedAccountDeletion;
    _runtimeCompletions[ownerScope.id.value] = _RuntimeDeletionCompletion(
      operationId: normalizedOperationId,
      authGeneration: capturedAuthGeneration,
    );
    _changes.add(null);
    await _box.put(
      key,
      jsonEncode(<String, Object>{
        'version': 1,
        'operationId': normalizedOperationId,
      }),
    );
  }

  Future<void> dispose() => _changes.close();

  bool _isValidTombstone(Object? value) {
    if (value is! String || value.length > 1024) {
      return false;
    }
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> &&
          decoded['version'] == 1 &&
          decoded['operationId'] is String &&
          RegExp(
            r'^[A-Za-z0-9-]{8,80}$',
          ).hasMatch(decoded['operationId'] as String);
    } on Object {
      return false;
    }
  }
}

final class _RuntimeDeletionCompletion {
  const _RuntimeDeletionCompletion({
    required this.operationId,
    required this.authGeneration,
  });

  final String operationId;
  final int authGeneration;
}
