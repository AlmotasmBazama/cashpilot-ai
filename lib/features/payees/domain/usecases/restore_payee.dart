import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../repositories/payees_repository.dart';

class RestorePayee {
  const RestorePayee(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<Payee>> call(String id) => _repository.restorePayee(id);
}
