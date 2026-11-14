import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../payees/domain/enums/payee_type.dart';
import '../entities/income_source_classification_rule.dart';
import '../entities/income_source_suggestion.dart';
import '../enums/income_source_type.dart';

class IncomeSourceResolver {
  const IncomeSourceResolver();

  IncomeSourceSuggestion resolve({
    required String input,
    required List<Category> categories,
    List<Account> accounts = const <Account>[],
    Payee? sourcePayee,
    List<IncomeSourceClassificationRule> userRules =
        const <IncomeSourceClassificationRule>[],
    IncomeSourceType? explicitSourceType,
    String? explicitCategoryId,
    String? explicitDestinationAccountId,
    String? destinationAccountHint,
    String? sourceNameHint,
    IncomeSourceType? aiSourceType,
    int? aiConfidence,
    String clarificationQuestion =
        'What kind of income is this, and which account received it?',
  }) {
    final normalized = _normalize(input);
    final internalTransfer = _looksLikeInternalTransfer(normalized);
    if (internalTransfer) {
      return IncomeSourceSuggestion(
        sourceType: IncomeSourceType.externalTransfer,
        destinationAccountId: explicitDestinationAccountId,
        destinationAccountHint: destinationAccountHint,
        confidence: 100,
        source: IncomeSourceSuggestionSource.explicitUserInput,
        requiresClarification: true,
        clarificationQuestion:
            'This looks like a transfer between your own accounts, not income.',
        isInternalTransfer: true,
      );
    }

    final trustedRule = _trustedRule(normalized, userRules);
    final phraseMatch = _exactPhrase(normalized);
    final localMatch = _localPhrase(normalized);
    final payeeType = _typeForPayee(sourcePayee);
    final IncomeSourceType resolvedType;
    final IncomeSourceSuggestionSource source;
    final int confidence;

    if (explicitSourceType != null) {
      resolvedType = explicitSourceType;
      source = IncomeSourceSuggestionSource.explicitUserInput;
      confidence = 100;
    } else if (trustedRule != null) {
      resolvedType = trustedRule.sourceType;
      source = IncomeSourceSuggestionSource.trustedLocalRule;
      confidence = trustedRule.isExplicit ? 100 : 95;
    } else if (payeeType != null) {
      resolvedType = payeeType;
      source = IncomeSourceSuggestionSource.payeeDefault;
      confidence = 90;
    } else if (phraseMatch != null) {
      resolvedType = phraseMatch.type;
      source = IncomeSourceSuggestionSource.exactPhrase;
      confidence = phraseMatch.confidence;
    } else if (aiSourceType != null && (aiConfidence ?? 0) >= 75) {
      resolvedType = aiSourceType;
      source = IncomeSourceSuggestionSource.aiSemantic;
      confidence = (aiConfidence ?? 75).clamp(0, 100);
    } else if (localMatch != null) {
      resolvedType = localMatch.type;
      source = IncomeSourceSuggestionSource.localParser;
      confidence = localMatch.confidence;
    } else {
      resolvedType = aiSourceType ?? IncomeSourceType.other;
      source = IncomeSourceSuggestionSource.fallback;
      confidence = aiConfidence?.clamp(0, 54) ?? 0;
    }

    final categoryId =
        explicitCategoryId ??
        trustedRule?.categoryId ??
        _categoryIdFor(resolvedType, categories);
    final destinationId =
        explicitDestinationAccountId ??
        trustedRule?.destinationAccountId ??
        sourcePayee?.defaultAccountId ??
        _accountIdForHint(destinationAccountHint, accounts);
    final uncertainExternal =
        resolvedType == IncomeSourceType.externalTransfer ||
        resolvedType == IncomeSourceType.other;
    final requiresClarification =
        uncertainExternal ||
        (destinationAccountHint?.trim().isNotEmpty == true &&
            destinationId == null);

    return IncomeSourceSuggestion(
      sourceType: resolvedType,
      sourceNameHint: sourceNameHint ?? sourcePayee?.name,
      sourcePayeeId: sourcePayee?.id,
      categoryId: categoryId,
      categoryHint: _categoryNameFor(resolvedType),
      destinationAccountId: destinationId,
      destinationAccountHint: destinationAccountHint,
      confidence: confidence,
      source: source,
      alternatives: uncertainExternal
          ? const <IncomeSourceType>[
              IncomeSourceType.gift,
              IncomeSourceType.debtRepayment,
              IncomeSourceType.loanProceeds,
              IncomeSourceType.reimbursement,
              IncomeSourceType.externalTransfer,
              IncomeSourceType.other,
            ]
          : const <IncomeSourceType>[],
      requiresClarification: requiresClarification,
      clarificationQuestion: requiresClarification
          ? clarificationQuestion
          : null,
    );
  }

