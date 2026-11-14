import 'dart:async';

import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_scope_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _scopeHashProvider = StateProvider<String?>((_) => _scopeA);
const _scopeA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _scopeB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  test('phase 1 late A settings reset cannot overwrite B state', () async {
    final store = _ControlledSettingsStore(blockSave: true);
    final fence = BackupOperationFence();
    final container = ProviderContainer(
      overrides: [
        aiAppControlScopeHashProvider.overrideWith(
          (ref) => ref.watch(_scopeHashProvider),
        ),
        aiToolOwnerScopeBindingProvider.overrideWith(
          (ref) => AiToolOwnerScopeBinding(
            accountScope: ref.watch(_scopeHashProvider)!,
            epoch: 1,
          ),
        ),
        aiAppControlSettingsStoreProvider.overrideWithValue(store),
        backupOperationFenceProvider.overrideWithValue(fence),
      ],
    );
    addTearDown(container.dispose);

    await container.read(aiAppControlSettingsControllerProvider.future);
    final reset = container
        .read(aiAppControlSettingsControllerProvider.notifier)
        .resetToConservativeDefaults();
    await store.saveStarted.future;

    container.read(_scopeHashProvider.notifier).state = _scopeB;
    final ownerB = await container.read(
      aiAppControlSettingsControllerProvider.future,
    );
    expect(ownerB?.settings.level, AiAppControlLevel.draftChanges);

    store.finishSave();
    await reset;

    final finalState = container.read(aiAppControlSettingsControllerProvider);
    expect(finalState.value?.settings.level, AiAppControlLevel.draftChanges);
    expect(store.savedSettings[_scopeA]?.level, AiAppControlLevel.off);
    expect(store.clearedScopes, isEmpty);
  });

  test(
    'deletion drains a delayed A Hive policy save before clearing it',
    () async {
      final store = _ControlledSettingsStore(blockSave: true);
      final fence = BackupOperationFence();
      final container = ProviderContainer(
        overrides: [
          aiAppControlScopeHashProvider.overrideWith(
            (ref) => ref.watch(_scopeHashProvider),
          ),
          aiToolOwnerScopeBindingProvider.overrideWith(
            (ref) => AiToolOwnerScopeBinding(
              accountScope: ref.watch(_scopeHashProvider)!,
              epoch: 1,
            ),
          ),
          aiAppControlSettingsStoreProvider.overrideWithValue(store),
          backupOperationFenceProvider.overrideWithValue(fence),
        ],
      );
      addTearDown(container.dispose);
      await container.read(aiAppControlSettingsControllerProvider.future);

      final save = container
          .read(aiAppControlSettingsControllerProvider.notifier)
          .setNavigation(true);
      await store.saveStarted.future;
      var deletionDrained = false;
      final deletion = fence
          .fenceAndDrain(
            ownerScopeValue: _scopeA,
            operationId: 'delete-owner-a',
          )
          .then((lease) {
            deletionDrained = true;
            return lease;
          });
      await pumpEventQueue();
      expect(deletionDrained, isFalse);

      store.finishSave();
      await save;
      final deletionLease = await deletion;
      store.clearDirectly(_scopeA);
      deletionLease.release();

      expect(store.savedSettings.containsKey(_scopeA), isFalse);
    },
  );

  test('B loading state cannot save a value retained from A', () async {
    final store = _OwnerTransitionReadStore(blockB: true);
    final container = _settingsContainer(store);
    addTearDown(() {
      store.releaseB();
      container.dispose();
    });
    await container.read(aiAppControlSettingsControllerProvider.future);

    container.read(_scopeHashProvider.notifier).state = _scopeB;
    await pumpEventQueue(times: 4);
    expect(
      container.read(aiAppControlSettingsControllerProvider).isLoading,
      isTrue,
    );
    await container
        .read(aiAppControlSettingsControllerProvider.notifier)
        .setNavigation(false);

    expect(store.savedScopes, isEmpty);
  });

  test('B read error cannot save a value retained from A', () async {
    final store = _OwnerTransitionReadStore(failB: true);
    final container = _settingsContainer(store);
    addTearDown(container.dispose);
    await container.read(aiAppControlSettingsControllerProvider.future);

    container.read(_scopeHashProvider.notifier).state = _scopeB;
    await expectLater(
      container.read(aiAppControlSettingsControllerProvider.future),
      throwsStateError,
    );
    await container
        .read(aiAppControlSettingsControllerProvider.notifier)
        .setLevel(AiAppControlLevel.off);

    expect(store.savedScopes, isEmpty);
  });
}

