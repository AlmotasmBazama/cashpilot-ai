import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/widgets/ai_financial_storage_preview_card.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category_suggestion.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/payment_methods/payment_methods.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} preview shows exact stored fields and only two actions',
      (tester) async {
        var rejected = 0;
        var confirmed = 0;
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: locale.languageCode == 'ar'
                ? CPTheme.dark()
                : CPTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AiFinancialStoragePreviewCard(
                    draft: _expenseDraft(),
                    onReject: () => rejected += 1,
                    onConfirm: () => confirmed += 1,
                    timeZoneName: 'Africa/Tripoli',
                    clock: () => DateTime.utc(2026, 8, 23, 12),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(locale);
        expect(find.text(l10n.aiFinancialPreviewTitle), findsOneWidget);
        expect(find.text('5 LYD'), findsWidgets);
        expect(find.text('Milk'), findsOneWidget);
        expect(find.text('Cash'), findsWidgets);
        expect(find.text(l10n.aiFinancialPreviewToday), findsOneWidget);
        expect(find.text(l10n.transactionStatusPosted), findsOneWidget);
        expect(find.text(l10n.paymentMethodCash), findsWidgets);
        expect(find.text('milk 5 dinar'), findsOneWidget);
        expect(
          find.text(l10n.aiFinancialPreviewCategoryAssumption),
          findsOneWidget,
        );
        expect(find.byType(CPButton), findsNWidgets(2));
        expect(find.text(l10n.edit), findsNothing);
        expect(
          Directionality.of(
            tester.element(find.byType(AiFinancialStoragePreviewCard)),
          ),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);

        final reject = find.byKey(const Key('ai_financial_preview_cancel'));
        final confirm = find.byKey(const Key('ai_financial_preview_confirm'));
        await tester.ensureVisible(reject);
        await tester.tap(reject);
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        expect(rejected, 1);
        expect(confirmed, 1);
      },
    );
  }
}

AiActionDraft _expenseDraft() {
  final account = Account.create(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    currencyCode: 'LYD',
    balance: Decimal.fromInt(100),
    icon: 'cash',
    color: 0xFF4F46E5,
  );
  final category = buildDefaultCategories().firstWhere(
    (item) => item.name == 'Groceries',
  );
  return AiActionDraft.create(
    action: CreateExpenseDraft(
      AiTransactionDraft(
        type: TransactionType.expense,
        amount: Money(amount: Decimal.fromInt(5), currencyCode: 'LYD'),
        account: account,
        category: category,
        paymentMethod: PaymentMethod.cash,
        paymentMethodDefinition: null,
        note: 'milk 5 dinar',
        itemDescription: 'milk',
        categorySuggestion: CategorySuggestion(
          categoryId: category.id,
          categoryHint: category.name,
          confidence: 96,
          source: CategorySuggestionSource.exactAlias,
          matchedPhrase: 'milk',
        ),
        // Midnight on Aug 23 in Tripoli is still Aug 22 in UTC. The preview
        // must nevertheless render this as Today for the configured timezone.
        transactionDate: DateTime.utc(2026, 8, 22, 22),
        status: TransactionStatus.posted,
      ),
    ),
  );
}
