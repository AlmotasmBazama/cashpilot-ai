import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/storage/settings_local_data_source.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/providers/exchange_rates_providers.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/entities/stored_exchange_rate.dart';
import 'package:cashpilot_ai/features/exchange_rates/presentation/widgets/exchange_rates_settings_section.dart';
import 'package:cashpilot_ai/features/settings/presentation/pages/settings_screen.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings renders the persisted base currency selector', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsLocalDataSourceProvider.overrideWithValue(
            _MemorySettingsLocalDataSource(baseCurrencyCode: 'USD'),
          ),
          currentAuthUserProvider.overrideWithValue(null),
          authStateProvider.overrideWith((_) => Stream<AuthUser?>.value(null)),
          allExchangeRatesProvider.overrideWith(
            (_) => Stream.value(
              const AppResult<List<StoredExchangeRate>>.success(
                <StoredExchangeRate>[],
              ),
            ),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('en'),
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Select the currency used for consolidated totals.'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(
      find.text('Select the currency used for consolidated totals.'),
      findsOneWidget,
    );
    expect(find.text('USD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add exchange-rate form rejects a zero rate', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allExchangeRatesProvider.overrideWith(
            (_) => Stream.value(
              const AppResult<List<StoredExchangeRate>>.success(
                <StoredExchangeRate>[],
              ),
            ),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('en'),
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ExchangeRatesSettingsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add exchange rate'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, '0');
    await tester.tap(find.widgetWithText(CPButton, 'Save'));
    await tester.pump();

    expect(find.text('Enter a rate greater than zero.'), findsOneWidget);
  });

  testWidgets('exchange-rate list is overflow-free at 320px in RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rate = StoredExchangeRate.create(
      baseCurrency: 'USD',
      quoteCurrency: 'LYD',
      rate: Decimal.parse('7.5'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allExchangeRatesProvider.overrideWith(
            (_) => Stream.value(
              AppResult<List<StoredExchangeRate>>.success(<StoredExchangeRate>[
                rate,
              ]),
            ),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('ar'),
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: ExchangeRatesSettingsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('USD \u2192 LYD'), findsOneWidget);
    expect(find.textContaining('1 USD = 7.5 LYD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _localizedApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: CPTheme.dark(),
    home: child,
  );
}

class _MemorySettingsLocalDataSource implements SettingsLocalDataSource {
  _MemorySettingsLocalDataSource({this.baseCurrencyCode = 'LYD'});

  String baseCurrencyCode;
  bool aiAgentMemoryPersistenceEnabled = false;
  ThemeMode themeMode = ThemeMode.dark;
  Locale? locale;

  @override
  String readBaseCurrencyCode() => baseCurrencyCode;

  @override
  Locale? readLocale() => locale;

  @override
  ThemeMode readThemeMode() => themeMode;

  @override
  bool readAiAgentMemoryPersistenceEnabled({required String accountScope}) =>
      aiAgentMemoryPersistenceEnabled;

  @override
  Future<void> clearAiAgentMemory({required String accountScope}) async {}

  @override
  Future<void> saveBaseCurrencyCode(String currencyCode) async {
    baseCurrencyCode = currencyCode;
  }

  @override
  Future<void> saveLocale(Locale? value) async {
    locale = value;
  }

  @override
  Future<void> saveThemeMode(ThemeMode value) async {
    themeMode = value;
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
