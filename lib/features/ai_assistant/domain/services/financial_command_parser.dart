import 'package:decimal/decimal.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as time_zone;

import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/domain/enums/account_type.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_classification_rule.dart';
import '../../../categories/domain/services/category_suggestion_resolver.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../income_sources/domain/entities/income_source_suggestion.dart';
import '../../../income_sources/domain/services/income_source_resolver.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../payees/domain/entities/payee_resolution.dart';
import '../../../payees/domain/services/payee_name_normalizer.dart';
import '../../../payees/domain/services/payee_resolver.dart';
import '../../../payment_methods/payment_methods.dart'
    show
        LibyanBankCatalog,
        LibyanBankDefinition,
        LibyanPaymentMethodCatalog,
        PaymentMethod,
        PaymentMethodDefinition;
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/ai_transaction_draft.dart';

class FinancialCommandParser {
  const FinancialCommandParser({
    PayeeResolver resolver = const PayeeResolver(),
    CategorySuggestionResolver categoryResolver =
        const CategorySuggestionResolver(),
    IncomeSourceResolver incomeSourceResolver = const IncomeSourceResolver(),
    DateTime Function()? clock,
    this.timeZoneName = 'Africa/Tripoli',
  }) : _resolver = resolver,
       _categoryResolver = categoryResolver,
       _incomeSourceResolver = incomeSourceResolver,
       _clock = clock;

  final PayeeResolver _resolver;
  final CategorySuggestionResolver _categoryResolver;
  final IncomeSourceResolver _incomeSourceResolver;
  final DateTime Function()? _clock;
  final String timeZoneName;

