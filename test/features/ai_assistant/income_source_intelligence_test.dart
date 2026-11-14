import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_structured_action_output.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_draft_factory.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/income_sources/domain/entities/income_source_classification_rule.dart';
import 'package:cashpilot_ai/features/income_sources/domain/entities/income_source_suggestion.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/income_sources/domain/services/income_reporting_policy.dart';
import 'package:cashpilot_ai/features/income_sources/domain/services/income_source_resolver.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/payees/domain/enums/payee_type.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = IncomeSourceResolver();
  const parser = FinancialCommandParser();
  final categories = buildDefaultCategories();
  final cash = _account(id: 'cash', name: 'Cash');
  final bank = _account(id: 'bank', name: 'مصرف الجمهورية');
  final usd = _account(id: 'usd', name: 'حساب الدولار', currencyCode: 'USD');

  group('income source resolver', () {
    final phraseCases = <(String, IncomeSourceType)>[
      ('المرتب نزل', IncomeSourceType.salary),
      ('خديت 500 مقابل شغل حر', IncomeSourceType.freelance),
      ('وصلت مبيعات المشروع', IncomeSourceType.businessRevenue),
      ('وصلتني هدية', IncomeSourceType.gift),
      ('رجعولي فلوسي', IncomeSourceType.refund),
      ('تعويض مصروف', IncomeSourceType.reimbursement),
      ('بعت التلفون', IncomeSourceType.sale),
      ('دخللي إيجار', IncomeSourceType.rentalIncome),
      ('نزلت المنحة', IncomeSourceType.governmentSupport),
      ('منحة دراسية', IncomeSourceType.scholarship),
      ('فزت بجائزة', IncomeSourceType.prize),
      ('وصل القرض', IncomeSourceType.loanProceeds),
      ('salary paid', IncomeSourceType.salary),
      ('freelance payment', IncomeSourceType.freelance),
      ('rent received', IncomeSourceType.rentalIncome),
      ('reimbursement', IncomeSourceType.reimbursement),
    ];

    for (final entry in phraseCases) {
      test('classifies ${entry.$1}', () {
        final suggestion = resolver.resolve(
          input: entry.$1,
          categories: categories,
          accounts: <Account>[cash],
          explicitDestinationAccountId: cash.id,
        );
        expect(suggestion.sourceType, entry.$2);
        expect(suggestion.isInternalTransfer, isFalse);
      });
    }

    test('explicit classification outranks trusted local rule', () {
      final suggestion = resolver.resolve(
        input: 'دفعة من العميل',
        categories: categories,
        explicitSourceType: IncomeSourceType.sale,
        userRules: <IncomeSourceClassificationRule>[
          IncomeSourceClassificationRule(
            normalizedPhrase: 'دفعة من العميل',
            sourceType: IncomeSourceType.businessRevenue,
            confirmedCount: 5,
            lastUsedAt: DateTime.utc(2026),
          ),
        ],
      );

      expect(suggestion.sourceType, IncomeSourceType.sale);
      expect(suggestion.source, IncomeSourceSuggestionSource.explicitUserInput);
    });

    test('trusted rule outranks AI semantic suggestion', () {
      final suggestion = resolver.resolve(
        input: 'دفعة عميل',
        categories: categories,
        userRules: <IncomeSourceClassificationRule>[
          IncomeSourceClassificationRule(
            normalizedPhrase: 'دفعة عميل',
            sourceType: IncomeSourceType.businessRevenue,
            confirmedCount: 2,
            lastUsedAt: DateTime.utc(2026),
          ),
        ],
        aiSourceType: IncomeSourceType.gift,
        aiConfidence: 99,
      );

      expect(suggestion.sourceType, IncomeSourceType.businessRevenue);
      expect(suggestion.source, IncomeSourceSuggestionSource.trustedLocalRule);
    });

    test('employer payee default outranks a generic AI suggestion', () {
      final employer = Payee.create(
        id: 'employer',
        name: 'Hexa',
        type: PayeeType.employer,
      );
      final suggestion = resolver.resolve(
        input: 'وصلتني دفعة',
        categories: categories,
        sourcePayee: employer,
        aiSourceType: IncomeSourceType.gift,
        aiConfidence: 99,
      );

      expect(suggestion.sourceType, IncomeSourceType.salary);
      expect(suggestion.source, IncomeSourceSuggestionSource.payeeDefault);
    });

    test('ambiguous external inflow requires clarification', () {
      final suggestion = resolver.resolve(
        input: 'دخلولي فلوس',
        categories: categories,
      );

      expect(suggestion.sourceType, IncomeSourceType.externalTransfer);
      expect(suggestion.requiresClarification, isTrue);
      expect(suggestion.alternatives, isNotEmpty);
    });

    for (final wording in <String>[
      'my friend gave me 1000 LYD',
      'صاحبي عطاني 300',
    ]) {
      test('generic giving wording remains unclassified: $wording', () {
        final suggestion = resolver.resolve(
          input: wording,
          categories: categories,
        );

        expect(suggestion.sourceType, IncomeSourceType.other);
        expect(suggestion.source, IncomeSourceSuggestionSource.fallback);
        expect(suggestion.requiresClarification, isTrue);
      });
    }

    for (final wording in <String>[
      'my friend gave me 150 LYD because today is my birthday',
      'صاحبي عطاني 150 دينار بمناسبة عيد ميلادي',
    ]) {
      test('explicit birthday context is classified as a gift: $wording', () {
        final suggestion = resolver.resolve(
          input: wording,
          categories: categories,
          explicitDestinationAccountId: cash.id,
        );

        expect(suggestion.sourceType, IncomeSourceType.gift);
        expect(suggestion.source, IncomeSourceSuggestionSource.exactPhrase);
        expect(suggestion.requiresClarification, isFalse);
      });
    }

    for (final wording in <String>[
      'debt repayment from my friend',
      'رجعلي ديني صاحبي',
    ]) {
      test('explicit debt repayment wording is classified: $wording', () {
        final suggestion = resolver.resolve(
          input: wording,
          categories: categories,
          explicitDestinationAccountId: cash.id,
        );

        expect(suggestion.sourceType, IncomeSourceType.debtRepayment);
        expect(suggestion.source, IncomeSourceSuggestionSource.exactPhrase);
        expect(suggestion.requiresClarification, isFalse);
      });
    }

    test('internal account transfer is never income', () {
      final suggestion = resolver.resolve(
        input: 'حولت 1000 من الكاش للمصرف',
        categories: categories,
      );

      expect(suggestion.isInternalTransfer, isTrue);
      expect(suggestion.isNormalEarnedIncome, isFalse);
      expect(suggestion.requiresClarification, isTrue);
    });
  });

  group('local income command parsing', () {
    test('salary resolves the named destination bank and today', () {
      final result = parser.parse(
        input: 'المرتب اليوم نزل 1000 في مصرف الجمهورية',
        accounts: <Account>[cash, bank],
        categories: categories,
        baseCurrencyCode: 'LYD',
        paymentMethodClarificationMessage: 'Which account?',
      );

      expect(
        result,
        isA<AiTransactionDraft>(),
        reason: result is AiTransactionClarification ? result.message : null,
      );
      final draft = result as AiTransactionDraft;
      expect(draft.type, TransactionType.income);
      expect(draft.account.id, bank.id);
      expect(draft.category, isNull);
      expect(draft.categorySuggestion?.categoryHint, 'Salary');
      expect(draft.incomeSourceSuggestion?.sourceType, IncomeSourceType.salary);
      expect(draft.transactionDate, isNotNull);
    });

    test(
      'gift from a person resolves to cash and the income Gift category',
      () {
        final salem = Payee.create(
          id: 'salem',
          name: 'سالم',
          type: PayeeType.person,
        );
        final result = parser.parse(
          input: 'وصلتني هدية 300 من سالم كاش',
          accounts: <Account>[cash],
          categories: categories,
          payees: <Payee>[salem],
          baseCurrencyCode: 'LYD',
          paymentMethodClarificationMessage: 'Which account?',
        );

        final draft = result as AiTransactionDraft;
        expect(draft.account.id, cash.id);
        expect(draft.payee?.id, salem.id);
        expect(draft.category, isNull);
        expect(draft.categorySuggestion?.categoryHint, 'Gift');
        expect(draft.incomeSourceSuggestion?.sourceType, IncomeSourceType.gift);
      },
    );

    test(
      'birthday inflow keeps missing account explicit and suggests Gift',
      () {
        final result = parser.parse(
          input:
              'my friend gave me 150 LYD because today is my birthday income',
          accounts: <Account>[cash],
          categories: categories,
          baseCurrencyCode: 'LYD',
          paymentMethodClarificationMessage: 'Which account?',
        );

        expect(result, isA<AiTransactionDraft>());
        final draft = result as AiTransactionDraft;
        expect(draft.type, TransactionType.income);
        expect(draft.account.id, AiTransactionDraft.unresolvedAccountId);
        expect(draft.incomeSourceSuggestion?.sourceType, IncomeSourceType.gift);
        expect(
          draft.incomeSourceSuggestion?.source,
          IncomeSourceSuggestionSource.exactPhrase,
        );
        expect(draft.incomeSourceSuggestion?.sourceNameHint, 'my friend');
        expect(draft.category, isNull);
        expect(draft.categorySuggestion?.categoryHint, 'Gift');
        expect(draft.transactionDate, isNotNull);
      },
    );

    test('freelance payment uses the explicit USD account currency', () {
      final result = parser.parse(
        input: 'خديت 500 مقابل شغل حر في حساب الدولار',
        accounts: <Account>[cash, usd],
        categories: categories,
        baseCurrencyCode: 'LYD',
        paymentMethodClarificationMessage: 'Which account?',
      );

      final draft = result as AiTransactionDraft;
      expect(draft.account.id, usd.id);
      expect(draft.amount.currencyCode, 'USD');
      expect(draft.category, isNull);
      expect(draft.categorySuggestion?.categoryHint, 'Freelance');
    });

    final categoryCases = <(String, String, IncomeSourceType)>[
      (
        'دخل مشروع 600 في Cash',
        'Business Revenue',
        IncomeSourceType.businessRevenue,
      ),
      (
        'دخللي إيجار 800 في Cash',
        'Rental Income',
        IncomeSourceType.rentalIncome,
      ),
      (
        'نزلت المنحة 400 في Cash',
        'Government Support',
        IncomeSourceType.governmentSupport,
      ),
      (
        'وصلت منحة دراسية 300 في Cash',
        'Scholarship',
        IncomeSourceType.scholarship,
      ),
      ('رجعولي 50 قيمة طلب ملغي في Cash', 'Refund', IncomeSourceType.refund),
      (
        'وصل تعويض مصروف 60 في Cash',
        'Reimbursement',
        IncomeSourceType.reimbursement,
      ),
      (
        'بعت التلفون بـ700 واستلمتهم Cash',
        'Sale Proceeds',
        IncomeSourceType.sale,
      ),
      (
        'وصلني قرض 5000 في Cash',
        'Loan Proceeds',
        IncomeSourceType.loanProceeds,
      ),
    ];

    for (final entry in categoryCases) {
      test('maps ${entry.$3.storageValue} to ${entry.$2}', () {
        final result = parser.parse(
          input: entry.$1,
          accounts: <Account>[cash],
          categories: categories,
          baseCurrencyCode: 'LYD',
          paymentMethodClarificationMessage: 'Which account?',
        );

        final draft = result as AiTransactionDraft;
        expect(draft.category, isNull);
        expect(draft.categorySuggestion?.categoryHint, entry.$2);
        expect(draft.incomeSourceSuggestion?.sourceType, entry.$3);
      });
    }

    test('multiple unnamed accounts require clarification', () {
      final result = parser.parse(
        input: 'وصلني مرتب 1000',
        accounts: <Account>[cash, bank],
        categories: categories,
        baseCurrencyCode: 'LYD',
        paymentMethodClarificationMessage: 'Which account?',
      );

      expect(result, isA<AiTransactionDraft>());
      expect(
        (result as AiTransactionDraft).account.id,
        AiTransactionDraft.unresolvedAccountId,
      );
    });
  });

  group('structured income contract', () {
    test('rejects unsupported income source enums', () {
      const json =
          '{"intent":"create_income","amount":"100","requiresConfirmation":true,"incomeSourceType":"magic_money"}';
      expect(AiStructuredActionOutput.tryParse(json), isNull);
    });

    test('salary from an employer resolves source and destination', () {
      final employer = Payee.create(
        id: 'hexa',
        name: 'شركة هيكسا',
        type: PayeeType.employer,
      );
      const json =
          '{"intent":"create_income","amount":"1000","currency":"LYD","description":"salary","categoryHint":"Salary","destinationAccountHint":"مصرف الجمهورية","incomeSourceType":"salary","incomeSourcePayeeHint":"شركة هيكسا","dateText":"today","requiresConfirmation":true}';
      final output = AiStructuredActionOutput.tryParse(json)!;
      final action = const AiActionDraftFactory().fromStructuredOutput(
        output: output,
        originalInput: 'وصلني مرتب 1000 من شركة هيكسا في مصرف الجمهورية',
        accounts: <Account>[cash, bank],
        categories: categories,
        payees: <Payee>[employer],
        baseCurrencyCode: 'LYD',
        accountClarificationMessage: 'Which account?',
      );

      expect(action, isA<CreateIncomeDraft>());
      final draft = (action as CreateIncomeDraft).transactionDraft;
      expect(draft.account.id, bank.id);
      expect(draft.payee?.id, employer.id);
      expect(draft.incomeSourceSuggestion?.sourceType, IncomeSourceType.salary);
      expect(action.requiresConfirmation, isTrue);
    });

    test('structured internal transfer cannot become income', () {
      const json =
          '{"intent":"create_income","amount":"1000","destinationAccountHint":"مصرف الجمهورية","incomeSourceType":"external_transfer","isInternalTransfer":true,"requiresConfirmation":true}';
      final action = const AiActionDraftFactory().fromStructuredOutput(
        output: AiStructuredActionOutput.tryParse(json)!,
        originalInput: 'حولت 1000 من الكاش للمصرف',
        accounts: <Account>[cash, bank],
        categories: categories,
        baseCurrencyCode: 'LYD',
        accountClarificationMessage: 'Which account?',
      );

      expect(action, isA<ClarificationRequiredAction>());
      expect(action, isNot(isA<CreateIncomeDraft>()));
    });
  });

  group('income reporting semantics', () {
    test(
      'loan proceeds and internal transfers are excluded from normal income',
      () {
        final salary = _transaction(
          type: TransactionType.income,
          incomeSourceType: IncomeSourceType.salary,
        );
        final loan = _transaction(
          type: TransactionType.income,
          incomeSourceType: IncomeSourceType.loanProceeds,
        );
        final transfer = _transaction(type: TransactionType.transferIn);

        expect(IncomeReportingPolicy.isNormalIncome(salary), isTrue);
        expect(IncomeReportingPolicy.isEarnedIncome(salary), isTrue);
        expect(IncomeReportingPolicy.isNormalIncome(loan), isFalse);
        expect(IncomeReportingPolicy.isNormalIncome(transfer), isFalse);
      },
    );

    test('refund and reimbursement remain identifiable', () {
      final refund = _transaction(
        type: TransactionType.income,
        incomeSourceType: IncomeSourceType.refund,
      );
      final reimbursement = _transaction(
        type: TransactionType.income,
        incomeSourceType: IncomeSourceType.reimbursement,
      );

      expect(IncomeReportingPolicy.isRefundOrReimbursement(refund), isTrue);
      expect(
        IncomeReportingPolicy.isRefundOrReimbursement(reimbursement),
        isTrue,
      );
      expect(IncomeReportingPolicy.isEarnedIncome(refund), isFalse);
    });
  });
}

Account _account({
  required String id,
  required String name,
  String currencyCode = 'LYD',
}) {
  return Account.create(
    id: id,
    name: name,
    type: name == 'Cash' ? AccountType.cash : AccountType.bank,
    currencyCode: currencyCode,
    balance: Decimal.zero,
    icon: 'wallet',
    color: 0xFF000000,
  );
}

Transaction _transaction({
  required TransactionType type,
  IncomeSourceType? incomeSourceType,
}) {
  return Transaction.create(
    accountId: 'account',
    categoryId: 'category',
    amount: Money(amount: Decimal.one, currencyCode: 'LYD'),
    type: type,
    incomeSourceType: incomeSourceType,
  );
}
