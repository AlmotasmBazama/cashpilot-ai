import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class Reauthenticate {
  const Reauthenticate(this._repository);

  final AuthRepository _repository;

  Future<AppResult<AuthUser>> call({
    required String email,
    required String password,
  }) {
    return _repository.reauthenticateWithPassword(
      email: email,
      password: password,
    );
  }
}
