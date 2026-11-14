import '../../../transactions/domain/entities/transaction.dart';
import 'receipt_analysis_draft.dart';
import 'transaction_split.dart';

class ReceiptTransactionDraft {
  const ReceiptTransactionDraft({
    required this.receipt,
    required this.transaction,
    required this.splits,
    required this.requiresConfirmation,
  });

  final ReceiptAnalysisDraft receipt;
  final Transaction transaction;
  final List<TransactionSplit> splits;
  final bool requiresConfirmation;
}

class ConfirmedReceiptTransaction {
  const ConfirmedReceiptTransaction({
    required this.transaction,
    required this.receipt,
  }) : metadataPersisted = true;

  final Transaction transaction;
  final ReceiptAnalysisDraft receipt;

  /// A successful confirmation is always complete. Partial persistence and
  /// privacy cleanup states are represented by typed [AppFailure] results.
  final bool metadataPersisted;
}
