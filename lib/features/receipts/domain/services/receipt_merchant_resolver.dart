import '../../../payees/domain/entities/payee.dart';
import '../../../payees/domain/entities/payee_resolution.dart';
import '../../../payees/domain/services/payee_resolver.dart';
import '../entities/receipt_analysis_draft.dart';

class ReceiptMerchantResolver {
  const ReceiptMerchantResolver({
    PayeeResolver payeeResolver = const PayeeResolver(),
  }) : _payeeResolver = payeeResolver;

  final PayeeResolver _payeeResolver;

  ReceiptAnalysisDraft resolve(ReceiptAnalysisDraft draft, List<Payee> payees) {
    final merchantName = draft.merchantName;
    if (merchantName == null || merchantName.isEmpty) {
      return draft;
    }
    final resolution = _payeeResolver.resolve(merchantName, payees);
    return switch (resolution) {
      PayeeResolved(:final payee) => draft.copyWith(merchantPayeeId: payee.id),
      PayeeAmbiguous() || PayeeNotFound() => draft,
    };
  }
}
