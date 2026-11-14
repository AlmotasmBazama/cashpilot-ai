import '../../../../core/error/result.dart';
import '../entities/transaction.dart';
import '../repositories/transactions_repository.dart';

class UpdateTransaction {
  const UpdateTransaction(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<Transaction>> call(
    Transaction transaction, {
    Transaction? expectedCurrent,
  }) {
    return _repository.updateTransaction(
      transaction,
      expectedCurrent: expectedCurrent,
    );
  }
}
