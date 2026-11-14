import '../../../../core/error/result.dart';
import '../entities/transaction.dart';
import '../enums/transaction_status.dart';
import '../repositories/transactions_repository.dart';

class UpdateTransactionStatus {
  const UpdateTransactionStatus(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<List<Transaction>>> call(
    String id,
    TransactionStatus status, {
    List<Transaction>? expectedCurrent,
  }) {
    return _repository.updateTransactionStatus(
      id,
      status,
      expectedCurrent: expectedCurrent,
    );
  }
}
