import '../../../../core/error/result.dart';
import '../entities/account.dart';
import '../repositories/accounts_repository.dart';

class CreateAccount {
  const CreateAccount(this._repository);

  final AccountsRepository _repository;

  Future<AppResult<Account>> call(Account account) {
    return _repository.createAccount(account);
  }
}
