import 'ai_environment_defaults.dart';

class AiAppControlFeatureFlags {
  const AiAppControlFeatureFlags({
    required this.appControlEnabled,
    required this.readToolsEnabled,
    required this.navigationToolsEnabled,
    required this.createDraftsEnabled,
    this.confirmedExecutionEnabled = false,
    this.transferExecutionEnabled = false,
    required this.updateDraftsEnabled,
    required this.archiveDraftsEnabled,
    required this.multiStepPlansEnabled,
    required this.agentAuditEnabled,
    required this.localDatasetScopeVerified,
  });

  static final AiAppControlFeatureFlags current =
      AiAppControlFeatureFlags.resolve(
        environmentValue: AiEnvironmentDefaults.current.environmentName,
        isReleaseMode: AiEnvironmentDefaults.current.isReleaseMode,
        hasExplicitProductionEnvironment:
            AiEnvironmentDefaults.current.hasExplicitProductionEnvironment,
        appControlValue: const String.fromEnvironment(
          'CASH_PILOT_AI_APP_CONTROL_ENABLED',
        ),
        readToolsValue: const String.fromEnvironment(
          'CASH_PILOT_AI_READ_TOOLS_ENABLED',
        ),
        navigationToolsValue: const String.fromEnvironment(
          'CASH_PILOT_AI_NAVIGATION_TOOLS_ENABLED',
        ),
        createDraftsValue: const String.fromEnvironment(
          'CASH_PILOT_AI_CREATE_DRAFTS_ENABLED',
        ),
        confirmedExecutionValue: const String.fromEnvironment(
          'CASH_PILOT_AI_CONFIRMED_EXECUTION_ENABLED',
        ),
        transferExecutionValue: const String.fromEnvironment(
          'CASH_PILOT_AI_TRANSFER_EXECUTION_ENABLED',
        ),
        updateDraftsValue: const String.fromEnvironment(
          'CASH_PILOT_AI_UPDATE_DRAFTS_ENABLED',
        ),
        archiveDraftsValue: const String.fromEnvironment(
          'CASH_PILOT_AI_ARCHIVE_DRAFTS_ENABLED',
        ),
        multiStepPlansValue: const String.fromEnvironment(
          'CASH_PILOT_AI_MULTI_STEP_PLANS_ENABLED',
        ),
        auditValue: const String.fromEnvironment(
          'CASH_PILOT_AI_AGENT_AUDIT_ENABLED',
        ),
        localDatasetScopeVerifiedValue: const String.fromEnvironment(
          'CASH_PILOT_AI_LOCAL_DATASET_SCOPE_VERIFIED',
        ),
      );

  final bool appControlEnabled;
  final bool readToolsEnabled;
  final bool navigationToolsEnabled;
  final bool createDraftsEnabled;
  final bool confirmedExecutionEnabled;
  final bool transferExecutionEnabled;
  final bool updateDraftsEnabled;
  final bool archiveDraftsEnabled;
  final bool multiStepPlansEnabled;
  final bool agentAuditEnabled;

  /// Fail-closed rollout gate. It must only be enabled after the open local
  /// Drift dataset has a proven authenticated owner boundary.
  final bool localDatasetScopeVerified;

  factory AiAppControlFeatureFlags.resolve({
    String environmentValue = '',
    bool isReleaseMode = false,
    bool hasExplicitProductionEnvironment = false,
    String appControlValue = '',
    String readToolsValue = '',
    String navigationToolsValue = '',
    String createDraftsValue = '',
    String confirmedExecutionValue = '',
    String transferExecutionValue = '',
    String updateDraftsValue = '',
    String archiveDraftsValue = '',
    String multiStepPlansValue = '',
    String auditValue = '',
    String localDatasetScopeVerifiedValue = '',
  }) {
    final normalizedEnvironment = environmentValue.trim().toLowerCase();
    final useStagingDefaults =
        !isReleaseMode && normalizedEnvironment == 'staging';
    final releaseConfigurationAdmitted =
        !isReleaseMode ||
        (hasExplicitProductionEnvironment &&
            normalizedEnvironment == 'production');

    bool capabilityFlag(String value, {required bool fallback}) =>
        releaseConfigurationAdmitted && _flag(value, fallback: fallback);

    return AiAppControlFeatureFlags(
      appControlEnabled: capabilityFlag(
        appControlValue,
        fallback: useStagingDefaults,
      ),
      readToolsEnabled: capabilityFlag(
        readToolsValue,
        fallback: useStagingDefaults,
      ),
      navigationToolsEnabled: capabilityFlag(
        navigationToolsValue,
        fallback: false,
      ),
      createDraftsEnabled: capabilityFlag(
        createDraftsValue,
        fallback: useStagingDefaults,
      ),
      confirmedExecutionEnabled: capabilityFlag(
        confirmedExecutionValue,
        fallback: useStagingDefaults,
      ),
      transferExecutionEnabled: capabilityFlag(
        transferExecutionValue,
        fallback: false,
      ),
      updateDraftsEnabled: capabilityFlag(updateDraftsValue, fallback: false),
      archiveDraftsEnabled: capabilityFlag(archiveDraftsValue, fallback: false),
      multiStepPlansEnabled: capabilityFlag(
        multiStepPlansValue,
        fallback: false,
      ),
      agentAuditEnabled: _flag(auditValue, fallback: true),
      // Runtime owner-scope health remains an independent mandatory gate. This
      // default only removes the retired compile-time staging kill switch and
      // is never inherited by release builds.
      localDatasetScopeVerified: capabilityFlag(
        localDatasetScopeVerifiedValue,
        fallback: useStagingDefaults,
      ),
    );
  }

  static bool _flag(String value, {required bool fallback}) {
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' || 'yes' || 'on' => true,
      '0' || 'false' || 'no' || 'off' => false,
      _ => fallback,
    };
  }
}
