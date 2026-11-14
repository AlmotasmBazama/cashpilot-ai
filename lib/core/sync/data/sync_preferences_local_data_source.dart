import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../features/auth/application/providers/auth_providers.dart';
import '../../../features/auth/domain/entities/auth_user.dart';
import '../../owner_scope/application/owner_scope_providers.dart';
import '../../owner_scope/domain/owner_scope.dart';
import '../../storage/owner_scoped_storage_keys.dart';
import '../../storage/hive_box_names.dart';
import '../../storage/settings_local_data_source.dart';
import '../../storage/settings_keys.dart';
import '../application/backup_consent_lifecycle.dart';
import '../application/backup_operation_fence.dart';
import 'sync_queue_repository.dart';

final syncPreferencesLocalDataSourceProvider =
    Provider<SyncPreferencesLocalDataSource>((ref) {
      final source = SyncPreferencesLocalDataSource(
        Hive.box<dynamic>(HiveBoxNames.settings),
        operationFence: ref.watch(backupOperationFenceProvider),
        onBackupConsentChanged: (change) {
          final coordinator = BackupConsentLifecycleCoordinator(
            queueRepository: DriftSyncQueueRepository(
              ref.read(requiredScopedAppDatabaseSessionProvider),
            ),
            operationFence: ref.read(backupOperationFenceProvider),
            readSettingsSnapshot: (userId) {
              final ownerScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
                userId,
              );
              final baseCurrencyCode = ref
                  .read(settingsLocalDataSourceProvider)
                  .readOwnerBaseCurrencyCode(ownerScope);
              if (baseCurrencyCode == null) {
                return const <String, dynamic>{};
              }
              return <String, dynamic>{'baseCurrencyCode': baseCurrencyCode};
            },
          );
          return coordinator.apply(
            userId: change.userId,
            enabled: change.enabled,
            generation: change.generation,
          );
        },
      );

      AuthSessionIdentity? repairInFlight;
      AuthSessionIdentity? repairedIdentity;

      void repairForActiveOwner() {
        final user = ref.read(currentAuthUserProvider);
        final session = ref.read(scopedAppDatabaseSessionProvider);
        if (user == null || user.isAnonymous || session == null) {
          return;
        }
        final identity = user.sessionIdentity;
        if (repairInFlight == identity || repairedIdentity == identity) {
          return;
        }
        repairInFlight = identity;
        unawaited(
          source
              .repairAfterStartup(user.uid)
              .then((_) {
                if (!ref.mounted ||
                    !identity.matches(ref.read(currentAuthUserProvider)) ||
                    !identical(
                      session,
                      ref.read(scopedAppDatabaseSessionProvider),
                    )) {
                  if (repairInFlight == identity) {
                    repairInFlight = null;
                  }
                  return;
                }
                // Disabled-backup repair briefly fences the owner while its
                // queue is purged. Reads that started during that fence fail
                // closed and may have cached the transient result. Refresh
                // the scoped-session boundary after the fence opens. The
                // identity marker prevents that deliberate refresh from
                // scheduling the same repair again.
                repairInFlight = null;
                repairedIdentity = identity;
                ref.invalidate(scopedAppDatabaseSessionProvider);
              })
              .catchError((Object _) {
                if (repairInFlight == identity) {
                  repairInFlight = null;
                }
              }),
        );
      }

      ref.listen(scopedAppDatabaseSessionProvider, (_, _) {
        repairForActiveOwner();
      });
      Future<void>.microtask(repairForActiveOwner);
      return source;
    }, name: 'syncPreferencesLocalDataSourceProvider');

typedef BackupConsentChanged =
    Future<BackupConsentLifecycleResult> Function(BackupConsentChange change);
typedef BeforeBackupConsentEnableCommit = Future<void> Function();
typedef BeforeOwnerSyncPreferenceWrite = Future<void> Function();

class BackupConsentChange {
  const BackupConsentChange({
    required this.userId,
    required this.enabled,
    required this.generation,
  });

  final String userId;
  final bool enabled;
  final int generation;
}

