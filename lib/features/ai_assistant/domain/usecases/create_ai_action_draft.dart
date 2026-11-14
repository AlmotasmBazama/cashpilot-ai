import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../budgets/domain/entities/budget_progress.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_classification_rule.dart';
import '../../../exchange_rates/domain/entities/stored_exchange_rate.dart';
import '../../../exchange_rates/domain/services/currency_conversion_query_parser.dart';
import '../../../exchange_rates/domain/usecases/convert_money.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/entities/goal_progress.dart';
import '../../../payees/domain/entities/payee.dart';
import '../entities/ai_action.dart';
import '../entities/ai_action_draft.dart';
import '../entities/ai_intent.dart';
import '../entities/ai_message.dart';
import '../entities/ai_request.dart';
import '../entities/ai_structured_action_output.dart';
import '../entities/ai_transaction_draft.dart';
import '../failures/ai_failure_codes.dart';
import '../repositories/ai_repository.dart';
import '../repositories/ai_transaction_mutation_draft_repository.dart';
import '../services/ai_action_context_builder.dart';
import '../services/ai_action_draft_factory.dart';
import '../services/ai_action_safety_policy.dart';
import '../services/financial_command_parser.dart';
import '../services/ai_intent_router.dart';

class CreateAiActionDraft {
  const CreateAiActionDraft({
    required AiRepository aiRepository,
    required FinancialCommandParser parser,
    required AiActionDraftFactory draftFactory,
    required AiActionContextBuilder contextBuilder,
    ConvertMoney? convertMoney,
    CurrencyConversionQueryParser conversionQueryParser =
        const CurrencyConversionQueryParser(),
    AiActionSafetyPolicy safetyPolicy = const AiActionSafetyPolicy(),
    AiIntentRouter intentRouter = const AiIntentRouter(),
    AiTransactionMutationDraftRepository? transactionMutationDraftRepository,
  }) : _aiRepository = aiRepository,
       _parser = parser,
       _draftFactory = draftFactory,
       _contextBuilder = contextBuilder,
       _convertMoney = convertMoney,
       _conversionQueryParser = conversionQueryParser,
       _safetyPolicy = safetyPolicy,
       _intentRouter = intentRouter,
       _transactionMutationDraftRepository = transactionMutationDraftRepository;

  final AiRepository _aiRepository;
  final FinancialCommandParser _parser;
  final AiActionDraftFactory _draftFactory;
  final AiActionContextBuilder _contextBuilder;
  final ConvertMoney? _convertMoney;
  final CurrencyConversionQueryParser _conversionQueryParser;
  final AiActionSafetyPolicy _safetyPolicy;
  final AiIntentRouter _intentRouter;
  final AiTransactionMutationDraftRepository?
  _transactionMutationDraftRepository;

