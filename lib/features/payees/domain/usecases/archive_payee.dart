import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../repositories/payees_repository.dart';

class ArchivePayee {
  const ArchivePayee(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<Payee>> call(String id) => _repository.archivePayee(id);
}
