enum AiIntent {
  greeting,
  smallTalk,
  help,
  supportedCapabilities,
  createExpense,
  createIncome,
  createTransfer,
  createCategory,
  createBudget,
  createGoal,
  addGoalContribution,
  updateTransaction,
  undoAction,
  askFinancialQuestion,
  currencyConversionQuestion,
  clarificationResponse,
  deleteAccount,
  deleteTransaction,
  deleteCategory,
  deletePayee,
  bulkDelete,
  resetData,
  unknown,
}

extension AiIntentX on AiIntent {
  String get storageValue {
    return switch (this) {
      AiIntent.greeting => 'greeting',
      AiIntent.smallTalk => 'small_talk',
      AiIntent.help => 'help',
      AiIntent.supportedCapabilities => 'supported_capabilities',
      AiIntent.createExpense => 'create_expense',
      AiIntent.createIncome => 'create_income',
      AiIntent.createTransfer => 'create_transfer',
      AiIntent.createCategory => 'create_category',
      AiIntent.createBudget => 'create_budget',
      AiIntent.createGoal => 'create_goal',
      AiIntent.addGoalContribution => 'add_goal_contribution',
      AiIntent.updateTransaction => 'update_transaction',
      AiIntent.undoAction => 'undo_action',
      AiIntent.askFinancialQuestion => 'ask_financial_question',
      AiIntent.currencyConversionQuestion => 'currency_conversion_question',
      AiIntent.clarificationResponse => 'clarification_response',
      AiIntent.deleteAccount => 'delete_account',
      AiIntent.deleteTransaction => 'delete_transaction',
      AiIntent.deleteCategory => 'delete_category',
      AiIntent.deletePayee => 'delete_payee',
      AiIntent.bulkDelete => 'bulk_delete',
      AiIntent.resetData => 'reset_data',
      AiIntent.unknown => 'unknown',
    };
  }

  bool get isDestructive {
    return switch (this) {
      AiIntent.deleteAccount ||
      AiIntent.deleteTransaction ||
      AiIntent.deleteCategory ||
      AiIntent.deletePayee ||
      AiIntent.bulkDelete ||
      AiIntent.resetData => true,
      _ => false,
    };
  }
}

abstract final class AiIntentMapper {
  static AiIntent fromStorage(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'create_expense' ||
      'createexpense' ||
      'expense' => AiIntent.createExpense,
      'create_income' || 'createincome' || 'income' => AiIntent.createIncome,
      'create_transfer' ||
      'createtransfer' ||
      'transfer' => AiIntent.createTransfer,
      'create_category' ||
      'createcategory' ||
      'category' => AiIntent.createCategory,
      'create_budget' || 'createbudget' || 'budget' => AiIntent.createBudget,
      'create_goal' || 'creategoal' || 'goal' => AiIntent.createGoal,
      'add_goal_contribution' ||
      'addgoalcontribution' ||
      'goal_contribution' ||
      'contribution' => AiIntent.addGoalContribution,
      'update_transaction' ||
      'updatetransaction' ||
      'edit_transaction' => AiIntent.updateTransaction,
      'undo_action' || 'undoaction' || 'undo' => AiIntent.undoAction,
      'ask_financial_question' ||
      'askfinancialquestion' ||
      'question' ||
      'ask' => AiIntent.askFinancialQuestion,
      'greeting' || 'hello' => AiIntent.greeting,
      'small_talk' || 'smalltalk' => AiIntent.smallTalk,
      'help' => AiIntent.help,
      'supported_capabilities' ||
      'supportedcapabilities' ||
      'capabilities' => AiIntent.supportedCapabilities,
      'currency_conversion_question' ||
      'currencyconversionquestion' ||
      'currency_conversion' => AiIntent.currencyConversionQuestion,
      'clarification_response' ||
      'clarificationresponse' => AiIntent.clarificationResponse,
      'delete_account' || 'deleteaccount' => AiIntent.deleteAccount,
      'delete_transaction' || 'deletetransaction' => AiIntent.deleteTransaction,
      'delete_category' || 'deletecategory' => AiIntent.deleteCategory,
      'delete_payee' || 'deletepayee' => AiIntent.deletePayee,
      'bulk_delete' || 'bulkdelete' => AiIntent.bulkDelete,
      'reset_data' || 'resetdata' => AiIntent.resetData,
      _ => AiIntent.unknown,
    };
  }
}
