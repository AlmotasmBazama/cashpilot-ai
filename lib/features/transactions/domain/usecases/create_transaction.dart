import '../../../../core/error/result.dart';
import '../entities/transaction.dart';
import '../repositories/transactions_repository.dart';

class CreateTransaction {
  const CreateTransaction(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<Transaction>> call(Transaction transaction) {
    return _repository.createTransaction(transaction);
  }
}
