import 'package:uuid/uuid.dart';

/// Assigns one restart-stable transaction identity to each receipt.
///
/// The identity is derived instead of being stored as a dangling transaction
/// reference. This lets the database keep enforcing that every persisted
/// `linked_transaction_id` already belongs to a real same-owner transaction.
abstract final class ReceiptTransactionIdentity {
  static const _operationNamePrefix =
      'https://cashpilot.local/receipts/transaction/';

  static String transactionIdForReceipt(String receiptId) {
    final normalizedReceiptId = receiptId.trim();
    if (normalizedReceiptId.isEmpty) {
      throw ArgumentError.value(receiptId, 'receiptId', 'Must not be empty.');
    }
    return const Uuid().v5(
      Namespace.url.value,
      '$_operationNamePrefix$normalizedReceiptId',
    );
  }
}
