import 'dart:async';

import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_scope_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/settings/presentation/widgets/ai_app_control_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _uiScopeProvider = StateProvider<String>((ref) => _scopeA);
const _scopeA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _scopeB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  for (final mode in _BReadMode.values) {
    testWidgets('B ${mode.name} never renders or enables retained A policy', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _UiOwnerSettingsStore(mode);
      final container = ProviderContainer(
        overrides: [
          aiAppControlFeatureFlagsProvider.overrideWithValue(_enabledFlags),
          aiAppControlScopeHashProvider.overrideWith(
            (ref) => ref.watch(_uiScopeProvider),
          ),
          aiToolOwnerScopeBindingProvider.overrideWith(
            (ref) => AiToolOwnerScopeBinding(
              accountScope: ref.watch(_uiScopeProvider),
              epoch: ref.watch(_uiScopeProvider) == _scopeA ? 1 : 2,
            ),
          ),
          aiAppControlSettingsStoreProvider.overrideWithValue(store),
          backupOperationFenceProvider.overrideWithValue(
            BackupOperationFence(),
          ),
          ownerScopeHealthProvider.overrideWith(
            (ref) async =>
                const OwnerScopeHealth(status: OwnerScopeStatus.safe),
          ),
        ],
      );
      addTearDown(() {
        store.release();
        container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AiAppControlSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _levelDropdown(tester).value,
        AiAppControlLevel.fullGovernedControl,
      );
      expect(_levelDropdown(tester).onChanged, isNotNull);

      container.read(_uiScopeProvider.notifier).state = _scopeB;
      for (var index = 0; index < 8; index += 1) {
        await tester.pump();
      }

      final dropdown = _levelDropdown(tester);
      expect(dropdown.value, AiAppControlLevel.off);
      expect(dropdown.onChanged, isNull);
      final navigation = tester.widget<Switch>(
        find.descendant(
          of: find.byKey(const Key('ai_allow_navigation')),
          matching: find.byType(Switch),
        ),
      );
      expect(navigation.value, isFalse);
      expect(navigation.onChanged, isNull);
    });
  }
}

DropdownButton<AiAppControlLevel> _levelDropdown(WidgetTester tester) =>
    tester.widget<DropdownButton<AiAppControlLevel>>(
      find.byKey(const Key('ai_app_control_level')),
    );

enum _BReadMode { loading, error }

final class _UiOwnerSettingsStore implements AiAppControlSettingsStore {
  _UiOwnerSettingsStore(this.mode);

  final _BReadMode mode;
  final Completer<void> _release = Completer<void>();

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<void> clear(String accountScopeHash) async {}

  @override
  Future<AiAppControlSettings> read(String accountScopeHash) async {
    if (accountScopeHash == _scopeB) {
      if (mode == _BReadMode.loading) {
        await _release.future;
      }
      throw StateError('owner B policy unavailable');
    }
    return _ownerAPolicy;
  }

  @override
  Future<void> save(
    String accountScopeHash,
    AiAppControlSettings settings,
  ) async {}
}

const _ownerAPolicy = AiAppControlSettings(
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

const _enabledFlags = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  updateDraftsEnabled: false,
  archiveDraftsEnabled: false,
  multiStepPlansEnabled: true,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);
