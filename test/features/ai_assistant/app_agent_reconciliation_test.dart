import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_command_runtime.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_reconciliation_service.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/durable_ai_action_bridge.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_action_executor.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/drift_app_agent_stores.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_reconciliation.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_validator.dart';
import 'package:cashpilot_ai/features/budgets/domain/repositories/budget_repository.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/repositories/categories_repository.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal_contribution.dart';
import 'package:cashpilot_ai/features/goals/domain/repositories/goal_repository.dart';
import 'package:cashpilot_ai/features/goals/domain/usecases/add_goal_contribution.dart';
import 'package:cashpilot_ai/features/income_sources/domain/entities/income_source_suggestion.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/payees/domain/repositories/payees_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/create_transfer_command.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transfer.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

const _tools = <String>[
  'createExpenseDraft',
  'createIncomeDraft',
  'createTransferDraft',
  'createBudgetDraft',
  'createGoalDraft',
  'createGoalContributionDraft',
];

const _persistedFieldCorruptions = <String, List<String>>{
  'createExpenseDraft': <String>['status', 'transactionDate', 'note'],
  'createIncomeDraft': <String>[
    'status',
    'transactionDate',
    'note',
    'incomeSourceType',
  ],
  'createTransferDraft': <String>[
    'status',
    'transactionDate',
    'note',
    'exchangeRate',
    'exchangeRateAsOf',
  ],
  'createBudgetDraft': <String>[
    'name',
    'categoryId',
    'amount',
    'currency',
    'periodType',
    'startDate',
    'endDate',
    'alertThresholdPercent',
    'isActive',
    'createdAt',
    'updatedAt',
    'archivedAt',
  ],
  'createGoalDraft': <String>[
    'title',
    'description',
    'type',
    'targetAmount',
    'currentAmount',
    'currency',
    'linkedAccountId',
    'targetDate',
    'icon',
    'color',
    'status',
    'createdAt',
    'updatedAt',
    'archivedAt',
    'completedAt',
  ],
  'createGoalContributionDraft': <String>[
    'goalId',
    'amount',
    'currency',
    'creditedAmount',
    'date',
    'note',
    'linkedTransactionId',
    'createdAt',
    'updatedAt',
    'reversedAt',
  ],
};

