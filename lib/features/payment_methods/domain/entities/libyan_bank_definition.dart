import 'payment_method_definition.dart';

class LibyanBankDefinition {
  const LibyanBankDefinition({
    required this.id,
    required this.displayName,
    required this.aliases,
  });

  final String id;
  final String displayName;
  final List<String> aliases;

  bool matchesText(String input) {
    final normalized = PaymentMethodDefinition.normalize(input);
    return _names.any(
      (name) => normalized.contains(PaymentMethodDefinition.normalize(name)),
    );
  }

  Iterable<String> get _names => <String>[displayName, ...aliases];
}
