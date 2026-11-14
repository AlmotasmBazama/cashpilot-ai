import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../categories/domain/entities/category_suggestion.dart';
import '../../domain/entities/receipt_analysis_draft.dart';
import '../../domain/entities/receipt_duplicate_result.dart';
import '../../domain/entities/receipt_line_item.dart';
import '../../domain/entities/transaction_split.dart';
import '../../domain/enums/image_retention_choice.dart';
import '../../domain/enums/receipt_document_type.dart';
import '../../domain/enums/receipt_draft_status.dart';
import '../../domain/enums/receipt_payment_status.dart';
import '../../domain/enums/receipt_warning.dart';
import '../../domain/failures/receipt_failure_codes.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../../domain/services/receipt_duplicate_detector.dart';
import '../services/receipt_local_image_store.dart';

class ReceiptRepositoryImpl implements ReceiptRepository {
  const ReceiptRepositoryImpl({
    required ScopedAppDatabaseSession session,
    required ReceiptLocalImageStore imageStore,
    ReceiptDuplicateDetector duplicateDetector =
        const ReceiptDuplicateDetector(),
  }) : _session = session,
       _imageStore = imageStore,
       _duplicateDetector = duplicateDetector;

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;
  final ReceiptLocalImageStore _imageStore;
  final ReceiptDuplicateDetector _duplicateDetector;