void main() {
  group('financial business reconciliation', () {
    late AppDatabase database;
    late ScopedAppDatabaseSession session;

    setUp(() async {
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      session = scopedTestSession(database);
      await database.customSelect('SELECT 1').get();
      await _seedBusinessReferences(database, session.ownerScopeValue);
    });

    tearDown(() => database.close());

    test(
      'all six production handlers inspect actual scoped business rows',
      () async {
        for (final tool in _tools) {
          final command = _reconciliationCommand(
            session.ownerScopeValue,
            tool,
            'actual-$tool',
          );
          final handler = ProductionFinancialCommandHandler.reconciliationOnly(
            toolId: tool,
            risk: AgentActionRisk.medium,
            session: session,
          );
          final operation = handler.businessOperationFor(command);
          final receipt = AppAgentExecutionReceipt(
            attemptId: 'attempt-$tool',
            commandId: command.commandId,
            commandRevision: command.revision,
            operation: operation,
            claimedAt: DateTime.utc(2026, 7, 31, 12),
          );

          expect(
            (await handler.reconcileBusinessOperation(command, receipt)).status,
            AppAgentReconciliationStatus.verifiedNotExecuted,
            reason: '$tool must not report success without its business row',
          );
          await _insertExpectedBusinessState(
            database,
            session.ownerScopeValue,
            command,
            operation,
          );
          final reconciled = await handler.reconcileBusinessOperation(
            command,
            receipt,
          );
          expect(
            reconciled.status,
            AppAgentReconciliationStatus.verifiedSucceeded,
            reason: '$tool did not recognize its committed business state',
          );
          expect(
            reconciled.affectedCount,
            tool == 'createTransferDraft' ? 2 : 1,
          );

          final otherScope = scopedTestSession(
            database,
            syntheticFirebaseUid: 'other-reconciliation-owner',
          );
          final crossScope =
              await ProductionFinancialCommandHandler.reconciliationOnly(
                toolId: tool,
                risk: AgentActionRisk.medium,
                session: otherScope,
              ).reconcileBusinessOperation(command, receipt);
          expect(crossScope.status, AppAgentReconciliationStatus.inconsistent);
        }
      },
    );

    test(
      'operation keys bind scope, revision, action, and redact diagnostics',
      () {
        final first = _reconciliationCommand(
          session.ownerScopeValue,
          _tools.first,
          'correlation-command',
        );
        final otherScope = _reconciliationCommand(
          scopedTestSession(
            database,
            syntheticFirebaseUid: 'correlation-owner-b',
          ).ownerScopeValue,
          _tools.first,
          first.commandId,
        );
        final otherRevision = first.copyWith(revision: first.revision + 1);
        final otherAction = AppAgentCommand(
          commandId: first.commandId,
          conversationId: first.conversationId,
          userAccountScope: first.userAccountScope,
          commandType: first.commandType,
          toolId: _tools[1],
          normalizedArguments: first.normalizedArguments,
          permission: first.permission,
          risk: first.risk,
          createdAt: first.createdAt,
          expiresAt: first.expiresAt,
          status: first.status,
          revision: first.revision,
        );

        final key = AppAgentBusinessIdentifiers.operationKey(first);
        expect(
          key.value,
          isNot(AppAgentBusinessIdentifiers.operationKey(otherScope).value),
        );
        expect(
          key.value,
          isNot(AppAgentBusinessIdentifiers.operationKey(otherRevision).value),
        );
        expect(
          key.value,
          isNot(AppAgentBusinessIdentifiers.operationKey(otherAction).value),
        );
        expect(key.toString(), isNot(contains(key.value)));
        expect(
          AppAgentBusinessIdentifiers.transactionId(first),
          isNot(AppAgentBusinessIdentifiers.transactionId(otherScope)),
        );
      },
    );

    test(
      'matching identity and amount cannot hide a wrong persisted status',
      () async {
        final command = _reconciliationCommand(
          session.ownerScopeValue,
          'createExpenseDraft',
          'wrong-status-expense',
        );
        final handler = ProductionFinancialCommandHandler.reconciliationOnly(
          toolId: command.toolId,
          risk: command.risk,
          session: session,
        );
        final operation = handler.businessOperationFor(command);
        final receipt = AppAgentExecutionReceipt(
          attemptId: 'attempt-wrong-status-expense',
          commandId: command.commandId,
          commandRevision: command.revision,
          operation: operation,
          claimedAt: DateTime.utc(2026, 7, 31, 12),
        );
        await _insertExpectedBusinessState(
          database,
          session.ownerScopeValue,
          command,
          operation,
        );
        await database.customStatement(
          'UPDATE transactions SET status = ? WHERE owner_scope_id = ? AND id = ?',
          <Object?>[
            'cancelled',
            session.ownerScopeValue,
            operation.expectedPersistedIdentifiers.single,
          ],
        );

        expect(
          (await handler.reconcileBusinessOperation(command, receipt)).status,
          AppAgentReconciliationStatus.inconsistent,
        );
      },
    );

    test('income reconciliation preserves pending and posted status', () async {
      for (final transactionStatus in <String>['pending', 'posted']) {
        final command = _reconciliationCommand(
          session.ownerScopeValue,
          'createIncomeDraft',
          'income-$transactionStatus',
          transactionStatus: transactionStatus,
        );
        final handler = ProductionFinancialCommandHandler.reconciliationOnly(
          toolId: command.toolId,
          risk: command.risk,
          session: session,
        );
        final operation = handler.businessOperationFor(command);
        final receipt = AppAgentExecutionReceipt(
          attemptId: 'attempt-income-$transactionStatus',
          commandId: command.commandId,
          commandRevision: command.revision,
          operation: operation,
          claimedAt: DateTime.utc(2026, 7, 31, 12),
        );
        await _insertExpectedBusinessState(
          database,
          session.ownerScopeValue,
          command,
          operation,
        );

        expect(
          (await handler.reconcileBusinessOperation(command, receipt)).status,
          AppAgentReconciliationStatus.verifiedSucceeded,
          reason: transactionStatus,
        );
        await database.customStatement(
          'UPDATE transactions SET status = ? WHERE owner_scope_id = ? AND id = ?',
          <Object?>[
            transactionStatus == 'pending' ? 'posted' : 'pending',
            session.ownerScopeValue,
            operation.expectedPersistedIdentifiers.single,
          ],
        );
        expect(
          (await handler.reconcileBusinessOperation(command, receipt)).status,
          AppAgentReconciliationStatus.inconsistent,
          reason: transactionStatus,
        );
      }
    });

    test(
      'legacy transaction commands without status default to posted',
      () async {
        final base = _reconciliationCommand(
          session.ownerScopeValue,
          'createIncomeDraft',
          'legacy-income-status',
        );
        final legacyArguments = Map<String, Object?>.from(
          base.normalizedArguments,
        )..remove('status');
        final command = AppAgentCommand(
          commandId: base.commandId,
          conversationId: base.conversationId,
          userAccountScope: base.userAccountScope,
          commandType: base.commandType,
          toolId: base.toolId,
          normalizedArguments: legacyArguments,
          permission: base.permission,
          risk: base.risk,
          createdAt: base.createdAt,
          expiresAt: base.expiresAt,
          status: base.status,
          revision: base.revision,
        );
        final handler = ProductionFinancialCommandHandler.reconciliationOnly(
          toolId: command.toolId,
          risk: command.risk,
          session: session,
        );
        final operation = handler.businessOperationFor(command);
        final receipt = AppAgentExecutionReceipt(
          attemptId: 'attempt-legacy-income-status',
          commandId: command.commandId,
          commandRevision: command.revision,
          operation: operation,
          claimedAt: DateTime.utc(2026, 7, 31, 12),
        );
        await _insertExpectedBusinessState(
          database,
          session.ownerScopeValue,
          command,
          operation,
        );

        expect(
          (await handler.reconcileBusinessOperation(command, receipt)).status,
          AppAgentReconciliationStatus.verifiedSucceeded,
        );
      },
    );

    test(
      'receipts must match every deterministic operation-spec field',
      () async {
        for (final tool in _tools) {
          final command = _reconciliationCommand(
            session.ownerScopeValue,
            tool,
            'forged-operation-$tool',
          );
          final handler = ProductionFinancialCommandHandler.reconciliationOnly(
            toolId: tool,
            risk: command.risk,
            session: session,
          );
          final expected = handler.businessOperationFor(command);
          await _insertExpectedBusinessState(
            database,
            session.ownerScopeValue,
            command,
            expected,
          );
          final wrongIdentifiers = <String>[
            ...expected.expectedPersistedIdentifiers,
          ];
          wrongIdentifiers[0] = 'forged-${wrongIdentifiers[0]}';
          final reorderedIdentifiers = <String>[
            ...expected.expectedPersistedIdentifiers.reversed,
          ];
          final forgeries = <String, AppAgentBusinessOperationSpec>{
            'key': _copyOperation(
              expected,
              key: const AppAgentBusinessOperationKey('forged-operation-key'),
            ),
            'entity type': _copyOperation(
              expected,
              expectedEntityType: 'forgedEntity',
            ),
            'persisted identifiers': _copyOperation(
              expected,
              expectedPersistedIdentifiers: wrongIdentifiers,
            ),
            if (reorderedIdentifiers.length > 1)
              'persisted identifier order': _copyOperation(
                expected,
                expectedPersistedIdentifiers: reorderedIdentifiers,
              ),
            'verification method': _copyOperation(
              expected,
              verificationMethod: 'forged_verification_method',
            ),
            'safe automatic resume': _copyOperation(
              expected,
              safeAutomaticResume: !expected.safeAutomaticResume,
            ),
            'automatic retry prohibition': _copyOperation(
              expected,
              automaticRetryProhibited: !expected.automaticRetryProhibited,
            ),
          };

          for (final forgery in forgeries.entries) {
            final receipt = AppAgentExecutionReceipt(
              attemptId: 'attempt-$tool-${forgery.key}',
              commandId: command.commandId,
              commandRevision: command.revision,
              operation: forgery.value,
              claimedAt: DateTime.utc(2026, 7, 31, 12),
            );
            expect(
              (await handler.reconcileBusinessOperation(
                command,
                receipt,
              )).status,
              AppAgentReconciliationStatus.inconsistent,
              reason: '$tool accepted a forged ${forgery.key}',
            );
          }
        }
      },
    );

    for (final entry in _persistedFieldCorruptions.entries) {
      test('${entry.key} rejects every command-bound field mismatch', () async {
        for (var index = 0; index < entry.value.length; index++) {
          final field = entry.value[index];
          final command = _reconciliationCommand(
            session.ownerScopeValue,
            entry.key,
            'wrong-field-${entry.key}-$index',
          );
          final handler = ProductionFinancialCommandHandler.reconciliationOnly(
            toolId: entry.key,
            risk: command.risk,
            session: session,
          );
          final operation = handler.businessOperationFor(command);
          await _insertExpectedBusinessState(
            database,
            session.ownerScopeValue,
            command,
            operation,
            corruptField: field,
          );
          final receipt = AppAgentExecutionReceipt(
            attemptId: 'attempt-${entry.key}-$index',
            commandId: command.commandId,
            commandRevision: command.revision,
            operation: operation,
            claimedAt: DateTime.utc(2026, 7, 31, 12),
          );

          expect(
            (await handler.reconcileBusinessOperation(command, receipt)).status,
            AppAgentReconciliationStatus.inconsistent,
            reason: '${entry.key} accepted the wrong persisted $field',
          );
        }
      });
    }

    test(
      'AppSuccess without its scoped row remains completion-uncertain',
      () async {
        final harness = _productionExpenseHarness(session);
        final bound = await _previewBoundExpense(
          harness,
          session.ownerScopeValue,
          'app-success-without-row',
        );

        final result = await harness.handler.executeConfirmed(bound.command);

        expect(harness.transactions.createCalls, 1);
        expect(result.verified, isFalse);
        expect(result.affectedCount, 0);
        expect(result.completionUncertain, isTrue);
        expect(
          result.safeFailureCode,
          AppAgentFailureCodes.recoveryNotExecuted,
        );
      },
    );

    test(
      'AppSuccess with an inconsistent scoped row remains completion-uncertain',
      () async {
        final harness = _productionExpenseHarness(session);
        final bound = await _previewBoundExpense(
          harness,
          session.ownerScopeValue,
          'app-success-inconsistent-row',
        );
        harness.transactions.onCreate = (_) => _insertExpectedBusinessState(
          database,
          session.ownerScopeValue,
          bound.command,
          bound.operation,
          corruptField: 'status',
        );

        final result = await harness.handler.executeConfirmed(bound.command);

        expect(harness.transactions.createCalls, 1);
        expect(result.verified, isFalse);
        expect(result.affectedCount, 0);
        expect(result.completionUncertain, isTrue);
        expect(
          result.safeFailureCode,
          AppAgentFailureCodes.recoveryInconsistent,
        );
      },
    );

    test(
      'AppSuccess is verified only after exact immediate reconciliation',
      () async {
        final harness = _productionExpenseHarness(session);
        final bound = await _previewBoundExpense(
          harness,
          session.ownerScopeValue,
          'app-success-exact-row',
        );
        harness.transactions.onCreate = (_) => _insertExpectedBusinessState(
          database,
          session.ownerScopeValue,
          bound.command,
          bound.operation,
        );

        final result = await harness.handler.executeConfirmed(bound.command);

        expect(harness.transactions.createCalls, 1);
        expect(result.verified, isTrue);
        expect(result.affectedCount, 1);
        expect(result.completionUncertain, isFalse);
        expect(result.safeFailureCode, isNull);
      },
    );

    test(
      'durable income persistence keeps complete typed preview and status',
      () async {
        final timestamp = DateTime.utc(2026, 8, 16, 9, 30);
        final account = Account.create(
          id: 'account-source',
          name: 'Income account',
          type: AccountType.cash,
          currencyCode: 'LYD',
          balance: Decimal.zero,
          icon: 'wallet',
          color: 1,
          createdAt: timestamp,
          updatedAt: timestamp,
        );
        final category = Category.create(
          id: 'category-financial',
          name: 'Other Income',
          type: CategoryType.income,
          icon: const CategoryIcon(key: 'tag'),
          color: const CategoryColor(argb: 1),
          createdAt: timestamp,
          updatedAt: timestamp,
        );
        final accounts = _MutableAccountsRepository(account);
        final categories = _StaticCategoriesRepository(category);
        final transactions = _AppSuccessTransactionsRepository();
        final resolver = DurableAiActionResolver(
          accounts: accounts,
          categories: categories,
          payees: _UnusedPayeesRepository(),
          budgets: _UnusedBudgetRepository(),
          goals: _UnusedGoalRepository(),
        );
        final handler = ProductionFinancialCommandHandler(
          toolId: 'createIncomeDraft',
          risk: AgentActionRisk.low,
          resolver: resolver,
          executor: AiActionExecutor(
            createTransaction: CreateTransaction(transactions),
            createTransfer: CreateTransfer(transactions),
            validator: const AiActionValidator(),
          ),
          session: session,
        );
        final registry = MapAppAgentCommandHandlerRegistry([handler]);
        final commandStore = DriftAppAgentCommandStore(
          session: session,
          canonicalDescriptors: const <AppAgentModelProposalDescriptor>[
            AppAgentModelProposalDescriptor(
              toolId: 'createIncomeDraft',
              permission: AgentPermission.createDraft,
              risk: AgentActionRisk.low,
              modelCallable: false,
            ),
          ],
        );
        final proofStore = DriftAppAgentConfirmationProofStore(session);
        final durableStore = DriftAppAgentDurableExecutionStore(session);
        final confirmationController = AppAgentConfirmationController(
          commandStore: commandStore,
          proofStore: proofStore,
        );
        final bridge = DurableAiActionBridge(
          commandStore: commandStore,
          confirmationController: confirmationController,
          commandExecutor: AppAgentCommandExecutor(
            commandStore: commandStore,
            auditStore: DriftAppAgentAuditStore(session),
            proofStore: proofStore,
            handlerRegistry: registry,
            accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
            durableExecutionStore: durableStore,
          ),
          handlerRegistry: registry,
          executionStore: durableStore,
          resolver: resolver,
          currentScope: () => session.ownerScopeValue,
          canExecuteConfirmedCreate: (_) => true,
        );
        final draft = AiActionDraft.create(
          action: CreateIncomeDraft(
            AiTransactionDraft(
              type: TransactionType.income,
              amount: Money(amount: Decimal.fromInt(1000), currencyCode: 'LYD'),
              account: account,
              category: category,
              paymentMethod: PaymentMethod.cash,
              paymentMethodDefinition: null,
              note: 'Debt repayment',
              payeeHint: 'Salem',
              incomeSourceSuggestion: const IncomeSourceSuggestion(
                sourceType: IncomeSourceType.debtRepayment,
                sourceNameHint: 'Salem',
                confidence: 100,
                source: IncomeSourceSuggestionSource.explicitUserInput,
                requiresClarification: false,
              ),
              transactionDate: timestamp,
              status: TransactionStatus.pending,
            ),
          ),
        );

        final command = await bridge.persistDraft(draft);
        final preview = await commandStore.readPreview(
          commandId: command.commandId,
          accountScope: session.ownerScopeValue,
        );
        final previewFields = <String, String>{
          for (final field in preview!.fields) field.label: field.proposedValue,
        };

        expect(command.normalizedArguments['status'], 'pending');
        expect(
          command.normalizedArguments['transactionDate'],
          timestamp.toIso8601String(),
        );
        expect(
          command.normalizedArguments['incomeSourceType'],
          'debt_repayment',
        );
        expect(command.normalizedArguments['incomeSourceIdentity'], 'Salem');
        expect(
          command.normalizedArguments['note'],
          'Debt repayment\nSource: Salem',
        );
        expect(previewFields['Amount'], 'LYD 1000');
        expect(previewFields['Destination account'], 'Income account');
        expect(previewFields['Category'], 'Other Income');
        expect(previewFields['Source classification'], 'debt_repayment');
        expect(previewFields['Source identity'], 'Salem');
        expect(previewFields['Date'], timestamp.toIso8601String());
        expect(previewFields['Status'], 'pending');
        expect(previewFields['Payment method'], 'cash');
        expect(previewFields['Note'], 'Debt repayment\nSource: Salem');

        final restored = await bridge.restoreLatestPendingDraft();
        final restoredAction = restored!.action as CreateIncomeDraft;
        expect(
          restoredAction.transactionDraft.status,
          TransactionStatus.pending,
        );
        expect(restoredAction.transactionDraft.transactionDate, timestamp);
        expect(
          restoredAction.transactionDraft.incomeSourceSuggestion?.sourceType,
          IncomeSourceType.debtRepayment,
        );
        expect(
          restoredAction
              .transactionDraft
              .incomeSourceSuggestion
              ?.sourceNameHint,
          'Salem',
        );

        final operation = handler.businessOperationFor(command);
        transactions.onCreate = (transaction) async {
          expect(transaction.status, TransactionStatus.pending);
          expect(transaction.transactionDate, timestamp);
          expect(transaction.incomeSourceType, IncomeSourceType.debtRepayment);
          expect(transaction.note, 'Debt repayment\nSource: Salem');
          await _insertExpectedBusinessState(
            database,
            session.ownerScopeValue,
            command,
            operation,
          );
        };

        final result = await bridge.confirmAndExecute(command.commandId);
        await bridge.confirmAndExecute(command.commandId);
        final row =
            await (database.select(database.transactions)..where(
                  (row) =>
                      row.ownerScopeId.equals(session.ownerScopeValue) &
                      row.id.equals(
                        operation.expectedPersistedIdentifiers.single,
                      ),
                ))
                .getSingle();

        expect(result.verified, isTrue);
        expect(result.affectedCount, 1);
        expect(transactions.createCalls, 1);
        expect(row.status, 'pending');
        expect(row.transactionDate.toUtc(), timestamp);
        expect(row.incomeSourceType, 'debt_repayment');
        expect(row.note, 'Debt repayment\nSource: Salem');
      },
    );

    test(
      'a reference revision change after preview never reaches the use case',
      () async {
        final harness = _productionExpenseHarness(session);
        final bound = await _previewBoundExpense(
          harness,
          session.ownerScopeValue,
          'reference-changed-after-preview',
        );
        harness.accounts.account = harness.accounts.account.copyWith(
          balance: Decimal.one,
          updatedAt: harness.accounts.account.updatedAt.add(
            const Duration(seconds: 1),
          ),
        );

        final result = await harness.handler.executeConfirmed(bound.command);

        expect(harness.transactions.createCalls, 0);
        expect(result.verified, isFalse);
        expect(result.affectedCount, 0);
        expect(result.completionUncertain, isFalse);
        expect(result.safeFailureCode, AppAgentFailureCodes.stalePreview);
      },
    );

    test(
      'a contribution created after preview never reaches the use case',
      () async {
        final harness = _productionContributionHarness(session);
        final bound = await _previewBoundContribution(
          harness,
          session.ownerScopeValue,
          'contribution-created-after-preview',
        );
        harness.goals.contributions = <GoalContribution>[
          GoalContribution.create(
            id: bound.operation.expectedPersistedIdentifiers.single,
            goalId: 'goal-parent',
            amount: Decimal.fromInt(10),
            currency: 'LYD',
            date: DateTime.utc(2026, 7, 31, 11, 40),
            note: 'concurrent contribution',
          ),
        ];

        final result = await harness.handler.executeConfirmed(bound.command);

        expect(harness.goals.addContributionCalls, 0);
        expect(result.verified, isFalse);
        expect(result.affectedCount, 0);
        expect(result.completionUncertain, isFalse);
        expect(result.safeFailureCode, AppAgentFailureCodes.stalePreview);
      },
    );
  });

  test(
    'all eight crash points are deterministic for every supported handler',
    () async {
      final database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      addTearDown(database.close);
      final session = scopedTestSession(database);
      await database.customSelect('SELECT 1').get();
      final commandStore = _commandStore(session);
      final proofStore = DriftAppAgentConfirmationProofStore(session);
      final durableStore = DriftAppAgentDurableExecutionStore(session);

      for (final tool in _tools) {
        for (final point in AppAgentExecutionCrashPoint.values) {
          final id = 'crash-${tool.hashCode}-${point.index}';
          final proposed = _reconciliationCommand(
            session.ownerScopeValue,
            tool,
            id,
            status: AppAgentCommandStatus.readyForPreview,
            revision: 0,
          );
          await commandStore.saveTrustedLocalCommand(proposed);
          await commandStore.savePreview(
            preview: _preview(id),
            accountScope: session.ownerScopeValue,
          );
          final decision =
              await AppAgentConfirmationController(
                commandStore: commandStore,
                proofStore: proofStore,
                clock: () => DateTime.utc(2026, 7, 31, 12),
              ).confirm(
                commandId: id,
                accountScope: session.ownerScopeValue,
                method: AppAgentConfirmationMethod.primaryButton,
              );
          final committed = <String>{};
          final handler = _CrashReconciliableHandler(tool, committed);
          final registry = MapAppAgentCommandHandlerRegistry([handler]);
          final executor = AppAgentCommandExecutor(
            commandStore: commandStore,
            auditStore: DriftAppAgentAuditStore(session),
            proofStore: proofStore,
            handlerRegistry: registry,
            accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
            durableExecutionStore: durableStore,
            clock: () => DateTime.utc(2026, 7, 31, 12, 0, 1),
            faultInjector: _SingleCrashInjector(point),
          );

          await expectLater(
            executor.execute(decision.confirmation!),
            throwsA(
              isA<AppAgentSimulatedProcessInterruption>().having(
                (error) => error.point,
                'point',
                point,
              ),
            ),
            reason: '$tool at ${point.name}',
          );

          final summary = await AppAgentStartupReconciler(
            commandStore: commandStore,
            executionStore: durableStore,
            handlerRegistry: registry,
          ).reconcile();
          final persisted = await commandStore.readCommand(
            commandId: id,
            accountScope: session.ownerScopeValue,
          );
          final commitsForCommand = committed.where(
            (value) => value.contains(id),
          );

          switch (point) {
            case AppAgentExecutionCrashPoint.beforeExecutionClaim:
              expect(persisted?.status, AppAgentCommandStatus.confirmed);
              expect(summary.confirmedPendingCount, greaterThanOrEqualTo(1));
              expect(commitsForCommand, isEmpty);
            case AppAgentExecutionCrashPoint.afterExecutionClaim ||
                AppAgentExecutionCrashPoint.beforeBusinessUseCase ||
                AppAgentExecutionCrashPoint.duringBusinessTransaction:
              expect(persisted?.status, AppAgentCommandStatus.failed);
              expect(commitsForCommand, isEmpty);
            case AppAgentExecutionCrashPoint.afterBusinessCommit ||
                AppAgentExecutionCrashPoint.beforeDurableResultSave ||
                AppAgentExecutionCrashPoint.afterDurableResultSave ||
                AppAgentExecutionCrashPoint.beforeUiReceivesResult:
              expect(persisted?.status, AppAgentCommandStatus.succeeded);
              expect(commitsForCommand, hasLength(1));
              expect(
                await durableStore.readVerifiedResult(id),
                isNotNull,
                reason: '$tool lost a verified commit at ${point.name}',
              );
              expect(
                summary.reconciledResults.any(
                  (result) => result.commandId == id,
                ),
                isTrue,
                reason: '$tool did not restore its result after ${point.name}',
              );
              await durableStore.acknowledgeUiDelivery(id);
              final afterUiAcknowledgement = await AppAgentStartupReconciler(
                commandStore: commandStore,
                executionStore: durableStore,
                handlerRegistry: registry,
              ).reconcile();
              expect(
                afterUiAcknowledgement.reconciledResults.any(
                  (result) => result.commandId == id,
                ),
                isFalse,
              );
          }

          final beforeDuplicateAttempt = committed.length;
          final retryResult = await executor.execute(decision.confirmation!);
          if (point == AppAgentExecutionCrashPoint.beforeExecutionClaim) {
            // No durable authority was consumed before the atomic claim, so
            // the still-running session may explicitly resubmit the original
            // proof. Startup recovery itself never reconstructs that proof or
            // executes the command.
            expect(retryResult.verified, isTrue);
            expect(
              committed.length,
              beforeDuplicateAttempt + 1,
              reason:
                  '$tool did not execute exactly once after a pre-claim retry',
            );
          } else {
            expect(
              committed.length,
              beforeDuplicateAttempt,
              reason: '$tool executed twice after ${point.name}',
            );
          }
          expect(
            await database
                .customSelect(
                  'SELECT COUNT(*) AS value FROM ai_agent_business_operations '
                  'WHERE owner_scope_id = ? AND command_id = ?',
                  variables: <Variable<Object>>[
                    Variable<String>(session.ownerScopeValue),
                    Variable<String>(id),
                  ],
                )
                .map((row) => row.read<int>('value'))
                .getSingle(),
            1,
          );
          if (point == AppAgentExecutionCrashPoint.afterExecutionClaim) {
            final otherScope = scopedTestSession(
              database,
              syntheticFirebaseUid: 'crash-recovery-owner-b',
            );
            final forged = AppAgentCommand(
              commandId: id,
              conversationId: proposed.conversationId,
              userAccountScope: otherScope.ownerScopeValue,
              commandType: proposed.commandType,
              toolId: proposed.toolId,
              normalizedArguments: proposed.normalizedArguments,
              permission: proposed.permission,
              risk: proposed.risk,
              createdAt: proposed.createdAt,
              expiresAt: proposed.expiresAt,
              status: AppAgentCommandStatus.executing,
              revision: 1,
            );
            expect(
              await DriftAppAgentDurableExecutionStore(
                otherScope,
              ).readExecutionReceipt(forged),
              isNull,
            );
          }
        }
      }
    },
  );
}

