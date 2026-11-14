import 'dart:convert';

import 'package:drift/drift.dart';

import '../../owner_scope/domain/owner_scope.dart';
import '../domain/sync_types.dart';

/// Converts the v14 outbox owner UID into the same opaque local scope used by
/// current sessions. The migration is deliberately independent of the active
/// owner: migrating while B is signed in must not claim A's tombstones for B.
abstract final class LegacySyncQueueMigration {
  static const _minimalPayload = '{}';
  static const _settingsAllowlist = <String>{
    'backupEnabled',
    'backupMode',
    'restoreSupported',
    'snapshotVersion',
    'baseCurrencyCode',
    'updatedAt',
  };

  static Future<int> runGlobally(
    GeneratedDatabase database, {
    required TableInfo<Table, Object?> syncQueueTable,
  }) => _run(database, syncQueueTable: syncQueueTable);

  static Future<int> runForScope(
    GeneratedDatabase database, {
    required TableInfo<Table, Object?> syncQueueTable,
    required String ownerScopeValue,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(ownerScopeValue)) {
      throw StateError('A valid opaque owner scope is required.');
    }
    return _run(
      database,
      syncQueueTable: syncQueueTable,
      ownerScopeValue: ownerScopeValue,
    );
  }

  static Future<int> _run(
    GeneratedDatabase database, {
    required TableInfo<Table, Object?> syncQueueTable,
    String? ownerScopeValue,
  }) async {
    final rows = await database.customSelect('''
      SELECT id, owner_user_id, entity_type, operation, payload_json, status
      FROM sync_queue
      WHERE owner_scope_id IS NULL
      ORDER BY created_at, id
    ''').get();
    var migratedCount = 0;
    for (final row in rows) {
      final id = row.read<String>('id');
      final legacyOwnerUid = row.read<String>('owner_user_id');
      final entityType = row.read<String>('entity_type');
      final operation = row.read<String>('operation');
      final status = row.read<String>('status');
      final payloadJson = row.read<String>('payload_json');
      final isKnownEntity = SyncEntityType.values.any(
        (value) => value.name == entityType,
      );
      final isKnownOperation = SyncOperationType.values.any(
        (value) => value.name == operation,
      );
      final isKnownStatus = SyncStatus.values.any(
        (value) => value.name == status,
      );

      ConfirmedOwnerScope legacyOwnerScope;
      try {
        legacyOwnerScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          legacyOwnerUid,
        );
      } on Object {
        // Never normalize a malformed raw UID into another owner's scope.
        // Quarantine-by-deletion is deterministic and retains no raw identity.
        migratedCount += await _deleteMalformed(
          database,
          syncQueueTable: syncQueueTable,
          id: id,
        );
        continue;
      }
      final opaqueScope = legacyOwnerScope.id.value;
      // Runtime reconciliation is bound to one live owner writer lease. It
      // must never mutate another owner's still-legacy row (especially while
      // that owner is under a deletion fence).
      if (ownerScopeValue != null && opaqueScope != ownerScopeValue) {
        continue;
      }

      // A malformed row cannot be safely addressed remotely. Remove it rather
      // than retaining a raw owner identifier or private legacy payload.
      if (!isKnownEntity ||
          !isKnownOperation ||
          !isKnownStatus ||
          status == SyncStatus.deleted.name) {
        migratedCount += await _deleteMalformed(
          database,
          syncQueueTable: syncQueueTable,
          id: id,
        );
        continue;
      }

      final safePayload = _safePayload(
        entityType: entityType,
        operation: operation,
        status: status,
        payloadJson: payloadJson,
      );
      final safeError = status == SyncStatus.failed.name
          ? 'sync_upload_failed'
          : null;
      migratedCount += await database.customUpdate(
        '''UPDATE sync_queue
           SET owner_scope_id = ?, owner_user_id = ?, payload_json = ?,
               last_error = ?
           WHERE id = ? AND owner_scope_id IS NULL''',
        variables: <Variable<Object>>[
          Variable<String>(opaqueScope),
          Variable<String>(opaqueScope),
          Variable<String>(safePayload),
          Variable<String>(safeError),
          Variable<String>(id),
        ],
        updates: <TableInfo<Table, Object?>>{syncQueueTable},
      );
    }
    return migratedCount;
  }

  static Future<int> _deleteMalformed(
    GeneratedDatabase database, {
    required TableInfo<Table, Object?> syncQueueTable,
    required String id,
  }) {
    return database.customUpdate(
      'DELETE FROM sync_queue WHERE id = ? AND owner_scope_id IS NULL',
      variables: <Variable<Object>>[Variable<String>(id)],
      updates: <TableInfo<Table, Object?>>{syncQueueTable},
    );
  }

  static String _safePayload({
    required String entityType,
    required String operation,
    required String status,
    required String payloadJson,
  }) {
    if (status == SyncStatus.synced.name) {
      final fingerprint = _manifestFingerprint(payloadJson);
      return fingerprint == null
          ? _minimalPayload
          : jsonEncode(<String, Object>{
              'fingerprint': fingerprint,
              'version': 1,
            });
    }
    if (operation == SyncOperationType.upsert.name &&
        entityType == SyncEntityType.settings.name) {
      return jsonEncode(_sanitizedSettings(payloadJson));
    }
    return _minimalPayload;
  }

  static Map<String, dynamic> _sanitizedSettings(String payloadJson) {
    Object? decoded;
    try {
      decoded = jsonDecode(payloadJson);
    } on FormatException {
      return <String, dynamic>{};
    }
    if (decoded is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{
      for (final entry in decoded.entries)
        if (_settingsAllowlist.contains(entry.key)) entry.key: entry.value,
    };
  }

  static String? _manifestFingerprint(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['fingerprint'];
        if (value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
          return value;
        }
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
