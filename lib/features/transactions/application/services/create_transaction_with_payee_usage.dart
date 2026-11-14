import '../../../../core/error/result.dart';
import '../../../payees/domain/usecases/touch_payee_last_used.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/create_transaction.dart';

class CreateTransactionWithPayeeUsage {
  const CreateTransactionWithPayeeUsage({
    required CreateTransaction createTransaction,
    required TouchPayeeLastUsed touchPayeeLastUsed,
  }) : _createTransaction = createTransaction,
       _touchPayeeLastUsed = touchPayeeLastUsed;

  final CreateTransaction _createTransaction;
  final TouchPayeeLastUsed _touchPayeeLastUsed;

  Future<AppResult<Transaction>> call(Transaction transaction) async {
    final result = await _createTransaction(transaction);
    if (result case AppSuccess<Transaction>(:final data)) {
      final payeeId = data.payeeId;
      if (payeeId != null) {
        try {
          await _touchPayeeLastUsed(payeeId, data.transactionDate);
        } on Object {
          // Usage metadata must not turn a committed transaction into a failure.
        }
      }
    }
    return result;
  }
}
