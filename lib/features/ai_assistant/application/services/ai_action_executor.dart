import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../budgets/domain/usecases/create_budget.dart';
import '../../../goals/domain/usecases/add_goal_contribution.dart';
import '../../../goals/domain/usecases/create_goal.dart';
import '../../../transactions/domain/entities/create_transfer_command.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_source.dart';
import '../../../transactions/domain/usecases/create_transaction.dart';
import '../../../transactions/domain/usecases/create_transfer.dart';
import '../../../payees/domain/usecases/touch_payee_last_used.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_intent.dart';
import '../../domain/entities/ai_transaction_draft.dart';
import '../../domain/app_agent/app_agent_reconciliation.dart';
import '../../domain/services/ai_action_validator.dart';

abstract final class AiActionFailureCodes {
  static const confirmationRequired = 'ai_action_confirmation_required';
  static const alreadyExecuted = 'ai_action_already_executed';
  static const invalid = 'ai_action_invalid';
  static const destructiveBlocked = 'ai_action_destructive_blocked';
  static const invalidStatus = 'ai_action_invalid_status';
  static const executionFailed = 'ai_action_execution_failed';
}

class AiActionExecutionResult {
  const AiActionExecutionResult({
    required this.intent,
    required this.draft,
    this.transactionIds = const <String>[],
  });

  final AiIntent intent;
  final AiActionDraft draft;
  final List<String> transactionIds;
}

class AiActionExecutor {
  AiActionExecutor({
    required CreateTransaction createTransaction,
    required CreateTransfer createTransfer,
    required AiActionValidator validator,
    CreateBudget? createBudget,
    CreateGoalUseCase? createGoal,
    AddGoalContributionUseCase? addGoalContribution,
    TouchPayeeLastUsed? touchPayeeLastUsed,
  }) : _createTransaction = createTransaction,
       _createTransfer = createTransfer,
       _createBudget = createBudget,
       _createGoal = createGoal,
       _addGoalContribution = addGoalContribution,
       _validator = validator,
       _touchPayeeLastUsed = touchPayeeLastUsed;

  final CreateTransaction _createTransaction;
  final CreateTransfer _createTransfer;
  final CreateBudget? _createBudget;
  final CreateGoalUseCase? _createGoal;
  final AddGoalContributionUseCase? _addGoalContribution;
  final AiActionValidator _validator;
  final TouchPayeeLastUsed? _touchPayeeLastUsed;
  final Map<String, AiActionExecutionStatus> _statuses =
      <String, AiActionExecutionStatus>{};
  final Map<String, DateTime> _statusUpdatedAt = <String, DateTime>{};

  AiActionExecutionStatus statusFor(AiActionDraft draft) {
    return _statuses[draft.id] ?? draft.status;
  }

  AiActionDraft currentDraft(AiActionDraft draft) {
    return draft.copyWith(
      status: statusFor(draft),
      updatedAt: _statusUpdatedAt[draft.id] ?? draft.updatedAt,
    );
  }

  AiActionDraft cancel(AiActionDraft draft) {
    final status = statusFor(draft);
    if (status == AiActionExecutionStatus.executing ||
        status == AiActionExecutionStatus.executed) {
      return currentDraft(draft);
    }

    _setStatus(draft.id, AiActionExecutionStatus.cancelled);
    return currentDraft(draft);
  }

