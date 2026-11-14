import '../../../../core/error/result.dart';
import '../entities/transaction.dart';
import '../repositories/transactions_repository.dart';

class DeleteTransaction {
  const DeleteTransaction(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<void>> call(
    String id, {
    List<Transaction>? expectedCurrent,
  }) {
    return _repository.deleteTransaction(id, expectedCurrent: expectedCurrent);
  }
}
