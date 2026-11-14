import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/accounts/presentation/widgets/account_card.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('archived account card is clear and overflow-free in RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final account = Account.create(
      id: 'account',
      name: 'حساب المصروفات اليومية الطويل',
      type: AccountType.bank,
      currencyCode: 'LYD',
      balance: Decimal.parse('987654321.12'),
      icon: 'bank',
      color: 0xFF4F46E5,
      isArchived: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AccountCard(
              account: account,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مؤرشف'), findsOneWidget);
    expect(find.text('حساب المصروفات اليومية الطويل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