  Future<AppResult<AiActionExecutionResult>> execute(
    AiActionDraft draft, {
    required bool confirmed,
    AppAgentBusinessOperationSpec? businessOperation,
    void Function(AppAgentExecutionCrashPoint point)? executionCheckpoint,
  }) async {
    final action = draft.action;
    final currentStatus = statusFor(draft);
    if (currentStatus == AiActionExecutionStatus.executing ||
        currentStatus == AiActionExecutionStatus.executed) {
      return const AppResult.failure(
        Failure(
          message: 'This AI action has already been executed.',
          code: AiActionFailureCodes.alreadyExecuted,
        ),
      );
    }

    if (action.requiresConfirmation && !confirmed) {
      return const AppResult.failure(
        Failure(
          message: 'AI actions require confirmation before saving.',
          code: AiActionFailureCodes.confirmationRequired,
        ),
      );
    }

    final validation = _validator.validate(action);
    if (!validation.isValid) {
      _setStatus(draft.id, AiActionExecutionStatus.failed);
      return AppResult.failure(
        Failure(
          message: validation.message ?? 'AI action is invalid.',
          code: action is BlockedAiAction
              ? AiActionFailureCodes.destructiveBlocked
              : AiActionFailureCodes.invalid,
        ),
      );
    }

    if (!action.requiresConfirmation ||
        currentStatus != AiActionExecutionStatus.awaitingConfirmation) {
      return const AppResult.failure(
        Failure(
          message: 'AI action is not awaiting confirmation.',
          code: AiActionFailureCodes.invalidStatus,
        ),
      );
    }

    // This claim happens before the first await, so a second call with the same
    // draft id observes `executing` and cannot reach a financial use case.
    _setStatus(draft.id, AiActionExecutionStatus.executing);
    executionCheckpoint?.call(
      AppAgentExecutionCrashPoint.duringBusinessTransaction,
    );

    final AppResult<_AiActionExecutionPayload> result;
    try {
      result = await switch (action) {
        CreateExpenseDraft(:final transactionDraft) ||
        CreateIncomeDraft(:final transactionDraft) => _executeTransaction(
          action.intent,
          transactionDraft,
          businessOperation?.expectedPersistedIdentifiers.firstOrNull ??
              draft.id,
        ),
        CreateTransferDraft() => _executeTransfer(
          action,
          businessOperation?.expectedPersistedIdentifiers,
        ),
        CreateBudgetDraft() => _executeBudget(action),
        CreateGoalDraft() => _executeGoal(action),
        AddGoalContributionDraft() => _executeGoalContribution(action),
        CreateCategoryDraft() => Future.value(
          const AppResult<_AiActionExecutionPayload>.failure(
            Failure(message: 'AI category creation is not enabled yet.'),
          ),
        ),
        AskQuestionAction() ||
        CurrencyConversionAnswerAction() ||
        BudgetProgressAnswerAction() ||
        GoalProgressAnswerAction() ||
        ClarificationRequiredAction() ||
        UpdateTransactionDraft() ||
        DeleteTransactionDraft() ||
        UndoAiActionDraft() ||
        BlockedAiAction() => Future.value(
          const AppResult<_AiActionExecutionPayload>.failure(
            Failure(
              message: 'AI action is invalid.',
              code: AiActionFailureCodes.invalid,
            ),
          ),
        ),
      };
    } on AppAgentSimulatedProcessInterruption {
      rethrow;
    } on Object {
      _setStatus(draft.id, AiActionExecutionStatus.failed);
      return const AppResult.failure(
        Failure(
          message: 'Unable to execute AI action.',
          code: AiActionFailureCodes.executionFailed,
        ),
      );
    }

    return switch (result) {
      AppSuccess(:final data) => _complete(draft, data),
      AppFailure(:final failure) => _fail(draft, failure),
    };
  }

  Future<AppResult<_AiActionExecutionPayload>> _executeTransaction(
    AiIntent intent,
    AiTransactionDraft transactionDraft,
    String businessEntityId,
  ) async {
    final result = await _createTransaction(
      Transaction.create(
        id: businessEntityId,
        accountId: transactionDraft.account.id,
        categoryId: transactionDraft.category!.id,
        payeeId: transactionDraft.payee?.id,
        amount: transactionDraft.amount,
        type: transactionDraft.type,
        paymentMethod: transactionDraft.paymentMethod,
        source: TransactionSource.aiGenerated,
        status: transactionDraft.status,
        incomeSourceType: transactionDraft.incomeSourceSuggestion?.sourceType,
        note: transactionDraft.noteForPersistence,
        transactionDate: transactionDraft.transactionDate,
        aiConfidence: transactionDraft.incomeSourceSuggestion?.confidence ?? 90,
        needsReview: false,
      ),
    );

    return switch (result) {
      AppSuccess(:final data) => await _transactionSuccess(
        intent,
        transactionDraft,
        data.id,
      ),
      AppFailure(:final failure) => AppResult.failure(failure),
    };
  }

  Future<AppResult<_AiActionExecutionPayload>> _transactionSuccess(
    AiIntent intent,
    AiTransactionDraft draft,
    String transactionId,
  ) async {
    if (draft.payee case final payee?) {
      try {
        await _touchPayeeLastUsed?.call(payee.id, DateTime.now().toUtc());
      } on Object {
        // Usage metadata must not hide a transaction that already committed.
      }
    }
    return AppResult.success(
      _AiActionExecutionPayload(
        intent: intent,
        transactionIds: <String>[transactionId],
      ),
    );
  }

