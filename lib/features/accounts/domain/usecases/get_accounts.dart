import '../../../../core/error/result.dart';
import '../entities/account.dart';
import '../repositories/accounts_repository.dart';

class GetAccounts {
  const GetAccounts(this._repository);

  final AccountsRepository _repository;

  Future<AppResult<List<Account>>> call({bool includeArchived = false}) {
    return _repository.getAccounts(includeArchived: includeArchived);
  }
}
