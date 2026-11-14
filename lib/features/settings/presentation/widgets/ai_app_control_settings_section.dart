import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../ai_assistant/application/providers/ai_app_control_providers.dart';
import '../../../ai_assistant/application/providers/ai_agent_scope_providers.dart';
import '../../../ai_assistant/domain/app_agent/ai_app_control_settings.dart';

class AiAppControlSettingsSection extends ConsumerWidget {
  const AiAppControlSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final flags = ref.watch(aiAppControlFeatureFlagsProvider);
    final effectivePolicy = ref.watch(effectiveAiAppControlPolicyProvider);
    final ownerBinding = ref.watch(aiToolOwnerScopeBindingProvider);
    final scopeHash = ref.watch(aiAppControlScopeHashProvider);
    final settingsAsync = ref.watch(aiAppControlSettingsControllerProvider);
    final settingsSnapshot = switch (settingsAsync) {
      AsyncData<AiAppControlSettingsSnapshot?>(value: final value?)
          when value.matches(ownerBinding, scopeHash) =>
        value,
      _ => null,
    };
    final settings =
        settingsSnapshot?.settings ?? const AiAppControlSettings.conservative();
    final controller = ref.read(
      aiAppControlSettingsControllerProvider.notifier,
    );
    final enabled = flags.appControlEnabled && settingsSnapshot != null;
    final financialScopeReady =
        enabled && effectivePolicy.scopedFinancialControlAvailable;
    return FinanceSection(
      title: isArabic ? 'تحكم المساعد في التطبيق' : 'AI app control',
      subtitle: isArabic
          ? 'كل تغيير يبقى مسودة إلى أن تؤكده داخل CashPilot.'
          : 'Every change remains a draft until you confirm it in CashPilot.',
      child: CPCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            if (!flags.appControlEnabled || !financialScopeReady)
              Padding(
                padding: const EdgeInsets.all(CPSpacing.lg),
                child: Text(
                  !flags.appControlEnabled
                      ? (isArabic
                            ? 'التحكم في التطبيق غير مفعّل في هذا الإصدار.'
                            : 'App control is not enabled in this build.')
                      : (isArabic
                            ? 'البيانات المالية مقفلة إلى أن يكتمل ربط قاعدة البيانات بالحساب.'
                            : 'Financial controls remain locked until local data ownership is verified.'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            CPListTile(
              title: isArabic ? 'مستوى التحكم' : 'Control level',
              subtitle: _levelDescription(settings.level, isArabic: isArabic),
              leading: const Icon(Icons.admin_panel_settings_outlined),
              trailing: DropdownButton<AiAppControlLevel>(
                key: const Key('ai_app_control_level'),
                value: settings.level,
                onChanged: enabled
                    ? (value) {
                        if (value != null) {
                          unawaited(controller.setLevel(value));
                        }
                      }
                    : null,
                items: AiAppControlLevel.values
                    .map(
                      (level) => DropdownMenuItem<AiAppControlLevel>(
                        value: level,
                        child: Text(_levelLabel(level, isArabic: isArabic)),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            _toggle(
              key: const Key('ai_allow_financial_analysis'),
              title: isArabic
                  ? 'السماح بالتحليل المالي'
                  : 'Allow financial analysis',
              value: settings.allowFinancialAnalysis,
              enabled: false,
              onChanged: controller.setFinancialAnalysis,
            ),
            _toggle(
              key: const Key('ai_allow_navigation'),
              title: isArabic ? 'السماح بالتنقل' : 'Allow navigation',
              value: settings.allowNavigation,
              enabled: false,
              onChanged: controller.setNavigation,
            ),
            _toggle(
              key: const Key('ai_allow_transaction_drafts'),
              title: isArabic ? 'مسودات المعاملات' : 'Transaction drafts',
              value: settings.allowTransactionDrafts,
              enabled: false,
              onChanged: controller.setTransactionDrafts,
            ),
            _toggle(
              key: const Key('ai_allow_budget_goal_drafts'),
              title: isArabic
                  ? 'مسودات الميزانيات والأهداف'
                  : 'Budget and goal drafts',
              value: settings.allowBudgetAndGoalDrafts,
              enabled: false,
              onChanged: controller.setBudgetAndGoalDrafts,
            ),
            _toggle(
              key: const Key('ai_allow_entity_drafts'),
              title: isArabic
                  ? 'مسودات الحسابات والتصنيفات والمستفيدين'
                  : 'Account, category, and payee drafts',
              value: settings.allowAccountCategoryPayeeDrafts,
              enabled: false,
              onChanged: controller.setAccountCategoryPayeeDrafts,
            ),
            _toggle(
              key: const Key('ai_allow_recurring_drafts'),
              title: isArabic ? 'مسودات التكرار' : 'Recurring drafts',
              value: settings.allowRecurringDrafts,
              enabled: false,
              onChanged: controller.setRecurringDrafts,
            ),
            _toggle(
              key: const Key('ai_allow_multi_step_plans'),
              title: isArabic ? 'الخطط متعددة الخطوات' : 'Multi-step plans',
              value: settings.allowMultiStepPlans,
              enabled: false,
              onChanged: controller.setMultiStepPlans,
            ),
            CPListTile(
              key: const Key('ai_execution_behavior'),
              title: isArabic ? 'سلوك التنفيذ' : 'Execution behavior',
              subtitle: isArabic
                  ? 'مراجعة وتأكيد — يلزم تأكيد صريح لكل تغيير.'
                  : 'Review and Confirm — every change requires explicit confirmation.',
              leading: const Icon(Icons.verified_user_outlined),
              trailing: Text(isArabic ? 'مراجعة وتأكيد' : 'Review and Confirm'),
            ),
            CPListTile(
              key: const Key('ai_clear_activity_history'),
              title: isArabic
                  ? 'مسح سجل نشاط المساعد'
                  : 'Clear AI activity history',
              subtitle: isArabic
                  ? 'يمسح سجل النشاط المحلي المرئي فقط.'
                  : 'Clears only the visible local activity history.',
              leading: const Icon(Icons.history_toggle_off_outlined),
              onTap: () async {
                final accountScope = ref.read(aiAgentAccountScopeProvider);
                if (accountScope == null) {
                  return;
                }
                await ref
                    .read(appAgentAuditStoreProvider)
                    .clearScope(accountScope);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArabic
                            ? 'تم مسح سجل نشاط المساعد المحلي.'
                            : 'Local AI activity history was cleared.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle({
    required Key key,
    required String title,
    required bool value,
    required bool enabled,
    required Future<void> Function(bool value) onChanged,
  }) {
    return CPListTile(
      key: key,
      title: title,
      trailing: Switch(
        value: value,
        onChanged: enabled ? (next) => unawaited(onChanged(next)) : null,
      ),
    );
  }

  String _levelLabel(AiAppControlLevel level, {required bool isArabic}) {
    return switch (level) {
      AiAppControlLevel.off => isArabic ? 'متوقف' : 'Off',
      AiAppControlLevel.readOnly => isArabic ? 'قراءة فقط' : 'Read only',
      AiAppControlLevel.reviewBeforeExecution =>
        isArabic ? 'مراجعة قبل التنفيذ' : 'Review before execution',
      AiAppControlLevel.fullControl => isArabic ? 'تحكم كامل' : 'Full control',
    };
  }

  String _levelDescription(AiAppControlLevel level, {required bool isArabic}) {
    return switch (level) {
      AiAppControlLevel.off =>
        isArabic
            ? 'لا يقرأ المساعد بيانات التطبيق ولا يتحكم فيه.'
            : 'The assistant cannot read or control app data.',
      AiAppControlLevel.readOnly =>
        isArabic
            ? 'قراءات مالية محلية محدودة فقط.'
            : 'Bounded local financial reads only.',
      AiAppControlLevel.reviewBeforeExecution =>
        isArabic
            ? 'يجهز مسودات، ولا ينفذ قبل التأكيد.'
            : 'Prepares drafts; never executes before confirmation.',
      AiAppControlLevel.fullControl =>
        isArabic
            ? 'أقصى صلاحيات محكومة مع بقاء التأكيد إلزامياً.'
            : 'Maximum governed capabilities with mandatory confirmation.',
    };
  }
}
