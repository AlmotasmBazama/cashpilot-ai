import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_intent.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_structured_action_output.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_understanding_result.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_context_builder.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_draft_factory.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/create_ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/understand_ai_message.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category_classification_rule.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category_suggestion.dart';
import 'package:cashpilot_ai/features/categories/domain/services/category_suggestion_resolver.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('intent routing and conversation separation', () {
    test('Arabic and English greetings are local visible responses', () async {
      for (final input in <String>[
        'مرحبا',
        'أهلا',
        'السلام عليكم',
        'hello',
        'hi',
      ]) {
        final repository = _RecordingRepository(_financialQuestionJson);
        final result = await _understander(repository)(
          input: input,
          accounts: const <Account>[],
          categories: const <Category>[],
          baseCurrencyCode: 'LYD',
          locale: input == 'hello' || input == 'hi' ? 'en' : 'ar',
          accountClarificationMessage: 'Which account?',
        );

        final understanding = _success(result);
        expect(understanding, isA<AiConversationalUnderstanding>());
        expect(understanding.requiresConfirmation, isFalse);
        expect(repository.sendCalls, 0);
      }
    });

    test('help and capabilities are not financial drafts', () {
      const router = AiIntentRouter();
      for (final input in <String>[
        'شن تقدر تدير',
        'ساعدني',
        'كيف نستخدم التطبيق',
        'what can you do',
        'how does this work',
      ]) {
        final route = router.route(input);
        expect(route.useFinancialPipeline, isFalse);
        expect(
          route.intent,
          anyOf(AiIntent.help, AiIntent.supportedCapabilities),
        );
      }
    });

    test('unknown non-financial input always has a visible safe outcome', () {
      final result = _understander(
        _RecordingRepository(_financialQuestionJson),
      ).understandLocally('write me a poem about the sea');

      expect(result, isA<AiUnsupportedUnderstanding>());
      expect(result?.requiresConfirmation, isFalse);
    });

    test('financial and goal questions never route as transactions', () {
      const router = AiIntentRouter();
      for (final input in <String>[
        'كم صرفت على الأكل؟',
        'شن أكبر مصروف عندي؟',
        'كيف ميزانيتي؟',
        'كم باقي للهدف؟',
      ]) {
        final route = router.route(input);
        expect(
          route.intent,
          AiIntent.askFinancialQuestion,
          reason:
              '$input target=${route.target} financial=${route.useFinancialPipeline}',
        );
        expect(route.useFinancialPipeline, isTrue, reason: input);
        expect(
          route.target,
          AssistantRouteTarget.personalFinancialAnalysis,
          reason: input,
        );
      }
    });

    test(
      'financial question maps to financial-question understanding',
      () async {
        final repository = _RecordingRepository(_financialQuestionJson);
        final result = await _understander(repository)(
          input: 'كم صرفت هذا الشهر؟',
          accounts: <Account>[_account()],
          categories: buildDefaultCategories(),
          baseCurrencyCode: 'LYD',
          locale: 'ar',
          accountClarificationMessage: 'Which account?',
        );

        final understanding = _success(result);
        expect(understanding, isA<AiFinancialQuestionUnderstanding>());
        final draft = (understanding as AiFinancialQuestionUnderstanding).draft;
        expect(draft.action, isA<AskQuestionAction>());
        expect(draft.action.requiresConfirmation, isFalse);
        expect(repository.sendCalls, 1);
      },
    );

    test(
      'destructive and confirmation-bypass requests are blocked locally',
      () {
        final understander = _understander(
          _RecordingRepository(_financialQuestionJson),
        );
        for (final input in <String>[
          'احذف كل معاملاتي',
          'غير رصيدي إلى مليون',
          'نفذ بدون تأكيد',
        ]) {
          final result = understander.understandLocally(input);
          expect(result, isA<AiUnsupportedUnderstanding>());
          expect(
            (result as AiUnsupportedUnderstanding).responseKey,
            AiConversationResponseKey.destructiveBlocked,
          );
        }
      },
    );
  });

  group('category intelligence', () {
    const resolver = CategorySuggestionResolver();
    final categories = buildDefaultCategories();

    test(
      'taxonomy separates groceries, household, care, dining, and bills',
      () {
        final cases = <String, String>{
          'حليب': 'Groceries',
          'خبز': 'Groceries',
          'بيض': 'Groceries',
          'مسحوق غسيل': 'Home',
          'شامبو': 'Beauty',
          'قهوة من كافيه': 'Coffee',
          'تعبئة رصيد': 'Phone',
          'فاتورة كهرباء': 'Bills',
          'بنزين': 'Fuel',
          'دواء': 'Pharmacy',
        };

        for (final entry in cases.entries) {
          final suggestion = resolver.resolve(
            input: entry.key,
            categories: categories,
          );
          expect(
            _categoryName(categories, suggestion.categoryId),
            entry.value,
            reason: entry.key,
          );
          expect(suggestion.confidenceLevel, CategoryConfidenceLevel.high);
        }
      },
    );

    test('milk beats an incorrect AI household suggestion', () {
      final suggestion = resolver.resolve(
        input: 'اشتريت حليب بـ5 للبيت',
        categories: categories,
        aiCategoryHint: 'Home',
        aiConfidence: 92,
      );

      expect(_categoryName(categories, suggestion.categoryId), 'Groceries');
      expect(suggestion.source, CategorySuggestionSource.exactAlias);
    });

    test('explicit category overrides rule, payee, aliases, and AI', () {
      final children = categories.first.copyWith(
        id: 'children-expenses',
        name: 'مصاريف الأطفال',
        isDefault: false,
      );
      final values = <Category>[...categories, children];
      final home = values.firstWhere((category) => category.name == 'Home');
      final suggestion = resolver.resolve(
        input: 'اشتريت حليب وحطه في مصاريف الأطفال',
        categories: values,
        payeeDefaultCategoryId: home.id,
        aiCategoryHint: 'Groceries',
        aiConfidence: 99,
        userRules: <CategoryClassificationRule>[
          CategoryClassificationRule(
            normalizedPhrase: 'حليب',
            categoryId: home.id,
            confirmedCount: 4,
            lastUsedAt: DateTime.utc(2026, 7, 25),
          ),
        ],
      );

      expect(suggestion.categoryId, children.id);
      expect(suggestion.source, CategorySuggestionSource.explicitUserInput);
    });

    test('trusted user rule outranks payee and semantic defaults', () {
      final groceries = categories.firstWhere(
        (category) => category.name == 'Groceries',
      );
      final home = categories.firstWhere((category) => category.name == 'Home');
      final suggestion = resolver.resolve(
        input: 'حفاضات 20',
        categories: categories,
        payeeDefaultCategoryId: home.id,
        aiCategoryHint: 'Home',
        userRules: <CategoryClassificationRule>[
          CategoryClassificationRule(
            normalizedPhrase: 'حفاضات',
            categoryId: groceries.id,
            confirmedCount: 2,
            lastUsedAt: DateTime.utc(2026, 7, 25),
          ),
        ],
      );

      expect(suggestion.categoryId, groceries.id);
      expect(suggestion.source, CategorySuggestionSource.userRule);
    });

    test('payee default applies only when no explicit category exists', () {
      final home = categories.firstWhere((category) => category.name == 'Home');
      final suggestion = resolver.resolve(
        input: 'اشتريت حليب من المتجر',
        categories: categories,
        payeeDefaultCategoryId: home.id,
      );

      expect(suggestion.categoryId, home.id);
      expect(suggestion.source, CategorySuggestionSource.payeeDefault);
    });

    test('high AI confidence preselects and low confidence asks a choice', () {
      final high = resolver.resolve(
        input: 'دفعت 20 في مكان جديد',
        categories: categories,
        aiCategoryHint: 'Restaurant',
        aiConfidence: 88,
      );
      final low = resolver.resolve(
        input: 'دفعت 20 في مكان جديد',
        categories: categories,
        aiCategoryHint: 'Restaurant',
        aiConfidence: 40,
        aiAlternativeHints: const <String>['Coffee', 'Groceries'],
      );

      expect(_categoryName(categories, high.categoryId), 'Restaurant');
      expect(high.confidenceLevel, CategoryConfidenceLevel.high);
      expect(high.source, CategorySuggestionSource.aiSemantic);
      expect(low.categoryId, isNull);
      expect(low.needsClarification, isTrue);
      expect(low.alternativeCategoryIds, isNotEmpty);
    });

    test('structured output carries item and category confidence safely', () {
      final output = AiStructuredActionOutput.tryParse(
        '{"intent":"create_expense","amount":"5","currency":"LYD",'
        '"description":"milk purchase","itemDescription":"milk",'
        '"categoryHint":"Groceries","categoryConfidence":"0.96",'
        '"categoryAlternatives":["Food"],"requiresConfirmation":true}',
      );

      expect(output, isNotNull);
      expect(output?.itemDescription, 'milk');
      expect(output?.categoryConfidence, 96);
      expect(output?.categoryAlternatives, <String>['Food']);
    });
  });

  group('short Arabic and Libyan parser', () {
    const parser = FinancialCommandParser();
    final categories = buildDefaultCategories();

    test('short expense and income variants parse deterministically', () {
      final cases = <({String input, String category, TransactionType type})>[
        (
          input: 'شريت حليب ب5 ادفعلي',
          category: 'Groceries',
          type: TransactionType.expense,
        ),
        (
          input: 'خديت خبز ب3 كاش',
          category: 'Groceries',
          type: TransactionType.expense,
        ),
        (
          input: 'عبيت رصيد 20',
          category: 'Phone',
          type: TransactionType.expense,
        ),
        (
          input: 'خلصت النت 40',
          category: 'Internet',
          type: TransactionType.expense,
        ),
        (
          input: 'وصلني مرتب 2500',
          category: 'Salary',
          type: TransactionType.income,
        ),
      ];

      for (final entry in cases) {
        final result = parser.parse(
          input: entry.input,
          accounts: <Account>[
            _account(paymentMethodIds: const <String>['edfaly']),
          ],
          categories: categories,
          baseCurrencyCode: 'LYD',
          paymentMethodClarificationMessage: 'Which account?',
        );
        expect(result, isA<AiTransactionDraft>(), reason: entry.input);
        final draft = result as AiTransactionDraft;
        expect(draft.type, entry.type, reason: entry.input);
        if (entry.type == TransactionType.income) {
          expect(draft.category, isNull, reason: entry.input);
          expect(
            draft.categorySuggestion?.categoryHint,
            entry.category,
            reason: entry.input,
          );
          expect(
            draft.account.id,
            AiTransactionDraft.unresolvedAccountId,
            reason: entry.input,
          );
        } else {
          expect(draft.category?.name, entry.category, reason: entry.input);
        }
      }
    });

    test('cash, Edfaly, and a safe textual amount are recognized', () {
      final cash =
          parser.parse(
                input: 'خديت خبز ب3 كاش',
                accounts: <Account>[_account()],
                categories: categories,
                baseCurrencyCode: 'LYD',
                paymentMethodClarificationMessage: 'Which account?',
              )
              as AiTransactionDraft;
      final edfaly =
          parser.parse(
                input: 'خديت حليب بخمسة من ادفعلي',
                accounts: <Account>[
                  _account(paymentMethodIds: const <String>['edfaly']),
                ],
                categories: categories,
                baseCurrencyCode: 'LYD',
                paymentMethodClarificationMessage: 'Which account?',
              )
              as AiTransactionDraft;

      expect(cash.paymentMethod, PaymentMethod.cash);
      expect(edfaly.paymentMethod, PaymentMethod.edfaly);
      expect(edfaly.amount.amount, Decimal.fromInt(5));
    });

    test('transfer wording never falls back to an expense', () {
      final result = parser.parse(
        input: 'حولت مية لسالم',
        accounts: <Account>[_account()],
        categories: categories,
        baseCurrencyCode: 'LYD',
        paymentMethodClarificationMessage: 'Which account?',
      );

      expect(result, isA<AiTransactionParseFailure>());
      expect(
        const AiIntentRouter().route('حولت مية لسالم').intent,
        AiIntent.createTransfer,
      );
    });
  });

  test('Gemini context contains semantics but no balances or identity', () {
    final context = const AiActionContextBuilder().build(
      locale: 'ar-LY',
      accounts: <Account>[
        _account(name: 'Daily cash', balance: Decimal.parse('12345.67')),
      ],
      categories: buildDefaultCategories(),
    );
    final encoded = context.toString();

    expect(context['categorySemantics'], isNotEmpty);
    expect(encoded, isNot(contains('12345.67')));
    expect(encoded, isNot(contains('uid')));
    expect(encoded, isNot(contains('email')));
    expect(encoded, isNot(contains('transaction')));
  });
}

