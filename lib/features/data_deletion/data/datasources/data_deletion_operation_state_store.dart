import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../../core/storage/owner_scoped_storage_keys.dart';
import '../../domain/entities/data_deletion_operation_context.dart';

final class StoredDataDeletionOperation {
  const StoredDataDeletionOperation({
    required this.operationId,
    required this.startedAtUtc,
    required this.lastCompletedStage,
  });

  final String operationId;
  final DateTime startedAtUtc;
  final DataDeletionStage lastCompletedStage;
}

final class DataDeletionOperationStateCorruptException implements Exception {
  const DataDeletionOperationStateCorruptException();

  @override
  String toString() => 'The account deletion checkpoint is invalid.';
}

final class DataDeletionOperationConflictException implements Exception {
  const DataDeletionOperationConflictException();

  @override
  String toString() => 'A different account deletion operation is active.';
}

final class DataDeletionOperationClaim {
  const DataDeletionOperationClaim({
    required this.operation,
    required this.wasCreated,
  });

  final StoredDataDeletionOperation operation;
  final bool wasCreated;
}

abstract interface class DataDeletionOperationStateStore {
  Future<DataDeletionOperationClaim> claim(
    TrustedDeletionIdentity identity, {
    required String proposedOperationId,
    required DateTime proposedStartedAtUtc,
  });

  Future<StoredDataDeletionOperation?> read(TrustedDeletionIdentity identity);

  Future<void> checkpoint(DataDeletionOperationContext context);

  Future<void> clear(DataDeletionOperationContext context);

  /// Removes only the exact UID-free checkpoint after a separate trusted
  /// secure marker has authorized startup finalization.
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target);
}

/// Stores only an opaque operation id, UTC timestamp, and stage checkpoint.
/// Firebase UIDs, credentials, paths, and financial data are never persisted.
final class HiveDataDeletionOperationStateStore
    implements DataDeletionOperationStateStore {
  HiveDataDeletionOperationStateStore(this._box);

  final Box<dynamic> _box;
  final Map<String, Future<void>> _ownerBarriers = <String, Future<void>>{};

  @override
  Future<DataDeletionOperationClaim> claim(
    TrustedDeletionIdentity identity, {
    required String proposedOperationId,
    required DateTime proposedStartedAtUtc,
  }) {
    final key = _key(identity);
    return _withOwnerLock(key, () async {
      final existing = _readForKey(key);
      if (existing != null) {
        return DataDeletionOperationClaim(
          operation: existing,
          wasCreated: false,
        );
      }
      final operation = StoredDataDeletionOperation(
        operationId: proposedOperationId,
        startedAtUtc: proposedStartedAtUtc.toUtc(),
        lastCompletedStage: DataDeletionStage.captured,
      );
      await _writeForKey(key, operation);
      return DataDeletionOperationClaim(operation: operation, wasCreated: true);
    });
  }

  @override
  Future<StoredDataDeletionOperation?> read(
    TrustedDeletionIdentity identity,
  ) async => _readForKey(_key(identity));

  StoredDataDeletionOperation? _readForKey(String key) {
    final value = _box.get(key);
    if (value == null) {
      return null;
    }
    if (value is! String || value.length > 1024) {
      throw const DataDeletionOperationStateCorruptException();
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        throw const DataDeletionOperationStateCorruptException();
      }
      final operationId = decoded['operationId'];
      final startedAt = decoded['startedAtUtc'];
      final stageName = decoded['lastCompletedStage'];
      if (operationId is! String ||
          !RegExp(r'^[A-Za-z0-9-]{8,80}$').hasMatch(operationId) ||
          startedAt is! String ||
          stageName is! String) {
        throw const DataDeletionOperationStateCorruptException();
      }
      final parsedStartedAt = DateTime.tryParse(startedAt)?.toUtc();
      final stage = DataDeletionStage.values
          .where((candidate) => candidate.name == stageName)
          .firstOrNull;
      if (parsedStartedAt == null ||
          stage == null ||
          stage == DataDeletionStage.authDeleted ||
          stage == DataDeletionStage.aborted) {
        throw const DataDeletionOperationStateCorruptException();
      }
      return StoredDataDeletionOperation(
        operationId: operationId,
        startedAtUtc: parsedStartedAt,
        lastCompletedStage: stage,
      );
    } on DataDeletionOperationStateCorruptException {
      rethrow;
    } on Object {
      throw const DataDeletionOperationStateCorruptException();
    }
  }

  @override
  Future<void> checkpoint(DataDeletionOperationContext context) async {
    if (context.stage == DataDeletionStage.authDeleted ||
        context.stage == DataDeletionStage.aborted) {
      throw const DataDeletionOperationStateCorruptException();
    }
    final key = _key(context.identity);
    await _withOwnerLock(key, () async {
      final existing = _readForKey(key);
      if (existing != null && existing.operationId != context.operationId) {
        throw const DataDeletionOperationConflictException();
      }
      final completedStage =
          existing != null &&
              existing.lastCompletedStage.index > context.stage.index
          ? existing.lastCompletedStage
          : context.stage;
      await _writeForKey(
        key,
        StoredDataDeletionOperation(
          operationId: context.operationId,
          startedAtUtc: context.startedAtUtc,
          lastCompletedStage: completedStage,
        ),
      );
    });
  }

  @override
  Future<void> clear(DataDeletionOperationContext context) async {
    await clearRecovery(context.recoveryTarget);
  }

  @override
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target) async {
    final key = OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
      target.ownerScopeValue,
    ).dataDeletionOperationState;
    await _withOwnerLock(key, () async {
      final existing = _readForKey(key);
      if (existing?.operationId == target.operationId) {
        await _box.delete(key);
      }
    });
  }

  Future<void> _writeForKey(String key, StoredDataDeletionOperation operation) {
    return _box.put(
      key,
      jsonEncode(<String, Object>{
        'version': 1,
        'operationId': operation.operationId,
        'startedAtUtc': operation.startedAtUtc.toUtc().toIso8601String(),
        'lastCompletedStage': operation.lastCompletedStage.name,
      }),
    );
  }

  Future<T> _withOwnerLock<T>(String key, Future<T> Function() operation) {
    final previous = _ownerBarriers[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    late final Future<void> barrier;
    barrier = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _ownerBarriers[key] = barrier;
    barrier.whenComplete(() {
      if (identical(_ownerBarriers[key], barrier)) {
        _ownerBarriers.remove(key);
      }
    });
    return result;
  }

  String _key(TrustedDeletionIdentity identity) =>
      OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        identity.ownerScope,
      ).dataDeletionOperationState;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
