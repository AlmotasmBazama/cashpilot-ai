import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/owner_scope/presentation/legacy_data_claim_dialog.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';

export '../../../../core/owner_scope/presentation/legacy_data_claim_dialog.dart'
    show showLegacyDataClaimDialog;

class LegacyDataClaimSection extends ConsumerWidget {
  const LegacyDataClaimSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final health = ref.watch(ownerScopeHealthProvider);
    if (health.value?.status != OwnerScopeStatus.legacyDataUnclaimed) {
      return const SizedBox.shrink();
    }
    final inventory = ref.watch(legacyDataInventoryProvider);
    final claimState = ref.watch(legacyDataClaimControllerProvider);
    final value = inventory.value;

    return FinanceSection(
      title: isArabic ? 'ربط البيانات المحلية' : 'Claim local legacy data',
      subtitle: isArabic
          ? 'بيانات من إصدار أقدم ما زالت غير مرتبطة بأي حساب.'
          : 'Data from an older version is still unassigned to an account.',
      child: CPCard(
        padding: const EdgeInsets.all(CPSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isArabic
                  ? 'راجع البيانات أولاً، ثم وافق صراحةً على ربطها بهذا الحساب فقط. لن تُرسل السجلات إلى أي نموذج ذكاء اصطناعي.'
                  : 'Review the data, then explicitly approve associating it with this account only. No records are sent to an AI model.',
            ),
            const SizedBox(height: CPSpacing.md),
            LegacyDataInventoryStatus(inventory: inventory, isArabic: isArabic),
            if (value?.hasUnexpectedSyncQueueRows == true) ...[
              const SizedBox(height: CPSpacing.sm),
              Text(
                isArabic
                    ? 'توجد بيانات مزامنة قديمة لا تخص هذا الحساب بشكل مؤكد. أعد تشغيل التطبيق لإكمال ترحيلها الآمن. لن يتم ربطها بهذا الحساب.'
                    : 'Some legacy sync metadata cannot be safely attributed to this account. Restart the app to finish its secure migration; it will not be claimed by this account.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: CPSpacing.md),
            FilledButton.icon(
              key: const Key('claim_legacy_local_data'),
              onPressed:
                  claimState.isLoading ||
                      value?.hasLegacyData != true ||
                      value?.hasUnexpectedSyncQueueRows == true
                  ? null
                  : () => unawaited(_openClaimDialog(context, isArabic)),
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                isArabic ? 'مراجعة البيانات وربطها' : 'Review and claim data',
              ),
            ),
            if (inventory.hasError ||
                (value != null && !value.hasLegacyData)) ...[
              const SizedBox(height: CPSpacing.sm),
              OutlinedButton.icon(
                key: const Key('refresh_legacy_local_data'),
                onPressed: claimState.isLoading
                    ? null
                    : () {
                        ref.invalidate(legacyDataInventoryProvider);
                        ref.invalidate(ownerScopeHealthProvider);
                      },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isArabic ? 'إعادة الفحص' : 'Inspect again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openClaimDialog(BuildContext context, bool isArabic) async {
    final succeeded = await showLegacyDataClaimDialog(context);
    if (!context.mounted || !succeeded) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'تم ربط البيانات المحلية بالحساب والتحقق منها بأمان.'
              : 'Local data was safely associated with this account and verified.',
        ),
      ),
    );
  }
}
