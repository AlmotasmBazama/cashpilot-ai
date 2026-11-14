import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_validator.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/widgets/ai_action_confirmation_card.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category_suggestion.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI confirmation card stays usable in narrow RTL layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final action = CreateTransferDraft(
      sourceAccount: _account(id: 'source', name: 'الحساب اليومي'),
      destinationAccount: _account(id: 'target', name: 'حساب الادخار'),
      sourceAmount: Money(
        amount: Decimal.parse('1250.75'),
        currencyCode: 'LYD',
      ),
    );
    final draft = AiActionDraft.create(action: action);
    final validation = const AiActionValidator().validate(action);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: AiActionConfirmationCard(
              draft: draft,
              validation: validation,
              onConfirm: () {},
              onEdit: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تأكيد'), findsOneWidget);
    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid transaction shows compact suggested category in RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final categories = buildDefaultCategories();
    final groceries = categories.firstWhere(
      (category) => category.name == 'Groceries',
    );
    final transactionDraft = AiTransactionDraft(
      type: TransactionType.expense,
      amount: Money(amount: Decimal.fromInt(5), currencyCode: 'LYD'),
      account: _account(id: 'cash', name: 'نقدي'),
      category: groceries,
      paymentMethod: PaymentMethod.cash,
      paymentMethodDefinition: null,
      note: 'حليب',
      itemDescription: 'حليب',
      categorySuggestion: CategorySuggestion(
        categoryId: groceries.id,
        categoryHint: groceries.name,
        confidence: 96,
        source: CategorySuggestionSource.exactAlias,
      ),
    );
    final action = CreateExpenseDraft(transactionDraft);
    final draft = AiActionDraft.create(action: action);
    final validation = const AiActionValidator().validate(action);
    Category? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: AiActionConfirmationCard(
              draft: draft,
              validation: validation,
              onConfirm: () {},
              onEdit: () {},
              onCancel: () {},
              categories: categories,
              onCategoryChanged: (category) => selected = category,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حليب'), findsWidgets);
    expect(find.text('بقالة ومواد غذائية'), findsOneWidget);
    expect(find.textContaining('ثقة عالية'), findsNothing);
    expect(find.byKey(const Key('ai_category_selector')), findsNothing);
    expect(find.byType(CPButton), findsNWidgets(2));
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });
}

Account _account({required String id, required String name}) {
  return Account.create(
    id: id,
    name: name,
    type: AccountType.bank,
    currencyCode: 'LYD',
    balance: Decimal.parse('5000'),
    icon: 'bank',
    color: 0xFF4F46E5,
  );
}