  Future<AppResult<_AiActionExecutionPayload>> _executeTransfer(
    CreateTransferDraft action,
    List<String>? expectedIdentifiers,
  ) async {
    final identifiers = expectedIdentifiers;
    final hasCorrelatedIdentifiers =
        identifiers != null && identifiers.length == 3;
    final result = await _createTransfer(
      CreateTransferCommand(
        sourceAccountId: action.sourceAccount.id,
        targetAccountId: action.destinationAccount.id,
        sourceAmount: action.sourceAmount,
        targetAmount: action.destinationAmount,
        exchangeRate: action.exchangeRate,
        source: TransactionSource.aiGenerated,
        note: action.note,
        transferGroupId: hasCorrelatedIdentifiers ? identifiers[0] : null,
        outgoingTransactionId: hasCorrelatedIdentifiers ? identifiers[1] : null,
        incomingTransactionId: hasCorrelatedIdentifiers ? identifiers[2] : null,
      ),
    );

    return switch (result) {
      AppSuccess(:final data) => AppResult.success(
        _AiActionExecutionPayload(
          intent: action.intent,
          transactionIds: <String>[
            data.outgoingTransaction.id,
            data.incomingTransaction.id,
          ],
        ),
      ),
      AppFailure(:final failure) => AppResult.failure(failure),
    };
  }

  Future<AppResult<_AiActionExecutionPayload>> _executeBudget(
    CreateBudgetDraft action,
  ) async {
    final createBudget = _createBudget;
    if (createBudget == null) {
      return const AppResult.failure(
        Failure(message: 'AI budget creation is not enabled.'),
      );
    }
    final result = await createBudget(action.budget);
    return switch (result) {
      AppSuccess() => AppResult.success(
        _AiActionExecutionPayload(
          intent: action.intent,
          transactionIds: const <String>[],
        ),
      ),
      AppFailure(:final failure) => AppResult.failure(failure),
    };
  }

  Future<AppResult<_AiActionExecutionPayload>> _executeGoal(
    CreateGoalDraft action,
  ) async {
    final createGoal = _createGoal;
    if (createGoal == null) {
      return const AppResult.failure(
        Failure(message: 'AI goal creation is not enabled.'),
      );
    }
    final result = await createGoal(action.goal);
    return switch (result) {
      AppSuccess() => AppResult.success(
        _AiActionExecutionPayload(
          intent: action.intent,
          transactionIds: const <String>[],
        ),
      ),
      AppFailure(:final failure) => AppResult.failure(failure),
    };
  }

  Future<AppResult<_AiActionExecutionPayload>> _executeGoalContribution(
    AddGoalContributionDraft action,
  ) async {
    final addContribution = _addGoalContribution;
    if (addContribution == null) {
      return const AppResult.failure(
        Failure(message: 'AI goal contributions are not enabled.'),
      );
    }
    final result = await addContribution(action.contribution);
    return switch (result) {
      AppSuccess() => AppResult.success(
        _AiActionExecutionPayload(
          intent: action.intent,
          transactionIds: const <String>[],
        ),
      ),
      AppFailure(:final failure) => AppResult.failure(failure),
    };
  }

  AppResult<AiActionExecutionResult> _complete(
    AiActionDraft draft,
    _AiActionExecutionPayload result,
  ) {
    _setStatus(draft.id, AiActionExecutionStatus.executed);
    return AppResult.success(
      AiActionExecutionResult(
        intent: result.intent,
        draft: currentDraft(draft),
        transactionIds: result.transactionIds,
      ),
    );
  }

  AppResult<AiActionExecutionResult> _fail(
    AiActionDraft draft,
    Failure failure,
  ) {
    _setStatus(draft.id, AiActionExecutionStatus.failed);
    return AppResult.failure(failure);
  }

  void _setStatus(String id, AiActionExecutionStatus status) {
    _statuses[id] = status;
    _statusUpdatedAt[id] = DateTime.now().toUtc();
  }
}

class _AiActionExecutionPayload {
  const _AiActionExecutionPayload({
    required this.intent,
    required this.transactionIds,
  });

  final AiIntent intent;
  final List<String> transactionIds;
}
