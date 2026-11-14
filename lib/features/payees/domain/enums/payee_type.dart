enum PayeeType {
  person,
  merchant,
  employer,
  bank,
  paymentService,
  utility,
  school,
  telecom,
  government,
  other,
}

extension PayeeTypeX on PayeeType {
  String get storageValue => name;
}

abstract final class PayeeTypeMapper {
  static PayeeType fromStorage(String value) {
    return PayeeType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => PayeeType.other,
    );
  }
}
