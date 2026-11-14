import '../enums/duplicate_match_strength.dart';

class ReceiptDuplicateResult {
  const ReceiptDuplicateResult({
    required this.strength,
    this.candidateIds = const <String>[],
  });

  final DuplicateMatchStrength strength;
  final List<String> candidateIds;
}
