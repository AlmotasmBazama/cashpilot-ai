import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class VerifyEmail {
  const VerifyEmail(this._repository);

  final AuthRepository _repository;

  Future<AppResult<void>> send() => _repository.sendEmailVerification();
}
