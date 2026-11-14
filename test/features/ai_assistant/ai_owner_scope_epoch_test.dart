import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/governed_ai_tool_registry.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/riverpod_financial_agent_data_gateway.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_durable_action_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/budgets/application/providers/budgets_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _scopeA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _scopeB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final _testScopeProvider = NotifierProvider<_TestScopeController, String>(
  _TestScopeController.new,
);

final _gatewayUnderTestProvider = Provider<RiverpodFinancialAgentDataGateway>((
  ref,
) {
  final boundScope = ref.watch(_testScopeProvider);
  return RiverpodFinancialAgentDataGateway(
    ref,
    boundOwnerScope: _bindingFor(boundScope),
    currentOwnerScope: () => _bindingFor(ref.read(_testScopeProvider)),
  );
});

void main() {
  group('AI owner-scope epoch isolation', () {
    test(
      'A permissive/safe policy fails closed while B settings and health load',
      () async {
        final settingsStore = _DelayedSettingsStore();
        final healthB = Completer<OwnerScopeHealth>();
        final database = AppDatabase(executor: NativeDatabase.memory());
        final scopeA =
            OwnerScopeDerivation.fromTrustedDeletionRecoveryCommitment(_scopeA);
        final scopeB =
            OwnerScopeDerivation.fromTrustedDeletionRecoveryCommitment(_scopeB);
        final sessionA = ScopedAppDatabaseSession(
          database: database,
          scope: scopeA,
        );
        final sessionB = ScopedAppDatabaseSession(
          database: database,
          scope: scopeB,
        );
        var reconciliationDependenciesRead = 0;
        final container = ProviderContainer(
          overrides: [
            aiAppControlFeatureFlagsProvider.overrideWithValue(
              _allCapabilitiesEnabled,
            ),
            aiAppControlScopeHashProvider.overrideWith(
              (ref) => ref.watch(_testScopeProvider),
            ),
            aiToolOwnerScopeBindingProvider.overrideWith(
              (ref) => _bindingFor(ref.watch(_testScopeProvider)),
            ),
            aiAppControlSettingsStoreProvider.overrideWithValue(settingsStore),
            backupOperationFenceProvider.overrideWithValue(
              BackupOperationFence(),
            ),
            scopedAppDatabaseSessionProvider.overrideWith(
              (ref) => ref.watch(_testScopeProvider) == _scopeA
                  ? sessionA
                  : sessionB,
            ),
            ownerScopeHealthProvider.overrideWith((ref) {
              final scope = ref.watch(_testScopeProvider);
              if (scope == _scopeA) {
                return Future<OwnerScopeHealth>.value(_safeHealth);
              }
              return healthB.future;
            }),
            appAgentCommandStoreProvider.overrideWith((ref) {
              reconciliationDependenciesRead += 1;
              throw StateError(
                'Reconciliation must not resolve stores while policy reloads.',
              );
            }),
          ],
        );
        addTearDown(() async {
          if (!settingsStore.scopeB.isCompleted) {
            settingsStore.scopeB.complete(
              const AiAppControlSettings.conservative(),
            );
          }
          if (!healthB.isCompleted) {
            healthB.complete(_safeHealth);
          }
          container.dispose();
          sessionA.invalidate();
          sessionB.invalidate();
          await database.close();
        });

        await container.read(aiAppControlSettingsControllerProvider.future);
        await container.read(ownerScopeHealthProvider.future);
        expect(
          container
              .read(effectiveAiAppControlPolicyProvider)
              .canReadFinancialData,
          isTrue,
        );

        container.read(_testScopeProvider.notifier).setScope(_scopeB);
        await Future<void>.delayed(Duration.zero);

        final loadingPolicy = container.read(
          effectiveAiAppControlPolicyProvider,
        );
        expect(loadingPolicy.appControlAvailable, isFalse);
        expect(loadingPolicy.canReadFinancialData, isFalse);
        expect(loadingPolicy.canNavigate, isFalse);
        expect(loadingPolicy.canCreateTransactionDraft, isFalse);
        expect(loadingPolicy.canExecuteConfirmedFinancialCreate, isFalse);
        final loadingRecovery = await container.read(
          appAgentStartupReconciliationProvider.future,
        );
        expect(loadingRecovery.inspectedCount, 0);
        expect(reconciliationDependenciesRead, 0);

        settingsStore.scopeB.complete(
          const AiAppControlSettings.conservative(),
        );
        healthB.complete(_safeHealth);
        await container.read(aiAppControlSettingsControllerProvider.future);
        await container.read(ownerScopeHealthProvider.future);
        final settledPolicy = container.read(
          effectiveAiAppControlPolicyProvider,
        );
        expect(settledPolicy.appControlAvailable, isTrue);
        expect(settledPolicy.canReadFinancialData, isFalse);
        expect(settledPolicy.canNavigate, isFalse);
        expect(settledPolicy.canExecuteConfirmedFinancialCreate, isFalse);
      },
    );

    test(
      'tool started under A aborts after an A-to-B await boundary',
      () async {
        final toolStarted = Completer<void>();
        final releaseTool = Completer<void>();
        var currentScope = _scopeA;
        final registry = GovernedAiToolRegistry(
          tools: <RegisteredAiTool>[
            RegisteredAiTool(
              definition: const AiToolDefinition(
                name: 'delayed_financial_read',
                description: 'Synthetic delayed owner-scoped read.',
                permission: AgentPermission.readFinancialData,
              ),
              handler: (arguments, context) async {
                toolStarted.complete();
                await releaseTool.future;
                return const AiToolResult(
                  toolName: 'delayed_financial_read',
                  data: <String, Object?>{'bounded': true},
                );
              },
            ),
          ],
          permissionPolicy: const DefaultAiToolPermissionPolicy(),
          currentOwnerScope: () => _bindingFor(currentScope),
        );
        addTearDown(() {
          if (!releaseTool.isCompleted) {
            releaseTool.complete();
          }
        });

        final result = registry.execute(
          const AiAgentToolCall(
            id: 'delayed-call',
            name: 'delayed_financial_read',
            arguments: <String, Object?>{},
          ),
          _contextFor(_scopeA),
        );
        await toolStarted.future;

        currentScope = _scopeB;
        releaseTool.complete();

        await expectLater(result, throwsA(_scopeChangedFailure));
        expect(currentScope, _scopeB);
      },
    );

    test(
      'real financial gateway keeps an in-flight A read out of B providers and egress',
      () async {
        final repositoryA = _DelayedBudgetSummaryRepository();
        final repositoryB = _ImmediateBudgetSummaryRepository(
          _summaryFor(_scopeB),
        );
        final providerReads = <String>[];
        final container = ProviderContainer(
          overrides: [
            aiToolOwnerScopeBindingProvider.overrideWith(
              (ref) => _bindingFor(ref.watch(_testScopeProvider)),
            ),
            financialAgentOwnerBoundDataProvider.overrideWith((ref, binding) {
              providerReads.add(binding.accountScope);
              final repository = binding.accountScope == _scopeA
                  ? repositoryA.read
                  : repositoryB.read;
              return _ownerBoundDataForBudgetSummary(repository);
            }),
          ],
        );
        addTearDown(() {
          repositoryA.releaseIfPending(_summaryFor(_scopeA));
          container.dispose();
        });

        final gatewayA = container.read(financialAgentDataGatewayProvider);
        var staleResultEgresses = 0;
        final result = gatewayA
            .executeReadTool(
              'get_budget_summary',
              const <String, Object?>{},
              _contextFor(_scopeA),
            )
            .then((value) {
              staleResultEgresses += 1;
              return value;
            });
        await repositoryA.started.future;

        container.read(_testScopeProvider.notifier).setScope(_scopeB);
        await Future<void>.delayed(Duration.zero);
        final gatewayB = container.read(financialAgentDataGatewayProvider);
        expect(identical(gatewayA, gatewayB), isFalse);

        repositoryA.release(_summaryFor(_scopeA));

        await expectLater(result, throwsA(_scopeChangedFailure));
        expect(providerReads, <String>[_scopeA]);
        expect(repositoryA.readCount, 1);
        expect(repositoryB.readCount, 0);
        expect(staleResultEgresses, 0);
      },
    );

    test('stale A context performs zero provider reads under B', () async {
      final scopesRead = <String>[];
      final container = ProviderContainer(
        overrides: [
          budgetSummaryProvider.overrideWith((ref) async {
            final scope = ref.watch(_testScopeProvider);
            scopesRead.add(scope);
            return AppResult.success(_summaryFor(scope));
          }),
        ],
      );
      addTearDown(container.dispose);

      final gateway = container.read(_gatewayUnderTestProvider);
      container.read(_testScopeProvider.notifier).setScope(_scopeB);

      await expectLater(
        gateway.executeReadTool(
          'get_budget_summary',
          const <String, Object?>{},
          _contextFor(_scopeA),
        ),
        throwsA(_scopeChangedFailure),
      );
      expect(scopesRead, isEmpty);
    });

    test(
      'same owner with a new session epoch is rejected before read',
      () async {
        var handlerCalls = 0;
        final registry = GovernedAiToolRegistry(
          tools: <RegisteredAiTool>[
            RegisteredAiTool(
              definition: const AiToolDefinition(
                name: 'epoch_scoped_read',
                description: 'Synthetic epoch-scoped read.',
                permission: AgentPermission.readFinancialData,
              ),
              handler: (arguments, context) async {
                handlerCalls += 1;
                return const AiToolResult(
                  toolName: 'epoch_scoped_read',
                  data: <String, Object?>{},
                );
              },
            ),
          ],
          permissionPolicy: const DefaultAiToolPermissionPolicy(),
          currentOwnerScope: () =>
              const AiToolOwnerScopeBinding(accountScope: _scopeA, epoch: 2),
        );

        await expectLater(
          registry.execute(
            const AiAgentToolCall(
              id: 'stale-epoch',
              name: 'epoch_scoped_read',
              arguments: <String, Object?>{},
            ),
            _contextFor(_scopeA),
          ),
          throwsA(_scopeChangedFailure),
        );
        expect(handlerCalls, 0);
      },
    );

    test('unverified financial scope is denied before handler', () async {
      var handlerCalls = 0;
      final registry = GovernedAiToolRegistry(
        tools: <RegisteredAiTool>[
          RegisteredAiTool(
            definition: const AiToolDefinition(
              name: 'verified_scope_read',
              description: 'Synthetic verified-scope read.',
              permission: AgentPermission.readFinancialData,
            ),
            handler: (arguments, context) async {
              handlerCalls += 1;
              return const AiToolResult(
                toolName: 'verified_scope_read',
                data: <String, Object?>{},
              );
            },
          ),
        ],
        permissionPolicy: const DefaultAiToolPermissionPolicy(),
        currentOwnerScope: () => _bindingFor(_scopeA),
      );
      final unverified = AiToolExecutionContext(
        locale: 'en',
        baseCurrencyCode: 'LYD',
        now: DateTime.utc(2026, 8, 10),
        maxSearchResults: 20,
        ownerScope: _bindingFor(_scopeA),
      );

      await expectLater(
        registry.execute(
          const AiAgentToolCall(
            id: 'unverified-scope',
            name: 'verified_scope_read',
            arguments: <String, Object?>{},
          ),
          unverified,
        ),
        throwsA(
          isA<AiToolFailure>().having(
            (failure) => failure.code,
            'code',
            'financial_scope_unverified',
          ),
        ),
      );
      expect(handlerCalls, 0);
    });
  });
}

