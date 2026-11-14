import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/storage/hive_box_names.dart';
import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';
import '../../data/app_agent/hive_ai_app_control_settings_store.dart';
import '../../data/app_agent/drift_app_agent_stores.dart';
import '../../data/config/ai_app_control_feature_flags.dart';
import '../../data/config/ai_environment_defaults.dart';
import '../../domain/app_agent/ai_app_control_settings.dart';
import '../../domain/app_agent/canonical_app_tool_catalog.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../app_agent/effective_ai_app_control_policy.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/app_agent/app_agent_contracts.dart';
import 'ai_agent_scope_providers.dart';

final aiAppControlFeatureFlagsProvider = Provider<AiAppControlFeatureFlags>(
  (_) => AiAppControlFeatureFlags.current,
  name: 'aiAppControlFeatureFlagsProvider',
);

final aiAppControlSettingsStoreProvider = Provider<AiAppControlSettingsStore>((
  _,
) {
  final environment = AiEnvironmentDefaults.current;
  final migrateStagingPolicy =
      !environment.isReleaseMode &&
      environment.environmentName.trim().toLowerCase() == 'staging';
  return HiveAiAppControlSettingsStore(
    Hive.box<dynamic>(HiveBoxNames.settings),
    missingPolicyDefault: AiAppControlSettings.initialForEnvironment(
      environmentName: environment.environmentName,
      isReleaseMode: environment.isReleaseMode,
    ),
    migrateUninitializedPolicy: migrateStagingPolicy,
    admitStagingMigrationPolicy: migrateStagingPolicy,
  );
}, name: 'aiAppControlSettingsStoreProvider');

final aiAppControlScopeHashProvider = Provider<String?>((ref) {
  final scope = ref.watch(aiAgentAccountScopeProvider);
  return scope == null
      ? null
      : OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
          scope,
        ).assistantScopeHash;
}, name: 'aiAppControlScopeHashProvider');

final aiAppControlSettingsControllerProvider =
    AsyncNotifierProvider<
      AiAppControlSettingsController,
      AiAppControlSettingsSnapshot?
    >(
      AiAppControlSettingsController.new,
      name: 'aiAppControlSettingsControllerProvider',
    );

