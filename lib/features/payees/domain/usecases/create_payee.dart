import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../repositories/payees_repository.dart';

class CreatePayee {
  const CreatePayee(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<Payee>> call(Payee payee) => _repository.createPayee(payee);
}
