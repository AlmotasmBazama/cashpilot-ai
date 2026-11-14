import 'dart:io';

import 'package:cashpilot_ai/app/app.dart';
import 'package:cashpilot_ai/app/router/app_route_paths.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/hive_box_names.dart';
import 'package:cashpilot_ai/core/storage/settings_local_data_source.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_startup_recovery_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/application/data_deletion_providers.dart';
import 'package:cashpilot_ai/features/dashboard/application/dashboard_providers.dart';
import 'package:cashpilot_ai/features/budgets/application/providers/budgets_providers.dart';
import 'package:cashpilot_ai/features/goals/application/providers/goals_providers.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/transactions/application/providers/transactions_providers.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('cashpilot_ai_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(HiveBoxNames.settings);

    addTearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  testWidgets('renders localized app shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (_) => Stream.value(
              const AuthUser(
                uid: 'test-user',
                email: 'pilot@example.com',
                displayName: 'Test Pilot',
                emailVerified: true,
                isAnonymous: false,
                currency: 'USD',
                language: 'en',
                country: 'US',
                timezone: 'UTC',
              ),
            ),
          ),
          onboardingCompletedProvider.overrideWith((_) => true),
          ..._emptyFinanceOverrides(),
        ],
        child: const CashPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total net worth'), findsOneWidget);
    expect(find.text('Recent transactions'), findsOneWidget);
  });

  testWidgets('RTL settings controls fit a narrow app shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = _FakeSettingsLocalDataSource()
      ..locale = const Locale('ar')
      ..themeMode = ThemeMode.dark;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (_) => Stream.value(
              const AuthUser(
                uid: 'test-user',
                email: 'pilot@example.com',
                displayName: 'طيار الاختبار',
                emailVerified: true,
                isAnonymous: false,
                currency: 'LYD',
                language: 'ar',
                country: 'LY',
                timezone: 'Africa/Tripoli',
              ),
            ),
          ),
          onboardingCompletedProvider.overrideWith((_) => true),
          settingsLocalDataSourceProvider.overrideWithValue(settings),
          ..._emptyFinanceOverrides(),
        ],
        child: const CashPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.text('إجمالي صافي الثروة')),
    ).go(AppRoutePaths.settings);
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات'), findsWidgets);
    expect(find.text('أدواتك المالية'), findsOneWidget);
    expect(find.text('الحسابات'), findsOneWidget);
    expect(find.text('التقارير'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('النمط'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('النمط'), findsOneWidget);
    expect(find.text('اللغة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redirects unauthenticated users away from protected routes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((_) => Stream.value(null)),
          onboardingCompletedProvider.overrideWith((_) => true),
          ..._emptyFinanceOverrides(),
        ],
        child: const CashPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CashPilot AI'), findsOneWidget);
    expect(find.text('Total net worth'), findsNothing);

    GoRouter.of(
      tester.element(find.text('Log in')),
    ).go(AppRoutePaths.dashboard);
    await tester.pumpAndSettle();

    expect(find.text('CashPilot AI'), findsOneWidget);
    expect(find.text('Total net worth'), findsNothing);
  });

  testWidgets('completes onboarding from get started button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((_) => Stream.value(null)),
          settingsLocalDataSourceProvider.overrideWithValue(
            _FakeSettingsLocalDataSource(),
          ),
          ..._emptyFinanceOverrides(),
        ],
        child: const CashPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Track every account.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('CashPilot AI'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Track every account.'), findsNothing);
  });

  testWidgets('routes unverified email users to verification', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (_) => Stream.value(
              const AuthUser(
                uid: 'test-user',
                email: 'pilot@example.com',
                displayName: 'Test Pilot',
                emailVerified: false,
                isAnonymous: false,
                currency: 'USD',
                language: 'en',
                country: 'US',
                timezone: 'UTC',
              ),
            ),
          ),
          onboardingCompletedProvider.overrideWith((_) => true),
          ..._emptyFinanceOverrides(),
        ],
        child: const CashPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Total net worth'), findsNothing);
  });

  testWidgets('routes incomplete profiles to profile completion', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (_) => Stream.value(
              const AuthUser(
                uid: 'test-user',
                email: 'pilot@example.com',
                displayName: 'Test Pilot',
                emailVerified: true,
                isAnonymous: false,
              ),
            ),
          ),
          onboardingCompletedProvider.overrideWith((_) => true),
          ..._emptyFinanceOverrides(),
        ],
        child: const CashPilotApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete profile'), findsOneWidget);
    expect(find.text('Total net worth'), findsNothing);
  });
}

