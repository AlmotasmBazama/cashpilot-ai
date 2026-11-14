import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/result.dart';
import '../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/domain/repositories/accounts_repository.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/domain/enums/budget_period_type.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/entities/goal_contribution.dart';
import '../../../goals/domain/enums/goal_status.dart';
import '../../../goals/domain/enums/goal_type.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../income_sources/domain/entities/income_source_suggestion.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../payees/domain/repositories/payees_repository.dart';
import '../../../transactions/domain/entities/create_transfer_command.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/repositories/transactions_repository.dart';
import '../../../transactions/domain/services/transaction_status_transition_policy.dart';
import '../../../transactions/domain/services/transaction_content_comparator.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../data/app_agent/drift_app_agent_stores.dart';
import '../../domain/app_agent/app_agent_contracts.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/app_agent/app_agent_reconciliation.dart';
import '../../domain/app_agent/canonical_app_tool_catalog.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_transaction_draft.dart';
import '../../domain/entities/ai_transaction_mutation_command.dart';
import '../services/ai_action_executor.dart';
import '../services/ai_transaction_mutation_executor.dart';
import 'app_agent_command_runtime.dart';

TransactionStatus? _transactionStatus(Object? value) {
  if (value == null) return TransactionStatus.posted;
  final normalized = value.toString().trim();
  return TransactionStatus.values
      .where(
        (status) =>
            status.name == normalized || status.storageValue == normalized,
      )
      .firstOrNull;
}

bool _samePersistedInstant(DateTime left, DateTime right) =>
    left.toUtc().millisecondsSinceEpoch ~/ 1000 ==
    right.toUtc().millisecondsSinceEpoch ~/ 1000;

class DurableAiActionResolver {
  const DurableAiActionResolver({
    required AccountsRepository accounts,
    required CategoriesRepository categories,
    required PayeesRepository payees,
    required BudgetRepository budgets,
    required GoalRepository goals,
    TransactionsRepository? transactions,
    AppAgentCommandStore? commandStore,
    AppAgentDurableExecutionStore? executionStore,
  }) : _accounts = accounts,
       _categories = categories,
       _payees = payees,
       _budgets = budgets,
       _goals = goals,
       _transactions = transactions,
       _commandStore = commandStore,
       _executionStore = executionStore;

  final AccountsRepository _accounts;
  final CategoriesRepository _categories;
  final PayeesRepository _payees;
  final BudgetRepository _budgets;
  final GoalRepository _goals;
  final TransactionsRepository? _transactions;
  final AppAgentCommandStore? _commandStore;
  final AppAgentDurableExecutionStore? _executionStore;

  Future<_ResolvedAiAction?> _resolve(AppAgentCommand command) async {
    try {
      final args = command.normalizedArguments;
      final action = switch (command.toolId) {
        'createExpenseDraft' ||
        'createIncomeDraft' => await _resolveTransaction(command.toolId, args),
        'createTransferDraft' => await _resolveTransfer(args),
        'createBudgetDraft' => await _resolveBudget(args),
        'createGoalDraft' => await _resolveGoal(args),
        'createGoalContributionDraft' => await _resolveContribution(args),
        'updateTransactionDraft' => await _resolveUpdate(command, args),
        'deleteTransactionDraft' => await _resolveDelete(command, args),
        'undoAiAction' => await _resolveUndo(command, args),
        _ => null,
      };
      if (action == null) return null;
      final fingerprint = _fingerprint(
        command.normalizedArguments,
        action.referenceRevisions,
      );
      return _ResolvedAiAction(action.action, fingerprint);
    } on Object {
      return null;
    }
  }

  Future<_ActionAndRevisions?> _resolveTransaction(
    String toolId,
    Map<String, Object?> args,
  ) async {
    final account = await _account(args['accountId']);
    final category = await _category(args['categoryId']);
    final payee = await _payee(args['payeeId']);
    if (account == null ||
        account.isArchived ||
        category == null ||
        category.isArchived ||
        (args['payeeId'] != null && payee == null)) {
      return null;
    }
    final amount = Decimal.tryParse(args['amount']?.toString() ?? '');
    final currency = args['currency']?.toString();
    final type = TransactionType.values
        .where((value) => value.name == args['transactionType'])
        .firstOrNull;
    final paymentMethod = PaymentMethod.values
        .where((value) => value.name == args['paymentMethod'])
        .firstOrNull;
    final status = _transactionStatus(args['status']);
    if (amount == null ||
        currency == null ||
        type == null ||
        paymentMethod == null ||
        status == null ||
        (status != TransactionStatus.pending &&
            status != TransactionStatus.posted)) {
      return null;
    }
    final incomeType = IncomeSourceTypeMapper.tryFromStorage(
      args['incomeSourceType']?.toString(),
    );
    final hasInvalidIncomeType =
        args['incomeSourceType'] != null && incomeType == null;
    final hasMismatchedTransactionType =
        (toolId == 'createIncomeDraft' && type != TransactionType.income) ||
        (toolId == 'createExpenseDraft' && type != TransactionType.expense);
    if (hasInvalidIncomeType || hasMismatchedTransactionType) {
      return null;
    }
    final transactionDate = DateTime.tryParse(
      args['transactionDate']?.toString() ?? '',
    );
    final sourceIdentity = args['incomeSourceIdentity']?.toString().trim();
    final transactionDraft = AiTransactionDraft(
      type: type,
      amount: Money(amount: amount, currencyCode: currency),
      account: account,
      category: category,
      paymentMethod: paymentMethod,
      paymentMethodDefinition: null,
      note: args['note']?.toString() ?? '',
      payee: payee,
      payeeHint: sourceIdentity?.isEmpty == true ? null : sourceIdentity,
      transactionDate: transactionDate,
      status: status,
      incomeSourceSuggestion: incomeType == null
          ? null
          : IncomeSourceSuggestion(
              sourceType: incomeType,
              sourceNameHint: sourceIdentity?.isEmpty == true
                  ? null
                  : sourceIdentity,
              sourcePayeeId: payee?.id,
              destinationAccountId: account.id,
              transactionDate: transactionDate,
              confidence: 100,
              source: IncomeSourceSuggestionSource.explicitUserInput,
              requiresClarification: false,
            ),
    );
    final action = toolId == 'createIncomeDraft'
        ? CreateIncomeDraft(transactionDraft)
        : CreateExpenseDraft(transactionDraft);
    return _ActionAndRevisions(action, <String>[
      'account:${account.id}:${account.updatedAt.toUtc().toIso8601String()}:${account.isArchived}',
      'category:${category.id}:${category.updatedAt.toUtc().toIso8601String()}:${category.isArchived}',
      if (payee != null)
        'payee:${payee.id}:${payee.updatedAt.toUtc().toIso8601String()}:${payee.isArchived}',
    ]);
  }

  Future<_ActionAndRevisions?> _resolveTransfer(
    Map<String, Object?> args,
  ) async {
    final source = await _account(args['sourceAccountId']);
    final destination = await _account(args['destinationAccountId']);
    final amount = Decimal.tryParse(args['sourceAmount']?.toString() ?? '');
    final currency = args['sourceCurrency']?.toString();
    if (source == null ||
        destination == null ||
        source.isArchived ||
        destination.isArchived ||
        source.id == destination.id ||
        amount == null ||
        currency == null) {
      return null;
    }
    final destinationAmount = Decimal.tryParse(
      args['destinationAmount']?.toString() ?? '',
    );
    final destinationCurrency = args['destinationCurrency']?.toString();
    final rate = Decimal.tryParse(args['exchangeRate']?.toString() ?? '');
    final action = CreateTransferDraft(
      sourceAccount: source,
      destinationAccount: destination,
      sourceAmount: Money(amount: amount, currencyCode: currency),
      destinationAmount:
          destinationAmount == null || destinationCurrency == null
          ? null
          : Money(amount: destinationAmount, currencyCode: destinationCurrency),
      exchangeRate: rate == null
          ? null
          : ExchangeRate(
              fromCurrencyCode: currency,
              toCurrencyCode: destinationCurrency ?? destination.currencyCode,
              rate: rate,
              asOf: DateTime.tryParse(
                args['exchangeRateAsOf']?.toString() ?? '',
              ),
            ),
      note: args['note']?.toString(),
    );
    return _ActionAndRevisions(action, <String>[
      'source:${source.id}:${source.updatedAt.toUtc().toIso8601String()}:${source.balance}',
      'destination:${destination.id}:${destination.updatedAt.toUtc().toIso8601String()}:${destination.balance}',
    ]);
  }