class _TestScopeController extends Notifier<String> {
  @override
  String build() => _scopeA;

  void setScope(String value) => state = value;
}

AiToolExecutionContext _contextFor(String scope) => AiToolExecutionContext(
  locale: 'en',
  baseCurrencyCode: 'LYD',
  now: DateTime.utc(2026, 8, 10),
  maxSearchResults: 20,
  ownerScope: _bindingFor(scope),
  financialDataScopeVerified: true,
);

AiToolOwnerScopeBinding _bindingFor(String scope) => AiToolOwnerScopeBinding(
  accountScope: scope,
  epoch: scope == _scopeA ? 1 : 2,
);

Matcher get _scopeChangedFailure => isA<AiToolFailure>().having(
  (failure) => failure.code,
  'code',
  'account_scope_changed',
);

BudgetSummary _summaryFor(String scope) => BudgetSummary(
  activeCount: scope == _scopeA ? 1 : 2,
  warningCount: 0,
  exceededCount: 0,
  topWarning: null,
);

FinancialAgentOwnerBoundData _ownerBoundDataForBudgetSummary(
  Future<AppResult<BudgetSummary>> Function() readBudgetSummary,
) => FinancialAgentOwnerBoundData(
  loadDashboardSnapshot: () async => throw StateError('unused dashboard read'),
  loadBudgetSummary: readBudgetSummary,
  loadBudgetProgress: () async => throw StateError('unused budget progress'),
  loadGoalSummary: () async => throw StateError('unused goal summary'),
  loadGoalProgress: () async => throw StateError('unused goal progress'),
  convertMoney: (money, toCurrencyCode) async =>
      throw StateError('unused conversion'),
  getLatestExchangeRate: (from, to) async =>
      throw StateError('unused exchange-rate read'),
  searchTransactions: (query) async =>
      throw StateError('unused transaction search'),
);