ProviderContainer _settingsContainer(AiAppControlSettingsStore store) {
  return ProviderContainer(
    overrides: [
      aiAppControlScopeHashProvider.overrideWith(
        (ref) => ref.watch(_scopeHashProvider),
      ),
      aiToolOwnerScopeBindingProvider.overrideWith(
        (ref) => AiToolOwnerScopeBinding(
          accountScope: ref.watch(_scopeHashProvider)!,
          epoch: 1,
        ),
      ),
      aiAppControlSettingsStoreProvider.overrideWithValue(store),
      backupOperationFenceProvider.overrideWithValue(BackupOperationFence()),
    ],
  );
}

final class _OwnerTransitionReadStore implements AiAppControlSettingsStore {
  _OwnerTransitionReadStore({this.blockB = false, this.failB = false});

  final bool blockB;
  final bool failB;
  final Completer<void> _releaseB = Completer<void>();
  final List<String> savedScopes = <String>[];

  void releaseB() {
    if (!_releaseB.isCompleted) _releaseB.complete();
  }

  @override
  Future<void> clear(String accountScopeHash) async {}

  @override
  Future<AiAppControlSettings> read(String accountScopeHash) async {
    if (accountScopeHash == _scopeB) {
      if (blockB) await _releaseB.future;
      if (failB) throw StateError('owner B settings unavailable');
      return const AiAppControlSettings.conservative();
    }
    return const AiAppControlSettings(
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
  }

  @override
  Future<void> save(
    String accountScopeHash,
    AiAppControlSettings settings,
  ) async {
    savedScopes.add(accountScopeHash);
  }
}

class _ControlledSettingsStore implements AiAppControlSettingsStore {
  _ControlledSettingsStore({this.blockSave = false});

  final bool blockSave;
  final Completer<void> saveStarted = Completer<void>();
  final Completer<void> _saveFinished = Completer<void>();
  final List<String> clearedScopes = <String>[];
  final Map<String, AiAppControlSettings> savedSettings =
      <String, AiAppControlSettings>{};

  void finishSave() => _saveFinished.complete();
  void clearDirectly(String scopeHash) => savedSettings.remove(scopeHash);

  @override
  Future<void> clear(String accountScopeHash) async {
    clearedScopes.add(accountScopeHash);
    savedSettings.remove(accountScopeHash);
  }

  @override
  Future<AiAppControlSettings> read(String accountScopeHash) async {
    if (accountScopeHash == _scopeB) {
      return const AiAppControlSettings(
        level: AiAppControlLevel.draftChanges,
        allowFinancialAnalysis: true,
        allowNavigation: false,
        allowTransactionDrafts: true,
        allowBudgetAndGoalDrafts: false,
        allowAccountCategoryPayeeDrafts: false,
        allowRecurringDrafts: false,
        allowMultiStepPlans: false,
        requireConfirmationForEveryChange: true,
      );
    }
    return const AiAppControlSettings.conservative();
  }

  @override
  Future<void> save(
    String accountScopeHash,
    AiAppControlSettings settings,
  ) async {
    if (blockSave) {
      saveStarted.complete();
      await _saveFinished.future;
    }
    savedSettings[accountScopeHash] = settings;
  }
}