DriftAppAgentCommandStore _commandStore(ScopedAppDatabaseSession session) {
  return DriftAppAgentCommandStore(
    session: session,
    canonicalDescriptors: _tools.map(
      (tool) => AppAgentModelProposalDescriptor(
        toolId: tool,
        permission: AgentPermission.createDraft,
        risk: AgentActionRisk.medium,
        modelCallable: false,
      ),
    ),
  );
}

AppAgentPreview _preview(String commandId) => AppAgentPreview(
  commandId: commandId,
  title: 'Synthetic financial create',
  entityType: 'financialEntity',
  fields: const [
    AppAgentPreviewField(label: 'Amount', proposedValue: 'LYD 10'),
  ],
  risk: AgentActionRisk.medium,
  confirmationLevel: AppAgentConfirmationLevel.detailed,
  stateFingerprint: 'state-fingerprint-v1',
  createdAt: DateTime.utc(2026, 7, 31, 12),
);

AppAgentBusinessOperationSpec _copyOperation(
  AppAgentBusinessOperationSpec operation, {
  AppAgentBusinessOperationKey? key,
  String? expectedEntityType,
  List<String>? expectedPersistedIdentifiers,
  String? verificationMethod,
  bool? safeAutomaticResume,
  bool? automaticRetryProhibited,
}) => AppAgentBusinessOperationSpec(
  key: key ?? operation.key,
  expectedEntityType: expectedEntityType ?? operation.expectedEntityType,
  expectedPersistedIdentifiers:
      expectedPersistedIdentifiers ?? operation.expectedPersistedIdentifiers,
  verificationMethod: verificationMethod ?? operation.verificationMethod,
  safeAutomaticResume: safeAutomaticResume ?? operation.safeAutomaticResume,
  automaticRetryProhibited:
      automaticRetryProhibited ?? operation.automaticRetryProhibited,
);

