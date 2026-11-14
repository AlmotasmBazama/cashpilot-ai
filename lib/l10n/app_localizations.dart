import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @aiUnsupportedPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'I could not complete that request. Try rephrasing it, or ask another safe question.'**
  String get aiUnsupportedPromptMessage;

  /// No description provided for @aiGreetingResponse.
  ///
  /// In en, this message translates to:
  /// **'Hi! How can I help today? You can ask a general question, review your spending, or prepare a new transaction.'**
  String get aiGreetingResponse;

  /// No description provided for @aiSmallTalkResponse.
  ///
  /// In en, this message translates to:
  /// **'I’m doing well, thanks! What can I help you with today?'**
  String get aiSmallTalkResponse;

  /// No description provided for @aiHelpResponse.
  ///
  /// In en, this message translates to:
  /// **'Ask any safe general question, request current information with sources, review your CashPilot data, or describe a financial action. Financial changes always wait for your review and confirmation.'**
  String get aiHelpResponse;

  /// No description provided for @aiCapabilitiesResponse.
  ///
  /// In en, this message translates to:
  /// **'I can answer general questions, explain concepts, find current information with sources, analyze your CashPilot data, and prepare reviewable transaction, budget, and goal drafts.'**
  String get aiCapabilitiesResponse;

  /// No description provided for @aiUnsupportedConversationResponse.
  ///
  /// In en, this message translates to:
  /// **'I could not complete that request, but you can rephrase it or ask another safe question.'**
  String get aiUnsupportedConversationResponse;

  /// No description provided for @aiDestructiveRequestBlockedResponse.
  ///
  /// In en, this message translates to:
  /// **'I can’t delete financial records, change balances directly, or bypass confirmation. I can help you prepare a safe reviewable action instead.'**
  String get aiDestructiveRequestBlockedResponse;

  /// No description provided for @aiAssistantResponseTitle.
  ///
  /// In en, this message translates to:
  /// **'CashPilot assistant'**
  String get aiAssistantResponseTitle;

  /// No description provided for @aiFinancialQuestionLocalResponse.
  ///
  /// In en, this message translates to:
  /// **'I recognized this as a financial question, not a transaction. CashPilot answers supported totals, budgets, goals, and currency conversions from local data without sending transaction history to Gemini. Add a period or category if you need a more specific answer.'**
  String get aiFinancialQuestionLocalResponse;

  /// No description provided for @aiSearchingCurrentInformation.
  ///
  /// In en, this message translates to:
  /// **'Searching for current information…'**
  String get aiSearchingCurrentInformation;

  /// No description provided for @aiSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get aiSources;

  /// No description provided for @aiUpdatedAsOf.
  ///
  /// In en, this message translates to:
  /// **'Current as of'**
  String get aiUpdatedAsOf;

  /// No description provided for @aiUnableVerifyCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current information could not be verified.'**
  String get aiUnableVerifyCurrent;

  /// No description provided for @aiReviewingYourData.
  ///
  /// In en, this message translates to:
  /// **'Reviewing your data…'**
  String get aiReviewingYourData;

  /// No description provided for @aiComparingPeriods.
  ///
  /// In en, this message translates to:
  /// **'Comparing periods…'**
  String get aiComparingPeriods;

  /// No description provided for @aiPreparingDraft.
  ///
  /// In en, this message translates to:
  /// **'Preparing a reviewable draft…'**
  String get aiPreparingDraft;

  /// No description provided for @aiGeneralUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The general assistant is temporarily unavailable. Please try again shortly.'**
  String get aiGeneralUnavailable;

  /// No description provided for @aiGroundedAnswer.
  ///
  /// In en, this message translates to:
  /// **'Grounded current answer'**
  String get aiGroundedAnswer;

  /// No description provided for @aiJumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get aiJumpToLatest;

  /// No description provided for @aiStopGenerating.
  ///
  /// In en, this message translates to:
  /// **'Stop generating'**
  String get aiStopGenerating;

  /// No description provided for @aiCopyResponse.
  ///
  /// In en, this message translates to:
  /// **'Copy response'**
  String get aiCopyResponse;

  /// No description provided for @aiRetryResponse.
  ///
  /// In en, this message translates to:
  /// **'Retry response'**
  String get aiRetryResponse;

  /// No description provided for @aiNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get aiNewConversation;

  /// No description provided for @aiClearConversation.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get aiClearConversation;

  /// No description provided for @aiClearConversationConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear every message in this conversation? This cannot be undone.'**
  String get aiClearConversationConfirmation;

  /// No description provided for @aiCurrentInfoMayChange.
  ///
  /// In en, this message translates to:
  /// **'Current information may change; review the linked sources.'**
  String get aiCurrentInfoMayChange;

  /// No description provided for @aiDraftToolsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Action drafting is temporarily unavailable. No financial change was made.'**
  String get aiDraftToolsUnavailable;

  /// No description provided for @aiAskAnotherQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ask another question'**
  String get aiAskAnotherQuestion;

  /// No description provided for @aiSelectDestinationAccount.
  ///
  /// In en, this message translates to:
  /// **'Select the account that received this income'**
  String get aiSelectDestinationAccount;

  /// No description provided for @aiEvidenceCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'Based on this month’s CashPilot data'**
  String get aiEvidenceCurrentMonth;

  /// No description provided for @aiEvidenceComparedPrior.
  ///
  /// In en, this message translates to:
  /// **'Compared with the previous month'**
  String get aiEvidenceComparedPrior;

  /// No description provided for @aiSearchEntryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Search follow-up suggestions are unavailable on this platform.'**
  String get aiSearchEntryUnavailable;

  /// No description provided for @promptWhatIsInflation.
  ///
  /// In en, this message translates to:
  /// **'What is inflation?'**
  String get promptWhatIsInflation;

  /// No description provided for @promptCurrentLibyaEconomy.
  ///
  /// In en, this message translates to:
  /// **'How is Libya’s economy currently?'**
  String get promptCurrentLibyaEconomy;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CashPilot AI'**
  String get appTitle;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Finance workspace'**
  String get homeHeadline;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your finance modules are ready to be built.'**
  String get homeSubtitle;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navDashboard;

  /// No description provided for @secureLocalFirst.
  ///
  /// In en, this message translates to:
  /// **'Local-first, finance-grade foundation'**
  String get secureLocalFirst;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balances and linked wallets'**
  String get accountsSubtitle;

  /// No description provided for @accountsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsScreenTitle;

  /// No description provided for @accountsScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track balances across cash, cards, banks, and wallets.'**
  String get accountsScreenSubtitle;

  /// No description provided for @activeAccountsLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeAccountsLabel;

  /// No description provided for @archivedAccountsLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedAccountsLabel;

  /// No description provided for @trackedCurrenciesLabel.
  ///
  /// In en, this message translates to:
  /// **'Currencies'**
  String get trackedCurrenciesLabel;

  /// No description provided for @archivedAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedAccountLabel;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccount;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @archiveAccount.
  ///
  /// In en, this message translates to:
  /// **'Archive account'**
  String get archiveAccount;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get accountType;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountTypeBank;

  /// No description provided for @accountTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get accountTypeCreditCard;

  /// No description provided for @accountTypeDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get accountTypeDebitCard;

  /// No description provided for @accountTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountTypeSavings;

  /// No description provided for @accountTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountTypeInvestment;

  /// No description provided for @accountTypeDigitalWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital wallet'**
  String get accountTypeDigitalWallet;

  /// No description provided for @accountTypeCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get accountTypeCrypto;

  /// No description provided for @accountTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get accountTypeOther;

  /// No description provided for @currencyCode.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyCode;

  /// No description provided for @accountCurrencyLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Currency is locked after account creation to keep balances and history accurate.'**
  String get accountCurrencyLockedMessage;

  /// No description provided for @openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get openingBalance;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalance;

  /// No description provided for @accountIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get accountIcon;

  /// No description provided for @accountColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get accountColor;

  /// No description provided for @accountPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get accountPaymentMethods;

  /// No description provided for @accountPaymentMethodsHint.
  ///
  /// In en, this message translates to:
  /// **'Link Libyan payment services that belong to this account.'**
  String get accountPaymentMethodsHint;

  /// No description provided for @accountNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Account name is required.'**
  String get accountNameRequired;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get invalidAmount;

  /// No description provided for @invalidCurrencyCode.
  ///
  /// In en, this message translates to:
  /// **'Use a 3-letter currency code.'**
  String get invalidCurrencyCode;

  /// No description provided for @selectAccountType.
  ///
  /// In en, this message translates to:
  /// **'Select account type'**
  String get selectAccountType;

  /// No description provided for @emptyAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get emptyAccountsTitle;

  /// No description provided for @emptyAccountsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your first account to start tracking balances.'**
  String get emptyAccountsMessage;

  /// No description provided for @accountsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load accounts'**
  String get accountsErrorTitle;

  /// No description provided for @accountsErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh the page or try again later.'**
  String get accountsErrorMessage;

  /// No description provided for @accountCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Account created.'**
  String get accountCreatedMessage;

  /// No description provided for @accountUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Account updated.'**
  String get accountUpdatedMessage;

  /// No description provided for @accountArchivedMessage.
  ///
  /// In en, this message translates to:
  /// **'Account archived.'**
  String get accountArchivedMessage;

  /// No description provided for @accountDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get accountDeletedMessage;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteAccountMessage;

  /// No description provided for @accountDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get accountDetailsTitle;

  /// No description provided for @accountDetailsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Detailed activity and controls for this account.'**
  String get accountDetailsPlaceholder;

  /// No description provided for @accountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get accountNotFound;

  /// No description provided for @accountsPreview.
  ///
  /// In en, this message translates to:
  /// **'Accounts preview'**
  String get accountsPreview;

  /// No description provided for @accountStatisticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Activity trend for the last six months.'**
  String get accountStatisticsSubtitle;

  /// No description provided for @transactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsTitle;

  /// No description provided for @transactionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cash flow and categorization'**
  String get transactionsSubtitle;

  /// No description provided for @transactionsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load transactions'**
  String get transactionsErrorTitle;

  /// No description provided for @transactionsErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh the page or try again later.'**
  String get transactionsErrorMessage;

  /// No description provided for @emptyTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get emptyTransactionsTitle;

  /// No description provided for @emptyTransactionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Transactions will appear here after you add income or expenses.'**
  String get emptyTransactionsMessage;

  /// No description provided for @searchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get searchTransactions;

  /// No description provided for @loadMoreTransactions.
  ///
  /// In en, this message translates to:
  /// **'Load more transactions'**
  String get loadMoreTransactions;

  /// No description provided for @transactionsLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'{loaded} of {total}'**
  String transactionsLoadedCount(int loaded, int total);

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @addIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get addIncome;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransaction;

  /// No description provided for @transactionCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Transaction created.'**
  String get transactionCreatedMessage;

  /// No description provided for @transactionUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Transaction updated.'**
  String get transactionUpdatedMessage;

  /// No description provided for @pendingTransactionEditHint.
  ///
  /// In en, this message translates to:
  /// **'Pending transactions do not affect account balances until they are posted.'**
  String get pendingTransactionEditHint;

  /// No description provided for @postedTransactionEditHint.
  ///
  /// In en, this message translates to:
  /// **'Saving reverses the previous posted balance effect, then applies the edited values exactly once.'**
  String get postedTransactionEditHint;

  /// No description provided for @transactionPrerequisitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts and categories required'**
  String get transactionPrerequisitesTitle;

  /// No description provided for @transactionPrerequisitesMessage.
  ///
  /// In en, this message translates to:
  /// **'Create at least one account and one matching category before adding a transaction.'**
  String get transactionPrerequisitesMessage;

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get transactionDetails;

  /// No description provided for @transactionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Transaction not found'**
  String get transactionNotFound;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction?'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionMessage.
  ///
  /// In en, this message translates to:
  /// **'Deleting a posted transaction will reverse its balance effect.'**
  String get deleteTransactionMessage;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get categoryTypeExpense;

  /// No description provided for @categoryTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get categoryTypeIncome;

  /// No description provided for @categoryTypeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get categoryTypeTransfer;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get paymentMethodDebitCard;

  /// No description provided for @paymentMethodCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get paymentMethodCreditCard;

  /// No description provided for @paymentMethodBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentMethodBankTransfer;

  /// No description provided for @paymentMethodDigitalWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital wallet'**
  String get paymentMethodDigitalWallet;

  /// No description provided for @paymentMethodEdfaly.
  ///
  /// In en, this message translates to:
  /// **'Edfaly'**
  String get paymentMethodEdfaly;

  /// No description provided for @paymentMethodMasrafiPay.
  ///
  /// In en, this message translates to:
  /// **'Masrafi Pay'**
  String get paymentMethodMasrafiPay;

  /// No description provided for @paymentMethodMobiCash.
  ///
  /// In en, this message translates to:
  /// **'Mobi Cash'**
  String get paymentMethodMobiCash;

  /// No description provided for @paymentMethodYusrPay.
  ///
  /// In en, this message translates to:
  /// **'Yusr Pay'**
  String get paymentMethodYusrPay;

  /// No description provided for @paymentMethodCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get paymentMethodCheck;

  /// No description provided for @paymentMethodCrypto.
  ///
  /// In en, this message translates to:
  /// **'Crypto'**
  String get paymentMethodCrypto;

  /// No description provided for @paymentMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentMethodOther;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @transactionStatusPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get transactionStatusPosted;

  /// No description provided for @transactionStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transactionStatusPending;

  /// No description provided for @transactionStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get transactionStatusCancelled;

  /// No description provided for @transactionStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transactionStatusFailed;

  /// No description provided for @transactionTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionTypeExpense;

  /// No description provided for @transactionTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionTypeIncome;

  /// No description provided for @transactionTypeTransferOut.
  ///
  /// In en, this message translates to:
  /// **'Transfer out'**
  String get transactionTypeTransferOut;

  /// No description provided for @transactionTypeTransferIn.
  ///
  /// In en, this message translates to:
  /// **'Transfer in'**
  String get transactionTypeTransferIn;

  /// No description provided for @transactionDate.
  ///
  /// In en, this message translates to:
  /// **'Transaction date'**
  String get transactionDate;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @transactionSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get transactionSourceManual;

  /// No description provided for @transactionSourceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get transactionSourceImported;

  /// No description provided for @transactionSourceRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get transactionSourceRecurring;

  /// No description provided for @transactionSourceAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI generated'**
  String get transactionSourceAiGenerated;

  /// No description provided for @transactionSourceCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get transactionSourceCloudSync;

  /// No description provided for @transactionSourceSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get transactionSourceSystem;

  /// No description provided for @aiReview.
  ///
  /// In en, this message translates to:
  /// **'AI review'**
  String get aiReview;

  /// No description provided for @aiReviewNeeded.
  ///
  /// In en, this message translates to:
  /// **'This transaction is marked for review.'**
  String get aiReviewNeeded;

  /// No description provided for @aiReviewNotNeeded.
  ///
  /// In en, this message translates to:
  /// **'No AI review is required.'**
  String get aiReviewNotNeeded;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize income, expenses, and transfers.'**
  String get categoriesSubtitle;

  /// No description provided for @createCategory.
  ///
  /// In en, this message translates to:
  /// **'Create category'**
  String get createCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Category name is required.'**
  String get categoryNameRequired;

  /// No description provided for @parentCategory.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get parentCategory;

  /// No description provided for @noParentCategory.
  ///
  /// In en, this message translates to:
  /// **'No parent category'**
  String get noParentCategory;

  /// No description provided for @categoriesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories'**
  String get categoriesErrorTitle;

  /// No description provided for @categoriesErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh the page or try again later.'**
  String get categoriesErrorMessage;

  /// No description provided for @emptyCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get emptyCategoriesTitle;

  /// No description provided for @emptyCategoriesMessage.
  ///
  /// In en, this message translates to:
  /// **'Default and custom categories will appear here.'**
  String get emptyCategoriesMessage;

  /// No description provided for @defaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultCategory;

  /// No description provided for @categoryNameFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryNameFood;

  /// No description provided for @categoryNameCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get categoryNameCoffee;

  /// No description provided for @categoryNameRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get categoryNameRestaurant;

  /// No description provided for @categoryNameTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryNameTransport;

  /// No description provided for @categoryNameTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get categoryNameTaxi;

  /// No description provided for @categoryNameFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get categoryNameFuel;

  /// No description provided for @categoryNameShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryNameShopping;

  /// No description provided for @categoryNameGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries & food staples'**
  String get categoryNameGroceries;

  /// No description provided for @categoryNameEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryNameEntertainment;

  /// No description provided for @categoryNameGaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get categoryNameGaming;

  /// No description provided for @categoryNameTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryNameTravel;

  /// No description provided for @categoryNameHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get categoryNameHotel;

  /// No description provided for @categoryNameBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get categoryNameBills;

  /// No description provided for @categoryNameInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get categoryNameInternet;

  /// No description provided for @categoryNamePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get categoryNamePhone;

  /// No description provided for @categoryNameRent.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get categoryNameRent;

  /// No description provided for @categoryNameInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoryNameInsurance;

  /// No description provided for @categoryNameHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Healthcare'**
  String get categoryNameHealthcare;

  /// No description provided for @categoryNamePharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get categoryNamePharmacy;

  /// No description provided for @categoryNameEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryNameEducation;

  /// No description provided for @categoryNameSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get categoryNameSubscription;

  /// No description provided for @categoryNameElectronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get categoryNameElectronics;

  /// No description provided for @categoryNamePets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get categoryNamePets;

  /// No description provided for @categoryNameCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity'**
  String get categoryNameCharity;

  /// No description provided for @categoryNameTaxes.
  ///
  /// In en, this message translates to:
  /// **'Taxes'**
  String get categoryNameTaxes;

  /// No description provided for @categoryNameGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get categoryNameGift;

  /// No description provided for @categoryNameClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoryNameClothing;

  /// No description provided for @categoryNameSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categoryNameSports;

  /// No description provided for @categoryNameBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryNameBeauty;

  /// No description provided for @categoryNameHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get categoryNameHome;

  /// No description provided for @categoryNameSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categoryNameSalary;

  /// No description provided for @categoryNameFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get categoryNameFreelance;

  /// No description provided for @categoryNameBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get categoryNameBonus;

  /// No description provided for @categoryNameInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get categoryNameInvestment;

  /// No description provided for @categoryNameRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get categoryNameRefund;

  /// No description provided for @categoryNameCashback.
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get categoryNameCashback;

  /// No description provided for @categoryNameRentalIncome.
  ///
  /// In en, this message translates to:
  /// **'Rental income'**
  String get categoryNameRentalIncome;

  /// No description provided for @categoryNameInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get categoryNameInterest;

  /// No description provided for @categoryNameOtherIncome.
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get categoryNameOtherIncome;

  /// No description provided for @categoryNameBusinessRevenue.
  ///
  /// In en, this message translates to:
  /// **'Business revenue'**
  String get categoryNameBusinessRevenue;

  /// No description provided for @categoryNameAllowance.
  ///
  /// In en, this message translates to:
  /// **'Allowance'**
  String get categoryNameAllowance;

  /// No description provided for @categoryNameReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get categoryNameReimbursement;

  /// No description provided for @categoryNameSaleProceeds.
  ///
  /// In en, this message translates to:
  /// **'Sale proceeds'**
  String get categoryNameSaleProceeds;

  /// No description provided for @categoryNameGovernmentSupport.
  ///
  /// In en, this message translates to:
  /// **'Government support'**
  String get categoryNameGovernmentSupport;

  /// No description provided for @categoryNameScholarship.
  ///
  /// In en, this message translates to:
  /// **'Scholarship'**
  String get categoryNameScholarship;

  /// No description provided for @categoryNamePrize.
  ///
  /// In en, this message translates to:
  /// **'Prize'**
  String get categoryNamePrize;

  /// No description provided for @categoryNameLoanProceeds.
  ///
  /// In en, this message translates to:
  /// **'Loan proceeds'**
  String get categoryNameLoanProceeds;

  /// No description provided for @categoryNameTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get categoryNameTransfer;

  /// No description provided for @payeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Payees'**
  String get payeesTitle;

  /// No description provided for @payeesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage people, merchants, employers, and services.'**
  String get payeesSubtitle;

  /// No description provided for @payeesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load payees'**
  String get payeesErrorTitle;

  /// No description provided for @searchPayees.
  ///
  /// In en, this message translates to:
  /// **'Search payees'**
  String get searchPayees;

  /// No description provided for @emptyPayeesTitle.
  ///
  /// In en, this message translates to:
  /// **'No payees yet'**
  String get emptyPayeesTitle;

  /// No description provided for @emptyPayeesMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a payee to improve transaction entry and AI matching.'**
  String get emptyPayeesMessage;

  /// No description provided for @payeeDetails.
  ///
  /// In en, this message translates to:
  /// **'Payee details'**
  String get payeeDetails;

  /// No description provided for @payeeDetailsMessage.
  ///
  /// In en, this message translates to:
  /// **'Defaults and aliases make transaction entry faster and more accurate.'**
  String get payeeDetailsMessage;

  /// No description provided for @payeeTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String payeeTransactionCount(int count);

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @budgetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plans and spending limits'**
  String get budgetsSubtitle;

  /// No description provided for @budgetProgress.
  ///
  /// In en, this message translates to:
  /// **'Budget progress'**
  String get budgetProgress;

  /// No description provided for @budgetProgressPending.
  ///
  /// In en, this message translates to:
  /// **'Set monthly limits to watch spending pace and category pressure here.'**
  String get budgetProgressPending;

  /// No description provided for @budgetBackendPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget control center'**
  String get budgetBackendPendingTitle;

  /// No description provided for @budgetBackendPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Plan limits, monitor pace, and keep spending alerts visible in one focused workspace.'**
  String get budgetBackendPendingMessage;

  /// No description provided for @createBudget.
  ///
  /// In en, this message translates to:
  /// **'Create budget'**
  String get createBudget;

  /// No description provided for @activeBudgets.
  ///
  /// In en, this message translates to:
  /// **'Active budgets'**
  String get activeBudgets;

  /// No description provided for @remainingBudget.
  ///
  /// In en, this message translates to:
  /// **'Remaining budget'**
  String get remainingBudget;

  /// No description provided for @budgetAlerts.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get budgetAlerts;

  /// No description provided for @emptyBudgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get emptyBudgetsTitle;

  /// No description provided for @emptyBudgetsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your budget cards will live here when you start assigning spending limits.'**
  String get emptyBudgetsMessage;

  /// No description provided for @addBudget.
  ///
  /// In en, this message translates to:
  /// **'Add budget'**
  String get addBudget;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get editBudget;

  /// No description provided for @archiveBudget.
  ///
  /// In en, this message translates to:
  /// **'Archive budget'**
  String get archiveBudget;

  /// No description provided for @restoreBudget.
  ///
  /// In en, this message translates to:
  /// **'Restore budget'**
  String get restoreBudget;

  /// No description provided for @budgetName.
  ///
  /// In en, this message translates to:
  /// **'Budget name'**
  String get budgetName;

  /// No description provided for @budgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget amount'**
  String get budgetAmount;

  /// No description provided for @budgetPeriod.
  ///
  /// In en, this message translates to:
  /// **'Budget period'**
  String get budgetPeriod;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @customPeriod.
  ///
  /// In en, this message translates to:
  /// **'Custom period'**
  String get customPeriod;

  /// No description provided for @alertThreshold.
  ///
  /// In en, this message translates to:
  /// **'Alert threshold'**
  String get alertThreshold;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @onTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get onTrack;

  /// No description provided for @nearLimit.
  ///
  /// In en, this message translates to:
  /// **'Near limit'**
  String get nearLimit;

  /// No description provided for @exceeded.
  ///
  /// In en, this message translates to:
  /// **'Exceeded'**
  String get exceeded;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @createYourFirstBudget.
  ///
  /// In en, this message translates to:
  /// **'Create your first budget to track a category spending limit.'**
  String get createYourFirstBudget;

  /// No description provided for @budgetSaved.
  ///
  /// In en, this message translates to:
  /// **'Budget saved.'**
  String get budgetSaved;

  /// No description provided for @budgetArchived.
  ///
  /// In en, this message translates to:
  /// **'Budget archived.'**
  String get budgetArchived;

  /// No description provided for @budgetRestored.
  ///
  /// In en, this message translates to:
  /// **'Budget restored.'**
  String get budgetRestored;

  /// No description provided for @invalidBudgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a budget amount greater than zero.'**
  String get invalidBudgetAmount;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category.'**
  String get selectCategory;

  /// No description provided for @budgetPeriodInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a valid start and end date.'**
  String get budgetPeriodInvalid;

  /// No description provided for @budgetMissingExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'This progress is partial because an exchange rate is missing.'**
  String get budgetMissingExchangeRate;

  /// No description provided for @includeArchivedBudgets.
  ///
  /// In en, this message translates to:
  /// **'Include archived budgets'**
  String get includeArchivedBudgets;

  /// No description provided for @budgetDetails.
  ///
  /// In en, this message translates to:
  /// **'Budget details'**
  String get budgetDetails;

  /// No description provided for @budgetStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get budgetStartDate;

  /// No description provided for @budgetEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get budgetEndDate;

  /// No description provided for @budgetArchiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archived budgets stop appearing in active planning summaries.'**
  String get budgetArchiveConfirm;

  /// No description provided for @budgetsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load budgets'**
  String get budgetsLoadError;

  /// No description provided for @budgetsLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Your budgets are still stored safely. Try loading them again.'**
  String get budgetsLoadErrorMessage;

  /// No description provided for @budgetSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the budget.'**
  String get budgetSaveError;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsTitle;

  /// No description provided for @goalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Savings targets and milestones'**
  String get goalsSubtitle;

  /// No description provided for @goalsProgress.
  ///
  /// In en, this message translates to:
  /// **'Goals progress'**
  String get goalsProgress;

  /// No description provided for @goalsProgressPending.
  ///
  /// In en, this message translates to:
  /// **'Create targets to follow milestones, saved amounts, and goal momentum.'**
  String get goalsProgressPending;

  /// No description provided for @goalsBackendPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal planning space'**
  String get goalsBackendPendingTitle;

  /// No description provided for @goalsBackendPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Shape savings targets, track milestones, and keep long-term plans visible.'**
  String get goalsBackendPendingMessage;

  /// No description provided for @createGoal.
  ///
  /// In en, this message translates to:
  /// **'Create goal'**
  String get createGoal;

  /// No description provided for @activeGoals.
  ///
  /// In en, this message translates to:
  /// **'Active goals'**
  String get activeGoals;

  /// No description provided for @savedForGoals.
  ///
  /// In en, this message translates to:
  /// **'Saved for goals'**
  String get savedForGoals;

  /// No description provided for @goalMilestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get goalMilestones;

  /// No description provided for @emptyGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get emptyGoalsTitle;

  /// No description provided for @emptyGoalsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your savings targets will appear here when you start planning a goal.'**
  String get emptyGoalsMessage;

  /// No description provided for @addGoal.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get addGoal;

  /// No description provided for @editGoal.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get editGoal;

  /// No description provided for @archiveGoal.
  ///
  /// In en, this message translates to:
  /// **'Archive goal'**
  String get archiveGoal;

  /// No description provided for @restoreGoal.
  ///
  /// In en, this message translates to:
  /// **'Restore goal'**
  String get restoreGoal;

  /// No description provided for @goalTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal title'**
  String get goalTitle;

  /// No description provided for @goalDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get goalDescription;

  /// No description provided for @goalType.
  ///
  /// In en, this message translates to:
  /// **'Goal type'**
  String get goalType;

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get targetAmount;

  /// No description provided for @currentAmount.
  ///
  /// In en, this message translates to:
  /// **'Current amount'**
  String get currentAmount;

  /// No description provided for @targetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get targetDate;

  /// No description provided for @clearTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Clear target date'**
  String get clearTargetDate;

  /// No description provided for @contribution.
  ///
  /// In en, this message translates to:
  /// **'Contribution'**
  String get contribution;

  /// No description provided for @addContribution.
  ///
  /// In en, this message translates to:
  /// **'Add contribution'**
  String get addContribution;

  /// No description provided for @contributionHistory.
  ///
  /// In en, this message translates to:
  /// **'Contribution history'**
  String get contributionHistory;

  /// No description provided for @savingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Savings goal'**
  String get savingsGoal;

  /// No description provided for @emergencyFund.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund'**
  String get emergencyFund;

  /// No description provided for @debtPayoff.
  ///
  /// In en, this message translates to:
  /// **'Debt payoff'**
  String get debtPayoff;

  /// No description provided for @purchaseGoal.
  ///
  /// In en, this message translates to:
  /// **'Purchase goal'**
  String get purchaseGoal;

  /// No description provided for @customGoal.
  ///
  /// In en, this message translates to:
  /// **'Custom goal'**
  String get customGoal;

  /// No description provided for @goalStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get goalStatusActive;

  /// No description provided for @goalStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get goalStatusCompleted;

  /// No description provided for @goalStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get goalStatusPaused;

  /// No description provided for @goalStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get goalStatusArchived;

  /// No description provided for @goalProgress.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get goalProgress;

  /// No description provided for @remainingAmount.
  ///
  /// In en, this message translates to:
  /// **'Remaining amount'**
  String get remainingAmount;

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'Days remaining'**
  String get daysRemaining;

  /// No description provided for @monthlyNeeded.
  ///
  /// In en, this message translates to:
  /// **'Monthly needed'**
  String get monthlyNeeded;

  /// No description provided for @createYourFirstGoal.
  ///
  /// In en, this message translates to:
  /// **'Create your first goal and track every contribution.'**
  String get createYourFirstGoal;

  /// No description provided for @goalSaved.
  ///
  /// In en, this message translates to:
  /// **'Goal saved.'**
  String get goalSaved;

  /// No description provided for @goalArchived.
  ///
  /// In en, this message translates to:
  /// **'Goal archived.'**
  String get goalArchived;

  /// No description provided for @goalRestored.
  ///
  /// In en, this message translates to:
  /// **'Goal restored.'**
  String get goalRestored;

  /// No description provided for @contributionAdded.
  ///
  /// In en, this message translates to:
  /// **'Contribution added.'**
  String get contributionAdded;

  /// No description provided for @contributionReversed.
  ///
  /// In en, this message translates to:
  /// **'Contribution reversed.'**
  String get contributionReversed;

  /// No description provided for @invalidGoalAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a target amount greater than zero.'**
  String get invalidGoalAmount;

  /// No description provided for @invalidContributionAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a contribution greater than zero.'**
  String get invalidContributionAmount;

  /// No description provided for @selectGoal.
  ///
  /// In en, this message translates to:
  /// **'Select a goal.'**
  String get selectGoal;

  /// No description provided for @includeArchivedGoals.
  ///
  /// In en, this message translates to:
  /// **'Include archived goals'**
  String get includeArchivedGoals;

  /// No description provided for @goalsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load goals'**
  String get goalsLoadError;

  /// No description provided for @goalsLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Your goals are still stored safely. Try loading them again.'**
  String get goalsLoadErrorMessage;

  /// No description provided for @goalSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the goal.'**
  String get goalSaveError;

  /// No description provided for @contributionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not add this contribution.'**
  String get contributionSaveError;

  /// No description provided for @goalDetails.
  ///
  /// In en, this message translates to:
  /// **'Goal details'**
  String get goalDetails;

  /// No description provided for @goalArchiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archived goals stop accepting contributions and leave active planning summaries.'**
  String get goalArchiveConfirm;

  /// No description provided for @contributionNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get contributionNote;

  /// No description provided for @contributionDate.
  ///
  /// In en, this message translates to:
  /// **'Contribution date'**
  String get contributionDate;

  /// No description provided for @reversedContribution.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get reversedContribution;

  /// No description provided for @reverseContribution.
  ///
  /// In en, this message translates to:
  /// **'Reverse contribution'**
  String get reverseContribution;

  /// No description provided for @reverseContributionConfirm.
  ///
  /// In en, this message translates to:
  /// **'This removes the contribution from the tracked goal progress without moving account money.'**
  String get reverseContributionConfirm;

  /// No description provided for @noContributionsYet.
  ///
  /// In en, this message translates to:
  /// **'No contributions yet'**
  String get noContributionsYet;

  /// No description provided for @noContributionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Contributions to this goal will appear here.'**
  String get noContributionsMessage;

  /// No description provided for @linkedAccount.
  ///
  /// In en, this message translates to:
  /// **'Linked account'**
  String get linkedAccount;

  /// No description provided for @noLinkedAccount.
  ///
  /// In en, this message translates to:
  /// **'No linked account'**
  String get noLinkedAccount;

  /// No description provided for @nearestTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Nearest target date'**
  String get nearestTargetDate;

  /// No description provided for @completedGoals.
  ///
  /// In en, this message translates to:
  /// **'Completed goals'**
  String get completedGoals;

  /// No description provided for @goalMissingExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Add a manual exchange rate before using this contribution currency.'**
  String get goalMissingExchangeRate;

  /// No description provided for @goalWouldExceedTarget.
  ///
  /// In en, this message translates to:
  /// **'This contribution would exceed the remaining target amount.'**
  String get goalWouldExceedTarget;

  /// No description provided for @goalTargetBelowCurrent.
  ///
  /// In en, this message translates to:
  /// **'The target cannot be lower than the amount already saved.'**
  String get goalTargetBelowCurrent;

  /// No description provided for @goalTrackingOnly.
  ///
  /// In en, this message translates to:
  /// **'Tracking contribution'**
  String get goalTrackingOnly;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @financialInsights.
  ///
  /// In en, this message translates to:
  /// **'Financial insights'**
  String get financialInsights;

  /// No description provided for @financialInsightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calculated privately from local financial activity'**
  String get financialInsightsSubtitle;

  /// No description provided for @noInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'No insights yet'**
  String get noInsightsTitle;

  /// No description provided for @noInsightsMessage.
  ///
  /// In en, this message translates to:
  /// **'Insights will appear when there is enough posted activity to compare.'**
  String get noInsightsMessage;

  /// No description provided for @insightSpendingIncreaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending increased'**
  String get insightSpendingIncreaseTitle;

  /// No description provided for @insightSpendingIncreaseMessage.
  ///
  /// In en, this message translates to:
  /// **'Spending is up {percent}% compared with last month.'**
  String insightSpendingIncreaseMessage(String percent);

  /// No description provided for @insightPositiveSpendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending trend improved'**
  String get insightPositiveSpendingTitle;

  /// No description provided for @insightPositiveSpendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Spending is down {percent}% compared with last month.'**
  String insightPositiveSpendingMessage(String percent);

  /// No description provided for @insightTopCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Top spending category'**
  String get insightTopCategoryTitle;

  /// No description provided for @insightTopCategoryMessage.
  ///
  /// In en, this message translates to:
  /// **'{category} led spending at {amount} this month.'**
  String insightTopCategoryMessage(String category, String amount);

  /// No description provided for @insightRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible recurring payments'**
  String get insightRecurringTitle;

  /// No description provided for @insightRecurringMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} possible recurring payment patterns were detected locally.'**
  String insightRecurringMessage(String count);

  /// No description provided for @insightCashFlowWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash flow needs attention'**
  String get insightCashFlowWarningTitle;

  /// No description provided for @insightCashFlowWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Current posted cash flow is {amount}.'**
  String insightCashFlowWarningMessage(String amount);

  /// No description provided for @insightPositiveCashFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Positive cash-flow trend'**
  String get insightPositiveCashFlowTitle;

  /// No description provided for @insightPositiveCashFlowMessage.
  ///
  /// In en, this message translates to:
  /// **'Current posted cash flow is {amount}.'**
  String insightPositiveCashFlowMessage(String amount);

  /// No description provided for @insightMissingRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing exchange rate'**
  String get insightMissingRateTitle;

  /// No description provided for @insightMissingRateMessage.
  ///
  /// In en, this message translates to:
  /// **'{pair} is missing, so some totals are partial.'**
  String insightMissingRateMessage(String pair);

  /// No description provided for @insightBudgetWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget alert'**
  String get insightBudgetWarningTitle;

  /// No description provided for @insightBudgetWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is at {percent}%.'**
  String insightBudgetWarningMessage(String name, String percent);

  /// No description provided for @insightGoalProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get insightGoalProgressTitle;

  /// No description provided for @insightGoalProgressMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} has reached {percent}%.'**
  String insightGoalProgressMessage(String name, String percent);

  /// No description provided for @insightSavingsOpportunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings opportunity'**
  String get insightSavingsOpportunityTitle;

  /// No description provided for @insightUnusualTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Unusual transaction'**
  String get insightUnusualTransactionTitle;

  /// No description provided for @insightPeriod.
  ///
  /// In en, this message translates to:
  /// **'Insight period'**
  String get insightPeriod;

  /// No description provided for @reviewInsight.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewInsight;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trends and financial insights'**
  String get reportsSubtitle;

  /// No description provided for @reportsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load reports'**
  String get reportsErrorTitle;

  /// No description provided for @monthlyReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly report'**
  String get monthlyReport;

  /// No description provided for @yearlyReport.
  ///
  /// In en, this message translates to:
  /// **'Yearly report'**
  String get yearlyReport;

  /// No description provided for @yearlyInsightsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Yearly insights are taking shape'**
  String get yearlyInsightsEmptyTitle;

  /// No description provided for @yearlyInsightsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'A complete yearly view will appear here when the reporting period is available.'**
  String get yearlyInsightsEmptyMessage;

  /// No description provided for @categoryReport.
  ///
  /// In en, this message translates to:
  /// **'Category report'**
  String get categoryReport;

  /// No description provided for @cashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get cashFlow;

  /// No description provided for @cashFlowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expense movement over the last six months.'**
  String get cashFlowSubtitle;

  /// No description provided for @cashFlowActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'Cash flow is calculated from posted local transactions.'**
  String get cashFlowActiveMessage;

  /// No description provided for @cashFlowEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add transactions to activate live cash-flow trends.'**
  String get cashFlowEmptyMessage;

  /// No description provided for @reportActualDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calculated from local accounts and transactions.'**
  String get reportActualDataSubtitle;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistantTitle;

  /// No description provided for @aiAssistantShort.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiAssistantShort;

  /// No description provided for @aiAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal finance intelligence'**
  String get aiAssistantSubtitle;

  /// No description provided for @aiAssistantBackendPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'CashPilot intelligence'**
  String get aiAssistantBackendPendingTitle;

  /// No description provided for @aiAssistantBackendPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Ask questions or describe a financial action. CashPilot prepares a reviewable draft and never changes money without your confirmation.'**
  String get aiAssistantBackendPendingMessage;

  /// No description provided for @aiAssistantPendingSnack.
  ///
  /// In en, this message translates to:
  /// **'Voice input is not available yet. You can type your request instead.'**
  String get aiAssistantPendingSnack;

  /// No description provided for @suggestedPrompts.
  ///
  /// In en, this message translates to:
  /// **'Suggested prompts'**
  String get suggestedPrompts;

  /// No description provided for @promptAnalyzeSpending.
  ///
  /// In en, this message translates to:
  /// **'Analyze my spending'**
  String get promptAnalyzeSpending;

  /// No description provided for @promptFindSavings.
  ///
  /// In en, this message translates to:
  /// **'Find savings opportunities'**
  String get promptFindSavings;

  /// No description provided for @promptExplainCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Explain my cash flow'**
  String get promptExplainCashFlow;

  /// No description provided for @promptReviewSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Review subscriptions'**
  String get promptReviewSubscriptions;

  /// No description provided for @insightCards.
  ///
  /// In en, this message translates to:
  /// **'Insight cards'**
  String get insightCards;

  /// No description provided for @aiInsightCard.
  ///
  /// In en, this message translates to:
  /// **'AI insight'**
  String get aiInsightCard;

  /// No description provided for @aiInsightDataReady.
  ///
  /// In en, this message translates to:
  /// **'Your local transaction history is ready for privacy-conscious AI analysis.'**
  String get aiInsightDataReady;

  /// No description provided for @aiInsightEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add transactions to unlock personalized AI insights.'**
  String get aiInsightEmpty;

  /// No description provided for @openAssistant.
  ///
  /// In en, this message translates to:
  /// **'Open assistant'**
  String get openAssistant;

  /// No description provided for @emptyConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversation yet'**
  String get emptyConversationTitle;

  /// No description provided for @emptyConversationMessage.
  ///
  /// In en, this message translates to:
  /// **'Start with a question or describe a transaction you want CashPilot to prepare.'**
  String get emptyConversationMessage;

  /// No description provided for @aiReadyBadge.
  ///
  /// In en, this message translates to:
  /// **'AI ready'**
  String get aiReadyBadge;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'Reviewing your request'**
  String get aiThinking;

  /// No description provided for @askAiHint.
  ///
  /// In en, this message translates to:
  /// **'Ask CashPilot AI'**
  String get askAiHint;

  /// No description provided for @aiTransactionDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction draft'**
  String get aiTransactionDraftTitle;

  /// No description provided for @aiClarifyPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Which payment method did you use?'**
  String get aiClarifyPaymentMethod;

  /// No description provided for @aiParsedAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get aiParsedAccount;

  /// No description provided for @aiParsedCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get aiParsedCurrency;

  /// No description provided for @aiParsedPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get aiParsedPaymentMethod;

  /// No description provided for @aiParsedConfidence.
  ///
  /// In en, this message translates to:
  /// **'Parsed from your message. Review before saving.'**
  String get aiParsedConfidence;

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceInput;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @aiDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI diagnostics'**
  String get aiDiagnosticsTitle;

  /// No description provided for @aiDiagnosticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify the configured remote text provider, gateway, authentication, and App Check without changing financial data.'**
  String get aiDiagnosticsDescription;

  /// No description provided for @aiConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'AI configuration'**
  String get aiConfigurationTitle;

  /// No description provided for @aiRemoteTextProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Remote text provider'**
  String get aiRemoteTextProviderLabel;

  /// No description provided for @aiGeneralConversationModelLabel.
  ///
  /// In en, this message translates to:
  /// **'General conversation model'**
  String get aiGeneralConversationModelLabel;

  /// No description provided for @aiFinancialExplanationModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Financial explanation model'**
  String get aiFinancialExplanationModelLabel;

  /// No description provided for @aiLocalCommandParserLabel.
  ///
  /// In en, this message translates to:
  /// **'Local command parser'**
  String get aiLocalCommandParserLabel;

  /// No description provided for @aiReceiptVisionProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt Vision provider'**
  String get aiReceiptVisionProviderLabel;

  /// No description provided for @aiProviderRoutingLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider routing'**
  String get aiProviderRoutingLabel;

  /// No description provided for @aiFirebaseTextFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Firebase text fallback'**
  String get aiFirebaseTextFallbackLabel;

  /// No description provided for @aiGatewayLabel.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get aiGatewayLabel;

  /// No description provided for @aiAuthenticationLabel.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get aiAuthenticationLabel;

  /// No description provided for @aiAppCheckLabel.
  ///
  /// In en, this message translates to:
  /// **'App Check'**
  String get aiAppCheckLabel;

  /// No description provided for @aiEnvironmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get aiEnvironmentLabel;

  /// No description provided for @aiBuildModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Build mode'**
  String get aiBuildModeLabel;

  /// No description provided for @aiProviderGroq.
  ///
  /// In en, this message translates to:
  /// **'Groq'**
  String get aiProviderGroq;

  /// No description provided for @aiProviderFirebaseAi.
  ///
  /// In en, this message translates to:
  /// **'Firebase AI'**
  String get aiProviderFirebaseAi;

  /// No description provided for @aiProviderNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get aiProviderNotConfigured;

  /// No description provided for @aiProviderRoutingGroqPrimary.
  ///
  /// In en, this message translates to:
  /// **'Groq primary'**
  String get aiProviderRoutingGroqPrimary;

  /// No description provided for @aiProviderRoutingFirebasePrimary.
  ///
  /// In en, this message translates to:
  /// **'Firebase primary'**
  String get aiProviderRoutingFirebasePrimary;

  /// No description provided for @aiProviderRoutingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Remote text disabled'**
  String get aiProviderRoutingDisabled;

  /// No description provided for @aiStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get aiStatusEnabled;

  /// No description provided for @aiStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get aiStatusDisabled;

  /// No description provided for @aiStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get aiStatusAvailable;

  /// No description provided for @aiStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get aiStatusUnavailable;

  /// No description provided for @aiStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get aiStatusReady;

  /// No description provided for @aiStatusNotReady.
  ///
  /// In en, this message translates to:
  /// **'Not ready'**
  String get aiStatusNotReady;

  /// No description provided for @aiStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get aiStatusVerified;

  /// No description provided for @aiStatusNotActivated.
  ///
  /// In en, this message translates to:
  /// **'Not activated'**
  String get aiStatusNotActivated;

  /// No description provided for @aiStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get aiStatusChecking;

  /// No description provided for @aiProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'AI provider'**
  String get aiProviderLabel;

  /// No description provided for @aiProviderMock.
  ///
  /// In en, this message translates to:
  /// **'Mock provider'**
  String get aiProviderMock;

  /// No description provided for @aiProviderLocalParserOnly.
  ///
  /// In en, this message translates to:
  /// **'Local parser only'**
  String get aiProviderLocalParserOnly;

  /// No description provided for @aiProviderFirebaseGemini.
  ///
  /// In en, this message translates to:
  /// **'Firebase Gemini (live)'**
  String get aiProviderFirebaseGemini;

  /// No description provided for @aiProviderAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic provider routing'**
  String get aiProviderAutomatic;

  /// No description provided for @aiProviderGroqGateway.
  ///
  /// In en, this message translates to:
  /// **'Groq secure gateway'**
  String get aiProviderGroqGateway;

  /// No description provided for @aiModelGatewayManaged.
  ///
  /// In en, this message translates to:
  /// **'Gateway-managed model'**
  String get aiModelGatewayManaged;

  /// No description provided for @aiModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Active AI model'**
  String get aiModelLabel;

  /// No description provided for @aiStructuredOutputEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Structured output enabled'**
  String get aiStructuredOutputEnabledLabel;

  /// No description provided for @aiStructuredOutputEnabledValue.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get aiStructuredOutputEnabledValue;

  /// No description provided for @aiStructuredOutputDisabledValue.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get aiStructuredOutputDisabledValue;

  /// No description provided for @aiLastTestStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Last test status'**
  String get aiLastTestStatusLabel;

  /// No description provided for @aiTestStatusNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get aiTestStatusNotTested;

  /// No description provided for @aiTestStatusTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get aiTestStatusTesting;

  /// No description provided for @aiTestStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get aiTestStatusAvailable;

  /// No description provided for @aiTestStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get aiTestStatusUnavailable;

  /// No description provided for @aiTestStatusConfigurationMissing.
  ///
  /// In en, this message translates to:
  /// **'Configuration missing'**
  String get aiTestStatusConfigurationMissing;

  /// No description provided for @aiTestStatusAuthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get aiTestStatusAuthenticationRequired;

  /// No description provided for @aiTestStatusAppCheckUnavailable.
  ///
  /// In en, this message translates to:
  /// **'App Check unavailable'**
  String get aiTestStatusAppCheckUnavailable;

  /// No description provided for @aiTestStatusGatewayUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Gateway unavailable'**
  String get aiTestStatusGatewayUnavailable;

  /// No description provided for @aiTestStatusModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Model unavailable'**
  String get aiTestStatusModelUnavailable;

  /// No description provided for @aiTestStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get aiTestStatusOffline;

  /// No description provided for @aiTestStatusTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Timed out'**
  String get aiTestStatusTimedOut;

  /// No description provided for @aiTestStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get aiTestStatusSuccess;

  /// No description provided for @aiTestStatusProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Provider unavailable'**
  String get aiTestStatusProviderUnavailable;

  /// No description provided for @aiTestStatusAppCheckBlocked.
  ///
  /// In en, this message translates to:
  /// **'App Check blocked'**
  String get aiTestStatusAppCheckBlocked;

  /// No description provided for @aiTestStatusRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Rate limited'**
  String get aiTestStatusRateLimited;

  /// No description provided for @aiTestStatusInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid response'**
  String get aiTestStatusInvalidResponse;

  /// No description provided for @aiTestStatusNetworkFailure.
  ///
  /// In en, this message translates to:
  /// **'Network failure'**
  String get aiTestStatusNetworkFailure;

  /// No description provided for @aiTestStatusFallbackUsed.
  ///
  /// In en, this message translates to:
  /// **'Fallback used'**
  String get aiTestStatusFallbackUsed;

  /// No description provided for @aiLastCheckedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last checked'**
  String get aiLastCheckedLabel;

  /// No description provided for @aiLiveTestLatencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Live-test latency'**
  String get aiLiveTestLatencyLabel;

  /// No description provided for @aiLiveTestLatencyValue.
  ///
  /// In en, this message translates to:
  /// **'{milliseconds} ms'**
  String aiLiveTestLatencyValue(int milliseconds);

  /// No description provided for @aiNotCheckedYet.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get aiNotCheckedYet;

  /// No description provided for @aiLastCheckedValue.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String aiLastCheckedValue(String date, String time);

  /// No description provided for @aiTechnicalCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Technical code'**
  String get aiTechnicalCodeLabel;

  /// No description provided for @aiFallbackAvailabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Safe local fallback'**
  String get aiFallbackAvailabilityLabel;

  /// No description provided for @aiFallbackAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get aiFallbackAvailable;

  /// No description provided for @aiFallbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get aiFallbackUnavailable;

  /// No description provided for @aiLiveProviderInactiveMessage.
  ///
  /// In en, this message translates to:
  /// **'The configured remote text provider is inactive. No live AI request will be sent.'**
  String get aiLiveProviderInactiveMessage;

  /// No description provided for @aiGroqLiveTestMessage.
  ///
  /// In en, this message translates to:
  /// **'This test sends a small live request through the configured Groq gateway using the same authenticated provider path as AI chat. The prompt and response are not displayed or stored here.'**
  String get aiGroqLiveTestMessage;

  /// No description provided for @aiRemoteProviderLiveTestMessage.
  ///
  /// In en, this message translates to:
  /// **'This test sends a small live request through the configured remote provider using the same authenticated path as AI chat. The prompt and response are not displayed or stored here.'**
  String get aiRemoteProviderLiveTestMessage;

  /// No description provided for @aiGroqNotConfiguredBuildMessage.
  ///
  /// In en, this message translates to:
  /// **'Groq is not configured in this build.'**
  String get aiGroqNotConfiguredBuildMessage;

  /// No description provided for @aiNotTestedCurrentConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Not tested with the current configuration'**
  String get aiNotTestedCurrentConfiguration;

  /// No description provided for @aiLiveTestAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The Groq gateway, authentication, App Check, and streaming response are available.'**
  String get aiLiveTestAvailableMessage;

  /// No description provided for @testAiConnection.
  ///
  /// In en, this message translates to:
  /// **'Test AI connection'**
  String get testAiConnection;

  /// No description provided for @testingAiConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing AI connection…'**
  String get testingAiConnection;

  /// No description provided for @aiConnectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Firebase AI Logic and App Check are ready.'**
  String get aiConnectionSuccess;

  /// No description provided for @aiProviderConnectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'The selected AI provider is ready.'**
  String get aiProviderConnectionSuccess;

  /// No description provided for @aiConnectionFallbackReady.
  ///
  /// In en, this message translates to:
  /// **'The local financial parser is ready. No remote AI request was used.'**
  String get aiConnectionFallbackReady;

  /// No description provided for @aiConnectionFallbackAfterFailure.
  ///
  /// In en, this message translates to:
  /// **'{reason} The safe local parser remains available.'**
  String aiConnectionFallbackAfterFailure(String reason);

  /// No description provided for @aiConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'AI connection and local fallback are unavailable.'**
  String get aiConnectionFailed;

  /// No description provided for @aiRateLimitedMessage.
  ///
  /// In en, this message translates to:
  /// **'The AI request limit was reached. Please wait a moment and try again.'**
  String get aiRateLimitedMessage;

  /// No description provided for @aiAppCheckBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'App Check could not verify this app for AI access. Review the Firebase setup.'**
  String get aiAppCheckBlockedMessage;

  /// No description provided for @aiNetworkFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'CashPilot could not reach the AI service. Check your connection and try again.'**
  String get aiNetworkFailureMessage;

  /// No description provided for @aiProviderUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The configured AI service is unavailable. The local parser will be used when possible.'**
  String get aiProviderUnavailableMessage;

  /// No description provided for @aiLocalParserOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'Remote AI is disabled in this build; the local financial parser is active.'**
  String get aiLocalParserOnlyMessage;

  /// No description provided for @aiInvalidResponseMessage.
  ///
  /// In en, this message translates to:
  /// **'The AI response could not be verified, so it was not used.'**
  String get aiInvalidResponseMessage;

  /// No description provided for @aiRequestInFlightMessage.
  ///
  /// In en, this message translates to:
  /// **'An AI request is already in progress.'**
  String get aiRequestInFlightMessage;

  /// No description provided for @aiRequestTooFastMessage.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment before sending another AI request.'**
  String get aiRequestTooFastMessage;

  /// No description provided for @aiDuplicatePromptMessage.
  ///
  /// In en, this message translates to:
  /// **'That same request was just sent. Please wait or change it before retrying.'**
  String get aiDuplicatePromptMessage;

  /// No description provided for @aiGenericFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'CashPilot could not complete the AI request safely.'**
  String get aiGenericFailureMessage;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @currencyPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Base currency preferences keep reports consistent across accounts.'**
  String get currencyPendingMessage;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @backupPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup is available for signed-in accounts.'**
  String get backupPendingMessage;

  /// No description provided for @cloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get cloudBackup;

  /// No description provided for @cloudBackupEnabled.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup is enabled.'**
  String get cloudBackupEnabled;

  /// No description provided for @cloudBackupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup is disabled.'**
  String get cloudBackupDisabled;

  /// No description provided for @backupOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Uploads queued local changes to your user-scoped cloud backup. Restore and cloud-to-device merge are not available yet.'**
  String get backupOnlyDescription;

  /// No description provided for @guestBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a non-guest account to use cloud backup.'**
  String get guestBackupWarning;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last successful backup'**
  String get lastBackup;

  /// No description provided for @neverBackedUp.
  ///
  /// In en, this message translates to:
  /// **'No successful backup yet'**
  String get neverBackedUp;

  /// No description provided for @pendingBackupItems.
  ///
  /// In en, this message translates to:
  /// **'Pending backup items'**
  String get pendingBackupItems;

  /// No description provided for @failedBackupItems.
  ///
  /// In en, this message translates to:
  /// **'Failed backup items'**
  String get failedBackupItems;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @retryFailedBackup.
  ///
  /// In en, this message translates to:
  /// **'Retry failed'**
  String get retryFailedBackup;

  /// No description provided for @backupNoPendingItems.
  ///
  /// In en, this message translates to:
  /// **'Your backup queue is already up to date.'**
  String get backupNoPendingItems;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backed up {count} items.'**
  String backupSuccess(int count);

  /// No description provided for @backupPartialFailure.
  ///
  /// In en, this message translates to:
  /// **'Backup finished with {count} failed items.'**
  String backupPartialFailure(int count);

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @biometricToggle.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get biometricToggle;

  /// No description provided for @biometricPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Device unlock keeps secure access fast on supported platforms.'**
  String get biometricPendingMessage;

  /// No description provided for @securityPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Email verification and session protection help keep the workspace secure.'**
  String get securityPendingMessage;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutMessage.
  ///
  /// In en, this message translates to:
  /// **'A premium local-first personal finance platform prepared for AI and cloud sync.'**
  String get aboutMessage;

  /// No description provided for @legalAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Legal and privacy'**
  String get legalAndPrivacy;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review how local data, cloud backup, AI, and deletion are handled.'**
  String get privacyPolicySubtitle;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @termsOfUseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the draft product-use terms and limitations.'**
  String get termsOfUseSubtitle;

  /// No description provided for @policyDraftNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft product information'**
  String get policyDraftNoticeTitle;

  /// No description provided for @policyDraftNoticeMessage.
  ///
  /// In en, this message translates to:
  /// **'This neutral placeholder requires legal review before any public release. It is not legal advice or a final policy.'**
  String get policyDraftNoticeMessage;

  /// No description provided for @privacyLocalDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data on this device'**
  String get privacyLocalDataTitle;

  /// No description provided for @privacyLocalDataMessage.
  ///
  /// In en, this message translates to:
  /// **'Financial records are stored locally in the app database and remain the source of truth. The full account deletion flow also erases this local financial data and the pending backup queue on this device.'**
  String get privacyLocalDataMessage;

  /// No description provided for @privacyCloudBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional cloud backup'**
  String get privacyCloudBackupTitle;

  /// No description provided for @privacyCloudBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'Signed-in, non-guest users can opt in to a user-scoped Firestore backup. The current foundation uploads queued changes only; restore and cloud-to-device merge are not available.'**
  String get privacyCloudBackupMessage;

  /// No description provided for @privacyAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI processing'**
  String get privacyAiTitle;

  /// No description provided for @privacyAiMessage.
  ///
  /// In en, this message translates to:
  /// **'AI requests may send the message and limited context needed for the configured provider to respond. AI output can be incomplete or inaccurate, and financial actions still require explicit confirmation.'**
  String get privacyAiMessage;

  /// No description provided for @privacyDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Account and data deletion'**
  String get privacyDeletionTitle;

  /// No description provided for @privacyDeletionMessage.
  ///
  /// In en, this message translates to:
  /// **'After explicit confirmation and any required reauthentication, Delete account removes known Firestore backup collections and the cloud profile, erases local financial records and account-specific preferences, then deletes the Firebase authentication profile. If a stage fails, later destructive stages are stopped so the operation can be retried safely.'**
  String get privacyDeletionMessage;

  /// No description provided for @termsPersonalUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal use'**
  String get termsPersonalUseTitle;

  /// No description provided for @termsPersonalUseMessage.
  ///
  /// In en, this message translates to:
  /// **'CashPilot AI is a personal record-keeping tool. You are responsible for reviewing entries, categories, balances, exchange rates, budgets, and goals for accuracy.'**
  String get termsPersonalUseMessage;

  /// No description provided for @termsFinancialInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial information'**
  String get termsFinancialInfoTitle;

  /// No description provided for @termsFinancialInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'Reports, forecasts, insights, and suggestions are informational product features. They are not financial, investment, tax, accounting, or legal advice.'**
  String get termsFinancialInfoMessage;

  /// No description provided for @termsAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI-assisted actions'**
  String get termsAiTitle;

  /// No description provided for @termsAiMessage.
  ///
  /// In en, this message translates to:
  /// **'AI-generated interpretations may be wrong. Review every proposed action and its account, amount, currency, category, status, and exchange rate before confirmation.'**
  String get termsAiMessage;

  /// No description provided for @termsAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Availability and backups'**
  String get termsAvailabilityTitle;

  /// No description provided for @termsAvailabilityMessage.
  ///
  /// In en, this message translates to:
  /// **'Offline local use can continue for supported features. Cloud backup may be delayed or unavailable and is not a substitute for a verified restore or export process.'**
  String get termsAvailabilityMessage;

  /// No description provided for @aiFinancialDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI output may be inaccurate and is for information only, not financial advice. Review every action before confirming.'**
  String get aiFinancialDisclaimer;

  /// No description provided for @bootstrapFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'CashPilot AI could not start'**
  String get bootstrapFailureTitle;

  /// No description provided for @bootstrapFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'A required local or Firebase service is unavailable. Check your connection and app configuration, then try again.'**
  String get bootstrapFailureMessage;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileGuestName.
  ///
  /// In en, this message translates to:
  /// **'Local profile'**
  String get profileGuestName;

  /// No description provided for @profileLocalAccount.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device'**
  String get profileLocalAccount;

  /// No description provided for @profileBackendPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Account profile'**
  String get profileBackendPendingTitle;

  /// No description provided for @profileBackendPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Manage identity, verification, and account preferences from your secure profile.'**
  String get profileBackendPendingMessage;

  /// No description provided for @authDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure access for your financial workspace.'**
  String get authDefaultSubtitle;

  /// No description provided for @authSecureAccess.
  ///
  /// In en, this message translates to:
  /// **'Secure access'**
  String get authSecureAccess;

  /// No description provided for @authVerifiedSession.
  ///
  /// In en, this message translates to:
  /// **'Verified session'**
  String get authVerifiedSession;

  /// No description provided for @authTermsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to the Terms and acknowledge the Privacy Policy.'**
  String get authTermsPrivacy;

  /// No description provided for @authCheckingSession.
  ///
  /// In en, this message translates to:
  /// **'Checking secure session'**
  String get authCheckingSession;

  /// No description provided for @onboardingTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Track every account.'**
  String get onboardingTrackTitle;

  /// No description provided for @onboardingTrackMessage.
  ///
  /// In en, this message translates to:
  /// **'Bring cash, cards, banks, and wallets into one calm financial cockpit.'**
  String get onboardingTrackMessage;

  /// No description provided for @onboardingAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Financial Assistant.'**
  String get onboardingAiTitle;

  /// No description provided for @onboardingAiMessage.
  ///
  /// In en, this message translates to:
  /// **'Ask smarter questions, review spending, and spot opportunities as your data grows.'**
  String get onboardingAiMessage;

  /// No description provided for @onboardingInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Insights.'**
  String get onboardingInsightsTitle;

  /// No description provided for @onboardingInsightsMessage.
  ///
  /// In en, this message translates to:
  /// **'Understand trends, budgets, and goals with polished reports built for decisions.'**
  String get onboardingInsightsMessage;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'CashPilot AI'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A secure personal finance workspace for accounts, cash flow, and AI-powered insights.'**
  String get authWelcomeSubtitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @loginHeadline.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginHeadline;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue your secure finance session.'**
  String get loginSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @authInvalidForm.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields and try again.'**
  String get authInvalidForm;

  /// No description provided for @registerHeadline.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerHeadline;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start with secure sign-in and finish your profile in the next step.'**
  String get registerSubtitle;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms and Privacy Policy.'**
  String get acceptTerms;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send a secure reset link.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent. Check your inbox to continue.'**
  String get resetLinkSent;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One quick confirmation keeps your account protected.'**
  String get verifyEmailSubtitle;

  /// No description provided for @verifyEmailMessage.
  ///
  /// In en, this message translates to:
  /// **'Open the verification link we sent, then refresh your status here.'**
  String get verifyEmailMessage;

  /// No description provided for @resendEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmail;

  /// No description provided for @refreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get refreshStatus;

  /// No description provided for @verificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent.'**
  String get verificationEmailSent;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @profileCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete profile'**
  String get profileCompletionTitle;

  /// No description provided for @profileCompletionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize CashPilot for your currency, language, and region.'**
  String get profileCompletionSubtitle;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @preferredCurrency.
  ///
  /// In en, this message translates to:
  /// **'Preferred currency'**
  String get preferredCurrency;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @guestModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Guest mode'**
  String get guestModeTitle;

  /// No description provided for @guestModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore the app with a temporary anonymous session.'**
  String get guestModeSubtitle;

  /// No description provided for @guestModeLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Local-first session'**
  String get guestModeLocalTitle;

  /// No description provided for @guestModeLocalMessage.
  ///
  /// In en, this message translates to:
  /// **'You can explore the workspace without sharing personal details.'**
  String get guestModeLocalMessage;

  /// No description provided for @guestModeSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync limited'**
  String get guestModeSyncTitle;

  /// No description provided for @guestModeSyncMessage.
  ///
  /// In en, this message translates to:
  /// **'Backup, multi-device sync, and recovery require a full account.'**
  String get guestModeSyncMessage;

  /// No description provided for @guestModeUpgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade anytime'**
  String get guestModeUpgradeTitle;

  /// No description provided for @guestModeUpgradeMessage.
  ///
  /// In en, this message translates to:
  /// **'Create an account later to unlock verification and protected recovery.'**
  String get guestModeUpgradeMessage;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @guestAccount.
  ///
  /// In en, this message translates to:
  /// **'Guest account'**
  String get guestAccount;

  /// No description provided for @deleteAccountSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this account and all local and cloud financial data.'**
  String get deleteAccountSettingsSubtitle;

  /// No description provided for @accountDataDeletionMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the cloud backup, local financial records, pending backup queue, account preferences, and authentication profile. This action cannot be undone.'**
  String get accountDataDeletionMessage;

  /// No description provided for @confirmFullDataDeletion.
  ///
  /// In en, this message translates to:
  /// **'I understand that my account and all financial data will be permanently deleted.'**
  String get confirmFullDataDeletion;

  /// No description provided for @passwordForEmailAccounts.
  ///
  /// In en, this message translates to:
  /// **'Email/password accounts must enter the current password. Google and Apple accounts will open their provider confirmation.'**
  String get passwordForEmailAccounts;

  /// No description provided for @dataDeletionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Deleting account and all data...'**
  String get dataDeletionInProgress;

  /// No description provided for @dataDeletionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Account and all data deleted.'**
  String get dataDeletionCompleted;

  /// No description provided for @dataDeletionConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm permanent deletion before continuing.'**
  String get dataDeletionConfirmationRequired;

  /// No description provided for @dataDeletionReauthFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not verify your identity. No data was deleted. Check your credentials and try again.'**
  String get dataDeletionReauthFailed;

  /// No description provided for @dataDeletionCloudFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud deletion did not finish. Your account and local data were kept so you can retry safely.'**
  String get dataDeletionCloudFailed;

  /// No description provided for @dataDeletionLocalFailed.
  ///
  /// In en, this message translates to:
  /// **'The cloud backup was removed, but local deletion failed. Your account was kept so you can retry.'**
  String get dataDeletionLocalFailed;

  /// No description provided for @dataDeletionPreferencesFailed.
  ///
  /// In en, this message translates to:
  /// **'Financial records were removed, but account preferences could not be cleared. Your account was kept so you can retry.'**
  String get dataDeletionPreferencesFailed;

  /// No description provided for @dataDeletionAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Your financial data was removed, but the authentication profile could not be deleted. Sign in again and retry.'**
  String get dataDeletionAuthFailed;

  /// No description provided for @verifiedAccount.
  ///
  /// In en, this message translates to:
  /// **'Verified account'**
  String get verifiedAccount;

  /// No description provided for @verifiedAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Your email is verified and your session is protected.'**
  String get verifiedAccountMessage;

  /// No description provided for @profileCompletionSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update display name, region, language, and currency.'**
  String get profileCompletionSettingsSubtitle;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @dashboardErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load dashboard'**
  String get dashboardErrorTitle;

  /// No description provided for @dashboardErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Refresh the page or try again later.'**
  String get dashboardErrorMessage;

  /// No description provided for @totalNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Total net worth'**
  String get totalNetWorth;

  /// No description provided for @monthlyIncome.
  ///
  /// In en, this message translates to:
  /// **'Monthly income'**
  String get monthlyIncome;

  /// No description provided for @monthlyExpense.
  ///
  /// In en, this message translates to:
  /// **'Monthly expense'**
  String get monthlyExpense;

  /// No description provided for @monthlySavings.
  ///
  /// In en, this message translates to:
  /// **'Monthly savings'**
  String get monthlySavings;

  /// No description provided for @yearlyIncome.
  ///
  /// In en, this message translates to:
  /// **'Yearly income'**
  String get yearlyIncome;

  /// No description provided for @yearlyExpense.
  ///
  /// In en, this message translates to:
  /// **'Yearly expense'**
  String get yearlyExpense;

  /// No description provided for @yearlySavings.
  ///
  /// In en, this message translates to:
  /// **'Yearly savings'**
  String get yearlySavings;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get recentTransactions;

  /// No description provided for @spendingChart.
  ///
  /// In en, this message translates to:
  /// **'Spending chart'**
  String get spendingChart;

  /// No description provided for @spendingChartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Top expense categories this month.'**
  String get spendingChartSubtitle;

  /// No description provided for @noSpendingYet.
  ///
  /// In en, this message translates to:
  /// **'No spending yet'**
  String get noSpendingYet;

  /// No description provided for @noSpendingYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Posted expenses will appear here.'**
  String get noSpendingYetMessage;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @openBudgets.
  ///
  /// In en, this message translates to:
  /// **'Open budgets'**
  String get openBudgets;

  /// No description provided for @openGoals.
  ///
  /// In en, this message translates to:
  /// **'Open goals'**
  String get openGoals;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @transferHistory.
  ///
  /// In en, this message translates to:
  /// **'Transfer history'**
  String get transferHistory;

  /// No description provided for @transferScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Move money between your accounts with a clear review before posting.'**
  String get transferScreenSubtitle;

  /// No description provided for @transferBackendPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer workspace'**
  String get transferBackendPendingTitle;

  /// No description provided for @transferBackendPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Review source and destination accounts before posting a paired transfer.'**
  String get transferBackendPendingMessage;

  /// No description provided for @transferExchangeRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange amount required'**
  String get transferExchangeRequiredTitle;

  /// No description provided for @transferExchangeRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'These accounts use different currencies. Enter the amount received by the destination account.'**
  String get transferExchangeRequiredMessage;

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get toAccount;

  /// No description provided for @destinationAmount.
  ///
  /// In en, this message translates to:
  /// **'Destination amount'**
  String get destinationAmount;

  /// No description provided for @transferPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer preview'**
  String get transferPreviewTitle;

  /// No description provided for @transferPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check the exact account and currency effect before creating this transfer.'**
  String get transferPreviewSubtitle;

  /// No description provided for @manualConversionBadge.
  ///
  /// In en, this message translates to:
  /// **'Manual conversion'**
  String get manualConversionBadge;

  /// No description provided for @manualExchangeRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Implied manual rate'**
  String get manualExchangeRateLabel;

  /// No description provided for @exchangeRatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get exchangeRatesTitle;

  /// No description provided for @exchangeRatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manual rates used for conversion and consolidated reporting.'**
  String get exchangeRatesSubtitle;

  /// No description provided for @baseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Base currency'**
  String get baseCurrency;

  /// No description provided for @addExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Add exchange rate'**
  String get addExchangeRate;

  /// No description provided for @editExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Edit exchange rate'**
  String get editExchangeRate;

  /// No description provided for @deleteExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Delete exchange rate'**
  String get deleteExchangeRate;

  /// No description provided for @archiveExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Archive exchange rate'**
  String get archiveExchangeRate;

  /// No description provided for @archiveExchangeRateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archived rates are no longer used for conversions or consolidated totals.'**
  String get archiveExchangeRateConfirm;

  /// No description provided for @fromCurrency.
  ///
  /// In en, this message translates to:
  /// **'From currency'**
  String get fromCurrency;

  /// No description provided for @toCurrency.
  ///
  /// In en, this message translates to:
  /// **'To currency'**
  String get toCurrency;

  /// No description provided for @exchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get exchangeRate;

  /// No description provided for @manualRate.
  ///
  /// In en, this message translates to:
  /// **'Manual rate'**
  String get manualRate;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @missingExchangeRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing exchange rate'**
  String get missingExchangeRateTitle;

  /// No description provided for @missingExchangeRateDescription.
  ///
  /// In en, this message translates to:
  /// **'Some totals are partial because a required currency pair has no active manual rate.'**
  String get missingExchangeRateDescription;

  /// No description provided for @conversionFailed.
  ///
  /// In en, this message translates to:
  /// **'Currency conversion failed.'**
  String get conversionFailed;

  /// No description provided for @sameCurrencyNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Choose two different currencies.'**
  String get sameCurrencyNotAllowed;

  /// No description provided for @invalidExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Enter a rate greater than zero.'**
  String get invalidExchangeRate;

  /// No description provided for @exchangeRateSaved.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate saved.'**
  String get exchangeRateSaved;

  /// No description provided for @exchangeRateDeleted.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate deleted.'**
  String get exchangeRateDeleted;

  /// No description provided for @exchangeRateArchived.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate archived.'**
  String get exchangeRateArchived;

  /// No description provided for @netWorthPartiallyCalculated.
  ///
  /// In en, this message translates to:
  /// **'Net worth is partially calculated.'**
  String get netWorthPartiallyCalculated;

  /// No description provided for @addRateToContinue.
  ///
  /// In en, this message translates to:
  /// **'Add the missing manual rate to complete these totals.'**
  String get addRateToContinue;

  /// No description provided for @selectBaseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select the currency used for consolidated totals.'**
  String get selectBaseCurrency;

  /// No description provided for @convertedTotal.
  ///
  /// In en, this message translates to:
  /// **'Converted total'**
  String get convertedTotal;

  /// No description provided for @originalCurrency.
  ///
  /// In en, this message translates to:
  /// **'Original currency'**
  String get originalCurrency;

  /// No description provided for @rateUsed.
  ///
  /// In en, this message translates to:
  /// **'Rate used'**
  String get rateUsed;

  /// No description provided for @suggestedStoredRate.
  ///
  /// In en, this message translates to:
  /// **'Suggested stored manual rate'**
  String get suggestedStoredRate;

  /// No description provided for @enterExchangeRate.
  ///
  /// In en, this message translates to:
  /// **'Enter exchange rate'**
  String get enterExchangeRate;

  /// No description provided for @exchangeRateRequired.
  ///
  /// In en, this message translates to:
  /// **'An exchange rate or destination amount is required.'**
  String get exchangeRateRequired;

  /// No description provided for @noExchangeRatesTitle.
  ///
  /// In en, this message translates to:
  /// **'No manual rates yet'**
  String get noExchangeRatesTitle;

  /// No description provided for @noExchangeRatesMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a rate when you need to convert balances or transactions between currencies.'**
  String get noExchangeRatesMessage;

  /// No description provided for @exchangeRatesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load exchange rates'**
  String get exchangeRatesErrorTitle;

  /// No description provided for @ratesAreManualNotice.
  ///
  /// In en, this message translates to:
  /// **'Rates are entered manually and are never fetched or guessed automatically.'**
  String get ratesAreManualNotice;

  /// No description provided for @includeArchivedRates.
  ///
  /// In en, this message translates to:
  /// **'Include archived rates'**
  String get includeArchivedRates;

  /// No description provided for @archivedRate.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedRate;

  /// No description provided for @destinationAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the destination amount to complete this preview.'**
  String get destinationAmountRequired;

  /// No description provided for @transferPostedEffectMessage.
  ///
  /// In en, this message translates to:
  /// **'Posted transfers update both account balances immediately.'**
  String get transferPostedEffectMessage;

  /// No description provided for @transferPendingEffectMessage.
  ///
  /// In en, this message translates to:
  /// **'Pending transfers are recorded without changing either balance.'**
  String get transferPendingEffectMessage;

  /// No description provided for @transferSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Review before creating'**
  String get transferSafetyTitle;

  /// No description provided for @transferSafetyMessage.
  ///
  /// In en, this message translates to:
  /// **'CashPilot creates one linked transfer pair after you submit. Cross-currency amounts are entered manually.'**
  String get transferSafetyMessage;

  /// No description provided for @createTransfer.
  ///
  /// In en, this message translates to:
  /// **'Create transfer'**
  String get createTransfer;

  /// No description provided for @transferCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Transfer created.'**
  String get transferCreatedMessage;

  /// No description provided for @transferFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed.'**
  String get transferFailedMessage;

  /// No description provided for @transferCannotBeEditedMessage.
  ///
  /// In en, this message translates to:
  /// **'Transfers cannot be edited directly.'**
  String get transferCannotBeEditedMessage;

  /// No description provided for @transferCannotBeDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'This transfer cannot be deleted safely.'**
  String get transferCannotBeDeletedMessage;

  /// No description provided for @postedTransferCannotBeDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Posted transfers cannot be deleted. Cancel the transfer to reverse it.'**
  String get postedTransferCannotBeDeletedMessage;

  /// No description provided for @missingExchangeRateMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a destination amount or a valid exchange rate.'**
  String get missingExchangeRateMessage;

  /// No description provided for @invalidTransferStateMessage.
  ///
  /// In en, this message translates to:
  /// **'This transfer is incomplete or in an invalid state.'**
  String get invalidTransferStateMessage;

  /// No description provided for @transferIntegrityReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Transfer history needs manual review before any new financial changes.'**
  String get transferIntegrityReviewMessage;

  /// No description provided for @transferReference.
  ///
  /// In en, this message translates to:
  /// **'Transfer reference'**
  String get transferReference;

  /// No description provided for @cancelTransfer.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer'**
  String get cancelTransfer;

  /// No description provided for @transferCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Transfer cancelled.'**
  String get transferCancelledMessage;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @aiActionConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Review AI action'**
  String get aiActionConfirmationTitle;

  /// No description provided for @aiActionConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'CashPilot will only save this after you confirm.'**
  String get aiActionConfirmationMessage;

  /// No description provided for @aiAwaitingConfirmationStatus.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get aiAwaitingConfirmationStatus;

  /// No description provided for @aiExecutingStatus.
  ///
  /// In en, this message translates to:
  /// **'Executing securely'**
  String get aiExecutingStatus;

  /// No description provided for @aiExecutedStatus.
  ///
  /// In en, this message translates to:
  /// **'Executed'**
  String get aiExecutedStatus;

  /// No description provided for @aiConfirmationSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing happens before you confirm'**
  String get aiConfirmationSafetyTitle;

  /// No description provided for @aiConfirmationSafetyMessage.
  ///
  /// In en, this message translates to:
  /// **'Review the details below. CashPilot executes this action once, only after confirmation.'**
  String get aiConfirmationSafetyMessage;

  /// No description provided for @aiActionConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'AI action saved.'**
  String get aiActionConfirmedMessage;

  /// No description provided for @aiActionCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'AI action cancelled.'**
  String get aiActionCancelledMessage;

  /// No description provided for @aiActionInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'This AI draft needs review before it can be saved.'**
  String get aiActionInvalidMessage;

  /// No description provided for @aiAmbiguousAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Which account should I use?'**
  String get aiAmbiguousAccountMessage;

  /// No description provided for @aiActionAlreadyExecutedMessage.
  ///
  /// In en, this message translates to:
  /// **'This AI action has already been executed.'**
  String get aiActionAlreadyExecutedMessage;

  /// No description provided for @aiClarificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Clarification needed'**
  String get aiClarificationTitle;

  /// No description provided for @aiActionExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense draft'**
  String get aiActionExpenseTitle;

  /// No description provided for @aiActionIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Income draft'**
  String get aiActionIncomeTitle;

  /// No description provided for @aiActionTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer draft'**
  String get aiActionTransferTitle;

  /// No description provided for @aiActionQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get aiActionQuestionTitle;

  /// No description provided for @aiDetectedItem.
  ///
  /// In en, this message translates to:
  /// **'Detected item'**
  String get aiDetectedItem;

  /// No description provided for @aiSuggestedCategory.
  ///
  /// In en, this message translates to:
  /// **'Suggested category'**
  String get aiSuggestedCategory;

  /// No description provided for @aiCategoryConfidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'High confidence'**
  String get aiCategoryConfidenceHigh;

  /// No description provided for @aiCategoryConfidenceSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get aiCategoryConfidenceSuggested;

  /// No description provided for @aiCategoryConfidenceNeedsChoice.
  ///
  /// In en, this message translates to:
  /// **'Needs your choice'**
  String get aiCategoryConfidenceNeedsChoice;

  /// No description provided for @aiCategorySourceExplicit.
  ///
  /// In en, this message translates to:
  /// **'Chosen from your message'**
  String get aiCategorySourceExplicit;

  /// No description provided for @aiCategorySourceUserRule.
  ///
  /// In en, this message translates to:
  /// **'Your saved rule'**
  String get aiCategorySourceUserRule;

  /// No description provided for @aiCategorySourcePayee.
  ///
  /// In en, this message translates to:
  /// **'Payee default'**
  String get aiCategorySourcePayee;

  /// No description provided for @aiCategorySourceAlias.
  ///
  /// In en, this message translates to:
  /// **'Item match'**
  String get aiCategorySourceAlias;

  /// No description provided for @aiCategorySourceAi.
  ///
  /// In en, this message translates to:
  /// **'Semantic suggestion'**
  String get aiCategorySourceAi;

  /// No description provided for @aiCategorySourceKeyword.
  ///
  /// In en, this message translates to:
  /// **'Local keyword match'**
  String get aiCategorySourceKeyword;

  /// No description provided for @aiCategorySourceFallback.
  ///
  /// In en, this message translates to:
  /// **'No confident match'**
  String get aiCategorySourceFallback;

  /// No description provided for @aiEditCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get aiEditCategory;

  /// No description provided for @aiIncomeSourceType.
  ///
  /// In en, this message translates to:
  /// **'Income source type'**
  String get aiIncomeSourceType;

  /// No description provided for @aiIncomeSourceName.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get aiIncomeSourceName;

  /// No description provided for @aiIncomeSourceIdentityHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the person or organization the money came from'**
  String get aiIncomeSourceIdentityHint;

  /// No description provided for @aiIncomeDestinationAccount.
  ///
  /// In en, this message translates to:
  /// **'Destination account'**
  String get aiIncomeDestinationAccount;

  /// No description provided for @aiRecordIncomeOffer.
  ///
  /// In en, this message translates to:
  /// **'It sounds like money came in. Would you like to record it?'**
  String get aiRecordIncomeOffer;

  /// No description provided for @aiRecordTransactionOffer.
  ///
  /// In en, this message translates to:
  /// **'Would you like to record this financial activity?'**
  String get aiRecordTransactionOffer;

  /// No description provided for @aiRecordIncomeOfferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Okay — I did not record anything.'**
  String get aiRecordIncomeOfferCancelled;

  /// No description provided for @aiIncomeMissingDetails.
  ///
  /// In en, this message translates to:
  /// **'Before I can prepare the preview, choose the receiving account, source classification, category, and transaction date, and identify the source when requested.'**
  String get aiIncomeMissingDetails;

  /// No description provided for @aiIncomeSpecialReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review this inflow carefully'**
  String get aiIncomeSpecialReviewTitle;

  /// No description provided for @aiIncomeLoanWarning.
  ///
  /// In en, this message translates to:
  /// **'Loan proceeds increase cash but are a liability, not earned income.'**
  String get aiIncomeLoanWarning;

  /// No description provided for @aiIncomeDebtRepaymentWarning.
  ///
  /// In en, this message translates to:
  /// **'A debt repayment returns money owed to you and is not new earned income.'**
  String get aiIncomeDebtRepaymentWarning;

  /// No description provided for @aiIncomeRefundWarning.
  ///
  /// In en, this message translates to:
  /// **'This is money returned from a purchase, not new earned income.'**
  String get aiIncomeRefundWarning;

  /// No description provided for @aiIncomeReimbursementWarning.
  ///
  /// In en, this message translates to:
  /// **'This repays an earlier expense and remains separate from salary or business revenue.'**
  String get aiIncomeReimbursementWarning;

  /// No description provided for @aiIncomeExternalTransferWarning.
  ///
  /// In en, this message translates to:
  /// **'Clarify whether this external transfer is a gift, reimbursement, sale, salary, or another source.'**
  String get aiIncomeExternalTransferWarning;

  /// No description provided for @aiIncomeOtherWarning.
  ///
  /// In en, this message translates to:
  /// **'Confirm the source type before saving this inflow.'**
  String get aiIncomeOtherWarning;

  /// No description provided for @incomeSourceSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get incomeSourceSalary;

  /// No description provided for @incomeSourceFreelance.
  ///
  /// In en, this message translates to:
  /// **'Freelance'**
  String get incomeSourceFreelance;

  /// No description provided for @incomeSourceBusinessRevenue.
  ///
  /// In en, this message translates to:
  /// **'Business revenue'**
  String get incomeSourceBusinessRevenue;

  /// No description provided for @incomeSourceGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get incomeSourceGift;

  /// No description provided for @incomeSourceDebtRepayment.
  ///
  /// In en, this message translates to:
  /// **'Debt repayment'**
  String get incomeSourceDebtRepayment;

  /// No description provided for @incomeSourceAllowance.
  ///
  /// In en, this message translates to:
  /// **'Allowance'**
  String get incomeSourceAllowance;

  /// No description provided for @incomeSourceRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get incomeSourceRefund;

  /// No description provided for @incomeSourceSale.
  ///
  /// In en, this message translates to:
  /// **'Sale proceeds'**
  String get incomeSourceSale;

  /// No description provided for @incomeSourceRentalIncome.
  ///
  /// In en, this message translates to:
  /// **'Rental income'**
  String get incomeSourceRentalIncome;

  /// No description provided for @incomeSourceGovernmentSupport.
  ///
  /// In en, this message translates to:
  /// **'Government support'**
  String get incomeSourceGovernmentSupport;

  /// No description provided for @incomeSourceScholarship.
  ///
  /// In en, this message translates to:
  /// **'Scholarship'**
  String get incomeSourceScholarship;

  /// No description provided for @incomeSourceInvestmentReturn.
  ///
  /// In en, this message translates to:
  /// **'Investment return'**
  String get incomeSourceInvestmentReturn;

  /// No description provided for @incomeSourceReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get incomeSourceReimbursement;

  /// No description provided for @incomeSourcePrize.
  ///
  /// In en, this message translates to:
  /// **'Prize'**
  String get incomeSourcePrize;

  /// No description provided for @incomeSourceLoanProceeds.
  ///
  /// In en, this message translates to:
  /// **'Loan proceeds'**
  String get incomeSourceLoanProceeds;

  /// No description provided for @incomeSourceExternalTransfer.
  ///
  /// In en, this message translates to:
  /// **'External transfer'**
  String get incomeSourceExternalTransfer;

  /// No description provided for @incomeSourceOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get incomeSourceOther;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get sortOldest;

  /// No description provided for @sortAmountHigh.
  ///
  /// In en, this message translates to:
  /// **'Highest amount'**
  String get sortAmountHigh;

  /// No description provided for @resultsLabel.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get resultsLabel;

  /// No description provided for @zero.
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get zero;

  /// No description provided for @switchLanguageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch language'**
  String get switchLanguageTooltip;

  /// No description provided for @switchThemeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch theme'**
  String get switchThemeTooltip;

  /// No description provided for @routeNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeNotFoundTitle;

  /// No description provided for @routeNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The requested destination is not available.'**
  String get routeNotFoundMessage;

  /// No description provided for @addPayee.
  ///
  /// In en, this message translates to:
  /// **'Add payee'**
  String get addPayee;

  /// No description provided for @editPayee.
  ///
  /// In en, this message translates to:
  /// **'Edit payee'**
  String get editPayee;

  /// No description provided for @archivePayee.
  ///
  /// In en, this message translates to:
  /// **'Archive payee'**
  String get archivePayee;

  /// No description provided for @restorePayee.
  ///
  /// In en, this message translates to:
  /// **'Restore payee'**
  String get restorePayee;

  /// No description provided for @payeeName.
  ///
  /// In en, this message translates to:
  /// **'Payee name'**
  String get payeeName;

  /// No description provided for @payeeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Payee name is required.'**
  String get payeeNameRequired;

  /// No description provided for @selectPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get selectPayee;

  /// No description provided for @noPayee.
  ///
  /// In en, this message translates to:
  /// **'No payee'**
  String get noPayee;

  /// No description provided for @payeeType.
  ///
  /// In en, this message translates to:
  /// **'Payee type'**
  String get payeeType;

  /// No description provided for @payeeAliases.
  ///
  /// In en, this message translates to:
  /// **'Aliases'**
  String get payeeAliases;

  /// No description provided for @payeeAliasesHint.
  ///
  /// In en, this message translates to:
  /// **'Separate aliases with commas'**
  String get payeeAliasesHint;

  /// No description provided for @payeeDefaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default category'**
  String get payeeDefaultCategory;

  /// No description provided for @payeeDefaultAccount.
  ///
  /// In en, this message translates to:
  /// **'Default account'**
  String get payeeDefaultAccount;

  /// No description provided for @payeeNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get payeeNotes;

  /// No description provided for @payeeTypeMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get payeeTypeMerchant;

  /// No description provided for @payeeTypePerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get payeeTypePerson;

  /// No description provided for @payeeTypeEmployer.
  ///
  /// In en, this message translates to:
  /// **'Employer'**
  String get payeeTypeEmployer;

  /// No description provided for @payeeTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get payeeTypeBank;

  /// No description provided for @payeeTypePaymentService.
  ///
  /// In en, this message translates to:
  /// **'Payment service'**
  String get payeeTypePaymentService;

  /// No description provided for @payeeTypeUtility.
  ///
  /// In en, this message translates to:
  /// **'Utility'**
  String get payeeTypeUtility;

  /// No description provided for @payeeTypeTelecom.
  ///
  /// In en, this message translates to:
  /// **'Telecom'**
  String get payeeTypeTelecom;

  /// No description provided for @payeeTypeGovernment.
  ///
  /// In en, this message translates to:
  /// **'Government'**
  String get payeeTypeGovernment;

  /// No description provided for @payeeTypeSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get payeeTypeSchool;

  /// No description provided for @payeeTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get payeeTypeOther;

  /// No description provided for @payeeAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A payee with this name already exists.'**
  String get payeeAlreadyExists;

  /// No description provided for @aliasAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This alias is already assigned to another payee.'**
  String get aliasAlreadyExists;

  /// No description provided for @ambiguousPayee.
  ///
  /// In en, this message translates to:
  /// **'Which payee did you mean?'**
  String get ambiguousPayee;

  /// No description provided for @payeeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Payee not found.'**
  String get payeeNotFound;

  /// No description provided for @createNewPayeeSuggestion.
  ///
  /// In en, this message translates to:
  /// **'No matching payee was found. You can create one after reviewing the transaction.'**
  String get createNewPayeeSuggestion;

  /// No description provided for @payeeArchivedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payee archived.'**
  String get payeeArchivedMessage;

  /// No description provided for @payeeRestoredMessage.
  ///
  /// In en, this message translates to:
  /// **'Payee restored.'**
  String get payeeRestoredMessage;

  /// No description provided for @payeeSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payee saved.'**
  String get payeeSavedMessage;

  /// No description provided for @includeArchivedPayees.
  ///
  /// In en, this message translates to:
  /// **'Include archived'**
  String get includeArchivedPayees;

  /// No description provided for @archivedPayee.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedPayee;

  /// No description provided for @filterByType.
  ///
  /// In en, this message translates to:
  /// **'Filter by type'**
  String get filterByType;

  /// No description provided for @allPayeeTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get allPayeeTypes;

  /// No description provided for @noDefaultSelection.
  ///
  /// In en, this message translates to:
  /// **'No default'**
  String get noDefaultSelection;

  /// No description provided for @lastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get lastUsed;

  /// No description provided for @neverUsed.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get neverUsed;

  /// No description provided for @relatedTransactions.
  ///
  /// In en, this message translates to:
  /// **'Related transactions'**
  String get relatedTransactions;

  /// No description provided for @scanReceipt.
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get scanReceipt;

  /// No description provided for @receiptScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt scanner'**
  String get receiptScannerTitle;

  /// No description provided for @receiptScannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capture a receipt or import an image, then review every extracted value.'**
  String get receiptScannerSubtitle;

  /// No description provided for @takeReceiptPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takeReceiptPhoto;

  /// No description provided for @importReceiptImage.
  ///
  /// In en, this message translates to:
  /// **'Import image'**
  String get importReceiptImage;

  /// No description provided for @documentScannerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Document scanner is unavailable on this device.'**
  String get documentScannerUnavailable;

  /// No description provided for @receiptPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Send this receipt to Firebase AI?'**
  String get receiptPrivacyTitle;

  /// No description provided for @receiptPrivacyMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected receipt image is sent to Firebase AI for extraction. Images can contain merchant, purchase, tax, or address details. CashPilot does not send account balances or transaction history with it. Review all results before confirming.'**
  String get receiptPrivacyMessage;

  /// No description provided for @analyzeReceipt.
  ///
  /// In en, this message translates to:
  /// **'Analyze receipt'**
  String get analyzeReceipt;

  /// No description provided for @manualReceiptReview.
  ///
  /// In en, this message translates to:
  /// **'Review manually'**
  String get manualReceiptReview;

  /// No description provided for @receiptReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review receipt'**
  String get receiptReviewTitle;

  /// No description provided for @receiptReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI extraction may be inaccurate. Nothing is saved as a transaction until you confirm.'**
  String get receiptReviewSubtitle;

  /// No description provided for @receiptMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get receiptMerchant;

  /// No description provided for @receiptDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get receiptDocumentType;

  /// No description provided for @receiptPaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment status'**
  String get receiptPaymentStatus;

  /// No description provided for @receiptPurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase date'**
  String get receiptPurchaseDate;

  /// No description provided for @receiptSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get receiptSubtotal;

  /// No description provided for @receiptTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get receiptTax;

  /// No description provided for @receiptDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get receiptDiscount;

  /// No description provided for @receiptTip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get receiptTip;

  /// No description provided for @receiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get receiptTotal;

  /// No description provided for @receiptLineItems.
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get receiptLineItems;

  /// No description provided for @receiptAddLineItem.
  ///
  /// In en, this message translates to:
  /// **'Add line item'**
  String get receiptAddLineItem;

  /// No description provided for @receiptWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get receiptWarnings;

  /// No description provided for @receiptKeepImage.
  ///
  /// In en, this message translates to:
  /// **'Keep image locally'**
  String get receiptKeepImage;

  /// No description provided for @receiptDeleteImage.
  ///
  /// In en, this message translates to:
  /// **'Delete image after extraction'**
  String get receiptDeleteImage;

  /// No description provided for @receiptRetentionRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose what CashPilot should do with the local image.'**
  String get receiptRetentionRequired;

  /// No description provided for @receiptWarningsAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'I reviewed the warnings and extracted values.'**
  String get receiptWarningsAcknowledgement;

  /// No description provided for @receiptSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get receiptSaveDraft;

  /// No description provided for @receiptConfirmTransaction.
  ///
  /// In en, this message translates to:
  /// **'Confirm transaction'**
  String get receiptConfirmTransaction;

  /// No description provided for @receiptCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Receipt transaction created.'**
  String get receiptCreatedMessage;

  /// No description provided for @receiptSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Receipt draft saved.'**
  String get receiptSavedMessage;

  /// No description provided for @receiptNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Add an account before confirming this receipt.'**
  String get receiptNoAccounts;

  /// No description provided for @receiptNoItems.
  ///
  /// In en, this message translates to:
  /// **'Add or review line items and categories before confirming.'**
  String get receiptNoItems;

  /// No description provided for @receiptDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'A possible duplicate receipt or transaction was found.'**
  String get receiptDuplicateWarning;

  /// No description provided for @receiptAnalysisProgress.
  ///
  /// In en, this message translates to:
  /// **'Analyzing the receipt securely…'**
  String get receiptAnalysisProgress;

  /// No description provided for @receiptPreparingProgress.
  ///
  /// In en, this message translates to:
  /// **'Preparing the receipt image…'**
  String get receiptPreparingProgress;

  /// No description provided for @receiptSavingDraftProgress.
  ///
  /// In en, this message translates to:
  /// **'Saving a private review draft…'**
  String get receiptSavingDraftProgress;

  /// No description provided for @receiptLoadingContextProgress.
  ///
  /// In en, this message translates to:
  /// **'Preparing categories and accounts for review…'**
  String get receiptLoadingContextProgress;

  /// No description provided for @aiLocalGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi! How can I help today? Ask what I can do to see the capabilities currently available.'**
  String get aiLocalGreeting;

  /// No description provided for @aiLocalSmallTalk.
  ///
  /// In en, this message translates to:
  /// **'I’m doing well, thanks! What can I help you with today?'**
  String get aiLocalSmallTalk;

  /// No description provided for @aiCapabilityLocal.
  ///
  /// In en, this message translates to:
  /// **'I can answer greetings, help, and capability questions locally without a network call.'**
  String get aiCapabilityLocal;

  /// No description provided for @aiCapabilityGeneralChat.
  ///
  /// In en, this message translates to:
  /// **'General questions are configured through a remote provider; each request still verifies availability.'**
  String get aiCapabilityGeneralChat;

  /// No description provided for @aiCapabilityCurrentKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Current-information lookup is configured with sources; each request still verifies availability.'**
  String get aiCapabilityCurrentKnowledge;

  /// No description provided for @aiCapabilityPersonalFinance.
  ///
  /// In en, this message translates to:
  /// **'When owner scope and consent remain valid, I can analyze the CashPilot financial data you allow.'**
  String get aiCapabilityPersonalFinance;

  /// No description provided for @aiCapabilityFinancialDrafts.
  ///
  /// In en, this message translates to:
  /// **'I can prepare reviewable financial drafts.'**
  String get aiCapabilityFinancialDrafts;

  /// No description provided for @aiCapabilityReceiptVision.
  ///
  /// In en, this message translates to:
  /// **'Receipt image analysis is configured after your consent; each request still verifies availability.'**
  String get aiCapabilityReceiptVision;

  /// No description provided for @aiCapabilityNavigation.
  ///
  /// In en, this message translates to:
  /// **'I can open supported CashPilot screens when you ask.'**
  String get aiCapabilityNavigation;

  /// No description provided for @aiCapabilityFinancialDisabled.
  ///
  /// In en, this message translates to:
  /// **'Personal financial analysis and actions are currently disabled.'**
  String get aiCapabilityFinancialDisabled;

  /// No description provided for @aiCapabilityConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'No financial change happens without your review and confirmation.'**
  String get aiCapabilityConfirmationRequired;

  /// No description provided for @aiUnavailablePlatformNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'General conversation is not configured on this platform. Local greetings and help are still available.'**
  String get aiUnavailablePlatformNotConfigured;

  /// No description provided for @aiUnavailableFirebaseNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'General conversation could not start because Firebase is not ready. Check the app setup and try again.'**
  String get aiUnavailableFirebaseNotInitialized;

  /// No description provided for @aiUnavailableFirebaseAi.
  ///
  /// In en, this message translates to:
  /// **'The configured conversation model is currently unavailable.'**
  String get aiUnavailableFirebaseAi;

  /// No description provided for @aiUnavailableAppCheck.
  ///
  /// In en, this message translates to:
  /// **'Device verification is getting ready. Try again in a moment.'**
  String get aiUnavailableAppCheck;

  /// No description provided for @aiUnavailableAppCheckTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Device verification took too long. Check your connection and try again.'**
  String get aiUnavailableAppCheckTimedOut;

  /// No description provided for @aiUnavailableAppCheckRejected.
  ///
  /// In en, this message translates to:
  /// **'This development build could not be verified on this device. Check the emulator\'s App Check registration.'**
  String get aiUnavailableAppCheckRejected;

  /// No description provided for @aiUnavailableAuthenticationNotReady.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in is still getting ready. Try again in a moment.'**
  String get aiUnavailableAuthenticationNotReady;

  /// No description provided for @aiUnavailableAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use general conversation. Greetings and help remain available locally.'**
  String get aiUnavailableAuthentication;

  /// No description provided for @aiUnavailableGatewayDisabled.
  ///
  /// In en, this message translates to:
  /// **'No general-conversation provider is enabled. Local greetings and help are still available.'**
  String get aiUnavailableGatewayDisabled;

  /// No description provided for @aiUnavailableGatewayUrlMissing.
  ///
  /// In en, this message translates to:
  /// **'The conversation gateway address is not configured, and no fallback provider is available.'**
  String get aiUnavailableGatewayUrlMissing;

  /// No description provided for @aiUnavailableGatewayUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The conversation service could not be reached. Check your connection and try again.'**
  String get aiUnavailableGatewayUnreachable;

  /// No description provided for @aiUnavailableOffline.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Check your internet connection and try again.'**
  String get aiUnavailableOffline;

  /// No description provided for @aiUnavailableProviderTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The conversation service took too long to respond. Try again.'**
  String get aiUnavailableProviderTimedOut;

  /// No description provided for @aiUnavailableProviderRejected.
  ///
  /// In en, this message translates to:
  /// **'The conversation service rejected this request safely. Rephrase it or try again.'**
  String get aiUnavailableProviderRejected;

  /// No description provided for @aiUnavailableFinancialAccess.
  ///
  /// In en, this message translates to:
  /// **'Access to personal financial analysis is currently disabled.'**
  String get aiUnavailableFinancialAccess;

  /// No description provided for @aiUnavailableOwnerScope.
  ///
  /// In en, this message translates to:
  /// **'Your private CashPilot data is not ready for this request. General conversation and local help may still be available.'**
  String get aiUnavailableOwnerScope;

  /// No description provided for @aiUnavailableLegacyData.
  ///
  /// In en, this message translates to:
  /// **'Personal financial analysis is paused until the legacy-data ownership check is resolved.'**
  String get aiUnavailableLegacyData;

  /// No description provided for @aiUnavailableReceiptVision.
  ///
  /// In en, this message translates to:
  /// **'Receipt image analysis is currently unavailable. You can still review the receipt manually.'**
  String get aiUnavailableReceiptVision;

  /// No description provided for @aiUnavailableTemporary.
  ///
  /// In en, this message translates to:
  /// **'The conversation could not be completed temporarily. Try again.'**
  String get aiUnavailableTemporary;

  /// No description provided for @aiFinancialAnalysisUnavailableWithGeneral.
  ///
  /// In en, this message translates to:
  /// **'General conversation is available, but analysis of your financial data is currently disabled.'**
  String get aiFinancialAnalysisUnavailableWithGeneral;

  /// No description provided for @aiFinancialAnalysisUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Analysis of your financial data is currently disabled.'**
  String get aiFinancialAnalysisUnavailable;

  /// No description provided for @aiNavigationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Assistant navigation is currently disabled. Open the requested screen from the app menu.'**
  String get aiNavigationUnavailable;

  /// No description provided for @aiDiagnosticCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic code'**
  String get aiDiagnosticCodeLabel;

  /// No description provided for @aiOfflineInflationAnswer.
  ///
  /// In en, this message translates to:
  /// **'Inflation is a broad, sustained rise in prices over time, which means the same amount of money buys less. It is commonly measured by tracking the changing cost of a basket of goods and services such as food, housing, and transport.'**
  String get aiOfflineInflationAnswer;

  /// No description provided for @aiOfflineTunisiaCapitalAnswer.
  ///
  /// In en, this message translates to:
  /// **'The capital of Tunisia is Tunis.'**
  String get aiOfflineTunisiaCapitalAnswer;

  /// No description provided for @expenseAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense analysis'**
  String get expenseAnalyticsTitle;

  /// No description provided for @expenseAnalyticsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get expenseAnalyticsThisWeek;

  /// No description provided for @expenseAnalyticsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get expenseAnalyticsThisMonth;

  /// No description provided for @expenseAnalyticsViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get expenseAnalyticsViewDetails;

  /// No description provided for @expenseAnalyticsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total expenses'**
  String get expenseAnalyticsTotal;

  /// No description provided for @expenseAnalyticsPartialTotal.
  ///
  /// In en, this message translates to:
  /// **'Partial total'**
  String get expenseAnalyticsPartialTotal;

  /// No description provided for @expenseAnalyticsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseAnalyticsOther;

  /// No description provided for @expenseAnalyticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No expenses were recorded in this period.'**
  String get expenseAnalyticsEmpty;

  /// No description provided for @expenseAnalyticsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load expense analysis'**
  String get expenseAnalyticsErrorTitle;

  /// No description provided for @expenseAnalyticsErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Your other Home information is still available. Try this card again.'**
  String get expenseAnalyticsErrorMessage;

  /// No description provided for @expenseAnalyticsPartialWarning.
  ///
  /// In en, this message translates to:
  /// **'Some expenses are not included in the total because an exchange rate is unavailable.'**
  String get expenseAnalyticsPartialWarning;

  /// No description provided for @expenseAnalyticsNoPreviousData.
  ///
  /// In en, this message translates to:
  /// **'No previous-period data is available.'**
  String get expenseAnalyticsNoPreviousData;

  /// No description provided for @expenseAnalyticsComparisonUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The comparison is unavailable because some exchange rates are missing.'**
  String get expenseAnalyticsComparisonUnavailable;

  /// No description provided for @expenseAnalyticsLastWeek.
  ///
  /// In en, this message translates to:
  /// **'last week'**
  String get expenseAnalyticsLastWeek;

  /// No description provided for @expenseAnalyticsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'last month'**
  String get expenseAnalyticsLastMonth;

  /// No description provided for @expenseAnalyticsIncreasedComparison.
  ///
  /// In en, this message translates to:
  /// **'Spending increased by {percentage} compared with {period}.'**
  String expenseAnalyticsIncreasedComparison(String percentage, String period);

  /// No description provided for @expenseAnalyticsDecreasedComparison.
  ///
  /// In en, this message translates to:
  /// **'Spending decreased by {percentage} compared with {period}.'**
  String expenseAnalyticsDecreasedComparison(String percentage, String period);

  /// No description provided for @expenseAnalyticsUnchangedComparison.
  ///
  /// In en, this message translates to:
  /// **'Spending is unchanged compared with {period}.'**
  String expenseAnalyticsUnchangedComparison(String period);

  /// No description provided for @expenseAnalyticsSemanticsSummary.
  ///
  /// In en, this message translates to:
  /// **'Total expenses {period} are {total}. The highest category is {category} at {categoryAmount}, representing {percentage}.'**
  String expenseAnalyticsSemanticsSummary(
    String period,
    String total,
    String category,
    String categoryAmount,
    String percentage,
  );

  /// No description provided for @expenseAnalyticsLegendSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category}, {amount}, {percentage}.'**
  String expenseAnalyticsLegendSemantics(
    String category,
    String amount,
    String percentage,
  );

  /// No description provided for @aiFinancialPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review transaction'**
  String get aiFinancialPreviewTitle;

  /// No description provided for @aiFinancialPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only these fields will be stored after you confirm.'**
  String get aiFinancialPreviewSubtitle;

  /// No description provided for @aiFinancialPreviewType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get aiFinancialPreviewType;

  /// No description provided for @aiFinancialPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get aiFinancialPreviewDescription;

  /// No description provided for @aiFinancialPreviewSuggestedCategory.
  ///
  /// In en, this message translates to:
  /// **'Suggested category'**
  String get aiFinancialPreviewSuggestedCategory;

  /// No description provided for @aiFinancialPreviewDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get aiFinancialPreviewDate;

  /// No description provided for @aiFinancialPreviewStorageEffect.
  ///
  /// In en, this message translates to:
  /// **'What will be saved'**
  String get aiFinancialPreviewStorageEffect;

  /// No description provided for @aiFinancialPreviewToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get aiFinancialPreviewToday;

  /// No description provided for @aiFinancialPreviewReject.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get aiFinancialPreviewReject;

  /// No description provided for @aiFinancialPreviewConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get aiFinancialPreviewConfirm;

  /// No description provided for @aiFinancialPreviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Operation cancelled. Nothing was saved.'**
  String get aiFinancialPreviewRejected;

  /// No description provided for @aiFinancialPreviewCategoryAssumption.
  ///
  /// In en, this message translates to:
  /// **'The category is a suggestion based on the transaction wording.'**
  String get aiFinancialPreviewCategoryAssumption;

  /// No description provided for @aiFinancialPreviewPostedExpenseEffect.
  ///
  /// In en, this message translates to:
  /// **'One posted expense will be saved. {amount} will be deducted from {account}.'**
  String aiFinancialPreviewPostedExpenseEffect(String amount, String account);

  /// No description provided for @aiFinancialPreviewPostedIncomeEffect.
  ///
  /// In en, this message translates to:
  /// **'One posted income transaction will be saved. {amount} will be added to {account}.'**
  String aiFinancialPreviewPostedIncomeEffect(String amount, String account);

  /// No description provided for @aiFinancialPreviewPendingEffect.
  ///
  /// In en, this message translates to:
  /// **'One pending transaction will be saved. The balance will not change until it is posted.'**
  String get aiFinancialPreviewPendingEffect;

  /// No description provided for @aiFinancialExpenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense recorded'**
  String get aiFinancialExpenseSaved;

  /// No description provided for @aiFinancialIncomeSaved.
  ///
  /// In en, this message translates to:
  /// **'Income recorded'**
  String get aiFinancialIncomeSaved;

  /// No description provided for @aiFinancialSavedSummary.
  ///
  /// In en, this message translates to:
  /// **'{amount} — {description}'**
  String aiFinancialSavedSummary(String amount, String description);

  /// No description provided for @aiFinancialSavedCategory.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String aiFinancialSavedCategory(String category);

  /// No description provided for @aiFinancialSavedAccount.
  ///
  /// In en, this message translates to:
  /// **'Account: {account}'**
  String aiFinancialSavedAccount(String account);

  /// No description provided for @aiFinancialSavedDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String aiFinancialSavedDate(String date);

  /// No description provided for @aiFinancialSavedStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String aiFinancialSavedStatus(String status);

  /// No description provided for @aiExpenseAccountClarification.
  ///
  /// In en, this message translates to:
  /// **'Which account should this expense use?'**
  String get aiExpenseAccountClarification;

  /// No description provided for @aiFinancialActionsDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial actions are disabled for this account.'**
  String get aiFinancialActionsDisabledTitle;

  /// No description provided for @aiFinancialActionsDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Enable Review Before Execution or Full Control from AI Settings.'**
  String get aiFinancialActionsDisabledBody;

  /// No description provided for @aiOpenAiSettings.
  ///
  /// In en, this message translates to:
  /// **'Open AI Settings'**
  String get aiOpenAiSettings;

  /// No description provided for @aiControlOffFailure.
  ///
  /// In en, this message translates to:
  /// **'AI app control is not enabled for this account. Enable it in Settings. No change was made.'**
  String get aiControlOffFailure;

  /// No description provided for @aiTransactionDraftsDisabledFailure.
  ///
  /// In en, this message translates to:
  /// **'The selected AI control level does not allow transaction drafts. No change was made.'**
  String get aiTransactionDraftsDisabledFailure;

  /// No description provided for @aiConfirmedExecutionDisabledFailure.
  ///
  /// In en, this message translates to:
  /// **'Confirmed financial execution is unavailable in this build. No change was made.'**
  String get aiConfirmedExecutionDisabledFailure;

  /// No description provided for @aiOwnerScopeNotReadyFailure.
  ///
  /// In en, this message translates to:
  /// **'Your account data is not ready for this financial action. Try again after account loading finishes. No change was made.'**
  String get aiOwnerScopeNotReadyFailure;

  /// No description provided for @aiLegacyDataUnresolvedFailure.
  ///
  /// In en, this message translates to:
  /// **'Link the existing local data to this account before creating a financial draft. No change was made.'**
  String get aiLegacyDataUnresolvedFailure;

  /// No description provided for @aiLegacyPolicyUnresolvedFailure.
  ///
  /// In en, this message translates to:
  /// **'Complete this account\'s AI control policy migration in Settings. No change was made.'**
  String get aiLegacyPolicyUnresolvedFailure;

  /// No description provided for @aiStaleControlFailure.
  ///
  /// In en, this message translates to:
  /// **'AI control settings changed while this draft was open. Review the current settings and try again. No change was made.'**
  String get aiStaleControlFailure;

  /// No description provided for @aiGenericDraftPermissionFailure.
  ///
  /// In en, this message translates to:
  /// **'AI app control does not allow this financial draft. No change was made.'**
  String get aiGenericDraftPermissionFailure;

  /// No description provided for @aiOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get aiOpenSettings;

  /// No description provided for @aiFinancialWriteFailure.
  ///
  /// In en, this message translates to:
  /// **'Saving failed. No transaction was saved and no balance changed. Try again.'**
  String get aiFinancialWriteFailure;

  /// No description provided for @aiStalePreviewFailure.
  ///
  /// In en, this message translates to:
  /// **'This transaction preview is stale. Create a new preview and review it again.'**
  String get aiStalePreviewFailure;

  /// No description provided for @aiDuplicateExecutionFailure.
  ///
  /// In en, this message translates to:
  /// **'This transaction was already submitted. No duplicate was created.'**
  String get aiDuplicateExecutionFailure;

  /// No description provided for @aiFinancialVerificationFailure.
  ///
  /// In en, this message translates to:
  /// **'CashPilot could not verify the saved transaction. No success was reported.'**
  String get aiFinancialVerificationFailure;

  /// No description provided for @aiInvalidFinancialDraftFailure.
  ///
  /// In en, this message translates to:
  /// **'The transaction details are no longer valid. Review them and try again.'**
  String get aiInvalidFinancialDraftFailure;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
