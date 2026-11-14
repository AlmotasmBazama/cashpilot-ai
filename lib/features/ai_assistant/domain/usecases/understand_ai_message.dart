import '../../../../core/error/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../budgets/domain/entities/budget_progress.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_classification_rule.dart';
import '../../../exchange_rates/domain/entities/stored_exchange_rate.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/entities/goal_progress.dart';
import '../../../payees/domain/entities/payee.dart';
import '../entities/ai_action.dart';
import '../entities/ai_action_draft.dart';
import '../entities/ai_intent.dart';
import '../entities/ai_understanding_result.dart';
import '../services/ai_intent_router.dart';
import 'create_ai_action_draft.dart';

class UnderstandAiMessage {
  const UnderstandAiMessage({
    required CreateAiActionDraft createActionDraft,
    AiIntentRouter intentRouter = const AiIntentRouter(),
  }) : _createActionDraft = createActionDraft,
       _intentRouter = intentRouter;

  final CreateAiActionDraft _createActionDraft;
  final AiIntentRouter _intentRouter;

  AiUnderstandingResult? understandLocally(String input) {
    final route = _intentRouter.route(input);
    if (route.blockedIntent case final blocked?) {
      return AiUnsupportedUnderstanding(
        responseKey: AiConversationResponseKey.destructiveBlocked,
        blockedIntent: blocked,
      );
    }
    if (route.isFinancialRecordOffer) {
      return AiFinancialRecordOfferUnderstanding(
        proposedIntent: route.intent,
        statement: input.trim(),
      );
    }
    if (route.isFinancialRecordOfferResponse) {
      return AiFinancialRecordDecisionUnderstanding(
        decision: route.recordOfferDecision,
      );
    }
    return switch (route.intent) {
      AiIntent.greeting => const AiConversationalUnderstanding(
        intent: AiIntent.greeting,
        responseKey: AiConversationResponseKey.greeting,
        suggestedPrompts: _capabilitySuggestions,
      ),
      AiIntent.smallTalk => const AiConversationalUnderstanding(
        intent: AiIntent.smallTalk,
        responseKey: AiConversationResponseKey.smallTalk,
        suggestedPrompts: _capabilitySuggestions,
      ),
      AiIntent.help => const AiConversationalUnderstanding(
        intent: AiIntent.help,
        responseKey: AiConversationResponseKey.help,
        suggestedPrompts: _capabilitySuggestions,
      ),
      AiIntent.supportedCapabilities => const AiConversationalUnderstanding(
        intent: AiIntent.supportedCapabilities,
        responseKey: AiConversationResponseKey.capabilities,
        suggestedPrompts: _capabilitySuggestions,
      ),
      AiIntent.unknown when !route.useFinancialPipeline =>
        const AiUnsupportedUnderstanding(
          responseKey: AiConversationResponseKey.unsupported,
        ),
      _ => null,
    };
  }

  Future<AppResult<AiUnderstandingResult>> call({
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
    final ordinalSelection = _isOrdinalSelection(input);
    final initialRoute = _intentRouter.route(
      input,
      awaitingFinancialClarification: ordinalSelection,
    );
    final local = ordinalSelection ? null : understandLocally(input);
    final continueConfirmedRecordOffer =
        explicitlyConfirmedMutation && initialRoute.isFinancialRecordOffer;
    if (local != null && !continueConfirmedRecordOffer) {
      return AppResult.success(local);
    }

    final route = initialRoute;
    final result = await _createActionDraft(
      input: input,
      accounts: accounts,
      categories: categories,
      baseCurrencyCode: baseCurrencyCode,
      locale: locale,
      accountClarificationMessage: accountClarificationMessage,
      expenseAccountClarificationMessage:
          expenseAccountClarificationMessage ?? accountClarificationMessage,
      payees: payees,
      categoryRules: categoryRules,
      exchangeRates: exchangeRates,
      budgetProgress: budgetProgress,
      goals: goals,
      goalProgress: goalProgress,
      ambiguousPayeeMessage: ambiguousPayeeMessage,
      exchangeRateClarificationMessage: exchangeRateClarificationMessage,
      categoryClarificationMessage: categoryClarificationMessage,
      goalClarificationMessage: goalClarificationMessage,
      unknownIntentClarificationMessage: unknownIntentClarificationMessage,
      explicitlyConfirmedMutation: explicitlyConfirmedMutation,
    );

    return switch (result) {
      AppFailure<AiActionDraft>(:final failure) => AppResult.failure(failure),
      AppSuccess<AiActionDraft>(:final data) => AppResult.success(
        _mapDraft(
          data,
          ordinalSelection ? AiIntent.clarificationResponse : route.intent,
        ),
      ),
    };
  }

  bool _isOrdinalSelection(String input) =>
      RegExp(r'^[1-3١-٣۱-۳]$').hasMatch(input.trim());

  AiUnderstandingResult _mapDraft(AiActionDraft draft, AiIntent routedIntent) {
    return switch (draft.action) {
      AskQuestionAction() ||
      CurrencyConversionAnswerAction() ||
      BudgetProgressAnswerAction() ||
      GoalProgressAnswerAction() => AiFinancialQuestionUnderstanding(
        draft: draft,
      ),
      ClarificationRequiredAction() when routedIntent == AiIntent.unknown =>
        const AiUnsupportedUnderstanding(
          responseKey: AiConversationResponseKey.unsupported,
        ),
      ClarificationRequiredAction() => AiClarificationUnderstanding(
        draft: draft,
      ),
      BlockedAiAction(:final blockedIntent) => AiUnsupportedUnderstanding(
        responseKey: AiConversationResponseKey.destructiveBlocked,
        blockedIntent: blockedIntent,
      ),
      _ => AiFinancialActionUnderstanding(draft: draft),
    };
  }
}

const _capabilitySuggestions = <AiSuggestedPrompt>[
  AiSuggestedPrompt.addExpense,
  AiSuggestedPrompt.addIncome,
  AiSuggestedPrompt.reviewBudget,
  AiSuggestedPrompt.financialReport,
];
