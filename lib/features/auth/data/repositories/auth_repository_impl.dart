import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_data_source.dart';
import '../mappers/auth_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AppLogger logger,
  }) : _remoteDataSource = remoteDataSource,
       _logger = logger;

  final AuthRemoteDataSource _remoteDataSource;
  final AppLogger _logger;

  @override
  Stream<AuthUser?> listenAuthState() {
    return _remoteDataSource.listenAuthState().map((user) => user?.toDomain());
  }

  @override
  Future<AppResult<AuthUser?>> getCurrentUser() {
    return _guardNullable(
      () async => (await _remoteDataSource.getCurrentUser())?.toDomain(),
      'Unable to load current user.',
    );
  }

  @override
  Future<AppResult<AuthUser>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) {
    return _guard(
      () async => (await _remoteDataSource.signIn(
        email: email,
        password: password,
        rememberMe: rememberMe,
      )).toDomain(),
      'Unable to sign in.',
    );
  }

  @override
  Future<AppResult<AuthUser>> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard(
      () async => (await _remoteDataSource.signUp(
        name: name,
        email: email,
        password: password,
      )).toDomain(),
      'Unable to create account.',
    );
  }

  @override
  Future<AppResult<AuthUser>> signInWithGoogle({required bool rememberMe}) {
    return _guard(
      () async => (await _remoteDataSource.signInWithGoogle(
        rememberMe: rememberMe,
      )).toDomain(),
      'Unable to continue with Google.',
    );
  }

  @override
  Future<AppResult<AuthUser>> signInWithApple({required bool rememberMe}) {
    return _guard(
      () async => (await _remoteDataSource.signInWithApple(
        rememberMe: rememberMe,
      )).toDomain(),
      'Unable to continue with Apple.',
    );
  }

  @override
  Future<AppResult<AuthUser>> signInAnonymously() {
    return _guard(
      () async => (await _remoteDataSource.signInAnonymously()).toDomain(),
      'Unable to continue as guest.',
    );
  }

  @override
  Future<AppResult<void>> sendPasswordResetEmail(String email) {
    return _guardVoid(
      () => _remoteDataSource.sendPasswordResetEmail(email),
      'Unable to send password reset email.',
    );
  }

  @override
  Future<AppResult<void>> sendEmailVerification() {
    return _guardVoid(
      _remoteDataSource.sendEmailVerification,
      'Unable to send verification email.',
    );
  }

  @override
  Future<AppResult<AuthUser?>> refreshUser() {
    return _guardNullable(
      () async => (await _remoteDataSource.refreshUser())?.toDomain(),
      'Unable to refresh user.',
    );
  }

  @override
  Future<AppResult<AuthUser>> completeProfile({
    required AuthSessionIdentity expectedSession,
    required String displayName,
    required String currency,
    required String language,
    required String country,
    required String timezone,
  }) {
    return _guard(
      () async => (await _remoteDataSource.completeProfile(
        expectedSession: expectedSession,
        displayName: displayName,
        currency: currency,
        language: language,
        country: country,
        timezone: timezone,
      )).toDomain(),
      'Unable to complete profile.',
    );
  }

  @override
  Future<AppResult<AuthUser>> reauthenticateWithPassword({
    required String email,
    required String password,
  }) {
    return _guard(
      () async => (await _remoteDataSource.reauthenticateWithPassword(
        email: email,
        password: password,
      )).toDomain(),
      'Unable to reauthenticate.',
    );
  }

  @override
  Future<AppResult<void>> signOut() {
    return _guardVoid(_remoteDataSource.signOut, 'Unable to sign out.');
  }

  Future<AppResult<T>> _guard<T>(
    Future<T> Function() action,
    String fallbackMessage,
  ) async {
    try {
      return AppResult.success(await action());
    } on Object catch (error, stackTrace) {
      return _failure(fallbackMessage, error, stackTrace);
    }
  }

  Future<AppResult<T?>> _guardNullable<T>(
    Future<T?> Function() action,
    String fallbackMessage,
  ) async {
    try {
      return AppResult.success(await action());
    } on Object catch (error, stackTrace) {
      return _failure(fallbackMessage, error, stackTrace);
    }
  }

  Future<AppResult<void>> _guardVoid(
    Future<void> Function() action,
    String fallbackMessage,
  ) async {
    try {
      await action();
      return const AppResult.success(null);
    } on Object catch (error, stackTrace) {
      return _failure(fallbackMessage, error, stackTrace);
    }
  }

  AppResult<T> _failure<T>(
    String fallbackMessage,
    Object error,
    StackTrace stackTrace,
  ) {
    final failure = _mapFailure(error, fallbackMessage);
    _logger.error(failure.message, error, stackTrace);

    return AppResult.failure(
      Failure(message: failure.message, code: failure.code),
    );
  }

  AuthFailure _mapFailure(Object error, String fallbackMessage) {
    if (error is firebase_auth.FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'invalid-email' => AuthFailure(
          message: 'Check your email and password, then try again.',
          code: error.code,
          type: AuthFailureType.invalidCredentials,
        ),
        'email-already-in-use' => AuthFailure(
          message: 'An account already exists for this email.',
          code: error.code,
          type: AuthFailureType.emailAlreadyInUse,
        ),
        'weak-password' => AuthFailure(
          message: 'Use a stronger password to protect your account.',
          code: error.code,
          type: AuthFailureType.weakPassword,
        ),
        'network-request-failed' => AuthFailure(
          message: 'Network unavailable. Check your connection and try again.',
          code: error.code,
          type: AuthFailureType.network,
        ),
        'too-many-requests' => AuthFailure(
          message: 'Too many attempts. Please wait a moment and try again.',
          code: error.code,
        ),
        'operation-not-allowed' || 'admin-restricted-operation' => AuthFailure(
          message: 'This sign-in method is not enabled for this project yet.',
          code: error.code,
          type: AuthFailureType.unsupportedProvider,
        ),
        'user-disabled' => AuthFailure(
          message: 'This account has been disabled.',
          code: error.code,
        ),
        'requires-recent-login' => AuthFailure(
          message: 'Please sign in again before changing this account.',
          code: error.code,
          type: AuthFailureType.requiresRecentLogin,
        ),
        'user-not-found' => AuthFailure(
          message: 'No account was found for those credentials.',
          code: error.code,
          type: AuthFailureType.userNotFound,
        ),
        'missing-google-id-token' || 'missing-apple-id-token' => AuthFailure(
          message: 'The identity provider did not return a secure token.',
          code: error.code,
          type: AuthFailureType.unsupportedProvider,
        ),
        _ => AuthFailure(message: fallbackMessage, code: error.code),
      };
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => AuthFailure(
          message:
              'Your account does not have permission to complete this action.',
          code: error.code,
        ),
        'unauthenticated' => AuthFailure(
          message: 'Please sign in again to continue.',
          code: error.code,
        ),
        'unavailable' => AuthFailure(
          message: 'Firebase is temporarily unavailable. Try again shortly.',
          code: error.code,
          type: AuthFailureType.network,
        ),
        _ => AuthFailure(message: fallbackMessage, code: error.code),
      };
    }

    if (error is GoogleSignInException) {
      final cancelled =
          error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted;
      return AuthFailure(
        message: cancelled
            ? 'Google sign-in was cancelled.'
            : 'Google sign-in is not available right now.',
        code: error.code.name,
        type: cancelled
            ? AuthFailureType.userCancelled
            : AuthFailureType.unsupportedProvider,
      );
    }

    if (error is SignInWithAppleAuthorizationException) {
      final cancelled = error.code == AuthorizationErrorCode.canceled;
      return AuthFailure(
        message: cancelled
            ? 'Apple sign-in was cancelled.'
            : 'Apple sign-in could not be completed.',
        code: error.code.name,
        type: cancelled
            ? AuthFailureType.userCancelled
            : AuthFailureType.unsupportedProvider,
      );
    }

    if (error is UnsupportedError ||
        error is SignInWithAppleNotSupportedException) {
      return AuthFailure(
        message: 'This sign-in method is not available on this device.',
        code: 'unsupported-provider',
        type: AuthFailureType.unsupportedProvider,
      );
    }

    return AuthFailure(message: fallbackMessage);
  }
}