  Future<AppResult<AiActionDraft>> call({
    required String input,
    required List<Account> accounts,
    required List<Category> categories,
    required String baseCurrencyCode,
    required String locale,
    required String accountClarificationMessage,
    String? expenseAccountClarificationMessage,
    List<Payee> payees = const <Payee>[],
    List<CategoryClassificationRule> categoryRules =
        const <CategoryClassificationRule>[],
    List<StoredExchangeRate> exchangeRates = const <StoredExchangeRate>[],
    List<BudgetProgress> budgetProgress = const <BudgetProgress>[],
    List<Goal> goals = const <Goal>[],
    List<GoalProgress> goalProgress = const <GoalProgress>[],
    String ambiguousPayeeMessage = 'Which payee did you mean?',
    String exchangeRateClarificationMessage =
        'Add the missing manual exchange rate.',
    String categoryClarificationMessage = 'Which category should I use?',
    String goalClarificationMessage = 'Which goal should I use?',
    String unknownIntentClarificationMessage =
        'I could not identify a supported financial action.',
    bool explicitlyConfirmedMutation = false,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return AppResult.success(
        AiActionDraft.create(
          action: const ClarificationRequiredAction(
            message: 'Message is empty.',
          ),
        ),
      );
    }

    final destructiveIntent = _safetyPolicy.destructiveIntentFor(trimmed);
    if (destructiveIntent != null &&
        destructiveIntent != AiIntent.deleteTransaction) {
      return AppResult.success(
        AiActionDraft.create(
          action: BlockedAiAction(blockedIntent: destructiveIntent),
        ),
      );
    }

    final mutationDraft = await _transactionMutationDraftRepository?.resolve(
      input: trimmed,
      accounts: accounts,
      categories: categories,
      payees: payees,
    );
    if (mutationDraft != null) {
      return AppResult.success(mutationDraft);
    }
    if (destructiveIntent == AiIntent.deleteTransaction) {
      return AppResult.success(
        AiActionDraft.create(
          action: const BlockedAiAction(
            blockedIntent: AiIntent.deleteTransaction,
          ),
        ),
      );
    }

    final budgetAnswer = _budgetProgressAction(
      input: trimmed,
      progress: budgetProgress,
      categories: categories,
      clarificationMessage: categoryClarificationMessage,
    );
    if (budgetAnswer != null) {
      return AppResult.success(AiActionDraft.create(action: budgetAnswer));
    }

    final goalAnswer = _goalProgressAction(
      input: trimmed,
      progress: goalProgress,
      clarificationMessage: goalClarificationMessage,
    );
    if (goalAnswer != null) {
      return AppResult.success(AiActionDraft.create(action: goalAnswer));
    }

    final conversionAction = await _currencyConversionAction(
      trimmed,
      exchangeRateClarificationMessage,
    );
    if (conversionAction != null) {
      return AppResult.success(AiActionDraft.create(action: conversionAction));
    }

    final deterministicRoute = _intentRouter.route(trimmed);
    final confirmedRecordOffer =
        explicitlyConfirmedMutation &&
        deterministicRoute.isFinancialRecordOffer &&
        (deterministicRoute.intent == AiIntent.createIncome ||
            deterministicRoute.intent == AiIntent.createExpense);
    if (explicitlyConfirmedMutation &&
        deterministicRoute.isFinancialRecordOffer &&
        deterministicRoute.intent == AiIntent.unknown) {
      return AppResult.success(
        AiActionDraft.create(
          action: const ClarificationRequiredAction(
            message: 'Should I record this as income or as an expense?',
          ),
        ),
      );
    }
    if (confirmedRecordOffer) {
      final parserInput =
          '$trimmed ${deterministicRoute.intent == AiIntent.createIncome ? 'income' : 'expense'}';
      final parsed = _parser.parse(
        input: parserInput,
        accounts: accounts,
        categories: categories,
        baseCurrencyCode: baseCurrencyCode,
        paymentMethodClarificationMessage: accountClarificationMessage,
        expenseAccountClarificationMessage:
            expenseAccountClarificationMessage ?? accountClarificationMessage,
        payees: payees,
        categoryRules: categoryRules,
        ambiguousPayeeMessage: ambiguousPayeeMessage,
      );
      final localResult = parsed is AiTransactionDraft
          ? parsed.copyWith(note: trimmed)
          : parsed;
      if (localResult is! AiTransactionParseFailure) {
        return AppResult.success(
          AiActionDraft.create(
            action: _draftFactory.fromParseResult(
              result: localResult,
              originalInput: trimmed,
              unsupportedMessage: unknownIntentClarificationMessage,
            ),
          ),
        );
      }
      return AppResult.success(
        AiActionDraft.create(
          action: _draftFactory.fromParseResult(
            result: localResult,
            originalInput: trimmed,
            unsupportedMessage: unknownIntentClarificationMessage,
          ),
        ),
      );
    }

    if (deterministicRoute.isFinancialAction &&
        deterministicRoute.useLocalFinancialParser &&
        (deterministicRoute.intent == AiIntent.createExpense ||
            deterministicRoute.intent == AiIntent.createIncome)) {
      final localResult = _parser.parse(
        input: trimmed,
        accounts: accounts,
        categories: categories,
        baseCurrencyCode: baseCurrencyCode,
        paymentMethodClarificationMessage: accountClarificationMessage,
        expenseAccountClarificationMessage:
            expenseAccountClarificationMessage ?? accountClarificationMessage,
        payees: payees,
        categoryRules: categoryRules,
        ambiguousPayeeMessage: ambiguousPayeeMessage,
      );
      if (localResult is! AiTransactionParseFailure) {
        return AppResult.success(
          AiActionDraft.create(
            action: _draftFactory.fromParseResult(
              result: localResult,
              originalInput: trimmed,
              unsupportedMessage: unknownIntentClarificationMessage,
            ),
          ),
        );
      }
    }

    final aiAttempt = await _draftFromAi(
      input: trimmed,
      accounts: accounts,
      categories: categories,
      baseCurrencyCode: baseCurrencyCode,
      locale: locale,
      accountClarificationMessage: accountClarificationMessage,
      payees: payees,
      exchangeRates: exchangeRates,
      ambiguousPayeeMessage: ambiguousPayeeMessage,
      exchangeRateClarificationMessage: exchangeRateClarificationMessage,
      categoryClarificationMessage: categoryClarificationMessage,
      goals: goals,
      goalClarificationMessage: goalClarificationMessage,
      unknownIntentClarificationMessage: unknownIntentClarificationMessage,
      categoryRules: categoryRules,
    );
    if (aiAttempt.action case final aiAction?) {
      return AppResult.success(AiActionDraft.create(action: aiAction));
    }

    final parseResult = _parser.parse(
      input: trimmed,
      accounts: accounts,
      categories: categories,
      baseCurrencyCode: baseCurrencyCode,
      paymentMethodClarificationMessage: accountClarificationMessage,
      expenseAccountClarificationMessage:
          expenseAccountClarificationMessage ?? accountClarificationMessage,
      payees: payees,
      categoryRules: categoryRules,
      ambiguousPayeeMessage: ambiguousPayeeMessage,
    );
    final providerFailure = aiAttempt.failure;
    if (parseResult is AiTransactionParseFailure &&
        providerFailure != null &&
        providerFailure.code != null &&
        providerFailure.code != AiFailureCodes.localParserOnly &&
        providerFailure.code != AiFailureCodes.liveProviderInactive) {
      return AppResult.failure(providerFailure);
    }

    return AppResult.success(
      AiActionDraft.create(
        action: _draftFactory.fromParseResult(
          result: parseResult,
          originalInput: trimmed,
          unsupportedMessage: unknownIntentClarificationMessage,
        ),
      ),
    );
  }