AppAgentCommand _reconciliationCommand(
  String scope,
  String tool,
  String id, {
  AppAgentCommandStatus status = AppAgentCommandStatus.executing,
  int revision = 1,
  String transactionStatus = 'posted',
}) {
  final arguments = switch (tool) {
    'createExpenseDraft' => <String, Object?>{
      'accountId': 'account-source',
      'categoryId': 'category-financial',
      'amount': '10',
      'currency': 'LYD',
      'transactionType': 'expense',
      'paymentMethod': 'cash',
      'status': transactionStatus,
      'note': 'expense note',
      'transactionDate': '2026-07-31T12:00:00.000Z',
    },
    'createIncomeDraft' => <String, Object?>{
      'accountId': 'account-source',
      'categoryId': 'category-financial',
      'amount': '10',
      'currency': 'LYD',
      'transactionType': 'income',
      'paymentMethod': 'cash',
      'status': transactionStatus,
      'note': 'income note',
      'transactionDate': '2026-07-31T12:00:00.000Z',
      'incomeSourceType': 'businessRevenue',
    },
    'createTransferDraft' => <String, Object?>{
      'sourceAccountId': 'account-source',
      'destinationAccountId': 'account-destination',
      'sourceAmount': '10',
      'sourceCurrency': 'LYD',
      'destinationAmount': '20',
      'destinationCurrency': 'EUR',
      'exchangeRate': '2',
      'exchangeRateAsOf': '2026-07-31T11:55:00.000Z',
      'note': 'transfer note',
    },
    'createBudgetDraft' => <String, Object?>{
      'budget': <String, Object?>{
        'id': 'budget-$id',
        'name': 'Household budget $id',
        'categoryId': 'category-financial',
        'amount': '100',
        'currency': 'LYD',
        'periodType': 'monthly',
        'startDate': '2026-08-01T00:00:00.000Z',
        'endDate': '2026-09-01T00:00:00.000Z',
        'alertThresholdPercent': 80,
        'isActive': true,
        'createdAt': '2026-07-31T11:30:00.000Z',
        'updatedAt': '2026-07-31T11:45:00.000Z',
        'archivedAt': null,
      },
    },
    'createGoalDraft' => <String, Object?>{
      'goal': <String, Object?>{
        'id': 'goal-$id',
        'title': 'Emergency reserve $id',
        'description': 'Six-month reserve',
        'type': 'emergencyFund',
        'targetAmount': '100',
        'currentAmount': '5',
        'currency': 'LYD',
        'linkedAccountId': 'account-source',
        'targetDate': '2027-07-31T00:00:00.000Z',
        'icon': 'shield',
        'color': 4278255360,
        'status': 'active',
        'createdAt': '2026-07-31T11:30:00.000Z',
        'updatedAt': '2026-07-31T11:45:00.000Z',
        'archivedAt': null,
        'completedAt': null,
      },
    },
    'createGoalContributionDraft' => <String, Object?>{
      'contribution': <String, Object?>{
        'id': 'contribution-$id',
        'goalId': 'goal-parent',
        'amount': '10',
        'currency': 'LYD',
        'creditedAmount': null,
        'date': '2026-07-31T11:40:00.000Z',
        'note': 'monthly savings',
        'linkedTransactionId': 'linked-transaction-$id',
        'createdAt': '2026-07-31T11:41:00.000Z',
        'updatedAt': '2026-07-31T11:42:00.000Z',
        'reversedAt': null,
      },
    },
    _ => const <String, Object?>{},
  };
  return AppAgentCommand(
    commandId: id,
    conversationId: 'reconciliation-test',
    userAccountScope: scope,
    commandType: AppAgentCommandType.create,
    toolId: tool,
    normalizedArguments: arguments,
    permission: AgentPermission.createDraft,
    risk: AgentActionRisk.medium,
    createdAt: DateTime.utc(2026, 7, 31, 12),
    expiresAt: DateTime.utc(2026, 7, 31, 12, 15),
    status: status,
    revision: revision,
  );
}

