enum CategoryType { expense, income, transfer }

extension CategoryTypeX on CategoryType {
  String get storageValue => name;

  String get label {
    return switch (this) {
      CategoryType.expense => 'Expense',
      CategoryType.income => 'Income',
      CategoryType.transfer => 'Transfer',
    };
  }
}

abstract final class CategoryTypeMapper {
  static CategoryType fromStorage(String value) {
    return CategoryType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => throw FormatException('Unsupported category type: $value'),
    );
  }
}
