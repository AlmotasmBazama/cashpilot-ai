import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class AnonymousLogin {
  const AnonymousLogin(this._repository);

  final AuthRepository _repository;

  Future<AppResult<AuthUser>> call() => _repository.signInAnonymously();
}
