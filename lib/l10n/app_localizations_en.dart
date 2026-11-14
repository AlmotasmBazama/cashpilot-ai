// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aiUnsupportedPromptMessage =>
      'I could not complete that request. Try rephrasing it, or ask another safe question.';

  @override
  String get aiGreetingResponse =>
      'Hi! How can I help today? You can ask a general question, review your spending, or prepare a new transaction.';

  @override
  String get aiSmallTalkResponse =>
      'I’m doing well, thanks! What can I help you with today?';

  @override
  String get aiHelpResponse =>
      'Ask any safe general question, request current information with sources, review your CashPilot data, or describe a financial action. Financial changes always wait for your review and confirmation.';

  @override
  String get aiCapabilitiesResponse =>
      'I can answer general questions, explain concepts, find current information with sources, analyze your CashPilot data, and prepare reviewable transaction, budget, and goal drafts.';

  @override
  String get aiUnsupportedConversationResponse =>
      'I could not complete that request, but you can rephrase it or ask another safe question.';

  @override
  String get aiDestructiveRequestBlockedResponse =>
      'I can’t delete financial records, change balances directly, or bypass confirmation. I can help you prepare a safe reviewable action instead.';

  @override
  String get aiAssistantResponseTitle => 'CashPilot assistant';

  @override
  String get aiFinancialQuestionLocalResponse =>
      'I recognized this as a financial question, not a transaction. CashPilot answers supported totals, budgets, goals, and currency conversions from local data without sending transaction history to Gemini. Add a period or category if you need a more specific answer.';

  @override
  String get aiSearchingCurrentInformation =>
      'Searching for current information…';

  @override
  String get aiSources => 'Sources';

  @override
  String get aiUpdatedAsOf => 'Current as of';

  @override
  String get aiUnableVerifyCurrent =>
      'Current information could not be verified.';

  @override
  String get aiReviewingYourData => 'Reviewing your data…';

  @override
  String get aiComparingPeriods => 'Comparing periods…';

  @override
  String get aiPreparingDraft => 'Preparing a reviewable draft…';

  @override
  String get aiGeneralUnavailable =>
      'The general assistant is temporarily unavailable. Please try again shortly.';

  @override
  String get aiGroundedAnswer => 'Grounded current answer';

  @override
  String get aiJumpToLatest => 'Jump to latest';

  @override
  String get aiStopGenerating => 'Stop generating';

  @override
  String get aiCopyResponse => 'Copy response';

  @override
  String get aiRetryResponse => 'Retry response';

  @override
  String get aiNewConversation => 'New conversation';

  @override
  String get aiClearConversation => 'Clear conversation';

  @override
  String get aiClearConversationConfirmation =>
      'Clear every message in this conversation? This cannot be undone.';

  @override
  String get aiCurrentInfoMayChange =>
      'Current information may change; review the linked sources.';

  @override
  String get aiDraftToolsUnavailable =>
      'Action drafting is temporarily unavailable. No financial change was made.';

  @override
  String get aiAskAnotherQuestion => 'Ask another question';

  @override
  String get aiSelectDestinationAccount =>
      'Select the account that received this income';

  @override
  String get aiEvidenceCurrentMonth => 'Based on this month’s CashPilot data';

  @override
  String get aiEvidenceComparedPrior => 'Compared with the previous month';

  @override
  String get aiSearchEntryUnavailable =>
      'Google Search follow-up suggestions are unavailable on this platform.';

  @override
  String get promptWhatIsInflation => 'What is inflation?';

  @override
  String get promptCurrentLibyaEconomy => 'How is Libya’s economy currently?';

  @override
  String get appTitle => 'CashPilot AI';

  @override
  String get homeHeadline => 'Finance workspace';

  @override
  String get homeSubtitle => 'Your finance modules are ready to be built.';

  @override
  String get navDashboard => 'Home';

  @override
  String get secureLocalFirst => 'Local-first, finance-grade foundation';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsSubtitle => 'Balances and linked wallets';

  @override
  String get accountsScreenTitle => 'Accounts';

  @override
  String get accountsScreenSubtitle =>
      'Track balances across cash, cards, banks, and wallets.';

  @override
  String get activeAccountsLabel => 'Active';

  @override
  String get archivedAccountsLabel => 'Archived';

  @override
  String get trackedCurrenciesLabel => 'Currencies';

  @override
  String get archivedAccountLabel => 'Archived';

  @override
  String get moreActions => 'More actions';

  @override
  String get addAccount => 'Add account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get archiveAccount => 'Archive account';

  @override
  String get accountName => 'Account name';

  @override
  String get accountType => 'Account type';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeCreditCard => 'Credit card';

  @override
  String get accountTypeDebitCard => 'Debit card';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get accountTypeDigitalWallet => 'Digital wallet';

  @override
  String get accountTypeCrypto => 'Crypto';

  @override
  String get accountTypeOther => 'Other';

  @override
  String get currencyCode => 'Currency';

  @override
  String get accountCurrencyLockedMessage =>
      'Currency is locked after account creation to keep balances and history accurate.';

  @override
  String get openingBalance => 'Opening balance';

  @override
  String get accountBalance => 'Balance';

  @override
  String get accountIcon => 'Icon';

  @override
  String get accountColor => 'Color';

  @override
  String get accountPaymentMethods => 'Payment methods';

  @override
  String get accountPaymentMethodsHint =>
      'Link Libyan payment services that belong to this account.';

  @override
  String get accountNameRequired => 'Account name is required.';

  @override
  String get invalidAmount => 'Enter a valid amount.';

  @override
  String get invalidCurrencyCode => 'Use a 3-letter currency code.';

  @override
  String get selectAccountType => 'Select account type';

  @override
  String get emptyAccountsTitle => 'No accounts yet';

  @override
  String get emptyAccountsMessage =>
      'Add your first account to start tracking balances.';

  @override
  String get accountsErrorTitle => 'Could not load accounts';

  @override
  String get accountsErrorMessage => 'Refresh the page or try again later.';

  @override
  String get accountCreatedMessage => 'Account created.';

  @override
  String get accountUpdatedMessage => 'Account updated.';

  @override
  String get accountArchivedMessage => 'Account archived.';

  @override
  String get accountDeletedMessage => 'Account deleted.';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountMessage => 'This action cannot be undone.';

  @override
  String get accountDetailsTitle => 'Account details';

  @override
  String get accountDetailsPlaceholder =>
      'Detailed activity and controls for this account.';

  @override
  String get accountNotFound => 'Account not found';

  @override
  String get accountsPreview => 'Accounts preview';

  @override
  String get accountStatisticsSubtitle =>
      'Activity trend for the last six months.';

  @override
  String get transactionsTitle => 'Transactions';

  @override
  String get transactionsSubtitle => 'Cash flow and categorization';

  @override
  String get transactionsErrorTitle => 'Could not load transactions';

  @override
  String get transactionsErrorMessage => 'Refresh the page or try again later.';

  @override
  String get emptyTransactionsTitle => 'No transactions yet';

  @override
  String get emptyTransactionsMessage =>
      'Transactions will appear here after you add income or expenses.';

  @override
  String get searchTransactions => 'Search transactions';

  @override
  String get loadMoreTransactions => 'Load more transactions';

  @override
  String transactionsLoadedCount(int loaded, int total) {
    return '$loaded of $total';
  }

  @override
  String get addExpense => 'Add expense';

  @override
  String get addIncome => 'Add income';

  @override
  String get editTransaction => 'Edit transaction';

  @override
  String get transactionCreatedMessage => 'Transaction created.';

  @override
  String get transactionUpdatedMessage => 'Transaction updated.';

  @override
  String get pendingTransactionEditHint =>
      'Pending transactions do not affect account balances until they are posted.';

  @override
  String get postedTransactionEditHint =>
      'Saving reverses the previous posted balance effect, then applies the edited values exactly once.';

  @override
  String get transactionPrerequisitesTitle =>
      'Accounts and categories required';

  @override
  String get transactionPrerequisitesMessage =>
      'Create at least one account and one matching category before adding a transaction.';

  @override
  String get transactionDetails => 'Transaction details';

  @override
  String get transactionNotFound => 'Transaction not found';

  @override
  String get deleteTransactionTitle => 'Delete transaction?';

  @override
  String get deleteTransactionMessage =>
      'Deleting a posted transaction will reverse its balance effect.';

  @override
  String get category => 'Category';

  @override
  String get categoryTypeExpense => 'Expense';

  @override
  String get categoryTypeIncome => 'Income';

  @override
  String get categoryTypeTransfer => 'Transfer';

  @override
  String get amount => 'Amount';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodDebitCard => 'Debit card';

  @override
  String get paymentMethodCreditCard => 'Credit card';

  @override
  String get paymentMethodBankTransfer => 'Bank transfer';

  @override
  String get paymentMethodDigitalWallet => 'Digital wallet';

  @override
  String get paymentMethodEdfaly => 'Edfaly';

  @override
  String get paymentMethodMasrafiPay => 'Masrafi Pay';

  @override
  String get paymentMethodMobiCash => 'Mobi Cash';

  @override
  String get paymentMethodYusrPay => 'Yusr Pay';

  @override
  String get paymentMethodCheck => 'Check';

  @override
  String get paymentMethodCrypto => 'Crypto';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get status => 'Status';

  @override
  String get transactionStatusPosted => 'Posted';

  @override
  String get transactionStatusPending => 'Pending';

  @override
  String get transactionStatusCancelled => 'Cancelled';

  @override
  String get transactionStatusFailed => 'Failed';

  @override
  String get transactionTypeExpense => 'Expense';

  @override
  String get transactionTypeIncome => 'Income';

  @override
  String get transactionTypeTransferOut => 'Transfer out';

  @override
  String get transactionTypeTransferIn => 'Transfer in';

  @override
  String get transactionDate => 'Transaction date';

  @override
  String get note => 'Note';

  @override
  String get location => 'Location';

  @override
  String get source => 'Source';

  @override
  String get transactionSourceManual => 'Manual';

  @override
  String get transactionSourceImported => 'Imported';

  @override
  String get transactionSourceRecurring => 'Recurring';

  @override
  String get transactionSourceAiGenerated => 'AI generated';

  @override
  String get transactionSourceCloudSync => 'Cloud sync';

  @override
  String get transactionSourceSystem => 'System';

  @override
  String get aiReview => 'AI review';

  @override
  String get aiReviewNeeded => 'This transaction is marked for review.';

  @override
  String get aiReviewNotNeeded => 'No AI review is required.';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesSubtitle => 'Organize income, expenses, and transfers.';

  @override
  String get createCategory => 'Create category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNameRequired => 'Category name is required.';

  @override
  String get parentCategory => 'Parent category';

  @override
  String get noParentCategory => 'No parent category';

  @override
  String get categoriesErrorTitle => 'Could not load categories';

  @override
  String get categoriesErrorMessage => 'Refresh the page or try again later.';

  @override
  String get emptyCategoriesTitle => 'No categories yet';

  @override
  String get emptyCategoriesMessage =>
      'Default and custom categories will appear here.';

  @override
  String get defaultCategory => 'Default';

  @override
  String get categoryNameFood => 'Food';

  @override
  String get categoryNameCoffee => 'Coffee';

  @override
  String get categoryNameRestaurant => 'Restaurant';

  @override
  String get categoryNameTransport => 'Transport';

  @override
  String get categoryNameTaxi => 'Taxi';

  @override
  String get categoryNameFuel => 'Fuel';

  @override
  String get categoryNameShopping => 'Shopping';

  @override
  String get categoryNameGroceries => 'Groceries & food staples';

  @override
  String get categoryNameEntertainment => 'Entertainment';

  @override
  String get categoryNameGaming => 'Gaming';

  @override
  String get categoryNameTravel => 'Travel';

  @override
  String get categoryNameHotel => 'Hotel';

  @override
  String get categoryNameBills => 'Bills';

  @override
  String get categoryNameInternet => 'Internet';

  @override
  String get categoryNamePhone => 'Phone';

  @override
  String get categoryNameRent => 'Rent';

  @override
  String get categoryNameInsurance => 'Insurance';

  @override
  String get categoryNameHealthcare => 'Healthcare';

  @override
  String get categoryNamePharmacy => 'Pharmacy';

  @override
  String get categoryNameEducation => 'Education';

  @override
  String get categoryNameSubscription => 'Subscription';

  @override
  String get categoryNameElectronics => 'Electronics';

  @override
  String get categoryNamePets => 'Pets';

  @override
  String get categoryNameCharity => 'Charity';

  @override
  String get categoryNameTaxes => 'Taxes';

  @override
  String get categoryNameGift => 'Gift';

  @override
  String get categoryNameClothing => 'Clothing';

  @override
  String get categoryNameSports => 'Sports';

  @override
  String get categoryNameBeauty => 'Beauty';

  @override
  String get categoryNameHome => 'Home';

  @override
  String get categoryNameSalary => 'Salary';

  @override
  String get categoryNameFreelance => 'Freelance';

  @override
  String get categoryNameBonus => 'Bonus';

  @override
  String get categoryNameInvestment => 'Investment';

  @override
  String get categoryNameRefund => 'Refund';

  @override
  String get categoryNameCashback => 'Cashback';

  @override
  String get categoryNameRentalIncome => 'Rental income';

  @override
  String get categoryNameInterest => 'Interest';

  @override
  String get categoryNameOtherIncome => 'Other income';

  @override
  String get categoryNameBusinessRevenue => 'Business revenue';

  @override
  String get categoryNameAllowance => 'Allowance';

  @override
  String get categoryNameReimbursement => 'Reimbursement';

  @override
  String get categoryNameSaleProceeds => 'Sale proceeds';

  @override
  String get categoryNameGovernmentSupport => 'Government support';

  @override
  String get categoryNameScholarship => 'Scholarship';

  @override
  String get categoryNamePrize => 'Prize';

  @override
  String get categoryNameLoanProceeds => 'Loan proceeds';

  @override
  String get categoryNameTransfer => 'Transfer';

  @override
  String get payeesTitle => 'Payees';

  @override
  String get payeesSubtitle =>
      'Manage people, merchants, employers, and services.';

  @override
  String get payeesErrorTitle => 'Could not load payees';

  @override
  String get searchPayees => 'Search payees';

  @override
  String get emptyPayeesTitle => 'No payees yet';

  @override
  String get emptyPayeesMessage =>
      'Add a payee to improve transaction entry and AI matching.';

  @override
  String get payeeDetails => 'Payee details';

  @override
  String get payeeDetailsMessage =>
      'Defaults and aliases make transaction entry faster and more accurate.';

  @override
  String payeeTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetsSubtitle => 'Plans and spending limits';

  @override
  String get budgetProgress => 'Budget progress';

  @override
  String get budgetProgressPending =>
      'Set monthly limits to watch spending pace and category pressure here.';

  @override
  String get budgetBackendPendingTitle => 'Budget control center';

  @override
  String get budgetBackendPendingMessage =>
      'Plan limits, monitor pace, and keep spending alerts visible in one focused workspace.';

  @override
  String get createBudget => 'Create budget';

  @override
  String get activeBudgets => 'Active budgets';

  @override
  String get remainingBudget => 'Remaining budget';

  @override
  String get budgetAlerts => 'Budget alerts';

  @override
  String get emptyBudgetsTitle => 'No budgets yet';

  @override
  String get emptyBudgetsMessage =>
      'Your budget cards will live here when you start assigning spending limits.';

  @override
  String get addBudget => 'Add budget';

  @override
  String get editBudget => 'Edit budget';

  @override
  String get archiveBudget => 'Archive budget';

  @override
  String get restoreBudget => 'Restore budget';

  @override
  String get budgetName => 'Budget name';

  @override
  String get budgetAmount => 'Budget amount';

  @override
  String get budgetPeriod => 'Budget period';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get customPeriod => 'Custom period';

  @override
  String get alertThreshold => 'Alert threshold';

  @override
  String get spent => 'Spent';

  @override
  String get remaining => 'Remaining';

  @override
  String get onTrack => 'On track';

  @override
  String get nearLimit => 'Near limit';

  @override
  String get exceeded => 'Exceeded';

  @override
  String get inactive => 'Inactive';

  @override
  String get createYourFirstBudget =>
      'Create your first budget to track a category spending limit.';

  @override
  String get budgetSaved => 'Budget saved.';

  @override
  String get budgetArchived => 'Budget archived.';

  @override
  String get budgetRestored => 'Budget restored.';

  @override
  String get invalidBudgetAmount => 'Enter a budget amount greater than zero.';

  @override
  String get selectCategory => 'Select a category.';

  @override
  String get budgetPeriodInvalid => 'Choose a valid start and end date.';

  @override
  String get budgetMissingExchangeRate =>
      'This progress is partial because an exchange rate is missing.';

  @override
  String get includeArchivedBudgets => 'Include archived budgets';

  @override
  String get budgetDetails => 'Budget details';

  @override
  String get budgetStartDate => 'Start date';

  @override
  String get budgetEndDate => 'End date';

  @override
  String get budgetArchiveConfirm =>
      'Archived budgets stop appearing in active planning summaries.';

  @override
  String get budgetsLoadError => 'Could not load budgets';

  @override
  String get budgetsLoadErrorMessage =>
      'Your budgets are still stored safely. Try loading them again.';

  @override
  String get budgetSaveError => 'Could not save the budget.';

  @override
  String get goalsTitle => 'Goals';

  @override
  String get goalsSubtitle => 'Savings targets and milestones';

  @override
  String get goalsProgress => 'Goals progress';

  @override
  String get goalsProgressPending =>
      'Create targets to follow milestones, saved amounts, and goal momentum.';

  @override
  String get goalsBackendPendingTitle => 'Goal planning space';

  @override
  String get goalsBackendPendingMessage =>
      'Shape savings targets, track milestones, and keep long-term plans visible.';

  @override
  String get createGoal => 'Create goal';

  @override
  String get activeGoals => 'Active goals';

  @override
  String get savedForGoals => 'Saved for goals';

  @override
  String get goalMilestones => 'Milestones';

  @override
  String get emptyGoalsTitle => 'No goals yet';

  @override
  String get emptyGoalsMessage =>
      'Your savings targets will appear here when you start planning a goal.';

  @override
  String get addGoal => 'Add goal';

  @override
  String get editGoal => 'Edit goal';

  @override
  String get archiveGoal => 'Archive goal';

  @override
  String get restoreGoal => 'Restore goal';

  @override
  String get goalTitle => 'Goal title';

  @override
  String get goalDescription => 'Description';

  @override
  String get goalType => 'Goal type';

  @override
  String get targetAmount => 'Target amount';

  @override
  String get currentAmount => 'Current amount';

  @override
  String get targetDate => 'Target date';

  @override
  String get clearTargetDate => 'Clear target date';

  @override
  String get contribution => 'Contribution';

  @override
  String get addContribution => 'Add contribution';

  @override
  String get contributionHistory => 'Contribution history';

  @override
  String get savingsGoal => 'Savings goal';

  @override
  String get emergencyFund => 'Emergency fund';

  @override
  String get debtPayoff => 'Debt payoff';

  @override
  String get purchaseGoal => 'Purchase goal';

  @override
  String get customGoal => 'Custom goal';

  @override
  String get goalStatusActive => 'Active';

  @override
  String get goalStatusCompleted => 'Completed';

  @override
  String get goalStatusPaused => 'Paused';

  @override
  String get goalStatusArchived => 'Archived';

  @override
  String get goalProgress => 'Goal progress';

  @override
  String get remainingAmount => 'Remaining amount';

  @override
  String get daysRemaining => 'Days remaining';

  @override
  String get monthlyNeeded => 'Monthly needed';

  @override
  String get createYourFirstGoal =>
      'Create your first goal and track every contribution.';

  @override
  String get goalSaved => 'Goal saved.';

  @override
  String get goalArchived => 'Goal archived.';

  @override
  String get goalRestored => 'Goal restored.';

  @override
  String get contributionAdded => 'Contribution added.';

  @override
  String get contributionReversed => 'Contribution reversed.';

  @override
  String get invalidGoalAmount => 'Enter a target amount greater than zero.';

  @override
  String get invalidContributionAmount =>
      'Enter a contribution greater than zero.';

  @override
  String get selectGoal => 'Select a goal.';

  @override
  String get includeArchivedGoals => 'Include archived goals';

  @override
  String get goalsLoadError => 'Could not load goals';

  @override
  String get goalsLoadErrorMessage =>
      'Your goals are still stored safely. Try loading them again.';

  @override
  String get goalSaveError => 'Could not save the goal.';

  @override
  String get contributionSaveError => 'Could not add this contribution.';

  @override
  String get goalDetails => 'Goal details';

  @override
  String get goalArchiveConfirm =>
      'Archived goals stop accepting contributions and leave active planning summaries.';

  @override
  String get contributionNote => 'Note';

  @override
  String get contributionDate => 'Contribution date';

  @override
  String get reversedContribution => 'Reversed';

  @override
  String get reverseContribution => 'Reverse contribution';

  @override
  String get reverseContributionConfirm =>
      'This removes the contribution from the tracked goal progress without moving account money.';

  @override
  String get noContributionsYet => 'No contributions yet';

  @override
  String get noContributionsMessage =>
      'Contributions to this goal will appear here.';

  @override
  String get linkedAccount => 'Linked account';

  @override
  String get noLinkedAccount => 'No linked account';

  @override
  String get nearestTargetDate => 'Nearest target date';

  @override
  String get completedGoals => 'Completed goals';

  @override
  String get goalMissingExchangeRate =>
      'Add a manual exchange rate before using this contribution currency.';

  @override
  String get goalWouldExceedTarget =>
      'This contribution would exceed the remaining target amount.';

  @override
  String get goalTargetBelowCurrent =>
      'The target cannot be lower than the amount already saved.';

  @override
  String get goalTrackingOnly => 'Tracking contribution';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get financialInsights => 'Financial insights';

  @override
  String get financialInsightsSubtitle =>
      'Calculated privately from local financial activity';

  @override
  String get noInsightsTitle => 'No insights yet';

  @override
  String get noInsightsMessage =>
      'Insights will appear when there is enough posted activity to compare.';

  @override
  String get insightSpendingIncreaseTitle => 'Spending increased';

  @override
  String insightSpendingIncreaseMessage(String percent) {
    return 'Spending is up $percent% compared with last month.';
  }

  @override
  String get insightPositiveSpendingTitle => 'Spending trend improved';

  @override
  String insightPositiveSpendingMessage(String percent) {
    return 'Spending is down $percent% compared with last month.';
  }

  @override
  String get insightTopCategoryTitle => 'Top spending category';

  @override
  String insightTopCategoryMessage(String category, String amount) {
    return '$category led spending at $amount this month.';
  }

  @override
  String get insightRecurringTitle => 'Possible recurring payments';

  @override
  String insightRecurringMessage(String count) {
    return '$count possible recurring payment patterns were detected locally.';
  }

  @override
  String get insightCashFlowWarningTitle => 'Cash flow needs attention';

  @override
  String insightCashFlowWarningMessage(String amount) {
    return 'Current posted cash flow is $amount.';
  }

  @override
  String get insightPositiveCashFlowTitle => 'Positive cash-flow trend';

  @override
  String insightPositiveCashFlowMessage(String amount) {
    return 'Current posted cash flow is $amount.';
  }

  @override
  String get insightMissingRateTitle => 'Missing exchange rate';

  @override
  String insightMissingRateMessage(String pair) {
    return '$pair is missing, so some totals are partial.';
  }

  @override
  String get insightBudgetWarningTitle => 'Budget alert';

  @override
  String insightBudgetWarningMessage(String name, String percent) {
    return '$name is at $percent%.';
  }

  @override
  String get insightGoalProgressTitle => 'Goal progress';

  @override
  String insightGoalProgressMessage(String name, String percent) {
    return '$name has reached $percent%.';
  }

  @override
  String get insightSavingsOpportunityTitle => 'Savings opportunity';

  @override
  String get insightUnusualTransactionTitle => 'Unusual transaction';

  @override
  String get insightPeriod => 'Insight period';

  @override
  String get reviewInsight => 'Review';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsSubtitle => 'Trends and financial insights';

  @override
  String get reportsErrorTitle => 'Could not load reports';

  @override
  String get monthlyReport => 'Monthly report';

  @override
  String get yearlyReport => 'Yearly report';

  @override
  String get yearlyInsightsEmptyTitle => 'Yearly insights are taking shape';

  @override
  String get yearlyInsightsEmptyMessage =>
      'A complete yearly view will appear here when the reporting period is available.';

  @override
  String get categoryReport => 'Category report';

  @override
  String get cashFlow => 'Cash flow';

  @override
  String get cashFlowSubtitle => 'Expense movement over the last six months.';

  @override
  String get cashFlowActiveMessage =>
      'Cash flow is calculated from posted local transactions.';

  @override
  String get cashFlowEmptyMessage =>
      'Add transactions to activate live cash-flow trends.';

  @override
  String get reportActualDataSubtitle =>
      'Calculated from local accounts and transactions.';

  @override
  String get aiAssistantTitle => 'AI Assistant';

  @override
  String get aiAssistantShort => 'AI';

  @override
  String get aiAssistantSubtitle => 'Personal finance intelligence';

  @override
  String get aiAssistantBackendPendingTitle => 'CashPilot intelligence';

  @override
  String get aiAssistantBackendPendingMessage =>
      'Ask questions or describe a financial action. CashPilot prepares a reviewable draft and never changes money without your confirmation.';

  @override
  String get aiAssistantPendingSnack =>
      'Voice input is not available yet. You can type your request instead.';

  @override
  String get suggestedPrompts => 'Suggested prompts';

  @override
  String get promptAnalyzeSpending => 'Analyze my spending';

  @override
  String get promptFindSavings => 'Find savings opportunities';

  @override
  String get promptExplainCashFlow => 'Explain my cash flow';

  @override
  String get promptReviewSubscriptions => 'Review subscriptions';

  @override
  String get insightCards => 'Insight cards';

  @override
  String get aiInsightCard => 'AI insight';

  @override
  String get aiInsightDataReady =>
      'Your local transaction history is ready for privacy-conscious AI analysis.';

  @override
  String get aiInsightEmpty =>
      'Add transactions to unlock personalized AI insights.';

  @override
  String get openAssistant => 'Open assistant';

  @override
  String get emptyConversationTitle => 'No conversation yet';

  @override
  String get emptyConversationMessage =>
      'Start with a question or describe a transaction you want CashPilot to prepare.';

  @override
  String get aiReadyBadge => 'AI ready';

  @override
  String get aiThinking => 'Reviewing your request';

  @override
  String get askAiHint => 'Ask CashPilot AI';

  @override
  String get aiTransactionDraftTitle => 'Transaction draft';

  @override
  String get aiClarifyPaymentMethod => 'Which payment method did you use?';

  @override
  String get aiParsedAccount => 'Account';

  @override
  String get aiParsedCurrency => 'Currency';

  @override
  String get aiParsedPaymentMethod => 'Payment method';

  @override
  String get aiParsedConfidence =>
      'Parsed from your message. Review before saving.';

  @override
  String get voiceInput => 'Voice input';

  @override
  String get send => 'Send';

  @override
  String get aiDiagnosticsTitle => 'AI diagnostics';

  @override
  String get aiDiagnosticsDescription =>
      'Verify the configured remote text provider, gateway, authentication, and App Check without changing financial data.';

  @override
  String get aiConfigurationTitle => 'AI configuration';

  @override
  String get aiRemoteTextProviderLabel => 'Remote text provider';

  @override
  String get aiGeneralConversationModelLabel => 'General conversation model';

  @override
  String get aiFinancialExplanationModelLabel => 'Financial explanation model';

  @override
  String get aiLocalCommandParserLabel => 'Local command parser';

  @override
  String get aiReceiptVisionProviderLabel => 'Receipt Vision provider';

  @override
  String get aiProviderRoutingLabel => 'Provider routing';

  @override
  String get aiFirebaseTextFallbackLabel => 'Firebase text fallback';

  @override
  String get aiGatewayLabel => 'Gateway';

  @override
  String get aiAuthenticationLabel => 'Authentication';

  @override
  String get aiAppCheckLabel => 'App Check';

  @override
  String get aiEnvironmentLabel => 'Environment';

  @override
  String get aiBuildModeLabel => 'Build mode';

  @override
  String get aiProviderGroq => 'Groq';

  @override
  String get aiProviderFirebaseAi => 'Firebase AI';

  @override
  String get aiProviderNotConfigured => 'Not configured';

  @override
  String get aiProviderRoutingGroqPrimary => 'Groq primary';

  @override
  String get aiProviderRoutingFirebasePrimary => 'Firebase primary';

  @override
  String get aiProviderRoutingDisabled => 'Remote text disabled';

  @override
  String get aiStatusEnabled => 'Enabled';

  @override
  String get aiStatusDisabled => 'Disabled';

  @override
  String get aiStatusAvailable => 'Available';

  @override
  String get aiStatusUnavailable => 'Unavailable';

  @override
  String get aiStatusReady => 'Ready';

  @override
  String get aiStatusNotReady => 'Not ready';

  @override
  String get aiStatusVerified => 'Verified';

  @override
  String get aiStatusNotActivated => 'Not activated';

  @override
  String get aiStatusChecking => 'Checking…';

  @override
  String get aiProviderLabel => 'AI provider';

  @override
  String get aiProviderMock => 'Mock provider';

  @override
  String get aiProviderLocalParserOnly => 'Local parser only';

  @override
  String get aiProviderFirebaseGemini => 'Firebase Gemini (live)';

  @override
  String get aiProviderAutomatic => 'Automatic provider routing';

  @override
  String get aiProviderGroqGateway => 'Groq secure gateway';

  @override
  String get aiModelGatewayManaged => 'Gateway-managed model';

  @override
  String get aiModelLabel => 'Active AI model';

  @override
  String get aiStructuredOutputEnabledLabel => 'Structured output enabled';

  @override
  String get aiStructuredOutputEnabledValue => 'Enabled';

  @override
  String get aiStructuredOutputDisabledValue => 'Disabled';

  @override
  String get aiLastTestStatusLabel => 'Last test status';

  @override
  String get aiTestStatusNotTested => 'Not tested';

  @override
  String get aiTestStatusTesting => 'Testing';

  @override
  String get aiTestStatusAvailable => 'Available';

  @override
  String get aiTestStatusUnavailable => 'Unavailable';

  @override
  String get aiTestStatusConfigurationMissing => 'Configuration missing';

  @override
  String get aiTestStatusAuthenticationRequired => 'Authentication required';

  @override
  String get aiTestStatusAppCheckUnavailable => 'App Check unavailable';

  @override
  String get aiTestStatusGatewayUnavailable => 'Gateway unavailable';

  @override
  String get aiTestStatusModelUnavailable => 'Model unavailable';

  @override
  String get aiTestStatusOffline => 'Offline';

  @override
  String get aiTestStatusTimedOut => 'Timed out';

  @override
  String get aiTestStatusSuccess => 'Success';

  @override
  String get aiTestStatusProviderUnavailable => 'Provider unavailable';

  @override
  String get aiTestStatusAppCheckBlocked => 'App Check blocked';

  @override
  String get aiTestStatusRateLimited => 'Rate limited';

  @override
  String get aiTestStatusInvalidResponse => 'Invalid response';

  @override
  String get aiTestStatusNetworkFailure => 'Network failure';

  @override
  String get aiTestStatusFallbackUsed => 'Fallback used';

  @override
  String get aiLastCheckedLabel => 'Last checked';

  @override
  String get aiLiveTestLatencyLabel => 'Live-test latency';

  @override
  String aiLiveTestLatencyValue(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get aiNotCheckedYet => 'Not checked yet';

  @override
  String aiLastCheckedValue(String date, String time) {
    return '$date at $time';
  }

  @override
  String get aiTechnicalCodeLabel => 'Technical code';

  @override
  String get aiFallbackAvailabilityLabel => 'Safe local fallback';

  @override
  String get aiFallbackAvailable => 'Available';

  @override
  String get aiFallbackUnavailable => 'Unavailable';

  @override
  String get aiLiveProviderInactiveMessage =>
      'The configured remote text provider is inactive. No live AI request will be sent.';

  @override
  String get aiGroqLiveTestMessage =>
      'This test sends a small live request through the configured Groq gateway using the same authenticated provider path as AI chat. The prompt and response are not displayed or stored here.';

  @override
  String get aiRemoteProviderLiveTestMessage =>
      'This test sends a small live request through the configured remote provider using the same authenticated path as AI chat. The prompt and response are not displayed or stored here.';

  @override
  String get aiGroqNotConfiguredBuildMessage =>
      'Groq is not configured in this build.';

  @override
  String get aiNotTestedCurrentConfiguration =>
      'Not tested with the current configuration';

  @override
  String get aiLiveTestAvailableMessage =>
      'The Groq gateway, authentication, App Check, and streaming response are available.';

  @override
  String get testAiConnection => 'Test AI connection';

  @override
  String get testingAiConnection => 'Testing AI connection…';

  @override
  String get aiConnectionSuccess =>
      'Firebase AI Logic and App Check are ready.';

  @override
  String get aiProviderConnectionSuccess =>
      'The selected AI provider is ready.';

  @override
  String get aiConnectionFallbackReady =>
      'The local financial parser is ready. No remote AI request was used.';

  @override
  String aiConnectionFallbackAfterFailure(String reason) {
    return '$reason The safe local parser remains available.';
  }

  @override
  String get aiConnectionFailed =>
      'AI connection and local fallback are unavailable.';

  @override
  String get aiRateLimitedMessage =>
      'The AI request limit was reached. Please wait a moment and try again.';

  @override
  String get aiAppCheckBlockedMessage =>
      'App Check could not verify this app for AI access. Review the Firebase setup.';

  @override
  String get aiNetworkFailureMessage =>
      'CashPilot could not reach the AI service. Check your connection and try again.';

  @override
  String get aiProviderUnavailableMessage =>
      'The configured AI service is unavailable. The local parser will be used when possible.';

  @override
  String get aiLocalParserOnlyMessage =>
      'Remote AI is disabled in this build; the local financial parser is active.';

  @override
  String get aiInvalidResponseMessage =>
      'The AI response could not be verified, so it was not used.';

  @override
  String get aiRequestInFlightMessage =>
      'An AI request is already in progress.';

  @override
  String get aiRequestTooFastMessage =>
      'Please wait a moment before sending another AI request.';

  @override
  String get aiDuplicatePromptMessage =>
      'That same request was just sent. Please wait or change it before retrying.';

  @override
  String get aiGenericFailureMessage =>
      'CashPilot could not complete the AI request safely.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get preferences => 'Preferences';

  @override
  String get currency => 'Currency';

  @override
  String get currencyPendingMessage =>
      'Base currency preferences keep reports consistent across accounts.';

  @override
  String get backup => 'Backup';

  @override
  String get backupPendingMessage =>
      'Cloud backup is available for signed-in accounts.';

  @override
  String get cloudBackup => 'Cloud backup';

  @override
  String get cloudBackupEnabled => 'Cloud backup is enabled.';

  @override
  String get cloudBackupDisabled => 'Cloud backup is disabled.';

  @override
  String get backupOnlyDescription =>
      'Uploads queued local changes to your user-scoped cloud backup. Restore and cloud-to-device merge are not available yet.';

  @override
  String get guestBackupWarning =>
      'Sign in with a non-guest account to use cloud backup.';

  @override
  String get lastBackup => 'Last successful backup';

  @override
  String get neverBackedUp => 'No successful backup yet';

  @override
  String get pendingBackupItems => 'Pending backup items';

  @override
  String get failedBackupItems => 'Failed backup items';

  @override
  String get backupNow => 'Back up now';

  @override
  String get retryFailedBackup => 'Retry failed';

  @override
  String get backupNoPendingItems => 'Your backup queue is already up to date.';

  @override
  String backupSuccess(int count) {
    return 'Backed up $count items.';
  }

  @override
  String backupPartialFailure(int count) {
    return 'Backup finished with $count failed items.';
  }

  @override
  String get security => 'Security';

  @override
  String get biometricToggle => 'Biometric unlock';

  @override
  String get biometricPendingMessage =>
      'Device unlock keeps secure access fast on supported platforms.';

  @override
  String get securityPendingMessage =>
      'Email verification and session protection help keep the workspace secure.';

  @override
  String get about => 'About';

  @override
  String get aboutMessage =>
      'A premium local-first personal finance platform prepared for AI and cloud sync.';

  @override
  String get legalAndPrivacy => 'Legal and privacy';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privacyPolicySubtitle =>
      'Review how local data, cloud backup, AI, and deletion are handled.';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get termsOfUseSubtitle =>
      'Review the draft product-use terms and limitations.';

  @override
  String get policyDraftNoticeTitle => 'Draft product information';

  @override
  String get policyDraftNoticeMessage =>
      'This neutral placeholder requires legal review before any public release. It is not legal advice or a final policy.';

  @override
  String get privacyLocalDataTitle => 'Data on this device';

  @override
  String get privacyLocalDataMessage =>
      'Financial records are stored locally in the app database and remain the source of truth. The full account deletion flow also erases this local financial data and the pending backup queue on this device.';

  @override
  String get privacyCloudBackupTitle => 'Optional cloud backup';

  @override
  String get privacyCloudBackupMessage =>
      'Signed-in, non-guest users can opt in to a user-scoped Firestore backup. The current foundation uploads queued changes only; restore and cloud-to-device merge are not available.';

  @override
  String get privacyAiTitle => 'AI processing';

  @override
  String get privacyAiMessage =>
      'AI requests may send the message and limited context needed for the configured provider to respond. AI output can be incomplete or inaccurate, and financial actions still require explicit confirmation.';

  @override
  String get privacyDeletionTitle => 'Account and data deletion';

  @override
  String get privacyDeletionMessage =>
      'After explicit confirmation and any required reauthentication, Delete account removes known Firestore backup collections and the cloud profile, erases local financial records and account-specific preferences, then deletes the Firebase authentication profile. If a stage fails, later destructive stages are stopped so the operation can be retried safely.';

  @override
  String get termsPersonalUseTitle => 'Personal use';

  @override
  String get termsPersonalUseMessage =>
      'CashPilot AI is a personal record-keeping tool. You are responsible for reviewing entries, categories, balances, exchange rates, budgets, and goals for accuracy.';

  @override
  String get termsFinancialInfoTitle => 'Financial information';

  @override
  String get termsFinancialInfoMessage =>
      'Reports, forecasts, insights, and suggestions are informational product features. They are not financial, investment, tax, accounting, or legal advice.';

  @override
  String get termsAiTitle => 'AI-assisted actions';

  @override
  String get termsAiMessage =>
      'AI-generated interpretations may be wrong. Review every proposed action and its account, amount, currency, category, status, and exchange rate before confirmation.';

  @override
  String get termsAvailabilityTitle => 'Availability and backups';

  @override
  String get termsAvailabilityMessage =>
      'Offline local use can continue for supported features. Cloud backup may be delayed or unavailable and is not a substitute for a verified restore or export process.';

  @override
  String get aiFinancialDisclaimer =>
      'AI output may be inaccurate and is for information only, not financial advice. Review every action before confirming.';

  @override
  String get bootstrapFailureTitle => 'CashPilot AI could not start';

  @override
  String get bootstrapFailureMessage =>
      'A required local or Firebase service is unavailable. Check your connection and app configuration, then try again.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileGuestName => 'Local profile';

  @override
  String get profileLocalAccount => 'Stored on this device';

  @override
  String get profileBackendPendingTitle => 'Account profile';

  @override
  String get profileBackendPendingMessage =>
      'Manage identity, verification, and account preferences from your secure profile.';

  @override
  String get authDefaultSubtitle =>
      'Secure access for your financial workspace.';

  @override
  String get authSecureAccess => 'Secure access';

  @override
  String get authVerifiedSession => 'Verified session';

  @override
  String get authTermsPrivacy =>
      'By continuing, you agree to the Terms and acknowledge the Privacy Policy.';

  @override
  String get authCheckingSession => 'Checking secure session';

  @override
  String get onboardingTrackTitle => 'Track every account.';

  @override
  String get onboardingTrackMessage =>
      'Bring cash, cards, banks, and wallets into one calm financial cockpit.';

  @override
  String get onboardingAiTitle => 'AI Financial Assistant.';

  @override
  String get onboardingAiMessage =>
      'Ask smarter questions, review spending, and spot opportunities as your data grows.';

  @override
  String get onboardingInsightsTitle => 'Financial Insights.';

  @override
  String get onboardingInsightsMessage =>
      'Understand trends, budgets, and goals with polished reports built for decisions.';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get authWelcomeTitle => 'CashPilot AI';

  @override
  String get authWelcomeSubtitle =>
      'A secure personal finance workspace for accounts, cash flow, and AI-powered insights.';

  @override
  String get login => 'Log in';

  @override
  String get createAccount => 'Create account';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get loginHeadline => 'Welcome back';

  @override
  String get loginSubtitle =>
      'Sign in to continue your secure finance session.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get authInvalidForm => 'Check the highlighted fields and try again.';

  @override
  String get registerHeadline => 'Create your account';

  @override
  String get registerSubtitle =>
      'Start with secure sign-in and finish your profile in the next step.';

  @override
  String get name => 'Name';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get acceptTerms => 'I accept the Terms and Privacy Policy.';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we will send a secure reset link.';

  @override
  String get resetLinkSent => 'Reset link sent. Check your inbox to continue.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String get verifyEmailSubtitle =>
      'One quick confirmation keeps your account protected.';

  @override
  String get verifyEmailMessage =>
      'Open the verification link we sent, then refresh your status here.';

  @override
  String get resendEmail => 'Resend email';

  @override
  String get refreshStatus => 'Refresh status';

  @override
  String get verificationEmailSent => 'Verification email sent.';

  @override
  String get logout => 'Log out';

  @override
  String get profileCompletionTitle => 'Complete profile';

  @override
  String get profileCompletionSubtitle =>
      'Personalize CashPilot for your currency, language, and region.';

  @override
  String get displayName => 'Display name';

  @override
  String get preferredCurrency => 'Preferred currency';

  @override
  String get country => 'Country';

  @override
  String get timezone => 'Timezone';

  @override
  String get guestModeTitle => 'Guest mode';

  @override
  String get guestModeSubtitle =>
      'Explore the app with a temporary anonymous session.';

  @override
  String get guestModeLocalTitle => 'Local-first session';

  @override
  String get guestModeLocalMessage =>
      'You can explore the workspace without sharing personal details.';

  @override
  String get guestModeSyncTitle => 'Cloud sync limited';

  @override
  String get guestModeSyncMessage =>
      'Backup, multi-device sync, and recovery require a full account.';

  @override
  String get guestModeUpgradeTitle => 'Upgrade anytime';

  @override
  String get guestModeUpgradeMessage =>
      'Create an account later to unlock verification and protected recovery.';

  @override
  String get account => 'Account';

  @override
  String get guestAccount => 'Guest account';

  @override
  String get deleteAccountSettingsSubtitle =>
      'Permanently remove this account and all local and cloud financial data.';

  @override
  String get accountDataDeletionMessage =>
      'This permanently deletes the cloud backup, local financial records, pending backup queue, account preferences, and authentication profile. This action cannot be undone.';

  @override
  String get confirmFullDataDeletion =>
      'I understand that my account and all financial data will be permanently deleted.';

  @override
  String get passwordForEmailAccounts =>
      'Email/password accounts must enter the current password. Google and Apple accounts will open their provider confirmation.';

  @override
  String get dataDeletionInProgress => 'Deleting account and all data...';

  @override
  String get dataDeletionCompleted => 'Account and all data deleted.';

  @override
  String get dataDeletionConfirmationRequired =>
      'Confirm permanent deletion before continuing.';

  @override
  String get dataDeletionReauthFailed =>
      'We could not verify your identity. No data was deleted. Check your credentials and try again.';

  @override
  String get dataDeletionCloudFailed =>
      'Cloud deletion did not finish. Your account and local data were kept so you can retry safely.';

  @override
  String get dataDeletionLocalFailed =>
      'The cloud backup was removed, but local deletion failed. Your account was kept so you can retry.';

  @override
  String get dataDeletionPreferencesFailed =>
      'Financial records were removed, but account preferences could not be cleared. Your account was kept so you can retry.';

  @override
  String get dataDeletionAuthFailed =>
      'Your financial data was removed, but the authentication profile could not be deleted. Sign in again and retry.';

  @override
  String get verifiedAccount => 'Verified account';

  @override
  String get verifiedAccountMessage =>
      'Your email is verified and your session is protected.';

  @override
  String get profileCompletionSettingsSubtitle =>
      'Update display name, region, language, and currency.';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get dashboardErrorTitle => 'Could not load dashboard';

  @override
  String get dashboardErrorMessage => 'Refresh the page or try again later.';

  @override
  String get totalNetWorth => 'Total net worth';

  @override
  String get monthlyIncome => 'Monthly income';

  @override
  String get monthlyExpense => 'Monthly expense';

  @override
  String get monthlySavings => 'Monthly savings';

  @override
  String get yearlyIncome => 'Yearly income';

  @override
  String get yearlyExpense => 'Yearly expense';

  @override
  String get yearlySavings => 'Yearly savings';

  @override
  String get recentTransactions => 'Recent transactions';

  @override
  String get spendingChart => 'Spending chart';

  @override
  String get spendingChartSubtitle => 'Top expense categories this month.';

  @override
  String get noSpendingYet => 'No spending yet';

  @override
  String get noSpendingYetMessage => 'Posted expenses will appear here.';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get viewAll => 'View all';

  @override
  String get openBudgets => 'Open budgets';

  @override
  String get openGoals => 'Open goals';

  @override
  String get transfer => 'Transfer';

  @override
  String get transferHistory => 'Transfer history';

  @override
  String get transferScreenSubtitle =>
      'Move money between your accounts with a clear review before posting.';

  @override
  String get transferBackendPendingTitle => 'Transfer workspace';

  @override
  String get transferBackendPendingMessage =>
      'Review source and destination accounts before posting a paired transfer.';

  @override
  String get transferExchangeRequiredTitle => 'Exchange amount required';

  @override
  String get transferExchangeRequiredMessage =>
      'These accounts use different currencies. Enter the amount received by the destination account.';

  @override
  String get fromAccount => 'From account';

  @override
  String get toAccount => 'To account';

  @override
  String get destinationAmount => 'Destination amount';

  @override
  String get transferPreviewTitle => 'Transfer preview';

  @override
  String get transferPreviewSubtitle =>
      'Check the exact account and currency effect before creating this transfer.';

  @override
  String get manualConversionBadge => 'Manual conversion';

  @override
  String get manualExchangeRateLabel => 'Implied manual rate';

  @override
  String get exchangeRatesTitle => 'Exchange rates';

  @override
  String get exchangeRatesSubtitle =>
      'Manual rates used for conversion and consolidated reporting.';

  @override
  String get baseCurrency => 'Base currency';

  @override
  String get addExchangeRate => 'Add exchange rate';

  @override
  String get editExchangeRate => 'Edit exchange rate';

  @override
  String get deleteExchangeRate => 'Delete exchange rate';

  @override
  String get archiveExchangeRate => 'Archive exchange rate';

  @override
  String get archiveExchangeRateConfirm =>
      'Archived rates are no longer used for conversions or consolidated totals.';

  @override
  String get fromCurrency => 'From currency';

  @override
  String get toCurrency => 'To currency';

  @override
  String get exchangeRate => 'Rate';

  @override
  String get manualRate => 'Manual rate';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get missingExchangeRateTitle => 'Missing exchange rate';

  @override
  String get missingExchangeRateDescription =>
      'Some totals are partial because a required currency pair has no active manual rate.';

  @override
  String get conversionFailed => 'Currency conversion failed.';

  @override
  String get sameCurrencyNotAllowed => 'Choose two different currencies.';

  @override
  String get invalidExchangeRate => 'Enter a rate greater than zero.';

  @override
  String get exchangeRateSaved => 'Exchange rate saved.';

  @override
  String get exchangeRateDeleted => 'Exchange rate deleted.';

  @override
  String get exchangeRateArchived => 'Exchange rate archived.';

  @override
  String get netWorthPartiallyCalculated =>
      'Net worth is partially calculated.';

  @override
  String get addRateToContinue =>
      'Add the missing manual rate to complete these totals.';

  @override
  String get selectBaseCurrency =>
      'Select the currency used for consolidated totals.';

  @override
  String get convertedTotal => 'Converted total';

  @override
  String get originalCurrency => 'Original currency';

  @override
  String get rateUsed => 'Rate used';

  @override
  String get suggestedStoredRate => 'Suggested stored manual rate';

  @override
  String get enterExchangeRate => 'Enter exchange rate';

  @override
  String get exchangeRateRequired =>
      'An exchange rate or destination amount is required.';

  @override
  String get noExchangeRatesTitle => 'No manual rates yet';

  @override
  String get noExchangeRatesMessage =>
      'Add a rate when you need to convert balances or transactions between currencies.';

  @override
  String get exchangeRatesErrorTitle => 'Could not load exchange rates';

  @override
  String get ratesAreManualNotice =>
      'Rates are entered manually and are never fetched or guessed automatically.';

  @override
  String get includeArchivedRates => 'Include archived rates';

  @override
  String get archivedRate => 'Archived';

  @override
  String get destinationAmountRequired =>
      'Enter the destination amount to complete this preview.';

  @override
  String get transferPostedEffectMessage =>
      'Posted transfers update both account balances immediately.';

  @override
  String get transferPendingEffectMessage =>
      'Pending transfers are recorded without changing either balance.';

  @override
  String get transferSafetyTitle => 'Review before creating';

  @override
  String get transferSafetyMessage =>
      'CashPilot creates one linked transfer pair after you submit. Cross-currency amounts are entered manually.';

  @override
  String get createTransfer => 'Create transfer';

  @override
  String get transferCreatedMessage => 'Transfer created.';

  @override
  String get transferFailedMessage => 'Transfer failed.';

  @override
  String get transferCannotBeEditedMessage =>
      'Transfers cannot be edited directly.';

  @override
  String get transferCannotBeDeletedMessage =>
      'This transfer cannot be deleted safely.';

  @override
  String get postedTransferCannotBeDeletedMessage =>
      'Posted transfers cannot be deleted. Cancel the transfer to reverse it.';

  @override
  String get missingExchangeRateMessage =>
      'Enter a destination amount or a valid exchange rate.';

  @override
  String get invalidTransferStateMessage =>
      'This transfer is incomplete or in an invalid state.';

  @override
  String get transferIntegrityReviewMessage =>
      'Transfer history needs manual review before any new financial changes.';

  @override
  String get transferReference => 'Transfer reference';

  @override
  String get cancelTransfer => 'Cancel transfer';

  @override
  String get transferCancelledMessage => 'Transfer cancelled.';

  @override
  String get confirm => 'Confirm';

  @override
  String get aiActionConfirmationTitle => 'Review AI action';

  @override
  String get aiActionConfirmationMessage =>
      'CashPilot will only save this after you confirm.';

  @override
  String get aiAwaitingConfirmationStatus => 'Awaiting confirmation';

  @override
  String get aiExecutingStatus => 'Executing securely';

  @override
  String get aiExecutedStatus => 'Executed';

  @override
  String get aiConfirmationSafetyTitle => 'Nothing happens before you confirm';

  @override
  String get aiConfirmationSafetyMessage =>
      'Review the details below. CashPilot executes this action once, only after confirmation.';

  @override
  String get aiActionConfirmedMessage => 'AI action saved.';

  @override
  String get aiActionCancelledMessage => 'AI action cancelled.';

  @override
  String get aiActionInvalidMessage =>
      'This AI draft needs review before it can be saved.';

  @override
  String get aiAmbiguousAccountMessage => 'Which account should I use?';

  @override
  String get aiActionAlreadyExecutedMessage =>
      'This AI action has already been executed.';

  @override
  String get aiClarificationTitle => 'Clarification needed';

  @override
  String get aiActionExpenseTitle => 'Expense draft';

  @override
  String get aiActionIncomeTitle => 'Income draft';

  @override
  String get aiActionTransferTitle => 'Transfer draft';

  @override
  String get aiActionQuestionTitle => 'Question';

  @override
  String get aiDetectedItem => 'Detected item';

  @override
  String get aiSuggestedCategory => 'Suggested category';

  @override
  String get aiCategoryConfidenceHigh => 'High confidence';

  @override
  String get aiCategoryConfidenceSuggested => 'Suggested';

  @override
  String get aiCategoryConfidenceNeedsChoice => 'Needs your choice';

  @override
  String get aiCategorySourceExplicit => 'Chosen from your message';

  @override
  String get aiCategorySourceUserRule => 'Your saved rule';

  @override
  String get aiCategorySourcePayee => 'Payee default';

  @override
  String get aiCategorySourceAlias => 'Item match';

  @override
  String get aiCategorySourceAi => 'Semantic suggestion';

  @override
  String get aiCategorySourceKeyword => 'Local keyword match';

  @override
  String get aiCategorySourceFallback => 'No confident match';

  @override
  String get aiEditCategory => 'Edit category';

  @override
  String get aiIncomeSourceType => 'Income source type';

  @override
  String get aiIncomeSourceName => 'From';

  @override
  String get aiIncomeSourceIdentityHint =>
      'Enter the person or organization the money came from';

  @override
  String get aiIncomeDestinationAccount => 'Destination account';

  @override
  String get aiRecordIncomeOffer =>
      'It sounds like money came in. Would you like to record it?';

  @override
  String get aiRecordTransactionOffer =>
      'Would you like to record this financial activity?';

  @override
  String get aiRecordIncomeOfferCancelled =>
      'Okay — I did not record anything.';

  @override
  String get aiIncomeMissingDetails =>
      'Before I can prepare the preview, choose the receiving account, source classification, category, and transaction date, and identify the source when requested.';

  @override
  String get aiIncomeSpecialReviewTitle => 'Review this inflow carefully';

  @override
  String get aiIncomeLoanWarning =>
      'Loan proceeds increase cash but are a liability, not earned income.';

  @override
  String get aiIncomeDebtRepaymentWarning =>
      'A debt repayment returns money owed to you and is not new earned income.';

  @override
  String get aiIncomeRefundWarning =>
      'This is money returned from a purchase, not new earned income.';

  @override
  String get aiIncomeReimbursementWarning =>
      'This repays an earlier expense and remains separate from salary or business revenue.';

  @override
  String get aiIncomeExternalTransferWarning =>
      'Clarify whether this external transfer is a gift, reimbursement, sale, salary, or another source.';

  @override
  String get aiIncomeOtherWarning =>
      'Confirm the source type before saving this inflow.';

  @override
  String get incomeSourceSalary => 'Salary';

  @override
  String get incomeSourceFreelance => 'Freelance';

  @override
  String get incomeSourceBusinessRevenue => 'Business revenue';

  @override
  String get incomeSourceGift => 'Gift';

  @override
  String get incomeSourceDebtRepayment => 'Debt repayment';

  @override
  String get incomeSourceAllowance => 'Allowance';

  @override
  String get incomeSourceRefund => 'Refund';

  @override
  String get incomeSourceSale => 'Sale proceeds';

  @override
  String get incomeSourceRentalIncome => 'Rental income';

  @override
  String get incomeSourceGovernmentSupport => 'Government support';

  @override
  String get incomeSourceScholarship => 'Scholarship';

  @override
  String get incomeSourceInvestmentReturn => 'Investment return';

  @override
  String get incomeSourceReimbursement => 'Reimbursement';

  @override
  String get incomeSourcePrize => 'Prize';

  @override
  String get incomeSourceLoanProceeds => 'Loan proceeds';

  @override
  String get incomeSourceExternalTransfer => 'External transfer';

  @override
  String get incomeSourceOther => 'Other';

  @override
  String get statistics => 'Statistics';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get archive => 'Archive';

  @override
  String get sort => 'Sort';

  @override
  String get all => 'All';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get pending => 'Pending';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortOldest => 'Oldest';

  @override
  String get sortAmountHigh => 'Highest amount';

  @override
  String get resultsLabel => 'Results';

  @override
  String get zero => '0';

  @override
  String get switchLanguageTooltip => 'Switch language';

  @override
  String get switchThemeTooltip => 'Switch theme';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundMessage =>
      'The requested destination is not available.';

  @override
  String get addPayee => 'Add payee';

  @override
  String get editPayee => 'Edit payee';

  @override
  String get archivePayee => 'Archive payee';

  @override
  String get restorePayee => 'Restore payee';

  @override
  String get payeeName => 'Payee name';

  @override
  String get payeeNameRequired => 'Payee name is required.';

  @override
  String get selectPayee => 'Payee';

  @override
  String get noPayee => 'No payee';

  @override
  String get payeeType => 'Payee type';

  @override
  String get payeeAliases => 'Aliases';

  @override
  String get payeeAliasesHint => 'Separate aliases with commas';

  @override
  String get payeeDefaultCategory => 'Default category';

  @override
  String get payeeDefaultAccount => 'Default account';

  @override
  String get payeeNotes => 'Notes';

  @override
  String get payeeTypeMerchant => 'Merchant';

  @override
  String get payeeTypePerson => 'Person';

  @override
  String get payeeTypeEmployer => 'Employer';

  @override
  String get payeeTypeBank => 'Bank';

  @override
  String get payeeTypePaymentService => 'Payment service';

  @override
  String get payeeTypeUtility => 'Utility';

  @override
  String get payeeTypeTelecom => 'Telecom';

  @override
  String get payeeTypeGovernment => 'Government';

  @override
  String get payeeTypeSchool => 'School';

  @override
  String get payeeTypeOther => 'Other';

  @override
  String get payeeAlreadyExists => 'A payee with this name already exists.';

  @override
  String get aliasAlreadyExists =>
      'This alias is already assigned to another payee.';

  @override
  String get ambiguousPayee => 'Which payee did you mean?';

  @override
  String get payeeNotFound => 'Payee not found.';

  @override
  String get createNewPayeeSuggestion =>
      'No matching payee was found. You can create one after reviewing the transaction.';

  @override
  String get payeeArchivedMessage => 'Payee archived.';

  @override
  String get payeeRestoredMessage => 'Payee restored.';

  @override
  String get payeeSavedMessage => 'Payee saved.';

  @override
  String get includeArchivedPayees => 'Include archived';

  @override
  String get archivedPayee => 'Archived';

  @override
  String get filterByType => 'Filter by type';

  @override
  String get allPayeeTypes => 'All types';

  @override
  String get noDefaultSelection => 'No default';

  @override
  String get lastUsed => 'Last used';

  @override
  String get neverUsed => 'Never used';

  @override
  String get relatedTransactions => 'Related transactions';

  @override
  String get scanReceipt => 'Scan receipt';

  @override
  String get receiptScannerTitle => 'Receipt scanner';

  @override
  String get receiptScannerSubtitle =>
      'Capture a receipt or import an image, then review every extracted value.';

  @override
  String get takeReceiptPhoto => 'Take photo';

  @override
  String get importReceiptImage => 'Import image';

  @override
  String get documentScannerUnavailable =>
      'Document scanner is unavailable on this device.';

  @override
  String get receiptPrivacyTitle => 'Send this receipt to Firebase AI?';

  @override
  String get receiptPrivacyMessage =>
      'The selected receipt image is sent to Firebase AI for extraction. Images can contain merchant, purchase, tax, or address details. CashPilot does not send account balances or transaction history with it. Review all results before confirming.';

  @override
  String get analyzeReceipt => 'Analyze receipt';

  @override
  String get manualReceiptReview => 'Review manually';

  @override
  String get receiptReviewTitle => 'Review receipt';

  @override
  String get receiptReviewSubtitle =>
      'AI extraction may be inaccurate. Nothing is saved as a transaction until you confirm.';

  @override
  String get receiptMerchant => 'Merchant';

  @override
  String get receiptDocumentType => 'Document type';

  @override
  String get receiptPaymentStatus => 'Payment status';

  @override
  String get receiptPurchaseDate => 'Purchase date';

  @override
  String get receiptSubtotal => 'Subtotal';

  @override
  String get receiptTax => 'Tax';

  @override
  String get receiptDiscount => 'Discount';

  @override
  String get receiptTip => 'Tip';

  @override
  String get receiptTotal => 'Total';

  @override
  String get receiptLineItems => 'Line items';

  @override
  String get receiptAddLineItem => 'Add line item';

  @override
  String get receiptWarnings => 'Warnings';

  @override
  String get receiptKeepImage => 'Keep image locally';

  @override
  String get receiptDeleteImage => 'Delete image after extraction';

  @override
  String get receiptRetentionRequired =>
      'Choose what CashPilot should do with the local image.';

  @override
  String get receiptWarningsAcknowledgement =>
      'I reviewed the warnings and extracted values.';

  @override
  String get receiptSaveDraft => 'Save draft';

  @override
  String get receiptConfirmTransaction => 'Confirm transaction';

  @override
  String get receiptCreatedMessage => 'Receipt transaction created.';

  @override
  String get receiptSavedMessage => 'Receipt draft saved.';

  @override
  String get receiptNoAccounts =>
      'Add an account before confirming this receipt.';

  @override
  String get receiptNoItems =>
      'Add or review line items and categories before confirming.';

  @override
  String get receiptDuplicateWarning =>
      'A possible duplicate receipt or transaction was found.';

  @override
  String get receiptAnalysisProgress => 'Analyzing the receipt securely…';

  @override
  String get receiptPreparingProgress => 'Preparing the receipt image…';

  @override
  String get receiptSavingDraftProgress => 'Saving a private review draft…';

  @override
  String get receiptLoadingContextProgress =>
      'Preparing categories and accounts for review…';

  @override
  String get aiLocalGreeting =>
      'Hi! How can I help today? Ask what I can do to see the capabilities currently available.';

  @override
  String get aiLocalSmallTalk =>
      'I’m doing well, thanks! What can I help you with today?';

  @override
  String get aiCapabilityLocal =>
      'I can answer greetings, help, and capability questions locally without a network call.';

  @override
  String get aiCapabilityGeneralChat =>
      'General questions are configured through a remote provider; each request still verifies availability.';

  @override
  String get aiCapabilityCurrentKnowledge =>
      'Current-information lookup is configured with sources; each request still verifies availability.';

  @override
  String get aiCapabilityPersonalFinance =>
      'When owner scope and consent remain valid, I can analyze the CashPilot financial data you allow.';

  @override
  String get aiCapabilityFinancialDrafts =>
      'I can prepare reviewable financial drafts.';

  @override
  String get aiCapabilityReceiptVision =>
      'Receipt image analysis is configured after your consent; each request still verifies availability.';

  @override
  String get aiCapabilityNavigation =>
      'I can open supported CashPilot screens when you ask.';

  @override
  String get aiCapabilityFinancialDisabled =>
      'Personal financial analysis and actions are currently disabled.';

  @override
  String get aiCapabilityConfirmationRequired =>
      'No financial change happens without your review and confirmation.';

  @override
  String get aiUnavailablePlatformNotConfigured =>
      'General conversation is not configured on this platform. Local greetings and help are still available.';

  @override
  String get aiUnavailableFirebaseNotInitialized =>
      'General conversation could not start because Firebase is not ready. Check the app setup and try again.';

  @override
  String get aiUnavailableFirebaseAi =>
      'The configured conversation model is currently unavailable.';

  @override
  String get aiUnavailableAppCheck =>
      'Device verification is getting ready. Try again in a moment.';

  @override
  String get aiUnavailableAppCheckTimedOut =>
      'Device verification took too long. Check your connection and try again.';

  @override
  String get aiUnavailableAppCheckRejected =>
      'This development build could not be verified on this device. Check the emulator\'s App Check registration.';

  @override
  String get aiUnavailableAuthenticationNotReady =>
      'Your sign-in is still getting ready. Try again in a moment.';

  @override
  String get aiUnavailableAuthentication =>
      'Sign in to use general conversation. Greetings and help remain available locally.';

  @override
  String get aiUnavailableGatewayDisabled =>
      'No general-conversation provider is enabled. Local greetings and help are still available.';

  @override
  String get aiUnavailableGatewayUrlMissing =>
      'The conversation gateway address is not configured, and no fallback provider is available.';

  @override
  String get aiUnavailableGatewayUnreachable =>
      'The conversation service could not be reached. Check your connection and try again.';

  @override
  String get aiUnavailableOffline =>
      'You appear to be offline. Check your internet connection and try again.';

  @override
  String get aiUnavailableProviderTimedOut =>
      'The conversation service took too long to respond. Try again.';

  @override
  String get aiUnavailableProviderRejected =>
      'The conversation service rejected this request safely. Rephrase it or try again.';

  @override
  String get aiUnavailableFinancialAccess =>
      'Access to personal financial analysis is currently disabled.';

  @override
  String get aiUnavailableOwnerScope =>
      'Your private CashPilot data is not ready for this request. General conversation and local help may still be available.';

  @override
  String get aiUnavailableLegacyData =>
      'Personal financial analysis is paused until the legacy-data ownership check is resolved.';

  @override
  String get aiUnavailableReceiptVision =>
      'Receipt image analysis is currently unavailable. You can still review the receipt manually.';

  @override
  String get aiUnavailableTemporary =>
      'The conversation could not be completed temporarily. Try again.';

  @override
  String get aiFinancialAnalysisUnavailableWithGeneral =>
      'General conversation is available, but analysis of your financial data is currently disabled.';

  @override
  String get aiFinancialAnalysisUnavailable =>
      'Analysis of your financial data is currently disabled.';

  @override
  String get aiNavigationUnavailable =>
      'Assistant navigation is currently disabled. Open the requested screen from the app menu.';

  @override
  String get aiDiagnosticCodeLabel => 'Diagnostic code';

  @override
  String get aiOfflineInflationAnswer =>
      'Inflation is a broad, sustained rise in prices over time, which means the same amount of money buys less. It is commonly measured by tracking the changing cost of a basket of goods and services such as food, housing, and transport.';

  @override
  String get aiOfflineTunisiaCapitalAnswer =>
      'The capital of Tunisia is Tunis.';

  @override
  String get expenseAnalyticsTitle => 'Expense analysis';

  @override
  String get expenseAnalyticsThisWeek => 'This week';

  @override
  String get expenseAnalyticsThisMonth => 'This month';

  @override
  String get expenseAnalyticsViewDetails => 'View details';

  @override
  String get expenseAnalyticsTotal => 'Total expenses';

  @override
  String get expenseAnalyticsPartialTotal => 'Partial total';

  @override
  String get expenseAnalyticsOther => 'Other';

  @override
  String get expenseAnalyticsEmpty =>
      'No expenses were recorded in this period.';

  @override
  String get expenseAnalyticsErrorTitle => 'Could not load expense analysis';

  @override
  String get expenseAnalyticsErrorMessage =>
      'Your other Home information is still available. Try this card again.';

  @override
  String get expenseAnalyticsPartialWarning =>
      'Some expenses are not included in the total because an exchange rate is unavailable.';

  @override
  String get expenseAnalyticsNoPreviousData =>
      'No previous-period data is available.';

  @override
  String get expenseAnalyticsComparisonUnavailable =>
      'The comparison is unavailable because some exchange rates are missing.';

  @override
  String get expenseAnalyticsLastWeek => 'last week';

  @override
  String get expenseAnalyticsLastMonth => 'last month';

  @override
  String expenseAnalyticsIncreasedComparison(String percentage, String period) {
    return 'Spending increased by $percentage compared with $period.';
  }

  @override
  String expenseAnalyticsDecreasedComparison(String percentage, String period) {
    return 'Spending decreased by $percentage compared with $period.';
  }

  @override
  String expenseAnalyticsUnchangedComparison(String period) {
    return 'Spending is unchanged compared with $period.';
  }

  @override
  String expenseAnalyticsSemanticsSummary(
    String period,
    String total,
    String category,
    String categoryAmount,
    String percentage,
  ) {
    return 'Total expenses $period are $total. The highest category is $category at $categoryAmount, representing $percentage.';
  }

  @override
  String expenseAnalyticsLegendSemantics(
    String category,
    String amount,
    String percentage,
  ) {
    return '$category, $amount, $percentage.';
  }

  @override
  String get aiFinancialPreviewTitle => 'Review transaction';

  @override
  String get aiFinancialPreviewSubtitle =>
      'Only these fields will be stored after you confirm.';

  @override
  String get aiFinancialPreviewType => 'Type';

  @override
  String get aiFinancialPreviewDescription => 'Description';

  @override
  String get aiFinancialPreviewSuggestedCategory => 'Suggested category';

  @override
  String get aiFinancialPreviewDate => 'Date';

  @override
  String get aiFinancialPreviewStorageEffect => 'What will be saved';

  @override
  String get aiFinancialPreviewToday => 'Today';

  @override
  String get aiFinancialPreviewReject => 'Cancel';

  @override
  String get aiFinancialPreviewConfirm => 'Confirm';

  @override
  String get aiFinancialPreviewRejected =>
      'Operation cancelled. Nothing was saved.';

  @override
  String get aiFinancialPreviewCategoryAssumption =>
      'The category is a suggestion based on the transaction wording.';

  @override
  String aiFinancialPreviewPostedExpenseEffect(String amount, String account) {
    return 'One posted expense will be saved. $amount will be deducted from $account.';
  }

  @override
  String aiFinancialPreviewPostedIncomeEffect(String amount, String account) {
    return 'One posted income transaction will be saved. $amount will be added to $account.';
  }

  @override
  String get aiFinancialPreviewPendingEffect =>
      'One pending transaction will be saved. The balance will not change until it is posted.';

  @override
  String get aiFinancialExpenseSaved => 'Expense recorded';

  @override
  String get aiFinancialIncomeSaved => 'Income recorded';

  @override
  String aiFinancialSavedSummary(String amount, String description) {
    return '$amount — $description';
  }

  @override
  String aiFinancialSavedCategory(String category) {
    return 'Category: $category';
  }

  @override
  String aiFinancialSavedAccount(String account) {
    return 'Account: $account';
  }

  @override
  String aiFinancialSavedDate(String date) {
    return 'Date: $date';
  }

  @override
  String aiFinancialSavedStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get aiExpenseAccountClarification =>
      'Which account should this expense use?';

  @override
  String get aiFinancialActionsDisabledTitle =>
      'Financial actions are disabled for this account.';

  @override
  String get aiFinancialActionsDisabledBody =>
      'Enable Review Before Execution or Full Control from AI Settings.';

  @override
  String get aiOpenAiSettings => 'Open AI Settings';

  @override
  String get aiControlOffFailure =>
      'AI app control is not enabled for this account. Enable it in Settings. No change was made.';

  @override
  String get aiTransactionDraftsDisabledFailure =>
      'The selected AI control level does not allow transaction drafts. No change was made.';

  @override
  String get aiConfirmedExecutionDisabledFailure =>
      'Confirmed financial execution is unavailable in this build. No change was made.';

  @override
  String get aiOwnerScopeNotReadyFailure =>
      'Your account data is not ready for this financial action. Try again after account loading finishes. No change was made.';

  @override
  String get aiLegacyDataUnresolvedFailure =>
      'Link the existing local data to this account before creating a financial draft. No change was made.';

  @override
  String get aiLegacyPolicyUnresolvedFailure =>
      'Complete this account\'s AI control policy migration in Settings. No change was made.';

  @override
  String get aiStaleControlFailure =>
      'AI control settings changed while this draft was open. Review the current settings and try again. No change was made.';

  @override
  String get aiGenericDraftPermissionFailure =>
      'AI app control does not allow this financial draft. No change was made.';

  @override
  String get aiOpenSettings => 'Open Settings';

  @override
  String get aiFinancialWriteFailure =>
      'Saving failed. No transaction was saved and no balance changed. Try again.';

  @override
  String get aiStalePreviewFailure =>
      'This transaction preview is stale. Create a new preview and review it again.';

  @override
  String get aiDuplicateExecutionFailure =>
      'This transaction was already submitted. No duplicate was created.';

  @override
  String get aiFinancialVerificationFailure =>
      'CashPilot could not verify the saved transaction. No success was reported.';

  @override
  String get aiInvalidFinancialDraftFailure =>
      'The transaction details are no longer valid. Review them and try again.';
}
