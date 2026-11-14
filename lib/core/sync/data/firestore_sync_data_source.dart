import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/sync_queue_item.dart';
import '../domain/sync_types.dart';

abstract interface class FirestoreSyncDataSource {
  Future<void> uploadItem(String userId, SyncQueueItem item);

  Future<void> updateSyncMetadata({
    required String userId,
    required String deviceId,
    required DateTime syncedAt,
    required int uploadedCount,
    required int failedCount,
    required bool snapshotComplete,
    required int snapshotVersion,
  });
}

class FirestoreSyncWritePlan {
  const FirestoreSyncWritePlan({
    required this.path,
    required this.deleteDocument,
    required this.payload,
    required this.merge,
  });

  final String path;
  final bool deleteDocument;
  final Map<String, dynamic> payload;
  final bool merge;
}

class DefaultFirestoreSyncDataSource implements FirestoreSyncDataSource {
  const DefaultFirestoreSyncDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static String documentPath(
    String userId,
    SyncEntityType entityType,
    String entityId,
  ) {
    final uid = _validatedUserId(userId);
    final collection = switch (entityType) {
      SyncEntityType.account => 'accounts',
      SyncEntityType.transaction => 'transactions',
      SyncEntityType.category => 'categories',
      SyncEntityType.payee => 'payees',
      SyncEntityType.budget => 'budgets',
      SyncEntityType.goal => 'goals',
      SyncEntityType.exchangeRate => 'exchangeRates',
      SyncEntityType.settings => 'settings',
    };
    final id = entityType == SyncEntityType.settings ? 'main' : entityId;
    if (id.trim().isEmpty) {
      throw ArgumentError.value(entityId, 'entityId', 'Entity id is required.');
    }
    return 'users/$uid/$collection/$id';
  }

  @override
  Future<void> uploadItem(String userId, SyncQueueItem item) async {
    final plan = writePlan(userId, item);
    final reference = _firestore.doc(plan.path);
    if (plan.deleteDocument) {
      await reference.delete();
      return;
    }
    await reference.set(plan.payload, SetOptions(merge: plan.merge));
  }

  static FirestoreSyncWritePlan writePlan(
    String userId,
    SyncQueueItem item, {
    DateTime? now,
  }) {
    final path = documentPath(userId, item.entityType, item.entityId);
    if (item.operation == SyncOperationType.delete) {
      return FirestoreSyncWritePlan(
        path: path,
        deleteDocument: true,
        payload: const <String, dynamic>{},
        merge: false,
      );
    }
    final decoded = jsonDecode(item.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Sync payload must be a JSON object.');
    }
    final backedUpAt = (now ?? DateTime.now()).toUtc().toIso8601String();
    final payload = <String, dynamic>{
      ...decoded,
      'id': item.entityId,
      'isDeleted': false,
      'backupOperation': item.operation.name,
      'backedUpAt': backedUpAt,
    };
    return FirestoreSyncWritePlan(
      path: path,
      deleteDocument: false,
      payload: payload,
      // Full replacement also clears fields removed by later schema versions.
      merge: false,
    );
  }

  @override
  Future<void> updateSyncMetadata({
    required String userId,
    required String deviceId,
    required DateTime syncedAt,
    required int uploadedCount,
    required int failedCount,
    required bool snapshotComplete,
    required int snapshotVersion,
  }) {
    final uid = _validatedUserId(userId);
    if (deviceId.trim().isEmpty) {
      throw ArgumentError('User and device ids are required.');
    }
    return _firestore.doc('users/$uid/syncMetadata/$deviceId').set({
      'deviceId': deviceId,
      'lastBackupAt': syncedAt.toUtc().toIso8601String(),
      'uploadedCount': uploadedCount,
      'failedCount': failedCount,
      'mode': 'backupOnly',
      'restoreSupported': false,
      'snapshotComplete': snapshotComplete,
      'snapshotVersion': snapshotVersion,
    }, SetOptions(merge: true));
  }

  static String _validatedUserId(String userId) {
    if (userId.isEmpty ||
        userId != userId.trim() ||
        utf8.encode(userId).length > 128 ||
        userId.contains('/') ||
        userId == '.' ||
        userId == '..') {
      throw ArgumentError.value(
        '<redacted>',
        'userId',
        'A canonical document-safe user id is required.',
      );
    }
    return userId;
  }
}
