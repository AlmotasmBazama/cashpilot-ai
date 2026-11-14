import 'package:decimal/decimal.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../../../../shared/domain/currency/currency_catalog.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../payment_methods/payment_methods.dart'
    show LibyanPaymentMethodCatalog, PaymentMethod;
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../entities/ai_intent.dart';

class AiTransactionTargetQuery {
  const AiTransactionTargetQuery({
    this.type,
    this.previousAmount,
    this.accountId,
    this.categoryId,
    this.payeeId,
    this.status,
    this.day,
    this.latest = false,
    this.transferRequested = false,
    this.subjectHints = const <String>[],
  });

  final TransactionType? type;
  final Decimal? previousAmount;
  final String? accountId;
  final String? categoryId;
  final String? payeeId;
  final TransactionStatus? status;
  final DateTime? day;
  final bool latest;
  final bool transferRequested;
  final List<String> subjectHints;
}

class AiTransactionRequestedChanges {
  const AiTransactionRequestedChanges({
    this.amount,
    this.accountId,
    this.categoryId,
    this.payeeId,
    this.paymentMethod,
    this.status,
    this.transactionDate,
    this.note,
    this.location,
    this.incomeSourceType,
  });

  final Decimal? amount;
  final String? accountId;
  final String? categoryId;
  final String? payeeId;
  final PaymentMethod? paymentMethod;
  final TransactionStatus? status;
  final DateTime? transactionDate;
  final String? note;
  final String? location;
  final IncomeSourceType? incomeSourceType;

  bool get isEmpty =>
      amount == null &&
      accountId == null &&
      categoryId == null &&
      payeeId == null &&
      paymentMethod == null &&
      status == null &&
      transactionDate == null &&
      note == null &&
      location == null &&
      incomeSourceType == null;
}

class AiParsedTransactionMutation {
  const AiParsedTransactionMutation({
    required this.intent,
    required this.query,
    required this.changes,
    required this.usesArabic,
    this.undoTransferCancellationRequested = false,
  });

  final AiIntent intent;
  final AiTransactionTargetQuery query;
  final AiTransactionRequestedChanges changes;
  final bool usesArabic;
  final bool undoTransferCancellationRequested;
}

/// Deterministic parser for the locally executable transaction-mutation
/// surface. It never consumes provider output and never accepts entity IDs.
class AiTransactionMutationParser {
  const AiTransactionMutationParser();

