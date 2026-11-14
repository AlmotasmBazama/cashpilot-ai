import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'receipt_providers.dart';
import 'receipt_review_workflow.dart';

final receiptReviewWorkflowProvider = Provider<ReceiptReviewWorkflow>(
  (ref) => ReceiptReviewWorkflow(
    repository: ref.watch(receiptRepositoryProvider),
    buildTransactionDraft:
        ({
          required draft,
          required account,
          required categories,
          required paymentMethod,
          required warningsAcknowledged,
          duplicateAcknowledged = false,
          explicitAccountAmount,
          explicitExchangeRate,
        }) => ref.read(buildReceiptTransactionDraftUseCaseProvider)(
          draft: draft,
          account: account,
          categories: categories,
          paymentMethod: paymentMethod,
          warningsAcknowledged: warningsAcknowledged,
          duplicateAcknowledged: duplicateAcknowledged,
          explicitAccountAmount: explicitAccountAmount,
          explicitExchangeRate: explicitExchangeRate,
        ),
    confirmTransaction: (draft, {required confirmed}) => ref.read(
      confirmReceiptTransactionUseCaseProvider,
    )(draft, confirmed: confirmed),
  ),
  name: 'receiptReviewWorkflowProvider',
);
