import 'package:decimal/decimal.dart';

import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../budgets/domain/enums/budget_period_type.dart';
import '../../../budgets/domain/failures/budget_failure_codes.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_classification_rule.dart';
import '../../../categories/domain/services/category_suggestion_resolver.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../exchange_rates/domain/entities/stored_exchange_rate.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../../goals/domain/entities/goal.dart';
import '../../../goals/domain/entities/goal_contribution.dart';
import '../../../goals/domain/enums/goal_type.dart';
import '../../../goals/domain/failures/goal_failure_codes.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../income_sources/domain/services/income_source_resolver.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../payees/domain/entities/payee_resolution.dart';
import '../../../payees/domain/services/payee_resolver.dart';
import '../../../payment_methods/payment_methods.dart'
    show LibyanPaymentMethodCatalog, PaymentMethod, PaymentMethodDefinition;
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/ai_action.dart';
import '../entities/ai_intent.dart';
import '../entities/ai_structured_action_output.dart';
import '../entities/ai_transaction_draft.dart';

class AiActionDraftFactory {
  const AiActionDraftFactory({
    PayeeResolver resolver = const PayeeResolver(),
    CategorySuggestionResolver categoryResolver =
        const CategorySuggestionResolver(),
    IncomeSourceResolver incomeSourceResolver = const IncomeSourceResolver(),
  }) : _resolver = resolver,
       _categoryResolver = categoryResolver,
       _incomeSourceResolver = incomeSourceResolver;

  final PayeeResolver _resolver;
  final CategorySuggestionResolver _categoryResolver;
  final IncomeSourceResolver _incomeSourceResolver;

  AiAction fromParseResult({
    required AiTransactionParseResult result,
    required String originalInput,
    String unsupportedMessage =
        'I could not identify a supported financial action.',
  }) {
    return switch (result) {
      AiTransactionDraft(:final type) when type == TransactionType.expense =>
        CreateExpenseDraft(result),
      AiTransactionDraft(:final type) when type == TransactionType.income =>
        CreateIncomeDraft(result),
      AiTransactionDraft() => ClarificationRequiredAction(
        message: 'Unsupported transaction draft.',
      ),
      AiTransactionClarification(:final message) => ClarificationRequiredAction(
        message: message,
      ),
      AiTransactionParseFailure(:final message) =>
        _questionLike(originalInput)
            ? AskQuestionAction(question: originalInput)
            : ClarificationRequiredAction(
                message: unsupportedMessage.isEmpty
                    ? message
                    : unsupportedMessage,
              ),
    };
  }

