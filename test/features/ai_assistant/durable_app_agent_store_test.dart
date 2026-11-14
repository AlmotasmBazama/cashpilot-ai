import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_command_runtime.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_reconciliation_service.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/drift_app_agent_stores.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_reconciliation.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

void main() {
  group('durable app-agent runtime', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      await database.customSelect('SELECT 1').get();
    });

    tearDown(() => database.close());

    test(
      'draft, proof, execution, result, and audit survive restart',
      () async {
        final session = scopedTestSession(database);
        final store = _commandStore(session);
        final proofStore = DriftAppAgentConfirmationProofStore(session);
        final auditStore = DriftAppAgentAuditStore(session);
        final durableExecution = DriftAppAgentDurableExecutionStore(session);
        final command = _command(session.ownerScopeValue, 'command-1');
        await store.saveTrustedLocalCommand(command);
        await store.savePreview(
          preview: _preview(command.commandId),
          accountScope: session.ownerScopeValue,
        );

        final restartedStore = _commandStore(scopedTestSession(database));
        expect(
          (await restartedStore.readCommand(
            commandId: command.commandId,
            accountScope: session.ownerScopeValue,
          ))?.status,
          AppAgentCommandStatus.awaitingConfirmation,
        );

        final confirmation =
            await AppAgentConfirmationController(
              commandStore: restartedStore,
              proofStore: proofStore,
              clock: () => DateTime.utc(2026, 7, 31, 12),
            ).confirm(
              commandId: command.commandId,
              accountScope: session.ownerScopeValue,
              method: AppAgentConfirmationMethod.primaryButton,
            );
        expect(confirmation.confirmation, isNotNull);
        final rawProof = await database
            .select(database.aiAgentConfirmationProofs)
            .getSingle();
        expect(
          rawProof.proofHash,
          isNot(confirmation.confirmation!.authorityProof),
        );
        expect(
          rawProof.proofHash,
          isNot(contains(confirmation.confirmation!.authorityProof)),
        );

        final handler = _CountingHandler();
        final executor = AppAgentCommandExecutor(
          commandStore: restartedStore,
          auditStore: auditStore,
          proofStore: proofStore,
          handlerRegistry: MapAppAgentCommandHandlerRegistry([handler]),
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: durableExecution,
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 1),
        );
        final results = await Future.wait([
          executor.execute(confirmation.confirmation!),
          executor.execute(confirmation.confirmation!),
        ]);
        expect(handler.executionCount, 1);
        expect(results.where((result) => result.verified), hasLength(1));

        final afterRestart = DriftAppAgentDurableExecutionStore(
          scopedTestSession(database),
        );
        final persisted = await afterRestart.readVerifiedResult(
          command.commandId,
        );
        expect(persisted?.verified, isTrue);
        expect(persisted?.affectedCount, 1);
        expect(
          await DriftAppAgentAuditStore(
            scopedTestSession(database),
          ).readRecent(accountScope: session.ownerScopeValue),
          hasLength(1),
        );
      },
    );

    test('confirmation proof is one-time and preview-revision-bound', () async {
      final session = scopedTestSession(database);
      final store = _commandStore(session);
      final proofStore = DriftAppAgentConfirmationProofStore(session);
      final command = _command(session.ownerScopeValue, 'command-proof');
      await store.saveTrustedLocalCommand(command);
      await store.savePreview(
        preview: _preview(command.commandId),
        accountScope: session.ownerScopeValue,
      );
      final decision =
          await AppAgentConfirmationController(
            commandStore: store,
            proofStore: proofStore,
            clock: () => DateTime.utc(2026, 7, 31, 12),
          ).confirm(
            commandId: command.commandId,
            accountScope: session.ownerScopeValue,
            method: AppAgentConfirmationMethod.primaryButton,
          );
      final proof = decision.confirmation!;
      expect(
        await proofStore.consumeProof(
          commandId: command.commandId,
          accountScope: session.ownerScopeValue,
          proof: proof.authorityProof,
          method: proof.method,
          now: DateTime.utc(2026, 7, 31, 12, 0, 1),
        ),
        isTrue,
      );
      expect(
        await proofStore.consumeProof(
          commandId: command.commandId,
          accountScope: session.ownerScopeValue,
          proof: proof.authorityProof,
          method: proof.method,
          now: DateTime.utc(2026, 7, 31, 12, 0, 2),
        ),
        isFalse,
      );

      final second = _command(session.ownerScopeValue, 'command-stale');
      await store.saveTrustedLocalCommand(second);
      await store.savePreview(
        preview: _preview(second.commandId),
        accountScope: session.ownerScopeValue,
      );
      final staleDecision =
          await AppAgentConfirmationController(
            commandStore: store,
            proofStore: proofStore,
            clock: () => DateTime.utc(2026, 7, 31, 12),
          ).confirm(
            commandId: second.commandId,
            accountScope: session.ownerScopeValue,
            method: AppAgentConfirmationMethod.primaryButton,
          );
      await (database.update(database.aiAgentCommands)
            ..where((row) => row.id.equals(second.commandId)))
          .write(const AiAgentCommandsCompanion(revision: Value(2)));
      expect(
        await proofStore.consumeProof(
          commandId: second.commandId,
          accountScope: session.ownerScopeValue,
          proof: staleDecision.confirmation!.authorityProof,
          method: staleDecision.confirmation!.method,
          now: DateTime.utc(2026, 7, 31, 12, 0, 1),
        ),
        isFalse,
      );
    });

    test('confirmation before a durable preview is rejected', () async {
      final session = scopedTestSession(database);
      final store = _commandStore(session);
      final command = _command(
        session.ownerScopeValue,
        'command-before-preview',
      );
      await store.saveTrustedLocalCommand(command);

      final decision =
          await AppAgentConfirmationController(
            commandStore: store,
            proofStore: DriftAppAgentConfirmationProofStore(session),
            clock: () => DateTime.utc(2026, 7, 31, 12),
          ).confirm(
            commandId: command.commandId,
            accountScope: session.ownerScopeValue,
            method: AppAgentConfirmationMethod.primaryButton,
          );

      expect(decision.confirmation, isNull);
      expect(decision.safeFailureCode, AppAgentFailureCodes.invalidStatus);
      expect(
        (await store.readCommand(
          commandId: command.commandId,
          accountScope: session.ownerScopeValue,
        ))?.status,
        AppAgentCommandStatus.readyForPreview,
      );
      expect(
        await database.select(database.aiAgentConfirmationProofs).get(),
        isEmpty,
      );
    });

    test('durable claim rejects a proof issued for another command', () async {
      final session = scopedTestSession(database);
      final store = _commandStore(session);
      final proofStore = DriftAppAgentConfirmationProofStore(session);
      final controller = AppAgentConfirmationController(
        commandStore: store,
        proofStore: proofStore,
        clock: () => DateTime.utc(2026, 7, 31, 12),
      );

      Future<AppAgentConfirmation> prepare(String commandId) async {
        final command = _command(session.ownerScopeValue, commandId);
        await store.saveTrustedLocalCommand(command);
        await store.savePreview(
          preview: _preview(command.commandId),
          accountScope: session.ownerScopeValue,
        );
        return (await controller.confirm(
          commandId: command.commandId,
          accountScope: session.ownerScopeValue,
          method: AppAgentConfirmationMethod.primaryButton,
        )).confirmation!;
      }

      final first = await prepare('command-proof-source');
      final second = await prepare('command-proof-target');
      final target = (await store.readCommand(
        commandId: second.commandId,
        accountScope: session.ownerScopeValue,
      ))!;

      await expectLater(
        DriftAppAgentDurableExecutionStore(session).claim(
          target,
          confirmation: AppAgentConfirmation(
            commandId: target.commandId,
            userAccountScope: target.userAccountScope,
            confirmedAt: first.confirmedAt,
            method: first.method,
            authorityProof: first.authorityProof,
          ),
          now: DateTime.utc(2026, 7, 31, 12, 0, 1),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.invalidConfirmation,
          ),
        ),
      );
      expect(
        await database.select(database.aiAgentExecutionAttempts).get(),
        isEmpty,
      );
      final proofs = await database
          .select(database.aiAgentConfirmationProofs)
          .get();
      expect(proofs, hasLength(2));
      expect(proofs.every((row) => row.status == 'active'), isTrue);
    });

    test('durable claim rejects an expired confirmation proof', () async {
      final session = scopedTestSession(database);
      final store = _commandStore(session);
      final proofStore = DriftAppAgentConfirmationProofStore(session);
      final command = _command(
        session.ownerScopeValue,
        'command-proof-expired',
      );
      await store.saveTrustedLocalCommand(command);
      await store.savePreview(
        preview: _preview(command.commandId),
        accountScope: session.ownerScopeValue,
      );
      final confirmation =
          (await AppAgentConfirmationController(
                commandStore: store,
                proofStore: proofStore,
                clock: () => DateTime.utc(2026, 7, 31, 12),
              ).confirm(
                commandId: command.commandId,
                accountScope: session.ownerScopeValue,
                method: AppAgentConfirmationMethod.primaryButton,
              ))
              .confirmation!;
      final confirmed = (await store.readCommand(
        commandId: command.commandId,
        accountScope: session.ownerScopeValue,
      ))!;

      await expectLater(
        DriftAppAgentDurableExecutionStore(session).claim(
          confirmed,
          confirmation: confirmation,
          now: DateTime.utc(2026, 7, 31, 12, 2),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.invalidConfirmation,
          ),
        ),
      );
      expect(
        await database.select(database.aiAgentExecutionAttempts).get(),
        isEmpty,
      );
      expect(
        (await database.select(database.aiAgentConfirmationProofs).getSingle())
            .status,
        'active',
      );
      expect(
        (await store.readCommand(
          commandId: command.commandId,
          accountScope: session.ownerScopeValue,
        ))?.status,
        AppAgentCommandStatus.confirmed,
      );
    });

    test('crash after execution claim cannot produce a second claim', () async {
      final session = scopedTestSession(database);
      final store = _commandStore(session);
      final proofStore = DriftAppAgentConfirmationProofStore(session);
      final command = _command(session.ownerScopeValue, 'command-crash');
      await store.saveTrustedLocalCommand(command);
      await store.savePreview(
        preview: _preview(command.commandId),
        accountScope: session.ownerScopeValue,
      );
      final decision =
          await AppAgentConfirmationController(
            commandStore: store,
            proofStore: proofStore,
            clock: () => DateTime.utc(2026, 7, 31, 12),
          ).confirm(
            commandId: command.commandId,
            accountScope: session.ownerScopeValue,
            method: AppAgentConfirmationMethod.primaryButton,
          );
      final confirmed = await store.readCommand(
        commandId: command.commandId,
        accountScope: session.ownerScopeValue,
      );
      final executionStore = DriftAppAgentDurableExecutionStore(session);
      expect(
        (await executionStore.claim(
          confirmed!,
          confirmation: decision.confirmation!,
          now: DateTime.utc(2026, 7, 31, 12, 0, 1),
        )).disposition,
        AppAgentExecutionClaimDisposition.claimed,
      );
      final afterCrash = DriftAppAgentDurableExecutionStore(
        scopedTestSession(database),
      );
      expect(
        (await afterCrash.claim(
          confirmed,
          confirmation: decision.confirmation!,
          now: DateTime.utc(2026, 7, 31, 12, 0, 2),
        )).disposition,
        AppAgentExecutionClaimDisposition.duplicateInProgress,
      );
      expect(
        (await afterCrash.readRecoverableCommands()).single.status,
        AppAgentCommandStatus.executing,
      );
    });

    test(
      'proof remains active when execution stops before the durable claim',
      () async {
        final session = scopedTestSession(database);
        final store = _commandStore(session);
        final proofStore = DriftAppAgentConfirmationProofStore(session);
        final command = _command(session.ownerScopeValue, 'command-atomic');
        await store.saveTrustedLocalCommand(command);
        await store.savePreview(
          preview: _preview(command.commandId),
          accountScope: session.ownerScopeValue,
        );
        final decision =
            await AppAgentConfirmationController(
              commandStore: store,
              proofStore: proofStore,
              clock: () => DateTime.utc(2026, 7, 31, 12),
            ).confirm(
              commandId: command.commandId,
              accountScope: session.ownerScopeValue,
              method: AppAgentConfirmationMethod.primaryButton,
            );
        final executor = AppAgentCommandExecutor(
          commandStore: store,
          auditStore: DriftAppAgentAuditStore(session),
          proofStore: proofStore,
          handlerRegistry: MapAppAgentCommandHandlerRegistry([
            _CountingHandler(),
          ]),
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: DriftAppAgentDurableExecutionStore(session),
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 1),
          faultInjector: const _ThrowAtCheckpoint(
            AppAgentExecutionCrashPoint.beforeExecutionClaim,
          ),
        );

        await expectLater(
          executor.execute(decision.confirmation!),
          throwsA(isA<AppAgentSimulatedProcessInterruption>()),
        );
        expect(
          (await database
                  .select(database.aiAgentConfirmationProofs)
                  .getSingle())
              .status,
          'active',
        );
        expect(
          await database.select(database.aiAgentExecutionAttempts).get(),
          isEmpty,
        );
        expect(
          (await store.readCommand(
            commandId: command.commandId,
            accountScope: session.ownerScopeValue,
          ))?.status,
          AppAgentCommandStatus.confirmed,
        );
      },
    );

    test(
      'pre-claim rejection invalidates only an authentic durable proof',
      () async {
        final session = scopedTestSession(database);
        final store = _commandStore(session);
        final proofStore = DriftAppAgentConfirmationProofStore(session);

        Future<AppAgentConfirmation> prepare(String id) async {
          final command = _command(session.ownerScopeValue, id);
          await store.saveTrustedLocalCommand(command);
          await store.savePreview(
            preview: _preview(command.commandId),
            accountScope: session.ownerScopeValue,
          );
          return (await AppAgentConfirmationController(
                commandStore: store,
                proofStore: proofStore,
                clock: () => DateTime.utc(2026, 7, 31, 12),
              ).confirm(
                commandId: command.commandId,
                accountScope: session.ownerScopeValue,
                method: AppAgentConfirmationMethod.primaryButton,
              ))
              .confirmation!;
        }

        AppAgentCommandExecutor executor() => AppAgentCommandExecutor(
          commandStore: store,
          auditStore: DriftAppAgentAuditStore(session),
          proofStore: proofStore,
          handlerRegistry: MapAppAgentCommandHandlerRegistry([
            _CountingHandler(currentStateFingerprint: 'changed-after-preview'),
          ]),
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: DriftAppAgentDurableExecutionStore(session),
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 1),
        );

        final authentic = await prepare('command-authentic-stale');
        final staleResult = await executor().execute(authentic);
        expect(staleResult.safeFailureCode, AppAgentFailureCodes.stalePreview);
        expect(
          (await database.select(database.aiAgentConfirmationProofs).get())
              .singleWhere((row) => row.commandId == authentic.commandId)
              .status,
          'consumed',
        );
        expect(
          (await store.readCommand(
            commandId: authentic.commandId,
            accountScope: session.ownerScopeValue,
          ))?.status,
          AppAgentCommandStatus.failed,
        );

        final issued = await prepare('command-forged-stale');
        final forged = AppAgentConfirmation(
          commandId: issued.commandId,
          userAccountScope: issued.userAccountScope,
          confirmedAt: issued.confirmedAt,
          method: issued.method,
          authorityProof: 'forged-authority-proof',
        );
        final forgedResult = await executor().execute(forged);
        expect(
          forgedResult.safeFailureCode,
          AppAgentFailureCodes.invalidConfirmation,
        );
        expect(
          (await store.readCommand(
            commandId: issued.commandId,
            accountScope: session.ownerScopeValue,
          ))?.status,
          AppAgentCommandStatus.confirmed,
        );
        expect(
          (await database.select(database.aiAgentConfirmationProofs).get())
              .singleWhere((row) => row.commandId == issued.commandId)
              .status,
          'active',
        );
        expect(
          await DriftAppAgentAuditStore(
            session,
          ).readRecent(accountScope: session.ownerScopeValue),
          hasLength(1),
        );
        expect(
          await database.select(database.aiAgentExecutionAttempts).get(),
          isEmpty,
        );
      },
    );

    test('durable claim rejects a confirmed command without proof', () async {
      final session = scopedTestSession(database);
      final store = _commandStore(session);
      final command = _command(session.ownerScopeValue, 'command-no-proof');
      await store.saveTrustedLocalCommand(command);
      await store.savePreview(
        preview: _preview(command.commandId),
        accountScope: session.ownerScopeValue,
      );
      final confirmed = await store.transition(
        commandId: command.commandId,
        accountScope: session.ownerScopeValue,
        expectedStatus: AppAgentCommandStatus.awaitingConfirmation,
        nextStatus: AppAgentCommandStatus.confirmed,
      );

      await expectLater(
        DriftAppAgentDurableExecutionStore(session).claim(
          confirmed!,
          confirmation: AppAgentConfirmation(
            commandId: command.commandId,
            userAccountScope: session.ownerScopeValue,
            confirmedAt: DateTime.utc(2026, 7, 31, 12),
            method: AppAgentConfirmationMethod.primaryButton,
            authorityProof: 'forged-proof-without-a-durable-record',
          ),
          now: DateTime.utc(2026, 7, 31, 12, 0, 1),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.invalidConfirmation,
          ),
        ),
      );
    });

    test(
      'dynamic authorization is rechecked before and after durable claim',
      () async {
        final session = scopedTestSession(database);
        final store = _commandStore(session);
        final proofStore = DriftAppAgentConfirmationProofStore(session);

        Future<AppAgentConfirmation> prepare(String id) async {
          final command = _command(session.ownerScopeValue, id);
          await store.saveTrustedLocalCommand(command);
          await store.savePreview(
            preview: _preview(command.commandId),
            accountScope: session.ownerScopeValue,
          );
          return (await AppAgentConfirmationController(
                commandStore: store,
                proofStore: proofStore,
                clock: () => DateTime.utc(2026, 7, 31, 12),
              ).confirm(
                commandId: command.commandId,
                accountScope: session.ownerScopeValue,
                method: AppAgentConfirmationMethod.primaryButton,
              ))
              .confirmation!;
        }

        final deniedBeforeClaim = await prepare('command-denied-before-claim');
        final firstHandler = _CountingHandler();
        final firstResult = await AppAgentCommandExecutor(
          commandStore: store,
          auditStore: DriftAppAgentAuditStore(session),
          proofStore: proofStore,
          handlerRegistry: MapAppAgentCommandHandlerRegistry([firstHandler]),
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: DriftAppAgentDurableExecutionStore(session),
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 1),
          executionAuthorization: (_) => false,
        ).execute(deniedBeforeClaim);
        expect(
          firstResult.safeFailureCode,
          AppAgentFailureCodes.permissionDenied,
        );
        expect(firstHandler.executionCount, 0);
        expect(
          await database.select(database.aiAgentExecutionAttempts).get(),
          isEmpty,
        );

        final deniedAfterClaim = await prepare('command-denied-after-claim');
        var authorizationChecks = 0;
        final secondHandler = _CountingHandler();
        final secondResult = await AppAgentCommandExecutor(
          commandStore: store,
          auditStore: DriftAppAgentAuditStore(session),
          proofStore: proofStore,
          handlerRegistry: MapAppAgentCommandHandlerRegistry([secondHandler]),
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: DriftAppAgentDurableExecutionStore(session),
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 2),
          executionAuthorization: (_) => ++authorizationChecks == 1,
        ).execute(deniedAfterClaim);
        expect(
          secondResult.safeFailureCode,
          AppAgentFailureCodes.permissionDenied,
        );
        expect(secondHandler.executionCount, 0);
        expect(authorizationChecks, 2);
        expect(
          await (database.select(database.aiAgentExecutionAttempts)..where(
                (row) => row.commandId.equals(deniedAfterClaim.commandId),
              ))
              .get(),
          hasLength(1),
        );
      },
    );

    test(
      'uncertain post-commit failure remains recoverable and is never rerun',
      () async {
        final session = scopedTestSession(database);
        final store = _commandStore(session);
        final proofStore = DriftAppAgentConfirmationProofStore(session);
        final durableStore = DriftAppAgentDurableExecutionStore(session);
        final command = _command(session.ownerScopeValue, 'command-uncertain');
        await store.saveTrustedLocalCommand(command);
        await store.savePreview(
          preview: _preview(command.commandId),
          accountScope: session.ownerScopeValue,
        );
        final confirmation =
            (await AppAgentConfirmationController(
                  commandStore: store,
                  proofStore: proofStore,
                  clock: () => DateTime.utc(2026, 7, 31, 12),
                ).confirm(
                  commandId: command.commandId,
                  accountScope: session.ownerScopeValue,
                  method: AppAgentConfirmationMethod.primaryButton,
                ))
                .confirmation!;
        final handler = _CommitThenTimeoutHandler();
        final registry = MapAppAgentCommandHandlerRegistry([handler]);
        final result = await AppAgentCommandExecutor(
          commandStore: store,
          auditStore: DriftAppAgentAuditStore(session),
          proofStore: proofStore,
          handlerRegistry: registry,
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: durableStore,
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 1),
        ).execute(confirmation);

        expect(result.verified, isFalse);
        expect(handler.executionCount, 1);
        expect(
          (await store.readCommand(
            commandId: command.commandId,
            accountScope: session.ownerScopeValue,
          ))?.status,
          AppAgentCommandStatus.executing,
        );
        final recovery = await AppAgentStartupReconciler(
          commandStore: store,
          executionStore: durableStore,
          handlerRegistry: registry,
        ).reconcile();
        expect(recovery.verifiedSucceededCount, 1);
        expect(recovery.reconciledResults.single.verified, isTrue);

        await AppAgentCommandExecutor(
          commandStore: store,
          auditStore: DriftAppAgentAuditStore(session),
          proofStore: proofStore,
          handlerRegistry: registry,
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: durableStore,
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 2),
        ).execute(confirmation);
        expect(handler.executionCount, 1);
      },
    );

    test(
      'premature UI acknowledgement cannot suppress a later result',
      () async {
        final session = scopedTestSession(database);
        final store = _commandStore(session);
        final proofStore = DriftAppAgentConfirmationProofStore(session);
        final durableStore = DriftAppAgentDurableExecutionStore(session);
        final command = _command(session.ownerScopeValue, 'command-ui-receipt');
        await store.saveTrustedLocalCommand(command);
        await store.savePreview(
          preview: _preview(command.commandId),
          accountScope: session.ownerScopeValue,
        );
        final confirmation =
            (await AppAgentConfirmationController(
                  commandStore: store,
                  proofStore: proofStore,
                  clock: () => DateTime.utc(2026, 7, 31, 12),
                ).confirm(
                  commandId: command.commandId,
                  accountScope: session.ownerScopeValue,
                  method: AppAgentConfirmationMethod.primaryButton,
                ))
                .confirmation!;
        final confirmed = (await store.readCommand(
          commandId: command.commandId,
          accountScope: session.ownerScopeValue,
        ))!;
        final operation = AppAgentBusinessOperationSpec(
          key: AppAgentBusinessOperationKey('operation:${command.commandId}'),
          expectedEntityType: 'transaction',
          expectedPersistedIdentifiers: <String>['row:${command.commandId}'],
          verificationMethod: 'test_exact_row_v1',
          safeAutomaticResume: false,
          automaticRetryProhibited: true,
        );
        final claim = await durableStore.claim(
          confirmed,
          confirmation: confirmation,
          now: DateTime.utc(2026, 7, 31, 12, 0, 1),
          operation: operation,
        );

        await durableStore.acknowledgeUiDelivery(command.commandId);
        await durableStore.complete(
          command: confirmed,
          attemptId: claim.attemptId!,
          result: AppAgentExecutionResult(
            commandId: command.commandId,
            status: AppAgentCommandStatus.succeeded,
            verified: true,
            entityType: 'transaction',
            affectedCount: 1,
            completedAt: DateTime.utc(2026, 7, 31, 12, 0, 2),
          ),
        );
        expect(
          (await durableStore.readRecoverableCommands()).map(
            (item) => item.commandId,
          ),
          contains(command.commandId),
        );

        await durableStore.acknowledgeUiDelivery(command.commandId);
        expect(
          (await durableStore.readRecoverableCommands()).map(
            (item) => item.commandId,
          ),
          isNot(contains(command.commandId)),
        );
      },
    );

    test('durable result and privacy-safe audit commit together', () async {
      final session = scopedTestSession(database);
      final store = _commandStore(session);
      final proofStore = DriftAppAgentConfirmationProofStore(session);
      final command = _command(session.ownerScopeValue, 'command-audit-atomic');
      await store.saveTrustedLocalCommand(command);
      await store.savePreview(
        preview: _preview(command.commandId),
        accountScope: session.ownerScopeValue,
      );
      final confirmation =
          (await AppAgentConfirmationController(
                commandStore: store,
                proofStore: proofStore,
                clock: () => DateTime.utc(2026, 7, 31, 12),
              ).confirm(
                commandId: command.commandId,
                accountScope: session.ownerScopeValue,
                method: AppAgentConfirmationMethod.primaryButton,
              ))
              .confirmation!;

      await expectLater(
        AppAgentCommandExecutor(
          commandStore: store,
          auditStore: DriftAppAgentAuditStore(session),
          proofStore: proofStore,
          handlerRegistry: MapAppAgentCommandHandlerRegistry([
            _CountingHandler(),
          ]),
          accountScopeProvider: _ScopeProvider(session.ownerScopeValue),
          durableExecutionStore: DriftAppAgentDurableExecutionStore(session),
          clock: () => DateTime.utc(2026, 7, 31, 12, 0, 1),
          faultInjector: const _ThrowAtCheckpoint(
            AppAgentExecutionCrashPoint.afterDurableResultSave,
          ),
        ).execute(confirmation),
        throwsA(isA<AppAgentSimulatedProcessInterruption>()),
      );
      expect(
        await database.select(database.aiAgentExecutionResults).get(),
        hasLength(1),
      );
      expect(
        await DriftAppAgentAuditStore(
          session,
        ).readRecent(accountScope: session.ownerScopeValue),
        hasLength(1),
      );
    });

    test('another scope cannot read or resume commands and audits', () async {
      final scopeA = scopedTestSession(
        database,
        syntheticFirebaseUid: 'agent-owner-a',
      );
      final scopeB = scopedTestSession(
        database,
        syntheticFirebaseUid: 'agent-owner-b',
      );
      final storeA = _commandStore(scopeA);
      final command = _command(scopeA.ownerScopeValue, 'command-private');
      await storeA.saveTrustedLocalCommand(command);
      expect(
        await _commandStore(scopeB).readCommand(
          commandId: command.commandId,
          accountScope: scopeB.ownerScopeValue,
        ),
        isNull,
      );
      expect(
        await DriftAppAgentAuditStore(
          scopeB,
        ).readRecent(accountScope: scopeB.ownerScopeValue),
        isEmpty,
      );
      expect(
        await DriftAppAgentDurableExecutionStore(
          scopeB,
        ).readVerifiedResult(command.commandId),
        isNull,
      );
    });
  });
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

