import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<AppResult<void>> call() => _repository.signOut();
}
