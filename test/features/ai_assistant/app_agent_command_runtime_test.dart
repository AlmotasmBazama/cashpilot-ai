import 'dart:math';

import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_command_runtime.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/canonical_app_tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 31, 12);

  group('app-agent permission and risk policy', () {
    const policy = AppAgentPolicy();

    test('accepts aligned permissions and rejects prohibited capabilities', () {
      final valid = _command(
        now: now,
        toolId: 'getDashboardSummary',
        commandType: AppAgentCommandType.read,
        permission: AgentPermission.readFinancialData,
        risk: AgentActionRisk.readOnly,
      );
      expect(
        () => policy.validateModelProposal(
          valid,
          descriptor: _canonicalDescriptor(valid.toolId),
        ),
        returnsNormally,
      );

      final mismatched = _command(
        now: now,
        commandType: AppAgentCommandType.update,
        permission: AgentPermission.updateDraft,
        toolId: 'getDashboardSummary',
      );
      expect(
        () => policy.validateModelProposal(
          mismatched,
          descriptor: _canonicalDescriptor(mismatched.toolId),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.permissionDenied,
          ),
        ),
      );

      for (final prohibited in <AppAgentCommand>[
        _command(now: now, toolId: 'setAccountBalance'),
        _command(now: now, risk: AgentActionRisk.prohibited),
        _command(now: now, permission: AgentPermission.executeConfirmedAction),
      ]) {
        expect(
          () => policy.validateModelProposal(
            prohibited,
            descriptor: AppAgentModelProposalDescriptor(
              toolId: prohibited.toolId,
              permission: prohibited.permission,
              risk: prohibited.risk,
              modelCallable: true,
            ),
          ),
          throwsA(
            isA<AppAgentPolicyViolation>().having(
              (error) => error.code,
              'code',
              AppAgentFailureCodes.prohibited,
            ),
          ),
        );
      }
    });

    test('model proposals require a canonical model-callable descriptor', () {
      final readCommand = _command(
        now: now,
        toolId: 'getDashboardSummary',
        commandType: AppAgentCommandType.read,
        permission: AgentPermission.readFinancialData,
        risk: AgentActionRisk.readOnly,
      );
      final draftCommand = _command(now: now);

      expect(
        () => policy.validateModelProposal(readCommand, descriptor: null),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.actionUnavailable,
          ),
        ),
      );
      expect(
        () => policy.validateModelProposal(
          draftCommand,
          descriptor: _canonicalDescriptor(draftCommand.toolId),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.prohibited,
          ),
        ),
      );
      expect(
        () => policy.validateModelProposal(
          readCommand,
          descriptor: AppAgentModelProposalDescriptor(
            toolId: readCommand.toolId,
            permission: AgentPermission.readAppConfiguration,
            risk: readCommand.risk,
            modelCallable: true,
          ),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.permissionDenied,
          ),
        ),
      );
    });

    test('canonical tools carry non-prohibited permissions and risks', () {
      for (final tool in CanonicalAppToolCatalog.safeTools) {
        expect(AppAgentPolicy.prohibitedToolIds, isNot(contains(tool.id)));
        expect(tool.permission, isNot(AgentPermission.executeConfirmedAction));
        expect(tool.risk, isNot(AgentActionRisk.prohibited));
      }
    });

    test('transaction mutation tools are deterministic local-only tools', () {
      final mutations = <String, ({AgentPermission permission})>{
        'updateTransactionDraft': (permission: AgentPermission.updateDraft),
        'deleteTransactionDraft': (permission: AgentPermission.archiveDraft),
        'undoAiAction': (permission: AgentPermission.updateDraft),
      };

      for (final entry in mutations.entries) {
        final descriptor = CanonicalAppToolCatalog.byId(entry.key);
        expect(descriptor, isNotNull);
        expect(descriptor!.modelCallable, isFalse);
        expect(descriptor.permission, entry.value.permission);
        expect(descriptor.risk, AgentActionRisk.medium);
      }
    });

    test('maps risk to the required confirmation level', () {
      expect(
        policy.confirmationLevelFor(AgentActionRisk.readOnly),
        AppAgentConfirmationLevel.none,
      );
      expect(
        policy.confirmationLevelFor(AgentActionRisk.low),
        AppAgentConfirmationLevel.normal,
      );
      expect(
        policy.confirmationLevelFor(AgentActionRisk.medium),
        AppAgentConfirmationLevel.detailed,
      );
      expect(
        policy.confirmationLevelFor(AgentActionRisk.high),
        AppAgentConfirmationLevel.doubleConfirmation,
      );
      expect(
        policy.confirmationLevelFor(AgentActionRisk.prohibited),
        AppAgentConfirmationLevel.protectedNativeWorkflow,
      );
    });

    test('requires money and exchange-rate arguments to be strings', () {
      expect(
        () => _validateTrustedCommand(
          policy,
          _command(
            now: now,
            arguments: const <String, Object?>{
              'amount': '25.50',
              'targetAmount': '5000.00',
              'destinationAmount': '121.25',
              'exchangeRate': '4.85000000',
              'income': '5000.00',
              'expense': '1250.00',
              'spentToDate': '900.00',
              'currentSpending': '700.00',
              'proposedBudget': '1000.00',
              'remaining': '2500.00',
              'monthlyContribution': '250.00',
              'fixedCosts': '800.00',
              'plannedSavings': '500.00',
              'incomeChange': '100.00',
              'scenarioA': '10.00',
              'scenarioB': '20.00',
              'rate': '4.85',
              'contribution': '50.00',
              'fee': '1.00',
              'limit': 10,
              'lineItems': <Object?>[
                <String, Object?>{'source_amount': '10.00'},
              ],
            },
          ),
        ),
        returnsNormally,
      );

      for (final arguments in <Map<String, Object?>>[
        const <String, Object?>{'amount': 25.5},
        const <String, Object?>{'targetAmount': 5000},
        const <String, Object?>{'destinationAmount': 121.25},
        const <String, Object?>{'exchangeRate': 4.85},
        const <String, Object?>{'income': 5000},
        const <String, Object?>{'expense': 1250},
        const <String, Object?>{'spentToDate': 900},
        const <String, Object?>{'currentSpending': 700},
        const <String, Object?>{'proposedBudget': 1000},
        const <String, Object?>{'remaining': 2500},
        const <String, Object?>{'monthlyContribution': 250},
        const <String, Object?>{'fixedCosts': 800},
        const <String, Object?>{'plannedSavings': 500},
        const <String, Object?>{'incomeChange': 100},
        const <String, Object?>{'scenarioA': 10},
        const <String, Object?>{'scenarioB': 20},
        const <String, Object?>{'rate': 4.85},
        const <String, Object?>{'contribution': 50},
        const <String, Object?>{'fee': 1},
        const <String, Object?>{
          'details': <String, Object?>{'source_amount': 25.5},
        },
      ]) {
        expect(
          () => _validateTrustedCommand(
            policy,
            _command(now: now, arguments: arguments),
          ),
          throwsA(
            isA<AppAgentPolicyViolation>().having(
              (error) => error.code,
              'code',
              AppAgentFailureCodes.invalidArguments,
            ),
          ),
        );
      }
    });

    test('command arguments are deep-copied and immutable', () {
      final nested = <String, Object?>{'amount': '25.50'};
      final command = _command(
        now: now,
        arguments: <String, Object?>{'details': nested},
      );

      nested['amount'] = '999.00';
      final storedNested = command.normalizedArguments['details']! as Map;

      expect(storedNested['amount'], '25.50');
      expect(() => storedNested['amount'] = '1000.00', throwsUnsupportedError);
    });

    test('normalizes nested secret keys before rejecting them', () {
      for (final arguments in <Map<String, Object?>>[
        const <String, Object?>{'API_KEY': 'not-accepted'},
        const <String, Object?>{
          'metadata': <String, Object?>{'User_Token': 'not-accepted'},
        },
      ]) {
        expect(
          () => _validateTrustedCommand(
            policy,
            _command(now: now, arguments: arguments),
          ),
          throwsA(
            isA<AppAgentPolicyViolation>().having(
              (error) => error.code,
              'code',
              AppAgentFailureCodes.permissionDenied,
            ),
          ),
        );
      }
    });

    test('rejects direct balance fields for every write proposal type', () {
      for (final proposal in <(AppAgentCommandType, AgentPermission)>[
        (AppAgentCommandType.create, AgentPermission.createDraft),
        (AppAgentCommandType.update, AgentPermission.updateDraft),
        (AppAgentCommandType.archive, AgentPermission.archiveDraft),
        (AppAgentCommandType.bulk, AgentPermission.bulkDraft),
      ]) {
        expect(
          () => _validateTrustedCommand(
            policy,
            _command(
              now: now,
              commandType: proposal.$1,
              permission: proposal.$2,
              arguments: const <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'account': <String, Object?>{'Current_Balance': '100.00'},
                  },
                ],
              },
            ),
          ),
          throwsA(
            isA<AppAgentPolicyViolation>().having(
              (error) => error.code,
              'code',
              AppAgentFailureCodes.prohibited,
            ),
          ),
        );
      }
    });
  });

  group('app-agent confirmation and execution runtime', () {
    late InMemoryAppAgentCommandStore commandStore;
    late InMemoryAppAgentConfirmationProofStore proofStore;
    late InMemoryAppAgentAuditStore auditStore;
    late _MutableAccountScopeProvider scopeProvider;

    setUp(() {
      commandStore = InMemoryAppAgentCommandStore(
        canonicalDescriptors: _canonicalModelDescriptors,
      );
      proofStore = InMemoryAppAgentConfirmationProofStore();
      auditStore = InMemoryAppAgentAuditStore();
      scopeProvider = _MutableAccountScopeProvider('scope-a');
    });

    test(
      'store rejects a non-model-callable proposal and accepts it only locally',
      () async {
        final command = _command(now: now);

        await expectLater(
          commandStore.saveCommand(command),
          throwsA(
            isA<AppAgentPolicyViolation>().having(
              (error) => error.code,
              'code',
              AppAgentFailureCodes.prohibited,
            ),
          ),
        );

        await commandStore.saveTrustedLocalCommand(command);
        expect(
          await commandStore.readCommand(
            commandId: command.commandId,
            accountScope: command.userAccountScope,
          ),
          isNotNull,
        );
      },
    );

    test('trusted local commands require canonical ID and metadata', () async {
      final nonCanonical = _command(
        now: now,
        toolId: 'locallyRegisteredButNonCanonical',
      );

      await expectLater(
        commandStore.saveTrustedLocalCommand(nonCanonical),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.actionUnavailable,
          ),
        ),
      );
      expect(
        await commandStore.readCommand(
          commandId: nonCanonical.commandId,
          accountScope: nonCanonical.userAccountScope,
        ),
        isNull,
      );

      final mismatchedRisk = _command(
        now: now,
        commandId: 'mismatched-risk',
        risk: AgentActionRisk.medium,
      );
      await expectLater(
        commandStore.saveTrustedLocalCommand(mismatchedRisk),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.permissionDenied,
          ),
        ),
      );
      expect(
        await commandStore.readCommand(
          commandId: mismatchedRisk.commandId,
          accountScope: mismatchedRisk.userAccountScope,
        ),
        isNull,
      );
    });

    test('medium and high-risk previews require meaningful detail', () async {
      final medium = _command(
        now: now,
        commandId: 'medium-command',
        toolId: 'createTransferDraft',
        risk: AgentActionRisk.medium,
      );
      await commandStore.saveTrustedLocalCommand(medium);

      await expectLater(
        commandStore.savePreview(
          accountScope: medium.userAccountScope,
          preview: AppAgentPreview(
            commandId: medium.commandId,
            title: 'Review transfer',
            entityType: 'transfer',
            fields: const <AppAgentPreviewField>[],
            risk: medium.risk,
            confirmationLevel: AppAgentConfirmationLevel.detailed,
            stateFingerprint: 'medium-state',
            createdAt: now,
          ),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.invalidArguments,
          ),
        ),
      );

      final high = _command(
        now: now,
        commandId: 'high-command',
        toolId: 'archiveBudgetDraft',
        commandType: AppAgentCommandType.archive,
        permission: AgentPermission.archiveDraft,
        risk: AgentActionRisk.high,
      );
      await commandStore.saveTrustedLocalCommand(high);
      await expectLater(
        commandStore.savePreview(
          accountScope: high.userAccountScope,
          preview: AppAgentPreview(
            commandId: high.commandId,
            title: 'Review archive',
            entityType: 'budget',
            fields: const <AppAgentPreviewField>[
              AppAgentPreviewField(label: 'Status', proposedValue: 'Archived'),
            ],
            risk: high.risk,
            confirmationLevel: AppAgentConfirmationLevel.doubleConfirmation,
            stateFingerprint: 'high-state',
            createdAt: now,
          ),
        ),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.invalidArguments,
          ),
        ),
      );
    });

    test(
      'execution requires confirmation issued by the local controller',
      () async {
        final command = _command(now: now);
        await _prepareAwaiting(commandStore, command, now: now);
        final handler = _RecordingHandler();
        final executor = _executor(
          commandStore: commandStore,
          proofStore: proofStore,
          auditStore: auditStore,
          scopeProvider: scopeProvider,
          handler: handler,
          now: now,
        );

        final result = await executor.execute(
          AppAgentConfirmation(
            commandId: command.commandId,
            userAccountScope: command.userAccountScope,
            confirmedAt: now,
            method: AppAgentConfirmationMethod.primaryButton,
            authorityProof: 'not-issued-by-the-controller',
          ),
        );

        expect(result.verified, isFalse);
        expect(
          result.safeFailureCode,
          AppAgentFailureCodes.confirmationRequired,
        );
        expect(handler.executedCommandIds, isEmpty);
      },
    );

    test(
      'confirmation proof cannot be relabeled with another method',
      () async {
        final command = _command(now: now);
        await _prepareAwaiting(commandStore, command, now: now);
        final issued = await _confirm(
          commandStore: commandStore,
          proofStore: proofStore,
          command: command,
          now: now,
        );
        final handler = _RecordingHandler();

        final result =
            await _executor(
              commandStore: commandStore,
              proofStore: proofStore,
              auditStore: auditStore,
              scopeProvider: scopeProvider,
              handler: handler,
              now: now,
            ).execute(
              AppAgentConfirmation(
                commandId: issued.commandId,
                userAccountScope: issued.userAccountScope,
                confirmedAt: issued.confirmedAt,
                method: AppAgentConfirmationMethod.doubleConfirmation,
                authorityProof: issued.authorityProof,
              ),
            );

        expect(result.verified, isFalse);
        expect(
          result.safeFailureCode,
          AppAgentFailureCodes.invalidConfirmation,
        );
        expect(handler.executedCommandIds, isEmpty);
        expect(
          await auditStore.readRecent(accountScope: command.userAccountScope),
          isEmpty,
        );
      },
    );

    test(
      'high-risk action requires two explicit high-risk confirmations',
      () async {
        final command = _highRiskCommand(now: now);
        await _prepareAwaiting(commandStore, command, now: now);
        final controller = _confirmationController(
          commandStore: commandStore,
          proofStore: proofStore,
          now: now,
        );

        final wrongMethod = await controller.confirm(
          commandId: command.commandId,
          accountScope: command.userAccountScope,
          method: AppAgentConfirmationMethod.primaryButton,
        );
        expect(wrongMethod.confirmation, isNull);
        expect(
          wrongMethod.safeFailureCode,
          AppAgentFailureCodes.doubleConfirmationRequired,
        );

        final first = await controller.confirm(
          commandId: command.commandId,
          accountScope: command.userAccountScope,
          method: AppAgentConfirmationMethod.doubleConfirmation,
        );
        expect(first.confirmation, isNull);
        expect(first.requiresSecondConfirmation, isTrue);
        expect(
          first.safeFailureCode,
          AppAgentFailureCodes.doubleConfirmationRequired,
        );

        await controller.clearScope('scope-b');

        final second = await controller.confirm(
          commandId: command.commandId,
          accountScope: command.userAccountScope,
          method: AppAgentConfirmationMethod.doubleConfirmation,
        );
        expect(second.requiresSecondConfirmation, isFalse);
        expect(second.confirmation, isNotNull);
        expect(
          (await commandStore.readCommand(
            commandId: command.commandId,
            accountScope: command.userAccountScope,
          ))?.status,
          AppAgentCommandStatus.confirmed,
        );
      },
    );

    test(
      'high-risk first approval expires before the second approval',
      () async {
        var currentTime = now;
        final command = _highRiskCommand(now: now);
        await _prepareAwaiting(commandStore, command, now: now);
        final controller = AppAgentConfirmationController(
          commandStore: commandStore,
          proofStore: proofStore,
          clock: () => currentTime,
          secureRandom: Random(7),
          highRiskApprovalWindow: const Duration(seconds: 20),
        );

        final first = await controller.confirm(
          commandId: command.commandId,
          accountScope: command.userAccountScope,
          method: AppAgentConfirmationMethod.doubleConfirmation,
        );
        expect(first.requiresSecondConfirmation, isTrue);

        currentTime = now.add(const Duration(seconds: 21));
        final expiredSecond = await controller.confirm(
          commandId: command.commandId,
          accountScope: command.userAccountScope,
          method: AppAgentConfirmationMethod.doubleConfirmation,
        );
        expect(expiredSecond.confirmation, isNull);
        expect(expiredSecond.requiresSecondConfirmation, isTrue);
        expect(
          expiredSecond.safeFailureCode,
          AppAgentFailureCodes.doubleConfirmationRequired,
        );
      },
    );

    test(
      'confirmation proofs are scope-bound, one-time, and expiring',
      () async {
        await proofStore.saveProof(
          commandId: 'command-proof',
          accountScope: 'scope-a',
          proof: 'opaque-proof',
          method: AppAgentConfirmationMethod.primaryButton,
          expiresAt: now.add(const Duration(minutes: 1)),
        );

        expect(
          await proofStore.consumeProof(
            commandId: 'command-proof',
            accountScope: 'scope-b',
            proof: 'opaque-proof',
            method: AppAgentConfirmationMethod.primaryButton,
            now: now,
          ),
          isFalse,
        );
        expect(
          await proofStore.consumeProof(
            commandId: 'command-proof',
            accountScope: 'scope-a',
            proof: 'opaque-proof',
            method: AppAgentConfirmationMethod.primaryButton,
            now: now,
          ),
          isTrue,
        );
        expect(
          await proofStore.consumeProof(
            commandId: 'command-proof',
            accountScope: 'scope-a',
            proof: 'opaque-proof',
            method: AppAgentConfirmationMethod.primaryButton,
            now: now,
          ),
          isFalse,
        );

        await proofStore.saveProof(
          commandId: 'expired-proof',
          accountScope: 'scope-a',
          proof: 'expired',
          method: AppAgentConfirmationMethod.primaryButton,
          expiresAt: now,
        );
        expect(
          await proofStore.consumeProof(
            commandId: 'expired-proof',
            accountScope: 'scope-a',
            proof: 'expired',
            method: AppAgentConfirmationMethod.primaryButton,
            now: now,
          ),
          isFalse,
        );
      },
    );

    test(
      'account-scope mismatch blocks execution before the handler',
      () async {
        final command = _command(now: now);
        await _prepareAwaiting(commandStore, command, now: now);
        final confirmation = await _confirm(
          commandStore: commandStore,
          proofStore: proofStore,
          command: command,
          now: now,
        );
        final handler = _RecordingHandler();
        scopeProvider.currentAccountScope = 'scope-b';

        final result = await _executor(
          commandStore: commandStore,
          proofStore: proofStore,
          auditStore: auditStore,
          scopeProvider: scopeProvider,
          handler: handler,
          now: now,
        ).execute(confirmation);

        expect(result.verified, isFalse);
        expect(
          result.safeFailureCode,
          AppAgentFailureCodes.accountScopeMismatch,
        );
        expect(handler.executedCommandIds, isEmpty);
      },
    );

    test('expired command cannot be confirmed and is marked expired', () async {
      final command = _command(
        now: now,
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );
      await _prepareAwaiting(commandStore, command, now: now);

      final decision =
          await _confirmationController(
            commandStore: commandStore,
            proofStore: proofStore,
            now: now,
          ).confirm(
            commandId: command.commandId,
            accountScope: command.userAccountScope,
            method: AppAgentConfirmationMethod.primaryButton,
          );

      expect(decision.confirmation, isNull);
      expect(decision.safeFailureCode, AppAgentFailureCodes.expired);
      expect(
        (await commandStore.readCommand(
          commandId: command.commandId,
          accountScope: command.userAccountScope,
        ))?.status,
        AppAgentCommandStatus.expired,
      );
    });

    test('stale preview fails closed before executing the handler', () async {
      final command = _command(now: now);
      await _prepareAwaiting(
        commandStore,
        command,
        now: now,
        fingerprint: 'preview-state',
      );
      final confirmation = await _confirm(
        commandStore: commandStore,
        proofStore: proofStore,
        command: command,
        now: now,
      );
      final handler = _RecordingHandler(currentStateFingerprint: 'newer-state');

      final result = await _executor(
        commandStore: commandStore,
        proofStore: proofStore,
        auditStore: auditStore,
        scopeProvider: scopeProvider,
        handler: handler,
        now: now,
      ).execute(confirmation);

      expect(result.verified, isFalse);
      expect(result.safeFailureCode, AppAgentFailureCodes.stalePreview);
      expect(handler.executedCommandIds, isEmpty);
      final stored = await commandStore.readCommand(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
      );
      expect(stored?.status, AppAgentCommandStatus.failed);
      expect(stored?.safeFailureCode, AppAgentFailureCodes.stalePreview);
      final audit = await auditStore.readRecent(
        accountScope: command.userAccountScope,
      );
      expect(audit, hasLength(1));
      expect(audit.single.result, AppAgentCommandStatus.failed);
      expect(audit.single.safeFailureCode, AppAgentFailureCodes.stalePreview);
      expect(handler.executedCommandIds, isEmpty);
    });

    test(
      'verified success executes once and records one safe audit event',
      () async {
        final command = _command(now: now);
        await _prepareAwaiting(commandStore, command, now: now);
        final confirmation = await _confirm(
          commandStore: commandStore,
          proofStore: proofStore,
          command: command,
          now: now,
        );
        final handler = _RecordingHandler(
          onExecute: (_) => const AppAgentHandlerResult(
            verified: true,
            entityType: 'transaction',
            affectedCount: 1,
            undoAvailable: true,
            undoToken: 'opaque-undo-token',
          ),
        );
        final executor = _executor(
          commandStore: commandStore,
          proofStore: proofStore,
          auditStore: auditStore,
          scopeProvider: scopeProvider,
          handler: handler,
          now: now,
        );

        final first = await executor.execute(confirmation);
        final duplicate = await executor.execute(confirmation);

        expect(first.verified, isTrue);
        expect(first.status, AppAgentCommandStatus.succeeded);
        expect(first.entityType, 'transaction');
        expect(first.affectedCount, 1);
        expect(first.undoAvailable, isTrue);
        expect(duplicate.verified, isFalse);
        expect(
          duplicate.safeFailureCode,
          AppAgentFailureCodes.duplicateExecutionPrevented,
        );
        expect(handler.executedCommandIds, <String>[command.commandId]);
        expect(
          (await commandStore.readCommand(
            commandId: command.commandId,
            accountScope: command.userAccountScope,
          ))?.status,
          AppAgentCommandStatus.succeeded,
        );

        final audit = await auditStore.readRecent(
          accountScope: command.userAccountScope,
        );
        expect(audit, hasLength(1));
        expect(audit.single.commandId, command.commandId);
        expect(audit.single.actionType, command.toolId);
        expect(audit.single.entityType, 'transaction');
        expect(audit.single.result, AppAgentCommandStatus.succeeded);
        expect(
          audit.single.confirmationMethod,
          AppAgentConfirmationMethod.primaryButton,
        );
        expect(audit.single.undoAvailable, isTrue);
        expect(
          audit.single.toJson(),
          isNot(containsPair('undoToken', anything)),
        );
      },
    );

    test('audit reads and clearing are isolated by account scope', () async {
      AppAgentAuditEvent event(String commandId, String accountScope) {
        return AppAgentAuditEvent(
          commandId: commandId,
          userAccountScope: accountScope,
          actionType: 'createExpenseDraft',
          entityType: 'transaction',
          result: AppAgentCommandStatus.succeeded,
          timestamp: now,
          confirmationMethod: AppAgentConfirmationMethod.primaryButton,
          undoAvailable: false,
        );
      }

      await auditStore.append(event('command-a', 'scope-a'));
      await auditStore.append(event('command-b', 'scope-b'));

      expect(
        (await auditStore.readRecent(
          accountScope: 'scope-a',
        )).map((item) => item.commandId),
        <String>['command-a'],
      );
      expect(
        (await auditStore.readRecent(
          accountScope: 'scope-b',
        )).map((item) => item.commandId),
        <String>['command-b'],
      );

      await auditStore.clearScope('scope-a');
      expect(await auditStore.readRecent(accountScope: 'scope-a'), isEmpty);
      expect(
        (await auditStore.readRecent(accountScope: 'scope-b')).single.commandId,
        'command-b',
      );
    });

    test(
      'bounded sequential plan stops and reports visible partial failure',
      () async {
        final commands = <AppAgentCommand>[
          _command(now: now, commandId: 'command-1'),
          _command(now: now, commandId: 'command-2'),
          _command(now: now, commandId: 'command-3'),
        ];
        final confirmations = <String, AppAgentConfirmation>{};
        for (final command in commands) {
          await _prepareAwaiting(commandStore, command, now: now);
          confirmations[command.commandId] = await _confirm(
            commandStore: commandStore,
            proofStore: proofStore,
            command: command,
            now: now,
          );
        }
        final handler = _RecordingHandler(
          onExecute: (command) => command.commandId == 'command-2'
              ? const AppAgentHandlerResult(
                  verified: false,
                  entityType: 'budget',
                  affectedCount: 0,
                  safeFailureCode: AppAgentFailureCodes.partialFailure,
                )
              : const AppAgentHandlerResult(
                  verified: true,
                  entityType: 'budget',
                  affectedCount: 1,
                ),
        );
        final executor = _executor(
          commandStore: commandStore,
          proofStore: proofStore,
          auditStore: auditStore,
          scopeProvider: scopeProvider,
          handler: handler,
          now: now,
        );
        final plan = AgentPlan(
          planId: 'plan-1',
          conversationId: 'conversation-1',
          userAccountScope: 'scope-a',
          steps: const <AgentPlanStep>[
            AgentPlanStep(
              stepId: 'step-2',
              commandId: 'command-2',
              position: 2,
            ),
            AgentPlanStep(
              stepId: 'step-1',
              commandId: 'command-1',
              position: 1,
            ),
            AgentPlanStep(
              stepId: 'step-3',
              commandId: 'command-3',
              position: 3,
            ),
          ],
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 10)),
        );

        final result = await AppAgentPlanExecutor(
          commandExecutor: executor,
        ).executeSequential(plan: plan, confirmations: confirmations);

        expect(result.status, AppAgentCommandStatus.partiallySucceeded);
        expect(result.results.map((item) => item.commandId), <String>[
          'command-1',
          'command-2',
        ]);
        expect(result.results.first.verified, isTrue);
        expect(result.results.last.verified, isFalse);
        expect(
          result.results.last.safeFailureCode,
          AppAgentFailureCodes.partialFailure,
        );
        expect(handler.executedCommandIds, <String>['command-1', 'command-2']);
        expect(
          (await commandStore.readCommand(
            commandId: 'command-3',
            accountScope: 'scope-a',
          ))?.status,
          AppAgentCommandStatus.confirmed,
        );
      },
    );

    test('a partially-succeeded step makes the plan partial', () async {
      final command = _command(now: now);
      await _prepareAwaiting(commandStore, command, now: now);
      final confirmation = await _confirm(
        commandStore: commandStore,
        proofStore: proofStore,
        command: command,
        now: now,
      );
      final handler = _RecordingHandler(
        onExecute: (_) => const AppAgentHandlerResult(
          verified: false,
          entityType: 'transaction',
          affectedCount: 1,
          partiallySucceeded: true,
        ),
      );
      final plan = AgentPlan(
        planId: 'partial-plan',
        conversationId: command.conversationId,
        userAccountScope: command.userAccountScope,
        steps: <AgentPlanStep>[
          AgentPlanStep(
            stepId: 'partial-step',
            commandId: command.commandId,
            position: 1,
          ),
        ],
        createdAt: now,
        expiresAt: command.expiresAt,
      );

      final result =
          await AppAgentPlanExecutor(
            commandExecutor: _executor(
              commandStore: commandStore,
              proofStore: proofStore,
              auditStore: auditStore,
              scopeProvider: scopeProvider,
              handler: handler,
              now: now,
            ),
          ).executeSequential(
            plan: plan,
            confirmations: <String, AppAgentConfirmation>{
              command.commandId: confirmation,
            },
          );

      expect(result.status, AppAgentCommandStatus.partiallySucceeded);
      expect(
        result.results.single.status,
        AppAgentCommandStatus.partiallySucceeded,
      );
      expect(result.results.single.verified, isFalse);
      expect(
        result.results.single.safeFailureCode,
        AppAgentFailureCodes.partialFailure,
      );
    });

    test('plan step count is bounded', () async {
      final plan = AgentPlan(
        planId: 'oversized-plan',
        conversationId: 'conversation-1',
        userAccountScope: 'scope-a',
        steps: List<AgentPlanStep>.generate(
          9,
          (index) => AgentPlanStep(
            stepId: 'step-$index',
            commandId: 'command-$index',
            position: index,
          ),
        ),
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      final handler = _RecordingHandler();

      await expectLater(
        AppAgentPlanExecutor(
          commandExecutor: _executor(
            commandStore: commandStore,
            proofStore: proofStore,
            auditStore: auditStore,
            scopeProvider: scopeProvider,
            handler: handler,
            now: now,
          ),
        ).executeSequential(plan: plan, confirmations: const {}),
        throwsA(
          isA<AppAgentPolicyViolation>().having(
            (error) => error.code,
            'code',
            AppAgentFailureCodes.invalidArguments,
          ),
        ),
      );
    });

    test(
      'plan scope and plan lifecycle are validated before execution',
      () async {
        final executor = AppAgentPlanExecutor(
          commandExecutor: _executor(
            commandStore: commandStore,
            proofStore: proofStore,
            auditStore: auditStore,
            scopeProvider: scopeProvider,
            handler: _RecordingHandler(),
            now: now,
          ),
        );
        AgentPlan plan({
          required String id,
          String accountScope = 'scope-a',
          DateTime? createdAt,
          DateTime? expiresAt,
        }) => AgentPlan(
          planId: id,
          conversationId: 'conversation-1',
          userAccountScope: accountScope,
          steps: const <AgentPlanStep>[
            AgentPlanStep(
              stepId: 'step-1',
              commandId: 'command-1',
              position: 1,
            ),
          ],
          createdAt: createdAt ?? now,
          expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
        );

        for (final invalid in <(AgentPlan, String)>[
          (
            plan(id: 'wrong-scope', accountScope: 'scope-b'),
            AppAgentFailureCodes.accountScopeMismatch,
          ),
          (
            plan(
              id: 'future-plan',
              createdAt: now.add(const Duration(seconds: 1)),
            ),
            AppAgentFailureCodes.invalidArguments,
          ),
          (
            plan(
              id: 'expired-plan',
              createdAt: now.subtract(const Duration(minutes: 1)),
              expiresAt: now,
            ),
            AppAgentFailureCodes.expired,
          ),
        ]) {
          await expectLater(
            executor.executeSequential(
              plan: invalid.$1,
              confirmations: const {},
            ),
            throwsA(
              isA<AppAgentPolicyViolation>().having(
                (error) => error.code,
                'code',
                invalid.$2,
              ),
            ),
          );
        }
      },
    );

    test('plan commands are bound to conversation and plan lifetime', () async {
      final wrongConversation = _command(
        now: now,
        commandId: 'wrong-conversation',
        conversationId: 'another-conversation',
      );
      final shortLived = _command(
        now: now,
        commandId: 'short-lived',
        expiresAt: now.add(const Duration(minutes: 2)),
      );
      await commandStore.saveTrustedLocalCommand(wrongConversation);
      await commandStore.saveTrustedLocalCommand(shortLived);
      final executor = AppAgentPlanExecutor(
        commandExecutor: _executor(
          commandStore: commandStore,
          proofStore: proofStore,
          auditStore: auditStore,
          scopeProvider: scopeProvider,
          handler: _RecordingHandler(),
          now: now,
        ),
      );
      AgentPlan planFor(AppAgentCommand command) => AgentPlan(
        planId: 'plan-${command.commandId}',
        conversationId: 'conversation-1',
        userAccountScope: 'scope-a',
        steps: <AgentPlanStep>[
          AgentPlanStep(
            stepId: 'step-${command.commandId}',
            commandId: command.commandId,
            position: 1,
          ),
        ],
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );

      for (final command in <AppAgentCommand>[wrongConversation, shortLived]) {
        await expectLater(
          executor.executeSequential(
            plan: planFor(command),
            confirmations: const {},
          ),
          throwsA(
            isA<AppAgentPolicyViolation>().having(
              (error) => error.code,
              'code',
              AppAgentFailureCodes.invalidArguments,
            ),
          ),
        );
      }
    });
  });
}

