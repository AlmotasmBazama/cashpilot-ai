import 'dart:async';

import 'package:cashpilot_ai/app/app.dart';
import 'package:cashpilot_ai/app/router/app_router.dart';
import 'package:cashpilot_ai/core/localization/locale_controller.dart';
import 'package:cashpilot_ai/core/theme/theme_mode_controller.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_startup_recovery_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/application/data_deletion_providers.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'pending deletion recovery constructs no routed or owner-sensitive provider',
    (tester) async {
      final recovery = Completer<AccountDeletionStartupRecoveryReport>();
      final observer = _RecordingProviderObserver();
      var routerBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          observers: [observer],
          overrides: _appOverrides(
            recover: (_) => recovery.future,
            onRouterBuild: () => routerBuilds += 1,
          ),
          child: const CashPilotApp(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('account-deletion-recovery-loading')),
        findsOneWidget,
      );
      expect(routerBuilds, 0);
      expect(
        observer.names.intersection(_ownerSensitiveProviderNames),
        isEmpty,
      );

      recovery.complete(_cleanReport);
      await tester.pumpAndSettle();

      expect(routerBuilds, 1);
      expect(find.text('safe routed tree'), findsOneWidget);
    },
  );

  testWidgets('recovery error stays locked and retry must finish cleanly', (
    tester,
  ) async {
    var attempts = 0;
    var routerBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: _appOverrides(
          recover: (_) async {
            attempts += 1;
            if (attempts == 1) {
              throw StateError('simulated secure recovery outage');
            }
            return _cleanReport;
          },
          onRouterBuild: () => routerBuilds += 1,
        ),
        child: const CashPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CashPilot AI could not start'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(routerBuilds, 0);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(routerBuilds, 1);
    expect(find.text('safe routed tree'), findsOneWidget);
  });

  testWidgets(
    'authenticated continuation is route-free until exact owner authorizes',
    (tester) async {
      final observer = _RecordingProviderObserver();
      var routerBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          observers: [observer],
          overrides: _appOverrides(
            recover: (_) async => _continuationReport,
            onRouterBuild: () => routerBuilds += 1,
          ),
          child: const CashPilotApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('account-deletion-continuation')),
        findsOneWidget,
      );
      expect(routerBuilds, 0);
      expect(
        observer.names.intersection(_ownerSensitiveProviderNames),
        isEmpty,
      );
    },
  );

  for (final blocked in <AccountDeletionStartupRecoveryReport>[
    const AccountDeletionStartupRecoveryReport(
      completed: 0,
      retained: 1,
      rejected: 0,
    ),
    const AccountDeletionStartupRecoveryReport(
      completed: 0,
      retained: 0,
      rejected: 1,
    ),
  ]) {
    final reason = blocked.retained > 0 ? 'retained' : 'rejected';
    testWidgets('$reason recovery marker stays locked until a clean retry', (
      tester,
    ) async {
      var attempts = 0;
      var routerBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _appOverrides(
            recover: (_) async {
              attempts += 1;
              return attempts == 1 ? blocked : _cleanReport;
            },
            onRouterBuild: () => routerBuilds += 1,
          ),
          child: const CashPilotApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CashPilot AI could not start'), findsOneWidget);
      expect(routerBuilds, 0);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(routerBuilds, 1);
      expect(find.text('safe routed tree'), findsOneWidget);
    });
  }
}

const _cleanReport = AccountDeletionStartupRecoveryReport(
  completed: 1,
  retained: 0,
  rejected: 0,
);

final _continuationReport = AccountDeletionStartupRecoveryReport(
  completed: 0,
  retained: 0,
  rejected: 0,
  authenticatedContinuations: <AccountDeletionRecoveryTarget>[
    AccountDeletionRecoveryTarget(
      operationId: '01900000-0000-7000-8000-000000000111',
      ownerScopeValue:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
  ],
);

const _ownerSensitiveProviderNames = <String>{
  'appRouterProvider',
  'authStateProvider',
  'currentAuthUserProvider',
  'confirmedOwnerScopeSnapshotProvider',
  'scopedAppDatabaseSessionProvider',
  'accountsProvider',
  'transactionsProvider',
  'aiAgentMemoryStoreProvider',
  'profileRepositoryProvider',
  'accountDeletionAuthenticatedContinuationProvider',
  'accountDeletionAuthDataSourceProvider',
  'dataDeletionRepositoryProvider',
};

List<Override> _appOverrides({
  required Future<AccountDeletionStartupRecoveryReport> Function(Ref ref)
  recover,
  required VoidCallback onRouterBuild,
}) {
  return <Override>[
    accountDeletionStartupRecoveryProvider.overrideWith(recover),
    appRouterProvider.overrideWith((ref) {
      onRouterBuild();
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('safe routed tree')),
          ),
        ],
      );
      ref.onDispose(router.dispose);
      return router;
    }),
    themeModeControllerProvider.overrideWith(_FixedThemeController.new),
    localeControllerProvider.overrideWith(_FixedLocaleController.new),
  ];
}

final class _FixedThemeController extends ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

final class _FixedLocaleController extends LocaleController {
  @override
  Locale? build() => const Locale('en');
}

final class _RecordingProviderObserver extends ProviderObserver {
  final Set<String> names = <String>{};

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final name = context.provider.name;
    if (name != null) {
      names.add(name);
    }
  }
}
