import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/create_transaction.dart';
import '../../../transactions/domain/usecases/get_transaction.dart';
import '../entities/receipt_transaction_draft.dart';
import '../enums/image_retention_choice.dart';
import '../failures/receipt_failure_codes.dart';
import '../repositories/receipt_repository.dart';
import '../services/receipt_transaction_identity.dart';

class ConfirmReceiptTransactionUseCase {
  ConfirmReceiptTransactionUseCase({
    required CreateTransaction createTransaction,
    required GetTransaction getTransaction,
    required ReceiptRepository receiptRepository,
  }) : _createTransaction = createTransaction,
       _getTransaction = getTransaction,
       _receiptRepository = receiptRepository;

  final CreateTransaction _createTransaction;
  final GetTransaction _getTransaction;
  final ReceiptRepository _receiptRepository;
  final Set<String> _inFlight = <String>{};
  final Map<String, ConfirmedReceiptTransaction> _completed =
      <String, ConfirmedReceiptTransaction>{};

  Future<AppResult<ConfirmedReceiptTransaction>> call(
    ReceiptTransactionDraft draft, {
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const AppResult.failure(
        Failure(
          message: 'Receipt transaction confirmation is required.',
          code: ReceiptFailureCodes.confirmationRequired,
        ),
      );
    }
    final receiptId = draft.receipt.id;
    final completed = _completed[receiptId];
    if (completed != null) {
      final replay = draft.transaction.copyWith(id: completed.transaction.id);
      return _matchesReservedTransaction(completed.transaction, replay)
          ? AppResult.success(completed)
          : _reservationConflict();
    }
    if (!_inFlight.add(receiptId)) {
      return const AppResult.failure(
        Failure(
          message: 'This receipt confirmation is already in progress.',
          code: ReceiptFailureCodes.alreadyConfirmed,
        ),
      );
    }
    try {
      final proposedTransactionId =
          ReceiptTransactionIdentity.transactionIdForReceipt(receiptId);
      final reserved = await _receiptRepository.reserveTransactionId(
        receiptId,
        proposedTransactionId,
      );
      final receipt = switch (reserved) {
        AppSuccess(:final data) => data,
        AppFailure() => null,
      };
      if (receipt == null) {
        return AppResult.failure((reserved as AppFailure).failure);
      }
      final transactionId =
          receipt.linkedTransactionId ?? proposedTransactionId;
      final transaction = draft.transaction.copyWith(id: transactionId);
      final savedResult = await _loadOrCreateExact(transaction);
      final savedTransaction = switch (savedResult) {
        AppSuccess(:final data) => data,
        AppFailure() => null,
      };
      if (savedTransaction == null) {
        return AppResult.failure((savedResult as AppFailure).failure);
      }

      final linkedSplits = draft.splits
          .map((split) => split.copyWith(transactionId: savedTransaction.id))
          .toList(growable: false);
      final finalized = await _receiptRepository.finalizeReceiptTransaction(
        receiptId: receiptId,
        transactionId: savedTransaction.id,
        splits: linkedSplits,
      );
      final finalizedReceipt = switch (finalized) {
        AppSuccess(:final data) => data,
        AppFailure() => null,
      };
      if (finalizedReceipt == null) {
        return _metadataFinalizationPending();
      }

      var completedReceipt = finalizedReceipt;
      if (finalizedReceipt.imageRetentionChoice ==
          ImageRetentionChoice.deleteAfterExtraction) {
        final deleted = await _receiptRepository.deleteLocalImage(receiptId);
        if (deleted is AppFailure<void>) {
          return _imageCleanupPending();
        }
        final reloaded = await _receiptRepository.getDraftById(receiptId);
        switch (reloaded) {
          case AppSuccess(data: final receipt?)
              when receipt.localImageReference == null:
            completedReceipt = receipt;
          case AppSuccess():
          case AppFailure():
            return _imageCleanupPending();
        }
      }

      final result = ConfirmedReceiptTransaction(
        transaction: savedTransaction,
        receipt: completedReceipt,
      );
      _completed[receiptId] = result;
      return AppResult.success(result);
    } finally {
      _inFlight.remove(receiptId);
    }
  }

