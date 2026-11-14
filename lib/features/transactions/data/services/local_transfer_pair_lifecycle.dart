import 'package:decimal/decimal.dart';

import '../../../../core/error/app_exception.dart';
import '../../../finance_engine/domain/entities/transfer_command.dart';
import '../../../finance_engine/domain/services/transfer_processor.dart';
import '../../domain/entities/transaction.dart';
import '../../../payment_methods/payment_methods.dart'
    show PaymentMethod, PaymentMethodX;
import '../../domain/enums/transaction_source.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/failures/transaction_failure_codes.dart';
import '../../domain/services/transaction_status_transition_policy.dart';
import '../../domain/services/transfer_pair_lifecycle.dart';
import '../datasources/local/transactions_local_data_source.dart';
import '../mappers/transaction_mapper.dart';

final class LocalTransferPairLifecycle implements TransferPairLifecycle {
  const LocalTransferPairLifecycle({
    required TransactionsLocalDataSource localDataSource,
    required TransferProcessor transferProcessor,
  }) : _localDataSource = localDataSource,
       _transferProcessor = transferProcessor;

  final TransactionsLocalDataSource _localDataSource;
  final TransferProcessor _transferProcessor;

  @override
  Future<List<String>> deletePendingPair(Transaction transaction) async {
    final pair = await _requiredTransferPair(transaction);
    if (pair.status != TransactionStatus.pending) {
      throw const AppException.validation(
        message:
            'Only a pending transfer can be deleted. Cancel posted transfers instead.',
        code: TransactionFailureCodes.transferHardDeleteNotAllowed,
      );
    }

    await _localDataSource.deleteTransferPair(
      transferGroupId: pair.outgoing.transferGroupId!,
      outgoingTransactionId: pair.outgoing.id,
      incomingTransactionId: pair.incoming.id,
    );
    return pair.transactions
        .map((transaction) => transaction.id)
        .toList(growable: false);
  }

  @override
  Future<List<Transaction>> updateStatus(
    Transaction transaction,
    TransactionStatus status,
  ) async {
    final pair = await _requiredTransferPair(transaction);
    validateTransactionStatusTransition(pair.status, status);
    if (pair.status == status) {
      return pair.transactions;
    }

    // Persisted leg amounts are the ledger authority for posting and reversal.
    // A target-only transfer can have a rounded informational rate, so do not
    // reinterpret that rate as a second independently supplied authority.
    final command = TransferCommand(
      sourceAccountId: pair.outgoing.accountId,
      targetAccountId: pair.incoming.accountId,
      sourceAmount: pair.outgoing.amount,
      targetAmount: pair.incoming.amount,
      occurredAt: DateTime.now().toUtc(),
    );

    if (pair.status == TransactionStatus.pending &&
        status == TransactionStatus.posted) {
      await _transferProcessor.process(command);
    } else if (pair.status == TransactionStatus.posted &&
        status == TransactionStatus.cancelled) {
      await _transferProcessor.reverse(command);
    }

    final updatedAt = DateTime.now().toUtc();
    final changedOutgoing = pair.outgoing.copyWith(
      status: status,
      updatedAt: updatedAt,
    );
    final changedIncoming = pair.incoming.copyWith(
      status: status,
      updatedAt: updatedAt,
    );
    final stored = await _localDataSource.updateTransferPair(
      outgoing: changedOutgoing.toDto(),
      incoming: changedIncoming.toDto(),
    );
    return List.unmodifiable(<Transaction>[
      stored.outgoing.toDomain(),
      stored.incoming.toDomain(),
    ]);
  }

  Future<_TransferPair> _requiredTransferPair(Transaction transaction) async {
    final transferGroupId = transaction.transferGroupId;
    if (transferGroupId == null ||
        !RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
        ).hasMatch(transferGroupId)) {
      throw const AppException.validation(
        message: 'This legacy transfer does not have a safe group link.',
        code: TransactionFailureCodes.transferGroupMissing,
      );
    }