  Future<_ActionAndRevisions?> _resolveBudget(Map<String, Object?> args) async {
    final json = _stringMap(args['budget']);
    if (json == null) return null;
    final budget = Budget.fromJson(json);
    final category = await _category(budget.categoryId);
    final existing = await _success(_budgets.getBudgetById(budget.id));
    if (category == null || category.isArchived || existing != null) {
      return null;
    }
    return _ActionAndRevisions(
      CreateBudgetDraft(budget: budget, category: category),
      <String>[
        'category:${category.id}:${category.updatedAt.toUtc().toIso8601String()}:${category.isArchived}',
        'budget-new:${budget.id}',
      ],
    );
  }

  Future<_ActionAndRevisions?> _resolveGoal(Map<String, Object?> args) async {
    final json = _stringMap(args['goal']);
    if (json == null) return null;
    final goal = Goal.fromJson(json);
    final existing = await _success(_goals.getGoalById(goal.id));
    if (existing != null) return null;
    Account? linked;
    if (goal.linkedAccountId != null) {
      linked = await _account(goal.linkedAccountId);
      if (linked == null || linked.isArchived) {
        return null;
      }
    }
    return _ActionAndRevisions(CreateGoalDraft(goal: goal), <String>[
      'goal-new:${goal.id}',
      if (linked != null)
        'account:${linked.id}:${linked.updatedAt.toUtc().toIso8601String()}:${linked.isArchived}',
    ]);
  }

  Future<_ActionAndRevisions?> _resolveContribution(
    Map<String, Object?> args,
  ) async {
    final json = _stringMap(args['contribution']);
    if (json == null) return null;
    final contribution = GoalContribution.fromJson(json);
    final goal = await _success(_goals.getGoalById(contribution.goalId));
    if (goal == null || goal.isArchived) return null;
    final existingContributions = switch (await _goals
        .watchGoalContributions(contribution.goalId)
        .first) {
      AppSuccess<List<GoalContribution>>(:final data) => data,
      AppFailure<List<GoalContribution>>() => null,
    };
    if (existingContributions == null ||
        existingContributions.any((item) => item.id == contribution.id)) {
      return null;
    }
    return _ActionAndRevisions(
      AddGoalContributionDraft(goal: goal, contribution: contribution),
      <String>[
        'goal:${goal.id}:${goal.updatedAt.toUtc().toIso8601String()}:${goal.currentAmount}:${goal.status.name}',
        'contribution-new:${contribution.id}',
      ],
    );
  }

  Future<_ActionAndRevisions?> _resolveUpdate(
    AppAgentCommand durableCommand,
    Map<String, Object?> args,
  ) async {
    final transactions = _transactions;
    final command = UpdateTransactionCommand.fromArguments(args);
    if (transactions == null ||
        command == null ||
        command.commandId != durableCommand.commandId ||
        !_samePersistedInstant(command.createdAt, durableCommand.createdAt) ||
        !_samePersistedInstant(command.expiresAt, durableCommand.expiresAt)) {
      return null;
    }
    final original = command.original.transaction;
    final updated = command.updated.transaction;
    final current = await _transaction(original.id);
    if (current == null ||
        !_sameTransaction(current, original) ||
        original.id != updated.id ||
        original.type != updated.type ||
        original.isTransfer ||
        updated.isTransfer ||
        original.transferGroupId != updated.transferGroupId ||
        updated.amount.amount <= Decimal.zero ||
        updated.status == TransactionStatus.cancelled ||
        updated.status == TransactionStatus.failed) {
      return null;
    }
    try {
      validateTransactionStatusTransition(original.status, updated.status);
    } on Object {
      return null;
    }
    final account = await _account(updated.accountId);
    final category = await _category(updated.categoryId);
    final payee = await _payee(updated.payeeId);
    final expectedCategoryType = updated.type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    if (account == null ||
        account.isArchived ||
        category == null ||
        category.isArchived ||
        category.type != expectedCategoryType ||
        account.currencyCode.toUpperCase() !=
            updated.amount.currencyCode.toUpperCase() ||
        (updated.payeeId != null && (payee == null || payee.isArchived))) {
      return null;
    }
    return _ActionAndRevisions(UpdateTransactionDraft(command: command), <
      String
    >[
      'target:${_transactionDigest(current)}',
      'account:${account.id}:${account.updatedAt.toUtc().toIso8601String()}:${account.isArchived}',
      'category:${category.id}:${category.updatedAt.toUtc().toIso8601String()}:${category.isArchived}',
      if (payee != null)
        'payee:${payee.id}:${payee.updatedAt.toUtc().toIso8601String()}:${payee.isArchived}',
    ]);
  }

  Future<_ActionAndRevisions?> _resolveDelete(
    AppAgentCommand durableCommand,
    Map<String, Object?> args,
  ) async {
    final command = DeleteTransactionCommand.fromArguments(args);
    if (_transactions == null ||
        command == null ||
        command.commandId != durableCommand.commandId ||
        !_samePersistedInstant(command.createdAt, durableCommand.createdAt) ||
        !_samePersistedInstant(command.expiresAt, durableCommand.expiresAt) ||
        command.targets.length > 2) {
      return null;
    }
    final current = <Transaction>[];
    for (final target in command.targets) {
      final transaction = await _transaction(target.transaction.id);
      if (transaction == null ||
          !_sameTransaction(transaction, target.transaction)) {
        return null;
      }
      if (await _account(transaction.accountId) == null ||
          await _category(transaction.categoryId) == null ||
          (transaction.payeeId != null &&
              await _payee(transaction.payeeId) == null)) {
        return null;
      }
      current.add(transaction);
    }
    final pairMode =
        command.mode == AiTransactionDeleteMode.deletePendingTransferPair ||
        command.mode == AiTransactionDeleteMode.cancelPostedTransferPair;
    if (pairMode) {
      final groupIds = current.map((item) => item.transferGroupId).toSet();
      if (current.length != 2 ||
          groupIds.length != 1 ||
          groupIds.single == null ||
          current
                  .where((item) => item.type == TransactionType.transferOut)
                  .length !=
              1 ||
          current
                  .where((item) => item.type == TransactionType.transferIn)
                  .length !=
              1) {
        return null;
      }
    } else if (current.length != 1 || current.single.isTransfer) {
      return null;
    }
    return _ActionAndRevisions(
      DeleteTransactionDraft(command: command),
      current.map((item) => 'target:${_transactionDigest(item)}').toList(),
    );
  }

  Future<_ActionAndRevisions?> _resolveUndo(
    AppAgentCommand durableCommand,
    Map<String, Object?> args,
  ) async {
    final command = UndoAiActionCommand.fromArguments(args);
    final commandStore = _commandStore;
    final executionStore = _executionStore;
    if (_transactions == null ||
        commandStore == null ||
        executionStore == null ||
        command == null ||
        command.commandId != durableCommand.commandId ||
        !_samePersistedInstant(command.createdAt, durableCommand.createdAt) ||
        !_samePersistedInstant(command.expiresAt, durableCommand.expiresAt)) {
      return null;
    }
    final source = await commandStore.readCommand(
      commandId: command.sourceCommandId,
      accountScope: durableCommand.userAccountScope,
    );
    final sourceResult = await executionStore.readVerifiedResult(
      command.sourceCommandId,
    );
    if (source == null ||
        source.userAccountScope != durableCommand.userAccountScope ||
        source.toolId != command.sourceToolId ||
        source.revision != command.sourceOperationRevision ||
        source.status != AppAgentCommandStatus.succeeded ||
        sourceResult == null ||
        !sourceResult.verified ||
        !sourceResult.undoAvailable) {
      return null;
    }
    final scopedCommands = await commandStore.readCommandsForScope(
      durableCommand.userAccountScope,
    );
    final competingUndo = scopedCommands.any(
      (item) =>
          item.commandId != durableCommand.commandId &&
          item.toolId == 'undoAiAction' &&
          item.normalizedArguments['sourceCommandId'] ==
              command.sourceCommandId &&
          (item.status == AppAgentCommandStatus.confirmed ||
              item.status == AppAgentCommandStatus.executing ||
              item.status == AppAgentCommandStatus.succeeded),
    );
    if (competingUndo) return null;

    final expectedPresent = switch (command.operationType) {
      AiUndoOperationType.undoCreateTransaction ||
      AiUndoOperationType.undoCreateTransfer ||
      AiUndoOperationType.undoUpdateTransaction => command.after,
      AiUndoOperationType.undoDeleteTransaction =>
        const <AiTransactionTargetSnapshot>[],
    };
    for (final snapshot in expectedPresent) {
      final current = await _transaction(snapshot.transaction.id);
      if (current == null || !_sameTransaction(current, snapshot.transaction)) {
        return null;
      }
    }
    if (command.operationType == AiUndoOperationType.undoDeleteTransaction) {
      for (final snapshot in command.before) {
        if (await _transaction(snapshot.transaction.id) != null ||
            snapshot.transaction.isTransfer) {
          return null;
        }
        if (await _account(snapshot.transaction.accountId) == null ||
            await _category(snapshot.transaction.categoryId) == null) {
          return null;
        }
      }
    }
    return _ActionAndRevisions(UndoAiActionDraft(command: command), <String>[
      'source:${source.commandId}:${source.revision}:${source.status.name}',
      for (final item in expectedPresent)
        'target:${_transactionDigest(item.transaction)}',
      for (final item in command.before)
        if (command.operationType == AiUndoOperationType.undoDeleteTransaction)
          'restore-absent:${item.transaction.id}',
    ]);
  }

