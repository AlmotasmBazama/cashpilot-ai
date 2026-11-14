import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> listenAuthState();

  Future<AppResult<AuthUser?>> getCurrentUser();

  Future<AppResult<AuthUser>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  });

  Future<AppResult<AuthUser>> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<AppResult<AuthUser>> signInWithGoogle({required bool rememberMe});

  Future<AppResult<AuthUser>> signInWithApple({required bool rememberMe});

  Future<AppResult<AuthUser>> signInAnonymously();

  Future<AppResult<void>> sendPasswordResetEmail(String email);

  Future<AppResult<void>> sendEmailVerification();

  Future<AppResult<AuthUser?>> refreshUser();

  Future<AppResult<AuthUser>> completeProfile({
    required AuthSessionIdentity expectedSession,
    required String displayName,
    required String currency,
    required String language,
    required String country,
    required String timezone,
  });

  Future<AppResult<AuthUser>> reauthenticateWithPassword({
    required String email,
    required String password,
  });

  Future<AppResult<void>> signOut();
}
