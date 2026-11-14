// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_intent_router.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:decimal/decimal.dart';

void main() {
  const router = AiIntentRouter();
  const parser = FinancialCommandParser();
  final now = DateTime.utc(2026, 8, 9);
  final accounts = <Account>[
    Account(
      id: 'probe-cash',
      name: 'الكاش',
      type: AccountType.cash,
      currencyCode: 'LYD',
      balance: Decimal.parse('1000'),
      icon: 'wallet',
      color: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final routingInputs = <String>[
    'مرحبا',
    'What can you do?',
    'Explain compound interest',
    'What is cash flow?',
    'ما هو سعر الدولار اليوم؟',
    'كم صرفت على الطعام هذا الشهر؟',
    'سجللي مصروف 25.50 دينار على القهوة من حساب الكاش',
    'Scan this receipt',
    'امسح هذه الفاتورة',
    'Go to reports',
    'افتحلي التقارير',
    'احذف كل معاملاتي',
  ];
  final parseInputs = <String>[
    'سجللي مصروف ١٢٫٥٠ دينار من حساب الكاش',
    'ديرلي مصروف خمسة وعشرين دينار من حساب الكاش',
    'سجللي مصروف 25.50 دينار من حساب الكاش',
  ];

  final output = <String, Object?>{
    'routing': [
      for (final input in routingInputs)
        {
          'input': input,
          'intent': router.route(input).intent.name,
          'target': router.route(input).target.name,
          'deterministic': router.route(input).isDeterministic,
          'financialPipeline': router.route(input).useFinancialPipeline,
          'navigationToolId': router.route(input).navigationToolId,
          'blockedIntent': router.route(input).blockedIntent?.name,
        },
    ],
    'parsing': [
      for (final input in parseInputs)
        _parseResult(
          input,
          parser.parse(
            input: input,
            accounts: accounts,
            categories: const [],
            baseCurrencyCode: 'LYD',
            paymentMethodClarificationMessage: 'اختر وسيلة الدفع',
          ),
        ),
    ],
  };

  print(const JsonEncoder.withIndent('  ').convert(output));
}

Map<String, Object?> _parseResult(
  String input,
  AiTransactionParseResult result,
) {
  return switch (result) {
    AiTransactionDraft() => {
      'input': input,
      'result': 'draft',
      'type': result.type.name,
      'amount': result.amount.amount.toString(),
      'currencyCode': result.amount.currencyCode,
      'accountId': result.account.id,
    },
    AiTransactionClarification() => {
      'input': input,
      'result': 'clarification',
      'message': result.message,
    },
    AiTransactionParseFailure() => {
      'input': input,
      'result': 'failure',
      'message': result.message,
    },
  };
}
