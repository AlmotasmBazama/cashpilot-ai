import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/storage/hive_box_names.dart';
import '../../../../core/storage/settings_local_data_source.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../../auth/application/providers/auth_providers.dart';
import '../../data/config/ai_runtime_config.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../agent/ai_agent_memory.dart';
import '../agent/ai_agent_orchestrator_impl.dart';
import '../agent/ai_agent_support.dart';
import '../agent/ai_provider_egress_guard.dart';
import '../agent/financial_agent_tools.dart';
import '../agent/governed_ai_tool_registry.dart';
import '../agent/riverpod_financial_agent_data_gateway.dart';
import '../controllers/ai_agent_conversation_controller.dart';
import '../services/ai_connection_diagnostic.dart';
import 'ai_assistant_providers.dart';
import 'ai_app_control_providers.dart';
import 'ai_agent_model_gateway_providers.dart';
import 'ai_agent_runtime_providers.dart';
import 'ai_agent_scope_providers.dart';

export 'ai_agent_model_gateway_providers.dart';
export 'ai_agent_runtime_providers.dart';
export 'ai_agent_scope_providers.dart';
export '../controllers/ai_agent_conversation_controller.dart'
    show AiAgentConversationState;

final aiAgentMemoryPreferenceControllerProvider =
    NotifierProvider<AiAgentMemoryPreferenceController, bool>(
      AiAgentMemoryPreferenceController.new,
      name: 'aiAgentMemoryPreferenceControllerProvider',
    );

class AiAgentMemoryPreferenceController extends Notifier<bool> {
  @override
  bool build() {
    final binding = ref.watch(aiToolOwnerScopeBindingProvider);
    if (binding == null || binding.accountScope.trim().isEmpty) {
      return false;
    }
    return ref
        .watch(settingsLocalDataSourceProvider)
        .readAiAgentMemoryPersistenceEnabled(
          accountScope: binding.accountScope,
        );
  }

  Future<void> setPersistence(bool enabled) async {
    final binding = ref.read(aiToolOwnerScopeBindingProvider);
    if (binding == null || binding.accountScope.trim().isEmpty) {
      state = false;
      return;
    }
    final lease = _tryAcquireLease(binding);
    if (lease == null) return;
    final settings = ref.read(settingsLocalDataSourceProvider);
    final memoryStore = ref.read(aiAgentMemoryStoreProvider);
    try {
      lease.assertActive();
      await settings.saveAiAgentMemoryPersistenceEnabled(
        accountScope: binding.accountScope,
        enabled: enabled,
        assertWriteAllowed: lease.assertActive,
      );
      lease.assertActive();
      if (!enabled) {
        await memoryStore.clear(access: lease.access);
      }
      lease.assertActive();
      if (!ref.mounted ||
          ref.read(aiToolOwnerScopeBindingProvider) != binding) {
        return;
      }
      state = enabled;
      ref.invalidate(aiAgentMemoryStoreProvider);
    } on BackupWriterCancelledException {
      // Deletion quarantine owns this scope; fail closed.
    } on AiAgentMemoryOwnerBindingChangedException {
      // A completion from an old authenticated session is discarded.
    } finally {
      lease.release();
    }
  }

  Future<void> clearHistory() async {
    final binding = ref.read(aiToolOwnerScopeBindingProvider);
    if (binding == null || binding.accountScope.trim().isEmpty) return;
    final lease = _tryAcquireLease(binding);
    if (lease == null) return;
    final memoryStore = ref.read(aiAgentMemoryStoreProvider);
    try {
      await memoryStore.clear(access: lease.access);
    } on BackupWriterCancelledException {
      // Deletion quarantine owns this scope; fail closed.
    } on AiAgentMemoryOwnerBindingChangedException {
      // An old session must not clear the new session's memory.
    } finally {
      lease.release();
    }
  }

  AiAgentMemoryOwnerLease? _tryAcquireLease(AiToolOwnerScopeBinding binding) {
    return AiAgentMemoryOwnerLease.tryAcquire(
      binding: binding,
      currentOwnerScope: () => ref.read(aiToolOwnerScopeBindingProvider),
      operationFence: ref.read(backupOperationFenceProvider),
    );
  }
}

