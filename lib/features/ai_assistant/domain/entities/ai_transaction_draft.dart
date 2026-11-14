import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_suggestion.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../income_sources/domain/entities/income_source_suggestion.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../payment_methods/payment_methods.dart'
    show PaymentMethod, PaymentMethodDefinition;
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';

sealed class AiTransactionParseResult {
  const AiTransactionParseResult();
}

class AiTransactionDraft extends AiTransactionParseResult {
  static const String unresolvedAccountId =
      '__cashpilot_unresolved_destination__';

  const AiTransactionDraft({
    required this.type,
    required this.amount,
    required this.account,
    required this.category,
    required this.paymentMethod,
    required this.paymentMethodDefinition,
    required this.note,
    this.payee,
    this.payeeHint,
    this.itemDescription,
    this.categorySuggestion,
    this.incomeSourceSuggestion,
    this.transactionDate,
    this.status = TransactionStatus.posted,
  });

  final TransactionType type;
  final Money amount;
  final Account account;
  final Category? category;
  final PaymentMethod paymentMethod;
  final PaymentMethodDefinition? paymentMethodDefinition;
  final String note;
  final Payee? payee;
  final String? payeeHint;
  final String? itemDescription;
  final CategorySuggestion? categorySuggestion;
  final IncomeSourceSuggestion? incomeSourceSuggestion;
  final DateTime? transactionDate;
  final TransactionStatus status;

  String? get incomeSourceIdentity {
    final identity =
        payee?.name ?? incomeSourceSuggestion?.sourceNameHint ?? payeeHint;
    final normalized = identity?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String get noteForPersistence {
    final normalizedNote = note.trim();
    final identity = incomeSourceIdentity;
    if (type != TransactionType.income || payee != null || identity == null) {
      return note;
    }
    if (_containsNormalizedPhrase(normalizedNote, identity)) {
      return note;
    }
    final sourceLabel = 'Source: $identity';
    return normalizedNote.isEmpty
        ? sourceLabel
        : '$normalizedNote\n$sourceLabel';
  }

  AiTransactionDraft copyWith({
    TransactionType? type,
    Money? amount,
    Account? account,
    Category? category,
    bool clearCategory = false,
    PaymentMethod? paymentMethod,
    PaymentMethodDefinition? paymentMethodDefinition,
    String? note,
    Payee? payee,
    String? payeeHint,
    String? itemDescription,
    CategorySuggestion? categorySuggestion,
    IncomeSourceSuggestion? incomeSourceSuggestion,
    DateTime? transactionDate,
    TransactionStatus? status,
  }) {
    return AiTransactionDraft(
      type: type ?? this.type,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      category: clearCategory ? null : category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodDefinition:
          paymentMethodDefinition ?? this.paymentMethodDefinition,
      note: note ?? this.note,
      payee: payee ?? this.payee,
      payeeHint: payeeHint ?? this.payeeHint,
      itemDescription: itemDescription ?? this.itemDescription,
      categorySuggestion: categorySuggestion ?? this.categorySuggestion,
      incomeSourceSuggestion:
          incomeSourceSuggestion ?? this.incomeSourceSuggestion,
      transactionDate: transactionDate ?? this.transactionDate,
      status: status ?? this.status,
    );
  }

  static bool _containsNormalizedPhrase(String value, String phrase) {
    String normalize(String input) => input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalizedValue = normalize(value);
    final normalizedPhrase = normalize(phrase);
    return normalizedPhrase.isNotEmpty &&
        ' $normalizedValue '.contains(' $normalizedPhrase ');
  }
}

class AiTransactionClarification extends AiTransactionParseResult {
  const AiTransactionClarification({required this.message});

  final String message;
}

class AiTransactionParseFailure extends AiTransactionParseResult {
  const AiTransactionParseFailure({required this.message});

  final String message;
}
