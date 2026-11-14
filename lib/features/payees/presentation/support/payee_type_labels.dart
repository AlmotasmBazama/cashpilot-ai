import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/payee_type.dart';

abstract final class PayeeTypeLabels {
  static String label(AppLocalizations l10n, PayeeType type) => switch (type) {
    PayeeType.person => l10n.payeeTypePerson,
    PayeeType.merchant => l10n.payeeTypeMerchant,
    PayeeType.employer => l10n.payeeTypeEmployer,
    PayeeType.bank => l10n.payeeTypeBank,
    PayeeType.paymentService => l10n.payeeTypePaymentService,
    PayeeType.utility => l10n.payeeTypeUtility,
    PayeeType.school => l10n.payeeTypeSchool,
    PayeeType.telecom => l10n.payeeTypeTelecom,
    PayeeType.government => l10n.payeeTypeGovernment,
    PayeeType.other => l10n.payeeTypeOther,
  };
}
