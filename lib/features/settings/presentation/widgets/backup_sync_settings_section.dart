import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/application/sync_providers.dart';
import '../../../../core/sync/data/sync_preferences_local_data_source.dart';
import '../../../../core/sync/domain/sync_queue_item.dart';
import '../../../../core/sync/domain/sync_result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../auth/application/providers/auth_providers.dart';

class BackupSyncSettingsSection extends ConsumerWidget {
  const BackupSyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentAuthUserProvider);
    final canBackUp = user != null && !user.isAnonymous;
    final userId = canBackUp ? user.uid : null;
    final enabled = userId == null
        ? false
        : ref.watch(backupEnabledProvider(userId));
    final lastBackupAt = userId == null
        ? null
        : ref.watch(lastBackupAtProvider(userId));
    final stats = userId == null
        ? const SyncQueueStats.empty()
        : switch (ref.watch(syncQueueStatsProvider(userId))) {
            AsyncData(:final value) => value,
            _ => const SyncQueueStats.empty(),
          };
    final action = ref.watch(syncActionControllerProvider);
    final isBusy = action.isLoading;
    final localeName = Localizations.localeOf(context).toLanguageTag();

    return FinanceSection(
      title: l10n.backup,
      child: CPCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            CPListTile(
              title: l10n.cloudBackup,
              subtitle: enabled
                  ? l10n.cloudBackupEnabled
                  : l10n.cloudBackupDisabled,
              leading: const Icon(Icons.cloud_upload_outlined),
              trailing: Switch(
                value: enabled,
                onChanged: canBackUp && !isBusy
                    ? (value) =>
                          unawaited(_setEnabled(context, ref, userId!, value))
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                CPSpacing.lg,
                0,
                CPSpacing.lg,
                CPSpacing.md,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  canBackUp
                      ? l10n.backupOnlyDescription
                      : l10n.guestBackupWarning,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            CPListTile(
              title: l10n.lastBackup,
              subtitle: lastBackupAt == null
                  ? l10n.neverBackedUp
                  : FinanceFormatters.dateTime(lastBackupAt, localeName),
              leading: const Icon(Icons.history_rounded),
            ),
            CPListTile(
              title: l10n.pendingBackupItems,
              subtitle: '${stats.pendingCount}',
              leading: const Icon(Icons.pending_actions_outlined),
            ),
            CPListTile(
              title: l10n.failedBackupItems,
              subtitle: '${stats.failedCount}',
              leading: Icon(
                Icons.cloud_off_outlined,
                color: stats.failedCount > 0 ? context.cpColors.expense : null,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
              child: Wrap(
                spacing: CPSpacing.sm,
                runSpacing: CPSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: enabled && !isBusy
                        ? () => unawaited(_sync(context, ref, retry: false))
                        : null,
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(l10n.backupNow),
                  ),
                  OutlinedButton.icon(
                    onPressed: enabled && !isBusy && stats.failedCount > 0
                        ? () => unawaited(_sync(context, ref, retry: true))
                        : null,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retryFailedBackup),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool enabled,
  ) async {
    final preferences = ref.read(syncPreferencesLocalDataSourceProvider);
    await preferences.saveBackupEnabled(userId, enabled);
    ref.invalidate(backupEnabledProvider(userId));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? AppLocalizations.of(context).cloudBackupEnabled
              : AppLocalizations.of(context).cloudBackupDisabled,
        ),
      ),
    );
  }

  Future<void> _sync(
    BuildContext context,
    WidgetRef ref, {
    required bool retry,
  }) async {
    final result = await ref
        .read(syncActionControllerProvider.notifier)
        .synchronize(ref.read(currentAuthUserProvider), retryFailed: retry);
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_resultMessage(l10n, result))));
  }

  String _resultMessage(AppLocalizations l10n, SyncResult result) {
    if (result.blocked) {
      return l10n.guestBackupWarning;
    }
    if (result.failedCount > 0) {
      return l10n.backupPartialFailure(result.failedCount);
    }
    if (result.attemptedCount == 0) {
      return l10n.backupNoPendingItems;
    }
    return l10n.backupSuccess(result.syncedCount + result.deletedCount);
  }
}
