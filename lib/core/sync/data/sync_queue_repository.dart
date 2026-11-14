import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../owner_scope/application/scoped_app_database_session.dart';
import '../../owner_scope/domain/owner_scope.dart';
import '../domain/sync_queue_item.dart';
import '../domain/sync_types.dart';
import 'legacy_sync_queue_migration.dart';

abstract interface class SyncQueueRepository {
  String get ownerScopeValue;

  Future<void> enqueue(SyncQueueItem item);

  Future<List<SyncQueueItem>> getPending();

  Stream<SyncQueueStats> watchStats();

  bool matchesConfirmedRemoteOwner(String firebaseUid);

  /// True only while this repository is still bound to the exact live owner
  /// session that created it. A logout/re-login creates a new session epoch,
  /// even when Firebase returns the same UID.
  bool isActiveForConfirmedRemoteOwner(String firebaseUid);

  Future<SyncReconciliationResult> reconcileDirtyState({
    required bool forceFull,
    required DateTime reconciledAt,
  });

  Future<void> purgeAll({String? fencedOperationId});

  Future<SyncUploadAttempt?> markAttempt(
    SyncQueueItem item,
    DateTime attemptedAt,
  );

  Future<bool> markCompleted(SyncUploadAttempt attempt);

  Future<bool> markFailed(
    SyncUploadAttempt attempt,
    String error,
    DateTime failedAt,
  );

  Future<void> retryFailed(DateTime updatedAt);
}

class DriftSyncQueueRepository implements SyncQueueRepository {
  DriftSyncQueueRepository(this._session)
    : _boundScope = _session.confirmedScope;

  static const _minimalPayload = '{}';
  static const _settingsAllowlist = <String>{
    'backupEnabled',
    'backupMode',
    'restoreSupported',
    'snapshotVersion',
    'baseCurrencyCode',
    'updatedAt',
  };

  final ScopedAppDatabaseSession _session;
  final ConfirmedOwnerScope _boundScope;
  AppDatabase get _database => _session.database;
  String get _scope => _boundScope.id.value;

  @override
  String get ownerScopeValue => _scope;

  @override
  bool matchesConfirmedRemoteOwner(String firebaseUid) {
    final derived = OwnerScopeDerivation.fromConfirmedFirebaseUid(firebaseUid);
    return derived.id == _boundScope.id;
  }

  @override
  bool isActiveForConfirmedRemoteOwner(String firebaseUid) {
    return _session.isActive && matchesConfirmedRemoteOwner(firebaseUid);
  }

