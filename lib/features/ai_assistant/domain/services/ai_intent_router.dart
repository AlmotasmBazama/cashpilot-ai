import '../../../../shared/domain/currency/currency_catalog.dart';
import '../agent/assistant_navigation_policy.dart';
import '../entities/ai_financial_record_offer.dart';
import '../entities/ai_intent.dart';
import 'ai_action_safety_policy.dart';

export '../entities/ai_financial_record_offer.dart';

enum AssistantRouteTarget {
  directConversation,
  generalConversation,
  groundedCurrentKnowledge,
  personalFinancialAnalysis,
  financialRecordOffer,
  financialAction,
  receiptAction,
  appNavigation,
  blocked,
}

class AiIntentRoute {
  const AiIntentRoute({
    required this.intent,
    required this.isDeterministic,
    required this.useFinancialPipeline,
    required this.target,
    this.blockedIntent,
    this.navigationToolId,
    this.isExplicitMutationRequest = false,
    this.useLocalFinancialParser = false,
    this.recordOfferDecision = FinancialRecordOfferDecision.none,
  });

  final AiIntent intent;
  final bool isDeterministic;
  final bool useFinancialPipeline;
  final AssistantRouteTarget target;
  final AiIntent? blockedIntent;
  final String? navigationToolId;
  final bool isExplicitMutationRequest;
  final bool useLocalFinancialParser;
  final FinancialRecordOfferDecision recordOfferDecision;

  bool get isFinancialAction => target == AssistantRouteTarget.financialAction;

  bool get isFinancialRecordOffer =>
      target == AssistantRouteTarget.financialRecordOffer &&
      recordOfferDecision == FinancialRecordOfferDecision.none;

  bool get isFinancialRecordOfferResponse =>
      target == AssistantRouteTarget.financialRecordOffer &&
      recordOfferDecision != FinancialRecordOfferDecision.none;
}

class AiIntentRouter {
  const AiIntentRouter({
    AiActionSafetyPolicy safetyPolicy = const AiActionSafetyPolicy(),
    AssistantNavigationPolicy navigationPolicy =
        const AssistantNavigationPolicy(),
  }) : _safetyPolicy = safetyPolicy,
       _navigationPolicy = navigationPolicy;

  final AiActionSafetyPolicy _safetyPolicy;
  final AssistantNavigationPolicy _navigationPolicy;

