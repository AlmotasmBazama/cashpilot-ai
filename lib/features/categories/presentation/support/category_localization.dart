import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_type.dart';

abstract final class CategoryLocalization {
  static String typeLabel(AppLocalizations l10n, CategoryType type) {
    return switch (type) {
      CategoryType.expense => l10n.categoryTypeExpense,
      CategoryType.income => l10n.categoryTypeIncome,
      CategoryType.transfer => l10n.categoryTypeTransfer,
    };
  }

  static String name(AppLocalizations l10n, Category category) {
    if (!category.isDefault) {
      return category.name;
    }

    return defaultCategoryName(l10n, category.name);
  }

  static String defaultCategoryName(AppLocalizations l10n, String name) {
    return switch (name) {
      'Food' => l10n.categoryNameFood,
      'Coffee' => l10n.categoryNameCoffee,
      'Restaurant' => l10n.categoryNameRestaurant,
      'Transport' => l10n.categoryNameTransport,
      'Taxi' => l10n.categoryNameTaxi,
      'Fuel' => l10n.categoryNameFuel,
      'Shopping' => l10n.categoryNameShopping,
      'Groceries' => l10n.categoryNameGroceries,
      'Entertainment' => l10n.categoryNameEntertainment,
      'Gaming' => l10n.categoryNameGaming,
      'Travel' => l10n.categoryNameTravel,
      'Hotel' => l10n.categoryNameHotel,
      'Bills' => l10n.categoryNameBills,
      'Internet' => l10n.categoryNameInternet,
      'Phone' => l10n.categoryNamePhone,
      'Rent' => l10n.categoryNameRent,
      'Insurance' => l10n.categoryNameInsurance,
      'Healthcare' => l10n.categoryNameHealthcare,
      'Pharmacy' => l10n.categoryNamePharmacy,
      'Education' => l10n.categoryNameEducation,
      'Subscription' => l10n.categoryNameSubscription,
      'Electronics' => l10n.categoryNameElectronics,
      'Pets' => l10n.categoryNamePets,
      'Charity' => l10n.categoryNameCharity,
      'Taxes' => l10n.categoryNameTaxes,
      'Gift' => l10n.categoryNameGift,
      'Clothing' => l10n.categoryNameClothing,
      'Sports' => l10n.categoryNameSports,
      'Beauty' => l10n.categoryNameBeauty,
      'Home' => l10n.categoryNameHome,
      'Salary' => l10n.categoryNameSalary,
      'Freelance' => l10n.categoryNameFreelance,
      'Bonus' => l10n.categoryNameBonus,
      'Investment' => l10n.categoryNameInvestment,
      'Refund' => l10n.categoryNameRefund,
      'Cashback' => l10n.categoryNameCashback,
      'Rental Income' => l10n.categoryNameRentalIncome,
      'Interest' => l10n.categoryNameInterest,
      'Other Income' => l10n.categoryNameOtherIncome,
      'Business Revenue' => l10n.categoryNameBusinessRevenue,
      'Allowance' => l10n.categoryNameAllowance,
      'Reimbursement' => l10n.categoryNameReimbursement,
      'Sale Proceeds' => l10n.categoryNameSaleProceeds,
      'Government Support' => l10n.categoryNameGovernmentSupport,
      'Scholarship' => l10n.categoryNameScholarship,
      'Prize' => l10n.categoryNamePrize,
      'Loan Proceeds' => l10n.categoryNameLoanProceeds,
      'Transfer' => l10n.categoryNameTransfer,
      _ => name,
    };
  }
}
