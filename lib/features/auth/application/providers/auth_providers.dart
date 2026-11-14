import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/storage/settings_local_data_source.dart';
import '../../../../core/storage/hive_box_names.dart';
import '../../data/datasources/firebase_auth_data_source.dart';
import '../../data/services/firebase_auth_session_guard.dart';
import '../../data/services/firebase_auth_operation_coordinator.dart';
import '../../data/services/firebase_oauth_credential_provider.dart';
import '../../data/services/firebase_restricted_auth_session_restorer.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/anonymous_login.dart';
import '../../domain/usecases/apple_sign_in.dart';
import '../../domain/usecases/complete_profile.dart';
import '../../domain/usecases/forgot_password.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/google_sign_in.dart';
import '../../domain/usecases/listen_auth_state.dart';
import '../../domain/usecases/reauthenticate.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/usecases/verify_email.dart';
import '../../domain/services/auth_oauth_credential_provider.dart';
import '../../domain/services/restricted_auth_session_restorer.dart';

final firebaseAuthSessionEpochGuardProvider =
    Provider<FirebaseAuthSessionEpochGuard>((ref) {
      final guard = FirebaseAuthSessionEpochGuard(
        ref.watch(firebaseAuthProvider),
      );
      ref.onDispose(guard.dispose);
      return guard;
    }, name: 'firebaseAuthSessionEpochGuardProvider');

final firebaseAuthOperationCoordinatorProvider =
    Provider<FirebaseAuthOperationCoordinator>(
      (_) => FirebaseAuthOperationCoordinator(),
      name: 'firebaseAuthOperationCoordinatorProvider',
    );

final firebaseOAuthCredentialProviderFactoryProvider =
    Provider<AuthOAuthCredentialProviderFactory<firebase_auth.AuthCredential>>(
      (ref) => InteractiveFirebaseOAuthCredentialProviderFactory(
        googleSignIn: ref.watch(googleSignInProvider),
      ),
      name: 'firebaseOAuthCredentialProviderFactoryProvider',
    );

final restrictedAuthSessionRestorerProvider =
    Provider<RestrictedAuthSessionRestorer>(
      (ref) => FirebaseRestrictedAuthSessionRestorer(
        auth: ref.watch(firebaseAuthProvider),
        sessionGuard: ref.watch(firebaseAuthSessionEpochGuardProvider),
        operationCoordinator: ref.watch(
          firebaseAuthOperationCoordinatorProvider,
        ),
        oauthCredentialProvider: ref
            .watch(firebaseOAuthCredentialProviderFactoryProvider)
            .create(),
      ),
      name: 'restrictedAuthSessionRestorerProvider',
    );

final completedAccountDeletionOverlayProvider =
    Provider<CompletedAccountDeletionOverlay>((ref) {
      final overlay = HiveCompletedAccountDeletionOverlay(
        box: Hive.box<dynamic>(HiveBoxNames.settings),
        sessionGuard: ref.watch(firebaseAuthSessionEpochGuardProvider),
      );
      ref.onDispose(overlay.dispose);
      return overlay;
    }, name: 'completedAccountDeletionOverlayProvider');

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final source = FirebaseAuthDataSource(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    logger: ref.watch(appLoggerProvider),
    completedDeletionOverlay: ref.watch(
      completedAccountDeletionOverlayProvider,
    ),
    sessionGuard: ref.watch(firebaseAuthSessionEpochGuardProvider),
    operationCoordinator: ref.watch(firebaseAuthOperationCoordinatorProvider),
  );
  ref.onDispose(source.dispose);
  return source;
}, name: 'authRemoteDataSourceProvider');

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
}, name: 'authRepositoryProvider');

final signInUseCaseProvider = Provider<SignIn>(
  (ref) => SignIn(ref.watch(authRepositoryProvider)),
  name: 'signInUseCaseProvider',
);

final signUpUseCaseProvider = Provider<SignUp>(
  (ref) => SignUp(ref.watch(authRepositoryProvider)),
  name: 'signUpUseCaseProvider',
);

final signOutUseCaseProvider = Provider<SignOut>(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
  name: 'signOutUseCaseProvider',
);

final googleSignInUseCaseProvider = Provider<GoogleSignInUseCase>(
  (ref) => GoogleSignInUseCase(ref.watch(authRepositoryProvider)),
  name: 'googleSignInUseCaseProvider',
);