class _FakeSettingsLocalDataSource implements SettingsLocalDataSource {
  var onboardingCompleted = false;
  var rememberMe = false;
  var aiAgentMemoryPersistenceEnabled = false;
  var baseCurrencyCode = 'LYD';
  final Map<String, String> ownerBaseCurrencyCodes = <String, String>{};
  ThemeMode themeMode = ThemeMode.system;
  Locale? locale;

  @override
  Locale? readLocale() => locale;

  @override
  String readBaseCurrencyCode() => baseCurrencyCode;

  @override
  String? readOwnerBaseCurrencyCode(ConfirmedOwnerScope ownerScope) =>
      ownerBaseCurrencyCodes[ownerScope.id.value];

  @override
  bool readOnboardingCompleted() => onboardingCompleted;

  @override
  bool readRememberMe() => rememberMe;

  @override
  ThemeMode readThemeMode() => themeMode;

  @override
  bool readAiAgentMemoryPersistenceEnabled({required String accountScope}) =>
      aiAgentMemoryPersistenceEnabled;

  @override
  Future<void> clearAiAgentMemory({required String accountScope}) async {}

  @override
  Future<void> saveLocale(Locale? locale) async {
    this.locale = locale;
  }

  @override
  Future<void> saveBaseCurrencyCode(String currencyCode) async {
    baseCurrencyCode = currencyCode;
  }

  @override
  Future<void> saveOwnerBaseCurrencyCode(
    ConfirmedOwnerScope ownerScope,
    String currencyCode,
  ) async {
    ownerBaseCurrencyCodes[ownerScope.id.value] = currencyCode;
  }

  @override
  Future<void> saveOnboardingCompleted(bool completed) async {
    onboardingCompleted = completed;
  }

  @override
  Future<void> saveRememberMe(bool rememberMe) async {
    this.rememberMe = rememberMe;
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    this.themeMode = themeMode;
  }

  @override
  Future<void> saveAiAgentMemoryPersistenceEnabled({
    required String accountScope,
    required bool enabled,
    void Function()? assertWriteAllowed,
  }) async {
    assertWriteAllowed?.call();
    aiAgentMemoryPersistenceEnabled = enabled;
  }
}

List<Override> _emptyFinanceOverrides() {
  final operationFence = BackupOperationFence();
  return [
    backupOperationFenceProvider.overrideWithValue(operationFence),
    aiAppControlSettingsStoreProvider.overrideWithValue(
      _StaticAiAppControlSettingsStore(),
    ),
    accountDeletionStartupRecoveryProvider.overrideWith(
      (_) async => const AccountDeletionStartupRecoveryReport(
        completed: 0,
        retained: 0,
        rejected: 0,
      ),
    ),
    accountsProvider.overrideWith(
      (_) async => AppResult<List<Account>>.success(const <Account>[]),
    ),
    categoriesProvider.overrideWith(
      (_) async => AppResult<List<Category>>.success(const <Category>[]),
    ),
    transactionsProvider.overrideWith(
      (_) async => AppResult<List<Transaction>>.success(const <Transaction>[]),
    ),
    dashboardTransactionsProvider.overrideWith(
      (_) => Stream.value(
        const AppResult<List<Transaction>>.success(<Transaction>[]),
      ),
    ),
    budgetSummaryProvider.overrideWith(
      (_) async => const AppResult<BudgetSummary>.success(
        BudgetSummary(
          activeCount: 0,
          warningCount: 0,
          exceededCount: 0,
          topWarning: null,
        ),
      ),
    ),
    goalSummaryProvider.overrideWith(
      (_) async => const AppResult<GoalSummary>.success(
        GoalSummary(
          activeCount: 0,
          savedTotals: <GoalCurrencyTotal>[],
          nearestTargetDate: null,
          completedCount: 0,
        ),
      ),
    ),
    financialInsightsProvider.overrideWith(
      (_) async => AppResult<List<FinancialInsight>>.success(const []),
    ),
  ];
}

final class _StaticAiAppControlSettingsStore
    implements AiAppControlSettingsStore {
  @override
  Future<AiAppControlSettings> read(String accountScopeHash) async =>
      AiAppControlSettings.forLevel(
        AiAppControlLevel.readOnly,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
      );

  @override
  Future<void> save(
    String accountScopeHash,
    AiAppControlSettings settings,
  ) async {}

  @override
  Future<void> clear(String accountScopeHash) async {}
}
