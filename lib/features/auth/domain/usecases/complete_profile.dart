import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class CompleteProfile {
  const CompleteProfile(this._repository);

  final AuthRepository _repository;

  Future<AppResult<AuthUser>> call({
    required AuthSessionIdentity expectedSession,
    required String displayName,
    required String currency,
    required String language,
    required String country,
    required String timezone,
  }) {
    return _repository.completeProfile(
      expectedSession: expectedSession,
      displayName: displayName,
      currency: currency,
      language: language,
      country: country,
      timezone: timezone,
    );
  }
}