Future<void> _seedBusinessReferences(AppDatabase database, String scope) async {
  for (final entry in const <(String, String, String)>[
    ('account-source', 'Source', 'LYD'),
    ('account-destination', 'Destination', 'EUR'),
  ]) {
    await database.customStatement(
      'INSERT INTO accounts (id, owner_scope_id, name, type, currency_code, '
      'balance, icon, color, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        entry.$1,
        scope,
        entry.$2,
        'cash',
        entry.$3,
        // Reconciliation only needs scoped account references. Accounts must
        // be created at zero; non-zero opening value belongs in the ledger.
        '0',
        'wallet',
        1,
        1,
        1,
      ],
    );
  }
  for (final entry in const <(String, String)>[
    ('category-financial', 'Test'),
    ('category-financial-alt', 'Alternate'),
  ]) {
    await database.customStatement(
      'INSERT INTO categories (id, owner_scope_id, name, type, icon, color, '
      'sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[entry.$1, scope, entry.$2, 'expense', 'tag', 1, 0, 1, 1],
    );
  }
  final transferDefinition = defaultCategoryDefinitions.singleWhere(
    (candidate) => candidate.id == defaultTransferCategoryId,
  );
  await database.customStatement(
    'INSERT INTO categories (id, owner_scope_id, name, type, icon, color, '
    'sort_order, is_default, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      transferDefinition.id,
      null,
      transferDefinition.name,
      transferDefinition.type.name,
      transferDefinition.iconKey,
      transferDefinition.colorArgb,
      transferDefinition.sortOrder,
      1,
      1,
      1,
    ],
  );
  for (final entry in const <(String, String)>[
    ('goal-parent', 'Parent'),
    ('goal-parent-alt', 'Alternate parent'),
  ]) {
    await database.customStatement(
      'INSERT INTO goals (id, owner_scope_id, title, type, target_amount, '
      'current_amount, currency, icon, color, status, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        entry.$1,
        scope,
        entry.$2,
        'savings',
        '100',
        '0',
        'LYD',
        'goal',
        1,
        'active',
        1,
        1,
      ],
    );
  }
}

