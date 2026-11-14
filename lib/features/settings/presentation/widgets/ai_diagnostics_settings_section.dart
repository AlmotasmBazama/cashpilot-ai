import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/app_check_activation_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../ai_assistant/application/providers/ai_runtime_status_providers.dart';
import '../../../ai_assistant/domain/entities/ai_capability.dart';
import '../../../ai_assistant/domain/entities/ai_runtime_status.dart';

class AiDiagnosticsSettingsSection extends ConsumerWidget {
  const AiDiagnosticsSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtimeStatus = ref.watch(aiRuntimeStatusControllerProvider);

    return FinanceSection(
      title: l10n.aiDiagnosticsTitle,
      subtitle: l10n.aiDiagnosticsDescription,
      child: runtimeStatus.when(
        data: (status) => _RuntimeStatusCard(
          status: status,
          onTest: () => _runLiveTest(context, ref),
        ),
        loading: () => const _RuntimeStatusLoadingCard(),
        error: (_, _) => _RuntimeStatusUnavailableCard(
          message: l10n.aiTestStatusUnavailable,
        ),
      ),
    );
  }

  Future<void> _runLiveTest(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(aiRuntimeStatusControllerProvider.notifier)
        .runLiveTest();
    if (!context.mounted || result == null) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_statusMessage(l10n, result))));
  }
}

class _RuntimeStatusCard extends StatelessWidget {
  const _RuntimeStatusCard({required this.status, required this.onTest});

  final AiRuntimeStatusSnapshot status;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final testStatus =
        status.remoteTextProvider == AiActiveProvider.groq &&
            !status.remoteTextProviderConfigured
        ? AiRuntimeUiStatus.configurationMissing
        : status.lastLiveTestStatus;
    final isTesting = testStatus == AiRuntimeUiStatus.testing;
    final generalModel = status.generalConversationModel;
    final financialModel =
        status.financialExplanationProvider == AiActiveProvider.none
        ? null
        : status.financialExplanationModel;

