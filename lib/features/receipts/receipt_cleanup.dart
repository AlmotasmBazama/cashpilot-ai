import 'data/services/receipt_local_image_store.dart';
import 'domain/services/receipt_image_cleanup_port.dart';

export 'domain/services/receipt_image_cleanup_port.dart';

/// Creates the production cleanup adapter for one confirmed opaque owner
/// scope. The adapter retains all path validation and legacy-token safeguards.
ReceiptImageCleanupPort createReceiptImageCleanupPort({
  required String ownerScopeValue,
}) => ReceiptLocalImageStore(ownerScopeValue: ownerScopeValue);
