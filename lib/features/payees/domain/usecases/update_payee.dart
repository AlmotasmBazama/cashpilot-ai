import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../repositories/payees_repository.dart';

class UpdatePayee {
  const UpdatePayee(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<Payee>> call(Payee payee) => _repository.updatePayee(payee);
}
