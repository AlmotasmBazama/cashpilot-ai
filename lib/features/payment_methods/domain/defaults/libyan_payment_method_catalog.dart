import '../entities/payment_method_definition.dart';
import '../enums/payment_method.dart';

abstract final class LibyanPaymentMethodCatalog {
  static const methods = [
    PaymentMethodDefinition(
      id: 'edfaly',
      displayName: 'Edfaly',
      providerName: 'Edfaly',
      bankName: 'Trade & Development Bank',
      transactionPaymentMethod: PaymentMethod.edfaly,
      aliases: ['ادفع لي', 'ادفعلي', 'edfaly', 'edfali'],
      bankAliases: [
        'Trade & Development Bank',
        'TDB',
        'مصرف التجارة والتنمية',
        'التجارة والتنمية',
      ],
    ),
    PaymentMethodDefinition(
      id: 'masrafi_pay',
      displayName: 'Masrafi Pay',
      providerName: 'Masrafi Pay',
      bankName: 'Jumhouria Bank',
      transactionPaymentMethod: PaymentMethod.masrafiPay,
      aliases: ['مصرفي', 'masrafi', 'masrafi pay'],
      bankAliases: ['Jumhouria Bank', 'مصرف الجمهورية', 'الجمهورية'],
    ),
    PaymentMethodDefinition(
      id: 'mobi_cash',
      displayName: 'Mobi Cash',
      providerName: 'Mobi Cash',
      bankName: 'Wahda Bank',
      transactionPaymentMethod: PaymentMethod.mobiCash,
      aliases: ['موبي', 'موبي كاش', 'mobicash', 'mobi cash', 'mobi'],
      bankAliases: ['Wahda Bank', 'مصرف الوحدة', 'الوحدة'],
    ),
    PaymentMethodDefinition(
      id: 'yusr_pay',
      displayName: 'Yusr Pay',
      providerName: 'Yusr Pay',
      bankName: 'Commercial National Bank',
      transactionPaymentMethod: PaymentMethod.yusrPay,
      aliases: ['يسر', 'يسر باي', 'yusr', 'yusr pay'],
      bankAliases: [
        'Commercial National Bank',
        'National Commercial Bank',
        'المصرف التجاري الوطني',
        'التجاري الوطني',
      ],
    ),
    PaymentMethodDefinition(
      id: 'lypay',
      displayName: 'LYPay',
      providerName: 'LYPay',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['lypay', 'ly pay', 'لاي باي', 'لي باي'],
    ),
    PaymentMethodDefinition(
      id: 'onepay',
      displayName: 'OnePay',
      providerName: 'OnePay',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['onepay', 'one pay', 'ون باي', 'وان باي'],
    ),
    PaymentMethodDefinition(
      id: 'moamalat',
      displayName: 'Moamalat',
      providerName: 'Moamalat',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.debitCard,
      aliases: ['moamalat', 'moamalat.net', 'معاملات', 'معاملات نت'],
    ),
    PaymentMethodDefinition(
      id: 'tadawul',
      displayName: 'Tadawul',
      providerName: 'Tadawul',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['tadawul', 'تداول'],
    ),
    PaymentMethodDefinition(
      id: 'sadad',
      displayName: 'Sadad',
      providerName: 'Sadad',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['sadad', 'سداد'],
    ),
    PaymentMethodDefinition(
      id: 'mobimal',
      displayName: 'Mobimal',
      providerName: 'Mobimal',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['mobimal', 'mobi mal', 'موبي مال', 'موبيمال'],
    ),
    PaymentMethodDefinition(
      id: 'libopay',
      displayName: 'LiboPay',
      providerName: 'LiboPay',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['libopay', 'libo pay', 'ليبو باي', 'ليبوباي'],
    ),
    PaymentMethodDefinition(
      id: 'gpay',
      displayName: 'GPAY',
      providerName: 'GPAY',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['gpay', 'g pay', 'جي باي'],
    ),
    PaymentMethodDefinition(
      id: 'runpay',
      displayName: 'RUNPAY',
      providerName: 'RUNPAY',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['runpay', 'run pay', 'رن باي'],
    ),
    PaymentMethodDefinition(
      id: 'qr',
      displayName: 'QR payment',
      providerName: 'QR',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.digitalWallet,
      aliases: ['qr', 'qr payment', 'دفع qr', 'رمز qr'],
    ),
    PaymentMethodDefinition(
      id: 'pos',
      displayName: 'POS',
      providerName: 'POS',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.debitCard,
      aliases: ['pos', 'point of sale', 'نقطة بيع'],
    ),
    PaymentMethodDefinition(
      id: 'bank_transfer',
      displayName: 'Bank transfer',
      providerName: 'Bank transfer',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.bankTransfer,
      aliases: [
        'bank transfer',
        'iban',
        'nad',
        'حوالة مصرفية',
        'تحويل مصرفي',
        'آيبان',
      ],
    ),
    PaymentMethodDefinition(
      id: 'local_bank_card',
      displayName: 'Local bank card',
      providerName: 'Local bank card',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.debitCard,
      aliases: ['local bank card', 'بطاقة مصرفية', 'بطاقة محلية'],
    ),
    PaymentMethodDefinition(
      id: 'cheque',
      displayName: 'Cheque',
      providerName: 'Cheque',
      bankName: '',
      transactionPaymentMethod: PaymentMethod.check,
      aliases: ['cheque', 'check', 'صك', 'شيك'],
    ),
  ];

  static PaymentMethodDefinition? findById(String id) {
    for (final method in methods) {
      if (method.id == id) {
        return method;
      }
    }

    return null;
  }

  static PaymentMethodDefinition? matchAlias(String input) {
    final normalized = PaymentMethodDefinition.normalize(input);
    for (final method in methods) {
      if (method.matchesAlias(normalized)) {
        return method;
      }
    }

    return null;
  }
}