AppAgentCommand _command(String scope, String id) {
  return AppAgentCommand(
    commandId: id,
    conversationId: 'conversation',
    userAccountScope: scope,
    commandType: AppAgentCommandType.create,
    toolId: 'createExpenseDraft',
    normalizedArguments: const {
      'amount': '10.00',
      'currency': 'USD',
      'accountRef': 'opaque-account',
      'categoryRef': 'opaque-category',
    },
    permission: AgentPermission.createDraft,
    risk: AgentActionRisk.medium,
    createdAt: DateTime.utc(2026, 7, 31, 12),
    expiresAt: DateTime.utc(2026, 7, 31, 12, 10),
    status: AppAgentCommandStatus.readyForPreview,
  );
}

AppAgentPreview _preview(String commandId) {
  return AppAgentPreview(
    commandId: commandId,
    title: 'Create expense',
    entityType: 'transaction',
    fields: const [
      AppAgentPreviewField(label: 'Amount', proposedValue: 'USD 10.00'),
    ],
    risk: AgentActionRisk.medium,
    confirmationLevel: AppAgentConfirmationLevel.detailed,
    stateFingerprint: 'state-fingerprint-v1',
    createdAt: DateTime.utc(2026, 7, 31, 12),
  );
}

class _ScopeProvider implements AppAgentAccountScopeProvider {
  const _ScopeProvider(this.currentAccountScope);

