enum PaymentMethod {
  cash,
  debitCard,
  creditCard,
  bankTransfer,
  digitalWallet,
  edfaly,
  masrafiPay,
  mobiCash,
  yusrPay,
  check,
  crypto,
  other,
}

extension PaymentMethodX on PaymentMethod {
  String get storageValue => name;
}

abstract final class PaymentMethodMapper {
  static PaymentMethod fromStorage(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.storageValue == value,
      orElse: () => PaymentMethod.other,
    );
  }
}
