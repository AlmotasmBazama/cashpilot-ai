import '../../../../core/error/result.dart';
import '../entities/transaction.dart';
import '../repositories/transactions_repository.dart';

class GetTransaction {
  const GetTransaction(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<Transaction?>> call(String id) {
    return _repository.getTransaction(id);
  }
}
