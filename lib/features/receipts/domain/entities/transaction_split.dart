import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';

class TransactionSplit {
  factory TransactionSplit({
    required String id,
    required String categoryId,
    required Decimal amount,
    required List<String> sourceReceiptItemIds,
    String? transactionId,
    String? draftId,
    String? description,
  }) {
    if (amount < Decimal.zero) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Transaction split amounts cannot be negative.',
      );
    }
    return TransactionSplit._(
      id: id,
      categoryId: categoryId,
      amount: amount,
      sourceReceiptItemIds: sourceReceiptItemIds,
      transactionId: transactionId,
      draftId: draftId,
      description: description,
    );
  }

  const TransactionSplit._({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.sourceReceiptItemIds,
    this.transactionId,
    this.draftId,
    this.description,
  });

  factory TransactionSplit.create({
    required String categoryId,
    required Decimal amount,
    required List<String> sourceReceiptItemIds,
    String? transactionId,
    String? draftId,
    String? description,
    String? id,
  }) {
    return TransactionSplit(
      id: id ?? const Uuid().v7(),
      transactionId: transactionId,
      draftId: draftId,
      categoryId: categoryId,
      amount: amount,
      sourceReceiptItemIds: List.unmodifiable(sourceReceiptItemIds),
      description: description?.trim(),
    );
  }

  final String id;
  final String? transactionId;
  final String? draftId;
  final String categoryId;
  final Decimal amount;
  final List<String> sourceReceiptItemIds;
  final String? description;

  TransactionSplit copyWith({String? transactionId, String? draftId}) {
    return TransactionSplit(
      id: id,
      transactionId: transactionId ?? this.transactionId,
      draftId: draftId ?? this.draftId,
      categoryId: categoryId,
      amount: amount,
      sourceReceiptItemIds: sourceReceiptItemIds,
      description: description,
    );
  }
}