  AiAction fromStructuredOutput({
    required AiStructuredActionOutput output,
    required String originalInput,
    required List<Account> accounts,
    required List<Category> categories,
    required String baseCurrencyCode,
    required String accountClarificationMessage,
    List<Payee> payees = const <Payee>[],
    String ambiguousPayeeMessage = 'Which payee did you mean?',
    List<StoredExchangeRate> exchangeRates = const <StoredExchangeRate>[],
    String exchangeRateClarificationMessage =
        'Add an exchange rate or destination amount.',
    String categoryClarificationMessage = 'Which category should I use?',
    List<Goal> goals = const <Goal>[],
    List<CategoryClassificationRule> categoryRules =
        const <CategoryClassificationRule>[],
    String goalClarificationMessage = 'Which goal should I use?',
    String unknownIntentClarificationMessage =
        'I could not identify a supported financial action.',
  }) {
    if (output.clarificationQuestion case final question?
        when question.isNotEmpty) {
      return ClarificationRequiredAction(message: question);
    }

    return switch (output.intent) {
      AiIntent.createExpense || AiIntent.createIncome => _transactionAction(
        output: output,
        originalInput: originalInput,
        accounts: accounts,
        categories: categories,
        baseCurrencyCode: baseCurrencyCode,
        accountClarificationMessage: accountClarificationMessage,
        payees: payees,
        ambiguousPayeeMessage: ambiguousPayeeMessage,
        categoryRules: categoryRules,
      ),
      AiIntent.createTransfer => _transferAction(
        output: output,
        originalInput: originalInput,
        accounts: accounts,
        baseCurrencyCode: baseCurrencyCode,
        accountClarificationMessage: accountClarificationMessage,
        exchangeRates: exchangeRates,
        exchangeRateClarificationMessage: exchangeRateClarificationMessage,
      ),
      AiIntent.createCategory => _categoryAction(output),
      AiIntent.createBudget => _budgetAction(
        output: output,
        originalInput: originalInput,
        categories: categories,
        baseCurrencyCode: baseCurrencyCode,
        categoryClarificationMessage: categoryClarificationMessage,
        categoryRules: categoryRules,
      ),
      AiIntent.createGoal => _goalAction(
        output: output,
        originalInput: originalInput,
        baseCurrencyCode: baseCurrencyCode,
      ),
      AiIntent.addGoalContribution => _goalContributionAction(
        output: output,
        originalInput: originalInput,
        goals: goals,
        baseCurrencyCode: baseCurrencyCode,
        clarificationMessage: goalClarificationMessage,
      ),
      AiIntent.updateTransaction ||
      AiIntent.undoAction => BlockedAiAction(blockedIntent: output.intent),
      AiIntent.askFinancialQuestion || AiIntent.currencyConversionQuestion =>
        AskQuestionAction(question: output.description ?? originalInput),
      AiIntent.greeting ||
      AiIntent.smallTalk ||
      AiIntent.help ||
      AiIntent.supportedCapabilities ||
      AiIntent.clarificationResponse => ClarificationRequiredAction(
        message: unknownIntentClarificationMessage,
      ),
      AiIntent.deleteAccount ||
      AiIntent.deleteTransaction ||
      AiIntent.deleteCategory ||
      AiIntent.deletePayee ||
      AiIntent.bulkDelete ||
      AiIntent.resetData => BlockedAiAction(blockedIntent: output.intent),
      AiIntent.unknown => ClarificationRequiredAction(
        message: unknownIntentClarificationMessage,
      ),
    };
  }

