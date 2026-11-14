/// Owner-scoped receipt-image operations required by account deletion.
///
/// The port deliberately excludes image creation and direct-reference deletion
/// so deletion workflows cannot depend on the Receipts persistence adapter.
abstract interface class ReceiptImageCleanupPort {
  Future<String?> deletionTokenForReference(String? reference);

  Future<bool> deleteToken(String token);

  Future<List<String>> listDeletionTokens();

  Future<bool> get isEmpty;

  Future<void> deleteAll();
}
