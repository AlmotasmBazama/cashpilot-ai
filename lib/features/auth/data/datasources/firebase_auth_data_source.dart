import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/services/auth_performance_trace.dart';
import '../dtos/auth_user_dto.dart';
import '../services/firebase_auth_operation_coordinator.dart';
import '../services/firebase_oauth_credential_provider.dart';
import '../services/firebase_auth_session_guard.dart';

abstract interface class AuthRemoteDataSource {
  Stream<AuthUserDto?> listenAuthState();

  Future<AuthUserDto?> getCurrentUser();

  Future<AuthUserDto> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  });

  Future<AuthUserDto> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthUserDto> signInWithGoogle({required bool rememberMe});

  Future<AuthUserDto> signInWithApple({required bool rememberMe});

  Future<AuthUserDto> signInAnonymously();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  Future<AuthUserDto?> refreshUser();

  Future<AuthUserDto> completeProfile({
    required AuthSessionIdentity expectedSession,
    required String displayName,
    required String currency,
    required String language,
    required String country,
    required String timezone,
  });

  Future<AuthUserDto> reauthenticateWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

typedef _CapturedFirebaseAuthSession = ({
  firebase_auth.User user,
  FirebaseAuthSessionSnapshot snapshot,
});

class FirebaseAuthDataSource implements AuthRemoteDataSource {
  FirebaseAuthDataSource({
    required firebase_auth.FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
    required AppLogger logger,
    required CompletedAccountDeletionOverlay completedDeletionOverlay,
    required FirebaseAuthSessionEpochGuard sessionGuard,
    FirebaseAuthOperationCoordinator? operationCoordinator,
    FirebaseOAuthCredentialProvider? oauthCredentialProvider,
  }) : _auth = auth,
       _firestore = firestore,
       _logger = logger,
       _completedDeletionOverlay = completedDeletionOverlay,
       _sessionGuard = sessionGuard,
       _operationCoordinator =
           operationCoordinator ?? FirebaseAuthOperationCoordinator(),
       _oauthCredentialProvider =
           oauthCredentialProvider ??
           InteractiveFirebaseOAuthCredentialProvider(
             googleSignIn: googleSignIn,
           );

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AppLogger _logger;
  final CompletedAccountDeletionOverlay _completedDeletionOverlay;
  final FirebaseAuthSessionEpochGuard _sessionGuard;
  final FirebaseAuthOperationCoordinator _operationCoordinator;
  final FirebaseOAuthCredentialProvider _oauthCredentialProvider;
  final StreamController<FirebaseAuthSessionEvent> _profileRefreshes =
      StreamController<FirebaseAuthSessionEvent>.broadcast(sync: true);

  static const _profileReadTimeout = Duration(seconds: 5);