  @override
  Future<AppResult<ReceiptAnalysisDraft>> createAnalysisDraft(
    ReceiptAnalysisDraft draft,
  ) async {
    try {
      return await _session.runGuardedWrite(() async {
        await _database.transaction(() async {
          await _database.into(_database.receipts).insert(_toCompanion(draft));
          await _replaceLineItems(draft.id, draft.lineItems);
          await _replaceSplits(draft.id, draft.splits);
        });
        return AppResult.success(draft);
      });
    } on Object {
      return _failure('The receipt draft could not be saved.');
    }
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> updateAnalysisDraft(
    ReceiptAnalysisDraft draft,
  ) async {
    try {
      return await _session.runGuardedWrite(() async {
        await _database.transaction(() async {
          final updated =
              await (_database.update(_database.receipts)..where(
                    (row) =>
                        row.ownerScopeId.equals(_scope) &
                        row.id.equals(draft.id),
                  ))
                  .write(_toCompanion(draft));
          if (updated != 1) {
            throw StateError('receipt_not_found');
          }
          await _replaceLineItems(draft.id, draft.lineItems);
          await _replaceSplits(draft.id, draft.splits);
        });
        return AppResult.success(draft);
      });
    } on Object {
      return _failure('The receipt draft could not be updated.');
    }
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft?>> getDraftById(String id) async {
    try {
      final row =
          await (_database.select(_database.receipts)..where(
                (receipt) =>
                    receipt.ownerScopeId.equals(_scope) & receipt.id.equals(id),
              ))
              .getSingleOrNull();
      return AppResult.success(row == null ? null : await _hydrate(row));
    } on Object {
      return _failure('The receipt draft could not be loaded.');
    }
  }

  @override
  Stream<AppResult<ReceiptAnalysisDraft?>> watchDraft(String id) {
    final query = _database.select(_database.receipts)
      ..where(
        (receipt) =>
            receipt.ownerScopeId.equals(_scope) & receipt.id.equals(id),
      );
    return _session.guardStream(
      query.watchSingleOrNull().asyncMap((row) async {
        try {
          return AppResult.success(row == null ? null : await _hydrate(row));
        } on Object {
          return _failure<ReceiptAnalysisDraft?>(
            'The receipt draft could not be loaded.',
          );
        }
      }),
    );
  }

  @override
  Future<AppResult<void>> deleteDraft(String id) async {
    try {
      return await _session.runGuardedWrite(() async {
        final loaded =
            await (_database.select(_database.receipts)..where(
                  (receipt) =>
                      receipt.ownerScopeId.equals(_scope) &
                      receipt.id.equals(id),
                ))
                .getSingleOrNull();
        await _imageStore.deleteReference(loaded?.localImageReference);
        await _database.transaction(() async {
          await (_database.delete(_database.transactionSplits)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.receiptId.equals(id),
              ))
              .go();
          await (_database.delete(_database.receiptLineItems)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.receiptId.equals(id),
              ))
              .go();
          await (_database.delete(_database.receipts)..where(
                (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
              ))
              .go();
        });
        return const AppResult.success(null);
      });
    } on Object {
      return _failure('The receipt draft could not be deleted.');
    }
  }

  @override
  Future<AppResult<void>> saveLineItems(
    String receiptId,
    List<ReceiptLineItem> items,
  ) async {
    try {
      return await _session.runGuardedWrite(() async {
        await _database.transaction(() => _replaceLineItems(receiptId, items));
        return const AppResult.success(null);
      });
    } on Object {
      return _failure('Receipt line items could not be saved.');
    }
  }

  @override
  Future<AppResult<void>> saveSplits(
    String receiptId,
    List<TransactionSplit> splits,
  ) async {
    try {
      return await _session.runGuardedWrite(() async {
        await _database.transaction(() => _replaceSplits(receiptId, splits));
        return const AppResult.success(null);
      });
    } on Object {
      return _failure('Receipt category splits could not be saved.');
    }
  }

  @override
  Future<AppResult<ReceiptDuplicateResult>> findDuplicateCandidates(
    ReceiptAnalysisDraft draft,
  ) async {
    try {
      final rows = await (_database.select(
        _database.receipts,
      )..where((row) => row.ownerScopeId.equals(_scope))).get();
      final candidates = <ReceiptAnalysisDraft>[];
      for (final row in rows) {
        if (row.id != draft.id) {
          candidates.add(await _hydrate(row));
        }
      }
      return AppResult.success(
        _duplicateDetector.detect(target: draft, candidates: candidates),
      );
    } on Object {
      return _failure('Duplicate receipt detection could not be completed.');
    }
  }

  @override
  Future<AppResult<String>> storeLocalImage(
    String receiptId,
    List<int> bytes,
  ) async {
    try {
      return await _session.runGuardedWrite(() async {
        final owned =
            await (_database.select(_database.receipts)..where(
                  (row) =>
                      row.ownerScopeId.equals(_scope) &
                      row.id.equals(receiptId),
                ))
                .getSingleOrNull();
        if (owned == null) {
          return _failure('The receipt draft was not found.');
        }
        return AppResult.success(await _imageStore.write(receiptId, bytes));
      });
    } on Object {
      return _failure('The receipt image could not be stored locally.');
    }
  }

  @override
  Future<AppResult<void>> deleteLocalImage(String receiptId) async {
    try {
      return await _session.runGuardedWrite(() async {
        final row =
            await (_database.select(_database.receipts)..where(
                  (receipt) =>
                      receipt.ownerScopeId.equals(_scope) &
                      receipt.id.equals(receiptId),
                ))
                .getSingleOrNull();
        await _imageStore.deleteReference(row?.localImageReference);
        if (row != null) {
          await (_database.update(_database.receipts)..where(
                (receipt) =>
                    receipt.ownerScopeId.equals(_scope) &
                    receipt.id.equals(receiptId),
              ))
              .write(const ReceiptsCompanion(localImageReference: Value(null)));
        }
        return const AppResult.success(null);
      });
    } on Object {
      return _failure('The local receipt image could not be deleted.');
    }
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> reserveTransactionId(
    String receiptId,
    String transactionId,
  ) async {
    try {
      return await _session.runGuardedWrite(() async {
        final row =
            await (_database.select(_database.receipts)..where(
                  (receipt) =>
                      receipt.ownerScopeId.equals(_scope) &
                      receipt.id.equals(receiptId),
                ))
                .getSingleOrNull();
        if (row == null) {
          return _failure('The receipt draft was not found.');
        }

        // `linked_transaction_id` remains a strict same-owner reference. Until
        // the transaction exists, expose the caller's restart-stable proposal
        // only in the returned aggregate instead of persisting a dangling FK.
        final reserved = row.linkedTransactionId == null
            ? row.copyWith(linkedTransactionId: Value(transactionId))
            : row;
        return AppResult.success(await _hydrate(reserved));
      });
    } on Object {
      return _failure('The receipt transaction could not be reserved.');
    }
  }

  @override
  Future<AppResult<ReceiptAnalysisDraft>> finalizeReceiptTransaction({
    required String receiptId,
    required String transactionId,
    required List<TransactionSplit> splits,
  }) async {
    try {
      return await _session.runGuardedWrite(() async {
        await _database.transaction(() async {
          final receipt =
              await (_database.select(_database.receipts)..where(
                    (row) =>
                        row.ownerScopeId.equals(_scope) &
                        row.id.equals(receiptId),
                  ))
                  .getSingleOrNull();
          if (receipt == null) {
            throw StateError('receipt_not_found');
          }
          final existingLink = receipt.linkedTransactionId;
          if (existingLink != null && existingLink != transactionId) {
            throw StateError('receipt_transaction_link_conflict');
          }
          final transaction =
              await (_database.select(_database.transactions)..where(
                    (row) =>
                        row.ownerScopeId.equals(_scope) &
                        row.id.equals(transactionId),
                  ))
                  .getSingleOrNull();
          if (transaction == null) {
            throw StateError('receipt_transaction_missing');
          }

          final updated =
              await (_database.update(_database.receipts)..where(
                    (receipt) =>
                        receipt.ownerScopeId.equals(_scope) &
                        receipt.id.equals(receiptId) &
                        (receipt.linkedTransactionId.isNull() |
                            receipt.linkedTransactionId.equals(transactionId)),
                  ))
                  .write(
                    ReceiptsCompanion(
                      linkedTransactionId: Value(transactionId),
                      status: Value(ReceiptDraftStatus.confirmed.storageValue),
                      updatedAt: Value(DateTime.now().toUtc()),
                    ),
                  );
          if (updated != 1) {
            throw StateError('receipt_transaction_link_conflict');
          }
          await _replaceSplits(receiptId, splits);
        });
        final result = await getDraftById(receiptId);
        return switch (result) {
          AppSuccess(data: final draft?) => AppResult.success(draft),
          AppSuccess() => _failure(
            'The confirmed receipt could not be loaded.',
          ),
          AppFailure(:final failure) => AppResult.failure(failure),
        };
      });
    } on Object {
      return _failure('The receipt transaction metadata could not be saved.');
    }
  }

  Future<void> _replaceLineItems(
    String receiptId,
    List<ReceiptLineItem> items,
  ) async {
    await (_database.delete(_database.receiptLineItems)..where(
          (row) =>
              row.ownerScopeId.equals(_scope) & row.receiptId.equals(receiptId),
        ))
        .go();
    if (items.isEmpty) {
      return;
    }
    await _database.batch((batch) {
      batch.insertAll(
        _database.receiptLineItems,
        items.map(_lineItemCompanion).toList(growable: false),
      );
    });
  }

  Future<void> _replaceSplits(
    String receiptId,
    List<TransactionSplit> splits,
  ) async {
    await (_database.delete(_database.transactionSplits)..where(
          (row) =>
              row.ownerScopeId.equals(_scope) & row.receiptId.equals(receiptId),
        ))
        .go();
    if (splits.isEmpty) {
      return;
    }
    await _database.batch((batch) {
      batch.insertAll(
        _database.transactionSplits,
        splits
            .map((split) => _splitCompanion(receiptId, split))
            .toList(growable: false),
      );
    });
  }

  Future<ReceiptAnalysisDraft> _hydrate(ReceiptRow row) async {
    final itemRows =
        await (_database.select(_database.receiptLineItems)
              ..where(
                (item) =>
                    item.ownerScopeId.equals(_scope) &
                    item.receiptId.equals(row.id),
              )
              ..orderBy([(item) => OrderingTerm.asc(item.sortOrder)]))
            .get();
    final splitRows =
        await (_database.select(_database.transactionSplits)..where(
              (split) =>
                  split.ownerScopeId.equals(_scope) &
                  split.receiptId.equals(row.id),
            ))
            .get();
    return ReceiptAnalysisDraft.create(
      id: row.id,
      documentType:
          ReceiptDocumentTypeMapper.tryFromStorage(row.documentType) ??
          ReceiptDocumentType.unknown,
      paymentStatus: ReceiptPaymentStatusMapper.fromStorage(row.paymentStatus),
      merchantName: row.merchantName,
      merchantPayeeId: row.merchantPayeeId,
      merchantAddress: row.merchantAddress,
      merchantTaxId: row.merchantTaxId,
      receiptNumber: row.receiptNumber,
      invoiceNumber: row.invoiceNumber,
      purchaseDate: row.purchaseDate,
      dueDate: row.dueDate,
      currency: row.currency,
      subtotal: _decimal(row.subtotal),
      tax: _decimal(row.tax),
      discount: _decimal(row.discount),
      serviceCharge: _decimal(row.serviceCharge),
      tip: _decimal(row.tip),
      otherFees: _decimal(row.otherFees),
      total: _decimal(row.total),
      amountPaid: _decimal(row.amountPaid),
      amountDue: _decimal(row.amountDue),
      paymentMethodHint: row.paymentMethodHint,
      accountHint: row.accountHint,
      confidence: row.confidence,
      warnings: _warnings(row.warningsJson),
      lineItems: itemRows.map(_lineItemFromRow).toList(growable: false),
      splits: splitRows.map(_splitFromRow).toList(growable: false),
      duplicateCandidateIds: _stringList(row.duplicateCandidateIdsJson),
      imageRetentionChoice: ImageRetentionChoiceMapper.fromStorage(
        row.imageRetentionChoice,
      ),
      localImageReference: row.localImageReference,
      imageHash: row.imageHash,
      status: ReceiptDraftStatusMapper.fromStorage(row.status),
      linkedTransactionId: row.linkedTransactionId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  ReceiptsCompanion _toCompanion(ReceiptAnalysisDraft draft) {
    return ReceiptsCompanion(
      id: Value(draft.id),
      ownerScopeId: Value(_scope),
      documentType: Value(draft.documentType.storageValue),
      paymentStatus: Value(draft.paymentStatus.storageValue),
      merchantName: Value(draft.merchantName),
      merchantPayeeId: Value(draft.merchantPayeeId),
      merchantAddress: Value(draft.merchantAddress),
      merchantTaxId: Value(draft.merchantTaxId),
      receiptNumber: Value(draft.receiptNumber),
      invoiceNumber: Value(draft.invoiceNumber),
      purchaseDate: Value(draft.purchaseDate),
      dueDate: Value(draft.dueDate),
      currency: Value(draft.currency),
      subtotal: Value(draft.subtotal?.toString()),
      tax: Value(draft.tax?.toString()),
      discount: Value(draft.discount?.toString()),
      serviceCharge: Value(draft.serviceCharge?.toString()),
      tip: Value(draft.tip?.toString()),
      otherFees: Value(draft.otherFees?.toString()),
      total: Value(draft.total?.toString()),
      amountPaid: Value(draft.amountPaid?.toString()),
      amountDue: Value(draft.amountDue?.toString()),
      paymentMethodHint: Value(draft.paymentMethodHint),
      accountHint: Value(draft.accountHint),
      confidence: Value(draft.confidence),
      warningsJson: Value(
        jsonEncode(draft.warnings.map((value) => value.storageValue).toList()),
      ),
      duplicateCandidateIdsJson: Value(jsonEncode(draft.duplicateCandidateIds)),
      imageRetentionChoice: Value(draft.imageRetentionChoice.storageValue),
      localImageReference: Value(draft.localImageReference),
      imageHash: Value(draft.imageHash),
      status: Value(draft.status.storageValue),
      linkedTransactionId: Value(draft.linkedTransactionId),
      createdAt: Value(draft.createdAt),
      updatedAt: Value(draft.updatedAt),
    );
  }

  ReceiptLineItemsCompanion _lineItemCompanion(ReceiptLineItem item) {
    return ReceiptLineItemsCompanion.insert(
      id: item.id,
      ownerScopeId: Value(_scope),
      receiptId: item.receiptId,
      description: item.description,
      normalizedDescription: item.normalizedDescription,
      quantity: Value(item.quantity?.toString()),
      unit: Value(item.unit),
      unitPrice: Value(item.unitPrice?.toString()),
      discount: Value(item.discount?.toString()),
      tax: Value(item.tax?.toString()),
      totalPrice: Value(item.totalPrice?.toString()),
      categoryId: Value(item.categoryId),
      categoryHint: Value(item.categoryHint),
      categoryConfidence: Value(item.categoryConfidence),
      categorySuggestionSource: item.categorySuggestionSource.name,
      categoryAlternativesJson: Value(jsonEncode(item.categoryAlternatives)),
      skuOrBarcode: Value(item.skuOrBarcode),
      warningsJson: Value(
        jsonEncode(item.warnings.map((value) => value.storageValue).toList()),
      ),
      sortOrder: Value(item.sortOrder),
    );
  }

  TransactionSplitsCompanion _splitCompanion(
    String receiptId,
    TransactionSplit split,
  ) {
    return TransactionSplitsCompanion.insert(
      id: split.id,
      ownerScopeId: Value(_scope),
      receiptId: receiptId,
      transactionId: Value(split.transactionId),
      draftId: Value(split.draftId),
      categoryId: split.categoryId,
      amount: split.amount.toString(),
      sourceReceiptItemIdsJson: Value(jsonEncode(split.sourceReceiptItemIds)),
      description: Value(split.description),
    );
  }

  ReceiptLineItem _lineItemFromRow(ReceiptLineItemRow row) {
    final source = CategorySuggestionSource.values
        .where((value) => value.name == row.categorySuggestionSource)
        .firstOrNull;
    return ReceiptLineItem.create(
      id: row.id,
      receiptId: row.receiptId,
      description: row.description,
      normalizedDescription: row.normalizedDescription,
      quantity: _decimal(row.quantity),
      unit: row.unit,
      unitPrice: _decimal(row.unitPrice),
      discount: _decimal(row.discount),
      tax: _decimal(row.tax),
      totalPrice: _decimal(row.totalPrice),
      categoryId: row.categoryId,
      categoryHint: row.categoryHint,
      categoryConfidence: row.categoryConfidence,
      categorySuggestionSource: source ?? CategorySuggestionSource.fallback,
      categoryAlternatives: _stringList(row.categoryAlternativesJson),
      skuOrBarcode: row.skuOrBarcode,
      warnings: _warnings(row.warningsJson),
      sortOrder: row.sortOrder,
    );
  }

  TransactionSplit _splitFromRow(TransactionSplitRow row) {
    return TransactionSplit.create(
      id: row.id,
      transactionId: row.transactionId,
      draftId: row.draftId,
      categoryId: row.categoryId,
      amount: Decimal.parse(row.amount),
      sourceReceiptItemIds: _stringList(row.sourceReceiptItemIdsJson),
      description: row.description,
    );
  }

  Decimal? _decimal(String? value) =>
      value == null ? null : Decimal.tryParse(value);

  List<String> _stringList(String value) {
    final decoded = jsonDecode(value);
    return decoded is List
        ? decoded.whereType<String>().toList(growable: false)
        : const <String>[];
  }

  List<ReceiptWarning> _warnings(String value) {
    return _stringList(
      value,
    ).map(ReceiptWarningMapper.fromStorage).toList(growable: false);
  }

  AppResult<T> _failure<T>(String message) {
    return AppResult.failure(
      Failure(message: message, code: ReceiptFailureCodes.persistenceFailed),
    );
  }
}
