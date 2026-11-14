import '../../../../core/error/result.dart';
import '../entities/transaction.dart';
import '../enums/transaction_status.dart';
import '../repositories/transactions_repository.dart';

class GetTransactions {
  const GetTransactions(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<List<Transaction>>> call({
    String? accountId,
    String? categoryId,
    String? payeeId,
    String? transferGroupId,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return _repository.getTransactions(
      accountId: accountId,
      categoryId: categoryId,
      payeeId: payeeId,
      transferGroupId: transferGroupId,
      status: status,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