  AiIntentRoute route(
    String input, {
    bool awaitingFinancialClarification = false,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const AiIntentRoute(
        intent: AiIntent.unknown,
        isDeterministic: true,
        useFinancialPipeline: false,
        target: AssistantRouteTarget.generalConversation,
      );
    }

    if (awaitingFinancialClarification && _isOrdinalSelection(trimmed)) {
      return _financialAction(AiIntent.clarificationResponse);
    }

    final blockedIntent = _safetyPolicy.destructiveIntentFor(trimmed);
    if (blockedIntent != null && blockedIntent != AiIntent.deleteTransaction) {
      return AiIntentRoute(
        intent: blockedIntent,
        blockedIntent: blockedIntent,
        isDeterministic: true,
        useFinancialPipeline: false,
        target: AssistantRouteTarget.blocked,
      );
    }

    final normalized = _normalize(trimmed);
    final transactionMutation = _transactionMutationIntent(normalized);
    if (transactionMutation != null) {
      return _financialAction(transactionMutation);
    }
    if (blockedIntent == AiIntent.deleteTransaction) {
      return _financialAction(AiIntent.deleteTransaction);
    }
    final navigation = _navigationPolicy.classify(trimmed);
    if (navigation != null) {
      return AiIntentRoute(
        intent: AiIntent.unknown,
        isDeterministic: true,
        useFinancialPipeline: false,
        target: AssistantRouteTarget.appNavigation,
        navigationToolId: navigation.toolName,
      );
    }
    if (_matchesDirectConversationPhrase(normalized, _greetings)) {
      return _local(AiIntent.greeting);
    }
    if (_containsAny(normalized, _capabilityPhrases)) {
      return _local(AiIntent.supportedCapabilities);
    }
    if (_containsAny(normalized, _helpPhrases)) {
      return _local(AiIntent.help);
    }
    if (_matchesDirectConversationPhrase(normalized, _smallTalkPhrases)) {
      return _local(AiIntent.smallTalk);
    }
    if (_containsAny(normalized, _receiptPhrases)) {
      return const AiIntentRoute(
        intent: AiIntent.unknown,
        isDeterministic: true,
        useFinancialPipeline: false,
        target: AssistantRouteTarget.receiptAction,
      );
    }
    if (_containsAny(normalized, _personalFollowUpPhrases)) {
      return _personalAnalysis(AiIntent.askFinancialQuestion);
    }
    if (_looksLikeCurrencyConversion(normalized)) {
      return _personalAnalysis(AiIntent.currencyConversionQuestion);
    }
    if (_looksLikeAccountBalanceQuestion(normalized)) {
      return _personalAnalysis(AiIntent.askFinancialQuestion);
    }
    if (_looksLikeFinancialQuestion(normalized)) {
      return _personalAnalysis(AiIntent.askFinancialQuestion);
    }
    if (_looksLikeGeneralFinancialEducation(normalized)) {
      return const AiIntentRoute(
        intent: AiIntent.unknown,
        isDeterministic: false,
        useFinancialPipeline: false,
        target: AssistantRouteTarget.generalConversation,
      );
    }

    final explicitMutationIntent = _explicitMutationIntent(normalized);
    if (explicitMutationIntent != null) {
      return _financialAction(explicitMutationIntent);
    }
    if (_containsAny(normalized, _transferPhrases)) {
      return _financialAction(AiIntent.createTransfer);
    }
    if (_containsAny(normalized, _budgetPhrases)) {
      return _financialAction(AiIntent.createBudget);
    }
    if (_containsAny(normalized, _goalContributionPhrases)) {
      return _financialAction(AiIntent.addGoalContribution);
    }
    if (_containsAny(normalized, _goalPhrases)) {
      return _financialAction(AiIntent.createGoal);
    }

    final declarativeIntent = _declarativeFinancialIntent(normalized);
    if (declarativeIntent != null) {
      // Clear income/expense proposals already express the user's recording
      // intent. Send them straight to the governed draft preview; confirmation
      // still remains mandatory before any durable write.
      return declarativeIntent == AiIntent.unknown
          ? _financialRecordOffer(declarativeIntent)
          : _financialAction(
              declarativeIntent,
              explicitMutationRequest: false,
              useLocalFinancialParser:
                  declarativeIntent == AiIntent.createIncome ||
                  _looksLikeDirectExpenseProposal(normalized),
            );
    }
    if (_looksCurrent(normalized)) {
      return const AiIntentRoute(
        intent: AiIntent.unknown,
        isDeterministic: false,
        useFinancialPipeline: false,
        target: AssistantRouteTarget.groundedCurrentKnowledge,
      );
    }

    final recordOfferDecision = _recordOfferDecision(normalized);
    if (recordOfferDecision != FinancialRecordOfferDecision.none) {
      return _financialRecordOfferResponse(recordOfferDecision);
    }

    return const AiIntentRoute(
      intent: AiIntent.unknown,
      isDeterministic: false,
      useFinancialPipeline: false,
      target: AssistantRouteTarget.generalConversation,
    );
  }

  AiIntentRoute _local(AiIntent intent) {
    return AiIntentRoute(
      intent: intent,
      isDeterministic: true,
      useFinancialPipeline: false,
      target: AssistantRouteTarget.directConversation,
    );
  }

  bool _isOrdinalSelection(String input) =>
      RegExp(r'^[1-3١-٣۱-۳]$').hasMatch(input.trim());

  AiIntentRoute _financialAction(
    AiIntent intent, {
    bool deterministic = true,
    bool explicitMutationRequest = true,
    bool useLocalFinancialParser = false,
  }) {
    return AiIntentRoute(
      intent: intent,
      isDeterministic: deterministic,
      useFinancialPipeline: true,
      target: AssistantRouteTarget.financialAction,
      isExplicitMutationRequest: explicitMutationRequest,
      useLocalFinancialParser: useLocalFinancialParser,
    );
  }