  AiAction _transactionAction({
    required AiStructuredActionOutput output,
    required String originalInput,
    required List<Account> accounts,
    required List<Category> categories,
    required String baseCurrencyCode,
    required String accountClarificationMessage,
    required List<Payee> payees,
    required String ambiguousPayeeMessage,
    required List<CategoryClassificationRule> categoryRules,
  }) {
    final amount = _amount(output.amount);
    if (amount == null) {
      return const ClarificationRequiredAction(
        message: 'I could not find a valid amount.',
      );
    }

    if (output.isInternalTransfer == true &&
        output.intent == AiIntent.createIncome) {
      return ClarificationRequiredAction(
        message:
            output.clarificationQuestion ??
            'This appears to be a transfer between your own accounts, not income.',
      );
    }

    final type = output.intent == AiIntent.createIncome
        ? TransactionType.income
        : TransactionType.expense;
    final payeeHint = type == TransactionType.income
        ? output.incomeSourcePayeeHint ?? output.payeeHint
        : output.payeeHint;
    final payeeResolution = payeeHint == null
        ? null
        : _resolver.resolve(payeeHint, payees);
    if (payeeResolution is PayeeAmbiguous) {
      return ClarificationRequiredAction(message: ambiguousPayeeMessage);
    }
    final payee = payeeResolution is PayeeResolved
        ? payeeResolution.payee
        : null;

    final explicitAccountHint =
        (type == TransactionType.income
                ? output.destinationAccountHint ?? output.accountHint
                : output.accountHint)
            ?.trim() ??
        '';
    final explicitAccount = explicitAccountHint.isEmpty
        ? null
        : _resolveAccount(
            hint: explicitAccountHint,
            accounts: accounts,
            allowSingleFallback: false,
          );
    final defaultAccount = payee?.defaultAccountId == null
        ? null
        : accounts
              .where((account) => account.id == payee!.defaultAccountId)
              .firstOrNull;
    final hintText = [
      output.accountHint,
      output.destinationAccountHint,
      output.description,
      originalInput,
    ].nonNulls.join(' ');
    final account = type == TransactionType.income
        ? explicitAccount ??
              _resolveAccount(
                hint: hintText,
                accounts: accounts,
                allowSingleFallback: false,
              )
        : explicitAccount ??
              (defaultAccount?.isArchived == false ? defaultAccount : null) ??
              _resolveAccount(hint: hintText, accounts: accounts);
    if (account == null) {
      return ClarificationRequiredAction(message: accountClarificationMessage);
    }

    final paymentMethodDefinition = LibyanPaymentMethodCatalog.matchAlias(
      hintText,
    );
    final specialIncomeType = output.isLoanProceeds == true
        ? IncomeSourceType.loanProceeds
        : output.isReimbursement == true
        ? IncomeSourceType.reimbursement
        : output.isRefund == true
        ? IncomeSourceType.refund
        : output.incomeSourceType;
    final incomeSuggestion = type == TransactionType.income
        ? _incomeSourceResolver.resolve(
            input: originalInput,
            categories: categories,
            accounts: accounts,
            sourcePayee: payee,
            destinationAccountHint:
                output.destinationAccountHint ?? output.accountHint,
            explicitDestinationAccountId: account.id,
            sourceNameHint: output.incomeSourceHint ?? payeeHint,
            aiSourceType: specialIncomeType,
            aiConfidence: output.confidence,
            clarificationQuestion:
                output.clarificationQuestion ??
                'What kind of income is this, and which account received it?',
          )
        : null;
    if (incomeSuggestion?.isInternalTransfer == true ||
        incomeSuggestion?.requiresClarification == true) {
      return ClarificationRequiredAction(
        message:
            incomeSuggestion?.clarificationQuestion ??
            'Please clarify this income source.',
      );
    }
    final categorySuggestion = _categoryResolver.resolve(
      input: originalInput,
      categories: categories,
      payeeDefaultCategoryId: payee?.defaultCategoryId,
      aiCategoryHint: output.categoryHint ?? incomeSuggestion?.categoryHint,
      aiConfidence: output.categoryConfidence ?? output.confidence,
      aiAlternativeHints: output.categoryAlternatives,
      userRules: categoryRules,
      categoryType: type == TransactionType.income
          ? CategoryType.income
          : CategoryType.expense,
    );
    final category =
        type == TransactionType.income || categorySuggestion.categoryId == null
        ? null
        : categories
              .where((category) => category.id == categorySuggestion.categoryId)
              .firstOrNull;
    final draft = AiTransactionDraft(
      type: type,
      amount: Money(
        amount: amount,
        currencyCode: output.currency ?? account.currencyCode,
      ),
      account: account,
      category: category,
      paymentMethod:
          paymentMethodDefinition?.transactionPaymentMethod ??
          _cashPaymentMethod(hintText) ??
          _singleLinkedPaymentMethod(account) ??
          PaymentMethod.other,
      paymentMethodDefinition: paymentMethodDefinition,
      note: output.description ?? originalInput,
      payee: payee,
      payeeHint: payeeHint,
      itemDescription:
          output.itemDescription ??
          output.description ??
          categorySuggestion.matchedPhrase,
      categorySuggestion: categorySuggestion,
      incomeSourceSuggestion: incomeSuggestion,
      transactionDate: type == TransactionType.income
          ? _transactionDateMentionedIn(originalInput)
          : _transactionDate(output.dateText),
    );

    return type == TransactionType.income
        ? CreateIncomeDraft(draft)
        : CreateExpenseDraft(draft);
  }

