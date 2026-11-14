import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system/design_system.dart';
import '../application/legacy_data_claim_service.dart';
import '../application/owner_scope_providers.dart';
import '../domain/owner_scope.dart';

/// Opens the single protected native flow used by Settings and the AI
/// assistant. The returned future is true only after the claim controller has
/// rebuilt the owner-scoped session and verified [OwnerScopeStatus.safe].
Future<bool> showLegacyDataClaimDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _LegacyDataClaimDialog(),
      ) ??
      false;
}

class _LegacyDataClaimDialog extends ConsumerStatefulWidget {
  const _LegacyDataClaimDialog();

  @override
  ConsumerState<_LegacyDataClaimDialog> createState() =>
      _LegacyDataClaimDialogState();
}

class _LegacyDataClaimDialogState
    extends ConsumerState<_LegacyDataClaimDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final inventory = ref.watch(legacyDataInventoryProvider);
    final claimState = ref.watch(legacyDataClaimControllerProvider);
    final value = inventory.value;
    final canClaim =
        _confirmed &&
        !claimState.isLoading &&
        value?.hasLegacyData == true &&
        value?.hasUnexpectedSyncQueueRows != true;

    return AlertDialog(
      title: Text(
        isArabic ? 'تأكيد ربط البيانات المحلية' : 'Confirm local data claim',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isArabic
                  ? 'هذا إجراء محلي لمرة واحدة. سيتم ربط السجلات غير المعيّنة بالحساب المسجّل دخوله حالياً فقط.'
                  : 'This is a one-time local action. Unassigned records will be associated only with the currently signed-in account.',
            ),
            const SizedBox(height: CPSpacing.md),
            LegacyDataInventoryStatus(inventory: inventory, isArabic: isArabic),
            if (value?.hasUnexpectedSyncQueueRows == true) ...[
              const SizedBox(height: CPSpacing.sm),
              Text(
                isArabic
                    ? 'تعذر إسناد بعض بيانات المزامنة القديمة لهذا الحساب بأمان. ألغِ العملية وأعد تشغيل التطبيق؛ لن يتم ربط بيانات حساب آخر.'
                    : 'Some legacy sync metadata cannot be safely attributed to this account. Cancel and restart the app; no other account data will be claimed.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (inventory.hasError ||
                (value != null && !value.hasLegacyData)) ...[
              const SizedBox(height: CPSpacing.sm),
              OutlinedButton.icon(
                key: const Key('refresh_legacy_claim_dialog_inventory'),
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
            CheckboxListTile(
              key: const Key('confirm_legacy_local_data_owner'),
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: claimState.isLoading
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: Text(
                isArabic
                    ? 'أؤكد أن هذه البيانات المحلية تخص هذا الحساب.'
                    : 'I confirm that this local data belongs to this account.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (claimState.hasError) ...[
              const SizedBox(height: CPSpacing.sm),
              Text(
                isArabic
                    ? 'لم يكتمل الربط أو التحقق. لم يتم ربط بيانات حساب آخر، ويمكن المحاولة مجدداً.'
                    : 'The claim or verification did not complete. No other account data was claimed; you can retry.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel_legacy_local_data_claim'),
          onPressed: claimState.isLoading
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_claim_legacy_local_data'),
          onPressed: canClaim ? _claim : null,
          child: claimState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isArabic ? 'تأكيد الربط' : 'Confirm claim'),
        ),
      ],
    );
  }

  Future<void> _claim() async {
    final succeeded = await ref
        .read(legacyDataClaimControllerProvider.notifier)
        .claim(protectedConfirmationAccepted: _confirmed);
    if (!mounted || !succeeded) return;
    Navigator.of(context).pop(true);
  }
}

/// Shared rendering of the inventory status used by the owner-claim entry
/// point and its protected dialog.
class LegacyDataInventoryStatus extends StatelessWidget {
  const LegacyDataInventoryStatus({
    required this.inventory,
    required this.isArabic,
    super.key,
  });

  final AsyncValue<LegacyDataInventory> inventory;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final text = inventory.isLoading
        ? (isArabic ? 'جارٍ فحص البيانات…' : 'Inspecting data…')
        : inventory.hasError
        ? (isArabic
              ? 'تعذر فحص البيانات بأمان.'
              : 'The data could not be inspected safely.')
        : (isArabic
              ? 'عدد السجلات المحلية: ${inventory.value?.total ?? 0}'
              : 'Local row count: ${inventory.value?.total ?? 0}');
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