final aiAgentMemoryStoreProvider = Provider<AiAgentMemoryStore>((ref) {
  final flags = ref.watch(aiAgentFeatureFlagsProvider);
  final accountScope = ref.watch(aiAgentAccountScopeProvider);
  if (!flags.conversationMemoryEnabled) {
    return InMemoryAiAgentMemoryStore();
  }
  if (accountScope == null || accountScope.trim().isEmpty) {
    return InMemoryAiAgentMemoryStore();
  }
  final persist = ref
      .watch(settingsLocalDataSourceProvider)
      .readAiAgentMemoryPersistenceEnabled(accountScope: accountScope);
  return persist
      ? HiveAiAgentMemoryStore(
          settingsBox: Hive.box<dynamic>(HiveBoxNames.settings),
          persistenceEnabled: true,
          accountScope: sha256.convert(utf8.encode(accountScope)).toString(),
        )
      : InMemoryAiAgentMemoryStore();
}, name: 'aiAgentMemoryStoreProvider');

final financialAgentDataGatewayProvider = Provider<FinancialAgentDataGateway>((
  ref,
) {
  final boundOwnerScope = ref.watch(aiToolOwnerScopeBindingProvider);
  return RiverpodFinancialAgentDataGateway(
    ref,
    boundOwnerScope: boundOwnerScope,
    currentOwnerScope: () => ref.read(aiToolOwnerScopeBindingProvider),
  );
}, name: 'financialAgentDataGatewayProvider');

final aiToolPermissionPolicyProvider = Provider<AiToolPermissionPolicy>(
  (ref) => DefaultAiToolPermissionPolicy(
    maxSearchResults: ref.watch(aiAgentLimitsProvider).maxSearchResults,
  ),
  name: 'aiToolPermissionPolicyProvider',
);

final aiToolRegistryProvider = Provider<AiToolRegistry>((ref) {
  final limits = ref.watch(aiAgentLimitsProvider);
  final effectiveAppControl = ref.watch(effectiveAiAppControlPolicyProvider);
  final tools =
      FinancialAgentToolCatalog(ref.watch(financialAgentDataGatewayProvider))
          .build(
            readOnlyEnabled: effectiveAppControl.canReadFinancialData,
            draftEnabled:
                effectiveAppControl.canCreateTransactionDraft ||
                effectiveAppControl.canCreateBudgetOrGoalDraft,
            navigationEnabled: effectiveAppControl.canNavigate,
          )
          .where((tool) {
            return switch (tool.definition.name) {
              'draft_transaction' ||
              'draft_transfer' => effectiveAppControl.canCreateTransactionDraft,
              'draft_budget' || 'draft_goal' || 'draft_goal_contribution' =>
                effectiveAppControl.canCreateBudgetOrGoalDraft,
              _ => true,
            };
          });
  return GovernedAiToolRegistry(
    tools: tools,
    permissionPolicy: ref.watch(aiToolPermissionPolicyProvider),
    currentOwnerScope: () => ref.read(aiToolOwnerScopeBindingProvider),
    toolTimeout: limits.toolTimeout,
  );
}, name: 'aiToolRegistryProvider');

/// Probes the same routed provider used by general conversation. Legacy
/// parser selection is deliberately irrelevant to this live diagnostic.
final aiConnectionDiagnosticProvider = Provider<AiConnectionDiagnostic>((ref) {
  final expectedAuthSession = ref
      .watch(currentAuthUserProvider)
      ?.sessionIdentity;
  final expectedOwnerScope = ref.watch(aiToolOwnerScopeBindingProvider);
  final authSessionGuard = ref.watch(firebaseAuthSessionEpochGuardProvider);
  final authOperationCoordinator = ref.watch(
    firebaseAuthOperationCoordinatorProvider,
  );
  AiProviderEgressGuard? egressGuard;
  if (expectedAuthSession != null) {
    final memoryAccess = AiAgentMemoryAccess(
      ownerScope: expectedOwnerScope,
      assertActive: () {
        if (ref.read(aiToolOwnerScopeBindingProvider) != expectedOwnerScope) {
          throw const AiProviderEgressRevokedException();
        }
      },
    );
    egressGuard = FirebaseAiProviderEgressGuard(
      expectedAuthSession: expectedAuthSession,
      expectedOwnerScope: expectedOwnerScope,
      currentOwnerScope: () => ref.read(aiToolOwnerScopeBindingProvider),
      memoryAccess: memoryAccess,
      authSessionGuard: authSessionGuard,
      authOperationCoordinator: authOperationCoordinator,
    );
  }
  final capabilities = ref.watch(aiAssistantCapabilitiesProvider);
  return AiConnectionDiagnostic(
    runtimeConfig: ref.watch(aiRuntimeConfigProvider),
    modelConfig: ref.watch(aiModelConfigProvider),
    repository: ref.watch(aiRepositoryProvider),
    localParser: ref.watch(financialCommandParserProvider),
    appCheckTokenProbe: ref.watch(appCheckTokenProbeProvider),
    capabilities: capabilities,
    modelGateway: ProviderSpecificAiConnectionDiagnosticGateway(
      expectedProvider: capabilities.activeProvider,
      firebaseGateway: ref.watch(firebaseAiAgentModelGatewayProvider),
      groqGateway: ref.watch(groqAiAgentModelGatewayProvider),
    ),
    egressGuard: egressGuard,
  );
}, name: 'aiConnectionDiagnosticProvider');