  AiTransactionParseResult parse({
    required String input,
    required List<Account> accounts,
    required List<Category> categories,
    required String baseCurrencyCode,
    required String paymentMethodClarificationMessage,
    String? expenseAccountClarificationMessage,
    List<Payee> payees = const <Payee>[],
    List<CategoryClassificationRule> categoryRules =
        const <CategoryClassificationRule>[],
    String ambiguousPayeeMessage = 'Which payee did you mean?',
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const AiTransactionParseFailure(message: 'Message is empty.');
    }

    if (_isUnsupportedTransfer(trimmed)) {
      return const AiTransactionParseFailure(
        message: 'Transfers need to be reviewed in the transfer workspace.',
      );
    }

    final amount = _extractAmount(trimmed);
    if (amount == null || amount <= Decimal.zero) {
      return const AiTransactionParseFailure(
        message: 'I could not find a valid amount.',
      );
    }

    final paymentMethodDefinition = LibyanPaymentMethodCatalog.matchAlias(
      trimmed,
    );
    final bankDefinition = LibyanBankCatalog.matchAlias(trimmed);
    final type = _resolveType(trimmed);
    // Receiving money never implies a destination account. Even when the
    // user has only one account, keep the destination unresolved unless the
    // message identifies it explicitly (including an explicit cash/payment
    // method alias).
    final needsDestinationSelection = type == TransactionType.income;
    final payeeResolution = _resolver.resolveFromText(trimmed, payees);
    if (payeeResolution is PayeeAmbiguous) {
      return AiTransactionClarification(message: ambiguousPayeeMessage);
    }
    final payee = payeeResolution is PayeeResolved
        ? payeeResolution.payee
        : null;
    final defaultAccount = payee?.defaultAccountId == null
        ? null
        : accounts
              .where((account) => account.id == payee!.defaultAccountId)
              .firstOrNull;
    final accountResult = _resolveAccount(
      input: trimmed,
      accounts: accounts,
      paymentMethodDefinition: paymentMethodDefinition,
      bankDefinition: bankDefinition,
      expenseAccountClarificationMessage:
          expenseAccountClarificationMessage ??
          paymentMethodClarificationMessage,
      defaultAccount: defaultAccount,
      allowUnresolvedSelection: needsDestinationSelection,
    );

    if (!needsDestinationSelection) {
      if (accountResult.clarificationMessage case final message?) {
        return AiTransactionClarification(message: message);
      }
    }

    final account =
        accountResult.account ??
        (needsDestinationSelection
            ? _unresolvedDestinationAccount(baseCurrencyCode)
            : null);
    if (account == null) {
      return const AiTransactionParseFailure(
        message: 'Create or link an account before using AI transaction entry.',
      );
    }

    final currencyCode = CurrencyCatalog.resolveCurrencyCode(
      trimmed,
      defaultCurrencyCode: account.currencyCode,
    );
    final IncomeSourceSuggestion? incomeSuggestion;
    if (type == TransactionType.income) {
      incomeSuggestion = _incomeSourceResolver.resolve(
        input: trimmed,
        categories: categories,
        accounts: accounts,
        sourcePayee: payee,
        sourceNameHint: payee?.name ?? _incomeSourceNameHint(trimmed),
        explicitDestinationAccountId:
            account.id == AiTransactionDraft.unresolvedAccountId
            ? null
            : account.id,
        destinationAccountHint:
            account.id == AiTransactionDraft.unresolvedAccountId
            ? null
            : account.name,
      );
      if (incomeSuggestion.isInternalTransfer) {
        return AiTransactionClarification(
          message:
              incomeSuggestion.clarificationQuestion ??
              'Please clarify the income source.',
        );
      }
    } else {
      incomeSuggestion = null;
    }
    final categorySuggestion = _categoryResolver.resolve(
      input: trimmed,
      categories: categories,
      payeeDefaultCategoryId: payee?.defaultCategoryId,
      aiCategoryHint: incomeSuggestion?.requiresClarification == true
          ? null
          : incomeSuggestion?.categoryHint,
      aiConfidence: incomeSuggestion?.requiresClarification == true
          ? null
          : incomeSuggestion?.confidence,
      userRules: categoryRules,
      categoryType: type == TransactionType.income
          ? CategoryType.income
          : CategoryType.expense,
    );
    // A source classification is not consent to a ledger category. Income
    // intake keeps category unresolved until the user selects it in preview.
    final category = type == TransactionType.income
        ? null
        : _categoryById(categories, categorySuggestion.categoryId);
    final paymentMethod =
        paymentMethodDefinition?.transactionPaymentMethod ??
        _cashPaymentMethod(trimmed) ??
        _singleLinkedPaymentMethod(account) ??
        PaymentMethod.other;

    return AiTransactionDraft(
      type: type,
      amount: Money(amount: amount, currencyCode: currencyCode),
      account: account,
      category: category,
      paymentMethod: paymentMethod,
      paymentMethodDefinition: paymentMethodDefinition,
      note: trimmed,
      payee: payee,
      payeeHint: payee?.name,
      itemDescription: _normalizedItemDescription(
        categorySuggestion.matchedPhrase,
      ),
      categorySuggestion: categorySuggestion,
      incomeSourceSuggestion: incomeSuggestion,
      transactionDate:
          _relativeDate(trimmed) ??
          (type == TransactionType.expense ? _todayUtc() : null),
      status: _transactionStatus(trimmed),
    );
  }

