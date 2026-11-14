import 'package:hive/hive.dart';

import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../../../core/sync/application/backup_operation_fence.dart';

typedef BeforeReceiptConsentWrite = Future<void> Function();

class ReceiptPrivacyConsentStore {
  ReceiptPrivacyConsentStore({
    required Box<dynamic> box,
    required ConfirmedOwnerScope ownerScope,
    required BackupOperationFence operationFence,
    BeforeReceiptConsentWrite? beforeWrite,
  }) : _box = box,
       _ownerScopeValue = ownerScope.id.value,
       _operationFence = operationFence,
       _beforeWrite = beforeWrite,
       _consentKey = OwnerScopedStorageKeys.fromConfirmedOwnerScope(
         ownerScope,
       ).receiptAiPrivacyConsent;

  final Box<dynamic> _box;
  final String _ownerScopeValue;
  final BackupOperationFence _operationFence;
  final BeforeReceiptConsentWrite? _beforeWrite;
  final String _consentKey;

  bool get hasAccepted =>
      !_operationFence.isFenced(_ownerScopeValue) &&
      _box.get(_consentKey) == true;

  Future<void> accept() => _guardedWrite(() => _box.put(_consentKey, true));

  Future<void> clear() => _guardedWrite(() => _box.delete(_consentKey));

  Future<void> _guardedWrite(Future<void> Function() operation) async {
    final writer = _operationFence.tryAcquireWriter(_ownerScopeValue);
    if (writer == null) {
      throw const OwnerScopeException(OwnerScopeFailure.deletionQuarantined);
    }
    try {
      writer.assertActive();
      await _beforeWrite?.call();
      writer.assertActive();
      await operation();
      writer.assertActive();
    } finally {
      writer.release();
    }
  }
}
