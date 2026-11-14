import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../../storage/owner_scoped_storage_keys.dart';
import '../../storage/settings_keys.dart';

abstract interface class OwnerDeletionQuarantineStore {
  Map<String, String> restore();

  Future<void> hold({
    required String ownerScopeValue,
    required String operationId,
  });

  Future<void> release({
    required String ownerScopeValue,
    required String operationId,
  });
}

final class OwnerDeletionQuarantineCorruptException implements Exception {
  const OwnerDeletionQuarantineCorruptException();

  @override
  String toString() => 'The account-deletion quarantine is invalid.';
}

final class OwnerDeletionQuarantineConflictException implements Exception {
  const OwnerDeletionQuarantineConflictException();

  @override
  String toString() =>
      'A different account-deletion operation owns this quarantine.';
}

final class OwnerDeletionQuarantinePostconditionException implements Exception {
  const OwnerDeletionQuarantinePostconditionException();

  @override
  String toString() =>
      'The account-deletion quarantine update could not be verified.';
}

/// Durable, UID-free local marker restored synchronously before provider
/// writers can acquire a lease. Invalid markers remain quarantined rather than
/// being interpreted as permission to write.
final class HiveOwnerDeletionQuarantineStore
    implements OwnerDeletionQuarantineStore {
  const HiveOwnerDeletionQuarantineStore(this._box);

  static const _corruptOperation = 'corrupt-deletion-quarantine';
  static final Expando<Map<String, Future<void>>> _boxKeyBarriers =
      Expando<Map<String, Future<void>>>('account-deletion-quarantine-locks');
  final Box<dynamic> _box;

  @override
  Map<String, String> restore() {
    final restored = <String, String>{};
    for (final key in _box.keys.whereType<String>()) {
      if (!key.startsWith(SettingsKeys.ownerDeletionQuarantinePrefix)) {
        continue;
      }
      final scope = key.substring(
        SettingsKeys.ownerDeletionQuarantinePrefix.length,
      );
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(scope)) {
        // A recognized quarantine key with unusable coordinates cannot be
        // mapped to a single owner fence. Treating it as absent would reopen
        // every writer even though a deletion may still be active.
        throw const OwnerDeletionQuarantineCorruptException();
      }
      final value = _box.get(key);
      restored[scope] = _decodeOperation(value) ?? _corruptOperation;
    }
    return Map.unmodifiable(restored);
  }

  @override
  Future<void> hold({
    required String ownerScopeValue,
    required String operationId,
  }) async {
    final key = _key(ownerScopeValue);
    await _withKeyLock(key, () async {
      final existing = _operationAt(key);
      if (existing != null && existing != operationId) {
        throw const OwnerDeletionQuarantineConflictException();
      }
      if (existing == operationId) {
        return;
      }
      await _box.put(
        key,
        jsonEncode(<String, Object>{'version': 1, 'operationId': operationId}),
      );
      if (_operationAt(key) != operationId) {
        throw const OwnerDeletionQuarantinePostconditionException();
      }
    });
  }

  @override
  Future<void> release({
    required String ownerScopeValue,
    required String operationId,
  }) async {
    final key = _key(ownerScopeValue);
    await _withKeyLock(key, () async {
      if (_operationAt(key) != operationId) {
        throw const OwnerDeletionQuarantineConflictException();
      }
      await _box.delete(key);
      if (_box.containsKey(key)) {
        throw const OwnerDeletionQuarantinePostconditionException();
      }
    });
  }

  String? _operationAt(String key) {
    if (!_box.containsKey(key)) {
      return null;
    }
    return _decodeOperation(_box.get(key)) ?? _corruptOperation;
  }

  static String? _decodeOperation(Object? value) {
    if (value is! String || value.length > 1024) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      final operationId = decoded is Map<String, dynamic>
          ? decoded['operationId']
          : null;
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != 1 ||
          operationId is! String ||
          !RegExp(r'^[A-Za-z0-9-]{8,80}$').hasMatch(operationId)) {
        return null;
      }
      return operationId;
    } on Object {
      return null;
    }
  }

  Future<T> _withKeyLock<T>(String key, Future<T> Function() action) {
    final barriers = _boxKeyBarriers[_box] ??= <String, Future<void>>{};
    final previous = barriers[key] ?? Future<void>.value();
    late final Future<void> barrier;
    final operation = previous.then<T>(
      (_) => action(),
      onError: (Object _, StackTrace _) => action(),
    );
    barrier = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    barriers[key] = barrier;
    return operation.whenComplete(() {
      if (identical(barriers[key], barrier)) {
        barriers.remove(key);
      }
    });
  }

  String _key(String ownerScopeValue) =>
      OwnerScopedStorageKeys.fromCanonicalOwnerScopeValue(
        ownerScopeValue,
      ).ownerDeletionQuarantine;
}
