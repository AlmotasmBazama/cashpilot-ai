import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../repositories/payees_repository.dart';

class TouchPayeeLastUsed {
  const TouchPayeeLastUsed(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<Payee>> call(String id, DateTime usedAt) =>
      _repository.touchLastUsed(id, usedAt);
}