  Future<Transaction?> _transaction(String id) async {
    final transactions = _transactions;
    if (transactions == null) return null;
    return _success(transactions.getTransaction(id));
  }

  bool _sameTransaction(Transaction left, Transaction right) =>
      transactionContentEquals(left, right);

  String _transactionDigest(Transaction transaction) => sha256
      .convert(utf8.encode(canonicalTransactionJson(transaction)))
      .toString();

  Future<_MutationBusinessState> _mutationBusinessState(AiAction action) async {
    return switch (action) {
      UpdateTransactionDraft(:final command) => _stateForUpdate(command),
      DeleteTransactionDraft(:final command) => _stateForDelete(command),
      UndoAiActionDraft(:final command) => _stateForUndo(command),
      _ => Future.value(_MutationBusinessState.inconsistent),
    };
  }

  Future<_MutationBusinessState> _stateForUpdate(
    UpdateTransactionCommand command,
  ) async {
    final current = await _transaction(command.updated.transaction.id);
    if (current == null) return _MutationBusinessState.inconsistent;
    if (_sameTransaction(current, command.updated.transaction)) {
      return _MutationBusinessState.succeeded;
    }
    return _sameTransaction(current, command.original.transaction)
        ? _MutationBusinessState.notExecuted
        : _MutationBusinessState.inconsistent;
  }

  Future<_MutationBusinessState> _stateForDelete(
    DeleteTransactionCommand command,
  ) async {
    final current = <Transaction?>[];
    for (final target in command.targets) {
      current.add(await _transaction(target.transaction.id));
    }
    if (command.mode == AiTransactionDeleteMode.cancelPostedTransferPair) {
      if (current.every(
        (item) => item?.status == TransactionStatus.cancelled,
      )) {
        return _MutationBusinessState.succeeded;
      }
    } else if (current.every((item) => item == null)) {
      return _MutationBusinessState.succeeded;
    }
    final untouched = List<int>.generate(current.length, (index) => index)
        .every(
          (index) =>
              current[index] != null &&
              _sameTransaction(
                current[index]!,
                command.targets[index].transaction,
              ),
        );
    return untouched
        ? _MutationBusinessState.notExecuted
        : _MutationBusinessState.inconsistent;
  }

  Future<_MutationBusinessState> _stateForUndo(
    UndoAiActionCommand command,
  ) async {
    switch (command.operationType) {
      case AiUndoOperationType.undoCreateTransaction:
        final current = await _transaction(command.after.single.transaction.id);
        if (current == null) return _MutationBusinessState.succeeded;
        return _sameTransaction(current, command.after.single.transaction)
            ? _MutationBusinessState.notExecuted
            : _MutationBusinessState.inconsistent;
      case AiUndoOperationType.undoCreateTransfer:
        final current = <Transaction?>[];
        for (final target in command.after) {
          current.add(await _transaction(target.transaction.id));
        }
        if (current.every(
          (item) => item?.status == TransactionStatus.cancelled,
        )) {
          return _MutationBusinessState.succeeded;
        }
        final untouched = List<int>.generate(current.length, (index) => index)
            .every(
              (index) =>
                  current[index] != null &&
                  _sameTransaction(
                    current[index]!,
                    command.after[index].transaction,
                  ),
            );
        return untouched
            ? _MutationBusinessState.notExecuted
            : _MutationBusinessState.inconsistent;
      case AiUndoOperationType.undoUpdateTransaction:
        final current = await _transaction(
          command.before.single.transaction.id,
        );
        if (current == null) return _MutationBusinessState.inconsistent;
        if (_sameTransaction(current, command.before.single.transaction)) {
          return _MutationBusinessState.succeeded;
        }
        return _sameTransaction(current, command.after.single.transaction)
            ? _MutationBusinessState.notExecuted
            : _MutationBusinessState.inconsistent;
      case AiUndoOperationType.undoDeleteTransaction:
        final current = await _transaction(
          command.before.single.transaction.id,
        );
        if (current == null) return _MutationBusinessState.notExecuted;
        return _sameTransaction(current, command.before.single.transaction)
            ? _MutationBusinessState.succeeded
            : _MutationBusinessState.inconsistent;
    }
  }

  Future<Account?> _account(Object? id) async {
    if (id is! String || id.trim().isEmpty) return null;
    return _success(_accounts.getAccountById(id));
  }

  Future<Category?> _category(Object? id) async {
    if (id is! String || id.trim().isEmpty) return null;
    return _success(_categories.getCategoryById(id));
  }

  Future<Payee?> _payee(Object? id) async {
    if (id == null) return null;
    if (id is! String || id.trim().isEmpty) return null;
    return _success(_payees.getPayeeById(id));
  }

  Future<T?> _success<T>(Future<AppResult<T?>> future) async {
    return switch (await future) {
      AppSuccess<T?>(:final data) => data,
      AppFailure<T?>() => null,
    };
  }

  Map<String, dynamic>? _stringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  String _fingerprint(Map<String, Object?> args, List<String> revisions) {
    return sha256
        .convert(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'arguments': args,
              'revisions': revisions,
            }),
          ),
        )
        .toString();
  }
}