  @override
  Future<void> enqueue(SyncQueueItem item) {
    if (item.status != SyncStatus.pending) {
      throw ArgumentError.value(
        item.status,
        'item.status',
        'New queue items must be pending.',
      );
    }
    if (item.ownerScopeId != _scope) {
      throw const OwnerScopeException(OwnerScopeFailure.activeScopeChanged);
    }
    final storedPayload = _payloadForStorage(item);
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        _session.assertActive();
        final activeQuery = _database.select(_database.syncQueue)
          ..where(
            (row) =>
                row.ownerScopeId.equals(_scope) &
                row.entityType.equals(item.entityType.name) &
                row.entityId.equals(item.entityId),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.createdAt),
            (row) => OrderingTerm.asc(row.id),
          ]);
        final active = await activeQuery.get();
        if (active.isEmpty) {
          await _insert(item.copyWith(payloadJson: storedPayload));
          return;
        }

        final canonical = active.first;
        await _writePending(
          id: canonical.id,
          operation: item.operation,
          payloadJson: storedPayload,
          updatedAt: item.updatedAt,
        );
        final duplicateIds = active.skip(1).map((row) => row.id).toList();
        if (duplicateIds.isNotEmpty) {
          await (_database.delete(_database.syncQueue)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.isIn(duplicateIds),
              ))
              .go();
        }
      }),
    );
  }

  String _payloadForStorage(SyncQueueItem item) {
    if (item.operation == SyncOperationType.delete ||
        item.entityType != SyncEntityType.settings) {
      return _minimalPayload;
    }
    return jsonEncode(_sanitizedSettings(item.payloadJson));
  }

  Map<String, dynamic> _sanitizedSettings(String payloadJson) {
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

  Future<void> _insert(SyncQueueItem item) {
    return _database
        .into(_database.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: item.id,
            ownerScopeId: Value(_scope),
            // owner_user_id is a legacy physical column. It intentionally stores
            // the same opaque local scope until a future schema removal.
            ownerUserId: _scope,
            entityType: item.entityType.name,
            entityId: item.entityId,
            operation: item.operation.name,
            payloadJson: item.payloadJson,
            status: Value(item.status.name),
            attemptCount: Value(item.attemptCount),
            lastError: Value(item.lastError),
            createdAt: item.createdAt.toUtc(),
            updatedAt: item.updatedAt.toUtc(),
            lastAttemptAt: Value(item.lastAttemptAt?.toUtc()),
          ),
        );
  }

  Future<void> _writePending({
    required String id,
    required SyncOperationType operation,
    required String payloadJson,
    required DateTime updatedAt,
  }) {
    return (_database.update(_database.syncQueue)
          ..where((row) => row.ownerScopeId.equals(_scope) & row.id.equals(id)))
        .write(
          SyncQueueCompanion(
            ownerUserId: Value(_scope),
            operation: Value(operation.name),
            payloadJson: Value(payloadJson),
            status: Value(SyncStatus.pending.name),
            attemptCount: const Value(0),
            lastError: const Value(null),
            lastAttemptAt: const Value(null),
            updatedAt: Value(updatedAt.toUtc()),
          ),
        );
  }

  @override
  Future<SyncReconciliationResult> reconcileDirtyState({
    required bool forceFull,
    required DateTime reconciledAt,
  }) {
    final at = reconciledAt.toUtc();
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        _session.assertActive();
        await LegacySyncQueueMigration.runForScope(
          _database,
          syncQueueTable: _database.syncQueue,
          ownerScopeValue: _scope,
        );
        final documents = await _loadDocuments();
        var rows =
            await (_database.select(_database.syncQueue)
                  ..where((row) => row.ownerScopeId.equals(_scope))
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.createdAt),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();

        // Remove sensitive legacy outbox content before using it as the durable
        // dirty manifest. Only safe settings are retained while pending.
        for (final row in rows) {
          if (row.status == SyncStatus.deleted.name) {
            await (_database.delete(_database.syncQueue)..where(
                  (item) =>
                      item.ownerScopeId.equals(_scope) & item.id.equals(row.id),
                ))
                .go();
            continue;
          }
          final operation = SyncOperationType.values.byName(row.operation);
          final entityType = SyncEntityType.values.byName(row.entityType);
          final safePayload = row.status == SyncStatus.synced.name
              ? _sanitizedManifest(row.payloadJson)
              : operation == SyncOperationType.upsert &&
                    entityType == SyncEntityType.settings
              ? jsonEncode(_sanitizedSettings(row.payloadJson))
              : _minimalPayload;
          if (row.ownerUserId != _scope || row.payloadJson != safePayload) {
            await (_database.update(_database.syncQueue)..where(
                  (item) =>
                      item.ownerScopeId.equals(_scope) & item.id.equals(row.id),
                ))
                .write(
                  SyncQueueCompanion(
                    ownerUserId: Value(_scope),
                    payloadJson: Value(safePayload),
                  ),
                );
          }
        }
        rows =
            await (_database.select(_database.syncQueue)
                  ..where((row) => row.ownerScopeId.equals(_scope))
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.createdAt),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();

        final byEntity = <String, SyncQueueRow>{};
        for (final row in rows) {
          final key = _entityKey(
            SyncEntityType.values.byName(row.entityType),
            row.entityId,
          );
          final previous = byEntity[key];
          if (previous == null) {
            byEntity[key] = row;
            continue;
          }
          final preferCurrent =
              previous.status == SyncStatus.synced.name &&
              row.status != SyncStatus.synced.name;
          final retained = preferCurrent ? row : previous;
          final removed = preferCurrent ? previous : row;
          byEntity[key] = retained;
          await (_database.delete(_database.syncQueue)..where(
                (item) =>
                    item.ownerScopeId.equals(_scope) &
                    item.id.equals(removed.id),
              ))
              .go();
        }

        var queuedUpserts = 0;
        var queuedDeletes = 0;
        for (final document in documents.values) {
          final key = _entityKey(document.entityType, document.entityId);
          final existing = byEntity[key];
          if (existing == null) {
            await _insert(
              SyncQueueItem(
                id: const Uuid().v7(),
                ownerScopeId: _scope,
                entityType: document.entityType,
                entityId: document.entityId,
                operation: SyncOperationType.upsert,
                payloadJson: _minimalPayload,
                status: SyncStatus.pending,
                attemptCount: 0,
                createdAt: at,
                updatedAt: at,
              ),
            );
            queuedUpserts++;
            continue;
          }
          final operation = SyncOperationType.values.byName(existing.operation);
          final status = SyncStatus.values.byName(existing.status);
          final needsRepair =
              operation == SyncOperationType.delete ||
              (status == SyncStatus.synced &&
                  (forceFull ||
                      _manifestFingerprint(existing.payloadJson) !=
                          _documentFingerprint(document.payload)));
          if (needsRepair) {
            await _writePending(
              id: existing.id,
              operation: SyncOperationType.upsert,
              payloadJson: _minimalPayload,
              updatedAt: at,
            );
            queuedUpserts++;
          }
        }

        for (final entry in byEntity.entries) {
          final row = entry.value;
          final entityType = SyncEntityType.values.byName(row.entityType);
          if (entityType == SyncEntityType.settings ||
              documents.containsKey(entry.key)) {
            continue;
          }
          final operation = SyncOperationType.values.byName(row.operation);
          final status = SyncStatus.values.byName(row.status);
          if (operation == SyncOperationType.delete &&
              status != SyncStatus.synced) {
            continue;
          }
          await _writePending(
            id: row.id,
            operation: SyncOperationType.delete,
            payloadJson: _minimalPayload,
            updatedAt: at,
          );
          queuedDeletes++;
        }

        return SyncReconciliationResult(
          queuedUpserts: queuedUpserts,
          queuedDeletes: queuedDeletes,
        );
      }),
    );
  }

  Future<SyncQueueItem> _materializeForUpload(SyncQueueItem item) async {
    _session.assertActive();
    if (item.ownerScopeId != _scope) {
      throw const OwnerScopeException(OwnerScopeFailure.activeScopeChanged);
    }
    if (item.operation == SyncOperationType.delete) {
      return item.copyWith(payloadJson: _minimalPayload);
    }
    if (item.entityType == SyncEntityType.settings) {
      return item.copyWith(
        payloadJson: jsonEncode(_sanitizedSettings(item.payloadJson)),
      );
    }
    final documents = await _loadDocuments();
    final document = documents[_entityKey(item.entityType, item.entityId)];
    _session.assertActive();
    if (document == null) {
      return item.copyWith(
        operation: SyncOperationType.delete,
        payloadJson: _minimalPayload,
      );
    }
    return item.copyWith(payloadJson: jsonEncode(document.payload));
  }

  Future<Map<String, _BackupDocument>> _loadDocuments() async {
    final documents = <String, _BackupDocument>{};
    void add(SyncEntityType type, String id, Map<String, dynamic> payload) {
      payload.remove('ownerScopeId');
      documents[_entityKey(type, id)] = _BackupDocument(
        entityType: type,
        entityId: id,
        payload: payload,
      );
    }

    final accounts = await (_database.select(
      _database.accounts,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    for (final row in accounts) {
      add(SyncEntityType.account, row.id, row.toJson());
    }

    final transactions = await (_database.select(
      _database.transactions,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    for (final row in transactions) {
      final payload = row.toJson()..remove('transferPayloadFingerprint');
      add(SyncEntityType.transaction, row.id, payload);
    }

    final categories = await (_database.select(
      _database.categories,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    for (final row in categories) {
      add(SyncEntityType.category, row.id, row.toJson());
    }

    final payees = await (_database.select(
      _database.payees,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    for (final row in payees) {
      add(SyncEntityType.payee, row.id, row.toJson());
    }

    final budgets = await (_database.select(
      _database.budgets,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    for (final row in budgets) {
      add(SyncEntityType.budget, row.id, row.toJson());
    }

    final contributions =
        await (_database.select(_database.goalContributions)
              ..where((row) => row.ownerScopeId.equals(_scope))
              ..orderBy([
                (row) => OrderingTerm.asc(row.createdAt),
                (row) => OrderingTerm.asc(row.id),
              ]))
            .get();
    final contributionsByGoal = <String, List<Map<String, dynamic>>>{};
    for (final row in contributions) {
      final payload = row.toJson()..remove('ownerScopeId');
      contributionsByGoal.putIfAbsent(row.goalId, () => []).add(payload);
    }
    final goals = await (_database.select(
      _database.goals,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    for (final row in goals) {
      final payload = row.toJson();
      payload['contributions'] = contributionsByGoal[row.id] ?? const [];
      add(SyncEntityType.goal, row.id, payload);
    }

    final exchangeRates = await (_database.select(
      _database.exchangeRates,
    )..where((row) => row.ownerScopeId.equals(_scope))).get();
    for (final row in exchangeRates) {
      add(SyncEntityType.exchangeRate, row.id, row.toJson());
    }
    _session.assertActive();
    return documents;
  }

  String _entityKey(SyncEntityType type, String entityId) =>
      '${type.name}\u0000$entityId';

  @override
  Future<List<SyncQueueItem>> getPending() async {
    _session.assertActive();
    final query = _database.select(_database.syncQueue)
      ..where(
        (row) =>
            row.ownerScopeId.equals(_scope) &
            row.status.equals(SyncStatus.pending.name),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    final rows = await query.get();
    _session.assertActive();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Stream<SyncQueueStats> watchStats() {
    final query = _database.select(_database.syncQueue)
      ..where((row) => row.ownerScopeId.equals(_scope));
    return _session.guardStream(query.watch()).map((rows) {
      var pendingCount = 0;
      var failedCount = 0;
      for (final row in rows) {
        if (row.status == SyncStatus.pending.name) {
          pendingCount++;
        } else if (row.status == SyncStatus.failed.name) {
          failedCount++;
        }
      }
      return SyncQueueStats(
        pendingCount: pendingCount,
        failedCount: failedCount,
      );
    });
  }

  @override
  Future<void> purgeAll({String? fencedOperationId}) async {
    if (fencedOperationId == null) {
      await _session.runGuardedWrite(() => _purgeAllWith(_database));
      return;
    }
    await _purgeAllWith(
      _session.deletionDatabase(operationId: fencedOperationId),
    );
  }

  Future<void> _purgeAllWith(AppDatabase database) async {
    await database.transaction(() async {
      await (database.delete(
        database.syncQueue,
      )..where((row) => row.ownerScopeId.equals(_scope))).go();
      final countExpression = database.syncQueue.id.count();
      final remaining =
          await (database.selectOnly(database.syncQueue)
                ..addColumns(<Expression<Object>>[countExpression])
                ..where(database.syncQueue.ownerScopeId.equals(_scope)))
              .map((row) => row.read(countExpression) ?? 0)
              .getSingle();
      if (remaining != 0) {
        throw StateError('The owner backup queue could not be purged.');
      }
    });
  }

  @override
  Future<SyncUploadAttempt?> markAttempt(
    SyncQueueItem item,
    DateTime attemptedAt,
  ) {
    if (item.ownerScopeId != _scope) {
      throw const OwnerScopeException(OwnerScopeFailure.activeScopeChanged);
    }
    return _session.runGuardedWrite(
      () => _database.transaction(() async {
        _session.assertActive();
        final row =
            await (_database.select(_database.syncQueue)..where(
                  (candidate) =>
                      candidate.ownerScopeId.equals(_scope) &
                      candidate.id.equals(item.id) &
                      candidate.status.equals(SyncStatus.pending.name),
                ))
                .getSingleOrNull();
        if (row == null) return null;

        // Materialize while the queue revision and local financial projection
        // share one database transaction. A subsequent local mutation will
        // reset the token through _writePending and make completion a no-op.
        final uploadItem = await _materializeForUpload(_toDomain(row));
        final token = 'attempt:${const Uuid().v7()}';
        final revision = row.attemptCount + 1;
        final at = attemptedAt.toUtc();
        final changed =
            await (_database.update(_database.syncQueue)..where((candidate) {
                  final samePreviousError = row.lastError == null
                      ? candidate.lastError.isNull()
                      : candidate.lastError.equals(row.lastError!);
                  return candidate.ownerScopeId.equals(_scope) &
                      candidate.id.equals(row.id) &
                      candidate.status.equals(SyncStatus.pending.name) &
                      candidate.attemptCount.equals(row.attemptCount) &
                      samePreviousError;
                }))
                .write(
                  SyncQueueCompanion(
                    attemptCount: Value(revision),
                    lastAttemptAt: Value(at),
                    updatedAt: Value(at),
                    lastError: Value(token),
                  ),
                );
        if (changed != 1) return null;
        return SyncUploadAttempt(
          uploadItem: uploadItem,
          token: token,
          revision: revision,
          attemptedAt: at,
          uploadedProjectionFingerprint:
              uploadItem.operation == SyncOperationType.upsert
              ? _projectionFingerprint(uploadItem.payloadJson)
              : null,
        );
      }),
    );
  }

  @override
  Future<bool> markCompleted(SyncUploadAttempt attempt) {
    _assertAttemptOwner(attempt);
    return _session.runGuardedWrite(() async {
      final uploadItem = attempt.uploadItem;
      if (uploadItem.operation == SyncOperationType.delete) {
        final deleted =
            await (_database.delete(_database.syncQueue)..where(
                  (item) =>
                      item.ownerScopeId.equals(_scope) &
                      item.id.equals(attempt.uploadItem.id) &
                      item.status.equals(SyncStatus.pending.name) &
                      item.attemptCount.equals(attempt.revision) &
                      item.lastError.equals(attempt.token),
                ))
                .go();
        return deleted == 1;
      }
      final fingerprint = attempt.uploadedProjectionFingerprint;
      if (fingerprint == null) {
        throw StateError('An upsert attempt requires an upload fingerprint.');
      }
      final changed =
          await (_database.update(_database.syncQueue)..where(
                (item) =>
                    item.ownerScopeId.equals(_scope) &
                    item.id.equals(attempt.uploadItem.id) &
                    item.status.equals(SyncStatus.pending.name) &
                    item.attemptCount.equals(attempt.revision) &
                    item.lastError.equals(attempt.token),
              ))
              .write(
                SyncQueueCompanion(
                  ownerUserId: Value(_scope),
                  payloadJson: Value(
                    jsonEncode(<String, dynamic>{
                      'fingerprint': fingerprint,
                      'version': 1,
                    }),
                  ),
                  status: Value(SyncStatus.synced.name),
                  lastError: const Value(null),
                  updatedAt: Value(DateTime.now().toUtc()),
                ),
              );
      return changed == 1;
    });
  }

  @override
  Future<bool> markFailed(
    SyncUploadAttempt attempt,
    String error,
    DateTime failedAt,
  ) {
    _assertAttemptOwner(attempt);
    return _session.runGuardedWrite(() async {
      final uploadItem = attempt.uploadItem;
      final retainSafeSettings =
          uploadItem.entityType == SyncEntityType.settings &&
          uploadItem.operation == SyncOperationType.upsert;
      final changed =
          await (_database.update(_database.syncQueue)..where(
                (item) =>
                    item.ownerScopeId.equals(_scope) &
                    item.id.equals(attempt.uploadItem.id) &
                    item.status.equals(SyncStatus.pending.name) &
                    item.attemptCount.equals(attempt.revision) &
                    item.lastError.equals(attempt.token),
              ))
              .write(
                SyncQueueCompanion(
                  payloadJson: Value(
                    retainSafeSettings
                        ? jsonEncode(_sanitizedSettings(uploadItem.payloadJson))
                        : _minimalPayload,
                  ),
                  status: Value(SyncStatus.failed.name),
                  // Error strings can echo private remote payloads. Persist
                  // only a stable class while returning details in-memory.
                  lastError: const Value('sync_upload_failed'),
                  updatedAt: Value(failedAt.toUtc()),
                ),
              );
      return changed == 1;
    });
  }

  void _assertAttemptOwner(SyncUploadAttempt attempt) {
    if (attempt.uploadItem.ownerScopeId != _scope ||
        !RegExp(r'^attempt:[0-9a-f-]{36}$').hasMatch(attempt.token) ||
        attempt.revision <= 0) {
      throw const OwnerScopeException(OwnerScopeFailure.activeScopeChanged);
    }
  }

  @override
  Future<void> retryFailed(DateTime updatedAt) {
    return _session.runGuardedWrite(
      () =>
          (_database.update(_database.syncQueue)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.status.equals(SyncStatus.failed.name),
              ))
              .write(
                SyncQueueCompanion(
                  status: Value(SyncStatus.pending.name),
                  lastError: const Value(null),
                  updatedAt: Value(updatedAt.toUtc()),
                ),
              ),
    );
  }

  SyncQueueItem _toDomain(SyncQueueRow row) => SyncQueueItem(
    id: row.id,
    ownerScopeId: row.ownerScopeId ?? _scope,
    entityType: SyncEntityType.values.byName(row.entityType),
    entityId: row.entityId,
    operation: SyncOperationType.values.byName(row.operation),
    payloadJson: row.payloadJson,
    status: SyncStatus.values.byName(row.status),
    attemptCount: row.attemptCount,
    lastError: row.lastError,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
    lastAttemptAt: row.lastAttemptAt?.toUtc(),
  );

  String _documentFingerprint(Map<String, dynamic> payload) =>
      sha256.convert(utf8.encode(jsonEncode(payload))).toString();

  String _projectionFingerprint(String payloadJson) =>
      sha256.convert(utf8.encode(payloadJson)).toString();

  String? _manifestFingerprint(String payloadJson) {
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

  String _sanitizedManifest(String payloadJson) {
    final fingerprint = _manifestFingerprint(payloadJson);
    return fingerprint == null
        ? _minimalPayload
        : jsonEncode(<String, dynamic>{
            'fingerprint': fingerprint,
            'version': 1,
          });
  }
}

class _BackupDocument {
  const _BackupDocument({
    required this.entityType,
    required this.entityId,
    required this.payload,
  });

  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic> payload;
}
