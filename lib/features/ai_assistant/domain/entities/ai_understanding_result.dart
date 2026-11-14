import 'ai_action_draft.dart';
import 'ai_financial_record_offer.dart';
import 'ai_intent.dart';

enum AiConversationResponseKey {
  greeting,
  smallTalk,
  help,
  capabilities,
  unsupported,
  destructiveBlocked,
}

enum AiSuggestedPrompt {
  addExpense,
  addIncome,
  transfer,
  reviewBudget,
  reviewGoals,
  financialReport,
}

sealed class AiUnderstandingResult {
  const AiUnderstandingResult();

  bool get requiresConfirmation;
}

class AiConversationalUnderstanding extends AiUnderstandingResult {
  const AiConversationalUnderstanding({
    required this.intent,
    required this.responseKey,
    this.suggestedPrompts = const <AiSuggestedPrompt>[],
  });

  final AiIntent intent;
  final AiConversationResponseKey responseKey;
  final List<AiSuggestedPrompt> suggestedPrompts;

  @override
  bool get requiresConfirmation => false;
}

class AiFinancialActionUnderstanding extends AiUnderstandingResult {
  const AiFinancialActionUnderstanding({required this.draft});

  final AiActionDraft draft;

  @override
  bool get requiresConfirmation => draft.action.requiresConfirmation;
}

class AiFinancialQuestionUnderstanding extends AiUnderstandingResult {
  const AiFinancialQuestionUnderstanding({required this.draft});

  final AiActionDraft draft;

  @override
  bool get requiresConfirmation => false;
}

class AiClarificationUnderstanding extends AiUnderstandingResult {
  const AiClarificationUnderstanding({required this.draft});

  final AiActionDraft draft;

  @override
  bool get requiresConfirmation => false;
}

/// A money-related event was described, but the user did not ask CashPilot to
/// mutate local data. The presentation layer may offer a normal Record action
/// and retain [statement] as pending conversational context.
class AiFinancialRecordOfferUnderstanding extends AiUnderstandingResult {
  const AiFinancialRecordOfferUnderstanding({
    required this.proposedIntent,
    required this.statement,
  });

  final AiIntent proposedIntent;
  final String statement;

  @override
  bool get requiresConfirmation => false;
}

/// A conversational answer to a prior record offer. This is intent consent,
/// not execution confirmation; a completed draft still requires Confirm.
class AiFinancialRecordDecisionUnderstanding extends AiUnderstandingResult {
  const AiFinancialRecordDecisionUnderstanding({required this.decision});

  final FinancialRecordOfferDecision decision;

  @override
  bool get requiresConfirmation => false;
}

class AiUnsupportedUnderstanding extends AiUnderstandingResult {
  const AiUnsupportedUnderstanding({
    required this.responseKey,
    this.blockedIntent,
  });

  final AiConversationResponseKey responseKey;
  final AiIntent? blockedIntent;

  @override
  bool get requiresConfirmation => false;
}
