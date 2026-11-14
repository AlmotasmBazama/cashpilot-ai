import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FinancialCommandParser();

  for (final scenario in <({String input, String amount, String category})>[
    (input: 'milk 5 dinar', amount: '5', category: 'Groceries'),
    (input: 'coffee 3 LYD', amount: '3', category: 'Coffee'),
    (input: 'bread 2 dinar', amount: '2', category: 'Groceries'),
    (input: 'حليب 5 دينار', amount: '5', category: 'Groceries'),
    (input: 'خبز بدينارين', amount: '2', category: 'Groceries'),
    (input: 'شريت حليب بـ 5', amount: '5', category: 'Groceries'),
    (input: 'دفعت 20 مواصلات', amount: '20', category: 'Transport'),
  ]) {
    test('parses "${scenario.input}" as a complete local expense draft', () {
      final result = parser.parse(
        input: scenario.input,
        accounts: <Account>[_cashAccount()],
        categories: buildDefaultCategories(),
        baseCurrencyCode: 'LYD',
        paymentMethodClarificationMessage: 'Which account?',
      );

      expect(result, isA<AiTransactionDraft>());
      final draft = result as AiTransactionDraft;
      expect(draft.amount.amount, Decimal.parse(scenario.amount));
      expect(draft.amount.amount.toStringAsFixed(3), '${scenario.amount}.000');
      expect(draft.amount.currencyCode, 'LYD');
      expect(draft.account.id, 'cash');
      expect(draft.category?.name, scenario.category);
      expect(draft.itemDescription, isNotEmpty);
      expect(draft.transactionDate, isNotNull);
    });
  }

  test('never invents an account when none exists', () {
    final result = parser.parse(
      input: 'milk 5 dinar',
      accounts: const <Account>[],
      categories: buildDefaultCategories(),
      baseCurrencyCode: 'LYD',
      paymentMethodClarificationMessage: 'Which account?',
      expenseAccountClarificationMessage:
          'Which account should this expense use?',
    );

    expect(result, isA<AiTransactionClarification>());
    expect(
      (result as AiTransactionClarification).message,
      'Which account should this expense use?',
    );
  });

  test('asks which account when more than one is plausible', () {
    final result = parser.parse(
      input: 'milk 5 dinar',
      accounts: <Account>[
        _cashAccount(),
        _cashAccount(id: 'wallet', name: 'Wallet'),
      ],
      categories: buildDefaultCategories(),
      baseCurrencyCode: 'LYD',
      paymentMethodClarificationMessage: 'Which account?',
      expenseAccountClarificationMessage:
          'Which account should this expense use?',
    );

    expect(result, isA<AiTransactionClarification>());
    expect(
      (result as AiTransactionClarification).message,
      'Which account should this expense use?',
    );
  });

  test('does not select an archived account as the only default', () {
    final result = parser.parse(
      input: 'milk 5 dinar',
      accounts: <Account>[_cashAccount().copyWith(isArchived: true)],
      categories: buildDefaultCategories(),
      baseCurrencyCode: 'LYD',
      paymentMethodClarificationMessage: 'Which account?',
      expenseAccountClarificationMessage:
          'Which account should this expense use?',
    );

    expect(result, isA<AiTransactionClarification>());
  });

  test('missing amount blocks transaction draft creation', () {
    final result = parser.parse(
      input: 'milk',
      accounts: <Account>[_cashAccount()],
      categories: buildDefaultCategories(),
      baseCurrencyCode: 'LYD',
      paymentMethodClarificationMessage: 'Which account?',
    );

    expect(result, isA<AiTransactionParseFailure>());
  });

  test('normalizes Milk and resolves today in Africa/Tripoli', () {
    final result =
        FinancialCommandParser(
          clock: () => DateTime.utc(2026, 8, 23, 22, 30),
        ).parse(
          input: 'milk 5 dinar',
          accounts: <Account>[_cashAccount()],
          categories: buildDefaultCategories(),
          baseCurrencyCode: 'LYD',
          paymentMethodClarificationMessage: 'Which account?',
        );

    final draft = result as AiTransactionDraft;
    expect(draft.itemDescription, 'Milk');
    expect(draft.transactionDate, DateTime.utc(2026, 8, 23, 22));
  });
}

Account _cashAccount({String id = 'cash', String name = 'Cash'}) {
  return Account.create(
    id: id,
    name: name,
    type: AccountType.cash,
    currencyCode: 'LYD',
    balance: Decimal.fromInt(100),
    icon: 'cash',
    color: 0xFF4F46E5,
  );
}
