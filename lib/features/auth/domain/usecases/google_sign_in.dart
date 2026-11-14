import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class GoogleSignInUseCase {
  const GoogleSignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<AppResult<AuthUser>> call({required bool rememberMe}) {
    return _repository.signInWithGoogle(rememberMe: rememberMe);
  }
}
