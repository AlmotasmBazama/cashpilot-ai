import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_support.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/tool_relevance_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_validation_result.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_intent.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_validator.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = AiIntentRouter();

  group('canonical assistant pre-route', () {
    final cases = <(String, AssistantRouteTarget, AiIntent)>[
      ('مرحبا', AssistantRouteTarget.directConversation, AiIntent.greeting),
      (
        'ما هو التضخم؟',
        AssistantRouteTarget.generalConversation,
        AiIntent.unknown,
      ),
      (
        'كيف وضع الاقتصاد الليبي حالياً؟',
        AssistantRouteTarget.groundedCurrentKnowledge,
        AiIntent.unknown,
      ),
      (
        'حصلت هدية بخمسين دينار',
        AssistantRouteTarget.financialAction,
        AiIntent.createIncome,
      ),
      (
        'ليش مصروفي زايد هذا الشهر؟',
        AssistantRouteTarget.personalFinancialAnalysis,
        AiIntent.askFinancialQuestion,
      ),
      (
        'شن رصيد حساب الكاش؟',
        AssistantRouteTarget.personalFinancialAnalysis,
        AiIntent.askFinancialQuestion,
      ),
      (
        'والشهر اللي فات؟',
        AssistantRouteTarget.personalFinancialAnalysis,
        AiIntent.askFinancialQuestion,
      ),
      (
        'Compare that with the previous month.',
        AssistantRouteTarget.personalFinancialAnalysis,
        AiIntent.askFinancialQuestion,
      ),
      (
        'ديرلي ميزانية مطاعم بـ300',
        AssistantRouteTarget.financialAction,
        AiIntent.createBudget,
      ),
    ];

    for (final entry in cases) {
      test('routes "${entry.$1}" exactly once', () {
        final route = router.route(entry.$1);
        expect(route.target, entry.$2);
        expect(route.intent, entry.$3);
      });
    }
  });

  test('generic financial concepts never open the personal data pipeline', () {
    for (final message in <String>[
      'What is cash flow?',
      'Explain how budgets work.',
      'What is a savings rate?',
      'اشرح لي الفرق بين الدخل والمصروف في جملتين',
    ]) {
      final route = router.route(message);
      expect(
        route.target,
        AssistantRouteTarget.generalConversation,
        reason: message,
      );
      expect(route.useFinancialPipeline, isFalse, reason: message);
    }

    for (final message in <String>[
      'Analyze my cash flow this month.',
      'How much did I spend this month?',
    ]) {
      final route = router.route(message);
      expect(
        route.target,
        AssistantRouteTarget.personalFinancialAnalysis,
        reason: message,
      );
      expect(route.useFinancialPipeline, isTrue, reason: message);
    }
  });

  test('ordinal choices re-enter only an active financial clarification', () {
    final ordinary = router.route('1');
    final clarification = router.route(
      '1',
      awaitingFinancialClarification: true,
    );

    expect(ordinary.target, isNot(AssistantRouteTarget.financialAction));
    expect(clarification.target, AssistantRouteTarget.financialAction);
    expect(clarification.intent, AiIntent.clarificationResponse);
    expect(clarification.useFinancialPipeline, isTrue);
  });

  test('gift income is a review-only draft with unresolved destination', () {
    final result = const FinancialCommandParser().parse(
      input: 'حصلت هدية بخمسين دينار',
      accounts: <Account>[_account('cash', 'Cash'), _account('bank', 'Bank')],
      categories: buildDefaultCategories(),
      baseCurrencyCode: 'LYD',
      paymentMethodClarificationMessage: 'Which account?',
    );

    expect(result, isA<AiTransactionDraft>());
    final draft = result as AiTransactionDraft;
    expect(draft.type, TransactionType.income);
    expect(draft.amount.amount, Decimal.fromInt(50));
    expect(draft.amount.currencyCode, 'LYD');
    expect(draft.category, isNull);
    expect(draft.categorySuggestion?.categoryHint, 'Gift');
    expect(draft.incomeSourceSuggestion?.sourceType, IncomeSourceType.gift);
    expect(draft.account.id, AiTransactionDraft.unresolvedAccountId);

    final validation = const AiActionValidator().validate(
      CreateIncomeDraft(draft),
    );
    expect(validation.status, AiActionValidationStatus.needsClarification);
    expect(validation.isValid, isFalse);
  });

  test('tool exposure is empty unless a personal query needs each tool', () {
    const definitions = <AiToolDefinition>[
      AiToolDefinition(
        name: 'get_monthly_comparison',
        description: 'Compare months',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_top_spending_categories',
        description: 'Top categories',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'get_budget_summary',
        description: 'Budget summary',
        permission: AiToolPermission.readFinancialData,
      ),
      AiToolDefinition(
        name: 'draft_transaction',
        description: 'Draft a transaction',
        permission: AiToolPermission.createDraft,
      ),
    ];
    const policy = ToolRelevancePolicy();

    List<String> namesFor(String message) {
      final route = router.route(message);
      return policy
          .relevantDefinitions(
            route: route,
            userMessage: message,
            memory: const AiAgentSessionMemory(),
            definitions: definitions,
          )
          .map((tool) => tool.name)
          .toList();
    }

    expect(namesFor('مرحبا'), isEmpty);
    expect(namesFor('ما هو التضخم؟'), isEmpty);
    expect(namesFor('كيف وضع الاقتصاد الليبي حالياً؟'), isEmpty);
    expect(namesFor('حصلت هدية بخمسين دينار'), isEmpty);
    expect(namesFor('What is cash flow?'), isEmpty);
    expect(namesFor('Explain how budgets work.'), isEmpty);
    expect(
      namesFor('ليش مصروفي زايد هذا الشهر؟'),
      containsAll(<String>[
        'get_monthly_comparison',
        'get_top_spending_categories',
      ]),
    );
    expect(
      namesFor('ليش مصروفي زايد هذا الشهر؟'),
      isNot(contains('get_budget_summary')),
    );
  });

  test('Arabic fallback composition never exposes raw English payloads', () {
    final response = const DefaultAiAgentResponseComposer().compose(
      modelText: null,
      locale: 'ar',
      results: const <AiToolResult>[
        AiToolResult(
          toolName: 'get_budget_summary',
          data: <String, Object?>{
            'activeCount': 2,
            'warningCount': 1,
            'exceededCount': 0,
          },
          evidenceSummary: '2 active budgets; 1 needs attention',
        ),
      ],
    );

    expect(response.message, isNot(contains('active budgets')));
    expect(response.message, isNot(contains('{')));
    expect(response.evidence.single.summary, isNot(contains('active budgets')));
  });
}

Account _account(String id, String name) {
  return Account.create(
    id: id,
    name: name,
    type: AccountType.bank,
    currencyCode: 'LYD',
    balance: Decimal.zero,
    icon: 'bank',
    color: 0xFF4F46E5,
  );
}
