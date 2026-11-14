import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_command_runtime.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_reconciliation_service.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/durable_ai_action_bridge.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_action_executor.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_transaction_mutation_executor.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/drift_app_agent_stores.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/canonical_app_tool_catalog.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_mutation_command.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_validator.dart';
import 'package:cashpilot_ai/features/budgets/domain/repositories/budget_repository.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/repositories/categories_repository.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/goals/domain/repositories/goal_repository.dart';
import 'package:cashpilot_ai/features/payees/domain/repositories/payees_repository.dart';
import 'package:cashpilot_ai/features/payment_methods/payment_methods.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/create_transfer_command.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/created_transfer.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_source.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/services/transaction_content_comparator.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transfer.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/delete_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/get_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/update_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/update_transaction_status.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  group('durable AI transaction mutations', () {
    late AppDatabase database;
    late ScopedAppDatabaseSession session;
    late _MemoryTransactionsRepository transactions;
    late _DurableMutationHarness harness;
    late DateTime now;

    setUp(() async {
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      session = scopedTestSession(database);
      await database.customSelect('SELECT 1').get();
      now = DateTime.now().toUtc();
      transactions = _MemoryTransactionsRepository(<Transaction>[
        _transaction('target', amount: '30', timestamp: now),
      ]);
      harness = _DurableMutationHarness(
        session: session,
        transactions: transactions,
      );
    });

    tearDown(() => database.close());

    test(
      'pending update survives restart and confirmed duplicate is fenced',
      () async {
        final original = transactions.values['target']!;
        final updated = original.copyWith(
          amount: _money('50'),
          updatedAt: now.add(const Duration(seconds: 1)),
        );
        final action = _updateAction(original, updated, now);
        await harness.bridge.persistDraft(
          AiActionDraft.create(
            id: action.command.commandId,
            action: action,
            createdAt: now,
          ),
        );
        final stored = (await harness.commandStore.readCommand(
          commandId: action.command.commandId,
          accountScope: session.ownerScopeValue,
        ))!;
        final decoded = UpdateTransactionCommand.fromArguments(
          stored.normalizedArguments,
        );
        expect(decoded, isNotNull);
        expect(
          transactionContentEquals(decoded!.original.transaction, original),
          isTrue,
        );
        expect(
          transactionContentEquals(decoded.updated.transaction, updated),
          isTrue,
          reason: 'updated snapshot must round-trip',
        );
        expect(decoded.commandId, stored.commandId);
        expect(
          decoded.createdAt.millisecondsSinceEpoch ~/ 1000,
          stored.createdAt.millisecondsSinceEpoch ~/ 1000,
        );
        expect(
          decoded.expiresAt.millisecondsSinceEpoch ~/ 1000,
          stored.expiresAt.millisecondsSinceEpoch ~/ 1000,
        );
        expect(
          (await harness.registry
                  .handlerFor('updateTransactionDraft')!
                  .revalidate(stored))
              .isValid,
          isTrue,
        );

        final reopened = harness.reopen();
        final restored = await reopened.bridge.restoreLatestPendingDraft();
        expect(restored?.action, isA<UpdateTransactionDraft>());
        expect(transactions.updateCalls, 0);

        final result = await reopened.bridge.confirmAndExecute(
          action.command.commandId,
        );
        final duplicate = await reopened.bridge.confirmAndExecute(
          action.command.commandId,
        );

        expect(result.verified, isTrue);
        expect(result.undoAvailable, isTrue);
        expect(result.undoToken, action.command.commandId);
        expect(transactions.updateCalls, 1);
        expect(
          transactions.values['target']!.amount.amount,
          Decimal.fromInt(50),
        );
        expect(duplicate.verified, isFalse);
        expect(transactions.updateCalls, 1);

        final recovered = await AppAgentStartupReconciler(
          commandStore: reopened.commandStore,
          executionStore: reopened.executionStore,
          handlerRegistry: reopened.registry,
        ).reconcile();
        expect(
          recovered.reconciledResults.any(
            (item) => item.commandId == action.command.commandId,
          ),
          isTrue,
        );
        await reopened.bridge.acknowledgeRecoveryResult(
          action.command.commandId,
        );
        final afterAcknowledgement = await AppAgentStartupReconciler(
          commandStore: reopened.commandStore,
          executionStore: reopened.executionStore,
          handlerRegistry: reopened.registry,
        ).reconcile();
        expect(
          afterAcknowledgement.reconciledResults.any(
            (item) => item.commandId == action.command.commandId,
          ),
          isFalse,
        );
      },
    );

    test('stale preview and wrong owner both execute zero mutations', () async {
      final original = transactions.values['target']!;
      final action = _updateAction(
        original,
        original.copyWith(
          amount: _money('45'),
          updatedAt: now.add(const Duration(seconds: 1)),
        ),
        now,
        id: 'stale-update',
      );
      await harness.bridge.persistDraft(
        AiActionDraft.create(
          id: action.command.commandId,
          action: action,
          createdAt: now,
        ),
      );
      transactions.values['target'] = original.copyWith(
        note: 'changed after preview',
        updatedAt: now.add(const Duration(seconds: 2)),
      );

      final stale = await harness.bridge.confirmAndExecute(
        action.command.commandId,
      );
      expect(stale.verified, isFalse);
      expect(stale.safeFailureCode, AppAgentFailureCodes.stalePreview);
      expect(transactions.updateCalls, 0);

      transactions.values['target'] = original;
      final ownerAction = _updateAction(
        original,
        original.copyWith(
          amount: _money('40'),
          updatedAt: now.add(const Duration(seconds: 1)),
        ),
        now,
        id: 'owner-update',
      );
      await harness.bridge.persistDraft(
        AiActionDraft.create(
          id: ownerAction.command.commandId,
          action: ownerAction,
          createdAt: now,
        ),
      );
      harness.currentScope = 'owner-b';
      final wrongOwner = await harness.bridge.confirmAndExecute(
        ownerAction.command.commandId,
      );
      expect(wrongOwner.verified, isFalse);
      expect(wrongOwner.safeFailureCode, AppAgentFailureCodes.permissionDenied);
      expect(transactions.updateCalls, 0);
    });

    test('delete and owner-bound undo each execute exactly once', () async {
      final original = transactions.values['target']!;
      final snapshot = _snapshot(original);
      final deleteCommand = DeleteTransactionCommand(
        commandId: 'delete-command',
        targets: <AiTransactionTargetSnapshot>[snapshot],
        mode: AiTransactionDeleteMode.reverseAndDeletePosted,
        operationRevision: 0,
        previewFingerprint: aiTransactionSnapshotFingerprint(
          <AiTransactionTargetSnapshot>[snapshot],
        ),
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
      );
      final deleteAction = DeleteTransactionDraft(command: deleteCommand);
      await harness.bridge.persistDraft(
        AiActionDraft.create(
          id: deleteCommand.commandId,
          action: deleteAction,
          createdAt: now,
        ),
      );
      final deleted = await harness.bridge.confirmAndExecute(
        deleteCommand.commandId,
      );
      expect(deleted.verified, isTrue);
      expect(deleted.undoAvailable, isTrue);
      expect(transactions.deleteCalls, 1);
      expect(transactions.values['target'], isNull);

      final source = (await harness.commandStore.readCommand(
        commandId: deleteCommand.commandId,
        accountScope: session.ownerScopeValue,
      ))!;
      final undoCommand = UndoAiActionCommand(
        commandId: 'undo-delete-command',
        sourceCommandId: source.commandId,
        sourceToolId: source.toolId,
        operationType: AiUndoOperationType.undoDeleteTransaction,
        before: <AiTransactionTargetSnapshot>[snapshot],
        after: const <AiTransactionTargetSnapshot>[],
        sourceOperationRevision: source.revision,
        operationRevision: 0,
        previewFingerprint: aiTransactionSnapshotFingerprint(
          <AiTransactionTargetSnapshot>[snapshot],
        ),
        createdAt: now.add(const Duration(seconds: 2)),
        expiresAt: now.add(const Duration(minutes: 15, seconds: 2)),
      );
      final undoAction = UndoAiActionDraft(command: undoCommand);
      await harness.bridge.persistDraft(
        AiActionDraft.create(
          id: undoCommand.commandId,
          action: undoAction,
          createdAt: undoCommand.createdAt,
        ),
      );
      final undone = await harness.bridge.confirmAndExecute(
        undoCommand.commandId,
      );
      final duplicate = await harness.bridge.confirmAndExecute(
        undoCommand.commandId,
      );

      expect(undone.verified, isTrue);
      expect(undone.undoAvailable, isFalse);
      expect(transactions.createCalls, 1);
      expect(
        transactionContentEquals(transactions.values['target']!, original),
        isTrue,
      );
      expect(duplicate.verified, isFalse);
      expect(transactions.createCalls, 1);
    });
  });
}