  Future<AppResult<Transaction>> _loadOrCreateExact(
    Transaction transaction,
  ) async {
    final existingResult = await _getTransaction(transaction.id);
    switch (existingResult) {
      case AppSuccess<Transaction?>(data: final existing?):
        return _matchesReservedTransaction(existing, transaction)
            ? AppResult.success(existing)
            : _reservationConflict();
      case AppFailure<Transaction?>(:final failure):
        return AppResult.failure(failure);
      case AppSuccess<Transaction?>(data: null):
        break;
    }

    final created = await _createTransaction(transaction);
    switch (created) {
      case AppSuccess<Transaction>(:final data):
        return _matchesReservedTransaction(data, transaction)
            ? AppResult.success(data)
            : _reservationConflict();
      case AppFailure<Transaction>():
        // Another process may have committed the deterministic identity after
        // the pre-read. The failed create transaction has rolled back its own
        // balance projection, so an exact reread is safe and mutation-free.
        final reconciled = await _getTransaction(transaction.id);
        return switch (reconciled) {
          AppSuccess<Transaction?>(data: final existing?) =>
            _matchesReservedTransaction(existing, transaction)
                ? AppResult.success(existing)
                : _reservationConflict(),
          AppSuccess<Transaction?>(data: null) => AppResult.failure(
            created.failure,
          ),
          AppFailure<Transaction?>(:final failure) => AppResult.failure(
            failure,
          ),
        };
    }
  }

  bool _matchesReservedTransaction(
    Transaction existing,
    Transaction requested,
  ) {
    return existing.id == requested.id &&
        existing.accountId == requested.accountId &&
        existing.categoryId == requested.categoryId &&
        existing.payeeId == requested.payeeId &&
        existing.amount.amount == requested.amount.amount &&
        existing.amount.normalizedCurrencyCode ==
            requested.amount.normalizedCurrencyCode &&
        existing.type == requested.type &&
        existing.paymentMethod == requested.paymentMethod &&
        existing.source == requested.source &&
        existing.status == requested.status &&
        existing.incomeSourceType == requested.incomeSourceType &&
        existing.transferGroupId == requested.transferGroupId &&
        _exchangeRatesMatch(existing, requested) &&
        existing.note == requested.note &&
        existing.transactionDate.toUtc() == requested.transactionDate.toUtc() &&
        existing.location == requested.location &&
        existing.attachmentCount == requested.attachmentCount &&
        existing.aiConfidence == requested.aiConfidence &&
        existing.needsReview == requested.needsReview;
  }

  bool _exchangeRatesMatch(Transaction existing, Transaction requested) {
    final existingRate = existing.exchangeRate;
    final requestedRate = requested.exchangeRate;
    if (existingRate == null || requestedRate == null) {
      return existingRate == null && requestedRate == null;
    }
    final existingAsOf = existingRate.asOf;
    final requestedAsOf = requestedRate.asOf;
    final sameAsOf = existingAsOf == null || requestedAsOf == null
        ? existingAsOf == null && requestedAsOf == null
        : existingAsOf.toUtc() == requestedAsOf.toUtc();
    return existingRate.fromCurrencyCode.toUpperCase() ==
            requestedRate.fromCurrencyCode.toUpperCase() &&
        existingRate.toCurrencyCode.toUpperCase() ==
            requestedRate.toCurrencyCode.toUpperCase() &&
        existingRate.rate == requestedRate.rate &&
        sameAsOf;
  }

  AppResult<T> _reservationConflict<T>() {
    return const AppResult.failure(
      Failure(
        message:
            'This receipt identity belongs to a different transaction. Review the receipt before retrying.',
        code: ReceiptFailureCodes.transactionReservationConflict,
      ),
    );
  }

  AppResult<T> _metadataFinalizationPending<T>() {
    return const AppResult.failure(
      Failure(
        message:
            'The transaction was created, but receipt confirmation is still pending. Retry to finish safely.',
        code: ReceiptFailureCodes.metadataFinalizationPending,
      ),
    );
  }

  AppResult<T> _imageCleanupPending<T>() {
    return const AppResult.failure(
      Failure(
        message:
            'The transaction was created, but its local receipt image could not be deleted. Retry to finish cleanup.',
        code: ReceiptFailureCodes.imageCleanupPending,
      ),
    );
  }
}
