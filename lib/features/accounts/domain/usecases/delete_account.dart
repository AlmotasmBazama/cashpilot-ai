import '../../../../core/error/result.dart';
import '../repositories/accounts_repository.dart';

class DeleteAccount {
  const DeleteAccount(this._repository);

  final AccountsRepository _repository;

  Future<AppResult<void>> call(String id) {
    return _repository.deleteAccount(id);
  }
}
