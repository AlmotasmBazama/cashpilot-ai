import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FinancialCommandParser();
  const clarification = 'Which payment method did you use?';

  test('parses Arabic grocery expense in LYD', () {
    final draft =
        parser.parse(
              input: 'اشتريت حليب بـ5 دنانير ودفعت عن طريق ادفع لي',
              accounts: [
                account(
                  id: 'tdb',
                  name: 'Trade & Development Bank Account',
                  paymentMethodIds: ['edfaly'],
                ),
              ],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;

    expect(draft.type, TransactionType.expense);
    expect(draft.amount.amount, Decimal.parse('5'));
    expect(draft.amount.currencyCode, 'LYD');
    expect(draft.paymentMethod, PaymentMethod.edfaly);
    expect(draft.account.id, 'tdb');
    expect(draft.category?.name, 'Groceries');
  });

  test('parses Arabic fuel expense', () {
    final draft =
        parser.parse(
              input: 'اشتريت بنزين بـ80 من موبي كاش',
              accounts: [
                account(
                  id: 'wahda',
                  name: 'Wahda Bank',
                  paymentMethodIds: ['mobi_cash'],
                ),
              ],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;

    expect(draft.type, TransactionType.expense);
    expect(draft.amount.amount, Decimal.parse('80'));
    expect(draft.amount.currencyCode, 'LYD');
    expect(draft.paymentMethod, PaymentMethod.mobiCash);
    expect(draft.category?.name, 'Fuel');
  });

  test('parses Arabic salary income', () {
    final draft =
        parser.parse(
              input: 'استلمت راتب 3200',
              accounts: [account(id: 'salary')],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;

    expect(draft.type, TransactionType.income);
    expect(draft.amount.amount, Decimal.parse('3200'));
    expect(draft.amount.currencyCode, 'LYD');
    expect(draft.category, isNull);
    expect(draft.categorySuggestion?.categoryHint, 'Salary');
    expect(draft.account.id, AiTransactionDraft.unresolvedAccountId);
  });

  test('the Arabic expense noun never classifies a draft as income', () {
    final draft =
        parser.parse(
              input: 'سجل مصروف 25 دينار',
              accounts: [account(id: 'cash')],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;

    expect(draft.type, TransactionType.expense);
    expect(draft.amount.amount, Decimal.parse('25'));
  });

  group('exact localized amount parsing', () {
    final validCases = <({String input, String expected})>[
      (input: 'دفعت ١٢٫٥٠ دينار', expected: '12.50'),
      (input: 'دفعت ۱۲٫۵۰ دينار', expected: '12.50'),
      (input: 'دفعت ١٬٢٣٤٫٥٠ دينار', expected: '1234.50'),
      (input: 'دفعت 1,234.50 دينار', expected: '1234.50'),
      (input: 'دفعت 25,50 دينار', expected: '25.50'),
      (input: 'دفعت خمسة وعشرين دينار', expected: '25'),
      (input: 'دفعت مئتين وخمسة وثلاثين دينار', expected: '235'),
      (input: 'شريت حليب بخمسة ونص', expected: '5.5'),
      (input: 'دفعت دينار ونص', expected: '1.5'),
      (input: 'دفعت ربع دينار', expected: '0.25'),
      (input: 'دفعت ٥٠٫٥٠٠ كاش', expected: '50.500'),
    ];

    for (final testCase in validCases) {
      test('parses ${testCase.input} without binary floating point', () {
        final result = parser.parse(
          input: testCase.input,
          accounts: [account(id: 'only')],
          categories: buildDefaultCategories(),
          baseCurrencyCode: 'LYD',
          paymentMethodClarificationMessage: clarification,
        );

        expect(result, isA<AiTransactionDraft>());
        final draft = result as AiTransactionDraft;
        expect(draft.amount.amount, Decimal.parse(testCase.expected));
      });
    }

    final rejectedCases = <String>[
      'دفعت 1e3 دينار',
      'دفعت 12,34,567 دينار',
      'دفعت 1.2345 دينار',
      'دفعت 25 دينار ثم 30 دينار',
    ];

    for (final input in rejectedCases) {
      test('rejects ambiguous or malformed amount in $input', () {
        final result = parser.parse(
          input: input,
          accounts: [account(id: 'only')],
          categories: buildDefaultCategories(),
          baseCurrencyCode: 'LYD',
          paymentMethodClarificationMessage: clarification,
        );

        expect(result, isA<AiTransactionParseFailure>());
        expect(
          (result as AiTransactionParseFailure).message,
          'I could not find a valid amount.',
        );
      });
    }
  });

  test('parses Libyan payment method aliases', () {
    final cases = [
      (
        input: 'دفعت 10 عن طريق ادفع لي',
        accountId: 'tdb',
        methodId: 'edfaly',
        paymentMethod: PaymentMethod.edfaly,
      ),
      (
        input: 'دفعت 30 عن طريق مصرفي',
        accountId: 'jumhouria',
        methodId: 'masrafi_pay',
        paymentMethod: PaymentMethod.masrafiPay,
      ),
      (
        input: 'دفعت 25 من موبي كاش',
        accountId: 'wahda',
        methodId: 'mobi_cash',
        paymentMethod: PaymentMethod.mobiCash,
      ),
      (
        input: 'دفعت 15 عن طريق يسر',
        accountId: 'cnb',
        methodId: 'yusr_pay',
        paymentMethod: PaymentMethod.yusrPay,
      ),
      (
        input: 'دفعت 12 عن طريق OnePay',
        accountId: 'one-pay',
        methodId: 'onepay',
        paymentMethod: PaymentMethod.digitalWallet,
      ),
      (
        input: 'دفعت 20 في نقطة بيع',
        accountId: 'pos',
        methodId: 'pos',
        paymentMethod: PaymentMethod.debitCard,
      ),
    ];

    for (final entry in cases) {
      final draft =
          parser.parse(
                input: entry.input,
                accounts: [
                  account(
                    id: entry.accountId,
                    paymentMethodIds: [entry.methodId],
                  ),
                ],
                categories: buildDefaultCategories(),
                baseCurrencyCode: 'LYD',
                paymentMethodClarificationMessage: clarification,
              )
              as AiTransactionDraft;

      expect(draft.paymentMethod, entry.paymentMethod);
      expect(draft.account.id, entry.accountId);
    }
  });

  test('resolves shortened Libyan bank names against canonical accounts', () {
    final draft =
        parser.parse(
              input: 'دفعت فاتورة النت 80 من الجمهورية',
              accounts: [
                account(id: 'cash', name: 'محفظة كاش'),
                account(id: 'jumhouria', name: 'مصرف الجمهورية'),
              ],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;

    expect(draft.account.id, 'jumhouria');
    expect(draft.amount.amount, Decimal.parse('80'));
  });

  test('maps yesterday in Libyan Arabic to the previous local date', () {
    final before = DateTime.now();
    final draft =
        parser.parse(
              input: 'امبارح شريت دواء بـ 25',
              accounts: [account(id: 'cash')],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;
    final expected = DateTime(
      before.year,
      before.month,
      before.day,
    ).subtract(const Duration(days: 1)).toUtc();

    expect(draft.transactionDate, expected);
  });

  test('recognizes non-LYD currency aliases', () {
    final usd =
        parser.parse(
              input: 'دفعت 100 دولار',
              accounts: [account(id: 'cash')],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;
    final eur =
        parser.parse(
              input: 'دفعت 50 يورو',
              accounts: [account(id: 'cash')],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;

    expect(usd.amount.currencyCode, 'USD');
    expect(eur.amount.currencyCode, 'EUR');
  });

  test('does not turn transfer wording into an expense draft', () {
    final result = parser.parse(
      input: 'حول 200 من حسابي بالدولار',
      accounts: [account(id: 'usd', currencyCode: 'USD')],
      categories: buildDefaultCategories(),
      baseCurrencyCode: 'LYD',
      paymentMethodClarificationMessage: clarification,
    );

    expect(result, isA<AiTransactionParseFailure>());
    expect(
      (result as AiTransactionParseFailure).message,
      contains('transfer workspace'),
    );
  });

  test('does not turn a cash withdrawal into an expense draft', () {
    final result = parser.parse(
      input: 'سحبت 200 من حسابي',
      accounts: [account(id: 'bank')],
      categories: buildDefaultCategories(),
      baseCurrencyCode: 'LYD',
      paymentMethodClarificationMessage: clarification,
    );

    expect(result, isA<AiTransactionParseFailure>());
    expect(
      (result as AiTransactionParseFailure).message,
      contains('transfer workspace'),
    );
  });

  test(
    'asks for payment method when multiple accounts need disambiguation',
    () {
      final result = parser.parse(
        input: 'اشتريت حليب بـ5 دنانير',
        accounts: [
          account(id: 'cash'),
          account(id: 'bank'),
        ],
        categories: buildDefaultCategories(),
        baseCurrencyCode: 'LYD',
        paymentMethodClarificationMessage: clarification,
      );

      expect(result, isA<AiTransactionClarification>());
      expect((result as AiTransactionClarification).message, clarification);
    },
  );

  test('uses the only account automatically when no method is mentioned', () {
    final draft =
        parser.parse(
              input: 'اشتريت حليب بـ5 دنانير',
              accounts: [account(id: 'only')],
              categories: buildDefaultCategories(),
              baseCurrencyCode: 'LYD',
              paymentMethodClarificationMessage: clarification,
            )
            as AiTransactionDraft;

    expect(draft.account.id, 'only');
    expect(draft.paymentMethod, PaymentMethod.other);
  });
}

Account account({
  required String id,
  String name = 'Cash',
  String currencyCode = 'LYD',
  List<String> paymentMethodIds = const <String>[],
}) {
  return Account.create(
    id: id,
    name: name,
    type: AccountType.bank,
    currencyCode: currencyCode,
    balance: Decimal.zero,
    icon: 'bank',
    color: 0xFF4F46E5,
    paymentMethodIds: paymentMethodIds,
  );
}
