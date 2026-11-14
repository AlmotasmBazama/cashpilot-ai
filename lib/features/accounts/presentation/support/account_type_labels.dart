import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/account_type.dart';

abstract final class AccountTypeLabels {
  static String label(AppLocalizations l10n, AccountType type) {
    return switch (type) {
      AccountType.cash => l10n.accountTypeCash,
      AccountType.bank => l10n.accountTypeBank,
      AccountType.creditCard => l10n.accountTypeCreditCard,
      AccountType.debitCard => l10n.accountTypeDebitCard,
      AccountType.savings => l10n.accountTypeSavings,
      AccountType.investment => l10n.accountTypeInvestment,
      AccountType.digitalWallet => l10n.accountTypeDigitalWallet,
      AccountType.crypto => l10n.accountTypeCrypto,
      AccountType.other => l10n.accountTypeOther,
    };
  }
}
