import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../ai_assistant/application/providers/ai_agent_providers.dart';
import '../../application/receipt_capture_state.dart';
import '../../application/receipt_providers.dart';

class ReceiptCaptureScreen extends ConsumerWidget {
  const ReceiptCaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(receiptCaptureControllerProvider);
    final enabled = ref.watch(receiptFeatureConfigProvider).enabled;
    return Scaffold(
      appBar: CPAppBar(
        title: l10n.receiptScannerTitle,
        subtitle: l10n.receiptScannerSubtitle,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(CPSpacing.lg),
              children: [
                CPCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: CPSpacing.lg),
                      Text(
                        l10n.receiptScannerSubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: CPSpacing.xl),
                      FilledButton.icon(
                        key: const Key('receipt_take_photo_button'),
                        onPressed: enabled && !state.isBusy
                            ? () => _start(context, ref, fromGallery: false)
                            : null,
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: Text(l10n.takeReceiptPhoto),
                      ),
                      const SizedBox(height: CPSpacing.md),
                      OutlinedButton.icon(
                        key: const Key('receipt_import_image_button'),
                        onPressed: enabled && !state.isBusy
                            ? () => _start(context, ref, fromGallery: true)
                            : null,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.importReceiptImage),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CPSpacing.md),
                ListTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: Text(l10n.documentScannerUnavailable),
                  subtitle: Text(l10n.manualReceiptReview),
                  enabled: false,
                ),
                if (state.isBusy) ...[
                  const SizedBox(height: CPSpacing.lg),
                  const LinearProgressIndicator(),
                  const SizedBox(height: CPSpacing.sm),
                  Text(
                    _stageLabel(l10n, state.stage),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: CPSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('receipt_cancel_processing_button'),
                    onPressed: () => ref
                        .read(receiptCaptureControllerProvider.notifier)
                        .cancel(),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(l10n.cancel),
                  ),
                ],
                if (state.failure case final failure?) ...[
                  const SizedBox(height: CPSpacing.lg),
                  CPErrorView(
                    title: l10n.receiptScannerTitle,
                    message: failure.message,
                    action: CPButton(
                      label: l10n.retry,
                      onPressed: () => ref
                          .read(receiptCaptureControllerProvider.notifier)
                          .clear(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stageLabel(AppLocalizations l10n, ReceiptCaptureStage? stage) {
    return switch (stage) {
      ReceiptCaptureStage.selectingAndPreparing =>
        l10n.receiptPreparingProgress,
      ReceiptCaptureStage.savingDraft => l10n.receiptSavingDraftProgress,
      ReceiptCaptureStage.loadingContext => l10n.receiptLoadingContextProgress,
      ReceiptCaptureStage.analyzing || null => l10n.receiptAnalysisProgress,
    };
  }

  Future<void> _start(
    BuildContext context,
    WidgetRef ref, {
    required bool fromGallery,
  }) async {
    final ownerScope = ref.read(confirmedOwnerScopeProvider);
    final scopedSession = ref.read(scopedAppDatabaseSessionProvider);
    bool ownerContextIsCurrent() {
      return ownerScope != null &&
          scopedSession != null &&
          ref.read(confirmedOwnerScopeProvider) == ownerScope &&
          identical(ref.read(scopedAppDatabaseSessionProvider), scopedSession);
    }

    final receiptVisionAvailable = ref
        .read(aiAssistantCapabilitiesProvider)
        .receiptVisionAvailable;
    var analyzeRemotely = false;
    if (receiptVisionAvailable && ownerContextIsCurrent()) {
      final consentStore = ref.read(receiptPrivacyConsentStoreProvider);
      analyzeRemotely = consentStore.hasAccepted;
      if (!analyzeRemotely && context.mounted) {
        analyzeRemotely = await _requestConsent(context);
        if (!context.mounted || !ownerContextIsCurrent()) {
          return;
        }
        if (analyzeRemotely) {
          await consentStore.accept();
          if (!context.mounted || !ownerContextIsCurrent()) {
            return;
          }
        }
      }
    }
    if (!context.mounted || !ownerContextIsCurrent()) {
      return;
    }
    final draft = await ref
        .read(receiptCaptureControllerProvider.notifier)
        .start(
          fromGallery: fromGallery,
          analyzeRemotely: analyzeRemotely,
          locale: Localizations.localeOf(context),
        );
    if (draft != null && context.mounted) {
      context.push(AppRoutePaths.receiptReviewPath(draft.id));
    }
  }

  Future<bool> _requestConsent(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.receiptPrivacyTitle),
            content: Text(l10n.receiptPrivacyMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.manualReceiptReview),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.analyzeReceipt),
              ),
            ],
          ),
        ) ??
        false;
  }
}
