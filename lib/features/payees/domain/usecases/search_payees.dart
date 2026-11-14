import '../../../../core/error/result.dart';
import '../entities/payee.dart';
import '../repositories/payees_repository.dart';

class SearchPayees {
  const SearchPayees(this._repository);
  final PayeesRepository _repository;
  Future<AppResult<List<Payee>>> call(
    String query, {
    bool includeArchived = false,
  }) => _repository.searchPayees(query, includeArchived: includeArchived);
}
