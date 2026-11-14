import '../../../../core/error/result.dart';
import '../entities/payee_resolution.dart';
import '../repositories/payees_repository.dart';

class ResolvePayee {
  const ResolvePayee(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<PayeeResolution>> call(
    String query, {
    bool includeArchived = false,
  }) => _repository.resolvePayee(query, includeArchived: includeArchived);
}