  _AccountResolution _resolveAccount({
    required String input,
    required List<Account> accounts,
    required PaymentMethodDefinition? paymentMethodDefinition,
    required LibyanBankDefinition? bankDefinition,
    required String expenseAccountClarificationMessage,
    Account? defaultAccount,
    bool allowUnresolvedSelection = false,
  }) {
    final activeAccounts = accounts
        .where((account) => !account.isArchived)
        .toList(growable: false);
    if (activeAccounts.isEmpty) {
      return _AccountResolution(
        clarificationMessage: expenseAccountClarificationMessage,
      );
    }

    final normalizedAccountInput = PayeeNameNormalizer.normalize(input);
    final named = activeAccounts
        .where(
          (account) => normalizedAccountInput.contains(
            PayeeNameNormalizer.normalize(account.name),
          ),
        )
        .toList(growable: false);
    if (named.length == 1) {
      return _AccountResolution(account: named.single);
    }
    if (named.length > 1) {
      return _AccountResolution(
        clarificationMessage: expenseAccountClarificationMessage,
      );
    }

    if (bankDefinition != null) {
      final bankMatched = activeAccounts
          .where((account) => bankDefinition.matchesText(account.name))
          .toList(growable: false);
      if (bankMatched.length == 1) {
        return _AccountResolution(account: bankMatched.single);
      }
      if (bankMatched.length > 1) {
        return _AccountResolution(
          clarificationMessage: expenseAccountClarificationMessage,
        );
      }
    }

    if (_cashPaymentMethod(input) == PaymentMethod.cash) {
      final cashAccounts = activeAccounts
          .where((account) => account.type == AccountType.cash)
          .toList(growable: false);
      if (cashAccounts.length == 1) {
        return _AccountResolution(account: cashAccounts.single);
      }
      if (cashAccounts.length > 1) {
        return _AccountResolution(
          clarificationMessage: expenseAccountClarificationMessage,
        );
      }
    }

    if (paymentMethodDefinition == null) {
      if (allowUnresolvedSelection) {
        return const _AccountResolution();
      }
      if (defaultAccount != null && !defaultAccount.isArchived) {
        return _AccountResolution(account: defaultAccount);
      }
      if (activeAccounts.length == 1) {
        return _AccountResolution(account: activeAccounts.first);
      }

      return _AccountResolution(
        clarificationMessage: expenseAccountClarificationMessage,
      );
    }

    final configured = activeAccounts
        .where(
          (account) =>
              account.paymentMethodIds.contains(paymentMethodDefinition.id),
        )
        .toList(growable: false);

    if (configured.length == 1) {
      return _AccountResolution(account: configured.first);
    }

    if (configured.length > 1) {
      return _AccountResolution(
        clarificationMessage: expenseAccountClarificationMessage,
      );
    }

    if (defaultAccount != null && !defaultAccount.isArchived) {
      return _AccountResolution(account: defaultAccount);
    }

    final normalizedPaymentInput = PaymentMethodDefinition.normalize(input);
    final bankMatched = activeAccounts
        .where(
          (account) =>
              paymentMethodDefinition.matchesBank(normalizedPaymentInput) &&
              normalizedPaymentInput.contains(
                PaymentMethodDefinition.normalize(account.name),
              ),
        )
        .toList(growable: false);

    if (bankMatched.length == 1) {
      return _AccountResolution(account: bankMatched.first);
    }

    if (activeAccounts.length == 1 && !allowUnresolvedSelection) {
      return _AccountResolution(account: activeAccounts.first);
    }

    if (allowUnresolvedSelection) {
      return const _AccountResolution();
    }
    return _AccountResolution(
      clarificationMessage: expenseAccountClarificationMessage,
    );
  }

  Account _unresolvedDestinationAccount(String baseCurrencyCode) {
    return Account.create(
      id: AiTransactionDraft.unresolvedAccountId,
      name: '',
      type: AccountType.cash,
      currencyCode: baseCurrencyCode,
      balance: Decimal.zero,
      icon: 'wallet',
      color: 0,
      isArchived: true,
    );
  }

  TransactionType _resolveType(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    final incomeTokens = [
      'راتب',
      'مرتب',
      'دخل',
      'ايراد',
      'استلمت',
      'استلم',
      'قبضت',
      'نزلولي',
      'نزل المرتب',
      'جاني',
      'دخلولي',
      'حولولي',
      'وصلني',
      'جاتني',
      'salary',
      'income',
      'paid me',
      'received',
      'sent me',
      'gave me',
      'مرتب',
      'معاش',
      'اجره',
      'اجرة',
      'شغل حر',
      'فريلانس',
      'مبيعات',
      'هديه',
      'هدية',
      'منحه',
      'منحة',
      'دعم',
      'ايجار',
      'إيجار',
      'استرداد',
      'رجعولي',
      'تعويض',
      'بعت',
      'جائزه',
      'جائزة',
      'قرض',
      'paycheck',
      'freelance',
      'business income',
      'gift',
      'allowance',
      'scholarship',
      'grant',
      'refund',
      'reimbursement',
      'rent received',
      'sold',
      'prize',
      'loan',
      'عطاني',
      'عطتني',
      'عطوني',
    ];
    if (incomeTokens.any(normalized.contains)) {
      return TransactionType.income;
    }

    return TransactionType.expense;
  }

