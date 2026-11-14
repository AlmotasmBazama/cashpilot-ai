enum BudgetPeriodType { weekly, monthly, yearly, custom }

extension BudgetPeriodTypeStorage on BudgetPeriodType {
  String get storageValue => name;

  static BudgetPeriodType fromStorage(String value) {
    return BudgetPeriodType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => BudgetPeriodType.monthly,
    );
  }
}