  AiAction _transferAction({
    required AiStructuredActionOutput output,
    required String originalInput,
    required List<Account> accounts,
    required String baseCurrencyCode,
    required String accountClarificationMessage,
    required List<StoredExchangeRate> exchangeRates,
    required String exchangeRateClarificationMessage,
  }) {
    final amount = _amount(output.amount);
    if (amount == null) {
      return const ClarificationRequiredAction(
        message: 'I could not find a valid transfer amount.',
      );
    }

    final sourceAccount = _resolveAccount(
      hint: output.sourceAccountHint ?? output.accountHint ?? '',
      accounts: accounts,
      allowSingleFallback: false,
    );
    final destinationAccount = _resolveAccount(
      hint: output.destinationAccountHint ?? output.payeeHint ?? '',
      accounts: accounts,
      allowSingleFallback: false,
    );
    if (sourceAccount == null || destinationAccount == null) {
      return ClarificationRequiredAction(message: accountClarificationMessage);
    }

    final sourceAmount = Money(
      amount: amount,
      currencyCode: output.currency ?? sourceAccount.currencyCode,
    );
    final sourceCurrency = sourceAccount.currencyCode.toUpperCase();
    final destinationCurrency = destinationAccount.currencyCode.toUpperCase();
    final crossCurrency = sourceCurrency != destinationCurrency;
    final explicitRateValue = _explicitExchangeRate(originalInput);
    final explicitDestinationValue = _explicitDestinationAmount(
      output.destinationAmount,
      originalInput,
    );
    final explicitRate = explicitRateValue == null
        ? null
        : ExchangeRate(
            fromCurrencyCode: sourceCurrency,
            toCurrencyCode: destinationCurrency,
            rate: explicitRateValue,
            asOf: DateTime.now().toUtc(),
          );
    final destinationAmount = explicitDestinationValue == null
        ? explicitRate == null
              ? null
              : Money(
                  amount: amount * explicitRate.rate,
                  currencyCode: destinationCurrency,
                )
        : Money(
            amount: explicitDestinationValue,
            currencyCode: destinationCurrency,
          );
    final storedRate =
        crossCurrency && explicitRate == null && destinationAmount == null
        ? _storedExchangeRate(
            sourceCurrency,
            destinationCurrency,
            exchangeRates,
          )
        : null;
    if (crossCurrency &&
        explicitRate == null &&
        destinationAmount == null &&
        storedRate == null) {
      return ClarificationRequiredAction(
        message: exchangeRateClarificationMessage,
      );
    }
    final rate = explicitRate ?? storedRate;

    return CreateTransferDraft(
      sourceAccount: sourceAccount,
      destinationAccount: destinationAccount,
      sourceAmount: sourceAmount,
      destinationAmount:
          destinationAmount ??
          (rate == null
              ? null
              : Money(
                  amount: amount * rate.rate,
                  currencyCode: destinationCurrency,
                )),
      exchangeRate: rate,
      note: output.description,
    );
  }