  @override
  Stream<AuthUserDto?> listenAuthState() {
    late final StreamController<AuthUserDto?> controller;
    StreamSubscription<FirebaseAuthSessionEvent>? authSubscription;
    StreamSubscription<void>? overlaySubscription;
    StreamSubscription<FirebaseAuthSessionEvent>? profileSubscription;
    var mappingEpoch = 0;
    var ended = false;
    FirebaseAuthSessionSnapshot? hydratedSnapshot;

    void publish(FirebaseAuthSessionEvent event) {
      if (ended) {
        return;
      }
      final eventEpoch = ++mappingEpoch;
      final user = event.user;
      final snapshot = event.snapshot;
      // Validate the identity policy before touching any owner-scoped overlay.
      if (user == null ||
          snapshot == null ||
          !FirebaseAuthIdentityPolicy.isSupportedUser(user) ||
          snapshot.fingerprint != firebaseAuthSessionFingerprintForUser(user) ||
          _shouldSuppressFailClosed(user)) {
        hydratedSnapshot = null;
        controller.add(null);
        return;
      }
      final alreadyHydrated =
          hydratedSnapshot?.generation == snapshot.generation &&
          hydratedSnapshot?.fingerprint == snapshot.fingerprint;
      if (!alreadyHydrated) {
        // A native identity is not an effective application identity until
        // its profile read succeeds (an absent document is a valid hydrated
        // incomplete profile; an outage is not).
        controller.add(null);
      }
      unawaited(
        _dtoForUser(user, authSessionGeneration: snapshot.generation)
            .then((dto) {
              if (!ended &&
                  eventEpoch == mappingEpoch &&
                  _sessionGuard.matches(snapshot) &&
                  FirebaseAuthIdentityPolicy.isSupportedUser(user) &&
                  !_shouldSuppressFailClosed(user)) {
                hydratedSnapshot = snapshot;
                controller.add(dto);
              }
            })
            .catchError((Object error, StackTrace stackTrace) {
              if (!ended && eventEpoch == mappingEpoch) {
                hydratedSnapshot = null;
                controller.add(null);
                controller.addError(error, stackTrace);
              }
            }),
      );
    }

    void failClosed([Object? error, StackTrace? stackTrace]) {
      if (ended) {
        return;
      }
      mappingEpoch++;
      hydratedSnapshot = null;
      controller.add(null);
      if (error != null) {
        controller.addError(error, stackTrace ?? StackTrace.current);
      }
    }

    Future<void> closeFailClosed() async {
      if (ended) {
        return;
      }
      failClosed();
      ended = true;
      await overlaySubscription?.cancel();
      await profileSubscription?.cancel();
      await controller.close();
    }

    controller = StreamController<AuthUserDto?>(
      sync: true,
      onListen: () {
        authSubscription = _sessionGuard.authStateEvents.listen(
          publish,
          onError: failClosed,
          onDone: closeFailClosed,
        );
        overlaySubscription = _completedDeletionOverlay.changes.listen(
          (_) => publish(_sessionGuard.currentAuthStateEvent()),
          onError: failClosed,
        );
        profileSubscription = _profileRefreshes.stream.listen(
          publish,
          onError: failClosed,
        );
        publish(_sessionGuard.currentAuthStateEvent());
      },
      onCancel: () async {
        ended = true;
        await authSubscription?.cancel();
        await overlaySubscription?.cancel();
        await profileSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<AuthUserDto?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null ||
        !FirebaseAuthIdentityPolicy.isSupportedUser(user) ||
        _shouldSuppressFailClosed(user)) {
      return null;
    }
    final snapshot = _matchingSnapshot(user);
    if (snapshot == null) {
      return null;
    }
    if (!FirebaseAuthIdentityPolicy.isSupportedUser(user)) {
      return null;
    }
    return _dtoForUser(user, authSessionGeneration: snapshot.generation);
  }

  @override
  Future<AuthUserDto> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final trace = AuthPerformanceTrace.start(
      operation: 'sign_in',
      log: _logger.info,
    );
    try {
      final intentBoundary = _captureAuthMutationIntent();
      final credential = await _operationCoordinator
          .run<firebase_auth.UserCredential>(
            assertBefore: () => _assertAuthMutationIntent(intentBoundary),
            operation: () async {
              await _applyPersistence(rememberMe);
              trace.mark(AuthTraceStage.persistenceConfigured);
              _assertAuthMutationIntent(intentBoundary);
              final result = await _auth.signInWithEmailAndPassword(
                email: email.trim(),
                password: password,
              );
              trace.mark(AuthTraceStage.providerResponded);
              _assertNativeSignInResultCurrent(result);
              return result;
            },
          );
      final user = _requireUser(credential.user);
      final captured = _captureCurrentNativeSession(user);
      final profile = await _prepareUserDocument(user);
      trace.mark(AuthTraceStage.profileBootstrapCompleted);
      _assertCapturedNativeSession(captured);
      final dto = AuthUserDto.fromFirebaseUser(
        user,
        profile: profile,
        authSessionGeneration: captured.snapshot.generation,
      );
      trace.mark(AuthTraceStage.profileHydrationCompleted);
      _assertCapturedNativeSession(captured);
      trace.mark(AuthTraceStage.completed);
      return dto;
    } on Object {
      trace.mark(AuthTraceStage.failed);
      rethrow;
    }
  }