final appleSignInUseCaseProvider = Provider<AppleSignInUseCase>(
  (ref) => AppleSignInUseCase(ref.watch(authRepositoryProvider)),
  name: 'appleSignInUseCaseProvider',
);

final anonymousLoginUseCaseProvider = Provider<AnonymousLogin>(
  (ref) => AnonymousLogin(ref.watch(authRepositoryProvider)),
  name: 'anonymousLoginUseCaseProvider',
);

final forgotPasswordUseCaseProvider = Provider<ForgotPassword>(
  (ref) => ForgotPassword(ref.watch(authRepositoryProvider)),
  name: 'forgotPasswordUseCaseProvider',
);

final verifyEmailUseCaseProvider = Provider<VerifyEmail>(
  (ref) => VerifyEmail(ref.watch(authRepositoryProvider)),
  name: 'verifyEmailUseCaseProvider',
);

final getCurrentUserUseCaseProvider = Provider<GetCurrentUser>(
  (ref) => GetCurrentUser(ref.watch(authRepositoryProvider)),
  name: 'getCurrentUserUseCaseProvider',
);

final listenAuthStateUseCaseProvider = Provider<ListenAuthState>(
  (ref) => ListenAuthState(ref.watch(authRepositoryProvider)),
  name: 'listenAuthStateUseCaseProvider',
);

final completeProfileUseCaseProvider = Provider<CompleteProfile>(
  (ref) => CompleteProfile(ref.watch(authRepositoryProvider)),
  name: 'completeProfileUseCaseProvider',
);

final reauthenticateUseCaseProvider = Provider<Reauthenticate>(
  (ref) => Reauthenticate(ref.watch(authRepositoryProvider)),
  name: 'reauthenticateUseCaseProvider',
);

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(listenAuthStateUseCaseProvider)();
}, name: 'authStateProvider');

final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading || auth.hasError) {
    return null;
  }
  return auth.value;
}, name: 'currentAuthUserProvider');

