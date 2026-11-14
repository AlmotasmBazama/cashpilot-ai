import 'dart:convert';

import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/payment_methods/payment_methods.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart'
    as legacy;
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_source.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/transactions.dart'
    as transactions_api;
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedStorageValues = <String>[
    'cash',
    'debitCard',
    'creditCard',
    'bankTransfer',
    'digitalWallet',
    'edfaly',
    'masrafiPay',
    'mobiCash',
    'yusrPay',
    'check',
    'crypto',
    'other',
  ];

  test('PaymentMethod order, names, indexes and storage values stay exact', () {
    expect(
      PaymentMethod.values.map((value) => value.name),
      expectedStorageValues,
    );
    expect(
      PaymentMethod.values.map((value) => value.storageValue),
      expectedStorageValues,
    );
    expect(
      PaymentMethod.values.map((value) => value.index),
      List<int>.generate(expectedStorageValues.length, (index) => index),
    );
  });

  test('former Transactions path preserves the exact contract identity', () {
    expect(legacy.PaymentMethod, same(PaymentMethod));
    expect(legacy.PaymentMethodMapper, same(PaymentMethodMapper));
    expect(transactions_api.PaymentMethod, same(PaymentMethod));
    expect(identical(legacy.PaymentMethod.cash, PaymentMethod.cash), isTrue);
    expect(
      legacy.PaymentMethodMapper.fromStorage('bankTransfer'),
      same(PaymentMethod.bankTransfer),
    );
    expect(legacy.PaymentMethodX(PaymentMethod.edfaly).storageValue, 'edfaly');
  });

  test('storage mapper remains exact and falls back to other', () {
    for (final method in PaymentMethod.values) {
      expect(
        PaymentMethodMapper.fromStorage(method.storageValue),
        same(method),
      );
    }

    for (final unsupported in const ['', 'Cash', ' cash ', 'unsupported']) {
      expect(
        PaymentMethodMapper.fromStorage(unsupported),
        PaymentMethod.other,
        reason: 'Unsupported storage text must retain the safe fallback.',
      );
    }
  });

  test('generated Transaction JSON keeps every payment method wire value', () {
    final timestamp = DateTime.utc(2026, 8, 17, 12, 34, 56);

    for (final method in PaymentMethod.values) {
      final transaction = Transaction(
        id: 'transaction-${method.name}',
        accountId: 'account-1',
        categoryId: 'category-1',
        amount: Money(amount: Decimal.parse('12.3400'), currencyCode: 'LYD'),
        type: TransactionType.expense,
        paymentMethod: method,
        source: TransactionSource.manual,
        status: TransactionStatus.posted,
        transactionDate: timestamp,
        attachmentCount: 0,
        needsReview: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      final json =
          jsonDecode(jsonEncode(transaction.toJson())) as Map<String, dynamic>;
      expect(json['paymentMethod'], method.storageValue);
      expect(Transaction.fromJson(json).paymentMethod, same(method));
    }
  });
}