class SyncPreferencesLocalDataSource {
  SyncPreferencesLocalDataSource(
    this._box, {
    required BackupOperationFence operationFence,
    BackupConsentChanged? onBackupConsentChanged,
    BeforeBackupConsentEnableCommit? beforeEnableCommit,
    BeforeOwnerSyncPreferenceWrite? beforeOwnerWrite,
  }) : _operationFence = operationFence,
       _onBackupConsentChanged = onBackupConsentChanged,
       _beforeEnableCommit = beforeEnableCommit,
       _beforeOwnerWrite = beforeOwnerWrite;

  final Box<dynamic> _box;
  final BackupOperationFence _operationFence;
  final BackupConsentChanged? _onBackupConsentChanged;
  final BeforeBackupConsentEnableCommit? _beforeEnableCommit;
  final BeforeOwnerSyncPreferenceWrite? _beforeOwnerWrite;
  Future<void> _transitionBarrier = Future<void>.value();

  bool readBackupEnabled(String userId) {
    return _readScoped(SettingsKeys.backupEnabled, userId) == true;
  }

  int readConsentGeneration(String userId) {
    final value = _box.get(_keys(userId).backupConsentGeneration);
    return value is int && value >= 0 ? value : 0;
  }

  bool readInitialSnapshotComplete(String userId) {
    return _box.get(_keys(userId).backupInitialSnapshotComplete) == true;
  }

  Future<void> saveInitialSnapshotComplete(String userId, bool complete) {
    final normalizedUserId = _normalizeUserId(userId);
    return _withOwnerWriter(normalizedUserId, (writer) async {
      await _box.put(
        _keys(normalizedUserId).backupInitialSnapshotComplete,
        complete,
      );
      writer.assertActive();
    });
  }

  Future<void> saveBackupEnabled(String userId, bool enabled) {
    return _serializeTransition(
      () => _saveBackupEnabled(userId: userId, enabled: enabled),
    );
  }

  /// Repairs only incomplete startup states. Disabled consent always purges
  /// its scoped queue; an interrupted enable is rebuilt while consent remains
  /// closed and is reopened only after the initial snapshot is durable.
  Future<void> repairAfterStartup(String userId) {
    return _serializeTransition(() async {
      final normalizedUserId = _normalizeUserId(userId);
      if (!readBackupEnabled(normalizedUserId)) {
        await _applyLifecycle(
          userId: normalizedUserId,
          enabled: false,
          generation: readConsentGeneration(normalizedUserId),
          requiredOutcome: (result) => result.queuePurged,
        );
        return;
      }
      if (!readInitialSnapshotComplete(normalizedUserId)) {
        await _saveBackupEnabled(userId: normalizedUserId, enabled: true);
      }
    });
  }

  Future<void> _saveBackupEnabled({
    required String userId,
    required bool enabled,
  }) async {
    final normalizedUserId = _normalizeUserId(userId);
    final keys = _keys(normalizedUserId);
    final enabledKey = keys.backupEnabled;
    final generationKey = keys.backupConsentGeneration;
    final snapshotKey = keys.backupInitialSnapshotComplete;

    if (enabled) {
      await _withOwnerWriter(normalizedUserId, (writer) async {
        final generation = readConsentGeneration(normalizedUserId) + 1;
        await _writeClosedConsentState(
          userId: normalizedUserId,
          writer: writer,
          enabledKey: enabledKey,
          generationKey: generationKey,
          snapshotKey: snapshotKey,
          generation: generation,
        );
        await _applyLifecycle(
          userId: normalizedUserId,
          enabled: true,
          generation: generation,
          requiredOutcome: (result) => result.snapshotPrepared,
        );
        await _beforeEnableCommit?.call();
        writer.assertActive();
        if (readConsentGeneration(normalizedUserId) != generation) {
          throw StateError('The backup consent generation changed.');
        }
        await _box.put(enabledKey, true);
        writer.assertActive();
      });
      return;
    }

    late final int generation;
    await _withOwnerWriter(normalizedUserId, (writer) async {
      generation = readConsentGeneration(normalizedUserId) + 1;
      await _writeClosedConsentState(
        userId: normalizedUserId,
        writer: writer,
        enabledKey: enabledKey,
        generationKey: generationKey,
        snapshotKey: snapshotKey,
        generation: generation,
      );
    });
    await _applyLifecycle(
      userId: normalizedUserId,
      enabled: false,
      generation: generation,
      requiredOutcome: (result) => result.queuePurged,
    );
  }