  @override
  final String? currentAccountScope;
}

class _CountingHandler implements AppAgentCommandHandler {
  _CountingHandler({this.currentStateFingerprint = 'state-fingerprint-v1'});

  final String currentStateFingerprint;
  int executionCount = 0;

  @override
  String get toolId => 'createExpenseDraft';

  @override
  AgentPermission get permission => AgentPermission.createDraft;

  @override
  AgentActionRisk get risk => AgentActionRisk.medium;

  @override
  Future<AppAgentRevalidationResult> revalidate(AppAgentCommand command) async {
    return AppAgentRevalidationResult(
      isValid: true,
      currentStateFingerprint: currentStateFingerprint,
    );
  }

  @override
  Future<AppAgentHandlerResult> executeConfirmed(
    AppAgentCommand command,
  ) async {
    executionCount++;
    return const AppAgentHandlerResult(
      verified: true,
      entityType: 'transaction',
      affectedCount: 1,
    );
  }
}

class _CommitThenTimeoutHandler implements AppAgentReconciliableCommandHandler {
  bool committed = false;
  int executionCount = 0;

  @override
  String get toolId => 'createExpenseDraft';

  @override
  AgentPermission get permission => AgentPermission.createDraft;

  @override
  AgentActionRisk get risk => AgentActionRisk.medium;

