import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class ForgotPassword {
  const ForgotPassword(this._repository);

  final AuthRepository _repository;

  Future<AppResult<void>> call(String email) {
    return _repository.sendPasswordResetEmail(email);
  }
}