class _DelayedBudgetSummaryRepository {
  final Completer<void> started = Completer<void>();
  final Completer<AppResult<BudgetSummary>> _result =
      Completer<AppResult<BudgetSummary>>();
  var readCount = 0;

  Future<AppResult<BudgetSummary>> read() {
    readCount += 1;
    if (!started.isCompleted) {
      started.complete();
    }
    return _result.future;
  }

  void release(BudgetSummary summary) {
    _result.complete(AppResult.success(summary));
  }

  void releaseIfPending(BudgetSummary summary) {
    if (!_result.isCompleted) {
      release(summary);
    }
  }
}

class _ImmediateBudgetSummaryRepository {
  _ImmediateBudgetSummaryRepository(this.summary);

  final BudgetSummary summary;
  var readCount = 0;

  Future<AppResult<BudgetSummary>> read() async {
    readCount += 1;
    return AppResult.success(summary);
  }
}

class _DelayedSettingsStore implements AiAppControlSettingsStore {
  final Completer<AiAppControlSettings> scopeB =
      Completer<AiAppControlSettings>();

  @override
  Future<void> clear(String accountScopeHash) async {}

  @override
  Future<AiAppControlSettings> read(String accountScopeHash) {
    if (accountScopeHash == _scopeA) {
      return Future<AiAppControlSettings>.value(_permissiveSettings);
    }
    return scopeB.future;
  }

  @override
  Future<void> save(
    String accountScopeHash,
    AiAppControlSettings settings,
  ) async {}
}

const _safeHealth = OwnerScopeHealth(status: OwnerScopeStatus.safe);

const _permissiveSettings = AiAppControlSettings(
  level: AiAppControlLevel.fullGovernedControl,
  allowFinancialAnalysis: true,
  allowNavigation: true,
  allowTransactionDrafts: true,
  allowBudgetAndGoalDrafts: true,
  allowAccountCategoryPayeeDrafts: true,
  allowRecurringDrafts: true,
  allowMultiStepPlans: true,
  requireConfirmationForEveryChange: true,
);

const _allCapabilitiesEnabled = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  confirmedExecutionEnabled: true,
  transferExecutionEnabled: true,
  updateDraftsEnabled: true,
  archiveDraftsEnabled: true,
  multiStepPlansEnabled: true,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);