  @override
  AppAgentBusinessOperationSpec businessOperationFor(AppAgentCommand command) {
    return AppAgentBusinessOperationSpec(
      key: AppAgentBusinessOperationKey('operation:${command.commandId}'),
      expectedEntityType: 'transaction',
      expectedPersistedIdentifiers: <String>['row:${command.commandId}'],
      verificationMethod: 'test_exact_row_v1',
      safeAutomaticResume: false,
      automaticRetryProhibited: true,
    );
  }

  @override
  Future<AppAgentHandlerResult> executeConfirmed(
    AppAgentCommand command,
  ) async {
    executionCount++;
    committed = true;
    throw TimeoutException('The result was lost after commit.');
  }

  @override
  Future<AppAgentReconciliationResult> reconcileBusinessOperation(
    AppAgentCommand command,
    AppAgentExecutionReceipt receipt,
  ) async {
    return AppAgentReconciliationResult(
      status: committed
          ? AppAgentReconciliationStatus.verifiedSucceeded
          : AppAgentReconciliationStatus.verifiedNotExecuted,
      entityType: 'transaction',
      affectedCount: committed ? 1 : 0,
      safeFailureCode: committed
          ? null
          : AppAgentFailureCodes.recoveryNotExecuted,
    );
  }

  @override
  Future<AppAgentRevalidationResult> revalidate(AppAgentCommand command) async {
    return const AppAgentRevalidationResult(
      isValid: true,
      currentStateFingerprint: 'state-fingerprint-v1',
    );
  }
}

class _ThrowAtCheckpoint implements AppAgentExecutionFaultInjector {
  const _ThrowAtCheckpoint(this.target);

  final AppAgentExecutionCrashPoint target;

  @override
  void checkpoint(AppAgentExecutionCrashPoint point, AppAgentCommand command) {
    if (point == target) {
      throw AppAgentSimulatedProcessInterruption(point);
    }
  }
}