class ProductionFinancialCommandHandler
    implements
        AppAgentReconciliableCommandHandler,
        AppAgentFaultAwareCommandHandler {
  const ProductionFinancialCommandHandler({
    required this.toolId,
    required this.risk,
    required DurableAiActionResolver resolver,
    required AiActionExecutor executor,
    AiTransactionMutationExecutor? mutationExecutor,
    required ScopedAppDatabaseSession session,
  }) : _resolver = resolver,
       _executor = executor,
       _mutationExecutor = mutationExecutor,
       _session = session;

  const ProductionFinancialCommandHandler.reconciliationOnly({
    required this.toolId,
    required this.risk,
    required ScopedAppDatabaseSession session,
  }) : _resolver = null,
       _executor = null,
       _mutationExecutor = null,
       _session = session;

  @override
  final String toolId;

  @override
  final AgentActionRisk risk;

  final DurableAiActionResolver? _resolver;
  final AiActionExecutor? _executor;
  final AiTransactionMutationExecutor? _mutationExecutor;
  final ScopedAppDatabaseSession _session;

  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  AgentPermission get permission => switch (toolId) {
    'updateTransactionDraft' || 'undoAiAction' => AgentPermission.updateDraft,
    'deleteTransactionDraft' => AgentPermission.archiveDraft,
    _ => AgentPermission.createDraft,
  };

  @override
  AppAgentBusinessOperationSpec businessOperationFor(AppAgentCommand command) {
    final expectedIds = switch (command.toolId) {
      'createExpenseDraft' || 'createIncomeDraft' => <String>[
        AppAgentBusinessIdentifiers.transactionId(command),
      ],
      'createTransferDraft' => <String>[
        AppAgentBusinessIdentifiers.transferGroupId(command),
        AppAgentBusinessIdentifiers.transferOutgoingId(command),
        AppAgentBusinessIdentifiers.transferIncomingId(command),
      ],
      'createBudgetDraft' => <String>[_nestedId(command, 'budget')],
      'createGoalDraft' => <String>[_nestedId(command, 'goal')],
      'createGoalContributionDraft' => <String>[
        _nestedId(command, 'contribution'),
      ],
      'updateTransactionDraft' => <String>[
        _transactionIdFromSnapshot(command.normalizedArguments['updated']),
      ],
      'deleteTransactionDraft' => _transactionIdsFromSnapshots(
        command.normalizedArguments['targets'],
      ),
      'undoAiAction' => _undoExpectedIds(command.normalizedArguments),
      _ => const <String>[],
    };
    if (expectedIds.isEmpty || expectedIds.any((id) => id.isEmpty)) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.invalidArguments,
        'The command does not define a verifiable business operation.',
      );
    }
    return AppAgentBusinessOperationSpec(
      key: AppAgentBusinessIdentifiers.operationKey(command),
      expectedEntityType: _entityType(command.toolId),
      expectedPersistedIdentifiers: expectedIds,
      verificationMethod: switch (command.toolId) {
        'createTransferDraft' => 'scoped_atomic_transfer_pair_v1',
        'updateTransactionDraft' => 'scoped_stale_safe_update_v1',
        'deleteTransactionDraft' => 'scoped_safe_delete_or_cancel_v1',
        'undoAiAction' => 'scoped_one_time_inverse_operation_v1',
        _ => 'scoped_entity_identity_and_fields_v1',
      },
      safeAutomaticResume: false,
      automaticRetryProhibited: true,
    );
  }

  @override
  Future<AppAgentReconciliationResult> reconcileBusinessOperation(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    if (command.userAccountScope != _scope ||
        command.toolId != toolId ||
        command.permission != permission ||
        command.risk != risk ||
        receipt.commandId != command.commandId ||
        receipt.commandRevision != command.revision) {
      return _reconciliation(
        AppAgentReconciliationStatus.inconsistent,
        command,
        AppAgentFailureCodes.accountScopeMismatch,
      );
    }
    try {
      if (!_sameBusinessOperation(
        receipt.operation,
        businessOperationFor(command),
      )) {
        return _inconsistent(command);
      }
      return switch (command.toolId) {
        'createExpenseDraft' ||
        'createIncomeDraft' => await _reconcileTransaction(command, receipt),
        'createTransferDraft' => await _reconcileTransfer(command, receipt),
        'createBudgetDraft' => await _reconcileBudget(command, receipt),
        'createGoalDraft' => await _reconcileGoal(command, receipt),
        'createGoalContributionDraft' => await _reconcileContribution(
          command,
          receipt,
        ),
        'updateTransactionDraft' ||
        'deleteTransactionDraft' ||
        'undoAiAction' => await _reconcileMutation(command),
        _ => _reconciliation(
          AppAgentReconciliationStatus.requiresManualReview,
          command,
          AppAgentFailureCodes.recoveryManualReview,
        ),
      };
    } on Object {
      return _reconciliation(
        AppAgentReconciliationStatus.requiresManualReview,
        command,
        AppAgentFailureCodes.recoveryManualReview,
      );
    }
  }

  Future<AppAgentReconciliationResult> _reconcileTransaction(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    final id = receipt.operation.expectedPersistedIdentifiers.single;
    final row =
        await (_database.select(_database.transactions)..where(
              (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
            ))
            .getSingleOrNull();
    if (row == null) return _notExecuted(command);
    final args = command.normalizedArguments;
    final expectedTransactionDate = _dateTime(args['transactionDate']);
    final expectedStatus = _transactionStatus(args['status']);
    if (expectedStatus == null ||
        (expectedStatus != TransactionStatus.pending &&
            expectedStatus != TransactionStatus.posted) ||
        (command.toolId == 'createIncomeDraft' &&
            expectedTransactionDate == null)) {
      return _inconsistent(command);
    }
    final expectedIncomeSourceArgument = args['incomeSourceType']?.toString();
    final expectedIncomeSource = expectedIncomeSourceArgument == null
        ? null
        : IncomeSourceTypeMapper.tryFromStorage(
            expectedIncomeSourceArgument,
          )?.storageValue;
    if (expectedIncomeSourceArgument != null && expectedIncomeSource == null) {
      return _inconsistent(command);
    }
    final valid =
        row.type == args['transactionType'] &&
        row.accountId == args['accountId'] &&
        row.categoryId == args['categoryId'] &&
        row.payeeId == args['payeeId'] &&
        row.amount == args['amount'] &&
        row.currencyCode == args['currency'] &&
        row.paymentMethod == args['paymentMethod'] &&
        row.source == 'aiGenerated' &&
        row.status == expectedStatus.storageValue &&
        row.incomeSourceType == expectedIncomeSource &&
        row.transferGroupId == null &&
        row.exchangeRateFromCurrencyCode == null &&
        row.exchangeRateToCurrencyCode == null &&
        row.exchangeRate == null &&
        row.exchangeRateAsOf == null &&
        row.note == args['note']?.toString() &&
        (expectedTransactionDate == null ||
            row.transactionDate.toUtc() == expectedTransactionDate) &&
        row.location == null &&
        row.attachmentCount == 0 &&
        row.aiConfidence == (expectedIncomeSource == null ? 90 : 100) &&
        !row.needsReview;
    return valid ? _succeeded(command) : _inconsistent(command);
  }

  Future<AppAgentReconciliationResult> _reconcileTransfer(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    final ids = receipt.operation.expectedPersistedIdentifiers;
    if (ids.length != 3) return _inconsistent(command);
    final groupId = ids[0];
    final transactionIds = ids.skip(1).toList(growable: false);
    final rows =
        await (_database.select(_database.transactions)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) & row.id.isIn(transactionIds),
            ))
            .get();
    if (rows.isEmpty) return _notExecuted(command);
    if (rows.length != 2 ||
        rows.any((row) => row.transferGroupId != groupId) ||
        rows.where((row) => row.type == 'transferOut').length != 1 ||
        rows.where((row) => row.type == 'transferIn').length != 1 ||
        rows.any(
          (row) =>
              row.source != 'aiGenerated' ||
              row.status != 'posted' ||
              row.paymentMethod != 'bankTransfer' ||
              row.categoryId != defaultTransferCategoryId ||
              row.payeeId != null ||
              row.incomeSourceType != null ||
              row.location != null ||
              row.attachmentCount != 0 ||
              row.aiConfidence != null ||
              row.needsReview,
        )) {
      return _inconsistent(command);
    }
    final outgoing = rows.singleWhere((row) => row.type == 'transferOut');
    final incoming = rows.singleWhere((row) => row.type == 'transferIn');
    final args = command.normalizedArguments;
    final expectedRate = Decimal.tryParse(
      args['exchangeRate']?.toString() ?? '',
    );
    final expectedRateAsOf = _dateTime(args['exchangeRateAsOf']);
    final sourceAmount = Decimal.tryParse(outgoing.amount);
    final destinationAmount = Decimal.tryParse(incoming.amount);
    final outgoingRate = Decimal.tryParse(outgoing.exchangeRate ?? '');
    final incomingRate = Decimal.tryParse(incoming.exchangeRate ?? '');
    final occurredAt = outgoing.transactionDate.toUtc();
    final fingerprintsAreBound =
        outgoing.transferPayloadFingerprint != null &&
        outgoing.transferPayloadFingerprint ==
            incoming.transferPayloadFingerprint &&
        RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(outgoing.transferPayloadFingerprint!);
    if (outgoing.id != ids[1] ||
        incoming.id != ids[2] ||
        outgoing.accountId != args['sourceAccountId'] ||
        incoming.accountId != args['destinationAccountId'] ||
        outgoing.amount != args['sourceAmount'] ||
        incoming.amount != args['destinationAmount'] ||
        outgoing.currencyCode != args['sourceCurrency'] ||
        incoming.currencyCode != args['destinationCurrency'] ||
        sourceAmount == null ||
        destinationAmount == null ||
        sourceAmount <= Decimal.zero ||
        destinationAmount <= Decimal.zero ||
        outgoingRate == null ||
        incomingRate == null ||
        outgoingRate <= Decimal.zero ||
        outgoingRate != incomingRate ||
        outgoing.exchangeRateFromCurrencyCode != args['sourceCurrency'] ||
        incoming.exchangeRateFromCurrencyCode != args['sourceCurrency'] ||
        outgoing.exchangeRateToCurrencyCode != args['destinationCurrency'] ||
        incoming.exchangeRateToCurrencyCode != args['destinationCurrency'] ||
        (expectedRate != null && outgoingRate != expectedRate) ||
        outgoing.exchangeRateAsOf?.toUtc() !=
            incoming.exchangeRateAsOf?.toUtc() ||
        (expectedRateAsOf != null &&
            outgoing.exchangeRateAsOf?.toUtc() != expectedRateAsOf) ||
        outgoing.note != args['note']?.toString() ||
        incoming.note != args['note']?.toString() ||
        incoming.transactionDate.toUtc() != occurredAt ||
        occurredAt.isBefore(receipt.claimedAt.toUtc()) ||
        occurredAt.isAfter(command.expiresAt.toUtc()) ||
        !fingerprintsAreBound) {
      return _inconsistent(command);
    }
    return _succeeded(command, affectedCount: 2);
  }

  Future<AppAgentReconciliationResult> _reconcileBudget(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    final row =
        await (_database.select(_database.budgets)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.id.equals(
                    receipt.operation.expectedPersistedIdentifiers.single,
                  ),
            ))
            .getSingleOrNull();
    if (row == null) return _notExecuted(command);
    final expected = Budget.fromJson(_nestedDynamic(command, 'budget'));
    return row.id == expected.id &&
            row.name == expected.name &&
            row.categoryId == expected.categoryId &&
            Decimal.tryParse(row.amount) == expected.amount &&
            row.currency == expected.currency &&
            row.periodType == expected.periodType.storageValue &&
            row.startDate.toUtc() == expected.startDate.toUtc() &&
            row.endDate.toUtc() == expected.endDate.toUtc() &&
            row.alertThresholdPercent == expected.alertThresholdPercent &&
            row.isActive == expected.isActive &&
            row.createdAt.toUtc() == expected.createdAt.toUtc() &&
            row.updatedAt.toUtc() == expected.updatedAt.toUtc() &&
            row.archivedAt?.toUtc() == expected.archivedAt?.toUtc()
        ? _succeeded(command)
        : _inconsistent(command);
  }

  Future<AppAgentReconciliationResult> _reconcileGoal(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    final row =
        await (_database.select(_database.goals)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.id.equals(
                    receipt.operation.expectedPersistedIdentifiers.single,
                  ),
            ))
            .getSingleOrNull();
    if (row == null) return _notExecuted(command);
    final expected = Goal.fromJson(_nestedDynamic(command, 'goal'));
    return row.id == expected.id &&
            row.title == expected.title &&
            row.description == expected.description &&
            row.type == expected.type.storageValue &&
            Decimal.tryParse(row.targetAmount) == expected.targetAmount &&
            Decimal.tryParse(row.currentAmount) == expected.currentAmount &&
            row.currency == expected.currency &&
            row.linkedAccountId == expected.linkedAccountId &&
            row.targetDate?.toUtc() == expected.targetDate?.toUtc() &&
            row.icon == expected.icon &&
            row.color == expected.color &&
            row.status == expected.status.storageValue &&
            row.createdAt.toUtc() == expected.createdAt.toUtc() &&
            row.updatedAt.toUtc() == expected.updatedAt.toUtc() &&
            row.archivedAt?.toUtc() == expected.archivedAt?.toUtc() &&
            row.completedAt?.toUtc() == expected.completedAt?.toUtc()
        ? _succeeded(command)
        : _inconsistent(command);
  }

  Future<AppAgentReconciliationResult> _reconcileContribution(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    final row =
        await (_database.select(_database.goalContributions)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) &
                  row.id.equals(
                    receipt.operation.expectedPersistedIdentifiers.single,
                  ),
            ))
            .getSingleOrNull();
    if (row == null) return _notExecuted(command);
    final expected = GoalContribution.fromJson(
      _nestedDynamic(command, 'contribution'),
    );
    final parent =
        await (_database.select(_database.goals)..where(
              (goal) =>
                  goal.ownerScopeId.equals(_scope) &
                  goal.id.equals(expected.goalId),
            ))
            .getSingleOrNull();
    final expectedCreditedAmount =
        expected.creditedAmount ??
        (parent?.currency == expected.currency ? expected.amount : null);
    return expectedCreditedAmount != null &&
            row.id == expected.id &&
            row.goalId == expected.goalId &&
            Decimal.tryParse(row.amount) == expected.amount &&
            row.currency == expected.currency &&
            Decimal.tryParse(row.creditedAmount) == expectedCreditedAmount &&
            row.date.toUtc() == expected.date.toUtc() &&
            row.note == expected.note &&
            row.linkedTransactionId == expected.linkedTransactionId &&
            row.createdAt.toUtc() == expected.createdAt.toUtc() &&
            row.updatedAt.toUtc() == expected.updatedAt.toUtc() &&
            row.reversedAt?.toUtc() == expected.reversedAt?.toUtc()
        ? _succeeded(command)
        : _inconsistent(command);
  }

  Future<AppAgentReconciliationResult> _reconcileMutation(
    AppAgentCommand command,
  ) async {
    final action = _mutationAction(command);
    final resolver = _resolver;
    if (action == null || resolver == null) return _inconsistent(command);
    final state = await resolver._mutationBusinessState(action);
    return switch (state) {
      _MutationBusinessState.succeeded => _succeeded(
        command,
        affectedCount: businessOperationFor(
          command,
        ).expectedPersistedIdentifiers.length,
      ),
      _MutationBusinessState.notExecuted => _notExecuted(command),
      _MutationBusinessState.inconsistent => _inconsistent(command),
    };
  }

  AiAction? _mutationAction(AppAgentCommand command) {
    if (command.toolId == 'updateTransactionDraft') {
      final decoded = UpdateTransactionCommand.fromArguments(
        command.normalizedArguments,
      );
      return decoded == null ? null : UpdateTransactionDraft(command: decoded);
    }
    if (command.toolId == 'deleteTransactionDraft') {
      final decoded = DeleteTransactionCommand.fromArguments(
        command.normalizedArguments,
      );
      return decoded == null ? null : DeleteTransactionDraft(command: decoded);
    }
    if (command.toolId == 'undoAiAction') {
      final decoded = UndoAiActionCommand.fromArguments(
        command.normalizedArguments,
      );
      return decoded == null ? null : UndoAiActionDraft(command: decoded);
    }
    return null;
  }

  String _transactionIdFromSnapshot(Object? value) {
    if (value is! Map || value['transaction'] is! Map) return '';
    return (value['transaction'] as Map)['id']?.toString() ?? '';
  }

  List<String> _transactionIdsFromSnapshots(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map(_transactionIdFromSnapshot)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _undoExpectedIds(Map<String, Object?> arguments) {
    final operation = arguments['undoOperationType']?.toString();
    final key = operation == AiUndoOperationType.undoDeleteTransaction.name
        ? 'before'
        : 'after';
    return _transactionIdsFromSnapshots(arguments[key]);
  }

  bool _sameBusinessOperation(
    AppAgentBusinessOperationSpec actual,
    AppAgentBusinessOperationSpec expected,
  ) {
    final actualIds = actual.expectedPersistedIdentifiers;
    final expectedIds = expected.expectedPersistedIdentifiers;
    return actual.key.value == expected.key.value &&
        actual.expectedEntityType == expected.expectedEntityType &&
        actual.verificationMethod == expected.verificationMethod &&
        actual.safeAutomaticResume == expected.safeAutomaticResume &&
        actual.automaticRetryProhibited == expected.automaticRetryProhibited &&
        actualIds.length == expectedIds.length &&
        List<int>.generate(
          actualIds.length,
          (index) => index,
        ).every((index) => actualIds[index] == expectedIds[index]);
  }

  DateTime? _dateTime(Object? value) {
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  }

  Map<String, Object?> _nested(AppAgentCommand command, String key) {
    final value = command.normalizedArguments[key];
    if (value is! Map) return const <String, Object?>{};
    return Map<String, Object?>.from(value);
  }

  Map<String, dynamic> _nestedDynamic(AppAgentCommand command, String key) {
    final nested = _nested(command, key);
    return nested.map((key, value) => MapEntry(key, value));
  }

  String _nestedId(AppAgentCommand command, String key) =>
      _nested(command, key)['id']?.toString() ?? '';

  AppAgentReconciliationResult _succeeded(
    AppAgentCommand command, {
    int affectedCount = 1,
  }) => AppAgentReconciliationResult(
    status: AppAgentReconciliationStatus.verifiedSucceeded,
    entityType: _entityType(command.toolId),
    affectedCount: affectedCount,
  );

  AppAgentReconciliationResult _notExecuted(AppAgentCommand command) =>
      _reconciliation(
        AppAgentReconciliationStatus.verifiedNotExecuted,
        command,
        AppAgentFailureCodes.recoveryNotExecuted,
      );

  AppAgentReconciliationResult _inconsistent(AppAgentCommand command) =>
      _reconciliation(
        AppAgentReconciliationStatus.inconsistent,
        command,
        AppAgentFailureCodes.recoveryInconsistent,
      );

  AppAgentReconciliationResult _reconciliation(
    AppAgentReconciliationStatus status,
    AppAgentCommand command,
    String safeFailureCode,
  ) => AppAgentReconciliationResult(
    status: status,
    entityType: _entityType(command.toolId),
    affectedCount: 0,
    safeFailureCode: safeFailureCode,
  );

  @override
  Future<AppAgentRevalidationResult> revalidate(AppAgentCommand command) async {
    final resolved = await _resolver?._resolve(command);
    final isMutation =
        command.toolId == 'updateTransactionDraft' ||
        command.toolId == 'deleteTransactionDraft' ||
        command.toolId == 'undoAiAction';
    return AppAgentRevalidationResult(
      isValid: resolved != null,
      currentStateFingerprint: resolved?.fingerprint ?? 'invalid',
      safeFailureCode: resolved == null
          ? (isMutation && command.previewFingerprint != null
                ? AppAgentFailureCodes.stalePreview
                : AppAgentFailureCodes.validationFailed)
          : null,
    );
  }

  @override
  Future<AppAgentHandlerResult> executeConfirmed(AppAgentCommand command) =>
      _executeConfirmed(command);

  @override
  Future<AppAgentHandlerResult> executeConfirmedWithFaultInjection(
    AppAgentCommand command,
    AppAgentExecutionFaultInjector faultInjector,
  ) => _executeConfirmed(command, faultInjector: faultInjector);

  Future<AppAgentHandlerResult> _executeConfirmed(
    AppAgentCommand command, {
    AppAgentExecutionFaultInjector? faultInjector,
  }) async {
    final resolved = await _resolver?._resolve(command);
    if (resolved == null ||
        command.previewFingerprint == null ||
        resolved.fingerprint != command.previewFingerprint) {
      return AppAgentHandlerResult(
        verified: false,
        entityType: _entityType(command.toolId),
        affectedCount: 0,
        safeFailureCode: AppAgentFailureCodes.stalePreview,
      );
    }
    final operation = businessOperationFor(command);
    final claimedAt = DateTime.now().toUtc();
    if (resolved.action is UpdateTransactionDraft ||
        resolved.action is DeleteTransactionDraft ||
        resolved.action is UndoAiActionDraft) {
      final mutationExecutor = _mutationExecutor;
      if (mutationExecutor == null) {
        return AppAgentHandlerResult(
          verified: false,
          entityType: 'transaction',
          affectedCount: 0,
          safeFailureCode: AppAgentFailureCodes.actionUnavailable,
        );
      }
      faultInjector?.checkpoint(
        AppAgentExecutionCrashPoint.duringBusinessTransaction,
        command,
      );
      final mutation = await mutationExecutor.execute(resolved.action);
      return switch (mutation) {
        AppFailure<AiTransactionMutationExecution>(:final failure) =>
          AppAgentHandlerResult(
            verified: false,
            entityType: 'transaction',
            affectedCount: 0,
            completionUncertain:
                failure.code == 'ai_transaction_mutation_failed',
            safeFailureCode:
                failure.code ?? AppAgentFailureCodes.verificationFailed,
          ),
        AppSuccess<AiTransactionMutationExecution>(:final data) =>
          await () async {
            final reconciliation = await reconcileBusinessOperation(
              command,
              AppAgentExecutionReceipt(
                attemptId: 'immediate:${command.commandId}:${command.revision}',
                commandId: command.commandId,
                commandRevision: command.revision,
                operation: operation,
                claimedAt: claimedAt,
              ),
            );
            final verified =
                reconciliation.status ==
                    AppAgentReconciliationStatus.verifiedSucceeded &&
                reconciliation.entityType == 'transaction' &&
                reconciliation.affectedCount == data.affectedCount;
            return AppAgentHandlerResult(
              verified: verified,
              entityType: 'transaction',
              affectedCount: verified ? data.affectedCount : 0,
              completionUncertain: !verified,
              safeFailureCode: verified
                  ? null
                  : reconciliation.safeFailureCode ??
                        AppAgentFailureCodes.verificationFailed,
              undoAvailable: verified && data.undoAvailable,
              undoToken: verified && data.undoAvailable
                  ? command.commandId
                  : null,
            );
          }(),
      };
    }
    final draft = AiActionDraft(
      id: command.commandId,
      action: resolved.action,
      status: AiActionExecutionStatus.awaitingConfirmation,
      createdAt: command.createdAt,
      updatedAt: command.createdAt,
    );
    final execution = await _executor!.execute(
      draft,
      confirmed: true,
      businessOperation: operation,
      executionCheckpoint: faultInjector == null
          ? null
          : (point) => faultInjector.checkpoint(point, command),
    );
    switch (execution) {
      case AppSuccess():
        final reconciliation = await reconcileBusinessOperation(
          command,
          AppAgentExecutionReceipt(
            attemptId: 'immediate:${command.commandId}:${command.revision}',
            commandId: command.commandId,
            commandRevision: command.revision,
            operation: operation,
            claimedAt: claimedAt,
          ),
        );
        final expectedAffectedCount = command.toolId == 'createTransferDraft'
            ? 2
            : 1;
        final verified =
            reconciliation.status ==
                AppAgentReconciliationStatus.verifiedSucceeded &&
            reconciliation.entityType == _entityType(command.toolId) &&
            reconciliation.affectedCount == expectedAffectedCount;
        return AppAgentHandlerResult(
          verified: verified,
          entityType: _entityType(command.toolId),
          affectedCount: verified ? expectedAffectedCount : 0,
          completionUncertain: !verified,
          safeFailureCode: verified
              ? null
              : reconciliation.safeFailureCode ??
                    AppAgentFailureCodes.verificationFailed,
          undoAvailable:
              verified &&
              (command.toolId == 'createExpenseDraft' ||
                  command.toolId == 'createIncomeDraft' ||
                  command.toolId == 'createTransferDraft'),
          undoToken:
              verified &&
                  (command.toolId == 'createExpenseDraft' ||
                      command.toolId == 'createIncomeDraft' ||
                      command.toolId == 'createTransferDraft')
              ? command.commandId
              : null,
        );
      case AppFailure(:final failure):
        return AppAgentHandlerResult(
          verified: false,
          entityType: _entityType(command.toolId),
          affectedCount: 0,
          completionUncertain:
              failure.code == AiActionFailureCodes.executionFailed,
          safeFailureCode:
              failure.code ?? AppAgentFailureCodes.verificationFailed,
        );
    }
  }

  String _entityType(String tool) => switch (tool) {
    'createExpenseDraft' ||
    'createIncomeDraft' ||
    'createTransferDraft' => 'transaction',
    'createBudgetDraft' => 'budget',
    'createGoalDraft' => 'goal',
    'createGoalContributionDraft' => 'goalContribution',
    'updateTransactionDraft' ||
    'deleteTransactionDraft' ||
    'undoAiAction' => 'transaction',
    _ => 'financialEntity',
  };
}