final aiAgentOrchestratorProvider = Provider<AiAgentOrchestrator>((ref) {
  final effectivePolicy = ref.watch(effectiveAiAppControlPolicyProvider);
  final capabilities = ref.watch(aiAssistantCapabilitiesProvider);
  final gatewayFlags = ref.watch(aiGatewayFeatureFlagsProvider);
  final runtime = ref.watch(aiRuntimeConfigProvider);
  final conversationPreference = runtime.resolvedConversationProviderPreference;
  final groqFinancialEnabled =
      (conversationPreference == AiConversationProviderPreference.auto ||
          conversationPreference == AiConversationProviderPreference.groq) &&
      ref.watch(aiGatewayRuntimeConfigProvider).isConfigured &&
      gatewayFlags.financialGatewayEnabledFor('en');
  final expectedAuthSession = ref
      .watch(currentAuthUserProvider)
      ?.sessionIdentity;
  final expectedOwnerScope = ref.watch(aiToolOwnerScopeBindingProvider);
  final authSessionGuard = ref.watch(firebaseAuthSessionEpochGuardProvider);
  final authOperationCoordinator = ref.watch(
    firebaseAuthOperationCoordinatorProvider,
  );
  return AiAgentOrchestratorImpl(
    toolRegistry: ref.watch(aiToolRegistryProvider),
    memoryStore: ref.watch(aiAgentMemoryStoreProvider),
    memoryCompactor: DefaultAiAgentMemoryCompactor(
      maxTurns: ref.watch(aiAgentLimitsProvider).maxConversationTurns,
    ),
    modelRouter: const DefaultAiAgentModelRouter(),
    contextSanitizer: const DefaultAiAgentContextSanitizer(),
    responseComposer: const DefaultAiAgentResponseComposer(),
    capabilities: capabilities,
    modelGateway: ref.watch(aiAgentModelGatewayProvider),
    providerEgressGuardFactory: (memoryAccess) {
      final authSession = expectedAuthSession;
      if (authSession == null) {
        return null;
      }
      return FirebaseAiProviderEgressGuard(
        expectedAuthSession: authSession,
        expectedOwnerScope: expectedOwnerScope,
        currentOwnerScope: () => ref.read(aiToolOwnerScopeBindingProvider),
        memoryAccess: memoryAccess,
        authSessionGuard: authSessionGuard,
        authOperationCoordinator: authOperationCoordinator,
      );
    },
    limits: ref.watch(aiAgentLimitsProvider),
    toolOwnerScope: expectedOwnerScope,
    currentToolOwnerScope: () => ref.read(aiToolOwnerScopeBindingProvider),
    operationFence: ref.watch(backupOperationFenceProvider),
    financialDataScopeVerified: effectivePolicy.scopedFinancialControlAvailable,
    deterministicFinancialExplanationEnabled:
        groqFinancialEnabled && !gatewayFlags.aiGroqToolSelectionEnabled,
  );
}, name: 'aiAgentOrchestratorProvider');

final _aiAgentConversationControllerDependencies =
    AiAgentConversationControllerDependencies(
      accountScopeProvider: aiAgentAccountScopeProvider,
      featureFlagsProvider: aiAgentFeatureFlagsProvider,
      orchestratorProvider: aiAgentOrchestratorProvider,
      assistantCapabilitiesProvider: aiAssistantCapabilitiesProvider,
      safeDiagnosticLogProvider: aiGatewaySafeDiagnosticLogProvider,
      intentRouterProvider: aiIntentRouterProvider,
      effectiveAppControlPolicyProvider: effectiveAiAppControlPolicyProvider,
      appCheckReadinessCoordinatorProvider:
          firebaseAppCheckReadinessCoordinatorProvider,
    );

final aiAgentControllerProvider =
    NotifierProvider<AiAgentController, AiAgentConversationState>(
      AiAgentController.new,
      name: 'aiAgentControllerProvider',
    );

class AiAgentController extends AiAgentConversationControllerCapability {
  AiAgentController() : super(_aiAgentConversationControllerDependencies);
}