  String? _incomeSourceNameHint(String input) {
    final normalized = input.trim();
    final english = RegExp(
      r'\b((?:my\s+)?[a-z][a-z .\-]{0,48}?)\s+(?:sent|gave|paid)\s+me\b',
      caseSensitive: false,
    ).firstMatch(normalized)?.group(1)?.trim();
    if (english != null && english.isNotEmpty) {
      return english;
    }

    final arabic = RegExp(
      r'(?:^|\s)([\u0600-\u06FF][\u0600-\u06FF\s]{0,32}?)\s+(?:عطاني|عطتني|عطوني|حوللي|حوّللي)(?:\s|$)',
    ).firstMatch(normalized)?.group(1)?.trim();
    return arabic == null || arabic.isEmpty ? null : arabic;
  }

  bool _isUnsupportedTransfer(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    const transferTokens = [
      'حول',
      'حواله',
      'تحويل',
      'نقلت',
      'انقل',
      'دزيت',
      'بعثت',
      'عطيت',
      'سحبت',
      'transfer',
    ];

    return transferTokens.any(normalized.contains);
  }

  Category? _categoryById(List<Category> categories, String? id) {
    if (id == null) {
      return null;
    }
    return categories.where((category) => category.id == id).firstOrNull;
  }

  Decimal? _extractAmount(String input) {
    final normalizedDigits = _normalizeDigits(
      input,
    ).replaceAll('−', '-').replaceAll('–', '-').replaceAll('—', '-');
    if (_scientificNotationPattern.hasMatch(normalizedDigits)) {
      return null;
    }

    final numericAmounts = <String>[];
    for (final match in _numericTokenPattern.allMatches(normalizedDigits)) {
      final canonical = _canonicalDecimalToken(match.group(0)!);
      if (canonical == null) {
        return null;
      }
      numericAmounts.add(canonical);
    }

    final wordAmounts = _extractArabicWordAmounts(normalizedDigits);
    if (wordAmounts == null ||
        numericAmounts.length + wordAmounts.length != 1) {
      return null;
    }

    if (numericAmounts case [final amount]) {
      return Decimal.tryParse(amount);
    }
    if (wordAmounts case [final amount]) {
      return amount;
    }
    return null;
  }

  DateTime? _relativeDate(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    if (normalized.contains('today') ||
        normalized.contains('اليوم') ||
        normalized.contains('توا')) {
      return _configuredDayUtc();
    }
    if (normalized.contains('yesterday') ||
        normalized.contains('امبارح') ||
        normalized.contains('مبارح') ||
        normalized.contains('البارح')) {
      return _configuredDayUtc(dayOffset: -1);
    }
    return null;
  }

  DateTime _todayUtc() {
    return _configuredDayUtc();
  }

