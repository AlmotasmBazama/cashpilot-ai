import '../enums/payment_method.dart';

class PaymentMethodDefinition {
  const PaymentMethodDefinition({
    required this.id,
    required this.displayName,
    required this.providerName,
    required this.bankName,
    required this.transactionPaymentMethod,
    required this.aliases,
    this.bankAliases = const [],
  });

  final String id;
  final String displayName;
  final String providerName;
  final String bankName;
  final PaymentMethod transactionPaymentMethod;
  final List<String> aliases;
  final List<String> bankAliases;

  bool matchesAlias(String normalizedInput) {
    return aliases.any((alias) => normalizedInput.contains(_normalize(alias)));
  }

  bool matchesBank(String normalizedInput) {
    return [bankName, ...bankAliases]
        .where((bank) => bank.trim().isNotEmpty)
        .any((bank) => normalizedInput.contains(_normalize(bank)));
  }

  static String normalize(String value) => _normalize(value);
}

String _normalize(String value) {
  return value
      .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
      .replaceAll('ـ', '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '');
}