abstract interface class AiActionDurableRuntime {
  Future<AppAgentCommand> persistDraft(AiActionDraft draft);

  Future<AppAgentExecutionResult> confirmAndExecute(String commandId);

  Future<void> cancel(String commandId);

  Future<AiActionDraft?> restoreLatestPendingDraft();

  Future<void> acknowledgeRecoveryResult(String commandId);
}

class DurableAiActionBridge implements AiActionDurableRuntime {
  const DurableAiActionBridge({
    required DriftAppAgentCommandStore commandStore,
    required AppAgentConfirmationController confirmationController,
    required AppAgentCommandExecutor commandExecutor,
    required AppAgentCommandHandlerRegistry handlerRegistry,
    required AppAgentDurableExecutionStore executionStore,
    required DurableAiActionResolver resolver,
    required String? Function() currentScope,
    required bool Function(String toolId) canExecuteConfirmedCreate,
  }) : _commandStore = commandStore,
       _confirmationController = confirmationController,
       _commandExecutor = commandExecutor,
       _handlerRegistry = handlerRegistry,
       _executionStore = executionStore,
       _resolver = resolver,
       _currentScope = currentScope,
       _canExecuteConfirmedCreate = canExecuteConfirmedCreate;

  final DriftAppAgentCommandStore _commandStore;
  final AppAgentConfirmationController _confirmationController;
  final AppAgentCommandExecutor _commandExecutor;
  final AppAgentCommandHandlerRegistry _handlerRegistry;
  final AppAgentDurableExecutionStore _executionStore;
  final DurableAiActionResolver _resolver;
  final String? Function() _currentScope;
  final bool Function(String toolId) _canExecuteConfirmedCreate;