UnderstandAiMessage _understander(_RecordingRepository repository) {
  return UnderstandAiMessage(
    createActionDraft: CreateAiActionDraft(
      aiRepository: repository,
      parser: const FinancialCommandParser(),
      draftFactory: const AiActionDraftFactory(),
      contextBuilder: const AiActionContextBuilder(),
    ),
  );
}

String? _categoryName(List<Category> categories, String? id) {
  return categories.where((category) => category.id == id).firstOrNull?.name;
}

Account _account({
  String name = 'Cash',
  Decimal? balance,
  List<String> paymentMethodIds = const <String>[],
}) {
  return Account.create(
    id: 'cash',
    name: name,
    type: AccountType.cash,
    currencyCode: 'LYD',
    balance: balance ?? Decimal.zero,
    icon: 'cash',
    color: 0xFF4F46E5,
    paymentMethodIds: paymentMethodIds,
  );
}

const _financialQuestionJson =
    '{"intent":"ask_financial_question","description":"monthly spending",'
    '"requiresConfirmation":false}';

class _RecordingRepository implements AiRepository {
  _RecordingRepository(this.responseText);

  final String responseText;
  int sendCalls = 0;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async {
    return const AppResult.success(<AiModel>[]);
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    sendCalls += 1;
    return AppResult.success(
      AiResponse(
        message: AiMessage.assistant(
          conversationId: request.conversationId,
          content: responseText,
        ),
        providerType: AiProviderType.gemini,
        modelId: 'fake',
        finishReason: AiFinishReason.complete,
        tokenUsage: const AiTokenUsage(inputTokens: 0, outputTokens: 0),
      ),
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