    return CPCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(CPSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.aiConfigurationTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: CPSpacing.sm),
                _acceptanceRow(
                  identifier: status.remoteTextProvider == AiActiveProvider.groq
                      ? 'ai_settings_remote_groq'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiRemoteTextProviderLabel,
                    value: _providerLabel(l10n, status.remoteTextProvider),
                    icon: Icons.hub_outlined,
                  ),
                ),
                _acceptanceRow(
                  identifier:
                      generalModel ==
                          AiRuntimeModelCatalog.gatewayGeneralConversation
                      ? 'ai_settings_general_20b'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiGeneralConversationModelLabel,
                    value: _modelLabel(l10n, generalModel),
                    icon: Icons.memory_outlined,
                  ),
                ),
                _acceptanceRow(
                  identifier:
                      financialModel ==
                          AiRuntimeModelCatalog.gatewayFinancialExplanation
                      ? 'ai_settings_financial_120b'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiFinancialExplanationModelLabel,
                    value: _modelLabel(l10n, financialModel),
                    icon: Icons.analytics_outlined,
                  ),
                ),
                _acceptanceRow(
                  identifier:
                      status.localCommandParser ==
                          AiRuntimeModelCatalog.localCommandParser
                      ? 'ai_settings_local_parser'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiLocalCommandParserLabel,
                    value: status.localCommandParser,
                    icon: Icons.rule_rounded,
                  ),
                ),
                _acceptanceRow(
                  identifier:
                      status.receiptVisionProvider == AiActiveProvider.firebase
                      ? 'ai_settings_receipt_firebase'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiReceiptVisionProviderLabel,
                    value: _receiptProviderLabel(l10n, status),
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                _DiagnosticDetailRow(
                  label: l10n.aiProviderRoutingLabel,
                  value: _routingLabel(l10n, status),
                  icon: Icons.alt_route_rounded,
                ),
                _acceptanceRow(
                  identifier: status.firebaseTextFallbackEnabled
                      ? null
                      : 'ai_settings_fallback_disabled',
                  child: _DiagnosticDetailRow(
                    label: l10n.aiFirebaseTextFallbackLabel,
                    value: status.firebaseTextFallbackEnabled
                        ? l10n.aiStatusEnabled
                        : l10n.aiStatusDisabled,
                    icon: Icons.swap_horiz_rounded,
                  ),
                ),
                _acceptanceRow(
                  identifier:
                      status.gatewayAvailability ==
                          AiRuntimeGatewayAvailability.available
                      ? 'ai_settings_gateway_available'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiGatewayLabel,
                    value: _gatewayLabel(l10n, status.gatewayAvailability),
                    icon: Icons.cloud_outlined,
                  ),
                ),
                _acceptanceRow(
                  identifier: status.authenticationReady
                      ? 'ai_settings_auth_ready'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiAuthenticationLabel,
                    value: status.authenticationReady
                        ? l10n.aiStatusReady
                        : l10n.aiStatusNotReady,
                    icon: Icons.verified_user_outlined,
                  ),
                ),
                _acceptanceRow(
                  identifier: status.appCheckActivated
                      ? 'ai_settings_appcheck_verified'
                      : null,
                  child: _DiagnosticDetailRow(
                    label: l10n.aiAppCheckLabel,
                    value: _appCheckLabel(l10n, status),
                    icon: Icons.shield_outlined,
                  ),
                ),
                _acceptanceRow(
                  identifier:
                      'ai_settings_test_${_acceptanceStatus(testStatus)}',
                  child: _DiagnosticDetailRow(
                    label: l10n.aiLastTestStatusLabel,
                    value: _statusLabel(l10n, testStatus),
                    valueColor: _statusColor(context, testStatus),
                    icon: _statusIcon(testStatus),
                  ),
                ),
                _DiagnosticDetailRow(
                  label: l10n.aiLastCheckedLabel,
                  value: _lastCheckedText(context, l10n, status),
                  icon: Icons.schedule_outlined,
                ),
                if (status.lastLiveTestLatency case final latency?)
                  _DiagnosticDetailRow(
                    label: l10n.aiLiveTestLatencyLabel,
                    value: l10n.aiLiveTestLatencyValue(latency.inMilliseconds),
                    icon: Icons.speed_rounded,
                  ),
                if (status.lastLiveTestFailureCode case final code?)
                  _DiagnosticDetailRow(
                    label: l10n.aiTechnicalCodeLabel,
                    value: code.name,
                    icon: Icons.code_rounded,
                  ),
                const SizedBox(height: CPSpacing.sm),
                _ProviderTestNotice(message: _noticeMessage(l10n, status)),
              ],
            ),
          ),
          const Divider(height: 1),
          CPListTile(
            title: isTesting ? l10n.testingAiConnection : l10n.testAiConnection,
            supportingText: _statusDescription(l10n, status),
            leading: const Icon(Icons.smart_toy_outlined),
            trailing: isTesting
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _statusIcon(testStatus),
                    color: _statusColor(context, testStatus),
                  ),
            onTap: isTesting ? null : onTest,
            // The acceptance-only identifier is attached to the complete
            // tappable tile by CPListTile. Normal builds receive null.
            semanticsIdentifier: cashPilotForceStopAcceptanceIdentifier(
              'ai_settings_live_test',
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeStatusLoadingCard extends StatelessWidget {
  const _RuntimeStatusLoadingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CPCard(
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: CPSpacing.md),
          Expanded(child: Text(l10n.aiStatusChecking)),
        ],
      ),
    );
  }
}