  Decimal? _explicitExchangeRate(String input) {
    final match = RegExp(
      r'(?:exchange\s+rate|rate|بسعر(?:\s+صرف)?|سعر(?:\s+صرف)?)\s*(?:of|هو|=|:)?\s*(\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    ).firstMatch(input);
    final value = Decimal.tryParse(match?.group(1)?.replaceAll(',', '.') ?? '');
    return value != null && value > Decimal.zero ? value : null;
  }

  Decimal? _explicitDestinationAmount(String? value, String input) {
    final parsed = _amount(value);
    if (parsed == null || parsed <= Decimal.zero) {
      return null;
    }
    final normalized = CurrencyCatalog.normalizeText(input);
    final hasMarker =
        normalized.contains('destination') ||
        normalized.contains('target amount') ||
        normalized.contains('received') ||
        normalized.contains('مبلغ الوجهه') ||
        normalized.contains('وصل') ||
        normalized.contains('استلم');
    final normalizedValue = value!.replaceAll(',', '.');
    return hasMarker && input.replaceAll(',', '.').contains(normalizedValue)
        ? parsed
        : null;
  }

  ExchangeRate? _storedExchangeRate(
    String from,
    String to,
    List<StoredExchangeRate> rates,
  ) {
    final direct = rates
        .where(
          (rate) =>
              !rate.isArchived &&
              rate.baseCurrency == from &&
              rate.quoteCurrency == to,
        )
        .firstOrNull;
    if (direct != null) {
      return ExchangeRate(
        fromCurrencyCode: from,
        toCurrencyCode: to,
        rate: direct.rate,
        asOf: direct.fetchedAt,
      );
    }
    final reverse = rates
        .where(
          (rate) =>
              !rate.isArchived &&
              rate.baseCurrency == to &&
              rate.quoteCurrency == from,
        )
        .firstOrNull;
    if (reverse == null) {
      return null;
    }
    return ExchangeRate(
      fromCurrencyCode: from,
      toCurrencyCode: to,
      rate: (Decimal.one / reverse.rate).toDecimal(
        scaleOnInfinitePrecision: 12,
      ),
      asOf: reverse.fetchedAt,
    );
  }

  AiAction _categoryAction(AiStructuredActionOutput output) {
    final name = output.categoryHint ?? output.description;
    if (name == null || name.trim().isEmpty) {
      return const ClarificationRequiredAction(
        message: 'Which category should I create?',
      );
    }

    return CreateCategoryDraft(name: name.trim());
  }

  AiAction _budgetAction({
    required AiStructuredActionOutput output,
    required String originalInput,
    required List<Category> categories,
    required String baseCurrencyCode,
    required String categoryClarificationMessage,
    required List<CategoryClassificationRule> categoryRules,
  }) {
    final amount = _amount(output.amount);
    if (amount == null || amount <= Decimal.zero) {
      return const ClarificationRequiredAction(
        message: 'I could not find a valid budget amount.',
      );
    }
    final categorySuggestion = _categoryResolver.resolve(
      input: originalInput,
      categories: categories,
      aiCategoryHint: output.categoryHint,
      aiConfidence: output.categoryConfidence ?? output.confidence,
      aiAlternativeHints: output.categoryAlternatives,
      userRules: categoryRules,
    );
    final category = categorySuggestion.categoryId == null
        ? null
        : categories
              .where((category) => category.id == categorySuggestion.categoryId)
              .firstOrNull;
    if (category == null) {
      return ClarificationRequiredAction(message: categoryClarificationMessage);
    }
    final periodType = _budgetPeriodType(output.periodType ?? originalInput);
    if (periodType == BudgetPeriodType.custom) {
      return const ClarificationRequiredAction(
        message: 'Please provide a start and end date for the custom budget.',
      );
    }
    final period = _budgetPeriod(periodType, DateTime.now().toUtc());
    try {
      final budget = Budget.create(
        name: category.name,
        categoryId: category.id,
        amount: amount,
        currency: output.currency ?? baseCurrencyCode,
        periodType: periodType,
        startDate: period.start,
        endDate: period.end,
      );
      return CreateBudgetDraft(budget: budget, category: category);
    } on BudgetValidationException catch (error) {
      return ClarificationRequiredAction(
        message: error.code == BudgetFailureCodes.invalidCategory
            ? categoryClarificationMessage
            : error.message,
      );
    }
  }

  AiAction _goalAction({
    required AiStructuredActionOutput output,
    required String originalInput,
    required String baseCurrencyCode,
  }) {
    final amount = _amount(output.amount);
    final title = output.goalHint ?? output.description;
    if (amount == null || amount <= Decimal.zero) {
      return const ClarificationRequiredAction(
        message: 'I could not find a valid goal amount.',
      );
    }
    if (title == null || title.trim().isEmpty) {
      return const ClarificationRequiredAction(
        message: 'What should this goal be called?',
      );
    }
    final type = _goalType(output.goalType ?? originalInput);
    try {
      return CreateGoalDraft(
        goal: Goal.create(
          title: title,
          description: output.description ?? '',
          type: type,
          targetAmount: amount,
          currency: output.currency ?? baseCurrencyCode,
          targetDate: _goalTargetDate(output.dateText, originalInput),
          icon: _goalIcon(type),
          color: _goalColor(type),
        ),
      );
    } on GoalValidationException catch (error) {
      return ClarificationRequiredAction(message: error.message);
    }
  }

  AiAction _goalContributionAction({
    required AiStructuredActionOutput output,
    required String originalInput,
    required List<Goal> goals,
    required String baseCurrencyCode,
    required String clarificationMessage,
  }) {
    final amount = _amount(output.amount);
    if (amount == null || amount <= Decimal.zero) {
      return const ClarificationRequiredAction(
        message: 'I could not find a valid contribution amount.',
      );
    }
    final goal = _resolveGoal(
      hint: output.goalHint ?? output.description ?? originalInput,
      goals: goals,
    );
    if (goal == null) {
      return ClarificationRequiredAction(message: clarificationMessage);
    }
    if (goal.isArchived) {
      return const ClarificationRequiredAction(
        message: 'Archived goals cannot receive contributions.',
      );
    }
    try {
      return AddGoalContributionDraft(
        goal: goal,
        contribution: GoalContribution.create(
          goalId: goal.id,
          amount: amount,
          currency: output.currency ?? baseCurrencyCode,
          note: output.description ?? originalInput,
        ),
      );
    } on GoalValidationException catch (error) {
      return ClarificationRequiredAction(message: error.message);
    }
  }

  Goal? _resolveGoal({required String hint, required List<Goal> goals}) {
    final activeGoals = goals.where((goal) => !goal.isArchived).toList();
    final normalizedHint = CurrencyCatalog.normalizeText(hint);
    final matched = activeGoals
        .where((goal) {
          final title = CurrencyCatalog.normalizeText(goal.title);
          return normalizedHint == title || normalizedHint.contains(title);
        })
        .toList(growable: false);
    if (matched.length == 1) {
      return matched.single;
    }
    return matched.isEmpty && activeGoals.length == 1
        ? activeGoals.single
        : null;
  }

  DateTime? _goalTargetDate(String? dateText, String originalInput) {
    final value = dateText?.trim();
    if (value != null) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    final text = [dateText, originalInput].nonNulls.join(' ');
    final match = RegExp(
      r'(\d+)\s*(?:months?|شهر|اشهر|شهور)',
      caseSensitive: false,
    ).firstMatch(CurrencyCatalog.normalizeText(text));
    final months = int.tryParse(match?.group(1) ?? '');
    if (months == null || months <= 0) {
      return null;
    }
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month + months, now.day, 23, 59, 59);
  }