  Future<_AiDraftAttempt> _draftFromAi({
    required String input,
    required List<Account> accounts,
    required List<Category> categories,
    required String baseCurrencyCode,
    required String locale,
    required String accountClarificationMessage,
    required List<Payee> payees,
    required List<CategoryClassificationRule> categoryRules,
    required List<StoredExchangeRate> exchangeRates,
    required String ambiguousPayeeMessage,
    required String exchangeRateClarificationMessage,
    required String categoryClarificationMessage,
    required List<Goal> goals,
    required String goalClarificationMessage,
    required String unknownIntentClarificationMessage,
  }) async {
    final conversationId = const Uuid().v7();
    final result = await _aiRepository.sendMessage(
      AiRequest(
        conversationId: conversationId,
        systemPrompt: _structuredActionPrompt,
        messages: [
          AiMessage.user(conversationId: conversationId, content: input),
        ],
        context: _contextBuilder.build(
          locale: locale,
          accounts: accounts,
          categories: categories,
        ),
        metadata: const <String, Object?>{
          'source': 'CreateAiActionDraft',
          'output': 'structured_action',
        },
      ),
    );

    final output = switch (result) {
      AppSuccess(:final data) => AiStructuredActionOutput.tryParse(
        data.message.content,
      ),
      AppFailure() => null,
    };
    if (output == null) {
      final failure = switch (result) {
        AppFailure(:final failure) => failure,
        AppSuccess() => const Failure(
          message: 'AI response could not be parsed safely.',
          code: AiFailureCodes.invalidResponse,
        ),
      };
      return _AiDraftAttempt(failure: failure);
    }

    return _AiDraftAttempt(
      action: _draftFactory.fromStructuredOutput(
        output: output,
        originalInput: input,
        accounts: accounts,
        categories: categories,
        baseCurrencyCode: baseCurrencyCode,
        accountClarificationMessage: accountClarificationMessage,
        payees: payees,
        exchangeRates: exchangeRates,
        ambiguousPayeeMessage: ambiguousPayeeMessage,
        exchangeRateClarificationMessage: exchangeRateClarificationMessage,
        categoryClarificationMessage: categoryClarificationMessage,
        goals: goals,
        categoryRules: categoryRules,
        goalClarificationMessage: goalClarificationMessage,
        unknownIntentClarificationMessage: unknownIntentClarificationMessage,
      ),
    );
  }

  AiAction? _budgetProgressAction({
    required String input,
    required List<BudgetProgress> progress,
    required List<Category> categories,
    required String clarificationMessage,
  }) {
    final normalized = CurrencyCatalog.normalizeText(input);
    final mentionsBudget =
        normalized.contains('budget') || normalized.contains('ميزاني');
    final asksProgress =
        normalized.contains('spent') ||
        normalized.contains('spend') ||
        normalized.contains('remaining') ||
        normalized.contains('صرف') ||
        normalized.contains('متبقي');
    if (!mentionsBudget || !asksProgress) {
      return null;
    }
    final categoryNames = {
      for (final category in categories)
        category.id: CurrencyCatalog.normalizeText(category.name),
    };
    final matched = progress
        .where((item) {
          final budgetName = CurrencyCatalog.normalizeText(item.budget.name);
          final categoryName = categoryNames[item.budget.categoryId];
          return normalized.contains(budgetName) ||
              (categoryName != null && normalized.contains(categoryName));
        })
        .toList(growable: false);
    final resolved = matched.length == 1
        ? matched.single
        : matched.isEmpty && progress.length == 1
        ? progress.single
        : null;
    return resolved == null
        ? ClarificationRequiredAction(message: clarificationMessage)
        : BudgetProgressAnswerAction(progress: resolved);
  }