class _RuntimeStatusUnavailableCard extends StatelessWidget {
  const _RuntimeStatusUnavailableCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => CPCard(
    child: Row(
      children: <Widget>[
        const Icon(Icons.error_outline_rounded),
        const SizedBox(width: CPSpacing.md),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

Widget _acceptanceRow({required String? identifier, required Widget child}) {
  if (identifier == null) return child;
  return cashPilotForceStopAcceptanceSemantics(
    identifier: identifier,
    child: child,
  );
}

String _providerLabel(AppLocalizations l10n, AiActiveProvider provider) {
  return switch (provider) {
    AiActiveProvider.groq => l10n.aiProviderGroq,
    AiActiveProvider.firebase => l10n.aiProviderFirebaseAi,
    _ => l10n.aiProviderNotConfigured,
  };
}

String _receiptProviderLabel(
  AppLocalizations l10n,
  AiRuntimeStatusSnapshot status,
) {
  return status.receiptVisionProvider == AiActiveProvider.firebase
      ? l10n.aiProviderFirebaseAi
      : l10n.aiStatusDisabled;
}

String _modelLabel(AppLocalizations l10n, String? model) {
  final normalized = model?.trim();
  return normalized == null || normalized.isEmpty
      ? l10n.aiProviderNotConfigured
      : normalized;
}

String _routingLabel(AppLocalizations l10n, AiRuntimeStatusSnapshot status) {
  return switch (status.preference) {
    AiRuntimeProviderPreference.groq => l10n.aiProviderRoutingGroqPrimary,
    AiRuntimeProviderPreference.firebase =>
      l10n.aiProviderRoutingFirebasePrimary,
    AiRuntimeProviderPreference.auto || AiRuntimeProviderPreference.legacy =>
      status.remoteTextProvider == AiActiveProvider.groq
          ? l10n.aiProviderRoutingGroqPrimary
          : status.remoteTextProvider == AiActiveProvider.firebase
          ? l10n.aiProviderRoutingFirebasePrimary
          : l10n.aiProviderRoutingDisabled,
    AiRuntimeProviderPreference.disabled => l10n.aiProviderRoutingDisabled,
  };
}

String _gatewayLabel(
  AppLocalizations l10n,
  AiRuntimeGatewayAvailability availability,
) {
  return switch (availability) {
    AiRuntimeGatewayAvailability.available => l10n.aiStatusAvailable,
    AiRuntimeGatewayAvailability.unavailable => l10n.aiStatusUnavailable,
    AiRuntimeGatewayAvailability.notConfigured => l10n.aiProviderNotConfigured,
    AiRuntimeGatewayAvailability.notChecked ||
    AiRuntimeGatewayAvailability.checking => l10n.aiStatusChecking,
  };
}

String _appCheckLabel(AppLocalizations l10n, AiRuntimeStatusSnapshot status) {
  if (status.appCheckActivated) return l10n.aiStatusVerified;
  return switch (status.appCheckPhase) {
    AppCheckActivationPhase.initializing => l10n.aiStatusChecking,
    _ => l10n.aiStatusNotActivated,
  };
}

String _statusLabel(AppLocalizations l10n, AiRuntimeUiStatus status) {
  return switch (status) {
    AiRuntimeUiStatus.notTested => l10n.aiNotTestedCurrentConfiguration,
    AiRuntimeUiStatus.testing => l10n.aiTestStatusTesting,
    AiRuntimeUiStatus.available => l10n.aiTestStatusAvailable,
    AiRuntimeUiStatus.unavailable => l10n.aiTestStatusUnavailable,
    AiRuntimeUiStatus.configurationMissing =>
      l10n.aiTestStatusConfigurationMissing,
    AiRuntimeUiStatus.authenticationRequired =>
      l10n.aiTestStatusAuthenticationRequired,
    AiRuntimeUiStatus.appCheckUnavailable =>
      l10n.aiTestStatusAppCheckUnavailable,
    AiRuntimeUiStatus.gatewayUnavailable => l10n.aiTestStatusGatewayUnavailable,
    AiRuntimeUiStatus.modelUnavailable => l10n.aiTestStatusModelUnavailable,
    AiRuntimeUiStatus.rateLimited => l10n.aiTestStatusRateLimited,
    AiRuntimeUiStatus.offline => l10n.aiTestStatusOffline,
    AiRuntimeUiStatus.timedOut => l10n.aiTestStatusTimedOut,
  };
}

String _statusDescription(
  AppLocalizations l10n,
  AiRuntimeStatusSnapshot status,
) {
  if (status.lastLiveTestStatus == AiRuntimeUiStatus.notTested) {
    return _noticeMessage(l10n, status);
  }
  return _statusMessage(l10n, status);
}

String _noticeMessage(AppLocalizations l10n, AiRuntimeStatusSnapshot status) {
  if (status.remoteTextProvider == AiActiveProvider.groq) {
    return status.remoteTextProviderConfigured
        ? l10n.aiGroqLiveTestMessage
        : l10n.aiGroqNotConfiguredBuildMessage;
  }
  if (status.remoteTextProvider == AiActiveProvider.firebase) {
    return l10n.aiRemoteProviderLiveTestMessage;
  }
  return l10n.aiLiveProviderInactiveMessage;
}

String _statusMessage(AppLocalizations l10n, AiRuntimeStatusSnapshot status) {
  return switch (status.lastLiveTestStatus) {
    AiRuntimeUiStatus.notTested => l10n.aiNotTestedCurrentConfiguration,
    AiRuntimeUiStatus.testing => l10n.testingAiConnection,
    AiRuntimeUiStatus.available => l10n.aiLiveTestAvailableMessage,
    AiRuntimeUiStatus.configurationMissing =>
      l10n.aiGroqNotConfiguredBuildMessage,
    AiRuntimeUiStatus.authenticationRequired =>
      l10n.aiTestStatusAuthenticationRequired,
    AiRuntimeUiStatus.appCheckUnavailable => l10n.aiAppCheckBlockedMessage,
    AiRuntimeUiStatus.gatewayUnavailable => l10n.aiTestStatusGatewayUnavailable,
    AiRuntimeUiStatus.modelUnavailable => l10n.aiTestStatusModelUnavailable,
    AiRuntimeUiStatus.rateLimited => l10n.aiRateLimitedMessage,
    AiRuntimeUiStatus.offline => l10n.aiNetworkFailureMessage,
    AiRuntimeUiStatus.timedOut => l10n.aiTestStatusTimedOut,
    AiRuntimeUiStatus.unavailable => l10n.aiTestStatusUnavailable,
  };
}

String _lastCheckedText(
  BuildContext context,
  AppLocalizations l10n,
  AiRuntimeStatusSnapshot status,
) {
  final checkedAt = status.lastLiveTestTimestamp;
  if (checkedAt == null) return l10n.aiNotCheckedYet;
  final localCheckedAt = checkedAt.toLocal();
  final materialL10n = MaterialLocalizations.of(context);
  final date = materialL10n.formatCompactDate(localCheckedAt);
  final time = materialL10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(localCheckedAt),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return l10n.aiLastCheckedValue(date, time);
}

String _acceptanceStatus(AiRuntimeUiStatus status) => switch (status) {
  AiRuntimeUiStatus.notTested => 'idle',
  AiRuntimeUiStatus.testing => 'testing',
  AiRuntimeUiStatus.available => 'available',
  AiRuntimeUiStatus.configurationMissing => 'configuration_missing',
  AiRuntimeUiStatus.authenticationRequired => 'authentication_required',
  AiRuntimeUiStatus.appCheckUnavailable => 'appcheck_unavailable',
  AiRuntimeUiStatus.gatewayUnavailable => 'gateway_unavailable',
  AiRuntimeUiStatus.modelUnavailable => 'model_unavailable',
  AiRuntimeUiStatus.rateLimited => 'rate_limited',
  AiRuntimeUiStatus.offline => 'offline',
  AiRuntimeUiStatus.timedOut => 'timed_out',
  AiRuntimeUiStatus.unavailable => 'unavailable',
};

IconData _statusIcon(AiRuntimeUiStatus status) {
  return switch (status) {
    AiRuntimeUiStatus.notTested => Icons.play_circle_outline_rounded,
    AiRuntimeUiStatus.testing => Icons.sync_rounded,
    AiRuntimeUiStatus.available => Icons.check_circle_outline_rounded,
    _ => Icons.error_outline_rounded,
  };
}

Color? _statusColor(BuildContext context, AiRuntimeUiStatus status) {
  return switch (status) {
    AiRuntimeUiStatus.notTested || AiRuntimeUiStatus.testing => null,
    AiRuntimeUiStatus.available => context.cpColors.income,
    AiRuntimeUiStatus.rateLimited => context.cpColors.warning,
    _ => context.cpColors.expense,
  };
}

class _DiagnosticDetailRow extends StatelessWidget {
  const _DiagnosticDetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: CPSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    final valueWidget = Text(
      value,
      textAlign: TextAlign.start,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: valueColor ?? colorScheme.onSurface,
        fontWeight: FontWeight.w900,
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: CPSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                labelWidget,
                const SizedBox(height: CPSpacing.xs),
                valueWidget,
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: labelWidget),
              const SizedBox(width: CPSpacing.lg),
              Flexible(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderTestNotice extends StatelessWidget {
  const _ProviderTestNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(CPRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CPSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: CPSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