  DateTime _configuredDayUtc({int dayOffset = 0}) {
    _ensureTimeZonesInitialized();
    final configured = timeZoneName.trim().isEmpty
        ? 'Africa/Tripoli'
        : timeZoneName.trim();
    time_zone.Location location;
    try {
      location = time_zone.getLocation(
        _timeZoneAliases[configured] ?? configured,
      );
    } on Object {
      location = time_zone.getLocation('Africa/Tripoli');
    }
    final nowUtc = (_clock?.call() ?? DateTime.now()).toUtc();
    final localNow = time_zone.TZDateTime.from(nowUtc, location);
    return time_zone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day + dayOffset,
    ).toUtc();
  }

  String? _normalizedItemDescription(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (!RegExp(r'^[a-z]').hasMatch(normalized)) return normalized;
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  TransactionStatus _transactionStatus(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    return <String>[
          'pending',
          'not cleared',
          'قيد الانتظار',
          'معلق',
          'معلّق',
          'مازال ما وصلش',
        ].any(normalized.contains)
        ? TransactionStatus.pending
        : TransactionStatus.posted;
  }

  PaymentMethod? _cashPaymentMethod(String input) {
    final normalized = CurrencyCatalog.normalizeText(input);
    return _cashAliases.any((alias) => normalized.contains(alias))
        ? PaymentMethod.cash
        : null;
  }

  PaymentMethod? _singleLinkedPaymentMethod(Account account) {
    if (account.paymentMethodIds.length != 1) {
      return null;
    }

    return LibyanPaymentMethodCatalog.findById(
      account.paymentMethodIds.first,
    )?.transactionPaymentMethod;
  }
}

class _AccountResolution {
  const _AccountResolution({this.account, this.clarificationMessage});

  final Account? account;
  final String? clarificationMessage;
}

String _normalizeDigits(String value) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var result = value;

  for (var index = 0; index < 10; index++) {
    result = result
        .replaceAll(eastern[index], '$index')
        .replaceAll(persian[index], '$index');
  }

  return result;
}

String? _canonicalDecimalToken(String token) {
  var unsigned = token;
  var sign = '';
  if (unsigned.startsWith('+') || unsigned.startsWith('-')) {
    sign = unsigned.startsWith('-') ? '-' : '';
    unsigned = unsigned.substring(1);
  }

  if (unsigned.isEmpty) {
    return null;
  }

  final containsArabicSeparator =
      unsigned.contains('٫') || unsigned.contains('٬');
  final containsAsciiSeparator =
      unsigned.contains('.') || unsigned.contains(',');
  if (containsArabicSeparator && containsAsciiSeparator) {
    return null;
  }

  final String canonical;
  if (unsigned.contains('٬')) {
    if (!_arabicGroupedNumberPattern.hasMatch(unsigned)) {
      return null;
    }
    canonical = unsigned.replaceAll('٬', '').replaceAll('٫', '.');
  } else if (unsigned.contains('٫')) {
    if (!_arabicDecimalPattern.hasMatch(unsigned)) {
      return null;
    }
    canonical = unsigned.replaceAll('٫', '.');
  } else if (unsigned.contains(',') && unsigned.contains('.')) {
    if (!_asciiGroupedDecimalPattern.hasMatch(unsigned)) {
      return null;
    }
    canonical = unsigned.replaceAll(',', '');
  } else if (unsigned.contains(',')) {
    final commaCount = ','.allMatches(unsigned).length;
    if (commaCount > 1) {
      if (!_asciiGroupedIntegerPattern.hasMatch(unsigned)) {
        return null;
      }
      canonical = unsigned.replaceAll(',', '');
    } else {
      final parts = unsigned.split(',');
      if (parts.length != 2 || parts.any((part) => part.isEmpty)) {
        return null;
      }
      final isThousandsGrouping =
          parts.first.length <= 3 && parts.last.length == 3;
      canonical = isThousandsGrouping
          ? '${parts.first}${parts.last}'
          : '${parts.first}.${parts.last}';
    }
  } else if (unsigned.contains('.')) {
    if (!_asciiDecimalPattern.hasMatch(unsigned)) {
      return null;
    }
    canonical = unsigned;
  } else {
    if (!_integerPattern.hasMatch(unsigned)) {
      return null;
    }
    canonical = unsigned;
  }

  final signed = '$sign$canonical';
  final decimalIndex = canonical.indexOf('.');
  if (decimalIndex >= 0 && canonical.length - decimalIndex - 1 > 3) {
    return null;
  }
  return Decimal.tryParse(signed) == null ? null : signed;
}