/// Ordered native Firebase identity for security UI that must remain
/// independent from Firestore profile hydration. This intentionally watches
/// only [FirebaseAuthSessionEpochGuard], never [authStateProvider].
final nativeAuthSessionIdentityProvider = StreamProvider<AuthSessionIdentity?>((
  ref,
) {
  final guard = ref.watch(firebaseAuthSessionEpochGuardProvider);
  StreamSubscription<FirebaseAuthSessionEvent>? subscription;
  late final StreamController<AuthSessionIdentity?> controller;
  controller = StreamController<AuthSessionIdentity?>(
    sync: true,
    onListen: () {
      subscription = guard.authStateEvents.listen(
        (event) => controller.add(_nativeSessionIdentity(event)),
        onError: controller.addError,
        onDone: () {
          controller.add(null);
          unawaited(controller.close());
        },
      );
      // Subscribe before taking the snapshot so an identity transition
      // between the two operations can only duplicate the newest value;
      // it can never roll the stream back to an older identity.
      controller.add(_nativeSessionIdentity(guard.currentAuthStateEvent()));
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}, name: 'nativeAuthSessionIdentityProvider');

final rememberMeProvider = StateProvider<bool>((ref) {
  return ref.watch(settingsLocalDataSourceProvider).readRememberMe();
}, name: 'rememberMeProvider');

final onboardingCompletedProvider = StateProvider<bool>((ref) {
  return ref.watch(settingsLocalDataSourceProvider).readOnboardingCompleted();
}, name: 'onboardingCompletedProvider');

final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(
      AuthController.new,
      name: 'authControllerProvider',
    );

class AuthController extends AsyncNotifier<void> {
  var _operationVersion = 0;
  AuthSessionIdentity? _activeSession;
  _ActiveAuthControllerOperation? _activeOperation;

  @override
  FutureOr<void> build() {
    _activeSession = ref.read(currentAuthUserProvider)?.sessionIdentity;
    ref.listen(authStateProvider, (_, next) {
      final isConfirmedValue =
          next.hasValue && !next.hasError && !next.isLoading;
      final nextSession = isConfirmedValue ? next.value?.sessionIdentity : null;
      if (nextSession != _activeSession) {
        final operation = _activeOperation;
        if (isConfirmedValue &&
            operation != null &&
            operation.version == _operationVersion &&
            operation.acceptTransition(_activeSession, nextSession)) {
          _activeSession = nextSession;
          return;
        }
        _activeSession = nextSession;
        _operationVersion++;
        _activeOperation = null;
        if (ref.mounted) {
          state = const AsyncData(null);
        }
      }
    });
    ref.onDispose(() {
      _operationVersion++;
      _activeOperation = null;
    });
  }

  Future<bool> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final result = await _run(
      () => ref.read(signInUseCaseProvider)(
        email: email,
        password: password,
        rememberMe: rememberMe,
      ),
      expectation: _AuthTransitionExpectation.signIn,
      resultSessionIdentity: (user) => user.sessionIdentity,
    );

    if (result) {
      await _saveRememberMe(rememberMe);
    }

    return result;
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _run(
      () => ref.read(signUpUseCaseProvider)(
        name: name,
        email: email,
        password: password,
      ),
      expectation: _AuthTransitionExpectation.signIn,
      resultSessionIdentity: (user) => user.sessionIdentity,
    );
  }

  Future<bool> signInWithGoogle({required bool rememberMe}) async {
    final result = await _run(
      () => ref.read(googleSignInUseCaseProvider)(rememberMe: rememberMe),
      expectation: _AuthTransitionExpectation.signIn,
      resultSessionIdentity: (user) => user.sessionIdentity,
    );

    if (result) {
      await _saveRememberMe(rememberMe);
    }

    return result;
  }

  Future<bool> signInWithApple({required bool rememberMe}) async {
    final result = await _run(
      () => ref.read(appleSignInUseCaseProvider)(rememberMe: rememberMe),
      expectation: _AuthTransitionExpectation.signIn,
      resultSessionIdentity: (user) => user.sessionIdentity,
    );

    if (result) {
      await _saveRememberMe(rememberMe);
    }

    return result;
  }

  Future<bool> signInAnonymously() {
    return _run(
      () => ref.read(anonymousLoginUseCaseProvider)(),
      expectation: _AuthTransitionExpectation.signIn,
      resultSessionIdentity: (user) => user.sessionIdentity,
    );
  }

  Future<bool> sendPasswordResetEmail(String email) {
    return _run(() => ref.read(forgotPasswordUseCaseProvider)(email));
  }

  Future<bool> sendEmailVerification() {
    return _run(() => ref.read(verifyEmailUseCaseProvider).send());
  }

  Future<bool> refreshUser() {
    return _run(() => ref.read(authRepositoryProvider).refreshUser());
  }

  Future<bool> completeProfile({
    required AuthSessionIdentity expectedSession,
    required String displayName,
    required String currency,
    required String language,
    required String country,
    required String timezone,
  }) {
    return _run(
      () => ref.read(completeProfileUseCaseProvider)(
        expectedSession: expectedSession,
        displayName: displayName,
        currency: currency,
        language: language,
        country: country,
        timezone: timezone,
      ),
    );
  }

  Future<bool> reauthenticate({
    required String email,
    required String password,
  }) {
    return _run(
      () => ref.read(reauthenticateUseCaseProvider)(
        email: email,
        password: password,
      ),
    );
  }

  Future<bool> signOut() async {
    final settings = ref.read(settingsLocalDataSourceProvider);
    final userId = ref.read(currentAuthUserProvider)?.uid;
    final accountScope = userId == null
        ? null
        : OwnerScopeDerivation.fromConfirmedFirebaseUid(userId).id.value;
    final succeeded = await _run(
      () => ref.read(signOutUseCaseProvider)(),
      expectation: _AuthTransitionExpectation.signOut,
    );
    if (succeeded && accountScope != null && accountScope.trim().isNotEmpty) {
      await settings.clearAiAgentMemory(accountScope: accountScope);
    }
    return succeeded;
  }

  Future<void> completeOnboarding() async {
    final keepAlive = ref.keepAlive();
    final operationVersion = _startOperation();
    final settingsLocalDataSource = ref.read(settingsLocalDataSourceProvider);
    final onboardingCompleted = ref.read(onboardingCompletedProvider.notifier);
    final logger = ref.read(appLoggerProvider);

    onboardingCompleted.state = true;

    unawaited(
      settingsLocalDataSource
          .saveOnboardingCompleted(true)
          .then((_) {
            if (_isCurrentOperation(operationVersion)) {
              state = const AsyncData(null);
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logger.error(
              'Unable to persist onboarding completion.',
              error,
              stackTrace,
            );
            if (_isCurrentOperation(operationVersion)) {
              onboardingCompleted.state = false;
              state = AsyncError(error, stackTrace);
            }
          })
          .whenComplete(keepAlive.close),
    );
  }

  Future<bool> _run<T>(
    Future<AppResult<T>> Function() operation, {
    _AuthTransitionExpectation expectation = _AuthTransitionExpectation.none,
    AuthSessionIdentity Function(T value)? resultSessionIdentity,
  }) async {
    final keepAlive = ref.keepAlive();
    final operationVersion = _startOperation(expectation: expectation);

    try {
      final result = await operation();
      if (!_isCurrentOperation(operationVersion)) {
        return false;
      }

      return switch (result) {
        AppSuccess<T>(data: final value) =>
          expectation == _AuthTransitionExpectation.signIn &&
                  (resultSessionIdentity == null ||
                      !(_activeOperation?.acceptSignInResult(
                            resultSessionIdentity(value),
                          ) ??
                          false))
              ? _failure(
                  const Failure(
                    message:
                        'The authenticated account changed. Please try again.',
                    code: 'auth-session-changed',
                  ),
                )
              : _success(),
        AppFailure<T>(failure: final failure) => _failure(failure),
      };
    } finally {
      if (_activeOperation?.version == operationVersion) {
        _activeOperation = null;
      }
      keepAlive.close();
    }
  }

  bool _success() {
    state = const AsyncData(null);
    return true;
  }

  bool _failure(Failure failure) {
    state = AsyncError(failure, StackTrace.current);
    return false;
  }

  Future<void> _saveRememberMe(bool rememberMe) async {
    final keepAlive = ref.keepAlive();
    final settingsLocalDataSource = ref.read(settingsLocalDataSourceProvider);
    final rememberMeNotifier = ref.read(rememberMeProvider.notifier);

    try {
      await settingsLocalDataSource.saveRememberMe(rememberMe);
      if (!ref.mounted) {
        return;
      }

      rememberMeNotifier.state = rememberMe;
    } finally {
      keepAlive.close();
    }
  }

  int _startOperation({
    _AuthTransitionExpectation expectation = _AuthTransitionExpectation.none,
  }) {
    state = const AsyncLoading();
    final version = ++_operationVersion;
    _activeOperation = _ActiveAuthControllerOperation(
      version: version,
      expectation: expectation,
      initialSession: _activeSession,
    );
    return version;
  }

  bool _isCurrentOperation(int operationVersion) {
    return ref.mounted && operationVersion == _operationVersion;
  }
}

enum _AuthTransitionExpectation { none, signIn, signOut }

AuthSessionIdentity? _nativeSessionIdentity(FirebaseAuthSessionEvent event) {
  final user = event.user;
  final snapshot = event.snapshot;
  if (user == null ||
      snapshot == null ||
      !FirebaseAuthIdentityPolicy.isSupportedUser(user) ||
      snapshot.fingerprint != firebaseAuthSessionFingerprintForUser(user)) {
    return null;
  }
  return AuthSessionIdentity(
    uid: snapshot.fingerprint.uid,
    isAnonymous: snapshot.fingerprint.isAnonymous,
    authSessionGeneration: snapshot.generation,
    tenantId: snapshot.fingerprint.tenantId,
  );
}

final class _ActiveAuthControllerOperation {
  _ActiveAuthControllerOperation({
    required this.version,
    required this.expectation,
    required this.initialSession,
  });

  final int version;
  final _AuthTransitionExpectation expectation;
  final AuthSessionIdentity? initialSession;
  var _consumed = false;
  AuthSessionIdentity? _observedSignInSession;

  bool acceptTransition(
    AuthSessionIdentity? previous,
    AuthSessionIdentity? next,
  ) {
    if (_consumed || previous != initialSession) {
      return false;
    }
    final accepted = switch (expectation) {
      _AuthTransitionExpectation.signIn => next != null,
      _AuthTransitionExpectation.signOut => next == null,
      _AuthTransitionExpectation.none => false,
    };
    if (accepted) {
      _consumed = true;
      if (expectation == _AuthTransitionExpectation.signIn) {
        _observedSignInSession = next;
      }
    }
    return accepted;
  }

  bool acceptSignInResult(AuthSessionIdentity resultSession) {
    if (expectation != _AuthTransitionExpectation.signIn) {
      return false;
    }
    final observed = _observedSignInSession;
    return observed == null || observed == resultSession;
  }
}
