import '../../../../core/error/result.dart';
import '../entities/receipt_analysis_draft.dart';
import '../entities/receipt_duplicate_result.dart';
import '../entities/receipt_line_item.dart';
import '../entities/transaction_split.dart';

abstract interface class ReceiptRepository {
  Future<AppResult<ReceiptAnalysisDraft>> createAnalysisDraft(
    ReceiptAnalysisDraft draft,
  );

  Future<AppResult<ReceiptAnalysisDraft>> updateAnalysisDraft(
    ReceiptAnalysisDraft draft,
  );

  Future<AppResult<ReceiptAnalysisDraft?>> getDraftById(String id);

  Stream<AppResult<ReceiptAnalysisDraft?>> watchDraft(String id);

  Future<AppResult<void>> deleteDraft(String id);

  Future<AppResult<void>> saveLineItems(
    String receiptId,
    List<ReceiptLineItem> items,
  );

  Future<AppResult<void>> saveSplits(
    String receiptId,
    List<TransactionSplit> splits,
  );

  Future<AppResult<ReceiptDuplicateResult>> findDuplicateCandidates(
    ReceiptAnalysisDraft draft,
  );

  Future<AppResult<String>> storeLocalImage(String receiptId, List<int> bytes);

  Future<AppResult<void>> deleteLocalImage(String receiptId);

  /// Resolves an existing finalized link or returns [transactionId] as an
  /// in-memory proposal. The proposal must be restart-stable; it is not stored
  /// in `linked_transaction_id` before the corresponding transaction exists.
  Future<AppResult<ReceiptAnalysisDraft>> reserveTransactionId(
    String receiptId,
    String transactionId,
  );

  Future<AppResult<ReceiptAnalysisDraft>> finalizeReceiptTransaction({
    required String receiptId,
    required String transactionId,
    required List<TransactionSplit> splits,
  });
}