  AiIntentRoute _financialRecordOffer(AiIntent proposedIntent) {
    return AiIntentRoute(
      intent: proposedIntent,
      isDeterministic: true,
      useFinancialPipeline: false,
      target: AssistantRouteTarget.financialRecordOffer,
    );
  }

  AiIntentRoute _financialRecordOfferResponse(
    FinancialRecordOfferDecision decision,
  ) {
    return AiIntentRoute(
      intent: AiIntent.clarificationResponse,
      isDeterministic: true,
      useFinancialPipeline: false,
      target: AssistantRouteTarget.financialRecordOffer,
      recordOfferDecision: decision,
    );
  }

  AiIntentRoute _personalAnalysis(AiIntent intent) {
    return AiIntentRoute(
      intent: intent,
      isDeterministic: false,
      useFinancialPipeline: true,
      target: AssistantRouteTarget.personalFinancialAnalysis,
    );
  }

  String _normalize(String input) {
    return CurrencyCatalog.normalizeText(input)
        .replaceAll(RegExp(r"['\u2018\u2019\u02BC\uFF07]"), '')
        .replaceAll(RegExp(r'[\u060C\u061B\u061F\u06D4]'), ' ')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesDirectConversationPhrase(String input, List<String> phrases) {
    return phrases.any((phrase) => input == _normalize(phrase));
  }

  bool _containsAny(String input, List<String> phrases) {
    return phrases.any((phrase) => input.contains(_normalize(phrase)));
  }

  bool _containsWholePhrase(String input, List<String> phrases) {
    final paddedInput = ' $input ';
    return phrases.any((phrase) {
      final normalizedPhrase = _normalize(phrase);
      return normalizedPhrase.isNotEmpty &&
          paddedInput.contains(' $normalizedPhrase ');
    });
  }

  bool _looksLikeCurrencyConversion(String input) {
    final currencyMentions = CurrencyCatalog.supported
        .where(
          (currency) => <String>[
            currency.code,
            ...currency.aliases,
          ].any((alias) => input.contains(_normalize(alias))),
        )
        .length;
    return currencyMentions >= 2 &&
        _containsAny(input, const <String>[
          'كم تساوي',
          'حول',
          'بالدينار',
          'in',
          'convert',
          'exchange',
        ]);
  }

  bool _looksLikeFinancialQuestion(String input) {
    final asks =
        _containsAny(input, _questionPhrases) ||
        input.endsWith('?') ||
        input.endsWith('؟');
    return asks &&
        _containsAny(input, _financialTopics) &&
        _containsWholePhrase(input, _personalFinancialSignals);
  }

  bool _looksLikeAccountBalanceQuestion(String input) {
    final asks =
        _containsAny(input, _questionPhrases) ||
        input.endsWith('?') ||
        input.endsWith('؟');
    if (!asks) return false;
    return _containsAny(input, const <String>[
      'شن رصيد حساب',
      'كم رصيد حساب',
      'رصيد حسابي',
      'my account balance',
      'balance of my account',
      "what's my balance",
      'what is my balance',
    ]);
  }

  bool _looksLikeGeneralFinancialEducation(String input) {
    return _containsAny(input, _financialEducationPhrases) &&
        _containsAny(input, _financialTopics) &&
        !_containsWholePhrase(input, _personalFinancialSignals) &&
        !_containsMoneySignal(input);
  }

  bool _looksCurrent(String input) {
    return _containsAny(input, _currentSignals) &&
        (_containsAny(input, _publicCurrentTopics) ||
            _containsAny(input, const <String>[
              'شن صاير',
              'what is happening',
              'latest',
              'news',
            ]));
  }

  bool _containsMoneySignal(String input) {
    return _containsAmountSignal(input) &&
        (_containsAny(input, _currencyPhrases) ||
            _containsAny(input, _paymentPhrases));
  }

  AiIntent? _explicitMutationIntent(String input) {
    if (_containsAny(input, _negatedMutationPhrases) ||
        (!_containsWholePhrase(input, _mutationVerbs) &&
            !_containsAny(input, _attachedMutationVerbs))) {
      return null;
    }

    if (_containsAny(input, _budgetPhrases)) {
      return AiIntent.createBudget;
    }
    if (_containsAny(input, _goalContributionPhrases)) {
      return AiIntent.addGoalContribution;
    }
    if (_containsAny(input, _goalPhrases)) {
      return AiIntent.createGoal;
    }
    if (_containsAny(input, _transferPhrases)) {
      return AiIntent.createTransfer;
    }
    if (_looksLikeIncomeStatement(input) ||
        _containsWholePhrase(input, _explicitIncomeTopics)) {
      return AiIntent.createIncome;
    }
    if (_looksLikeExpenseStatement(input) ||
        _containsWholePhrase(input, _explicitExpenseTopics) ||
        _containsMoneySignal(input)) {
      return AiIntent.createExpense;
    }
    return null;
  }

  AiIntent? _transactionMutationIntent(String input) {
    final undo =
        input == 'undo' ||
        _containsAny(input, const <String>[
          'تراجع',
          'الغ اخر تعديل',
          'الغي اخر تعديل',
          'رجع العمليه اللي حذفتها',
          'undo the last change',
          'undo the last transaction change',
          'restore the transaction i deleted',
        ]);
    if (undo) return AiIntent.undoAction;
    final mentionsTransaction = _containsAny(input, const <String>[
      'عمليه',
      'معامله',
      'مصروف',
      'دخل',
      'مرتب',
      'راتب',
      'تحويل',
      'transaction',
      'expense',
      'income',
      'salary',
      'transfer',
    ]);
    if (!mentionsTransaction) return null;
    if (_containsAny(input, const <String>[
      'احذف',
      'امسح',
      'الغي',
      'الغ ',
      'delete',
      'remove',
      'cancel the',
    ])) {
      return AiIntent.deleteTransaction;
    }
    if (_containsAny(input, const <String>[
      'عدل',
      'غير',
      'بدل',
      'خلي',
      'رجع اخر عمليه منشوره',
      'edit',
      'change',
      'move the',
    ])) {
      return AiIntent.updateTransaction;
    }
    return null;
  }

  AiIntent? _declarativeFinancialIntent(String input) {
    if (_containsAny(input, _negatedMutationPhrases)) {
      return null;
    }
    if (_looksLikeIncomeStatement(input)) {
      return AiIntent.createIncome;
    }
    if (_looksLikeExpenseStatement(input)) {
      return AiIntent.createExpense;
    }
    if (_looksLikeDirectExpenseProposal(input)) {
      return AiIntent.createExpense;
    }
    if (_containsMoneySignal(input)) {
      // A bare amount and currency is still not an expense request. Keep the
      // direction unresolved until the user chooses to record and clarifies it.
      return AiIntent.unknown;
    }
    return null;
  }

  bool _looksLikeIncomeStatement(String input) {
    final hasIncomeLanguage =
        _containsAny(input, _incomePhrases) ||
        _containsWholePhrase(input, _declarativeIncomePhrases);
    return hasIncomeLanguage &&
        (_containsAmountSignal(input) ||
            _containsAny(input, _currencyPhrases) ||
            _containsAny(input, _incomePhrases));
  }

  bool _looksLikeExpenseStatement(String input) {
    final hasExpenseLanguage = _containsAny(input, _expensePhrases);
    return hasExpenseLanguage &&
        (_containsAmountSignal(input) ||
            _containsAny(input, _currencyPhrases) ||
            _containsAny(input, _expensePhrases));
  }

  bool _looksLikeDirectExpenseProposal(String input) {
    return _containsAmountSignal(input) &&
        _containsWholePhrase(input, _directExpenseItemPhrases);
  }

  bool _containsAmountSignal(String input) {
    return RegExp(r'\d').hasMatch(input) ||
        _containsWholePhrase(input, _arabicAmountWords);
  }

  FinancialRecordOfferDecision recordOfferDecisionFor(String input) {
    return _recordOfferDecision(_normalize(input.trim()));
  }

  bool isAffirmativeRecordOfferResponse(String input) =>
      recordOfferDecisionFor(input) == FinancialRecordOfferDecision.accept;

  bool isNegativeRecordOfferResponse(String input) =>
      recordOfferDecisionFor(input) == FinancialRecordOfferDecision.decline;

  FinancialRecordOfferDecision _recordOfferDecision(String normalized) {
    if (normalized.isEmpty || normalized.split(' ').length > 10) {
      return FinancialRecordOfferDecision.none;
    }
    if (_containsAny(normalized, _negatedMutationPhrases)) {
      return FinancialRecordOfferDecision.decline;
    }
    if (_matchesDecisionPhrase(
      normalized,
      _negativeRecordOfferResponses,
      allowSingleWordPrefix: false,
    )) {
      return FinancialRecordOfferDecision.decline;
    }
    if (_matchesDecisionPhrase(
      normalized,
      _positiveRecordOfferResponses,
      allowSingleWordPrefix: true,
    )) {
      return FinancialRecordOfferDecision.accept;
    }
    return FinancialRecordOfferDecision.none;
  }

  bool _matchesDecisionPhrase(
    String input,
    List<String> phrases, {
    required bool allowSingleWordPrefix,
  }) {
    return phrases.any((phrase) {
      final normalizedPhrase = _normalize(phrase);
      if (input == normalizedPhrase) {
        return true;
      }
      final isSingleWord = !normalizedPhrase.contains(' ');
      return (!isSingleWord || allowSingleWordPrefix) &&
          input.startsWith('$normalizedPhrase ');
    });
  }
}

const _greetings = <String>[
  'مرحبا',
  'اهلا',
  'اهلين',
  'السلام عليكم',
  'سلام',
  'صباح الخير',
  'مساء الخير',
  'hello',
  'hi',
  'hey',
  'good morning',
  'good evening',
];

const _smallTalkPhrases = <String>[
  'كيف حالك',
  'شن حالك',
  'كيفك',
  'شلونك',
  'شخبارك',
  'شني أخبارك',
  'how are you',
  'how are u',
  'how r u',
  "how're you",
  'what’s up',
  'whats up',
  'sup',
  'u good',
];

const _capabilityPhrases = <String>[
  'شن تقدر تدير',
  'ماذا تستطيع',
  'شن خدماتك',
  'what can you do',
  'capabilities',
];

const _helpPhrases = <String>[
  'ساعدني',
  'مساعده',
  'كيف نستخدم التطبيق',
  'كيف استخدم التطبيق',
  'help me',
  'how does this work',
];

const _expensePhrases = <String>[
  'اشتريت',
  'شريت',
  'خديت',
  'دفعت',
  'خلصت',
  'صرفت',
  'expense',
  'spent',
  'paid',
  'bought',
];

// Bounded, high-confidence item/category terms used only when a valid amount
// and currency/payment signal are also present. Arbitrary names plus money
// remain direction-ambiguous and never default to an expense.
const _directExpenseItemPhrases = <String>[
  'milk',
  'coffee',
  'fuel',
  'petrol',
  'gasoline',
  'groceries',
  'bread',
  'transport',
  'transportation',
  'taxi',
  'حليب',
  'قهوة',
  'قهوه',
  'وقود',
  'بنزين',
  'خبز',
  'مواد غذائية',
  'مواصلات',
  'تاكسي',
];

const _incomePhrases = <String>[
  'وصلني راتب',
  'وصلني مرتب',
  'وصلتني هدية',
  'حصلت هدية',
  'جتني هدية',
  'هدية',
  'جاتني',
  'استلمت',
  'قبضت',
  'دخل',
  'income',
  'salary',
  'paid me',
];

const _declarativeIncomePhrases = <String>[
  'received',
  'received money',
  'money came in',
  'sent me',
  'send me',
  'send to me',
  'gave me',
  'got paid',
  'وصلني',
  'وصلتني',
  'عطاني',
  'اعطاني',
  'أعطاني',
  'جاتني',
  'جتني',
  'دخللي',
  'دخلولي',
];

const _mutationVerbs = <String>[
  'record',
  'log',
  'add',
  'save',
  'enter',
  'create',
  'سجل',
  'سجّل',
  'اضف',
  'أضف',
  'ضيف',
  'قيد',
  'قيّد',
  'دون',
  'دوّن',
  'احفظ',
  'إحفظ',
];

const _attachedMutationVerbs = <String>[
  'سجلها',
  'سجّلها',
  'سجله',
  'سجّلها',
  'سجللي',
  'ضيفها',
  'ضيفلي',
  'اضفها',
  'أضفها',
  'قيدها',
  'قيّدها',
  'دونها',
  'دوّنها',
];

const _negatedMutationPhrases = <String>[
  'do not record',
  "don't record",
  'dont record',
  'never record',
  'do not add',
  "don't add",
  'dont add',
  'لا تسجل',
  'لا تسجلها',
  'ما تسجل',
  'ما تسجلها',
  'ماتسجل',
  'ماتسجلها',
];

const _explicitIncomeTopics = <String>[
  'income',
  'earning',
  'earnings',
  'deposit',
  'دخل',
  'الدخل',
  'ايراد',
  'إيراد',
  'راتب',
  'مرتب',
  'هدية',
];

const _explicitExpenseTopics = <String>[
  'expense',
  'purchase',
  'payment',
  'spending',
  'مصروف',
  'المصروف',
  'نفقة',
  'دفعة',
  'شراء',
];

const _transferPhrases = <String>['حولت', 'حول', 'تحويل', 'نقلت', 'transfer'];

const _budgetPhrases = <String>[
  'حطلي ميزانيه',
  'حطلي ميزانية',
  'انشئ ميزانيه',
  'انشئ ميزانية',
  'ديرلي ميزانيه',
  'ديرلي ميزانية',
  'create budget',
  'set budget',
];

const _goalContributionPhrases = <String>[
  'ضيف للهدف',
  'ساهمت في الهدف',
  'goal contribution',
  'add to goal',
];

const _goalPhrases = <String>[
  'انشئ هدف',
  'هدف ادخار',
  'create goal',
  'savings goal',
];

const _questionPhrases = <String>[
  'كم',
  'شن',
  'ليش',
  'لماذا',
  'ما هو',
  'ماذا',
  'كيف',
  'what',
  'why',
  'which',
  'how much',
  'show',
  'analyze',
  'analyse',
  'compare',
  'forecast',
];

const _financialTopics = <String>[
  'صرفت',
  'مصروف',
  'مصروفي',
  'انفاق',
  'ميزاني',
  'هدف',
  'باقي',
  'دخل',
  'راتب',
  'تقرير',
  'spend',
  'spent',
  'expense',
  'budget',
  'goal',
  'income',
  'cash flow',
  'saving',
  'savings',
  'financial',
];

const _financialEducationPhrases = <String>[
  'explain',
  'difference between',
  'what is',
  'how does',
  'how do',
  '\u0627\u0634\u0631\u062d',
  '\u0627\u0644\u0641\u0631\u0642 \u0628\u064a\u0646',
  '\u0634\u0646 \u0627\u0644\u0641\u0631\u0642',
  '\u0645\u0627 \u0647\u0648',
  '\u0645\u0627 \u0647\u064a',
];

/// Signals that a financial question is about the signed-in user's own data.
/// A topic alone (for example, "What is cash flow?") is general education and
/// must not authorize private financial tool reads.
const _personalFinancialSignals = <String>[
  'my',
  'mine',
  'i',
  'our',
  'show me',
  'this month',
  'last month',
  'previous month',
  'my account',
  'my transaction',
  'my report',
  '\u0645\u0635\u0631\u0648\u0641\u064a',
  '\u0645\u064a\u0632\u0627\u0646\u064a\u062a\u064a',
  '\u062d\u0633\u0627\u0628\u064a',
  '\u062f\u062e\u0644\u064a',
  '\u0631\u0627\u062a\u0628\u064a',
  '\u0627\u062f\u062e\u0627\u0631\u064a',
  '\u0647\u062f\u0641\u064a',
  '\u0635\u0631\u0641\u062a',
  '\u0639\u0646\u062f\u064a',
  '\u0644\u0644\u0647\u062f\u0641',
  '\u0647\u0630\u0627 \u0627\u0644\u0634\u0647\u0631',
  '\u0627\u0644\u0634\u0647\u0631 \u0627\u0644\u0645\u0627\u0636\u064a',
];

const _currencyPhrases = <String>[
  'دينار',
  'دنانير',
  'د ل',
  'dinar',
  'dinars',
  'lyd',
  'usd',
  'دولار',
  'يورو',
];

const _paymentPhrases = <String>[
  'كاش',
  'نقدي',
  'ادفع لي',
  'ادفعلي',
  'edfaly',
  'مصرفي',
  'موبي',
  'يسر',
  'cash',
  'paid',
];

const _positiveRecordOfferResponses = <String>[
  'yes',
  'yes please',
  'yeah',
  'yep',
  'sure',
  'ok',
  'okay',
  'confirm',
  'do it',
  'record it',
  'please record it',
  'نعم',
  'اي',
  'إي',
  'ايه',
  'إيه',
  'ايوه',
  'أيوه',
  'تمام',
  'موافق',
  'سجلها',
  'سجّلها',
  'سجلها لو سمحت',
];

const _negativeRecordOfferResponses = <String>[
  'no',
  'no thanks',
  'no thank you',
  'nope',
  'cancel',
  'do not record it',
  "don't record it",
  'dont record it',
  'not now',
  'لا',
  'لا شكرا',
  'لا شكرًا',
  'لا تسجلها',
  'ما تسجلها',
  'ماتسجلها',
  'ماتسجلهاش',
  'مش توا',
  'مش توه',
  'الغي',
  'إلغاء',
];

const _arabicAmountWords = <String>[
  'دينارين',
  'بدينارين',
  'صفر',
  'واحد',
  'وحدة',
  'اثنين',
  'اثنان',
  'اتنين',
  'ثلاثة',
  'ثلاث',
  'اربعة',
  'أربعة',
  'خمس',
  'خمسة',
  'ست',
  'ستة',
  'سبع',
  'سبعة',
  'ثمان',
  'ثمانية',
  'تسع',
  'تسعة',
  'عشر',
  'عشرة',
  'عشرين',
  'ثلاثين',
  'اربعين',
  'أربعين',
  'خمسين',
  'ستين',
  'سبعين',
  'ثمانين',
  'تسعين',
  'مية',
  'مئة',
  'مائة',
  'ميتين',
  'مئتين',
  'الف',
  'ألف',
  'ألفين',
  'الفين',
];

const _receiptPhrases = <String>[
  'امسح الايصال',
  'امسح الإيصال',
  'صور الايصال',
  'صور الإيصال',
  'scan receipt',
  'receipt photo',
];

const _personalFollowUpPhrases = <String>[
  'والشهر اللي فات',
  'الشهر اللي فات',
  'والشهر الماضي',
  'الشهر الماضي',
  'what about last month',
  'and last month',
  'previous month',
  'compare that',
  'compare with last month',
];

const _currentSignals = <String>[
  'حاليا',
  'حالياً',
  'اليوم',
  'اخر',
  'آخر',
  'احدث',
  'أحدث',
  'هذه السنه',
  'هذه السنة',
  'السنه هذي',
  'السنة هذي',
  'latest',
  'currently',
  'current',
  'today',
  'this year',
  'news',
];

const _publicCurrentTopics = <String>[
  'اقتصاد',
  'التضخم',
  'تضخم',
  'سعر الصرف',
  'اسعار النفط',
  'أسعار النفط',
  'نفط',
  'لوائح',
  'قانون',
  'تقنيه',
  'تقنية',
  'رئيس',
  'وزير',
  'جدول',
  'موعد',
  'سعر',
  'econom',
  'inflation',
  'exchange rate',
  'oil',
  'regulation',
  'technology',
  'president',
  'minister',
  'price',
  'schedule',
];