final List<AppAgentModelProposalDescriptor> _canonicalModelDescriptors =
    <AppAgentModelProposalDescriptor>[
      ...CanonicalAppToolCatalog.safeTools.map(
        (tool) => AppAgentModelProposalDescriptor(
          toolId: tool.id,
          permission: tool.permission,
          risk: tool.risk,
          modelCallable: tool.modelCallable,
        ),
      ),
      const AppAgentModelProposalDescriptor(
        toolId: 'archiveBudgetDraft',
        permission: AgentPermission.archiveDraft,
        risk: AgentActionRisk.high,
        modelCallable: false,
      ),
    ];

AppAgentModelProposalDescriptor _canonicalDescriptor(String toolId) =>
    _canonicalModelDescriptors.firstWhere(
      (descriptor) => descriptor.toolId == toolId,
    );

void _validateTrustedCommand(AppAgentPolicy policy, AppAgentCommand command) {
  policy.validateTrustedLocalCommand(
    command,
    descriptor: _canonicalDescriptor(command.toolId),
  );
}

AppAgentCommand _highRiskCommand({required DateTime now}) => _command(
  now: now,
  toolId: 'archiveBudgetDraft',
  commandType: AppAgentCommandType.archive,
  permission: AgentPermission.archiveDraft,
  risk: AgentActionRisk.high,
);

