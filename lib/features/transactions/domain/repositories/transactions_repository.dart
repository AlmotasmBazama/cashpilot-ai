import '../../../../core/error/result.dart';
import '../entities/create_transfer_command.dart';
import '../entities/created_transfer.dart';
import '../entities/transaction.dart';
import '../enums/transaction_status.dart';
import '../enums/transaction_type.dart';

abstract interface class TransactionsRepository {
  Future<AppResult<Transaction>> createTransaction(Transaction transaction);

  Future<AppResult<CreatedTransfer>> createTransfer(
    CreateTransferCommand command,
  );

  Future<AppResult<Transaction>> updateTransaction(
    Transaction transaction, {
    Transaction? expectedCurrent,
  });

  Future<AppResult<List<Transaction>>> updateTransactionStatus(
    String id,
    TransactionStatus status, {
    List<Transaction>? expectedCurrent,
  });

  Future<AppResult<void>> deleteTransaction(
    String id, {
    List<Transaction>? expectedCurrent,
  });

  Future<AppResult<Transaction?>> getTransaction(String id);

  Future<AppResult<List<Transaction>>> getTransactions({
    String? accountId,
    String? categoryId,
    String? payeeId,
    String? transferGroupId,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<AppResult<List<Transaction>>> searchTransactions(
    String query, {
    int? limit,
    Set<TransactionType>? transactionTypes,
    TransactionStatus? status,
  });
}