  @override
  Future<AuthUserDto> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final trace = AuthPerformanceTrace.start(
      operation: 'sign_up',
      log: _logger.info,
    );
    try {
      final intentBoundary = _captureAuthMutationIntent();
      final credential = await _operationCoordinator
          .run<firebase_auth.UserCredential>(
            assertBefore: () => _assertAuthMutationIntent(intentBoundary),
            operation: () async {
              await _applyPersistence(true);
              trace.mark(AuthTraceStage.persistenceConfigured);
              _assertAuthMutationIntent(intentBoundary);
              final result = await _auth.createUserWithEmailAndPassword(
                email: email.trim(),
                password: password,
              );
              trace.mark(AuthTraceStage.providerResponded);
              _assertNativeSignInResultCurrent(result);
              return result;
            },
          );
      final user = _requireUser(credential.user);
      final captured = _captureCurrentNativeSession(user);
      await _runCapturedNativeOperation<void>(
        captured,
        () => user.updateDisplayName(name.trim()),
      );
      final profile = await _prepareUserDocument(
        user,
        displayName: name.trim(),
      );
      trace.mark(AuthTraceStage.profileBootstrapCompleted);
      await _runCapturedNativeOperation<void>(
        captured,
        user.sendEmailVerification,
      );
      await _runCapturedNativeOperation<void>(captured, user.reload);
      final dto = AuthUserDto.fromFirebaseUser(
        user,
        profile: profile,
        authSessionGeneration: captured.snapshot.generation,
      );
      trace.mark(AuthTraceStage.profileHydrationCompleted);
      _assertCapturedNativeSession(captured);
      trace.mark(AuthTraceStage.completed);
      return dto;
    } on Object {
      trace.mark(AuthTraceStage.failed);
      rethrow;
    }
  }

  @override
  Future<AuthUserDto> signInWithGoogle({required bool rememberMe}) async {
    final intentBoundary = _captureAuthMutationIntent();
    final oauth = await _oauthCredentialProvider.acquireGoogleCredential();
    final result = await _operationCoordinator
        .run<firebase_auth.UserCredential>(
          assertBefore: () => _assertAuthMutationIntent(intentBoundary),
          operation: () async {
            await _applyPersistence(rememberMe);
            _assertAuthMutationIntent(intentBoundary);
            final signedIn = await _auth.signInWithCredential(oauth.credential);
            _assertNativeSignInResultCurrent(signedIn);
            return signedIn;
          },
        );
    final user = _requireUser(result.user);
    final captured = _captureCurrentNativeSession(user);
    await _prepareUserDocument(user);
    _assertCapturedNativeSession(captured);
    final dto = await _dtoForUser(
      user,
      authSessionGeneration: captured.snapshot.generation,
    );
    _assertCapturedNativeSession(captured);
    return dto;
  }

  @override
  Future<AuthUserDto> signInWithApple({required bool rememberMe}) async {
    final intentBoundary = _captureAuthMutationIntent();
    final oauth = await _oauthCredentialProvider.acquireAppleCredential(
      requestFullName: true,
    );
    final result = await _operationCoordinator
        .run<firebase_auth.UserCredential>(
          assertBefore: () => _assertAuthMutationIntent(intentBoundary),
          operation: () async {
            await _applyPersistence(rememberMe);
            _assertAuthMutationIntent(intentBoundary);
            final signedIn = await _auth.signInWithCredential(oauth.credential);
            _assertNativeSignInResultCurrent(signedIn);
            return signedIn;
          },
        );
    final user = _requireUser(result.user);
    final captured = _captureCurrentNativeSession(user);
    final displayName = oauth.displayName;
    if (displayName != null && (user.displayName ?? '').isEmpty) {
      await _runCapturedNativeOperation<void>(
        captured,
        () => user.updateDisplayName(displayName),
      );
    }
    await _prepareUserDocument(user, displayName: displayName);
    _assertCapturedNativeSession(captured);
    final dto = await _dtoForUser(
      user,
      authSessionGeneration: captured.snapshot.generation,
    );
    _assertCapturedNativeSession(captured);
    return dto;
  }

  @override
  Future<AuthUserDto> signInAnonymously() async {
    final intentBoundary = _captureAuthMutationIntent();
    final credential = await _operationCoordinator
        .run<firebase_auth.UserCredential>(
          assertBefore: () => _assertAuthMutationIntent(intentBoundary),
          operation: () async {
            _assertAuthMutationIntent(intentBoundary);
            final result = await _auth.signInAnonymously();
            _assertNativeSignInResultCurrent(result);
            return result;
          },
        );
    final user = _requireUser(credential.user);
    final captured = _captureCurrentNativeSession(user);
    await _prepareUserDocument(user, displayName: 'Guest');
    _assertCapturedNativeSession(captured);
    final dto = await _dtoForUser(
      user,
      authSessionGeneration: captured.snapshot.generation,
    );
    _assertCapturedNativeSession(captured);
    return dto;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _requireUser(_auth.currentUser);
    final captured = _captureCurrentNativeSession(user);
    if (!user.emailVerified && !user.isAnonymous) {
      await _runCapturedNativeOperation<void>(
        captured,
        user.sendEmailVerification,
      );
    }
  }

  @override
  Future<AuthUserDto?> refreshUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final captured = _captureCurrentNativeSession(user);
    await _runCapturedNativeOperation<void>(captured, user.reload);
    final refreshed = _auth.currentUser;
    if (refreshed == null) {
      return null;
    }
    _publishProfileRefresh(refreshed);
    final dto = await _dtoForUser(
      refreshed,
      authSessionGeneration: captured.snapshot.generation,
    );
    _assertCapturedNativeSession(captured);
    return dto;
  }

  @override
  Future<AuthUserDto> completeProfile({
    required AuthSessionIdentity expectedSession,
    required String displayName,
    required String currency,
    required String language,
    required String country,
    required String timezone,
  }) async {
    final captured = _captureExpectedSession(expectedSession);
    final user = captured.user;
    _assertExpectedSession(expectedSession, captured);
    await _operationCoordinator.run<void>(
      assertBefore: () => _assertExpectedSession(expectedSession, captured),
      operation: () => user.updateDisplayName(displayName.trim()),
      assertAfter: (_) => _assertExpectedSession(expectedSession, captured),
    );
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': displayName.trim(),
      'email': user.email,
      'photoURL': user.photoURL,
      'currency': CurrencyCatalog.normalizeCode(currency),
      'language': language.trim(),
      'country': country.trim(),
      'timezone': timezone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _assertExpectedSession(expectedSession, captured);
    await _operationCoordinator.run<void>(
      assertBefore: () => _assertExpectedSession(expectedSession, captured),
      operation: user.reload,
      assertAfter: (_) => _assertExpectedSession(expectedSession, captured),
    );
    final dto = await _dtoForUser(
      user,
      authSessionGeneration: captured.snapshot.generation,
    );
    _assertExpectedSession(expectedSession, captured);
    _publishProfileRefresh(user);
    return dto;
  }

  @override
  Future<AuthUserDto> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final user = _requireUser(_auth.currentUser);
    final captured = _captureCurrentNativeSession(user);
    final credential = firebase_auth.EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final result =
        await _runCapturedNativeOperation<firebase_auth.UserCredential>(
          captured,
          () => user.reauthenticateWithCredential(credential),
        );
    final resultUser = _requireUser(result.user);
    final dto = await _dtoForUser(
      resultUser,
      authSessionGeneration: captured.snapshot.generation,
    );
    _assertCapturedNativeSession(captured);
    return dto;
  }

  @override
  Future<void> signOut() async {
    final expectedUser = _auth.currentUser;
    final expected = _sessionGuard.currentSnapshot();
    if (expectedUser != null && expected == null) {
      throw firebase_auth.FirebaseAuthException(
        code: 'auth-session-changed',
        message: 'The authenticated session is not safely confirmed.',
      );
    }
    await _operationCoordinator.run<void>(
      assertBefore: () {
        if ((expected == null && _auth.currentUser != null) ||
            (expected != null && !_sessionGuard.matches(expected))) {
          throw firebase_auth.FirebaseAuthException(
            code: 'auth-session-changed',
            message: 'The authenticated session changed before sign out.',
          );
        }
      },
      operation: () async {
        // Revoke Firebase first. Google cleanup is intentionally second and
        // remains inside the same serialized boundary.
        await _auth.signOut();
        if (_auth.currentUser != null) {
          throw firebase_auth.FirebaseAuthException(
            code: 'sign-out-incomplete',
            message: 'Firebase did not clear the authenticated session.',
          );
        }
        await _tryGoogleSignOut();
      },
    );
  }

  Future<void> _applyPersistence(bool rememberMe) async {
    if (!kIsWeb) {
      return;
    }

    await _auth.setPersistence(
      rememberMe
          ? firebase_auth.Persistence.LOCAL
          : firebase_auth.Persistence.SESSION,
    );
  }

  Future<void> _tryGoogleSignOut() async {
    try {
      await _oauthCredentialProvider.signOutGoogle();
    } on Object catch (error, stackTrace) {
      _logger.warning('Unable to sign out of Google.', error, stackTrace);
    }
  }

  Future<AuthUserDto> _dtoForUser(
    firebase_auth.User user, {
    int? authSessionGeneration,
  }) async {
    FirebaseAuthIdentityPolicy.assertSupportedUser(user);
    final generation =
        authSessionGeneration ?? _matchingSnapshot(user)?.generation ?? -1;
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(_profileReadTimeout);
    return AuthUserDto.fromFirebaseUser(
      user,
      profile: snapshot.data(),
      authSessionGeneration: generation,
    );
  }

  FirebaseAuthSessionSnapshot? _matchingSnapshot(firebase_auth.User user) {
    final snapshot = _sessionGuard.currentSnapshot();
    if (snapshot == null) {
      return null;
    }
    final fingerprint = firebaseAuthSessionFingerprintForUser(user);
    return snapshot.fingerprint == fingerprint ? snapshot : null;
  }

  ({firebase_auth.User user, FirebaseAuthSessionSnapshot snapshot})
  _captureExpectedSession(AuthSessionIdentity expected) {
    final user = _requireUser(_auth.currentUser);
    FirebaseAuthIdentityPolicy.assertSupportedUser(user);
    final snapshot = _matchingSnapshot(user);
    if (snapshot == null ||
        snapshot.generation != expected.authSessionGeneration ||
        snapshot.fingerprint.uid != expected.uid ||
        snapshot.fingerprint.isAnonymous != expected.isAnonymous ||
        snapshot.fingerprint.tenantId != expected.tenantId) {
      throw firebase_auth.FirebaseAuthException(
        code: 'auth-session-changed',
        message: 'The authenticated session changed before profile update.',
      );
    }
    return (user: user, snapshot: snapshot);
  }

  _CapturedFirebaseAuthSession _captureCurrentNativeSession(
    firebase_auth.User user,
  ) {
    FirebaseAuthIdentityPolicy.assertSupportedUser(user);
    final snapshot = _matchingSnapshot(user);
    if (snapshot == null) {
      throw firebase_auth.FirebaseAuthException(
        code: 'auth-session-changed',
        message: 'The authenticated session is no longer current.',
      );
    }
    final captured = (user: user, snapshot: snapshot);
    _assertCapturedNativeSession(captured);
    return captured;
  }

  FirebaseAuthSessionBoundary _captureAuthMutationIntent() {
    final boundary = _sessionGuard.currentBoundary();
    final current = _auth.currentUser;
    if (boundary == null) {
      throw _authSessionChanged();
    }
    if (current != null) {
      FirebaseAuthIdentityPolicy.assertSupportedUser(current);
    }
    final currentFingerprint = current == null
        ? null
        : firebaseAuthSessionFingerprintForUser(current);
    if (currentFingerprint != boundary.fingerprint) {
      throw _authSessionChanged();
    }
    return boundary;
  }

  void _assertAuthMutationIntent(FirebaseAuthSessionBoundary expected) {
    final current = _auth.currentUser;
    if (!_sessionGuard.matchesBoundary(expected) ||
        (current != null &&
            !FirebaseAuthIdentityPolicy.isSupportedUser(current)) ||
        (current == null
                ? null
                : firebaseAuthSessionFingerprintForUser(current)) !=
            expected.fingerprint) {
      throw _authSessionChanged();
    }
  }

  void _assertNativeSignInResultCurrent(
    firebase_auth.UserCredential credential,
  ) {
    final resultUser = _requireUser(credential.user);
    final current = _auth.currentUser;
    if (current == null ||
        !FirebaseAuthIdentityPolicy.isSupportedUser(current) ||
        !FirebaseAuthIdentityPolicy.isSupportedUser(resultUser) ||
        firebaseAuthSessionFingerprintForUser(current) !=
            firebaseAuthSessionFingerprintForUser(resultUser)) {
      throw _authSessionChanged();
    }
  }

  firebase_auth.FirebaseAuthException _authSessionChanged() =>
      firebase_auth.FirebaseAuthException(
        code: 'auth-session-changed',
        message: 'The authenticated session changed before sign in.',
      );

  Future<T> _runCapturedNativeOperation<T>(
    _CapturedFirebaseAuthSession captured,
    Future<T> Function() operation,
  ) {
    return _operationCoordinator.run<T>(
      assertBefore: () => _assertCapturedNativeSession(captured),
      operation: operation,
      assertAfter: (_) => _assertCapturedNativeSession(captured),
    );
  }

  void _assertCapturedNativeSession(_CapturedFirebaseAuthSession captured) {
    final current = _auth.currentUser;
    if (current == null ||
        !FirebaseAuthIdentityPolicy.isSupportedUser(current) ||
        !_sessionGuard.matches(captured.snapshot) ||
        firebaseAuthSessionFingerprintForUser(current) !=
            captured.snapshot.fingerprint ||
        firebaseAuthSessionFingerprintForUser(captured.user) !=
            captured.snapshot.fingerprint) {
      throw firebase_auth.FirebaseAuthException(
        code: 'auth-session-changed',
        message: 'The authenticated session changed during the operation.',
      );
    }
  }

  void _assertExpectedSession(
    AuthSessionIdentity expected,
    ({firebase_auth.User user, FirebaseAuthSessionSnapshot snapshot}) captured,
  ) {
    final current = _auth.currentUser;
    if (current == null ||
        !FirebaseAuthIdentityPolicy.isSupportedUser(current) ||
        !_sessionGuard.matches(captured.snapshot)) {
      throw firebase_auth.FirebaseAuthException(
        code: 'auth-session-changed',
        message: 'The authenticated session changed during profile update.',
      );
    }
    final currentFingerprint = firebaseAuthSessionFingerprintForUser(current);
    final capturedFingerprint = firebaseAuthSessionFingerprintForUser(
      captured.user,
    );
    if (captured.snapshot.generation != expected.authSessionGeneration ||
        capturedFingerprint != captured.snapshot.fingerprint ||
        currentFingerprint != captured.snapshot.fingerprint ||
        currentFingerprint.uid != expected.uid ||
        currentFingerprint.isAnonymous != expected.isAnonymous ||
        currentFingerprint.tenantId != expected.tenantId) {
      throw firebase_auth.FirebaseAuthException(
        code: 'auth-session-changed',
        message: 'The authenticated session changed during profile update.',
      );
    }
  }

  Future<Map<String, dynamic>> _prepareUserDocument(
    firebase_auth.User user, {
    String? displayName,
  }) async {
    FirebaseAuthIdentityPolicy.assertSupportedUser(user);
    final doc = _firestore.collection('users').doc(user.uid);
    final snapshot = await doc.get();
    final hasDocument = snapshot.exists;
    final nowValue = FieldValue.serverTimestamp();
    final name = _firstText(displayName, user.displayName, 'Guest');

    final profile = <String, dynamic>{
      ...?snapshot.data(),
      'uid': user.uid,
      'name': name,
      'email': user.email,
      'photoURL': user.photoURL,
      'currency':
          snapshot.data()?['currency'] ?? CurrencyCatalog.defaultCurrencyCode,
      'language': snapshot.data()?['language'] ?? 'en',
      'country': snapshot.data()?['country'] ?? '',
      'timezone': snapshot.data()?['timezone'] ?? DateTime.now().timeZoneName,
    };
    await doc.set({
      ...profile,
      if (!hasDocument) 'createdAt': nowValue,
      'updatedAt': nowValue,
      'lastLogin': nowValue,
    }, SetOptions(merge: true));
    _publishProfileRefresh(user);
    return profile;
  }

  bool _shouldSuppressFailClosed(firebase_auth.User user) {
    try {
      return _completedDeletionOverlay.shouldSuppress(user);
    } on Object {
      return true;
    }
  }

  void _publishProfileRefresh(firebase_auth.User user) {
    if (_profileRefreshes.isClosed ||
        !FirebaseAuthIdentityPolicy.isSupportedUser(user)) {
      return;
    }
    final snapshot = _matchingSnapshot(user);
    if (snapshot == null) {
      return;
    }
    _profileRefreshes.add(
      FirebaseAuthSessionEvent(user: user, snapshot: snapshot),
    );
  }

  Future<void> dispose() async {
    if (!_profileRefreshes.isClosed) {
      await _profileRefreshes.close();
    }
  }

  firebase_auth.User _requireUser(firebase_auth.User? user) {
    if (user == null) {
      throw firebase_auth.FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user is available.',
      );
    }

    return user;
  }

  String _firstText(String? first, String? second, String fallback) {
    if (_hasText(first)) {
      return first!.trim();
    }
    if (_hasText(second)) {
      return second!.trim();
    }

    return fallback;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}
