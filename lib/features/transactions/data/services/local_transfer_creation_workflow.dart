import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../../finance_engine/domain/entities/processed_transfer.dart';
import '../../../finance_engine/domain/entities/transfer_command.dart';
import '../../../finance_engine/domain/exceptions/finance_exception.dart';
import '../../../finance_engine/domain/services/transfer_processor.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../domain/entities/create_transfer_command.dart';
import '../../domain/entities/created_transfer.dart';
import '../../domain/entities/transaction.dart';
import '../../../payment_methods/payment_methods.dart'
    show PaymentMethod, PaymentMethodX;
import '../../domain/enums/transaction_source.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/failures/transaction_failure_codes.dart';
import '../../domain/services/transfer_creation_workflow.dart';
import '../datasources/local/transactions_local_data_source.dart';
import '../dtos/transaction_dto.dart';
import '../mappers/transaction_mapper.dart';

/// Local, atomic implementation of the transfer-creation port.
///
/// The order of replay inspection, account validation, Finance Engine
/// projection, pair persistence, and best-effort sync enqueueing is part of
/// the existing behavior contract and is deliberately kept in one workflow.
final class LocalTransferCreationWorkflow implements TransferCreationWorkflow {
  const LocalTransferCreationWorkflow({
    required TransactionsLocalDataSource localDataSource,
    required TransferProcessor transferProcessor,
    required AppLogger logger,
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _transferProcessor = transferProcessor,
       _logger = logger,
       _syncQueue = syncQueue;

  final TransactionsLocalDataSource _localDataSource;
  final TransferProcessor _transferProcessor;
  final AppLogger _logger;
  final SyncMutationQueue? _syncQueue;

  @override
  Future<AppResult<CreatedTransfer>> create(CreateTransferCommand command) {
    final key =
        '${_localDataSource.ownerScopeValue}:${command.transferGroupId}';
    return _TransferCreationCoordinator.run(
      key,
      () => _createSerialized(command),
    );
  }

  Future<AppResult<CreatedTransfer>> _createSerialized(
    CreateTransferCommand command,
  ) async {
    final payloadFingerprint = _transferPayloadFingerprint(command);
    try {
      if (command.status != TransactionStatus.pending &&
          command.status != TransactionStatus.posted) {
        throw const AppException.validation(
          message: 'A transfer must be created as pending or posted.',
          code: TransactionFailureCodes.invalidTransferInitialStatus,
        );
      }

      final outcome = await _localDataSource.runInTransaction(() async {
        final replay = await _reconcileTransferReplay(
          command,
          payloadFingerprint,
        );
        if (replay != null) {
          return _TransferCreationOutcome(replay, createdNow: false);
        }

        await _validateTransferCreationAccounts(command);
        final transferGroupId = command.transferGroupId;
        final financeCommand = TransferCommand(
          sourceAccountId: command.sourceAccountId,
          targetAccountId: command.targetAccountId,
          sourceAmount: command.sourceAmount,
          targetAmount: command.targetAmount,
          exchangeRate: command.exchangeRate,
          occurredAt: command.occurredAt,
        );
        final processed = command.status == TransactionStatus.posted
            ? await _transferProcessor.process(financeCommand)
            : _processedFromPreview(
                await _transferProcessor.preview(financeCommand),
              );
        final outgoing = _transferTransaction(
          accountId: command.sourceAccountId,
          categoryId: command.categoryId,
          amount: processed.sourceAmount,
          type: TransactionType.transferOut,
          status: command.status,
          transferGroupId: transferGroupId,
          source: command.source,
          exchangeRate: processed.exchangeRate,
          note: command.note,
          transactionDate: processed.processedAt,
          id: command.outgoingTransactionId,
        );
        final incoming = _transferTransaction(
          accountId: command.targetAccountId,
          categoryId: command.categoryId,
          amount: processed.targetAmount,
          type: TransactionType.transferIn,
          status: command.status,
          transferGroupId: transferGroupId,
          source: command.source,
          exchangeRate: processed.exchangeRate,
          note: command.note,
          transactionDate: processed.processedAt,
          id: command.incomingTransactionId,
        );

        final pair = await _localDataSource.createTransferPair(
          outgoing: outgoing.toDto(),
          incoming: incoming.toDto(),
          payloadFingerprint: payloadFingerprint,
        );

        return _TransferCreationOutcome(
          CreatedTransfer(
            transferGroupId: transferGroupId,
            outgoingTransaction: pair.outgoing.toDomain(),
            incomingTransaction: pair.incoming.toDomain(),
            transfer: processed,
          ),
          createdNow: true,
        );
      });

      if (outcome.createdNow) {
        await _queueUpsert(outcome.transfer.outgoingTransaction);
        await _queueUpsert(outcome.transfer.incomingTransaction);
      }
      return AppResult.success(outcome.transfer);
    } on Object catch (error, stackTrace) {
      // A separate connection/process may have committed the exact pair after
      // our pre-read. The failed outer transaction has already rolled back any
      // Finance Engine projection, so reconciliation is safe and mutation-free.
      try {
        final replay = await _localDataSource.runInTransaction(
          () => _reconcileTransferReplay(command, payloadFingerprint),
        );
        if (replay != null) {
          return AppResult.success(replay);
        }
      } on Object catch (replayError, replayStackTrace) {
        return _failure(
          'Unable to reconcile transfer.',
          replayError,
          replayStackTrace,
        );
      }
      return _failure('Unable to create transfer.', error, stackTrace);
    }
  }

  Future<CreatedTransfer?> _reconcileTransferReplay(
    CreateTransferCommand command,
    String payloadFingerprint,
  ) async {
    final integrity = await _localDataSource.inspectTransferGroup(
      command.transferGroupId,
    );
    switch (integrity) {
      case TransferGroupIntegrity.absent:
        return null;
      case TransferGroupIntegrity.crossScopeCollision:
        throw const AppException.validation(
          message: 'The transfer identity belongs to another owner scope.',
          code: TransactionFailureCodes.transferGroupConflict,
        );
      case TransferGroupIntegrity.scopedMalformed:
        throw const AppException.validation(
          message: 'The stored transfer group is malformed.',
          code: TransactionFailureCodes.transferGroupMalformed,
        );
      case TransferGroupIntegrity.scopedPair:
        break;
    }

    final records = await _localDataSource.getStoredTransferGroup(
      command.transferGroupId,
    );
    if (records.length != 2 ||
        records.any((record) => record.payloadFingerprint == null)) {
      throw const AppException.validation(
        message: 'The stored transfer group has no replay authority.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    if (records.any(
      (record) => record.payloadFingerprint != payloadFingerprint,
    )) {
      throw const AppException.validation(
        message: 'The transfer identity was reused for another payload.',
        code: TransactionFailureCodes.transferGroupConflict,
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
        message: 'The stored transfer roles are malformed.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    final outgoingDto = outgoingRecords.single.transaction;
    final incomingDto = incomingRecords.single.transaction;
    _validateStoredReplayPayload(
      command: command,
      outgoing: outgoingDto,
      incoming: incomingDto,
    );

    final outgoing = outgoingDto.toDomain();
    final incoming = incomingDto.toDomain();
    final sourceSnapshot = await _localDataSource.getAccountBalanceSnapshot(
      outgoing.accountId,
    );
    final targetSnapshot = await _localDataSource.getAccountBalanceSnapshot(
      incoming.accountId,
    );
    if (sourceSnapshot == null || targetSnapshot == null) {
      throw const AppException.validation(
        message: 'The stored transfer accounts are unavailable.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    if (sourceSnapshot.currencyCode.toUpperCase() !=
            outgoing.amount.normalizedCurrencyCode ||
        targetSnapshot.currencyCode.toUpperCase() !=
            incoming.amount.normalizedCurrencyCode) {
      throw const AppException.validation(
        message: 'The stored transfer account currencies are inconsistent.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    final sourceBalance = _snapshotMoney(sourceSnapshot);
    final targetBalance = _snapshotMoney(targetSnapshot);
    final exchangeRate = outgoing.exchangeRate;
    if (exchangeRate == null) {
      throw const AppException.validation(
        message: 'The stored transfer exchange rate is unavailable.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
    return CreatedTransfer(
      transferGroupId: command.transferGroupId,
      outgoingTransaction: outgoing,
      incomingTransaction: incoming,
      transfer: ProcessedTransfer(
        sourceAccountId: outgoing.accountId,
        targetAccountId: incoming.accountId,
        sourceAmount: outgoing.amount,
        targetAmount: incoming.amount,
        sourcePreviousBalance: sourceBalance,
        sourceNewBalance: sourceBalance,
        targetPreviousBalance: targetBalance,
        targetNewBalance: targetBalance,
        exchangeRate: exchangeRate,
        processedAt: DateTime.now().toUtc(),
      ),
      replayed: true,
    );
  }

  Future<void> _validateTransferCreationAccounts(
    CreateTransferCommand command,
  ) async {
    final source = await _localDataSource.getAccountBalanceSnapshot(
      command.sourceAccountId,
    );
    if (source == null || source.isArchived) {
      throw FinanceException.accountNotFound(command.sourceAccountId);
    }
    final target = await _localDataSource.getAccountBalanceSnapshot(
      command.targetAccountId,
    );
    if (target == null || target.isArchived) {
      throw FinanceException.accountNotFound(command.targetAccountId);
    }
    if (source.currencyCode.toUpperCase() !=
        command.sourceAmount.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: source.currencyCode,
        actualCurrencyCode: command.sourceAmount.currencyCode,
      );
    }
    final explicitTarget = command.targetAmount;
    if (explicitTarget != null &&
        target.currencyCode.toUpperCase() !=
            explicitTarget.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: target.currencyCode,
        actualCurrencyCode: explicitTarget.currencyCode,
      );
    }
  }

  void _validateStoredReplayPayload({
    required CreateTransferCommand command,
    required TransactionDto outgoing,
    required TransactionDto incoming,
  }) {
    final validStatuses = TransactionStatus.values
        .map((value) => value.storageValue)
        .toSet();
    final validSources = TransactionSource.values
        .map((value) => value.storageValue)
        .toSet();
    Decimal sourceAmount;
    Decimal targetAmount;
    Decimal outgoingRate;
    Decimal incomingRate;
    try {
      sourceAmount = Decimal.parse(outgoing.amount);
      targetAmount = Decimal.parse(incoming.amount);
      outgoingRate = Decimal.parse(outgoing.exchangeRate ?? '');
      incomingRate = Decimal.parse(incoming.exchangeRate ?? '');
    } on Object {
      throw const AppException.validation(
        message: 'The stored transfer numeric payload is malformed.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }

    final structurallyValid =
        validStatuses.contains(outgoing.status) &&
        validStatuses.contains(incoming.status) &&
        validSources.contains(outgoing.source) &&
        validSources.contains(incoming.source) &&
        outgoing.paymentMethod == PaymentMethod.bankTransfer.storageValue &&
        incoming.paymentMethod == PaymentMethod.bankTransfer.storageValue &&
        outgoing.transferGroupId == command.transferGroupId &&
        incoming.transferGroupId == command.transferGroupId &&
        outgoing.id == command.outgoingTransactionId &&
        incoming.id == command.incomingTransactionId &&
        outgoing.status == incoming.status &&
        outgoing.categoryId == incoming.categoryId &&
        outgoing.source == incoming.source &&
        outgoing.note == incoming.note &&
        outgoing.transactionDate.toUtc() == incoming.transactionDate.toUtc() &&
        outgoing.exchangeRateFromCurrencyCode ==
            incoming.exchangeRateFromCurrencyCode &&
        outgoing.exchangeRateToCurrencyCode ==
            incoming.exchangeRateToCurrencyCode &&
        outgoing.exchangeRateFromCurrencyCode?.toUpperCase() ==
            outgoing.currencyCode.toUpperCase() &&
        outgoing.exchangeRateToCurrencyCode?.toUpperCase() ==
            incoming.currencyCode.toUpperCase() &&
        outgoingRate == incomingRate &&
        outgoingRate > Decimal.zero &&
        outgoing.exchangeRateAsOf?.toUtc() ==
            incoming.exchangeRateAsOf?.toUtc() &&
        outgoing.payeeId == null &&
        incoming.payeeId == null &&
        outgoing.incomeSourceType == null &&
        incoming.incomeSourceType == null &&
        outgoing.location == null &&
        incoming.location == null &&
        outgoing.attachmentCount == 0 &&
        incoming.attachmentCount == 0 &&
        outgoing.aiConfidence == null &&
        incoming.aiConfidence == null &&
        !outgoing.needsReview &&
        !incoming.needsReview &&
        outgoing.accountId != incoming.accountId &&
        sourceAmount > Decimal.zero &&
        targetAmount > Decimal.zero;
    if (!structurallyValid) {
      throw const AppException.validation(
        message: 'The stored transfer payload is malformed.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }

    final explicitTarget = command.targetAmount;
    final explicitRate = command.exchangeRate;
    final commandMatches =
        outgoing.accountId == command.sourceAccountId &&
        incoming.accountId == command.targetAccountId &&
        sourceAmount == command.sourceAmount.amount &&
        outgoing.currencyCode.toUpperCase() ==
            command.sourceAmount.normalizedCurrencyCode &&
        (explicitTarget == null ||
            (targetAmount == explicitTarget.amount &&
                incoming.currencyCode.toUpperCase() ==
                    explicitTarget.normalizedCurrencyCode)) &&
        (explicitRate == null ||
            (outgoing.exchangeRateFromCurrencyCode?.toUpperCase() ==
                    explicitRate.fromCurrencyCode.toUpperCase() &&
                outgoing.exchangeRateToCurrencyCode?.toUpperCase() ==
                    explicitRate.toCurrencyCode.toUpperCase() &&
                outgoingRate == explicitRate.rate &&
                outgoing.exchangeRateAsOf?.toUtc() ==
                    (explicitRate.asOf ??
                            command.occurredAt ??
                            outgoing.transactionDate)
                        .toUtc())) &&
        _isReplayStatusDescendant(
          initial: command.status,
          currentStorageValue: outgoing.status,
        ) &&
        outgoing.categoryId == command.categoryId &&
        outgoing.source == command.source.storageValue &&
        outgoing.note == command.note &&
        (command.occurredAt == null ||
            outgoing.transactionDate.toUtc() == command.occurredAt!.toUtc());
    if (!commandMatches) {
      throw const AppException.validation(
        message: 'The transfer identity was reused for another payload.',
        code: TransactionFailureCodes.transferGroupConflict,
      );
    }
  }

  bool _isReplayStatusDescendant({
    required TransactionStatus initial,
    required String currentStorageValue,
  }) {
    final current = TransactionStatus.values
        .where((status) => status.storageValue == currentStorageValue)
        .firstOrNull;
    return switch ((initial, current)) {
      (TransactionStatus.pending, TransactionStatus.pending) ||
      (TransactionStatus.pending, TransactionStatus.posted) ||
      (TransactionStatus.pending, TransactionStatus.cancelled) ||
      (TransactionStatus.posted, TransactionStatus.posted) ||
      (TransactionStatus.posted, TransactionStatus.cancelled) => true,
      _ => false,
    };
  }

  String _transferPayloadFingerprint(CreateTransferCommand command) {
    Map<String, Object?> money(Money value) => <String, Object?>{
      'decimal': value.amount.toString(),
      'currency': value.normalizedCurrencyCode,
    };
    Map<String, Object?> optionalMoney(Money? value) => <String, Object?>{
      'present': value != null,
      'value': value == null ? null : money(value),
    };
    Map<String, Object?> optionalDate(DateTime? value) => <String, Object?>{
      'present': value != null,
      'utc': value?.toUtc().toIso8601String(),
    };
    final rate = command.exchangeRate;
    final canonical = <String, Object?>{
      'domain': 'cashpilot.transfer-intent.v1',
      'ownerScope': _localDataSource.ownerScopeValue,
      'transferGroupId': command.transferGroupId,
      'outgoingTransactionId': command.outgoingTransactionId,
      'incomingTransactionId': command.incomingTransactionId,
      'sourceAccountId': command.sourceAccountId,
      'targetAccountId': command.targetAccountId,
      'sourceAmount': money(command.sourceAmount),
      'targetAmount': optionalMoney(command.targetAmount),
      'rateProvenance': rate != null
          ? 'explicit'
          : command.targetAmount != null
          ? 'derivedFromTarget'
          : 'provider',
      'exchangeRate': <String, Object?>{
        'present': rate != null,
        'from': rate?.fromCurrencyCode.toUpperCase(),
        'to': rate?.toCurrencyCode.toUpperCase(),
        'decimal': rate?.rate.toString(),
        'asOf': optionalDate(rate?.asOf),
      },
      'status': command.status.storageValue,
      'categoryId': command.categoryId,
      'source': command.source.storageValue,
      'paymentMethod': PaymentMethod.bankTransfer.storageValue,
      'note': <String, Object?>{
        'present': command.note != null,
        'value': command.note,
      },
      'occurredAt': optionalDate(command.occurredAt),
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  Money _snapshotMoney(ScopedAccountBalanceSnapshot snapshot) {
    try {
      return Money(
        amount: Decimal.parse(snapshot.balance),
        currencyCode: snapshot.currencyCode,
      );
    } on Object {
      throw const AppException.validation(
        message: 'The account balance projection is malformed.',
        code: TransactionFailureCodes.transferGroupMalformed,
      );
    }
  }

  Transaction _transferTransaction({
    required String accountId,
    required String categoryId,
    required Money amount,
    required TransactionType type,
    required TransactionStatus status,
    required String transferGroupId,
    required TransactionSource source,
    required ExchangeRate exchangeRate,
    required DateTime transactionDate,
    String? note,
    String? id,
  }) {
    return Transaction.create(
      id: id,
      accountId: accountId,
      categoryId: categoryId,
      amount: amount,
      type: type,
      paymentMethod: PaymentMethod.bankTransfer,
      source: source,
      status: status,
      transferGroupId: transferGroupId,
      exchangeRate: exchangeRate,
      note: note,
      transactionDate: transactionDate,
    );
  }

  ProcessedTransfer _processedFromPreview(PreparedTransfer prepared) {
    return ProcessedTransfer(
      sourceAccountId: prepared.sourceAccount.accountId,
      targetAccountId: prepared.targetAccount.accountId,
      sourceAmount: prepared.sourceAmount,
      targetAmount: prepared.targetAmount,
      sourcePreviousBalance: prepared.sourceAccount.money,
      sourceNewBalance: prepared.sourceAccount.money,
      targetPreviousBalance: prepared.targetAccount.money,
      targetNewBalance: prepared.targetAccount.money,
      exchangeRate: prepared.exchangeRate,
      processedAt: prepared.processedAt,
    );
  }

  AppResult<T> _failure<T>(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(message, error, stackTrace);
    if (error is AppException) {
      return AppResult.failure(
        Failure(message: error.message, code: error.code),
      );
    }
    if (error is FinanceException) {
      return AppResult.failure(
        Failure(message: error.message, code: error.code),
      );
    }
    return AppResult.failure(Failure(message: message));
  }

  Future<void> _queueUpsert(Transaction transaction) {
    final payload = Map<String, dynamic>.from(transaction.toJson())
      ..remove('accountBalance')
      ..remove('balance');
    return enqueueSyncUpsertBestEffort(
      queue: _syncQueue,
      entityType: SyncEntityType.transaction,
      entityId: transaction.id,
      payload: payload,
      logger: _logger,
    );
  }
}

final class _TransferCreationOutcome {
  const _TransferCreationOutcome(this.transfer, {required this.createdNow});

  final CreatedTransfer transfer;
  final bool createdNow;
}

abstract final class _TransferCreationCoordinator {
  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<T> run<T>(String key, Future<T> Function() operation) async {
    final previous = _tails[key] ?? Future<void>.value();
    final completer = Completer<void>();
    _tails[key] = completer.future;
    try {
      try {
        await previous;
      } on Object {
        // A previous caller's result is independent; serialization continues.
      }
      return await operation();
    } finally {
      completer.complete();
      if (identical(_tails[key], completer.future)) {
        _tails.remove(key);
      }
    }
  }
}
