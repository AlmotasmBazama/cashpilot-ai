import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../enums/payee_type.dart';
import '../repositories/payees_repository.dart';

class WatchPayees {
  const WatchPayees(this._repository);
  final PayeesRepository _repository;

  Stream<AppResult<List<Payee>>> call({
    bool includeArchived = false,
    PayeeType? type,
  }) => _repository.watchPayees(includeArchived: includeArchived, type: type);
}
