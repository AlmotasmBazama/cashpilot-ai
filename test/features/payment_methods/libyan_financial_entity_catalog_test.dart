import 'package:cashpilot_ai/features/payment_methods/payment_methods.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'official CBL commercial-bank seed keeps canonical names and aliases',
    () {
      expect(LibyanBankCatalog.banks, hasLength(26));
      expect(
        LibyanBankCatalog.matchAlias('حسابي في الجمهورية')?.id,
        'jumhouria',
      );
      expect(
        LibyanBankCatalog.matchAlias('مصرف الامان للتجارة والاستثمار')?.id,
        'alaman',
      );
      expect(
        LibyanBankCatalog.matchAlias('Libyan Foreign Bank')?.id,
        'libyan_foreign',
      );
    },
  );

  test('payment labels are recognition metadata, not integration claims', () {
    expect(
      LibyanPaymentMethodCatalog.matchAlias(
        'دفعت بخدمة LYPay',
      )?.transactionPaymentMethod,
      PaymentMethod.digitalWallet,
    );
    expect(
      LibyanPaymentMethodCatalog.matchAlias(
        'دفعت في نقطة بيع',
      )?.transactionPaymentMethod,
      PaymentMethod.debitCard,
    );
    expect(
      LibyanPaymentMethodCatalog.matchAlias(
        'دفعت بصك',
      )?.transactionPaymentMethod,
      PaymentMethod.check,
    );
  });
}