  GoalType _goalType(String value) {
    final normalized = CurrencyCatalog.normalizeText(value);
    if (normalized.contains('emergency') || normalized.contains('طوار')) {
      return GoalType.emergencyFund;
    }
    if (normalized.contains('debt') || normalized.contains('دين')) {
      return GoalType.debtPayoff;
    }
    if (normalized.contains('purchase') || normalized.contains('شراء')) {
      return GoalType.purchase;
    }
    if (normalized.contains('custom') || normalized.contains('مخصص')) {
      return GoalType.custom;
    }
    return GoalType.savings;
  }

  String _goalIcon(GoalType type) => switch (type) {
    GoalType.savings => 'savings',
    GoalType.emergencyFund => 'shield',
    GoalType.debtPayoff => 'receipt',
    GoalType.purchase => 'shopping_bag',
    GoalType.custom => 'flag',
  };

  int _goalColor(GoalType type) => switch (type) {
    GoalType.savings => 0xFF17A673,
    GoalType.emergencyFund => 0xFFE0A21A,
    GoalType.debtPayoff => 0xFFD75455,
    GoalType.purchase => 0xFF197E8C,
    GoalType.custom => 0xFF6D5BD0,
  };

  BudgetPeriodType _budgetPeriodType(String value) {
    final normalized = CurrencyCatalog.normalizeText(value);
    if (normalized.contains('week') || normalized.contains('اسبوع')) {
      return BudgetPeriodType.weekly;
    }
    if (normalized.contains('year') || normalized.contains('سن')) {
      return BudgetPeriodType.yearly;
    }
    if (normalized.contains('custom') || normalized.contains('مخصص')) {
      return BudgetPeriodType.custom;
    }
    return BudgetPeriodType.monthly;
  }

