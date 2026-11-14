import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/services/transaction_content_comparator.dart';
import '../../../transactions/domain/usecases/create_transaction.dart';
import '../../../transactions/domain/usecases/delete_transaction.dart';
import '../../../transactions/domain/usecases/get_transaction.dart';
import '../../../transactions/domain/usecases/update_transaction.dart';
import '../../../transactions/domain/usecases/update_transaction_status.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_transaction_mutation_command.dart';

class AiTransactionMutationExecution {
  const AiTransactionMutationExecution({
    required this.affectedCount,
    required this.undoAvailable,
  });

  final int affectedCount;
  final bool undoAvailable;
}

/// Executes typed mutation actions exclusively through the same transaction
/// use cases used by manual UI. Every successful return is locally verified.
class AiTransactionMutationExecutor {
  const AiTransactionMutationExecutor({
    required UpdateTransaction updateTransaction,
    required DeleteTransaction deleteTransaction,
    required UpdateTransactionStatus updateTransactionStatus,
    required CreateTransaction createTransaction,
    required GetTransaction getTransaction,
  }) : _updateTransaction = updateTransaction,
       _deleteTransaction = deleteTransaction,
       _updateTransactionStatus = updateTransactionStatus,
       _createTransaction = createTransaction,
       _getTransaction = getTransaction;

  final UpdateTransaction _updateTransaction;
  final DeleteTransaction _deleteTransaction;
  final UpdateTransactionStatus _updateTransactionStatus;
  final CreateTransaction _createTransaction;
  final GetTransaction _getTransaction;

  Future<AppResult<AiTransactionMutationExecution>> execute(
    AiAction action,
  ) async {
    try {
      return switch (action) {
        UpdateTransactionDraft(:final command) => _update(command),
        DeleteTransactionDraft(:final command) => _delete(command),
        UndoAiActionDraft(:final command) => _undo(command),
        _ => const AppResult.failure(
          Failure(
            message: 'Unsupported transaction mutation.',
            code: 'ai_transaction_mutation_unsupported',
          ),
        ),
      };
    } on Object {
      return const AppResult.failure(
        Failure(
          message: 'The transaction mutation failed safely.',
          code: 'ai_transaction_mutation_failed',
        ),
      );
    }
  }

  Future<AppResult<AiTransactionMutationExecution>> _update(
    UpdateTransactionCommand command,
  ) async {
    final result = await _updateTransaction(
      command.updated.transaction,
      expectedCurrent: command.original.transaction,
    );
    if (result case AppFailure<Transaction>(:final failure)) {
      return AppResult.failure(failure);
    }
    final verified = await _isCurrent(command.updated.transaction);
    return verified
        ? const AppResult.success(
            AiTransactionMutationExecution(
              affectedCount: 1,
              undoAvailable: true,
            ),
          )
        : const AppResult.failure(
            Failure(
              message: 'The updated transaction could not be verified.',
              code: 'ai_transaction_mutation_verification_failed',
            ),
          );
  }

  Future<AppResult<AiTransactionMutationExecution>> _delete(
    DeleteTransactionCommand command,
  ) async {
    final expected = command.targets
        .map((target) => target.transaction)
        .toList(growable: false);
    switch (command.mode) {
      case AiTransactionDeleteMode.deletePending ||
          AiTransactionDeleteMode.reverseAndDeletePosted ||
          AiTransactionDeleteMode.deletePendingTransferPair:
        final result = await _deleteTransaction(
          expected.first.id,
          expectedCurrent: expected,
        );
        if (result case AppFailure<void>(:final failure)) {
          return AppResult.failure(failure);
        }
        for (final transaction in expected) {
          if (await _current(transaction.id) != null) {
            return const AppResult.failure(
              Failure(
                message: 'The deleted transaction could not be verified.',
                code: 'ai_transaction_mutation_verification_failed',
              ),
            );
          }
        }
      case AiTransactionDeleteMode.cancelPostedTransferPair:
        final result = await _updateTransactionStatus(
          expected.first.id,
          TransactionStatus.cancelled,
          expectedCurrent: expected,
        );
        if (result case AppFailure<List<Transaction>>(:final failure)) {
          return AppResult.failure(failure);
        }
        for (final transaction in expected) {
          final current = await _current(transaction.id);
          if (current?.status != TransactionStatus.cancelled) {
            return const AppResult.failure(
              Failure(
                message: 'The cancelled transfer could not be verified.',
                code: 'ai_transaction_mutation_verification_failed',
              ),
            );
          }
        }
    }
    return AppResult.success(
      AiTransactionMutationExecution(
        affectedCount: expected.length,
        undoAvailable: !expected.first.isTransfer,
      ),
    );
  }

  Future<AppResult<AiTransactionMutationExecution>> _undo(
    UndoAiActionCommand command,
  ) async {
    switch (command.operationType) {
      case AiUndoOperationType.undoCreateTransaction:
        final expected = command.after.single.transaction;
        final result = await _deleteTransaction(
          expected.id,
          expectedCurrent: <Transaction>[expected],
        );
        if (result case AppFailure<void>(:final failure)) {
          return AppResult.failure(failure);
        }
        if (await _current(expected.id) != null) return _undoVerificationFailed;
        return const AppResult.success(
          AiTransactionMutationExecution(
            affectedCount: 1,
            undoAvailable: false,
          ),
        );
      case AiUndoOperationType.undoCreateTransfer:
        final expected = command.after
            .map((item) => item.transaction)
            .toList(growable: false);
        final result = await _updateTransactionStatus(
          expected.first.id,
          TransactionStatus.cancelled,
          expectedCurrent: expected,
        );
        if (result case AppFailure<List<Transaction>>(:final failure)) {
          return AppResult.failure(failure);
        }
        for (final transaction in expected) {
          if ((await _current(transaction.id))?.status !=
              TransactionStatus.cancelled) {
            return _undoVerificationFailed;
          }
        }
        return AppResult.success(
          AiTransactionMutationExecution(
            affectedCount: expected.length,
            undoAvailable: false,
          ),
        );
      case AiUndoOperationType.undoUpdateTransaction:
        final before = command.before.single.transaction;
        final after = command.after.single.transaction;
        final result = await _updateTransaction(before, expectedCurrent: after);
        if (result case AppFailure<Transaction>(:final failure)) {
          return AppResult.failure(failure);
        }
        if (!await _isCurrent(before)) return _undoVerificationFailed;
        return const AppResult.success(
          AiTransactionMutationExecution(
            affectedCount: 1,
            undoAvailable: false,
          ),
        );
      case AiUndoOperationType.undoDeleteTransaction:
        final before = command.before.single.transaction;
        if (await _current(before.id) != null) return _undoVerificationFailed;
        final result = await _createTransaction(before);
        if (result case AppFailure<Transaction>(:final failure)) {
          return AppResult.failure(failure);
        }
        if (!await _isCurrent(before)) return _undoVerificationFailed;
        return const AppResult.success(
          AiTransactionMutationExecution(
            affectedCount: 1,
            undoAvailable: false,
          ),
        );
    }
  }

  Future<Transaction?> _current(String id) async {
    return switch (await _getTransaction(id)) {
      AppSuccess<Transaction?>(:final data) => data,
      AppFailure<Transaction?>() => null,
    };
  }

  Future<bool> _isCurrent(Transaction expected) async {
    final current = await _current(expected.id);
    return current != null && transactionContentEquals(current, expected);
  }

  static const _undoVerificationFailed =
      AppResult<AiTransactionMutationExecution>.failure(
        Failure(
          message: 'The undo result could not be verified.',
          code: 'ai_transaction_undo_verification_failed',
        ),
      );
}