  IncomeSourceClassificationRule? _trustedRule(
    String input,
    List<IncomeSourceClassificationRule> rules,
  ) {
    final matches =
        rules
            .where(
              (rule) =>
                  rule.isTrusted &&
                  _containsPhrase(input, rule.normalizedPhrase),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => right.normalizedPhrase.length.compareTo(
              left.normalizedPhrase.length,
            ),
          );
    return matches.firstOrNull;
  }

  _IncomePhraseMatch? _exactPhrase(String input) {
    final matches = <_IncomePhraseMatch>[];
    for (final entry in _incomePhrases.entries) {
      for (final phrase in entry.value) {
        if (_containsPhrase(input, phrase)) {
          matches.add(
            _IncomePhraseMatch(type: entry.key, phrase: phrase, confidence: 96),
          );
        }
      }
    }
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((a, b) => b.phrase.length.compareTo(a.phrase.length));
    return matches.first;
  }

  _IncomePhraseMatch? _localPhrase(String input) {
    for (final entry in _localIncomePhrases.entries) {
      for (final phrase in entry.value) {
        if (input.contains(_normalize(phrase))) {
          return _IncomePhraseMatch(
            type: entry.key,
            phrase: phrase,
            confidence: 65,
          );
        }
      }
    }
    return null;
  }

  IncomeSourceType? _typeForPayee(Payee? payee) {
    return switch (payee?.type) {
      PayeeType.employer => IncomeSourceType.salary,
      PayeeType.government => IncomeSourceType.governmentSupport,
      PayeeType.school => IncomeSourceType.scholarship,
      _ => null,
    };
  }

  String? _categoryIdFor(IncomeSourceType type, List<Category> categories) {
    final name = _categoryNameFor(type);
    final normalizedName = _normalize(name);
    return categories
        .where(
          (category) =>
              !category.isArchived &&
              category.type == CategoryType.income &&
              _normalize(category.name) == normalizedName,
        )
        .firstOrNull
        ?.id;
  }

  String _categoryNameFor(IncomeSourceType type) {
    return switch (type) {
      IncomeSourceType.salary => 'Salary',
      IncomeSourceType.freelance => 'Freelance',
      IncomeSourceType.businessRevenue => 'Business Revenue',
      IncomeSourceType.gift => 'Gift',
      IncomeSourceType.allowance => 'Allowance',
      IncomeSourceType.refund => 'Refund',
      IncomeSourceType.sale => 'Sale Proceeds',
      IncomeSourceType.rentalIncome => 'Rental Income',
      IncomeSourceType.governmentSupport => 'Government Support',
      IncomeSourceType.scholarship => 'Scholarship',
      IncomeSourceType.investmentReturn => 'Investment',
      IncomeSourceType.reimbursement => 'Reimbursement',
      IncomeSourceType.debtRepayment => 'Debt Repayment',
      IncomeSourceType.prize => 'Prize',
      IncomeSourceType.loanProceeds => 'Loan Proceeds',
      IncomeSourceType.externalTransfer => 'Other Income',
      IncomeSourceType.other => 'Other Income',
    };
  }

  String? _accountIdForHint(String? hint, List<Account> accounts) {
    final normalizedHint = _normalize(hint ?? '');
    if (normalizedHint.isEmpty) {
      return null;
    }
    final matches = accounts
        .where((account) {
          if (account.isArchived) {
            return false;
          }
          final name = _normalize(account.name);
          return name == normalizedHint ||
              _containsPhrase(normalizedHint, name) ||
              _containsPhrase(name, normalizedHint);
        })
        .toList(growable: false);
    return matches.length == 1 ? matches.single.id : null;
  }

