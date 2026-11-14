import 'package:decimal/decimal.dart';

import '../enums/income_source_type.dart';

enum IncomeSourceSuggestionSource {
  explicitUserInput,
  trustedLocalRule,
  payeeDefault,
  exactPhrase,
  aiSemantic,
  localParser,
  fallback,
}

class IncomeSourceSuggestion {
  const IncomeSourceSuggestion({
    required this.sourceType,
    required this.confidence,
    required this.source,
    required this.requiresClarification,
    this.sourceNameHint,
    this.sourcePayeeId,
    this.categoryId,
    this.categoryHint,
    this.destinationAccountId,
    this.destinationAccountHint,
    this.amount,
    this.currency,
    this.transactionDate,
    this.description,
    this.alternatives = const <IncomeSourceType>[],
    this.clarificationQuestion,
    this.isInternalTransfer = false,
  });

  final IncomeSourceType sourceType;
  final String? sourceNameHint;
  final String? sourcePayeeId;
  final String? categoryId;
  final String? categoryHint;
  final String? destinationAccountId;
  final String? destinationAccountHint;
  final Decimal? amount;
  final String? currency;
  final DateTime? transactionDate;
  final String? description;
  final int confidence;
  final IncomeSourceSuggestionSource source;
  final List<IncomeSourceType> alternatives;
  final bool requiresClarification;
  final String? clarificationQuestion;
  final bool isInternalTransfer;

  bool get isNormalEarnedIncome =>
      !isInternalTransfer && sourceType.isEarnedIncome;

  IncomeSourceSuggestion copyWith({
    IncomeSourceType? sourceType,
    String? sourceNameHint,
    String? sourcePayeeId,
    String? categoryId,
    String? categoryHint,
    String? destinationAccountId,
    String? destinationAccountHint,
    Decimal? amount,
    String? currency,
    DateTime? transactionDate,
    String? description,
    int? confidence,
    IncomeSourceSuggestionSource? source,
    List<IncomeSourceType>? alternatives,
    bool? requiresClarification,
    String? clarificationQuestion,
    bool? isInternalTransfer,
  }) {
    return IncomeSourceSuggestion(
      sourceType: sourceType ?? this.sourceType,
      sourceNameHint: sourceNameHint ?? this.sourceNameHint,
      sourcePayeeId: sourcePayeeId ?? this.sourcePayeeId,
      categoryId: categoryId ?? this.categoryId,
      categoryHint: categoryHint ?? this.categoryHint,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      destinationAccountHint:
          destinationAccountHint ?? this.destinationAccountHint,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      transactionDate: transactionDate ?? this.transactionDate,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      alternatives: alternatives ?? this.alternatives,
      requiresClarification:
          requiresClarification ?? this.requiresClarification,
      clarificationQuestion:
          clarificationQuestion ?? this.clarificationQuestion,
      isInternalTransfer: isInternalTransfer ?? this.isInternalTransfer,
    );
  }
}
