import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../features/auth/application/providers/auth_providers.dart';
import '../../../../features/auth/domain/entities/auth_user.dart';
import '../../../../features/data_deletion/application/data_deletion_providers.dart';
import '../../../../features/data_deletion/data_deletion_presentation.dart'
    show AccountDeletionCredentials, DeleteAllUserDataDialog;
import '../../../../features/data_deletion/domain/entities/data_deletion_request.dart';
import '../../../../features/data_deletion/domain/failures/data_deletion_failure_codes.dart';
import '../../../../features/exchange_rates/exchange_rates_presentation.dart'
    show ExchangeRatesSettingsSection;
import '../../../../features/exchange_rates/application/base_currency_provider.dart';
import '../../../../features/ai_assistant/application/providers/ai_agent_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../widgets/backup_sync_settings_section.dart';
import '../widgets/ai_diagnostics_settings_section.dart';
import '../widgets/ai_app_control_settings_section.dart';
import '../widgets/legacy_data_claim_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final user = ref.watch(currentAuthUserProvider);
    final isDeletingAccount = ref
        .watch(dataDeletionControllerProvider)
        .isLoading;
    final baseCurrencyCode = ref.watch(effectiveBaseCurrencyCodeProvider);
    final activeLocale = locale ?? Localizations.localeOf(context);
    final persistAiConversation = ref.watch(
      aiAgentMemoryPreferenceControllerProvider,
    );
    final ownerScopeHealth = ref.watch(ownerScopeHealthProvider);
    final isArabic = activeLocale.languageCode == 'ar';

    return Scaffold(
      appBar: CPAppBar(title: l10n.settingsTitle),
      body: cashPilotForceStopAcceptanceSemantics(
        identifier: 'ai_settings_card',
        child: FinanceScreenBody(
          child: ListView(
            children: [
              if (ownerScopeHealth.value?.status ==
                  OwnerScopeStatus.legacyDataUnclaimed) ...[
                const LegacyDataClaimSection(),
                const SizedBox(height: CPSpacing.xl),
              ],
              FinanceSection(
                title: isArabic ? 'أدواتك المالية' : 'Financial tools',
                child: CPCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _FinancialToolLink(
                        title: l10n.accountsTitle,
                        icon: Icons.account_balance_wallet_outlined,
                        path: AppRoutePaths.accounts,
                      ),
                      _FinancialToolLink(
                        title: l10n.reportsTitle,
                        icon: Icons.query_stats_outlined,
                        path: AppRoutePaths.reports,
                      ),
                      _FinancialToolLink(
                        title: l10n.budgetsTitle,
                        icon: Icons.savings_outlined,
                        path: AppRoutePaths.budgets,
                      ),
                      _FinancialToolLink(
                        title: l10n.goalsTitle,
                        icon: Icons.flag_outlined,
                        path: AppRoutePaths.goals,
                      ),
                      _FinancialToolLink(
                        title: l10n.categoriesTitle,
                        icon: Icons.category_outlined,
                        path: AppRoutePaths.categories,
                      ),
                      _FinancialToolLink(
                        title: l10n.payeesTitle,
                        icon: Icons.storefront_outlined,
                        path: AppRoutePaths.payees,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xl),
              FinanceSection(
                title: l10n.account,
                child: CPCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      CPListTile(
                        title: user?.displayName ?? l10n.profileGuestName,
                        subtitle: user?.email ?? l10n.guestAccount,
                        leading: const Icon(Icons.person_outline_rounded),
                        trailing: user == null
                            ? null
                            : Icon(
                                user.emailVerified || user.isAnonymous
                                    ? Icons.verified_user_outlined
                                    : Icons.mark_email_unread_outlined,
                              ),
                        onTap: () => context.go(AppRoutePaths.profile),
                      ),
                      if (user != null)
                        cashPilotForceStopAcceptanceSemantics(
                          identifier: 'cashpilot_acceptance_logout',
                          child: CPListTile(
                            title: l10n.logout,
                            leading: const Icon(Icons.logout_rounded),
                            onTap: () => _signOut(context, ref),
                          ),
                        ),
                      if (user != null)
                        CPListTile(
                          title: l10n.deleteAccount,
                          subtitle: l10n.deleteAccountSettingsSubtitle,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: context.cpColors.expense,
                          ),
                          trailing: isDeletingAccount
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: isDeletingAccount
                              ? null
                              : () => _deleteAccount(context, ref),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xl),
              FinanceSection(
                title: l10n.appearance,
                child: CPCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _AdaptiveSettingControl(
                        title: l10n.theme,
                        subtitle: _themeLabel(l10n, themeMode),
                        icon: Icons.dark_mode_outlined,
                        control: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          expandedInsets: EdgeInsets.zero,
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text(l10n.system),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text(l10n.light),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text(l10n.dark),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (selection) => unawaited(
                            ref
                                .read(themeModeControllerProvider.notifier)
                                .setThemeMode(selection.first),
                          ),
                        ),
                      ),
                      _AdaptiveSettingControl(
                        title: l10n.language,
                        subtitle: activeLocale.languageCode == 'ar'
                            ? l10n.arabic
                            : l10n.english,
                        icon: Icons.translate_rounded,
                        control: SegmentedButton<String>(
                          showSelectedIcon: false,
                          expandedInsets: EdgeInsets.zero,
                          segments: [
                            ButtonSegment(
                              value: 'en',
                              label: Text(l10n.english),
                            ),
                            ButtonSegment(
                              value: 'ar',
                              label: Text(l10n.arabic),
                            ),
                          ],
                          selected: {activeLocale.languageCode},
                          onSelectionChanged: (selection) => unawaited(
                            ref
                                .read(localeControllerProvider.notifier)
                                .setLocale(Locale(selection.first)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xl),
              FinanceSection(
                title: l10n.preferences,
                child: CPCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _AdaptiveSettingControl(
                        title: l10n.currency,
                        subtitle: l10n.selectBaseCurrency,
                        icon: Icons.payments_outlined,
                        control: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: baseCurrencyCode,
                            items: [
                              for (final currency in CurrencyCatalog.supported)
                                DropdownMenuItem(
                                  value: currency.code,
                                  child: Text(currency.code),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              unawaited(
                                _setBaseCurrency(
                                  context,
                                  ref,
                                  user,
                                  value,
                                  activeLocale,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xl),
              const BackupSyncSettingsSection(),
              const SizedBox(height: CPSpacing.xl),
              const ExchangeRatesSettingsSection(),
              const SizedBox(height: CPSpacing.xl),
              const AiAppControlSettingsSection(),
              const SizedBox(height: CPSpacing.xl),
              const AiDiagnosticsSettingsSection(),
              const SizedBox(height: CPSpacing.xl),
              FinanceSection(
                title: isArabic
                    ? 'خصوصية مساعد الذكاء'
                    : 'AI assistant privacy',
                child: CPCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      CPListTile(
                        title: isArabic
                            ? 'حفظ المحادثة محلياً'
                            : 'Save conversation locally',
                        subtitle: isArabic
                            ? 'متوقف افتراضياً. لا تتم مزامنة محادثات الذكاء مع السحابة.'
                            : 'Off by default. AI conversations are never cloud-synced.',
                        leading: const Icon(Icons.memory_outlined),
                        trailing: Switch(
                          value: persistAiConversation,
                          onChanged: (value) => unawaited(
                            ref
                                .read(
                                  aiAgentMemoryPreferenceControllerProvider
                                      .notifier,
                                )
                                .setPersistence(value),
                          ),
                        ),
                      ),
                      CPListTile(
                        title: isArabic
                            ? 'مسح سجل محادثة الذكاء'
                            : 'Clear AI conversation history',
                        subtitle: isArabic
                            ? 'يمسح الذاكرة والجلسة المحلية فقط.'
                            : 'Clears local memory and session context only.',
                        leading: const Icon(Icons.delete_sweep_outlined),
                        onTap: () => _clearAiConversation(
                          context,
                          ref,
                          isArabic: isArabic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xl),
              FinanceSection(
                title: l10n.security,
                child: CPCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      CPListTile(
                        title: l10n.biometricToggle,
                        subtitle: l10n.biometricPendingMessage,
                        leading: const Icon(Icons.fingerprint_rounded),
                        trailing: const Switch(value: false, onChanged: null),
                      ),
                      CPListTile(
                        title: l10n.security,
                        subtitle: l10n.securityPendingMessage,
                        leading: const Icon(Icons.shield_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xl),
              FinanceSection(
                title: l10n.legalAndPrivacy,
                child: CPCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      CPListTile(
                        title: l10n.privacyPolicy,
                        subtitle: l10n.privacyPolicySubtitle,
                        leading: const Icon(Icons.privacy_tip_outlined),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(AppRoutePaths.privacyPolicy),
                      ),
                      CPListTile(
                        title: l10n.termsOfUse,
                        subtitle: l10n.termsOfUseSubtitle,
                        leading: const Icon(Icons.description_outlined),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(AppRoutePaths.termsOfUse),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xl),
              FinanceSection(
                title: l10n.about,
                child: FinanceInfoCard(
                  title: l10n.appTitle,
                  message: l10n.aboutMessage,
                  icon: Icons.flight_takeoff_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  leading: const CPBrandMark(size: 56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearAiConversation(
    BuildContext context,
    WidgetRef ref, {
    required bool isArabic,
  }) async {
    await ref
        .read(aiAgentMemoryPreferenceControllerProvider.notifier)
        .clearHistory();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic
              ? 'تم مسح سجل محادثة الذكاء المحلي.'
              : 'Local AI conversation history was cleared.',
        ),
      ),
    );
  }

  Future<void> _setBaseCurrency(
    BuildContext context,
    WidgetRef ref,
    AuthUser? user,
    String currencyCode,
    Locale activeLocale,
  ) async {
    final l10n = AppLocalizations.of(context);
    final normalized = CurrencyCatalog.normalizeCode(currencyCode);
    final baseCurrencyController = ref.read(
      baseCurrencyControllerProvider.notifier,
    );
    final authController = ref.read(authControllerProvider.notifier);
    final expectedSession = user?.sessionIdentity;
    final saved = await baseCurrencyController.setBaseCurrencyCode(
      normalized,
      expectedSession: expectedSession,
    );

    if (!saved) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.dashboardErrorMessage)));
      }
      return;
    }

    if (user == null) {
      return;
    }

    final ok = await authController.completeProfile(
      expectedSession: user.sessionIdentity,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : user.email?.split('@').first ?? l10n.profileGuestName,
      currency: normalized,
      language: user.language ?? activeLocale.languageCode,
      country: user.country ?? 'LY',
      timezone: user.timezone ?? DateTime.now().timeZoneName,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dashboardErrorMessage)));
    }
  }

  String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => l10n.system,
      ThemeMode.light => l10n.light,
      ThemeMode.dark => l10n.dark,
    };
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) {
      context.go(AppRoutePaths.login);
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final authBoundary = ref.read(accountDeletionAuthDataSourceProvider);
    final confirmationLease = await authBoundary.issueConfirmationLease();
    if (!context.mounted) {
      authBoundary.releaseConfirmationLease(confirmationLease);
      return;
    }
    final credentials = await _showDeleteAccountDialog(
      context,
      confirmationLease,
    );
    if (credentials == null) {
      authBoundary.releaseConfirmationLease(confirmationLease);
      return;
    }

    final failure = await ref
        .read(dataDeletionControllerProvider.notifier)
        .deleteAll(
          DataDeletionRequest(
            confirmationAccepted: true,
            confirmationLease: confirmationLease,
            email: credentials.email,
            password: credentials.password,
          ),
        );

    if (failure == null && context.mounted) {
      context.go(AppRoutePaths.welcome);
      return;
    }
    if (failure != null && context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_dataDeletionFailureMessage(l10n, failure.code)),
        ),
      );
    }
  }

  Future<AccountDeletionCredentials?> _showDeleteAccountDialog(
    BuildContext context,
    AccountDeletionConfirmationLease confirmationLease,
  ) {
    return showDialog<AccountDeletionCredentials>(
      context: context,
      builder: (_) =>
          DeleteAllUserDataDialog(confirmationLease: confirmationLease),
    );
  }

  String _dataDeletionFailureMessage(
    AppLocalizations l10n,
    String? failureCode,
  ) {
    return switch (failureCode) {
      DataDeletionFailureCodes.confirmationRequired =>
        l10n.dataDeletionConfirmationRequired,
      DataDeletionFailureCodes.reauthenticationFailed =>
        l10n.dataDeletionReauthFailed,
      DataDeletionFailureCodes.identityChanged => l10n.dataDeletionReauthFailed,
      DataDeletionFailureCodes.cloudDeletionFailed =>
        l10n.dataDeletionCloudFailed,
      DataDeletionFailureCodes.cloudGatewayRequestInvalid ||
      DataDeletionFailureCodes.cloudGatewayConfigurationFailed ||
      DataDeletionFailureCodes.cloudGatewayAuthorizationFailed ||
      DataDeletionFailureCodes.cloudGatewayAuthenticationRequired ||
      DataDeletionFailureCodes.cloudGatewayAppCheckUnavailable ||
      DataDeletionFailureCodes.cloudGatewayDeletionProofInvalid ||
      DataDeletionFailureCodes.cloudGatewayPermissionDenied ||
      DataDeletionFailureCodes.cloudGatewayOperationConflict ||
      DataDeletionFailureCodes.cloudGatewayReauthenticationRequired ||
      DataDeletionFailureCodes.cloudGatewayRateLimited ||
      DataDeletionFailureCodes.cloudGatewayProviderUnavailable ||
      DataDeletionFailureCodes.cloudGatewayTimeout ||
      DataDeletionFailureCodes.cloudGatewayDeletePartial ||
      DataDeletionFailureCodes.cloudGatewayVerificationFailed ||
      DataDeletionFailureCodes.cloudGatewayNetworkFailed ||
      DataDeletionFailureCodes.cloudGatewayInvalidResponse ||
      DataDeletionFailureCodes.cloudGatewayDeletionNotReady ||
      DataDeletionFailureCodes.cloudGatewayUnknownTemporaryFailure =>
        l10n.dataDeletionCloudFailed,
      DataDeletionFailureCodes.localDeletionFailed =>
        l10n.dataDeletionLocalFailed,
      DataDeletionFailureCodes.preferencesDeletionFailed =>
        l10n.dataDeletionPreferencesFailed,
      DataDeletionFailureCodes.authDeletionFailed =>
        l10n.dataDeletionAuthFailed,
      _ => l10n.dashboardErrorMessage,
    };
  }
}

class _FinancialToolLink extends StatelessWidget {
  const _FinancialToolLink({
    required this.title,
    required this.icon,
    required this.path,
  });

  final String title;
  final IconData icon;
  final String path;

  @override
  Widget build(BuildContext context) {
    return CPListTile(
      title: title,
      leading: Icon(icon),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(path),
    );
  }
}

class _AdaptiveSettingControl extends StatelessWidget {
  const _AdaptiveSettingControl({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.control,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 620) {
          return CPListTile(
            title: title,
            subtitle: subtitle,
            leading: Icon(icon),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: control,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: CPSpacing.xxs,
                    ),
                    child: Icon(icon),
                  ),
                  const SizedBox(width: CPSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: CPSpacing.xxs),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CPSpacing.md),
              control,
            ],
          ),
        );
      },
    );
  }
}
