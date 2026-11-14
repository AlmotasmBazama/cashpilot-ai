import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../repositories/payees_repository.dart';

class GetPayeeById {
  const GetPayeeById(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<Payee?>> call(String id) => _repository.getPayeeById(id);
}