  bool _looksLikeInternalTransfer(String input) {
    final hasTransfer = _internalTransferTokens.any(
      (token) => _containsPhrase(input, token),
    );
    final hasFrom = _containsAny(input, const <String>['من', 'from']);
    final hasTo = _containsAny(input, const <String>[
      'الى',
      'إلى',
      'للمصرف',
      'to',
    ]);
    return hasTransfer && hasFrom && hasTo;
  }

  bool _containsAny(String input, List<String> values) {
    return values.any((value) => _containsPhrase(input, value));
  }

  bool _containsPhrase(String input, String phrase) {
    final normalizedPhrase = _normalize(phrase);
    return ' $input '.contains(' $normalizedPhrase ');
  }

  String _normalize(String value) {
    return CurrencyCatalog.normalizeText(value)
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _IncomePhraseMatch {
  const _IncomePhraseMatch({
    required this.type,
    required this.phrase,
    required this.confidence,
  });

  final IncomeSourceType type;
  final String phrase;
  final int confidence;
}

const _incomePhrases = <IncomeSourceType, List<String>>{
  IncomeSourceType.salary: <String>[
    'وصلني مرتب',
    'وصلني راتب',
    'المرتب نزل',
    'الراتب نزل',
    'المرتب اليوم نزل',
    'الراتب اليوم نزل',
    'نزل المرتب',
    'نزل الراتب',
    'مرتب',
    'راتب',
    'salary',
    'paycheck',
    'wage',
    'أجرة',
    'اجرة',
    'معاش',
  ],
  IncomeSourceType.freelance: <String>[
    'شغل حر',
    'خديت مقابل شغل',
    'فريلانس',
    'freelance',
  ],
  IncomeSourceType.businessRevenue: <String>[
    'دخل مشروع',
    'ايراد مشروع',
    'إيراد مشروع',
    'مبيعات',
    'business income',
    'business revenue',
  ],
  IncomeSourceType.gift: <String>[
    'هدية',
    'هديه',
    'gift',
    'birthday gift',
    'for my birthday',
    'my birthday',
    'عيد ميلادي',
    'عيد ميلاد',
  ],
  IncomeSourceType.allowance: <String>['مصروف', 'allowance'],
  IncomeSourceType.refund: <String>[
    'رجعولي فلوسي',
    'رجعولي',
    'استرداد',
    'refund',
  ],
  IncomeSourceType.sale: <String>[
    'بعت الحاجة',
    'بعت التلفون',
    'بعت',
    'sold',
    'sale proceeds',
  ],
  IncomeSourceType.rentalIncome: <String>[
    'دخللي إيجار',
    'دخللي ايجار',
    'إيجار',
    'ايجار',
    'rental income',
    'rent received',
  ],
  IncomeSourceType.governmentSupport: <String>[
    'نزلت المنحة',
    'منحة',
    'منحه',
    'دعم',
    'government support',
    'grant',
  ],
  IncomeSourceType.scholarship: <String>['منحة دراسية', 'scholarship'],
  IncomeSourceType.investmentReturn: <String>[
    'عائد استثمار',
    'investment return',
    'dividend',
  ],
  IncomeSourceType.reimbursement: <String>['تعويض مصروف', 'reimbursement'],
  IncomeSourceType.debtRepayment: <String>[
    'سداد دين',
    'سداد الدين',
    'رجعلي ديني',
    'ردلي ديني',
    'debt repayment',
    'repaid a debt',
    'repaid the debt',
    'paid back the debt',
  ],
  IncomeSourceType.prize: <String>[
    'جائزة',
    'جائزه',
    'بجائزة',
    'بجائزه',
    'prize',
  ],
  IncomeSourceType.loanProceeds: <String>[
    'وصلني قرض',
    'وصل القرض',
    'قرض',
    'loan proceeds',
    'loan',
  ],
  IncomeSourceType.externalTransfer: <String>[
    'حوالة واردة',
    'حواله وارده',
    'external transfer',
  ],
};

const _localIncomePhrases = <IncomeSourceType, List<String>>{
  IncomeSourceType.externalTransfer: <String>[
    'دخلولي فلوس',
    'وصلتني فلوس',
    'money came in',
  ],
  IncomeSourceType.freelance: <String>['مقابل شغل', 'for work'],
};

const _internalTransferTokens = <String>[
  'حولت',
  'حول',
  'تحويل',
  'نقلت',
  'transfer',
  'moved',
];