  AiAction? _goalProgressAction({
    required String input,
    required List<GoalProgress> progress,
    required String clarificationMessage,
  }) {
    final normalized = CurrencyCatalog.normalizeText(input);
    final mentionsGoal =
        normalized.contains('goal') || normalized.contains('هدف');
    final asksProgress =
        normalized.contains('saved') ||
        normalized.contains('progress') ||
        normalized.contains('remaining') ||
        normalized.contains('مدخر') ||
        normalized.contains('جمعت') ||
        normalized.contains('تقدم') ||
        normalized.contains('متبقي');
    if (!mentionsGoal || !asksProgress) {
      return null;
    }
    final matched = progress
        .where((item) {
          final title = CurrencyCatalog.normalizeText(item.goal.title);
          return normalized.contains(title);
        })
        .toList(growable: false);
    final resolved = matched.length == 1
        ? matched.single
        : matched.isEmpty && progress.length == 1
        ? progress.single
        : null;
    return resolved == null
        ? ClarificationRequiredAction(message: clarificationMessage)
        : GoalProgressAnswerAction(progress: resolved);
  }

  Future<AiAction?> _currencyConversionAction(
    String input,
    String missingRateMessage,
  ) async {
    final query = _conversionQueryParser.parse(input);
    final convertMoney = _convertMoney;
    if (query == null || convertMoney == null) {
      return null;
    }
    final result = await convertMoney(
      query.sourceAmount,
      query.targetCurrencyCode,
    );
    return switch (result) {
      AppSuccess(:final data) => CurrencyConversionAnswerAction(
        sourceAmount: query.sourceAmount,
        convertedAmount: data,
      ),
      AppFailure() => ClarificationRequiredAction(message: missingRateMessage),
    };
  }
}

class _AiDraftAttempt {
  const _AiDraftAttempt({this.action, this.failure});

  final AiAction? action;
  final Failure? failure;
}

const _structuredActionPrompt = '''
You convert personal finance messages into one JSON object only.
Never execute actions.
Never request destructive actions.
Allowed intents: create_expense, create_income, create_transfer, create_category, create_budget, create_goal, add_goal_contribution, ask_financial_question, unknown.
Amount must be a string, never a number.
Data-changing actions must set requiresConfirmation to true.
Use this shape:
{"intent":"create_expense","confidence":"0.92","amount":"5","currency":"LYD","description":"milk purchase","itemDescription":"milk","categoryHint":"Groceries","categoryConfidence":"0.96","categoryAlternatives":[],"accountHint":"edfaly","sourceAccountHint":null,"destinationAccountHint":null,"destinationAmount":null,"exchangeRate":null,"periodType":null,"goalType":null,"goalHint":null,"payeeHint":null,"incomeSourceType":null,"incomeSourceHint":null,"incomeSourcePayeeHint":null,"dateText":null,"isRefund":null,"isReimbursement":null,"isLoanProceeds":null,"isInternalTransfer":null,"requiresConfirmation":true,"clarificationQuestion":null}
Classify categories by meaning, not loose substring overlap.
Milk, bread, eggs, produce, meat, and other food staples belong to Groceries even when bought for the home.
Home means non-food household goods such as detergent, cleaning supplies, and kitchen tools.
Return a categoryConfidence from 0 to 1 and up to three categoryAlternatives.
Only use category names supplied in the allowed context.
For transfers, only copy exchangeRate or destinationAmount when the user explicitly states it. Otherwise return null for those fields.
For income, classify incomeSourceType as salary, freelance, business_revenue, gift, allowance, refund, sale, rental_income, government_support, scholarship, investment_return, reimbursement, prize, loan_proceeds, external_transfer, or other.
Keep loan proceeds distinct from normal income. Set isLoanProceeds true for loans.
Keep refunds and reimbursements distinct. Set their matching boolean when supported by the visible text.
If money moves between the user's own accounts, use create_transfer and set isInternalTransfer true; never classify it as income.
For income, destinationAccountHint is the receiving account or bank. incomeSourcePayeeHint is the person or organization the money came from.
Never invent an income source, destination account, currency, date, or classification. Use clarificationQuestion when the source or account is ambiguous.
For budgets, set periodType to weekly, monthly, yearly, or custom.
For goals, put the short goal title in goalHint, use goalType savings, emergency_fund, debt_payoff, purchase, or custom, and put an ISO or relative target date in dateText.
For goal contributions, put the existing goal title in goalHint. Contributions only track progress and never move account money.
''';
