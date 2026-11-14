import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/localization/locale_controller.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/ai_assistant/application/providers/ai_durable_action_providers.dart';
import '../features/ai_assistant/application/providers/ai_app_control_providers.dart';
import '../features/data_deletion/application/data_deletion_providers.dart';
import '../features/data_deletion/presentation/account_deletion_continuation_app.dart';
import '../l10n/app_localizations.dart';
import 'bootstrap_failure_app.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class CashPilotApp extends ConsumerWidget {
  const CashPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Account-deletion recovery is a hard startup barrier. Do not construct
    // the router (or any of its Auth/profile/finance/AI provider graph) until
    // every durable marker has been resolved without retention or rejection.
    final recovery = ref.watch(accountDeletionStartupRecoveryProvider);
    if (recovery.isLoading) {
      return const _AccountDeletionRecoveryLoadingApp();
    }
    if (recovery case AsyncData(value: final report)) {
      if (report.retained == 0 && report.rejected == 0) {
        if (report.authenticatedContinuations.isEmpty) {
          return const _RoutedCashPilotApp();
        }
        return AccountDeletionContinuationApp(
          targets: report.authenticatedContinuations,
        );
      }
    }
    return BootstrapFailureApp(
      onRetry: () => _retryAccountDeletionStartupRecovery(ref),
    );
  }
}

class _RoutedCashPilotApp extends ConsumerWidget {
  const _RoutedCashPilotApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final config = ref.watch(appConfigProvider);
    // Reconciliation is inert without a confirmed, healthy owner scope and
    // never executes a business use case.
    if (ref.watch(aiAppControlFeatureFlagsProvider).appControlEnabled) {
      ref.watch(appAgentStartupReconciliationProvider);
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: config.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _AccountDeletionRecoveryLoadingApp extends StatelessWidget {
  const _AccountDeletionRecoveryLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CashPilot AI',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: Key('account-deletion-recovery-loading'),
          ),
        ),
      ),
    );
  }
}

Future<void> _retryAccountDeletionStartupRecovery(WidgetRef ref) async {
  ref.invalidate(accountDeletionStartupRecoveryProvider);
  try {
    await ref.read(accountDeletionStartupRecoveryProvider.future);
  } on Object {
    // The provider exposes the failure and keeps the app locked. The retry
    // surface remains available without leaking recovery details.
  }
}
