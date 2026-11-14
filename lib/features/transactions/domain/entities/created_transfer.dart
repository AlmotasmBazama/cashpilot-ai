import '../../../finance_engine/domain/entities/processed_transfer.dart';
import 'transaction.dart';

class CreatedTransfer {
  const CreatedTransfer({
    required this.transferGroupId,
    required this.outgoingTransaction,
    required this.incomingTransaction,
    required this.transfer,
    this.replayed = false,
  });

  final String transferGroupId;
  final Transaction outgoingTransaction;
  final Transaction incomingTransaction;
  final ProcessedTransfer transfer;

  /// True when an exact durable pair was reconciled without executing the
  /// Finance Engine. In that case the processed balance snapshots truthfully
  /// describe a no-effect replay observation (previous == new), not history.
  final bool replayed;
}