Future<void> _insertExpectedBusinessState(
  AppDatabase database,
  String scope,
  AppAgentCommand command,
  AppAgentBusinessOperationSpec operation, {
  String? corruptField,
}) async {
  final ids = operation.expectedPersistedIdentifiers;
  final args = command.normalizedArguments;
  switch (command.toolId) {
    case 'createExpenseDraft' || 'createIncomeDraft':
      final incomeSourceArgument = args['incomeSourceType']?.toString();
      final expectedIncomeSource = switch (incomeSourceArgument) {
        'businessRevenue' => 'business_revenue',
        'rentalIncome' => 'rental_income',
        'governmentSupport' => 'government_support',
        'investmentReturn' => 'investment_return',
        'debtRepayment' => 'debt_repayment',
        'loanProceeds' => 'loan_proceeds',
        'externalTransfer' => 'external_transfer',
        _ => incomeSourceArgument,
      };
      final transactionDate = _requiredUtc(args, 'transactionDate');
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: ids.single,
              ownerScopeId: Value(scope),
              accountId: args['accountId']!.toString(),
              categoryId: args['categoryId']!.toString(),
              payeeId: Value<String?>(args['payeeId']?.toString()),
              amount: args['amount']!.toString(),
              currencyCode: args['currency']!.toString(),
              type: args['transactionType']!.toString(),
              paymentMethod: args['paymentMethod']!.toString(),
              source: 'aiGenerated',
              status: corruptField == 'status'
                  ? 'cancelled'
                  : args['status']?.toString() ?? 'posted',
              incomeSourceType: Value<String?>(
                corruptField == 'incomeSourceType'
                    ? expectedIncomeSource == null
                          ? 'salary'
                          : 'salary'
                    : expectedIncomeSource,
              ),
              note: Value<String?>(
                corruptField == 'note'
                    ? 'persisted note does not match'
                    : args['note']?.toString(),
              ),
              transactionDate: corruptField == 'transactionDate'
                  ? transactionDate.add(const Duration(minutes: 1))
                  : transactionDate,
              attachmentCount: const Value(0),
              aiConfidence: Value<int?>(
                expectedIncomeSource == null ? 90 : 100,
              ),
              needsReview: const Value(false),
              createdAt: command.createdAt.toUtc(),
              updatedAt: command.createdAt.toUtc(),
            ),
          );
      return;
    case 'createTransferDraft':
      final occurredAt = command.createdAt.toUtc();
      final exchangeRateAsOf = _requiredUtc(args, 'exchangeRateAsOf');
      final status = corruptField == 'status' ? 'cancelled' : 'posted';
      final note = corruptField == 'note'
          ? 'persisted transfer note does not match'
          : args['note']?.toString();
      final exchangeRate = corruptField == 'exchangeRate'
          ? '3'
          : args['exchangeRate']!.toString();
      final persistedRateAsOf = corruptField == 'exchangeRateAsOf'
          ? exchangeRateAsOf.add(const Duration(days: 1))
          : exchangeRateAsOf;
      final persistedDate = corruptField == 'transactionDate'
          ? occurredAt.subtract(const Duration(minutes: 1))
          : occurredAt;
      TransactionsCompanion leg({
        required String id,
        required String accountId,
        required String type,
        required String amount,
        required String currency,
      }) => TransactionsCompanion(
        id: Value(id),
        ownerScopeId: Value(scope),
        accountId: Value(accountId),
        categoryId: const Value(defaultTransferCategoryId),
        amount: Value(amount),
        currencyCode: Value(currency),
        type: Value(type),
        paymentMethod: const Value('bankTransfer'),
        source: const Value('aiGenerated'),
        status: Value(status),
        transferGroupId: Value(ids[0]),
        exchangeRateFromCurrencyCode: Value(args['sourceCurrency']!.toString()),
        exchangeRateToCurrencyCode: Value(
          args['destinationCurrency']!.toString(),
        ),
        exchangeRate: Value(exchangeRate),
        exchangeRateAsOf: Value(persistedRateAsOf),
        note: Value<String?>(note),
        transactionDate: Value(persistedDate),
        attachmentCount: const Value(0),
        aiConfidence: const Value<int?>(null),
        needsReview: const Value(false),
        createdAt: Value(occurredAt),
        updatedAt: Value(occurredAt),
      );
      await database.insertTransferPair(
        ownerScopeId: scope,
        payloadFingerprint: List<String>.filled(64, 'a').join(),
        outgoing: leg(
          id: ids[1],
          accountId: args['sourceAccountId']!.toString(),
          type: 'transferOut',
          amount: args['sourceAmount']!.toString(),
          currency: args['sourceCurrency']!.toString(),
        ),
        incoming: leg(
          id: ids[2],
          accountId: args['destinationAccountId']!.toString(),
          type: 'transferIn',
          amount: args['destinationAmount']!.toString(),
          currency: args['destinationCurrency']!.toString(),
        ),
      );
      return;
    case 'createBudgetDraft':
      final budget = _nestedArguments(command, 'budget');
      final startDate = _requiredUtc(budget, 'startDate');
      final endDate = _requiredUtc(budget, 'endDate');
      final createdAt = _requiredUtc(budget, 'createdAt');
      final updatedAt = _requiredUtc(budget, 'updatedAt');
      await database
          .into(database.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: ids.single,
              ownerScopeId: Value(scope),
              name: corruptField == 'name'
                  ? 'Wrong persisted budget name'
                  : budget['name']!.toString(),
              categoryId: corruptField == 'categoryId'
                  ? 'category-financial-alt'
                  : budget['categoryId']!.toString(),
              amount: corruptField == 'amount'
                  ? '101'
                  : budget['amount']!.toString(),
              currency: corruptField == 'currency'
                  ? 'EUR'
                  : budget['currency']!.toString(),
              periodType: corruptField == 'periodType'
                  ? 'weekly'
                  : budget['periodType']!.toString(),
              startDate: corruptField == 'startDate'
                  ? startDate.add(const Duration(days: 1))
                  : startDate,
              endDate: corruptField == 'endDate'
                  ? endDate.subtract(const Duration(days: 1))
                  : endDate,
              alertThresholdPercent: corruptField == 'alertThresholdPercent'
                  ? 81
                  : (budget['alertThresholdPercent']! as num).toInt(),
              isActive: Value(
                corruptField == 'isActive'
                    ? !(budget['isActive']! as bool)
                    : budget['isActive']! as bool,
              ),
              createdAt: corruptField == 'createdAt'
                  ? createdAt.subtract(const Duration(minutes: 1))
                  : createdAt,
              updatedAt: corruptField == 'updatedAt'
                  ? updatedAt.add(const Duration(minutes: 1))
                  : updatedAt,
              archivedAt: Value<DateTime?>(
                corruptField == 'archivedAt'
                    ? DateTime.utc(2026, 8, 2)
                    : _optionalUtc(budget['archivedAt']),
              ),
            ),
          );
      return;
    case 'createGoalDraft':
      final goal = _nestedArguments(command, 'goal');
      final targetDate = _optionalUtc(goal['targetDate']);
      final createdAt = _requiredUtc(goal, 'createdAt');
      final updatedAt = _requiredUtc(goal, 'updatedAt');
      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              id: ids.single,
              ownerScopeId: Value(scope),
              title: corruptField == 'title'
                  ? 'Wrong persisted goal title'
                  : goal['title']!.toString(),
              description: Value(
                corruptField == 'description'
                    ? 'Wrong persisted description'
                    : goal['description']!.toString(),
              ),
              type: corruptField == 'type'
                  ? 'purchase'
                  : _goalTypeStorage(goal['type']!.toString()),
              targetAmount: corruptField == 'targetAmount'
                  ? '101'
                  : goal['targetAmount']!.toString(),
              currentAmount: corruptField == 'currentAmount'
                  ? '6'
                  : goal['currentAmount']!.toString(),
              currency: corruptField == 'currency'
                  ? 'EUR'
                  : goal['currency']!.toString(),
              linkedAccountId: Value<String?>(
                corruptField == 'linkedAccountId'
                    ? 'account-destination'
                    : goal['linkedAccountId']?.toString(),
              ),
              targetDate: Value<DateTime?>(
                corruptField == 'targetDate'
                    ? targetDate!.add(const Duration(days: 1))
                    : targetDate,
              ),
              icon: corruptField == 'icon'
                  ? 'wrong-icon'
                  : goal['icon']!.toString(),
              color: corruptField == 'color'
                  ? 4278190335
                  : (goal['color']! as num).toInt(),
              status: corruptField == 'status'
                  ? 'paused'
                  : goal['status']!.toString(),
              createdAt: corruptField == 'createdAt'
                  ? createdAt.subtract(const Duration(minutes: 1))
                  : createdAt,
              updatedAt: corruptField == 'updatedAt'
                  ? updatedAt.add(const Duration(minutes: 1))
                  : updatedAt,
              archivedAt: Value<DateTime?>(
                corruptField == 'archivedAt'
                    ? DateTime.utc(2026, 8, 2)
                    : _optionalUtc(goal['archivedAt']),
              ),
              completedAt: Value<DateTime?>(
                corruptField == 'completedAt'
                    ? DateTime.utc(2026, 8, 3)
                    : _optionalUtc(goal['completedAt']),
              ),
            ),
          );
      return;
    case 'createGoalContributionDraft':
      final contribution = _nestedArguments(command, 'contribution');
      final date = _requiredUtc(contribution, 'date');
      final createdAt = _requiredUtc(contribution, 'createdAt');
      final updatedAt = _requiredUtc(contribution, 'updatedAt');
      final expectedCreditedAmount =
          contribution['creditedAmount']?.toString() ??
          contribution['amount']!.toString();
      final persistedLinkedTransactionId = corruptField == 'linkedTransactionId'
          ? 'wrong-linked-transaction'
          : contribution['linkedTransactionId']?.toString();
      await database
          .into(database.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: persistedLinkedTransactionId!,
              ownerScopeId: Value(scope),
              accountId: 'account-source',
              categoryId: 'category-financial',
              amount: '10',
              currencyCode: 'LYD',
              type: 'expense',
              paymentMethod: 'cash',
              source: 'manual',
              status: 'pending',
              transactionDate: date,
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
      await database
          .into(database.goalContributions)
          .insert(
            GoalContributionsCompanion.insert(
              id: ids.single,
              ownerScopeId: Value(scope),
              goalId: corruptField == 'goalId'
                  ? 'goal-parent-alt'
                  : contribution['goalId']!.toString(),
              amount: corruptField == 'amount'
                  ? '11'
                  : contribution['amount']!.toString(),
              currency: corruptField == 'currency'
                  ? 'EUR'
                  : contribution['currency']!.toString(),
              creditedAmount: corruptField == 'creditedAmount'
                  ? '11'
                  : expectedCreditedAmount,
              date: corruptField == 'date'
                  ? date.add(const Duration(minutes: 1))
                  : date,
              note: Value(
                corruptField == 'note'
                    ? 'Wrong persisted contribution note'
                    : contribution['note']!.toString(),
              ),
              linkedTransactionId: Value<String?>(persistedLinkedTransactionId),
              createdAt: corruptField == 'createdAt'
                  ? createdAt.subtract(const Duration(minutes: 1))
                  : createdAt,
              updatedAt: corruptField == 'updatedAt'
                  ? updatedAt.add(const Duration(minutes: 1))
                  : updatedAt,
              reversedAt: Value<DateTime?>(
                corruptField == 'reversedAt'
                    ? DateTime.utc(2026, 8, 2)
                    : _optionalUtc(contribution['reversedAt']),
              ),
            ),
          );
      return;
  }
}

