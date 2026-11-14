import 'dart:convert';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_command_runtime.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_reconciliation_service.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/drift_app_agent_stores.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_reconciliation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  test(
    'missing business-operation correlation persists a recoverable manual-review result',
    () async {
      final database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();

      final session = scopedTestSession(database);
      final commandStore = _commandStore(session);
      final proofStore = DriftAppAgentConfirmationProofStore(session);
      final executionStore = DriftAppAgentDurableExecutionStore(session);
      final command = _command(session.ownerScopeValue);
      await commandStore.saveTrustedLocalCommand(command);
      await commandStore.savePreview(
        preview: _preview(command.commandId),
        accountScope: session.ownerScopeValue,
      );
      final confirmation =
          (await AppAgentConfirmationController(
                commandStore: commandStore,
                proofStore: proofStore,
                clock: () => DateTime.utc(2026, 8, 10, 12),
              ).confirm(
                commandId: command.commandId,
                accountScope: session.ownerScopeValue,
                method: AppAgentConfirmationMethod.primaryButton,
              ))
              .confirmation!;
      final confirmed = (await commandStore.readCommand(
        commandId: command.commandId,
        accountScope: session.ownerScopeValue,
      ))!;
      final claim = await executionStore.claim(
        confirmed,
        confirmation: confirmation,
        now: DateTime.utc(2026, 8, 10, 12, 0, 1),
      );
      expect(claim.disposition, AppAgentExecutionClaimDisposition.claimed);
      expect(
        (await database.select(database.aiAgentExecutionAttempts).getSingle())
            .businessOperationId,
        isNull,
      );

      final handler = _NeverCalledHandler();
      final restartedSession = scopedTestSession(database);
      final restartedCommandStore = _commandStore(restartedSession);
      final restartedExecutionStore = DriftAppAgentDurableExecutionStore(
        restartedSession,
      );
      final reconciler = AppAgentStartupReconciler(
        commandStore: restartedCommandStore,
        executionStore: restartedExecutionStore,
        handlerRegistry: MapAppAgentCommandHandlerRegistry([handler]),
      );

      final firstRecovery = await reconciler.reconcile();

      expect(firstRecovery.inspectedCount, 1);
      expect(firstRecovery.requiresManualReviewCount, 1);
      expect(firstRecovery.reconciledResults, hasLength(1));
      final result = firstRecovery.reconciledResults.single;
      expect(result.commandId, command.commandId);
      expect(result.status, AppAgentCommandStatus.partiallySucceeded);
      expect(result.verified, isFalse);
      expect(result.affectedCount, 0);
      expect(result.safeFailureCode, AppAgentFailureCodes.recoveryManualReview);
      expect(handler.executionCount, 0);
      expect(handler.revalidationCount, 0);
      expect(handler.reconciliationCount, 0);

      final persistedCommand = await restartedCommandStore.readCommand(
        commandId: command.commandId,
        accountScope: restartedSession.ownerScopeValue,
      );
      expect(
        persistedCommand?.status,
        AppAgentCommandStatus.partiallySucceeded,
      );
      expect(
        persistedCommand?.safeFailureCode,
        AppAgentFailureCodes.recoveryManualReview,
      );
      final attempt = await database
          .select(database.aiAgentExecutionAttempts)
          .getSingle();
      expect(attempt.status, AppAgentCommandStatus.partiallySucceeded.name);
      expect(attempt.completedAt, isNotNull);
      expect(
        attempt.safeFailureCode,
        AppAgentFailureCodes.recoveryManualReview,
      );
      final idempotency = await database
          .select(database.aiAgentIdempotencyRecords)
          .getSingle();
      expect(idempotency.status, 'completed');
      expect(idempotency.executionResultId, isNotNull);
      final resultRow = await database
          .select(database.aiAgentExecutionResults)
          .getSingle();
      expect(resultRow.id, idempotency.executionResultId);
      expect(resultRow.status, AppAgentCommandStatus.partiallySucceeded.name);
      expect(resultRow.verified, isFalse);
      expect(resultRow.affectedCount, 0);
      expect(
        resultRow.safeFailureCode,
        AppAgentFailureCodes.recoveryManualReview,
      );
      final safeResult =
          jsonDecode(resultRow.safeResultJson) as Map<String, dynamic>;
      expect(safeResult['uiDeliveryAcknowledged'], isFalse);
      expect(safeResult['verified'], isFalse);
      expect(safeResult['affectedCount'], 0);
      expect(resultRow.safeResultJson, isNot(contains('normalizedArguments')));
      expect(resultRow.safeResultJson, isNot(contains('authorityProof')));
      expect(resultRow.safeResultJson, isNot(contains('opaque-account')));
      expect(
        await database.select(database.aiAgentBusinessOperations).get(),
        isEmpty,
      );
      final audit = await DriftAppAgentAuditStore(
        restartedSession,
      ).readRecent(accountScope: restartedSession.ownerScopeValue);
      expect(audit, hasLength(1));
      expect(audit.single.result, AppAgentCommandStatus.partiallySucceeded);
      expect(
        audit.single.safeFailureCode,
        AppAgentFailureCodes.recoveryManualReview,
      );
      expect(
        audit.single.confirmationMethod,
        AppAgentConfirmationMethod.primaryButton,
      );

      expect(
        (await restartedExecutionStore.readRecoverableCommands()).map(
          (item) => item.commandId,
        ),
        contains(command.commandId),
      );
      final secondRecovery = await reconciler.reconcile();
      expect(secondRecovery.requiresManualReviewCount, 1);
      expect(secondRecovery.reconciledResults, hasLength(1));
      expect(
        secondRecovery.reconciledResults.single.status,
        AppAgentCommandStatus.partiallySucceeded,
      );
      expect(
        await database.select(database.aiAgentExecutionResults).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.aiAgentAuditEvents).get(),
        hasLength(1),
      );
      expect(handler.executionCount, 0);
      expect(handler.revalidationCount, 0);
      expect(handler.reconciliationCount, 0);

      await restartedExecutionStore.acknowledgeUiDelivery(command.commandId);
      expect(await restartedExecutionStore.readRecoverableCommands(), isEmpty);
      final acknowledgedRow = await database
          .select(database.aiAgentExecutionResults)
          .getSingle();
      expect(
        (jsonDecode(acknowledgedRow.safeResultJson)
            as Map<String, dynamic>)['uiDeliveryAcknowledged'],
        isTrue,
      );
      final afterAcknowledgement = await reconciler.reconcile();
      expect(afterAcknowledgement.inspectedCount, 0);
      expect(afterAcknowledgement.reconciledResults, isEmpty);
      expect(handler.executionCount, 0);
    },
  );
}

