import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_intent.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_understanding_result.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_context_builder.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_draft_factory.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/create_ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/understand_ai_message.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = AiIntentRouter();

  group('declarative financial draft proposals', () {
    final cases = <(String, AiIntent)>[
      ('my friend sent me 1000 LYD', AiIntent.createIncome),
      ('my friend send to me 1000 lyd', AiIntent.createIncome),
      ('I received 500 dinars', AiIntent.createIncome),
      ('وصلني ألف دينار', AiIntent.createIncome),
      ('صاحبي عطاني 300', AiIntent.createIncome),
      ('I bought milk for 5 LYD', AiIntent.createExpense),
      ('دفعت 25 دينار', AiIntent.createExpense),
      ('milk 5 dinar', AiIntent.createExpense),
      ('حليب 5 دينار', AiIntent.createExpense),
      ('coffee 10 LYD', AiIntent.createExpense),
      ('bread 2 dinar', AiIntent.createExpense),
      ('خبز بدينارين', AiIntent.createExpense),
      ('دفعت 20 قهوة', AiIntent.createExpense),
      ('دفعت 20 مواصلات', AiIntent.createExpense),
      ('fuel 30 lyd', AiIntent.createExpense),
    ];

    for (final entry in cases) {
      test('routes "${entry.$1}" straight to governed draft creation', () {
        final route = router.route(entry.$1);

        expect(route.target, AssistantRouteTarget.financialAction);
        expect(route.intent, entry.$2);
        expect(route.isFinancialRecordOffer, isFalse);
        expect(route.isExplicitMutationRequest, isFalse);
        expect(route.useFinancialPipeline, isTrue);
        expect(route.isDeterministic, isTrue);
        expect(route.recordOfferDecision, FinancialRecordOfferDecision.none);
      });
    }

    test('a bare amount does not silently become an expense', () {
      final route = router.route('1000 LYD');

      expect(route.target, AssistantRouteTarget.financialRecordOffer);
      expect(route.intent, AiIntent.unknown);
      expect(route.isExplicitMutationRequest, isFalse);
    });

    test('bounded item proposals select the local financial parser', () {
      for (final input in <String>[
        'milk 5 dinar',
        'coffee 10 LYD',
        'bread 2 dinar',
        'حليب 5 دينار',
        'خبز بدينارين',
        'شريت حليب بـ 5',
        'دفعت 20 قهوة',
        'دفعت 20 مواصلات',
        'fuel 30 lyd',
      ]) {
        expect(
          router.route(input).useLocalFinancialParser,
          isTrue,
          reason: input,
        );
      }
      expect(router.route('Paid New Shop 10').useLocalFinancialParser, isFalse);
    });
  });

  group('explicit mutation commands', () {
    final cases = <(String, AiIntent)>[
      ('record this income', AiIntent.createIncome),
      ('record my friend sent me 1000 LYD as income', AiIntent.createIncome),
      ('log this income', AiIntent.createIncome),
      ('سجل هذا الدخل', AiIntent.createIncome),
      ('سجّلها كدخل', AiIntent.createIncome),
      ('ضيفها كدخل', AiIntent.createIncome),
      ('record a 5 LYD expense', AiIntent.createExpense),
      ('سجل مصروف 25 دينار', AiIntent.createExpense),
    ];

    for (final entry in cases) {
      test('routes "${entry.$1}" to draft creation', () {
        final route = router.route(entry.$1);

        expect(route.target, AssistantRouteTarget.financialAction);
        expect(route.intent, entry.$2);
        expect(route.isExplicitMutationRequest, isTrue);
        expect(route.useFinancialPipeline, isTrue);
      });
    }
  });

  group('record-offer decisions', () {
    test('recognizes English, Arabic, and Libyan affirmative responses', () {
      for (final input in <String>[
        'yes',
        'yes please, record it',
        'sure',
        'okay, use Cash',
        'record it',
        'نعم',
        'إيه',
        'أيوه سجلها',
        'تمام، سجلها',
        'سجلها',
      ]) {
        expect(
          router.recordOfferDecisionFor(input),
          FinancialRecordOfferDecision.accept,
          reason: input,
        );
        expect(router.isAffirmativeRecordOfferResponse(input), isTrue);
      }
    });

    test('recognizes English, Arabic, and Libyan negative responses', () {
      for (final input in <String>[
        'no',
        'no thanks',
        "don't record it",
        'cancel',
        'not now',
        'لا',
        'لا تسجلها',
        'ماتسجلهاش',
        'مش توا',
      ]) {
        expect(
          router.recordOfferDecisionFor(input),
          FinancialRecordOfferDecision.decline,
          reason: input,
        );
        expect(router.isNegativeRecordOfferResponse(input), isTrue);
      }
    });

    test('does not mistake ordinary account wording for a decline', () {
      expect(
        router.recordOfferDecisionFor('no account yet'),
        FinancialRecordOfferDecision.none,
      );
    });
  });

  group('understanding continuation', () {
    test(
      'milk proposal builds a complete typed draft without a provider',
      () async {
        final repository = _ProviderMustNotBeCalled();
        final result = await _understander(repository)(
          input: 'milk 5 dinar',
          accounts: <Account>[_cashAccount()],
          categories: buildDefaultCategories(),
          baseCurrencyCode: 'LYD',
          locale: 'en',
          accountClarificationMessage: 'Which account?',
        );

        final understanding =
            _success(result) as AiFinancialActionUnderstanding;
        final action = understanding.draft.action as CreateExpenseDraft;
        expect(action.transactionDraft.amount.amount, Decimal.fromInt(5));
        expect(action.transactionDraft.category?.name, 'Groceries');
        expect(action.transactionDraft.account.name, 'Cash');
        expect(repository.sendCalls, 0);
      },
    );

    test('clear declarative income builds a local draft directly', () async {
      final repository = _ProviderMustNotBeCalled();
      final result = await _understander(repository)(
        input: 'my friend sent me 1000 LYD as a gift to Cash today',
        accounts: <Account>[_cashAccount()],
        categories: buildDefaultCategories(),
        baseCurrencyCode: 'LYD',
        locale: 'en',
        accountClarificationMessage: 'Which account?',
      );

      final understanding = _success(result);
      expect(understanding, isA<AiFinancialActionUnderstanding>());
      final action =
          (understanding as AiFinancialActionUnderstanding).draft.action;
      expect(action, isA<CreateIncomeDraft>());
      expect(understanding.requiresConfirmation, isTrue);
      expect(repository.sendCalls, 0);
    });

    test(
      'accepted offer parses locally and preserves source and note',
      () async {
        const input = 'My friend sent me 1000 LYD as a gift to Cash';
        final repository = _ProviderMustNotBeCalled();
        final result = await _understander(repository)(
          input: input,
          accounts: <Account>[_cashAccount()],
          categories: buildDefaultCategories(),
          baseCurrencyCode: 'LYD',
          locale: 'en',
          accountClarificationMessage: 'Which account?',
          explicitlyConfirmedMutation: true,
        );

        final understanding = _success(result);
        expect(understanding, isA<AiFinancialActionUnderstanding>());
        final action =
            (understanding as AiFinancialActionUnderstanding).draft.action;
        expect(action, isA<CreateIncomeDraft>());
        final draft = (action as CreateIncomeDraft).transactionDraft;
        expect(draft.type, TransactionType.income);
        expect(draft.note, input);
        expect(draft.incomeSourceSuggestion?.sourceNameHint, 'My friend');
        expect(draft.account.id, 'cash');
        expect(understanding.requiresConfirmation, isTrue);
        expect(repository.sendCalls, 0);
      },
    );

    test('bare consent maps to intent consent, not execution confirmation', () {
      final understanding = _understander(
        _ProviderMustNotBeCalled(),
      ).understandLocally('نعم');

      expect(understanding, isA<AiFinancialRecordDecisionUnderstanding>());
      final decision = understanding as AiFinancialRecordDecisionUnderstanding;
      expect(decision.decision, FinancialRecordOfferDecision.accept);
      expect(decision.requiresConfirmation, isFalse);
    });
  });
}

UnderstandAiMessage _understander(AiRepository repository) {
  return UnderstandAiMessage(
    createActionDraft: CreateAiActionDraft(
      aiRepository: repository,
      parser: const FinancialCommandParser(),
      draftFactory: const AiActionDraftFactory(),
      contextBuilder: const AiActionContextBuilder(),
    ),
  );
}

Account _cashAccount() {
  return Account.create(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    currencyCode: 'LYD',
    balance: Decimal.zero,
    icon: 'cash',
    color: 0xFF4F46E5,
  );
}

class _ProviderMustNotBeCalled implements AiRepository {
  int sendCalls = 0;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async {
    return const AppResult.success(<AiModel>[]);
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    sendCalls += 1;
    throw StateError(
      'The provider must not be called for deterministic offers.',
    );
  }
}

T _success<T>(AppResult<T> result) {
  return switch (result) {
    AppSuccess<T>(:final data) => data,
    AppFailure<T>(:final failure) => fail(
      'Expected success but received ${failure.code ?? 'unknown'}.',
    ),
  };
}