  @override
  Future<AppAgentCommand> persistDraft(AiActionDraft draft) async {
    final scope = _currentScope();
    if (scope == null) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.accountScopeMismatch,
        'A confirmed scope is required.',
      );
    }
    final descriptor = _descriptor(draft.action);
    final arguments = _arguments(draft.action);
    final command = AppAgentCommand(
      commandId: draft.id,
      conversationId: 'local-financial-draft',
      userAccountScope: scope,
      commandType: const AppAgentPolicy().commandTypeForPermission(
        descriptor.permission,
      ),
      toolId: descriptor.id,
      normalizedArguments: arguments,
      permission: descriptor.permission,
      risk: descriptor.risk,
      createdAt: draft.createdAt,
      expiresAt: draft.createdAt.add(const Duration(minutes: 15)),
      status: AppAgentCommandStatus.readyForPreview,
    );
    await _commandStore.saveTrustedLocalCommand(command);
    final handler = _handlerRegistry.handlerFor(command.toolId);
    final revalidation = await handler?.revalidate(command);
    if (handler == null || revalidation == null || !revalidation.isValid) {
      throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.validationFailed,
        'The draft could not be resolved locally.',
      );
    }
    await _commandStore.savePreview(
      preview: AppAgentPreview(
        commandId: command.commandId,
        title: descriptor.id,
        entityType: handler.toolId,
        fields: _previewFields(draft.action, descriptor.id, arguments),
        risk: descriptor.risk,
        confirmationLevel: const AppAgentPolicy().confirmationLevelFor(
          descriptor.risk,
        ),
        stateFingerprint: revalidation.currentStateFingerprint,
        createdAt: DateTime.now().toUtc(),
      ),
      accountScope: scope,
    );
    return (await _commandStore.readCommand(
      commandId: command.commandId,
      accountScope: scope,
    ))!;
  }

  @override
  Future<AppAgentExecutionResult> confirmAndExecute(String commandId) async {
    final scope = _currentScope();
    if (scope == null) {
      return AppAgentExecutionResult(
        commandId: commandId,
        status: AppAgentCommandStatus.failed,
        verified: false,
        entityType: 'financialEntity',
        affectedCount: 0,
        completedAt: DateTime.now().toUtc(),
        safeFailureCode: AppAgentFailureCodes.accountScopeMismatch,
      );
    }
    final command = await _commandStore.readCommand(
      commandId: commandId,
      accountScope: scope,
    );
    if (command == null || !_canExecuteConfirmedCreate(command.toolId)) {
      return AppAgentExecutionResult(
        commandId: commandId,
        status: AppAgentCommandStatus.failed,
        verified: false,
        entityType: 'financialEntity',
        affectedCount: 0,
        completedAt: DateTime.now().toUtc(),
        safeFailureCode: AppAgentFailureCodes.permissionDenied,
      );
    }
    final decision = await _confirmationController.confirm(
      commandId: commandId,
      accountScope: scope,
      method: AppAgentConfirmationMethod.primaryButton,
    );
    final confirmation = decision.confirmation;
    if (confirmation == null) {
      return AppAgentExecutionResult(
        commandId: commandId,
        status: AppAgentCommandStatus.failed,
        verified: false,
        entityType: 'financialEntity',
        affectedCount: 0,
        completedAt: DateTime.now().toUtc(),
        safeFailureCode:
            decision.safeFailureCode ??
            AppAgentFailureCodes.invalidConfirmation,
      );
    }
    return _commandExecutor.execute(confirmation);
  }

  @override
  Future<void> cancel(String commandId) async {
    final scope = _currentScope();
    if (scope == null) return;
    final command = await _commandStore.readCommand(
      commandId: commandId,
      accountScope: scope,
    );
    if (command == null || command.isTerminal) return;
    await _commandStore.transition(
      commandId: commandId,
      accountScope: scope,
      expectedStatus: command.status,
      nextStatus: AppAgentCommandStatus.cancelled,
    );
  }

  @override
  Future<void> acknowledgeRecoveryResult(String commandId) async {
    try {
      await _executionStore.acknowledgeUiDelivery(commandId);
    } on Object {
      // A missing acknowledgement may repeat a safe recovery notice, but it
      // must never alter or retry an already committed financial operation.
    }
  }

  /// Restores only a command that is still safe to display. It never resumes
  /// an execution or reconstructs authority from a persisted confirmation.
  @override
  Future<AiActionDraft?> restoreLatestPendingDraft() async {
    final scope = _currentScope();
    if (scope == null) return null;
    final commands = await _commandStore.readCommandsForScope(scope);
    for (final command in commands) {
      if (!_isSupportedTool(command.toolId)) continue;
      if (command.status != AppAgentCommandStatus.awaitingConfirmation &&
          command.status != AppAgentCommandStatus.confirmed &&
          command.status != AppAgentCommandStatus.executing &&
          command.status != AppAgentCommandStatus.partiallySucceeded &&
          command.status != AppAgentCommandStatus.failed &&
          command.status != AppAgentCommandStatus.expired) {
        continue;
      }
      if (command.isExpiredAt(DateTime.now().toUtc()) &&
          command.status == AppAgentCommandStatus.awaitingConfirmation) {
        await _commandStore.transition(
          commandId: command.commandId,
          accountScope: scope,
          expectedStatus: command.status,
          nextStatus: AppAgentCommandStatus.expired,
          safeFailureCode: AppAgentFailureCodes.expired,
        );
      }
      final resolved = await _resolver._resolve(command);
      if (resolved == null) continue;
      final status = switch (command.status) {
        AppAgentCommandStatus.awaitingConfirmation =>
          AiActionExecutionStatus.awaitingConfirmation,
        AppAgentCommandStatus.confirmed ||
        AppAgentCommandStatus.executing => AiActionExecutionStatus.executing,
        _ => AiActionExecutionStatus.failed,
      };
      return AiActionDraft(
        id: command.commandId,
        action: resolved.action,
        status: status,
        createdAt: command.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    return null;
  }

  bool _isSupportedTool(String toolId) => const <String>{
    'createExpenseDraft',
    'createIncomeDraft',
    'createTransferDraft',
    'createBudgetDraft',
    'createGoalDraft',
    'createGoalContributionDraft',
    'updateTransactionDraft',
    'deleteTransactionDraft',
    'undoAiAction',
  }.contains(toolId);

  AppAgentToolDescriptor _descriptor(AiAction action) {
    final id = switch (action) {
      CreateExpenseDraft() => 'createExpenseDraft',
      CreateIncomeDraft() => 'createIncomeDraft',
      CreateTransferDraft() => 'createTransferDraft',
      CreateBudgetDraft() => 'createBudgetDraft',
      CreateGoalDraft() => 'createGoalDraft',
      AddGoalContributionDraft() => 'createGoalContributionDraft',
      UpdateTransactionDraft() => 'updateTransactionDraft',
      DeleteTransactionDraft() => 'deleteTransactionDraft',
      UndoAiActionDraft() => 'undoAiAction',
      _ => throw const AppAgentPolicyViolation(
        AppAgentFailureCodes.prohibited,
        'This action is not supported by the durable bridge.',
      ),
    };
    return CanonicalAppToolCatalog.byId(id)!;
  }

  Map<String, Object?> _arguments(AiAction action) => switch (action) {
    CreateExpenseDraft(:final transactionDraft) ||
    CreateIncomeDraft(
      :final transactionDraft,
    ) => _transactionArguments(transactionDraft),
    CreateTransferDraft(
      :final sourceAccount,
      :final destinationAccount,
      :final sourceAmount,
      :final destinationAmount,
      :final exchangeRate,
      :final note,
    ) =>
      <String, Object?>{
        'sourceAccountId': sourceAccount.id,
        'destinationAccountId': destinationAccount.id,
        'sourceAmount': sourceAmount.amount.toString(),
        'sourceCurrency': sourceAmount.currencyCode,
        'destinationAmount': ?destinationAmount?.amount.toString(),
        'destinationCurrency': ?destinationAmount?.currencyCode,
        if (exchangeRate != null) 'exchangeRate': exchangeRate.rate.toString(),
        if (exchangeRate?.asOf != null)
          'exchangeRateAsOf': exchangeRate!.asOf!.toUtc().toIso8601String(),
        'note': ?note,
      },
    CreateBudgetDraft(:final budget) => <String, Object?>{
      'budget': budget.toJson(),
    },
    CreateGoalDraft(:final goal) => <String, Object?>{'goal': goal.toJson()},
    AddGoalContributionDraft(:final contribution) => <String, Object?>{
      'contribution': contribution.toJson(),
    },
    UpdateTransactionDraft(:final command) => command.toArguments(),
    DeleteTransactionDraft(:final command) => command.toArguments(),
    UndoAiActionDraft(:final command) => command.toArguments(),
    _ => throw const AppAgentPolicyViolation(
      AppAgentFailureCodes.prohibited,
      'This action is not supported by the durable bridge.',
    ),
  };

  Map<String, Object?> _transactionArguments(
    AiTransactionDraft transactionDraft,
  ) {
    final sourceIdentity = _incomeSourceIdentity(transactionDraft);
    return <String, Object?>{
      'accountId': transactionDraft.account.id,
      'categoryId': transactionDraft.category!.id,
      if (transactionDraft.payee != null) 'payeeId': transactionDraft.payee!.id,
      'amount': transactionDraft.amount.amount.toString(),
      'currency': transactionDraft.amount.currencyCode,
      'transactionType': transactionDraft.type.name,
      'paymentMethod': transactionDraft.paymentMethod.name,
      'status': transactionDraft.status.name,
      'note': transactionDraft.noteForPersistence,
      if (transactionDraft.transactionDate != null)
        'transactionDate': transactionDraft.transactionDate!
            .toUtc()
            .toIso8601String(),
      if (transactionDraft.incomeSourceSuggestion != null)
        'incomeSourceType':
            transactionDraft.incomeSourceSuggestion!.sourceType.storageValue,
      'incomeSourceIdentity': ?sourceIdentity,
    };
  }

  List<AppAgentPreviewField> _previewFields(
    AiAction action,
    String descriptorId,
    Map<String, Object?> arguments,
  ) {
    if (action case UpdateTransactionDraft(:final command)) {
      final before = command.original;
      final after = command.updated;
      return <AppAgentPreviewField>[
        const AppAgentPreviewField(
          label: 'Action',
          proposedValue: 'Update transaction',
        ),
        AppAgentPreviewField(
          label: 'Transaction type',
          previousValue: before.transaction.type.name,
          proposedValue: after.transaction.type.name,
        ),
        AppAgentPreviewField(
          label: 'Amount',
          previousValue:
              '${before.transaction.amount.amount} ${before.transaction.amount.currencyCode}',
          proposedValue:
              '${after.transaction.amount.amount} ${after.transaction.amount.currencyCode}',
        ),
        AppAgentPreviewField(
          label: 'Account',
          previousValue: before.accountName,
          proposedValue: after.accountName,
        ),
        AppAgentPreviewField(
          label: 'Category',
          previousValue: before.categoryName,
          proposedValue: after.categoryName,
        ),
        AppAgentPreviewField(
          label: 'Status',
          previousValue: before.transaction.status.name,
          proposedValue: after.transaction.status.name,
        ),
        AppAgentPreviewField(
          label: 'Date',
          previousValue: before.transaction.transactionDate
              .toUtc()
              .toIso8601String(),
          proposedValue: after.transaction.transactionDate
              .toUtc()
              .toIso8601String(),
        ),
        AppAgentPreviewField(
          label: 'Expected balance effect',
          proposedValue: _updateBalanceEffect(command),
        ),
        if (before.transaction.affectsBalance ||
            after.transaction.affectsBalance)
          const AppAgentPreviewField(
            label: 'Financial warning',
            proposedValue:
                'The old posted effect will be reversed and the new posted effect applied atomically.',
          ),
      ];
    }
    if (action case DeleteTransactionDraft(:final command)) {
      final primary = command.targets.first;
      return <AppAgentPreviewField>[
        const AppAgentPreviewField(
          label: 'Action',
          proposedValue: 'Delete or cancel transaction',
        ),
        AppAgentPreviewField(
          label: 'Transaction type',
          proposedValue: primary.transaction.type.name,
        ),
        AppAgentPreviewField(
          label: 'Amount',
          proposedValue:
              '${primary.transaction.amount.amount} ${primary.transaction.amount.currencyCode}',
        ),
        AppAgentPreviewField(
          label: 'Account',
          proposedValue: primary.accountName,
        ),
        AppAgentPreviewField(
          label: 'Category or source',
          proposedValue: primary.payeeName ?? primary.categoryName,
        ),
        AppAgentPreviewField(
          label: 'Date',
          proposedValue: primary.transaction.transactionDate
              .toUtc()
              .toIso8601String(),
        ),
        AppAgentPreviewField(
          label: 'Status',
          proposedValue: primary.transaction.status.name,
        ),
        AppAgentPreviewField(
          label: 'Balance change',
          proposedValue: primary.transaction.affectsBalance
              ? 'The posted financial effect will be reversed.'
              : 'No balance effect.',
        ),
        AppAgentPreviewField(
          label: 'Undo availability',
          proposedValue: primary.transaction.isTransfer
              ? 'Transfer restoration is unavailable unless proven safe.'
              : 'Available for 24 hours if the target remains unchanged.',
        ),
        if (command.targets.length == 2)
          AppAgentPreviewField(
            label: 'Transfer pair',
            proposedValue: command.targets
                .map(
                  (item) =>
                      '${item.accountName}: ${item.transaction.amount.amount} ${item.transaction.amount.currencyCode}',
                )
                .join(' | '),
          ),
      ];
    }
    if (action case UndoAiActionDraft(:final command)) {
      final target = command.before.firstOrNull ?? command.after.firstOrNull;
      return <AppAgentPreviewField>[
        const AppAgentPreviewField(
          label: 'Action',
          proposedValue: 'Undo last eligible AI action',
        ),
        AppAgentPreviewField(
          label: 'Original action',
          proposedValue: command.sourceToolId,
        ),
        AppAgentPreviewField(
          label: 'Inverse operation',
          proposedValue: command.operationType.name,
        ),
        if (target != null)
          AppAgentPreviewField(
            label: 'Transaction',
            proposedValue:
                '${target.transaction.amount.amount} ${target.transaction.amount.currencyCode} — ${target.accountName}',
          ),
        const AppAgentPreviewField(
          label: 'One-time rule',
          proposedValue:
              'This undo is owner-bound, revision-bound, and can run only once.',
        ),
      ];
    }
    final transactionDraft = action.transactionDraft;
    if (transactionDraft != null) {
      final sourceIdentity = _incomeSourceIdentity(transactionDraft);
      return <AppAgentPreviewField>[
        AppAgentPreviewField(label: 'Action', proposedValue: descriptorId),
        AppAgentPreviewField(
          label: 'Transaction type',
          proposedValue: transactionDraft.type.name,
        ),
        AppAgentPreviewField(
          label: 'Amount',
          proposedValue:
              '${transactionDraft.amount.currencyCode} ${transactionDraft.amount.amount}',
        ),
        AppAgentPreviewField(
          label: transactionDraft.type == TransactionType.income
              ? 'Destination account'
              : 'Account',
          proposedValue: transactionDraft.account.name,
        ),
        AppAgentPreviewField(
          label: 'Category',
          proposedValue: transactionDraft.category!.name,
        ),
        if (transactionDraft.type == TransactionType.income)
          AppAgentPreviewField(
            label: 'Source classification',
            proposedValue: transactionDraft
                .incomeSourceSuggestion!
                .sourceType
                .storageValue,
          ),
        if (transactionDraft.type == TransactionType.income)
          AppAgentPreviewField(
            label: 'Source identity',
            proposedValue: sourceIdentity ?? 'Not specified',
          ),
        AppAgentPreviewField(
          label: 'Date',
          proposedValue:
              transactionDraft.transactionDate?.toUtc().toIso8601String() ??
              'Not specified',
        ),
        AppAgentPreviewField(
          label: 'Status',
          proposedValue: transactionDraft.status.storageValue,
        ),
        AppAgentPreviewField(
          label: 'Payee',
          proposedValue: transactionDraft.payee?.name ?? 'Not specified',
        ),
        AppAgentPreviewField(
          label: 'Payment method',
          proposedValue: transactionDraft.paymentMethod.name,
        ),
        AppAgentPreviewField(
          label: 'Note',
          proposedValue: transactionDraft.noteForPersistence.isEmpty
              ? 'None'
              : transactionDraft.noteForPersistence,
        ),
      ];
    }
    return <AppAgentPreviewField>[
      AppAgentPreviewField(label: 'Action', proposedValue: descriptorId),
      for (final entry in arguments.entries)
        AppAgentPreviewField(
          label: entry.key,
          proposedValue: entry.value is String
              ? entry.value! as String
              : jsonEncode(entry.value),
        ),
    ];
  }

  String? _incomeSourceIdentity(AiTransactionDraft transactionDraft) {
    return transactionDraft.incomeSourceIdentity;
  }

  String _updateBalanceEffect(UpdateTransactionCommand command) {
    final before = command.original.transaction;
    final after = command.updated.transaction;
    if (!before.affectsBalance && !after.affectsBalance) {
      return 'No balance effect.';
    }
    if (before.affectsBalance && !after.affectsBalance) {
      return 'Reverse the previous posted effect once.';
    }
    if (!before.affectsBalance && after.affectsBalance) {
      return 'Apply the new posted effect once.';
    }
    return 'Reverse the previous effect, then apply the new effect atomically.';
  }
}

class _ResolvedAiAction {
  const _ResolvedAiAction(this.action, this.fingerprint);
  final AiAction action;
  final String fingerprint;
}

class _ActionAndRevisions {
  const _ActionAndRevisions(this.action, this.referenceRevisions);
  final AiAction action;
  final List<String> referenceRevisions;
}

enum _MutationBusinessState { succeeded, notExecuted, inconsistent }
