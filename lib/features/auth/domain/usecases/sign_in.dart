import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  const SignIn(this._repository);

  final AuthRepository _repository;

  Future<AppResult<AuthUser>> call({
    required String email,
    required String password,
    required bool rememberMe,
  }) {
    return _repository.signIn(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
  }
}