final class _DurableMutationHarness {
  _DurableMutationHarness({
    required this.session,
    required this.transactions,
    DriftAppAgentCommandStore? commandStore,
    DriftAppAgentDurableExecutionStore? executionStore,
  }) : commandStore = commandStore ?? _commandStore(session),
       executionStore =
           executionStore ?? DriftAppAgentDurableExecutionStore(session) {
    _compose();
  }

  final ScopedAppDatabaseSession session;
  final _MemoryTransactionsRepository transactions;
  final DriftAppAgentCommandStore commandStore;
  final DriftAppAgentDurableExecutionStore executionStore;
  String? currentScope;
  late DurableAiActionResolver resolver;
  late AppAgentCommandHandlerRegistry registry;
  late DurableAiActionBridge bridge;

  void _compose() {
    currentScope ??= session.ownerScopeValue;
    final account = Account.create(
      id: 'cash',
      name: 'Cash',
      type: AccountType.cash,
      currencyCode: 'LYD',
      balance: Decimal.fromInt(100),
      icon: 'wallet',
      color: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final category = Category.create(
      id: 'coffee',
      name: 'Coffee',
      type: CategoryType.expense,
      icon: const CategoryIcon(key: 'coffee'),
      color: const CategoryColor(argb: 1),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    resolver = DurableAiActionResolver(
      accounts: _AccountsRepository(account),
      categories: _CategoriesRepository(category),
      payees: _UnusedPayeesRepository(),
      budgets: _UnusedBudgetRepository(),
      goals: _UnusedGoalRepository(),
      transactions: transactions,
      commandStore: commandStore,
      executionStore: executionStore,
    );
    final generalExecutor = AiActionExecutor(
      createTransaction: CreateTransaction(transactions),
      createTransfer: CreateTransfer(transactions),
      validator: const AiActionValidator(),
    );
    final mutationExecutor = AiTransactionMutationExecutor(
      updateTransaction: UpdateTransaction(transactions),
      deleteTransaction: DeleteTransaction(transactions),
      updateTransactionStatus: UpdateTransactionStatus(transactions),
      createTransaction: CreateTransaction(transactions),
      getTransaction: GetTransaction(transactions),
    );
    registry = MapAppAgentCommandHandlerRegistry(
      _mutationDescriptors.map(
        (descriptor) => ProductionFinancialCommandHandler(
          toolId: descriptor.id,
          risk: descriptor.risk,
          resolver: resolver,
          executor: generalExecutor,
          mutationExecutor: mutationExecutor,
          session: session,
        ),
      ),
    );
    final proofStore = DriftAppAgentConfirmationProofStore(session);
    bridge = DurableAiActionBridge(
      commandStore: commandStore,
      confirmationController: AppAgentConfirmationController(
        commandStore: commandStore,
        proofStore: proofStore,
      ),
      commandExecutor: AppAgentCommandExecutor(
        commandStore: commandStore,
        auditStore: DriftAppAgentAuditStore(session),
        proofStore: proofStore,
        handlerRegistry: registry,
        accountScopeProvider: _ScopeProvider(() => currentScope),
        durableExecutionStore: executionStore,
      ),
      handlerRegistry: registry,
      executionStore: executionStore,
      resolver: resolver,
      currentScope: () => currentScope,
      canExecuteConfirmedCreate: (_) => true,
    );
  }

  _DurableMutationHarness reopen() => _DurableMutationHarness(
    session: session,
    transactions: transactions,
    commandStore: commandStore,
    executionStore: executionStore,
  );
}

Iterable<AppAgentToolDescriptor> get _mutationDescriptors =>
    CanonicalAppToolCatalog.safeTools.where(
      (item) => const <String>{
        'updateTransactionDraft',
        'deleteTransactionDraft',
        'undoAiAction',
      }.contains(item.id),
    );

DriftAppAgentCommandStore _commandStore(ScopedAppDatabaseSession session) =>
    DriftAppAgentCommandStore(
      session: session,
      canonicalDescriptors: _mutationDescriptors.map(
        (item) => AppAgentModelProposalDescriptor(
          toolId: item.id,
          permission: item.permission,
          risk: item.risk,
          modelCallable: item.modelCallable,
        ),
      ),
    );

UpdateTransactionDraft _updateAction(
  Transaction original,
  Transaction updated,
  DateTime now, {
  String id = 'update-command',
}) {
  final before = _snapshot(original);
  final after = _snapshot(updated);
  return UpdateTransactionDraft(
    command: UpdateTransactionCommand(
      commandId: id,
      original: before,
      updated: after,
      operationRevision: 0,
      previewFingerprint: aiTransactionSnapshotFingerprint(
        <AiTransactionTargetSnapshot>[before, after],
      ),
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    ),
  );
}

AiTransactionTargetSnapshot _snapshot(Transaction transaction) =>
    AiTransactionTargetSnapshot(
      transaction: transaction,
      accountName: 'Cash',
      categoryName: 'Coffee',
    );

Transaction _transaction(
  String id, {
  required String amount,
  required DateTime timestamp,
}) => Transaction.create(
  id: id,
  accountId: 'cash',
  categoryId: 'coffee',
  amount: _money(amount),
  type: TransactionType.expense,
  paymentMethod: PaymentMethod.cash,
  source: TransactionSource.aiGenerated,
  status: TransactionStatus.posted,
  note: 'coffee',
  transactionDate: timestamp,
  createdAt: timestamp,
  updatedAt: timestamp,
);

Money _money(String amount) =>
    Money(amount: Decimal.parse(amount), currencyCode: 'LYD');

final class _MemoryTransactionsRepository implements TransactionsRepository {
  _MemoryTransactionsRepository(List<Transaction> initial)
    : values = <String, Transaction>{for (final item in initial) item.id: item};

  final Map<String, Transaction> values;
  int updateCalls = 0;
  int deleteCalls = 0;
  int createCalls = 0;

  @override
  Future<AppResult<Transaction?>> getTransaction(String id) async =>
      AppResult.success(values[id]);

  @override
  Future<AppResult<List<Transaction>>> getTransactions({
    String? accountId,
    String? categoryId,
    String? payeeId,
    String? transferGroupId,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async => AppResult.success(
    values.values
        .where(
          (item) =>
              (transferGroupId == null ||
                  item.transferGroupId == transferGroupId) &&
              (status == null || item.status == status),
        )
        .toList(growable: false),
  );

  @override
  Future<AppResult<List<Transaction>>> searchTransactions(
    String query, {
    int? limit,
    Set<TransactionType>? transactionTypes,
    TransactionStatus? status,
  }) async =>
      AppResult.success(values.values.take(limit ?? values.length).toList());

  @override
  Future<AppResult<Transaction>> updateTransaction(
    Transaction transaction, {
    Transaction? expectedCurrent,
  }) async {
    final current = values[transaction.id];
    if (current == null ||
        expectedCurrent == null ||
        !transactionContentEquals(current, expectedCurrent)) {
      return const AppResult.failure(
        Failure(message: 'stale', code: 'transaction_stale_mutation_target'),
      );
    }
    updateCalls += 1;
    values[transaction.id] = transaction;
    return AppResult.success(transaction);
  }

  @override
  Future<AppResult<void>> deleteTransaction(
    String id, {
    List<Transaction>? expectedCurrent,
  }) async {
    final current = values[id];
    if (current == null ||
        expectedCurrent == null ||
        expectedCurrent.length != 1 ||
        !transactionContentEquals(current, expectedCurrent.single)) {
      return const AppResult.failure(
        Failure(message: 'stale', code: 'transaction_stale_mutation_target'),
      );
    }
    deleteCalls += 1;
    values.remove(id);
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    if (values.containsKey(transaction.id)) {
      return const AppResult.failure(
        Failure(message: 'duplicate', code: 'duplicate'),
      );
    }
    createCalls += 1;
    values[transaction.id] = transaction;
    return AppResult.success(transaction);
  }

  @override
  Future<AppResult<List<Transaction>>> updateTransactionStatus(
    String id,
    TransactionStatus status, {
    List<Transaction>? expectedCurrent,
  }) async => const AppResult.failure(Failure(message: 'not used'));

  @override
  Future<AppResult<CreatedTransfer>> createTransfer(
    CreateTransferCommand command,
  ) async => const AppResult.failure(Failure(message: 'not used'));
}

final class _AccountsRepository implements AccountsRepository {
  const _AccountsRepository(this.account);
  final Account account;

  @override
  Future<AppResult<Account?>> getAccountById(String id) async =>
      AppResult.success(id == account.id ? account : null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _CategoriesRepository implements CategoriesRepository {
  const _CategoriesRepository(this.category);
  final Category category;

  @override
  Future<AppResult<Category?>> getCategoryById(String id) async =>
      AppResult.success(id == category.id ? category : null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedPayeesRepository implements PayeesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedBudgetRepository implements BudgetRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedGoalRepository implements GoalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ScopeProvider implements AppAgentAccountScopeProvider {
  const _ScopeProvider(this.readScope);
  final String? Function() readScope;

  @override
  String? get currentAccountScope => readScope();
}