AppAgentCommand _command({
  required DateTime now,
  String commandId = 'command-1',
  String toolId = 'createExpenseDraft',
  AppAgentCommandType commandType = AppAgentCommandType.create,
  AgentPermission permission = AgentPermission.createDraft,
  AgentActionRisk risk = AgentActionRisk.low,
  Map<String, Object?> arguments = const <String, Object?>{'amount': '25.50'},
  String conversationId = 'conversation-1',
  String userAccountScope = 'scope-a',
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  return AppAgentCommand(
    commandId: commandId,
    conversationId: conversationId,
    userAccountScope: userAccountScope,
    commandType: commandType,
    toolId: toolId,
    normalizedArguments: arguments,
    permission: permission,
    risk: risk,
    createdAt: createdAt ?? now.subtract(const Duration(minutes: 1)),
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 10)),
    status: AppAgentCommandStatus.readyForPreview,
  );
}

Future<void> _prepareAwaiting(
  InMemoryAppAgentCommandStore store,
  AppAgentCommand command, {
  required DateTime now,
  String fingerprint = 'state-v1',
}) async {
  await store.saveTrustedLocalCommand(command);
  await store.savePreview(
    accountScope: command.userAccountScope,
    preview: AppAgentPreview(
      commandId: command.commandId,
      title: 'Review change',
      entityType: 'transaction',
      fields: const <AppAgentPreviewField>[
        AppAgentPreviewField(label: 'Amount', proposedValue: '25.50 L Y D'),
      ],
      risk: command.risk,
      confirmationLevel: const AppAgentPolicy().confirmationLevelFor(
        command.risk,
      ),
      stateFingerprint: fingerprint,
      createdAt: now,
      affectedItems: command.risk == AgentActionRisk.high
          ? const <AppAgentAffectedItem>[
              AppAgentAffectedItem(
                opaqueReference: 'local-item-1',
                label: 'Selected item',
                summary: 'One item will be changed.',
              ),
            ]
          : const <AppAgentAffectedItem>[],
    ),
  );
}