  ({DateTime start, DateTime end}) _budgetPeriod(
    BudgetPeriodType type,
    DateTime now,
  ) {
    return switch (type) {
      BudgetPeriodType.weekly => (
        start: DateTime.utc(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - DateTime.monday)),
        end: DateTime.utc(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - DateTime.monday))
            .add(const Duration(days: 7)),
      ),
      BudgetPeriodType.monthly => (
        start: DateTime.utc(now.year, now.month),
        end: DateTime.utc(now.year, now.month + 1),
      ),
      BudgetPeriodType.yearly => (
        start: DateTime.utc(now.year),
        end: DateTime.utc(now.year + 1),
      ),
      BudgetPeriodType.custom => throw StateError('Custom period unresolved.'),
    };
  }

  Account? _resolveAccount({
    required String hint,
    required List<Account> accounts,
    bool allowSingleFallback = true,
  }) {
    if (accounts.isEmpty) {
      return null;
    }

    final normalizedHint = PaymentMethodDefinition.normalize(hint);
    final paymentMethodDefinition = LibyanPaymentMethodCatalog.matchAlias(hint);
    if (paymentMethodDefinition != null) {
      final configured = accounts
          .where(
            (account) =>
                account.paymentMethodIds.contains(paymentMethodDefinition.id),
          )
          .toList(growable: false);
      if (configured.length == 1) {
        return configured.single;
      }
    }

    if (normalizedHint.isNotEmpty) {
      final matched = accounts
          .where((account) {
            final normalizedName = PaymentMethodDefinition.normalize(
              account.name,
            );
            return normalizedName.contains(normalizedHint) ||
                normalizedHint.contains(normalizedName);
          })
          .toList(growable: false);
      if (matched.length == 1) {
        return matched.single;
      }
    }

    if (allowSingleFallback && accounts.length == 1) {
      return accounts.single;
    }

    return null;
  }

  Decimal? _amount(String? value) {
    if (value == null) {
      return null;
    }

    return Decimal.tryParse(value.replaceAll(',', '.'));
  }

  DateTime? _transactionDate(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final normalized = CurrencyCatalog.normalizeText(text);
    final now = DateTime.now();
    if (normalized == 'today' || normalized == 'اليوم' || normalized == 'توا') {
      return DateTime(now.year, now.month, now.day).toUtc();
    }
    final parsed = DateTime.tryParse(text);
    return parsed?.toUtc();
  }

  DateTime? _transactionDateMentionedIn(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    if (normalized.contains('today') ||
        normalized.contains('ط§ظ„ظٹظˆظ…') ||
        normalized.contains('طھظˆط§')) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).toUtc();
    }
    final isoDate = RegExp(
      r'\b\d{4}-\d{2}-\d{2}\b',
    ).firstMatch(input)?.group(0);
    return isoDate == null ? null : DateTime.tryParse(isoDate)?.toUtc();
  }

  PaymentMethod? _singleLinkedPaymentMethod(Account account) {
    if (account.paymentMethodIds.length != 1) {
      return null;
    }

    return LibyanPaymentMethodCatalog.findById(
      account.paymentMethodIds.first,
    )?.transactionPaymentMethod;
  }

  PaymentMethod? _cashPaymentMethod(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    return _cashAliases.any((alias) => normalized.contains(alias))
        ? PaymentMethod.cash
        : null;
  }

  bool _questionLike(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    return input.contains('?') ||
        normalized.contains('analyze') ||
        normalized.contains('explain') ||
        normalized.contains('review') ||
        normalized.contains('find') ||
        normalized.contains('what') ||
        normalized.contains('why') ||
        normalized.contains('how');
  }
}

const _cashAliases = <String>['cash', 'كاش', 'نقدي', 'نقدا'];
