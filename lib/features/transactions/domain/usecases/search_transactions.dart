import '../../../../core/error/result.dart';
import '../entities/transaction.dart';
import '../enums/transaction_status.dart';
import '../enums/transaction_type.dart';
import '../repositories/transactions_repository.dart';

class SearchTransactions {
  const SearchTransactions(this._repository);

  final TransactionsRepository _repository;

  Future<AppResult<List<Transaction>>> call(
    String query, {
    int? limit,
    Set<TransactionType>? transactionTypes,
    TransactionStatus? status,
  }) {
    return _repository.searchTransactions(
      query,
      limit: limit,
      transactionTypes: transactionTypes,
      status: status,
    );
  }
}
