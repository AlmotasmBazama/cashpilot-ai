enum IncomeSourceType {
  salary,
  freelance,
  businessRevenue,
  gift,
  allowance,
  refund,
  sale,
  rentalIncome,
  governmentSupport,
  scholarship,
  investmentReturn,
  reimbursement,
  debtRepayment,
  prize,
  loanProceeds,
  externalTransfer,
  other,
}

enum IncomeSourceReportingBucket {
  ordinaryIncome,
  refundOrReimbursement,
  debtRepayment,
  loanProceeds,
  externalTransfer,
  unclassified,
}

extension IncomeSourceTypeX on IncomeSourceType {
  String get storageValue {
    return switch (this) {
      IncomeSourceType.businessRevenue => 'business_revenue',
      IncomeSourceType.rentalIncome => 'rental_income',
      IncomeSourceType.governmentSupport => 'government_support',
      IncomeSourceType.investmentReturn => 'investment_return',
      IncomeSourceType.debtRepayment => 'debt_repayment',
      IncomeSourceType.loanProceeds => 'loan_proceeds',
      IncomeSourceType.externalTransfer => 'external_transfer',
      _ => name,
    };
  }

  bool get isEarnedIncome {
    return switch (this) {
      IncomeSourceType.salary ||
      IncomeSourceType.freelance ||
      IncomeSourceType.businessRevenue ||
      IncomeSourceType.rentalIncome => true,
      _ => false,
    };
  }

  IncomeSourceReportingBucket get reportingBucket {
    return switch (this) {
      IncomeSourceType.salary ||
      IncomeSourceType.freelance ||
      IncomeSourceType.businessRevenue ||
      IncomeSourceType.gift ||
      IncomeSourceType.allowance ||
      IncomeSourceType.sale ||
      IncomeSourceType.rentalIncome ||
      IncomeSourceType.governmentSupport ||
      IncomeSourceType.scholarship ||
      IncomeSourceType.investmentReturn ||
      IncomeSourceType.prize => IncomeSourceReportingBucket.ordinaryIncome,
      IncomeSourceType.refund || IncomeSourceType.reimbursement =>
        IncomeSourceReportingBucket.refundOrReimbursement,
      IncomeSourceType.debtRepayment =>
        IncomeSourceReportingBucket.debtRepayment,
      IncomeSourceType.loanProceeds => IncomeSourceReportingBucket.loanProceeds,
      IncomeSourceType.externalTransfer =>
        IncomeSourceReportingBucket.externalTransfer,
      IncomeSourceType.other => IncomeSourceReportingBucket.unclassified,
    };
  }

  bool get needsSpecialReview {
    return reportingBucket != IncomeSourceReportingBucket.ordinaryIncome;
  }

  bool get requiresSourceIdentity {
    return switch (this) {
      IncomeSourceType.gift ||
      IncomeSourceType.debtRepayment ||
      IncomeSourceType.loanProceeds ||
      IncomeSourceType.reimbursement ||
      IncomeSourceType.externalTransfer => true,
      _ => false,
    };
  }
}

abstract final class IncomeSourceTypeMapper {
  static IncomeSourceType? tryFromStorage(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('-', '_');
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    for (final type in IncomeSourceType.values) {
      if (type.storageValue == normalized ||
          type.name.toLowerCase() == normalized) {
        return type;
      }
    }
    return null;
  }
}
