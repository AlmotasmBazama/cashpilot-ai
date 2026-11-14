import 'package:hive/hive.dart';

import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../domain/entities/data_deletion_operation_context.dart';

abstract interface class DeletionPreferencesDataSource {
  Future<void> clearForIdentity(TrustedDeletionIdentity identity);
}

class HiveDeletionPreferencesDataSource
    implements DeletionPreferencesDataSource {
  const HiveDeletionPreferencesDataSource(this._box);

  final Box<dynamic> _box;

  @override
  Future<void> clearForIdentity(TrustedDeletionIdentity identity) {
    final keys = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
      firebaseUid: identity.userId,
      ownerScope: identity.ownerScope,
    );
    return _box.deleteAll(<String>[
      ...keys.accountDeletionPreferenceKeys,
      ...keys.legacyRawUidSyncPreferenceKeys,
    ]);
  }
}