class AiAppControlSettingsController
    extends AsyncNotifier<AiAppControlSettingsSnapshot?> {
  var _operationVersion = 0;

  @override
  Future<AiAppControlSettingsSnapshot?> build() async {
    final configurationRevision = ++_operationVersion;
    final ownerBinding = ref.watch(aiToolOwnerScopeBindingProvider);
    final scopeHash = ref.watch(aiAppControlScopeHashProvider);
    if (ownerBinding == null || scopeHash == null) {
      return null;
    }
    // The first read may perform a one-time account-scoped schema/default
    // migration. Fence it like every other owner-scoped write so account
    // deletion can cancel or drain it safely.
    final writer = ref
        .watch(backupOperationFenceProvider)
        .tryAcquireWriter(ownerBinding.accountScope);
    if (writer == null) {
      throw const OwnerScopeException(OwnerScopeFailure.deletionQuarantined);
    }
    try {
      writer.assertActive();
      final settings = await ref
          .watch(aiAppControlSettingsStoreProvider)
          .read(scopeHash);
      writer.assertActive();
      return AiAppControlSettingsSnapshot(
        ownerBinding: ownerBinding,
        scopeHash: scopeHash,
        settings: settings,
        configurationRevision: configurationRevision,
      );
    } finally {
      writer.release();
    }
  }

  Future<void> setLevel(AiAppControlLevel level) {
    return _save(
      (_) => AiAppControlSettings.forLevel(
        level,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
      ),
    );
  }

  Future<void> setFinancialAnalysis(bool value) {
    return _save(
      (settings) => settings.copyWith(allowFinancialAnalysis: value),
    );
  }

  Future<void> setNavigation(bool value) {
    return _save((settings) => settings.copyWith(allowNavigation: value));
  }

  Future<void> setTransactionDrafts(bool value) {
    return _save(
      (settings) => settings.copyWith(allowTransactionDrafts: value),
    );
  }

  Future<void> setBudgetAndGoalDrafts(bool value) {
    return _save(
      (settings) => settings.copyWith(allowBudgetAndGoalDrafts: value),
    );
  }

  Future<void> setAccountCategoryPayeeDrafts(bool value) {
    return _save(
      (settings) => settings.copyWith(allowAccountCategoryPayeeDrafts: value),
    );
  }

  Future<void> setRecurringDrafts(bool value) {
    return _save((settings) => settings.copyWith(allowRecurringDrafts: value));
  }

  Future<void> setMultiStepPlans(bool value) {
    return _save((settings) => settings.copyWith(allowMultiStepPlans: value));
  }

  Future<void> resetToConservativeDefaults() async {
    final captured = _currentSnapshot();
    if (captured == null) return;
    final operationVersion = ++_operationVersion;
    final writer = ref
        .read(backupOperationFenceProvider)
        .tryAcquireWriter(captured.ownerBinding.accountScope);
    if (writer == null) {
      state = AsyncError(
        const OwnerScopeException(OwnerScopeFailure.deletionQuarantined),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    try {
      writer.assertActive();
      await ref
          .read(aiAppControlSettingsStoreProvider)
          .save(
            captured.scopeHash,
            const AiAppControlSettings.conservative(
              provenance: AiAppControlPolicyProvenance.persistedUserSelection,
            ),
          );
      writer.assertActive();
      if (!_isCurrentOwnerOperation(captured, operationVersion)) {
        return;
      }
      state = AsyncData(
        captured.copyWith(
          settings: const AiAppControlSettings.conservative(
            provenance: AiAppControlPolicyProvenance.persistedUserSelection,
          ),
          configurationRevision: operationVersion,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (_isCurrentOwnerOperation(captured, operationVersion)) {
        state = AsyncError(error, stackTrace);
      }
    } finally {
      writer.release();
    }
  }

  Future<void> _save(
    AiAppControlSettings Function(AiAppControlSettings current) update,
  ) async {
    final captured = _currentSnapshot();
    if (captured == null) return;
    final operationVersion = ++_operationVersion;
    final writer = ref
        .read(backupOperationFenceProvider)
        .tryAcquireWriter(captured.ownerBinding.accountScope);
    if (writer == null) {
      state = AsyncError(
        const OwnerScopeException(OwnerScopeFailure.deletionQuarantined),
        StackTrace.current,
      );
      return;
    }
    final next = update(captured.settings).normalizedForLevel(
      provenance: AiAppControlPolicyProvenance.persistedUserSelection,
    );
    // Never expose elevated consent before the account-scoped write commits.
    // The effective provider treats this loading interval as fail-closed.
    state = const AsyncLoading();
    try {
      writer.assertActive();
      await ref
          .read(aiAppControlSettingsStoreProvider)
          .save(captured.scopeHash, next);
      writer.assertActive();
      if (!_isCurrentOwnerOperation(captured, operationVersion)) {
        return;
      }
      state = AsyncData(
        captured.copyWith(
          settings: next,
          configurationRevision: operationVersion,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (_isCurrentOwnerOperation(captured, operationVersion)) {
        state = AsyncError(error, stackTrace);
      }
    } finally {
      writer.release();
    }
  }

  AiAppControlSettingsSnapshot? _currentSnapshot() {
    final currentState = state;
    if (currentState case AsyncData<AiAppControlSettingsSnapshot?>(
      value: final snapshot?,
    )) {
      final ownerBinding = ref.read(aiToolOwnerScopeBindingProvider);
      final scopeHash = ref.read(aiAppControlScopeHashProvider);
      return snapshot.matches(ownerBinding, scopeHash) ? snapshot : null;
    }
    return null;
  }

  bool _isCurrentOwnerOperation(
    AiAppControlSettingsSnapshot captured,
    int operationVersion,
  ) {
    try {
      return ref.mounted &&
          operationVersion == _operationVersion &&
          captured.matches(
            ref.read(aiToolOwnerScopeBindingProvider),
            ref.read(aiAppControlScopeHashProvider),
          );
    } on Object {
      return false;
    }
  }
}

final class AiAppControlSettingsSnapshot {
  const AiAppControlSettingsSnapshot({
    required this.ownerBinding,
    required this.scopeHash,
    required this.settings,
    required this.configurationRevision,
  });

  final AiToolOwnerScopeBinding ownerBinding;
  final String scopeHash;
  final AiAppControlSettings settings;
  final int configurationRevision;

  AiAppControlPolicyProvenance get provenance => settings.provenance;

  bool matches(
    AiToolOwnerScopeBinding? currentOwnerBinding,
    String? currentScopeHash,
  ) => ownerBinding == currentOwnerBinding && scopeHash == currentScopeHash;

  AiAppControlSettingsSnapshot copyWith({
    required AiAppControlSettings settings,
    int? configurationRevision,
  }) => AiAppControlSettingsSnapshot(
    ownerBinding: ownerBinding,
    scopeHash: scopeHash,
    settings: settings,
    configurationRevision: configurationRevision ?? this.configurationRevision,
  );
}

final effectiveAiAppControlPolicyProvider =
    Provider<EffectiveAiAppControlPolicy>((ref) {
      final ownerBinding = ref.watch(aiToolOwnerScopeBindingProvider);
      final scopeHash = ref.watch(aiAppControlScopeHashProvider);
      final settingsState = ref.watch(aiAppControlSettingsControllerProvider);
      final healthState = ref.watch(ownerScopeHealthProvider);
      final settingsSnapshot = switch (settingsState) {
        AsyncData<AiAppControlSettingsSnapshot?>(value: final value?)
            when value.matches(ownerBinding, scopeHash) =>
          value,
        _ => null,
      };
      final settings =
          settingsSnapshot?.settings ??
          const AiAppControlSettings.conservative();
      final health = switch (healthState) {
        AsyncData<OwnerScopeHealth>(:final value) => value,
        _ => null,
      };
      final currentScopeReady =
          ownerBinding != null &&
          scopeHash != null &&
          settingsSnapshot != null &&
          healthState is AsyncData<OwnerScopeHealth>;
      return EffectiveAiAppControlPolicy(
        flags: ref.watch(aiAppControlFeatureFlagsProvider),
        settings: settings,
        hasAuthenticatedScope: currentScopeReady,
        runtimeOwnerScopeSafe: currentScopeReady && health?.isSafe == true,
        provenance:
            settingsSnapshot?.provenance ??
            AiAppControlPolicyProvenance.environmentDefault,
        configurationRevision: settingsSnapshot?.configurationRevision ?? 0,
      );
    }, name: 'effectiveAiAppControlPolicyProvider');

final appAgentCommandStoreProvider = Provider<AppAgentCommandStore>((ref) {
  return DriftAppAgentCommandStore(
    session: ref.watch(requiredScopedAppDatabaseSessionProvider),
    canonicalDescriptors: CanonicalAppToolCatalog.safeTools.map(
      (tool) => AppAgentModelProposalDescriptor(
        toolId: tool.id,
        permission: tool.permission,
        risk: tool.risk,
        modelCallable: tool.modelCallable,
      ),
    ),
  );
}, name: 'appAgentCommandStoreProvider');

final appAgentConfirmationProofStoreProvider =
    Provider<AppAgentConfirmationProofStore>((ref) {
      return DriftAppAgentConfirmationProofStore(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
      );
    }, name: 'appAgentConfirmationProofStoreProvider');

final appAgentDurableExecutionStoreProvider =
    Provider<AppAgentDurableExecutionStore>((ref) {
      return DriftAppAgentDurableExecutionStore(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
      );
    }, name: 'appAgentDurableExecutionStoreProvider');

final appAgentAuditStoreProvider = Provider<AppAgentAuditStore>(
  (ref) => DriftAppAgentAuditStore(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'appAgentAuditStoreProvider',
);
