import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../../../income_sources/domain/enums/income_source_type.dart';
import 'ai_intent.dart';

class AiStructuredActionOutput {
  const AiStructuredActionOutput({
    required this.intent,
    required this.requiresConfirmation,
    this.confidence,
    this.amount,
    this.currency,
    this.description,
    this.itemDescription,
    this.categoryHint,
    this.categoryConfidence,
    this.categoryAlternatives = const <String>[],
    this.accountHint,
    this.sourceAccountHint,
    this.destinationAccountHint,
    this.destinationAmount,
    this.exchangeRate,
    this.periodType,
    this.goalType,
    this.goalHint,
    this.payeeHint,
    this.incomeSourceType,
    this.incomeSourceHint,
    this.incomeSourcePayeeHint,
    this.dateText,
    this.isRefund,
    this.isReimbursement,
    this.isLoanProceeds,
    this.isInternalTransfer,
    this.clarificationQuestion,
  });

  final AiIntent intent;
  final bool requiresConfirmation;
  final int? confidence;
  final String? amount;
  final String? currency;
  final String? description;
  final String? itemDescription;
  final String? categoryHint;
  final int? categoryConfidence;
  final List<String> categoryAlternatives;
  final String? accountHint;
  final String? sourceAccountHint;
  final String? destinationAccountHint;
  final String? destinationAmount;
  final String? exchangeRate;
  final String? periodType;
  final String? goalType;
  final String? goalHint;
  final String? payeeHint;
  final IncomeSourceType? incomeSourceType;
  final String? incomeSourceHint;
  final String? incomeSourcePayeeHint;
  final String? dateText;
  final bool? isRefund;
  final bool? isReimbursement;
  final bool? isLoanProceeds;
  final bool? isInternalTransfer;
  final String? clarificationQuestion;

  static AiStructuredActionOutput? tryParse(String content) {
    final jsonText = _extractJsonObject(content);
    if (jsonText == null) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      return null;
    }

    if (decoded is! Map) {
      return null;
    }

    final json = Map<String, Object?>.from(decoded);
    if (!_hasSupportedSchema(json)) {
      return null;
    }

    return AiStructuredActionOutput.fromJson(json);
  }

  factory AiStructuredActionOutput.fromJson(Map<String, Object?> json) {
    return AiStructuredActionOutput(
      intent: AiIntentMapper.fromStorage(_string(json['intent'])),
      confidence: _confidence(json['confidence']),
      amount: _string(json['amount']),
      currency: _string(json['currency'])?.toUpperCase(),
      description: _string(json['description']),
      itemDescription: _string(json['itemDescription']),
      categoryHint: _string(json['categoryHint']),
      categoryConfidence: _confidence(json['categoryConfidence']),
      categoryAlternatives: _stringList(json['categoryAlternatives']),
      accountHint: _string(json['accountHint']),
      sourceAccountHint: _string(json['sourceAccountHint']),
      destinationAccountHint: _string(json['destinationAccountHint']),
      destinationAmount: _string(json['destinationAmount']),
      exchangeRate: _string(json['exchangeRate']),
      periodType: _string(json['periodType']),
      goalType: _string(json['goalType']),
      goalHint: _string(json['goalHint']),
      payeeHint: _string(json['payeeHint']),
      incomeSourceType: IncomeSourceTypeMapper.tryFromStorage(
        _string(json['incomeSourceType']),
      ),
      incomeSourceHint: _string(json['incomeSourceHint']),
      incomeSourcePayeeHint: _string(json['incomeSourcePayeeHint']),
      dateText: _string(json['dateText']),
      isRefund: _boolean(json['isRefund']),
      isReimbursement: _boolean(json['isReimbursement']),
      isLoanProceeds: _boolean(json['isLoanProceeds']),
      isInternalTransfer: _boolean(json['isInternalTransfer']),
      requiresConfirmation: json['requiresConfirmation'] == true,
      clarificationQuestion: _string(json['clarificationQuestion']),
    );
  }

  static String? _extractJsonObject(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }

    return content.substring(start, end + 1);
  }

  static String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  static int? _confidence(Object? value) {
    final text = switch (value) {
      String() => value,
      int() => value.toString(),
      _ => null,
    };
    if (text == null) {
      return null;
    }

    final parsed = Decimal.tryParse(text);
    if (parsed == null) {
      return null;
    }

    final percent = parsed <= Decimal.one
        ? parsed * Decimal.fromInt(100)
        : parsed;
    return percent.round().toBigInt().toInt().clamp(0, 100);
  }

  static bool? _boolean(Object? value) => value is bool ? value : null;

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }

  static bool _hasSupportedSchema(Map<String, Object?> json) {
    final rawIntent = _string(json['intent']);
    final confirmation = json['requiresConfirmation'];
    if (rawIntent == null || confirmation is! bool) {
      return false;
    }

    final intent = AiIntentMapper.fromStorage(rawIntent);
    if (intent == AiIntent.unknown && rawIntent.toLowerCase() != 'unknown') {
      return false;
    }

    final rawIncomeSourceType = _string(json['incomeSourceType']);
    if (rawIncomeSourceType != null &&
        IncomeSourceTypeMapper.tryFromStorage(rawIncomeSourceType) == null) {
      return false;
    }
    for (final key in const <String>[
      'isRefund',
      'isReimbursement',
      'isLoanProceeds',
      'isInternalTransfer',
    ]) {
      final value = json[key];
      if (value != null && value is! bool) {
        return false;
      }
    }

    final changesData = switch (intent) {
      AiIntent.createExpense ||
      AiIntent.createIncome ||
      AiIntent.createTransfer ||
      AiIntent.createCategory ||
      AiIntent.createBudget ||
      AiIntent.createGoal ||
      AiIntent.addGoalContribution => true,
      _ => false,
    };
    if (changesData && !confirmation) {
      return false;
    }

    final requiresAmount = switch (intent) {
      AiIntent.createExpense ||
      AiIntent.createIncome ||
      AiIntent.createTransfer ||
      AiIntent.createBudget ||
      AiIntent.createGoal ||
      AiIntent.addGoalContribution => true,
      _ => false,
    };
    if (requiresAmount) {
      final amount = json['amount'];
      if (amount is! String ||
          Decimal.tryParse(amount.replaceAll(',', '.')) == null) {
        return false;
      }
    }

    return true;
  }
}
