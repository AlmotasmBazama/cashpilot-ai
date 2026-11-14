import 'package:cashpilot_ai/features/ai_assistant/application/agent/financial_agent_tools.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _legacyPermissiveFlags = AiAgentFeatureFlags(
  agentEnabled: true,
  readOnlyToolsEnabled: true,
  draftToolsEnabled: true,
  conversationMemoryEnabled: true,
  complexPlanningEnabled: true,
);

const _allCapabilitiesEnabled = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  confirmedExecutionEnabled: true,
  updateDraftsEnabled: true,
  archiveDraftsEnabled: true,
  multiStepPlansEnabled: true,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);

const _masterDisabled = AiAppControlFeatureFlags(
  appControlEnabled: false,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  updateDraftsEnabled: true,
  archiveDraftsEnabled: true,
  multiStepPlansEnabled: true,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);

const _unverifiedDataset = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  updateDraftsEnabled: true,
  archiveDraftsEnabled: true,
  multiStepPlansEnabled: true,
  agentAuditEnabled: true,
  localDatasetScopeVerified: false,
);

const _fullConsent = AiAppControlSettings(
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

void main() {
  test('app-control master off ignores permissive legacy tool flags', () {
    const policy = EffectiveAiAppControlPolicy(
      flags: _masterDisabled,
      settings: _fullConsent,
      hasAuthenticatedScope: true,
      configurationRevision: 1,
    );
    final container = _containerFor(policy);
    addTearDown(container.dispose);

    final definitions = container.read(aiToolRegistryProvider).definitions;

    expect(_governedDefinitions(definitions), isEmpty);
    expect(
      definitions.where((tool) => tool.permission == AgentPermission.calculate),
      isNotEmpty,
    );
  });

  test('missing authenticated scope exposes no governed app tools', () {
    const policy = EffectiveAiAppControlPolicy(
      flags: _allCapabilitiesEnabled,
      settings: _fullConsent,
      hasAuthenticatedScope: false,
      configurationRevision: 1,
    );
    final container = _containerFor(policy);
    addTearDown(container.dispose);

    final definitions = container.read(aiToolRegistryProvider).definitions;

    expect(_governedDefinitions(definitions), isEmpty);
  });

  test(
    'unverified financial dataset blocks reads and drafts but not consented navigation',
    () {
      const policy = EffectiveAiAppControlPolicy(
        flags: _unverifiedDataset,
        settings: _fullConsent,
        hasAuthenticatedScope: true,
        configurationRevision: 1,
      );
      final container = _containerFor(policy);
      addTearDown(container.dispose);

      final definitions = container.read(aiToolRegistryProvider).definitions;

      expect(
        definitions.where(
          (tool) => tool.permission == AgentPermission.readFinancialData,
        ),
        isEmpty,
      );
      expect(
        definitions.where(
          (tool) => tool.permission == AgentPermission.createDraft,
        ),
        isEmpty,
      );
      expect(
        definitions.where(
          (tool) => tool.permission == AgentPermission.navigate,
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'verified Read Only policy cannot inherit retired navigation consent',
    () {
      const policy = EffectiveAiAppControlPolicy(
        flags: _allCapabilitiesEnabled,
        settings: AiAppControlSettings(
          level: AiAppControlLevel.readAndNavigate,
          allowFinancialAnalysis: true,
          allowNavigation: true,
          allowTransactionDrafts: true,
          allowBudgetAndGoalDrafts: true,
          allowAccountCategoryPayeeDrafts: true,
          allowRecurringDrafts: true,
          allowMultiStepPlans: true,
          requireConfirmationForEveryChange: true,
        ),
        hasAuthenticatedScope: true,
        runtimeOwnerScopeSafe: true,
        configurationRevision: 1,
      );
      final container = _containerFor(policy);
      addTearDown(container.dispose);

      final permissions = container
          .read(aiToolRegistryProvider)
          .definitions
          .map((tool) => tool.permission)
          .toSet();

      expect(permissions, <AgentPermission>{
        AgentPermission.calculate,
        AgentPermission.readFinancialData,
        AgentPermission.readAppConfiguration,
      });
    },
  );

  test('transaction draft consent does not expose budget or goal drafts', () {
    const policy = EffectiveAiAppControlPolicy(
      flags: _allCapabilitiesEnabled,
      settings: AiAppControlSettings(
        level: AiAppControlLevel.draftChanges,
        allowFinancialAnalysis: false,
        allowNavigation: false,
        allowTransactionDrafts: true,
        allowBudgetAndGoalDrafts: false,
        allowAccountCategoryPayeeDrafts: false,
        allowRecurringDrafts: false,
        allowMultiStepPlans: false,
        requireConfirmationForEveryChange: true,
      ),
      hasAuthenticatedScope: true,
      runtimeOwnerScopeSafe: true,
      configurationRevision: 1,
    );
    final container = _containerFor(policy);
    addTearDown(container.dispose);

    final registry = container.read(aiToolRegistryProvider);

    expect(registry.definitionFor('draft_transaction'), isNotNull);
    expect(registry.definitionFor('draft_transfer'), isNotNull);
    expect(registry.definitionFor('draft_budget'), isNull);
    expect(registry.definitionFor('draft_goal'), isNull);
    expect(registry.definitionFor('draft_goal_contribution'), isNull);
    expect(
      registry.definitions.where(
        (tool) => tool.permission == AgentPermission.createDraft,
      ),
      isEmpty,
    );
  });

  test('budget and goal consent does not expose transaction drafts', () {
    const policy = EffectiveAiAppControlPolicy(
      flags: _allCapabilitiesEnabled,
      settings: AiAppControlSettings(
        level: AiAppControlLevel.draftChanges,
        allowFinancialAnalysis: false,
        allowNavigation: false,
        allowTransactionDrafts: false,
        allowBudgetAndGoalDrafts: true,
        allowAccountCategoryPayeeDrafts: false,
        allowRecurringDrafts: false,
        allowMultiStepPlans: false,
        requireConfirmationForEveryChange: true,
      ),
      hasAuthenticatedScope: true,
      runtimeOwnerScopeSafe: true,
      configurationRevision: 1,
    );
    final container = _containerFor(policy);
    addTearDown(container.dispose);

    final registry = container.read(aiToolRegistryProvider);

    expect(registry.definitionFor('draft_transaction'), isNull);
    expect(registry.definitionFor('draft_transfer'), isNull);
    expect(registry.definitionFor('draft_budget'), isNotNull);
    expect(registry.definitionFor('draft_goal'), isNotNull);
    expect(registry.definitionFor('draft_goal_contribution'), isNotNull);
    expect(
      registry.definitions.where(
        (tool) => tool.permission == AgentPermission.createDraft,
      ),
      isEmpty,
    );
  });
}

ProviderContainer _containerFor(EffectiveAiAppControlPolicy policy) {
  return ProviderContainer(
    overrides: [
      aiAgentFeatureFlagsProvider.overrideWithValue(_legacyPermissiveFlags),
      effectiveAiAppControlPolicyProvider.overrideWithValue(policy),
      financialAgentDataGatewayProvider.overrideWithValue(
        const _FakeFinancialAgentDataGateway(),
      ),
    ],
  );
}

Iterable<AiToolDefinition> _governedDefinitions(
  Iterable<AiToolDefinition> definitions,
) {
  const permissions = <AgentPermission>{
    AgentPermission.readFinancialData,
    AgentPermission.createDraft,
    AgentPermission.navigate,
  };
  return definitions.where((tool) => permissions.contains(tool.permission));
}

class _FakeFinancialAgentDataGateway implements FinancialAgentDataGateway {
  const _FakeFinancialAgentDataGateway();

  @override
  Future<AiToolResult> executeReadTool(
    String name,
    Map<String, Object?> arguments,
    AiToolExecutionContext context,
  ) {
    throw UnsupportedError('Provider composition tests do not execute tools.');
  }
}