DriftAppAgentCommandStore _commandStore(ScopedAppDatabaseSession session) {
  return DriftAppAgentCommandStore(
    session: session,
    canonicalDescriptors: const [
      AppAgentModelProposalDescriptor(
        toolId: 'createExpenseDraft',
        permission: AgentPermission.createDraft,
        risk: AgentActionRisk.medium,
        modelCallable: false,
      ),
    ],
  );
}

AppAgentCommand _command(String scope) => AppAgentCommand(
  commandId: 'missing-correlation-command',
  conversationId: 'missing-correlation-conversation',
  userAccountScope: scope,
  commandType: AppAgentCommandType.create,
  toolId: 'createExpenseDraft',
  normalizedArguments: const <String, Object?>{
    'amount': '10.00',
    'currency': 'USD',
    'accountRef': 'opaque-account',
    'categoryRef': 'opaque-category',
  },
  permission: AgentPermission.createDraft,
  risk: AgentActionRisk.medium,
  createdAt: DateTime.utc(2026, 8, 10, 12),
  expiresAt: DateTime.utc(2026, 8, 10, 12, 10),
  status: AppAgentCommandStatus.readyForPreview,
);

AppAgentPreview _preview(String commandId) => AppAgentPreview(
  commandId: commandId,
  title: 'Create expense',
  entityType: 'transaction',
  fields: const [
    AppAgentPreviewField(label: 'Amount', proposedValue: 'USD 10.00'),
  ],
  risk: AgentActionRisk.medium,
  confirmationLevel: AppAgentConfirmationLevel.detailed,
  stateFingerprint: 'state-fingerprint-v1',
  createdAt: DateTime.utc(2026, 8, 10, 12),
);

final class _NeverCalledHandler implements AppAgentReconciliableCommandHandler {
  int executionCount = 0;
  int revalidationCount = 0;
  int reconciliationCount = 0;

  @override
  String get toolId => 'createExpenseDraft';

  @override
  AgentPermission get permission => AgentPermission.createDraft;

  @override
  AgentActionRisk get risk => AgentActionRisk.medium;

  @override
  AppAgentBusinessOperationSpec businessOperationFor(AppAgentCommand command) {
    throw StateError('Recovery must not reconstruct missing correlation.');
  }

  @override
  Future<AppAgentHandlerResult> executeConfirmed(
    AppAgentCommand command,
  ) async {
    executionCount += 1;
    throw StateError('Recovery must never execute the business operation.');
  }

  @override
  Future<AppAgentReconciliationResult> reconcileBusinessOperation(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    reconciliationCount += 1;
    throw StateError('A missing receipt cannot be reconciled automatically.');
  }

  @override
  Future<AppAgentRevalidationResult> revalidate(AppAgentCommand command) async {
    revalidationCount += 1;
    throw StateError('Startup recovery must not revalidate for execution.');
  }
}
