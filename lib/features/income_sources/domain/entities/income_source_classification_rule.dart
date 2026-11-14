import '../enums/income_source_type.dart';

class IncomeSourceClassificationRule {
  const IncomeSourceClassificationRule({
    required this.normalizedPhrase,
    required this.sourceType,
    required this.confirmedCount,
    required this.lastUsedAt,
    this.categoryId,
    this.destinationAccountId,
    this.isExplicit = false,
  });

  final String normalizedPhrase;
  final IncomeSourceType sourceType;
  final String? categoryId;
  final String? destinationAccountId;
  final int confirmedCount;
  final DateTime lastUsedAt;
  final bool isExplicit;

  bool get isTrusted => isExplicit || confirmedCount >= 2;
}