    final integrity = await _localDataSource.inspectTransferGroup(
      transferGroupId,
    );
    if (integrity != TransferGroupIntegrity.scopedPair) {
      throw const AppException.validation(
        message: 'The linked transfer records are incomplete or inconsistent.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    final records = await _localDataSource.getStoredTransferGroup(
      transferGroupId,
    );
    final pair = _validatedStoredPair(records);
    final source = await _localDataSource.getAccountBalanceSnapshot(
      pair.outgoing.accountId,
    );
    final target = await _localDataSource.getAccountBalanceSnapshot(
      pair.incoming.accountId,
    );
    if (source == null ||
        target == null ||
        source.currencyCode.toUpperCase() !=
            pair.outgoing.amount.normalizedCurrencyCode ||
        target.currencyCode.toUpperCase() !=
            pair.incoming.amount.normalizedCurrencyCode) {
      throw const AppException.validation(
        message: 'The stored transfer account currencies are invalid.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    return pair;
  }

  _TransferPair _validatedStoredPair(List<StoredTransferRecord> records) {
    if (records.length != 2) {
      throw const AppException.validation(
        message: 'The stored transfer pair is incomplete.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    final outgoingRecords = records.where(
      (record) =>
          record.transaction.type == TransactionType.transferOut.storageValue,
    );
    final incomingRecords = records.where(
      (record) =>
          record.transaction.type == TransactionType.transferIn.storageValue,
    );
    if (outgoingRecords.length != 1 || incomingRecords.length != 1) {
      throw const AppException.validation(
        message: 'The stored transfer roles are invalid.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    final outgoingDto = outgoingRecords.single.transaction;
    final incomingDto = incomingRecords.single.transaction;
    Decimal outgoingAmount;
    Decimal incomingAmount;
    Decimal outgoingRate;
    Decimal incomingRate;
    try {
      outgoingAmount = Decimal.parse(outgoingDto.amount);
      incomingAmount = Decimal.parse(incomingDto.amount);
      outgoingRate = Decimal.parse(outgoingDto.exchangeRate ?? '');
      incomingRate = Decimal.parse(incomingDto.exchangeRate ?? '');
    } on Object {
      throw const AppException.validation(
        message: 'The stored transfer numeric values are invalid.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    final fingerprints = records
        .map((record) => record.payloadFingerprint)
        .toList(growable: false);
    final fingerprintValid =
        fingerprints[0] == fingerprints[1] &&
        (fingerprints[0] == null ||
            RegExp(r'^[0-9a-f]{64}$').hasMatch(fingerprints[0]!));
    final transferTermsValid = _transferTermsAreValid(
      outgoingCurrencyCode: outgoingDto.currencyCode,
      incomingCurrencyCode: incomingDto.currencyCode,
      outgoingAmount: outgoingAmount,
      incomingAmount: incomingAmount,
      exchangeRate: outgoingRate,
      allowInformationalCrossCurrencyRate: fingerprints.every(
        (fingerprint) => fingerprint != null,
      ),
    );
    final statuses = TransactionStatus.values
        .map((status) => status.storageValue)
        .toSet();
    final sources = TransactionSource.values
        .map((source) => source.storageValue)
        .toSet();
    final valid =
        fingerprintValid &&
        transferTermsValid &&
        RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
        ).hasMatch(outgoingDto.transferGroupId ?? '') &&
        outgoingDto.transferGroupId == incomingDto.transferGroupId &&
        RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
        ).hasMatch(outgoingDto.id) &&
        RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
        ).hasMatch(incomingDto.id) &&
        statuses.contains(outgoingDto.status) &&
        statuses.contains(incomingDto.status) &&
        sources.contains(outgoingDto.source) &&
        sources.contains(incomingDto.source) &&
        outgoingDto.id != incomingDto.id &&
        outgoingDto.accountId != incomingDto.accountId &&
        outgoingAmount > Decimal.zero &&
        incomingAmount > Decimal.zero &&
        outgoingRate > Decimal.zero &&
        incomingRate == outgoingRate &&
        outgoingDto.status == incomingDto.status &&
        outgoingDto.categoryId == incomingDto.categoryId &&
        outgoingDto.source == incomingDto.source &&
        outgoingDto.note == incomingDto.note &&
        outgoingDto.transactionDate.toUtc() ==
            incomingDto.transactionDate.toUtc() &&
        outgoingDto.paymentMethod == PaymentMethod.bankTransfer.storageValue &&
        incomingDto.paymentMethod == PaymentMethod.bankTransfer.storageValue &&
        outgoingDto.exchangeRateFromCurrencyCode?.toUpperCase() ==
            outgoingDto.currencyCode.toUpperCase() &&
        outgoingDto.exchangeRateToCurrencyCode?.toUpperCase() ==
            incomingDto.currencyCode.toUpperCase() &&
        outgoingDto.exchangeRateFromCurrencyCode ==
            incomingDto.exchangeRateFromCurrencyCode &&
        outgoingDto.exchangeRateToCurrencyCode ==
            incomingDto.exchangeRateToCurrencyCode &&
        outgoingDto.exchangeRateAsOf?.toUtc() ==
            incomingDto.exchangeRateAsOf?.toUtc() &&
        outgoingDto.payeeId == null &&
        incomingDto.payeeId == null &&
        outgoingDto.incomeSourceType == null &&
        incomingDto.incomeSourceType == null &&
        outgoingDto.location == null &&
        incomingDto.location == null &&
        outgoingDto.attachmentCount == 0 &&
        incomingDto.attachmentCount == 0 &&
        outgoingDto.aiConfidence == null &&
        incomingDto.aiConfidence == null &&
        !outgoingDto.needsReview &&
        !incomingDto.needsReview;
    if (!valid) {
      throw const AppException.validation(
        message: 'The stored transfer pair is malformed.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    final outgoing = outgoingDto.toDomain();
    final incoming = incomingDto.toDomain();
    return _TransferPair(
      transactions: <Transaction>[outgoing, incoming],
      outgoing: outgoing,
      incoming: incoming,
    );
  }

  static bool _transferTermsAreValid({
    required String outgoingCurrencyCode,
    required String incomingCurrencyCode,
    required Decimal outgoingAmount,
    required Decimal incomingAmount,
    required Decimal exchangeRate,
    required bool allowInformationalCrossCurrencyRate,
  }) {
    final isSameCurrency =
        outgoingCurrencyCode.toUpperCase() ==
        incomingCurrencyCode.toUpperCase();
    if (isSameCurrency) {
      return exchangeRate == Decimal.one && incomingAmount == outgoingAmount;
    }
    return allowInformationalCrossCurrencyRate ||
        incomingAmount == outgoingAmount * exchangeRate;
  }
}

final class _TransferPair {
  const _TransferPair({
    required this.transactions,
    required this.outgoing,
    required this.incoming,
  });

  final List<Transaction> transactions;
  final Transaction outgoing;
  final Transaction incoming;

  TransactionStatus get status => outgoing.status;
}