List<Decimal>? _extractArabicWordAmounts(String input) {
  final normalized = CurrencyCatalog.normalizeText(input)
      .replaceAll('بدينارين', 'اثنين دينار')
      .replaceAll('دينارين', 'اثنين دينار')
      .replaceAll(RegExp(r'دينار\s+و?(?:نص|نصف)'), 'واحد ونص');
  final tokens = normalized
      .split(RegExp(r'[^ء-ي]+'))
      .where((token) => token.isNotEmpty);
  final amounts = <Decimal>[];
  final parts = <_ArabicNumberPart>[];

  bool flushParts() {
    if (parts.isEmpty) {
      return true;
    }
    final amount = _composeArabicNumber(parts);
    parts.clear();
    if (amount == null) {
      return false;
    }
    amounts.add(Decimal.fromInt(amount));
    return true;
  }

  for (final token in tokens) {
    final part = _arabicNumberPartFor(token);
    if (part != null) {
      parts.add(part);
      continue;
    }
    final fraction = _arabicFractionFor(token);
    if (fraction != null) {
      final whole = parts.isEmpty ? 0 : _composeArabicNumber(parts);
      parts.clear();
      if (whole == null) {
        return null;
      }
      amounts.add(Decimal.fromInt(whole) + fraction);
      continue;
    }
    if (token == 'و' && parts.isNotEmpty) {
      continue;
    }
    if (!flushParts()) {
      return null;
    }
  }

  return flushParts() ? amounts : null;
}

Decimal? _arabicFractionFor(String token) {
  var normalized = token;
  if (normalized.startsWith('و') && normalized.length > 1) {
    normalized = normalized.substring(1);
  }
  if (normalized.startsWith('ب') && normalized.length > 1) {
    normalized = normalized.substring(1);
  }
  return switch (normalized) {
    'نص' || 'نصف' => Decimal.parse('0.5'),
    'ربع' => Decimal.parse('0.25'),
    _ => null,
  };
}

_ArabicNumberPart? _arabicNumberPartFor(String token) {
  final direct = _arabicNumberWords[token];
  if (direct != null) {
    return direct;
  }

  var withoutPrefix = token;
  if (withoutPrefix.startsWith('و') && withoutPrefix.length > 1) {
    withoutPrefix = withoutPrefix.substring(1);
  }
  if (withoutPrefix.startsWith('ب') && withoutPrefix.length > 1) {
    withoutPrefix = withoutPrefix.substring(1);
  }
  return _arabicNumberWords[withoutPrefix];
}

int? _composeArabicNumber(List<_ArabicNumberPart> parts) {
  var index = 0;
  var amount = 0;
  if (parts.first.kind == _ArabicNumberKind.hundreds) {
    amount += parts.first.value;
    index++;
  }

  final remaining = parts.length - index;
  if (remaining == 0) {
    return amount;
  }
  if (parts
      .skip(index)
      .any((part) => part.kind == _ArabicNumberKind.hundreds)) {
    return null;
  }
  if (remaining == 1) {
    return amount + parts[index].value;
  }
  if (remaining == 2 &&
      parts[index].kind == _ArabicNumberKind.units &&
      parts[index + 1].kind == _ArabicNumberKind.tens &&
      parts[index + 1].value >= 20) {
    return amount + parts[index].value + parts[index + 1].value;
  }
  return null;
}

enum _ArabicNumberKind { units, tens, hundreds }

class _ArabicNumberPart {
  const _ArabicNumberPart(this.value, this.kind);

  final int value;
  final _ArabicNumberKind kind;
}