  AiParsedTransactionMutation? parse({
    required String input,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Payee> payees,
    DateTime? nowUtc,
    String timeZoneName = 'Africa/Tripoli',
  }) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) return null;
    final usesArabic = RegExp(r'[\u0600-\u06ff]').hasMatch(input);
    final intent = _intent(normalized);
    if (intent == null) return null;
    if (intent == AiIntent.undoAction) {
      return AiParsedTransactionMutation(
        intent: intent,
        query: const AiTransactionTargetQuery(),
        changes: const AiTransactionRequestedChanges(),
        usesArabic: usesArabic,
        undoTransferCancellationRequested:
            normalized.contains('تحويل') &&
            _containsAny(normalized, const <String>['الغاء', 'الغي']),
      );
    }

    final amounts = _amounts(input);
    final amountChange = _amountChange(input, amounts);
    final accountMatches = _entityMatches<Account>(
      normalized,
      accounts,
      (item) => item.name,
    );
    final categoryMatches = _entityMatches<Category>(
      normalized,
      categories,
      (item) => item.name,
    );
    final payeeMatches = _payeeMatches(normalized, payees);
    final statuses = _statuses(normalized);
    final relativeDay = _relativeDay(
      normalized,
      (nowUtc ?? DateTime.now().toUtc()).toUtc(),
      timeZoneName,
    );
    final isUpdate = intent == AiIntent.updateTransaction;
    final accountPair = _oldAndNewEntity(
      normalized,
      accountMatches.map((item) => item.id).toList(growable: false),
      isUpdate: isUpdate,
    );
    final categoryPair = _oldAndNewEntity(
      normalized,
      categoryMatches.map((item) => item.id).toList(growable: false),
      isUpdate: isUpdate,
    );
    final payeePair = _oldAndNewEntity(
      normalized,
      payeeMatches.map((item) => item.id).toList(growable: false),
      isUpdate: isUpdate,
    );
    final statusPair = _oldAndNewStatus(statuses, isUpdate: isUpdate);
    final changesDate =
        isUpdate &&
        (normalized.contains('غير التاريخ') ||
            normalized.contains('عدل التاريخ') ||
            normalized.contains('change date'));
    final changes = isUpdate
        ? AiTransactionRequestedChanges(
            amount: amountChange.$2,
            accountId: accountPair.$2,
            categoryId: categoryPair.$2,
            payeeId: payeePair.$2,
            paymentMethod: _newPaymentMethod(normalized),
            status: statusPair.$2,
            transactionDate: changesDate ? relativeDay : null,
            note: _changedText(normalized, input, const <String>[
              'note',
              'ملاحظه',
              'الملاحظه',
            ]),
            location: _changedText(normalized, input, const <String>[
              'location',
              'موقع',
              'الموقع',
              'مكان',
            ]),
            incomeSourceType: _newIncomeSourceType(normalized),
          )
        : const AiTransactionRequestedChanges();

    return AiParsedTransactionMutation(
      intent: intent,
      query: AiTransactionTargetQuery(
        type: _transactionType(normalized),
        previousAmount: isUpdate && amounts.length > 1
            ? amountChange.$1
            : !isUpdate && amounts.isNotEmpty
            ? amounts.first
            : null,
        accountId: accountPair.$1,
        categoryId: categoryPair.$1,
        payeeId: payeePair.$1,
        status: statusPair.$1,
        day: changesDate ? null : relativeDay,
        latest: _containsAny(normalized, const <String>[
          'اخر',
          'الاخيره',
          'الاخير',
          'last',
          'latest',
          'previous',
        ]),
        transferRequested: _containsAny(normalized, const <String>[
          'تحويل',
          'transfer',
        ]),
        subjectHints: _subjectHints(
          normalized,
          ignoredEntityLabels: <String>[
            for (final item in accountMatches) item.name,
            for (final item in categoryMatches) item.name,
            for (final item in payeeMatches) item.name,
          ],
        ),
      ),
      changes: changes,
      usesArabic: usesArabic,
    );
  }

  AiIntent? _intent(String input) {
    if (_isUndo(input)) return AiIntent.undoAction;
    if (_containsAny(input, const <String>[
      'احذف',
      'امسح',
      'الغ العمليه',
      'الغي العمليه',
      'الغ التحويل',
      'الغي التحويل',
      'الغ اخر تحويل',
      'الغي اخر تحويل',
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

  bool _isUndo(String input) {
    final trimmed = input.trim();
    return _containsAny(input, const <String>[
          'تراجع',
          'الغ اخر تعديل',
          'الغي اخر تعديل',
          'رجع العمليه اللي حذفتها',
          'رجع العملية اللي حذفتها',
          'undo the last change',
          'undo the last transaction change',
          'restore the transaction i deleted',
        ]) ||
        trimmed == 'undo';
  }

  List<Decimal> _amounts(String input) {
    final matches = RegExp(
      r'[0-9\u0660-\u0669\u06f0-\u06f9]+(?:[\.,\u066b][0-9\u0660-\u0669\u06f0-\u06f9]+)?',
    ).allMatches(input);
    return matches
        .map((match) => LocalizedDecimalParser.tryParse(match.group(0)!))
        .whereType<Decimal>()
        .toList(growable: false);
  }

  (Decimal?, Decimal?) _amountChange(String input, List<Decimal> amounts) {
    if (amounts.isEmpty) return (null, null);
    if (amounts.length == 1) return (null, amounts.single);
    final normalized = _normalize(input);
    final firstAmount = RegExp(
      r'[0-9\u0660-\u0669\u06f0-\u06f9]+(?:[\.,\u066b][0-9\u0660-\u0669\u06f0-\u06f9]+)?',
    ).firstMatch(input);
    final replacementWord = normalized.indexOf('بدل');
    if (firstAmount != null &&
        replacementWord >= 0 &&
        firstAmount.start < input.indexOf('بدل')) {
      // Libyan phrasing commonly puts the new value first:
      // "خليها 50 بدل 30" => 30 -> 50.
      return (amounts.last, amounts.first);
    }
    return (amounts.first, amounts.last);
  }

  List<T> _entityMatches<T>(
    String input,
    List<T> values,
    String Function(T value) label,
  ) {
    final matches = <(int, T)>[];
    for (final value in values) {
      final token = _normalize(label(value));
      if (token.isEmpty) continue;
      final directIndex = input.indexOf(token);
      final attachedLamIndex = token.startsWith('ال')
          ? input.indexOf('ل${token.substring(1)}')
          : -1;
      final index = directIndex >= 0 ? directIndex : attachedLamIndex;
      if (index >= 0) matches.add((index, value));
    }
    matches.sort((left, right) => left.$1.compareTo(right.$1));
    return matches.map((item) => item.$2).toList(growable: false);
  }

  List<Payee> _payeeMatches(String input, List<Payee> payees) {
    final matches = <(int, Payee)>[];
    for (final payee in payees) {
      final names = <String>[payee.name, ...payee.aliases];
      final indexes = names
          .map((name) => input.indexOf(_normalize(name)))
          .where((index) => index >= 0)
          .toList(growable: false);
      if (indexes.isNotEmpty) matches.add((indexes.reduce(_min), payee));
    }
    matches.sort((left, right) => left.$1.compareTo(right.$1));
    return matches.map((item) => item.$2).toList(growable: false);
  }

  (String?, String?) _oldAndNewEntity(
    String input,
    List<String> ids, {
    required bool isUpdate,
  }) {
    if (ids.isEmpty) return (null, null);
    if (!isUpdate) return (ids.first, null);
    if (ids.length >= 2) return (ids.first, ids.last);
    final hasDestination = RegExp(
      r'(?:^|\s)(?:الي|الى|to)(?:\s|$)',
    ).hasMatch(input);
    return hasDestination ? (null, ids.single) : (ids.single, null);
  }

  List<TransactionStatus> _statuses(String input) {
    final matches = <(int, TransactionStatus)>[];
    void add(TransactionStatus status, List<String> aliases) {
      final indexes = aliases
          .map((alias) => input.indexOf(_normalize(alias)))
          .where((index) => index >= 0)
          .toList(growable: false);
      if (indexes.isNotEmpty) matches.add((indexes.reduce(_min), status));
    }

    add(TransactionStatus.pending, const <String>[
      'معلقه',
      'المعلقه',
      'pending',
    ]);
    add(TransactionStatus.posted, const <String>[
      'منشوره',
      'المنشوره',
      'posted',
      'completed',
    ]);
    matches.sort((left, right) => left.$1.compareTo(right.$1));
    return matches.map((item) => item.$2).toList(growable: false);
  }

  (TransactionStatus?, TransactionStatus?) _oldAndNewStatus(
    List<TransactionStatus> statuses, {
    required bool isUpdate,
  }) {
    if (statuses.isEmpty) return (null, null);
    if (!isUpdate) return (statuses.first, null);
    if (statuses.length >= 2) return (statuses.first, statuses.last);
    return (null, statuses.single);
  }

  TransactionType? _transactionType(String input) {
    if (_containsAny(input, const <String>['مصروف', 'expense'])) {
      return TransactionType.expense;
    }
    if (_containsAny(input, const <String>[
      'دخل',
      'مرتب',
      'راتب',
      'income',
      'salary',
    ])) {
      return TransactionType.income;
    }
    return null;
  }

  DateTime? _relativeDay(String input, DateTime nowUtc, String timeZoneName) {
    _ensureTimeZonesInitialized();
    final locationName =
        _timeZoneAliases[timeZoneName.trim()] ??
        (timeZoneName.trim().isEmpty ? 'Africa/Tripoli' : timeZoneName.trim());
    timezone.Location location;
    try {
      location = timezone.getLocation(locationName);
    } on Object {
      location = timezone.getLocation('Africa/Tripoli');
    }
    final localNow = timezone.TZDateTime.from(nowUtc, location);
    final localDay = timezone.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day,
    );
    if (_containsAny(input, const <String>['اليوم', 'today'])) {
      return localDay.toUtc();
    }
    if (_containsAny(input, const <String>['امس', 'البارح', 'yesterday'])) {
      return timezone.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day - 1,
      ).toUtc();
    }
    return null;
  }

  PaymentMethod? _newPaymentMethod(String input) {
    if (!_containsAny(input, const <String>[
      'طريقه الدفع',
      'طريقة الدفع',
      'payment method',
      'كاش',
      'cash',
      'بطاقه',
      'card',
      'ادفعلي',
      'مصرفي',
      'موبي',
      'يسر',
    ])) {
      return null;
    }
    return LibyanPaymentMethodCatalog.matchAlias(
          input,
        )?.transactionPaymentMethod ??
        (input.contains('كاش') || input.contains('cash')
            ? PaymentMethod.cash
            : null);
  }

  IncomeSourceType? _newIncomeSourceType(String input) {
    if (!_containsAny(input, const <String>[
      'تصنيف الدخل',
      'مصدر الدخل',
      'income source',
    ])) {
      return null;
    }
    const aliases = <IncomeSourceType, List<String>>{
      IncomeSourceType.salary: <String>['مرتب', 'راتب', 'salary'],
      IncomeSourceType.freelance: <String>['عمل حر', 'freelance'],
      IncomeSourceType.businessRevenue: <String>['دخل تجاري', 'business'],
      IncomeSourceType.gift: <String>['هديه', 'gift'],
      IncomeSourceType.refund: <String>['استرجاع', 'refund'],
      IncomeSourceType.reimbursement: <String>['تعويض', 'reimbursement'],
      IncomeSourceType.loanProceeds: <String>['قرض', 'loan'],
    };
    for (final entry in aliases.entries) {
      if (_containsAny(input, entry.value)) return entry.key;
    }
    return null;
  }

  String? _changedText(String normalized, String original, List<String> keys) {
    if (!_containsAny(normalized, keys)) return null;
    final match = RegExp(
      r'(?:إلى|الى|لـ|to)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(original.trim());
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  List<String> _subjectHints(
    String input, {
    required List<String> ignoredEntityLabels,
  }) {
    final ignoredTokens = ignoredEntityLabels
        .expand((label) => _normalize(label).split(' '))
        .map(_semanticToken)
        .toSet();
    final cleaned = input
        .replaceAll(RegExp(r'[0-9\u0660-\u0669\u06f0-\u06f9\.,\u066b]+'), ' ')
        .split(' ')
        .map(_semanticToken)
        .where(
          (token) =>
              token.length >= 3 &&
              !_isSubjectStopWord(token) &&
              !ignoredTokens.contains(token),
        )
        .toSet()
        .take(6)
        .toList(growable: false);
    return cleaned;
  }

  String _normalize(String input) => CurrencyCatalog.normalizeText(input)
      .replaceAll(RegExp(r"['\u2018\u2019]"), '')
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _semanticToken(String value) {
    final normalized = _normalize(value);
    return normalized.startsWith('ال') && normalized.length > 4
        ? normalized.substring(2)
        : normalized;
  }

  bool _isSubjectStopWord(String token) {
    if (_stopWords.contains(token)) return true;
    return token.startsWith('و') &&
        token.length > 1 &&
        _stopWords.contains(token.substring(1));
  }

  bool _containsAny(String input, Iterable<String> values) =>
      values.any((value) => input.contains(_normalize(value)));
}

bool _timeZonesInitialized = false;

void _ensureTimeZonesInitialized() {
  if (_timeZonesInitialized) return;
  timezone_data.initializeTimeZones();
  _timeZonesInitialized = true;
}

const _timeZoneAliases = <String, String>{
  'Libya Standard Time': 'Africa/Tripoli',
  'EET': 'Africa/Tripoli',
  'UTC': 'UTC',
  'GMT': 'UTC',
};

int _min(int left, int right) => left < right ? left : right;

const _stopWords = <String>{
  'عدل',
  'غير',
  'بدل',
  'خلي',
  'خليه',
  'خليها',
  'رجع',
  'احذف',
  'امسح',
  'الغي',
  'عمليه',
  'معامله',
  'مصروف',
  'دخل',
  'اخر',
  'اخيره',
  'اليوم',
  'يوم',
  'امس',
  'البارح',
  'بارح',
  'معلقه',
  'منشوره',
  'دينار',
  'حساب',
  'تصنيف',
  'تحويل',
  'بدلها',
  'حذفتها',
  'اللي',
  'من',
  'الي',
  'الى',
  'to',
  'from',
  'with',
  'into',
  'last',
  'latest',
  'today',
  'yesterday',
  'edit',
  'change',
  'move',
  'delete',
  'remove',
  'cancel',
  'transaction',
  'expense',
  'income',
  'pending',
  'posted',
  'lyd',
};