AppAgentConfirmationController _confirmationController({
  required InMemoryAppAgentCommandStore commandStore,
  required InMemoryAppAgentConfirmationProofStore proofStore,
  required DateTime now,
}) {
  return AppAgentConfirmationController(
    commandStore: commandStore,
    proofStore: proofStore,
    clock: () => now,
    secureRandom: Random(7),
  );
}

Future<AppAgentConfirmation> _confirm({
  required InMemoryAppAgentCommandStore commandStore,
  required InMemoryAppAgentConfirmationProofStore proofStore,
  required AppAgentCommand command,
  required DateTime now,
}) async {
  final decision =
      await _confirmationController(
        commandStore: commandStore,
        proofStore: proofStore,
        now: now,
      ).confirm(
        commandId: command.commandId,
        accountScope: command.userAccountScope,
        method: AppAgentConfirmationMethod.primaryButton,
      );
  expect(decision.safeFailureCode, isNull);
  return decision.confirmation!;
}

AppAgentCommandExecutor _executor({
  required InMemoryAppAgentCommandStore commandStore,
  required InMemoryAppAgentConfirmationProofStore proofStore,
  required InMemoryAppAgentAuditStore auditStore,
  required _MutableAccountScopeProvider scopeProvider,
  required _RecordingHandler handler,
  required DateTime now,
}) {
  return AppAgentCommandExecutor(
    commandStore: commandStore,
    auditStore: auditStore,
    proofStore: proofStore,
    handlerRegistry: MapAppAgentCommandHandlerRegistry(<AppAgentCommandHandler>[
      handler,
    ]),
    accountScopeProvider: scopeProvider,
    clock: () => now,
  );
}

class _MutableAccountScopeProvider implements AppAgentAccountScopeProvider {
  _MutableAccountScopeProvider(this.currentAccountScope);

  @override
  String? currentAccountScope;
}

class _RecordingHandler implements AppAgentCommandHandler {
  _RecordingHandler({
    this.currentStateFingerprint = 'state-v1',
    AppAgentHandlerResult Function(AppAgentCommand)? onExecute,
  }) : _onExecute =
           onExecute ??
           ((_) => const AppAgentHandlerResult(
             verified: true,
             entityType: 'transaction',
             affectedCount: 1,
           ));

  final String currentStateFingerprint;
  final AppAgentHandlerResult Function(AppAgentCommand) _onExecute;
  final List<String> executedCommandIds = <String>[];

  @override
  String get toolId => 'createExpenseDraft';

  @override
  AgentPermission get permission => AgentPermission.createDraft;

  @override
  AgentActionRisk get risk => AgentActionRisk.low;

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
    executedCommandIds.add(command.commandId);
    return _onExecute(command);
  }
}