final _scientificNotationPattern = RegExp(r'\d(?:[.,٫٬]\d+)*[eE][+\-]?\d');
final _numericTokenPattern = RegExp(r'[+\-]?\d+(?:[.,٫٬]\d+)*');
final _integerPattern = RegExp(r'^\d+$');
final _asciiDecimalPattern = RegExp(r'^\d+\.\d+$');
final _asciiGroupedIntegerPattern = RegExp(r'^\d{1,3}(?:,\d{3})+$');
final _asciiGroupedDecimalPattern = RegExp(r'^\d{1,3}(?:,\d{3})+\.\d+$');
final _arabicDecimalPattern = RegExp(r'^\d+٫\d+$');
final _arabicGroupedNumberPattern = RegExp(r'^\d{1,3}(?:٬\d{3})+(?:٫\d+)?$');

const _cashAliases = <String>['cash', 'كاش', 'نقدي', 'نقدا'];

bool _timeZonesInitialized = false;

void _ensureTimeZonesInitialized() {
  if (_timeZonesInitialized) return;
  time_zone_data.initializeTimeZones();
  _timeZonesInitialized = true;
}

const _timeZoneAliases = <String, String>{
  'Libya Standard Time': 'Africa/Tripoli',
  'EET': 'Africa/Tripoli',
};

const _arabicNumberWords = <String, _ArabicNumberPart>{
  'واحد': _ArabicNumberPart(1, _ArabicNumberKind.units),
  'وحده': _ArabicNumberPart(1, _ArabicNumberKind.units),
  'اثنين': _ArabicNumberPart(2, _ArabicNumberKind.units),
  'اثنان': _ArabicNumberPart(2, _ArabicNumberKind.units),
  'اتنين': _ArabicNumberPart(2, _ArabicNumberKind.units),
  'ثلاثه': _ArabicNumberPart(3, _ArabicNumberKind.units),
  'ثلاث': _ArabicNumberPart(3, _ArabicNumberKind.units),
  'اربعه': _ArabicNumberPart(4, _ArabicNumberKind.units),
  'اربع': _ArabicNumberPart(4, _ArabicNumberKind.units),
  'خمسه': _ArabicNumberPart(5, _ArabicNumberKind.units),
  'خمس': _ArabicNumberPart(5, _ArabicNumberKind.units),
  'سته': _ArabicNumberPart(6, _ArabicNumberKind.units),
  'ست': _ArabicNumberPart(6, _ArabicNumberKind.units),
  'سبعه': _ArabicNumberPart(7, _ArabicNumberKind.units),
  'سبع': _ArabicNumberPart(7, _ArabicNumberKind.units),
  'ثمانيه': _ArabicNumberPart(8, _ArabicNumberKind.units),
  'ثماني': _ArabicNumberPart(8, _ArabicNumberKind.units),
  'ثمان': _ArabicNumberPart(8, _ArabicNumberKind.units),
  'تسعه': _ArabicNumberPart(9, _ArabicNumberKind.units),
  'تسع': _ArabicNumberPart(9, _ArabicNumberKind.units),
  'عشره': _ArabicNumberPart(10, _ArabicNumberKind.tens),
  'عشر': _ArabicNumberPart(10, _ArabicNumberKind.tens),
  'عشرين': _ArabicNumberPart(20, _ArabicNumberKind.tens),
  'ثلاثين': _ArabicNumberPart(30, _ArabicNumberKind.tens),
  'اربعين': _ArabicNumberPart(40, _ArabicNumberKind.tens),
  'خمسين': _ArabicNumberPart(50, _ArabicNumberKind.tens),
  'ستين': _ArabicNumberPart(60, _ArabicNumberKind.tens),
  'سبعين': _ArabicNumberPart(70, _ArabicNumberKind.tens),
  'ثمانين': _ArabicNumberPart(80, _ArabicNumberKind.tens),
  'تسعين': _ArabicNumberPart(90, _ArabicNumberKind.tens),
  'ميه': _ArabicNumberPart(100, _ArabicNumberKind.hundreds),
  'مايه': _ArabicNumberPart(100, _ArabicNumberKind.hundreds),
  'ميتين': _ArabicNumberPart(200, _ArabicNumberKind.hundreds),
  'مايتين': _ArabicNumberPart(200, _ArabicNumberKind.hundreds),
};