Map<String, Object?> _nestedArguments(AppAgentCommand command, String key) {
  final value = command.normalizedArguments[key];
  if (value is! Map) throw StateError('Missing $key test arguments.');
  return Map<String, Object?>.from(value);
}

DateTime _requiredUtc(Map<String, Object?> values, String key) {
  final parsed = _optionalUtc(values[key]);
  if (parsed == null) throw StateError('Missing $key test timestamp.');
  return parsed;
}

DateTime? _optionalUtc(Object? value) =>
    value == null ? null : DateTime.parse(value.toString()).toUtc();

String _goalTypeStorage(String value) => switch (value) {
  'emergencyFund' => 'emergency_fund',
  'debtPayoff' => 'debt_payoff',
  _ => value,
};

_ProductionExpenseHarness _productionExpenseHarness(
  ScopedAppDatabaseSession session,
) {
  final timestamp = DateTime.utc(2026, 7, 31, 10);
  final accounts = _MutableAccountsRepository(
    Account.create(
      id: 'account-source',
      name: 'Source',
      type: AccountType.cash,
      currencyCode: 'LYD',
      balance: Decimal.zero,
      icon: 'wallet',
      color: 1,
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
  final categories = _StaticCategoriesRepository(
    Category.create(
      id: 'category-financial',
      name: 'Test',
      type: CategoryType.expense,
      icon: const CategoryIcon(key: 'tag'),
      color: const CategoryColor(argb: 1),
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
  final transactions = _AppSuccessTransactionsRepository();
  final resolver = DurableAiActionResolver(
    accounts: accounts,
    categories: categories,
    payees: _UnusedPayeesRepository(),
    budgets: _UnusedBudgetRepository(),
    goals: _UnusedGoalRepository(),
  );
  final handler = ProductionFinancialCommandHandler(
    toolId: 'createExpenseDraft',
    risk: AgentActionRisk.medium,
    resolver: resolver,
    executor: AiActionExecutor(
      createTransaction: CreateTransaction(transactions),
      createTransfer: CreateTransfer(transactions),
      validator: const AiActionValidator(),
    ),
    session: session,
  );
  return _ProductionExpenseHarness(
    handler: handler,
    accounts: accounts,
    transactions: transactions,
  );
}

Future<({AppAgentCommand command, AppAgentBusinessOperationSpec operation})>
_previewBoundExpense(
  _ProductionExpenseHarness harness,
  String scope,
  String commandId,
) async {
  final proposed = _reconciliationCommand(
    scope,
    'createExpenseDraft',
    commandId,
  );
  final revalidation = await harness.handler.revalidate(proposed);
  if (!revalidation.isValid) {
    throw StateError('The production expense fixture did not resolve.');
  }
  final command = proposed.copyWith(
    previewFingerprint: revalidation.currentStateFingerprint,
  );
  return (
    command: command,
    operation: harness.handler.businessOperationFor(command),
  );
}

_ProductionContributionHarness _productionContributionHarness(
  ScopedAppDatabaseSession session,
) {
  final timestamp = DateTime.utc(2026, 7, 31, 10);
  final goals = _MutableGoalRepository(
    Goal.create(
      id: 'goal-parent',
      title: 'Parent',
      targetAmount: Decimal.fromInt(100),
      currentAmount: Decimal.zero,
      currency: 'LYD',
      createdAt: timestamp,
      updatedAt: timestamp,
    ),
  );
  final transactions = _AppSuccessTransactionsRepository();
  final resolver = DurableAiActionResolver(
    accounts: _UnusedAccountsRepository(),
    categories: _UnusedCategoriesRepository(),
    payees: _UnusedPayeesRepository(),
    budgets: _UnusedBudgetRepository(),
    goals: goals,
  );
  final handler = ProductionFinancialCommandHandler(
    toolId: 'createGoalContributionDraft',
    risk: AgentActionRisk.medium,
    resolver: resolver,
    executor: AiActionExecutor(
      createTransaction: CreateTransaction(transactions),
      createTransfer: CreateTransfer(transactions),
      validator: const AiActionValidator(),
      addGoalContribution: AddGoalContributionUseCase(
        repository: goals,
        convertMoney: (money, toCurrencyCode) async => AppResult<Money>.success(
          Money(amount: money.amount, currencyCode: toCurrencyCode),
        ),
      ),
    ),
    session: session,
  );
  return _ProductionContributionHarness(handler: handler, goals: goals);
}

Future<({AppAgentCommand command, AppAgentBusinessOperationSpec operation})>
_previewBoundContribution(
  _ProductionContributionHarness harness,
  String scope,
  String commandId,
) async {
  final proposed = _reconciliationCommand(
    scope,
    'createGoalContributionDraft',
    commandId,
  );
  final revalidation = await harness.handler.revalidate(proposed);
  if (!revalidation.isValid) {
    throw StateError('The production contribution fixture did not resolve.');
  }
  final command = proposed.copyWith(
    previewFingerprint: revalidation.currentStateFingerprint,
  );
  return (
    command: command,
    operation: harness.handler.businessOperationFor(command),
  );
}

final class _ProductionExpenseHarness {
  const _ProductionExpenseHarness({
    required this.handler,
    required this.accounts,
    required this.transactions,
  });

  final ProductionFinancialCommandHandler handler;
  final _MutableAccountsRepository accounts;
  final _AppSuccessTransactionsRepository transactions;
}

final class _ProductionContributionHarness {
  const _ProductionContributionHarness({
    required this.handler,
    required this.goals,
  });

  final ProductionFinancialCommandHandler handler;
  final _MutableGoalRepository goals;
}

final class _UnusedAccountsRepository implements AccountsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedCategoriesRepository implements CategoriesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MutableAccountsRepository implements AccountsRepository {
  _MutableAccountsRepository(this.account);

  Account account;

  @override
  Future<AppResult<Account?>> getAccountById(String id) async =>
      AppResult<Account?>.success(id == account.id ? account : null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StaticCategoriesRepository implements CategoriesRepository {
  const _StaticCategoriesRepository(this.category);

  final Category category;

  @override
  Future<AppResult<Category?>> getCategoryById(String id) async =>
      AppResult<Category?>.success(id == category.id ? category : null);

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

final class _MutableGoalRepository implements GoalRepository {
  _MutableGoalRepository(this.goal);

  Goal goal;
  List<GoalContribution> contributions = <GoalContribution>[];
  int addContributionCalls = 0;

  @override
  Future<AppResult<Goal?>> getGoalById(String id) async =>
      AppResult<Goal?>.success(id == goal.id ? goal : null);

  @override
  Stream<AppResult<List<GoalContribution>>> watchGoalContributions(
    String goalId,
  ) => Stream<AppResult<List<GoalContribution>>>.value(
    AppResult<List<GoalContribution>>.success(
      goalId == goal.id
          ? List<GoalContribution>.unmodifiable(contributions)
          : const <GoalContribution>[],
    ),
  );

  @override
  Future<AppResult<GoalContribution>> addContribution(
    GoalContribution contribution,
  ) async {
    addContributionCalls += 1;
    contributions = <GoalContribution>[...contributions, contribution];
    return AppResult<GoalContribution>.success(contribution);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AppSuccessTransactionsRepository
    implements TransactionsRepository {
  int createCalls = 0;
  Future<void> Function(Transaction transaction)? onCreate;

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    createCalls += 1;
    await onCreate?.call(transaction);
    return AppResult<Transaction>.success(transaction);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _CrashReconciliableHandler
    implements
        AppAgentReconciliableCommandHandler,
        AppAgentFaultAwareCommandHandler {
  _CrashReconciliableHandler(this.toolId, this.committed);

  @override
  final String toolId;
  final Set<String> committed;

  @override
  AgentPermission get permission => AgentPermission.createDraft;

  @override
  AgentActionRisk get risk => AgentActionRisk.medium;

  @override
  AppAgentBusinessOperationSpec businessOperationFor(AppAgentCommand command) {
    return AppAgentBusinessOperationSpec(
      key: AppAgentBusinessIdentifiers.operationKey(command),
      expectedEntityType: 'syntheticFinancialEntity',
      expectedPersistedIdentifiers: <String>['business:${command.commandId}'],
      verificationMethod: 'synthetic_persisted_identity_v1',
      safeAutomaticResume: false,
      automaticRetryProhibited: true,
    );
  }

  @override
  Future<AppAgentRevalidationResult> revalidate(AppAgentCommand command) async {
    return const AppAgentRevalidationResult(
      isValid: true,
      currentStateFingerprint: 'state-fingerprint-v1',
    );
  }

  @override
  Future<AppAgentHandlerResult> executeConfirmed(
    AppAgentCommand command,
  ) async {
    committed.add(
      businessOperationFor(command).expectedPersistedIdentifiers.single,
    );
    return const AppAgentHandlerResult(
      verified: true,
      entityType: 'syntheticFinancialEntity',
      affectedCount: 1,
    );
  }

  @override
  Future<AppAgentHandlerResult> executeConfirmedWithFaultInjection(
    AppAgentCommand command,
    AppAgentExecutionFaultInjector faultInjector,
  ) async {
    faultInjector.checkpoint(
      AppAgentExecutionCrashPoint.duringBusinessTransaction,
      command,
    );
    return executeConfirmed(command);
  }

  @override
  Future<AppAgentReconciliationResult> reconcileBusinessOperation(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    final exists = committed.contains(
      receipt.operation.expectedPersistedIdentifiers.single,
    );
    return AppAgentReconciliationResult(
      status: exists
          ? AppAgentReconciliationStatus.verifiedSucceeded
          : AppAgentReconciliationStatus.verifiedNotExecuted,
      entityType: receipt.operation.expectedEntityType,
      affectedCount: exists ? 1 : 0,
      safeFailureCode: exists ? null : AppAgentFailureCodes.recoveryNotExecuted,
    );
  }
}

final class _SingleCrashInjector implements AppAgentExecutionFaultInjector {
  _SingleCrashInjector(this.target);

  final AppAgentExecutionCrashPoint target;
  bool _thrown = false;

  @override
  void checkpoint(AppAgentExecutionCrashPoint point, AppAgentCommand command) {
    if (!_thrown && point == target) {
      _thrown = true;
      throw AppAgentSimulatedProcessInterruption(point);
    }
  }
}

final class _ScopeProvider implements AppAgentAccountScopeProvider {
  const _ScopeProvider(this.currentAccountScope);

  @override
  final String? currentAccountScope;
}
