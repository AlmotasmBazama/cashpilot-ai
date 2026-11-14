import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../../finance_engine/finance_engine.dart'
    show
        FinanceException,
        FinanceTransactionDirection,
        FinanceValidationService,
        TransactionCommand,
        TransactionProcessor,
        TransferProcessor;
import '../../domain/entities/create_transfer_command.dart';
import '../../domain/entities/created_transfer.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/failures/transaction_failure_codes.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../../domain/services/transaction_status_transition_policy.dart';
import '../../domain/services/transaction_content_comparator.dart';
import '../../domain/services/transfer_creation_workflow.dart';
import '../../domain/services/transfer_pair_lifecycle.dart';
import '../datasources/local/transactions_local_data_source.dart';
import '../mappers/transaction_mapper.dart';
import '../services/local_transfer_creation_workflow.dart';
import '../services/local_transfer_pair_lifecycle.dart';

class TransactionsRepositoryImpl implements TransactionsRepository {
  const TransactionsRepositoryImpl({
    required TransactionsLocalDataSource localDataSource,
    required TransactionProcessor transactionProcessor,
    required TransferProcessor transferProcessor,
    required AppLogger logger,
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _transactionProcessor = transactionProcessor,
       _transferProcessor = transferProcessor,
       _logger = logger,
       _syncQueue = syncQueue;

  final TransactionsLocalDataSource _localDataSource;
  final TransactionProcessor _transactionProcessor;
  final TransferProcessor _transferProcessor;
  final AppLogger _logger;
  final SyncMutationQueue? _syncQueue;

  TransferCreationWorkflow get _transferCreationWorkflow =>
      LocalTransferCreationWorkflow(
        localDataSource: _localDataSource,
        transferProcessor: _transferProcessor,
        logger: _logger,
        syncQueue: _syncQueue,
      );

  TransferPairLifecycle get _transferPairLifecycle =>
      LocalTransferPairLifecycle(
        localDataSource: _localDataSource,
        transferProcessor: _transferProcessor,
      );

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    try {
      if (transaction.isTransfer || transaction.transferGroupId != null) {
        throw const AppException.validation(
          message: 'Transfer records must be created as a pair.',
          code: TransactionFailureCodes.transferCreationRequiresPair,
        );
      }
      if (transaction.status != TransactionStatus.pending &&
          transaction.status != TransactionStatus.posted) {
        throw const AppException.validation(
          message: 'A transaction must be created as pending or posted.',
          code: TransactionFailureCodes.invalidInitialStatus,
        );
      }

      final created = await _localDataSource.runInTransaction(() async {
        await _validateUnpostedTransaction(transaction);
        await _applyIfPosted(transaction);
        return _localDataSource.createTransaction(transaction.toDto());
      });

      final result = created.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to create transaction.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<CreatedTransfer>> createTransfer(
    CreateTransferCommand command,
  ) => _transferCreationWorkflow.create(command);

  @override
  Future<AppResult<void>> deleteTransaction(
    String id, {
    List<Transaction>? expectedCurrent,
  }) async {
    try {
      final deletedIds = await _localDataSource.runInTransaction(() async {
        final existing = await _requiredTransaction(id);
        await _assertExpectedCurrent(existing, expectedCurrent);

        if (existing.isTransfer || existing.transferGroupId != null) {
          return _transferPairLifecycle.deletePendingPair(existing);
        }

        await _reverseIfPosted(existing);
        await _localDataSource.deleteTransaction(id);
        return <String>[id];
      });

      for (final deletedId in deletedIds) {
        await enqueueSyncDeleteBestEffort(
          queue: _syncQueue,
          entityType: SyncEntityType.transaction,
          entityId: deletedId,
          logger: _logger,
        );
      }

      return const AppResult.success(null);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to delete transaction.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Transaction?>> getTransaction(String id) async {
    try {
      final transaction = await _localDataSource.getTransaction(id);
      return AppResult.success(transaction?.toDomain());
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load transaction.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Transaction>>> getTransactions({
    String? accountId,
    String? categoryId,
    String? payeeId,
    String? transferGroupId,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final transactions = await _localDataSource.getTransactions(
        accountId: accountId,
        categoryId: categoryId,
        payeeId: payeeId,
        transferGroupId: transferGroupId,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
      );

      return AppResult.success(
        transactions
            .map((transaction) => transaction.toDomain())
            .toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load transactions.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Transaction>>> searchTransactions(
    String query, {
    int? limit,
    Set<TransactionType>? transactionTypes,
    TransactionStatus? status,
  }) async {
    try {
      final transactions = await _localDataSource.searchTransactions(
        query,
        limit: limit,
        transactionTypes: transactionTypes,
        status: status,
      );
      return AppResult.success(
        transactions
            .map((transaction) => transaction.toDomain())
            .toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to search transactions.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Transaction>> updateTransaction(
    Transaction transaction, {
    Transaction? expectedCurrent,
  }) async {
    try {
      final updated = await _localDataSource.runInTransaction(() async {
        final existing = await _requiredTransaction(transaction.id);
        await _assertExpectedCurrent(
          existing,
          expectedCurrent == null ? null : <Transaction>[expectedCurrent],
        );

        if (existing.isTransfer ||
            transaction.isTransfer ||
            transaction.transferGroupId != null) {
          throw const AppException.validation(
            message:
                'Transfer records cannot be edited directly. Update the transfer pair instead.',
            code: TransactionFailureCodes.transferDirectEditNotAllowed,
          );
        }

        validateTransactionStatusTransition(
          existing.status,
          transaction.status,
        );
        await _validateUnpostedTransaction(transaction);
        await _reverseIfPosted(existing);
        await _applyIfPosted(transaction);
        return _localDataSource.updateTransaction(transaction.toDto());
      });

      final result = updated.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to update transaction.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Transaction>>> updateTransactionStatus(
    String id,
    TransactionStatus status, {
    List<Transaction>? expectedCurrent,
  }) async {
    try {
      final updated = await _localDataSource.runInTransaction(() async {
        final existing = await _requiredTransaction(id);
        await _assertExpectedCurrent(existing, expectedCurrent);
        if (existing.isTransfer || existing.transferGroupId != null) {
          return _transferPairLifecycle.updateStatus(existing, status);
        }

        validateTransactionStatusTransition(existing.status, status);
        if (existing.status == status) {
          return [existing];
        }

        if (existing.status == TransactionStatus.posted) {
          await _reverseIfPosted(existing);
        } else if (status == TransactionStatus.posted) {
          await _applyIfPosted(existing.copyWith(status: status));
        }

        final changed = existing.copyWith(
          status: status,
          updatedAt: DateTime.now().toUtc(),
        );
        final stored = await _localDataSource.updateTransaction(
          changed.toDto(),
        );
        return [stored.toDomain()];
      });

      for (final transaction in updated) {
        await _queueUpsert(transaction);
      }
      return AppResult.success(updated);
    } on Object catch (error, stackTrace) {
      return _failure(
        'Unable to update transaction status.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _assertExpectedCurrent(
    Transaction existing,
    List<Transaction>? expected,
  ) async {
    if (expected == null) return;
    final current = existing.transferGroupId == null
        ? <Transaction>[existing]
        : (await _localDataSource.getTransactions(
            transferGroupId: existing.transferGroupId,
          )).map((item) => item.toDomain()).toList(growable: false);
    if (current.length != expected.length) {
      throw const AppException.validation(
        message: 'The transaction changed after the preview was prepared.',
        code: TransactionFailureCodes.staleMutationTarget,
      );
    }
    final currentById = {for (final item in current) item.id: item};
    final matches = expected.every((item) {
      final currentItem = currentById[item.id];
      return currentItem != null && transactionContentEquals(currentItem, item);
    });
    if (!matches) {
      throw const AppException.validation(
        message: 'The transaction changed after the preview was prepared.',
        code: TransactionFailureCodes.staleMutationTarget,
      );
    }
  }

  Future<Transaction> _requiredTransaction(String id) async {
    final transaction = await _localDataSource.getTransaction(id);
    if (transaction == null) {
      throw StateError('Transaction not found: $id');
    }
    return transaction.toDomain();
  }

  Future<void> _applyIfPosted(Transaction transaction) async {
    if (!transaction.affectsBalance) return;
    await _transactionProcessor.process(
      TransactionCommand(
        accountId: transaction.accountId,
        amount: transaction.amount,
        direction: _directionFor(transaction.type),
        occurredAt: transaction.transactionDate,
      ),
    );
  }

  Future<void> _validateUnpostedTransaction(Transaction transaction) async {
    if (transaction.affectsBalance) return;
    // Posting validates through the Finance Engine. Pending records still
    // need valid money and an owned account, but must not reserve funds or
    // require today's balance to cover a future expense.
    const FinanceValidationService().validateAmount(transaction.amount);
    final account = await _localDataSource.getAccountBalanceSnapshot(
      transaction.accountId,
    );
    if (account == null) {
      throw FinanceException.accountNotFound(transaction.accountId);
    }
    if (account.currencyCode.toUpperCase() !=
        transaction.amount.normalizedCurrencyCode) {
      throw FinanceException.currencyMismatch(
        expectedCurrencyCode: account.currencyCode,
        actualCurrencyCode: transaction.amount.currencyCode,
      );
    }
  }

  Future<void> _reverseIfPosted(Transaction transaction) async {
    if (!transaction.affectsBalance) return;
    await _transactionProcessor.process(
      TransactionCommand(
        accountId: transaction.accountId,
        amount: transaction.amount,
        direction: _directionFor(transaction.type).opposite,
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }

  FinanceTransactionDirection _directionFor(TransactionType type) {
    return switch (type) {
      TransactionType.expense ||
      TransactionType.transferOut => FinanceTransactionDirection.debit,
      TransactionType.income ||
      TransactionType.transferIn => FinanceTransactionDirection.credit,
    };
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

extension on FinanceTransactionDirection {
  FinanceTransactionDirection get opposite {
    return switch (this) {
      FinanceTransactionDirection.debit => FinanceTransactionDirection.credit,
      FinanceTransactionDirection.credit => FinanceTransactionDirection.debit,
    };
  }
}
