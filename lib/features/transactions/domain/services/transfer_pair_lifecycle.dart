import '../entities/transaction.dart';
import '../enums/transaction_status.dart';

abstract interface class TransferPairLifecycle {
  Future<List<String>> deletePendingPair(Transaction transaction);

  Future<List<Transaction>> updateStatus(
    Transaction transaction,
    TransactionStatus status,
  );
}
