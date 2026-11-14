import '../../../../core/error/result.dart';
import '../entities/account.dart';
import '../repositories/accounts_repository.dart';

class GetAccountById {
  const GetAccountById(this._repository);

  final AccountsRepository _repository;

  Future<AppResult<Account?>> call(String id) {
    return _repository.getAccountById(id);
  }
}
