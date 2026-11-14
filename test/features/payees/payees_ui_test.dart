import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/payees/application/providers/payees_providers.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/payees/domain/enums/payee_type.dart';
import 'package:cashpilot_ai/features/payees/presentation/pages/payee_details_screen.dart';
import 'package:cashpilot_ai/features/payees/presentation/pages/payees_screen.dart';
import 'package:cashpilot_ai/features/payees/presentation/widgets/payee_form_sheet.dart';
import 'package:cashpilot_ai/features/transactions/application/providers/transactions_providers.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('payees list renders in a narrow RTL layout without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final salem = Payee.create(
      name: 'سالم',
      type: PayeeType.person,
      aliases: const <String>['Salem'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allPayeesProvider.overrideWith(
            (_) => Stream.value(AppResult.success(<Payee>[salem])),
          ),
          accountsProvider.overrideWith(
            (_) async => const AppResult.success(<Account>[]),
          ),
          categoriesProvider.overrideWith(
            (_) async => const AppResult.success(<Category>[]),
          ),
        ],
        child: _app(locale: const Locale('ar'), child: const PayeesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سالم'), findsOneWidget);
    expect(find.textContaining('Salem'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add payee form validates the required name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (_) async => const AppResult.success(<Account>[]),
          ),
          categoriesProvider.overrideWith(
            (_) async => const AppResult.success(<Category>[]),
          ),
        ],
        child: _app(child: const Scaffold(body: PayeeFormSheet())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Payee name is required.'), findsOneWidget);
  });

  testWidgets('payee details render dedicated fields and transactions', (
    tester,
  ) async {
    final payee = Payee.create(
      id: 'merchant',
      name: 'Al Nawar',
      type: PayeeType.merchant,
      aliases: const <String>['Nawar Market'],
      notes: 'Weekly groceries',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          payeeByIdProvider.overrideWith(
            (_, id) async => AppResult<Payee?>.success(payee),
          ),
          transactionsByPayeeProvider.overrideWith(
            (_, id) async => const AppResult.success(<Transaction>[]),
          ),
          accountsProvider.overrideWith(
            (_) async => const AppResult.success(<Account>[]),
          ),
          categoriesProvider.overrideWith(
            (_) async => const AppResult.success(<Category>[]),
          ),
        ],
        child: _app(child: const PayeeDetailsScreen(payeeId: 'merchant')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payee details'), findsOneWidget);
    expect(find.text('Al Nawar'), findsOneWidget);
    expect(find.text('Nawar Market'), findsOneWidget);
    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(find.text('Never used'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Related transactions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({required Widget child, Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: CPTheme.light(),
    home: child,
  );
}