  Future<void> _writeClosedConsentState({
    required String userId,
    required BackupWriterLease writer,
    required String enabledKey,
    required String generationKey,
    required String snapshotKey,
    required int generation,
  }) async {
    // Consent closes before any awaited lifecycle transition. Every write is
    // under the same owner lease, so account deletion either cancels it before
    // commit or drains it and clears the resulting keys afterward.
    await _box.put(enabledKey, false);
    writer.assertActive();
    await _box.put(generationKey, generation);
    writer.assertActive();
    await _box.put(snapshotKey, false);
    writer.assertActive();
    await _deleteLegacyRawUidKeys(userId);
    writer.assertActive();
  }

  Future<void> _applyLifecycle({
    required String userId,
    required bool enabled,
    required int generation,
    required bool Function(BackupConsentLifecycleResult result) requiredOutcome,
  }) async {
    final callback = _onBackupConsentChanged;
    if (callback == null) {
      return;
    }
    final result = await callback(
      BackupConsentChange(
        userId: userId,
        enabled: enabled,
        generation: generation,
      ),
    );
    if (!requiredOutcome(result)) {
      throw StateError('The backup consent transition was not completed.');
    }
  }

  Future<void> _serializeTransition(Future<void> Function() operation) {
    final result = _transitionBarrier.then((_) => operation());
    _transitionBarrier = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<T> _withOwnerWriter<T>(
    String userId,
    Future<T> Function(BackupWriterLease writer) operation,
  ) async {
    final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
      userId,
    ).id.value;
    final writer = _operationFence.tryAcquireWriter(scope);
    if (writer == null) {
      throw const OwnerScopeException(OwnerScopeFailure.deletionQuarantined);
    }
    try {
      writer.assertActive();
      await _beforeOwnerWrite?.call();
      writer.assertActive();
      final result = await operation(writer);
      writer.assertActive();
      return result;
    } finally {
      writer.release();
    }
  }

  String _normalizeUserId(String userId) {
    if (userId.isEmpty || userId != userId.trim()) {
      throw ArgumentError.value(
        '<redacted>',
        'userId',
        'A confirmed backup owner is required.',
      );
    }
    OwnerScopeDerivation.fromConfirmedFirebaseUid(userId);
    return userId;
  }

  DateTime? readLastBackupAt(String userId) {
    final value = _readScoped(SettingsKeys.lastBackupAt, userId);
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }

  Future<void> saveLastBackupAt(String userId, DateTime value) async {
    final normalizedUserId = _normalizeUserId(userId);
    await _withOwnerWriter(normalizedUserId, (writer) async {
      await _box.put(
        _keys(normalizedUserId).lastBackupAt,
        value.toUtc().toIso8601String(),
      );
      writer.assertActive();
      await _box.delete(
        _legacyUserKey(SettingsKeys.lastBackupAt, normalizedUserId),
      );
      writer.assertActive();
    });
  }

  String? readSyncDeviceId() {
    final value = _box.get(SettingsKeys.syncDeviceId);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  Future<void> saveSyncDeviceId(String deviceId) {
    return _box.put(SettingsKeys.syncDeviceId, deviceId);
  }

  Object? _readScoped(String key, String userId) {
    final keys = _keys(userId);
    final opaqueKey = switch (key) {
      SettingsKeys.backupEnabled => keys.backupEnabled,
      SettingsKeys.lastBackupAt => keys.lastBackupAt,
      _ => throw ArgumentError('Unsupported owner-scoped sync key.'),
    };
    if (_box.containsKey(opaqueKey)) {
      return _box.get(opaqueKey);
    }
    // One-way compatibility read. The next save removes the raw-UID key.
    return _box.get(_legacyUserKey(key, userId));
  }

  Future<void> _deleteLegacyRawUidKeys(String userId) async {
    await _box.delete(_legacyUserKey(SettingsKeys.backupEnabled, userId));
    await _box.delete(_legacyUserKey(SettingsKeys.lastBackupAt, userId));
    await _box.delete(
      _legacyUserKey(SettingsKeys.backupConsentGeneration, userId),
    );
    await _box.delete(
      _legacyUserKey(SettingsKeys.backupInitialSnapshotComplete, userId),
    );
  }

  OwnerScopedStorageKeys _keys(String userId) =>
      OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: userId,
        ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(userId),
      );

  String _legacyUserKey(String key, String userId) => '${key}_$userId';
}
