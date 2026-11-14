import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/data_deletion_operation_context.dart';

const accountDeletionSessionProofHeader = 'X-Cashpilot-Deletion-Session';

/// A canonical 256-bit bearer proof for one account-deletion operation.
///
/// The raw value must never be logged, persisted outside platform secure
/// storage, or included in diagnostics. It is intentionally redacted from
/// [toString].
final class AccountDeletionSessionProof {
  AccountDeletionSessionProof._(this.headerValue);

  factory AccountDeletionSessionProof.parse(String value) {
    if (!_canonicalProofPattern.hasMatch(value)) {
      throw const AccountDeletionSessionProofCorruptException();
    }
    try {
      final decoded = base64Url.decode('$value=');
      final canonical = base64UrlEncode(decoded).replaceAll('=', '');
      if (decoded.length != _proofByteLength || canonical != value) {
        throw const AccountDeletionSessionProofCorruptException();
      }
    } on AccountDeletionSessionProofCorruptException {
      rethrow;
    } on Object {
      throw const AccountDeletionSessionProofCorruptException();
    }
    return AccountDeletionSessionProof._(value);
  }

  static final RegExp _canonicalProofPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  final String headerValue;

  @override
  String toString() => 'AccountDeletionSessionProof(<redacted>)';
}

final class AccountDeletionSessionProofUnavailableException
    implements Exception {
  const AccountDeletionSessionProofUnavailableException();

  @override
  String toString() => 'Secure account-deletion authorization is unavailable.';
}

final class AccountDeletionSessionProofCorruptException implements Exception {
  const AccountDeletionSessionProofCorruptException();

  @override
  String toString() => 'Secure account-deletion authorization is invalid.';
}

/// Small seam that keeps platform-channel storage out of deterministic tests.
abstract interface class AccountDeletionSecretStorage {
  Future<String?> read(String key);

  Future<Map<String, String>> readAll();

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Platform-backed secret storage. No Hive or shared-preferences fallback is
/// permitted: an unavailable Keychain/Keystore/credential store must stop the
/// deletion before its next remote mutation.
final class FlutterSecureAccountDeletionSecretStorage
    implements AccountDeletionSecretStorage {
  const FlutterSecureAccountDeletionSecretStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: 'cashpilot_account_deletion_v1',
        resetOnError: false,
        migrateOnAlgorithmChange: false,
      ),
      iOptions: IOSOptions(
        accountName: 'cashpilot.account-deletion.v1',
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
      mOptions: MacOsOptions(
        accountName: 'cashpilot.account-deletion.v1',
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
        usesDataProtectionKeychain: true,
      ),
      webOptions: WebOptions(
        dbName: 'CashPilotAccountDeletion',
        publicKey: 'CashPilotAccountDeletionKey',
      ),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

abstract interface class AccountDeletionSessionProofStore {
  /// Called immediately after successful reauthentication and before its
  /// durable checkpoint. An existing proof for the same operation is reused,
  /// including after process restart.
  Future<AccountDeletionSessionProof> createAfterReauthentication(
    DataDeletionOperationContext context,
  );

  /// Loads the already-created proof. It never generates a replacement because
  /// the server may already have committed the missing value.
  Future<AccountDeletionSessionProof> requireExisting(
    DataDeletionOperationContext context,
  );

  /// Loads the proof for the UID-free, read-only server recovery request.
  Future<AccountDeletionSessionProof> requireExistingForRecovery(
    AccountDeletionRecoveryTarget target,
  );

  /// Returns the platform-secure state that authorizes startup recovery.
  /// Hive checkpoints and quarantine entries are deliberately insufficient.
  Future<AccountDeletionSecureOperationStatus> recoveryStatus(
    AccountDeletionRecoveryTarget target,
  );

  /// Enumerates opaque recovery coordinates from secure storage. This is used
  /// only by the route-free startup gate when a crash occurred after durable
  /// quarantine removal but before the final secure-record erase.
  Future<List<AccountDeletionRecoveryTarget>> recoveryTargets();

  /// Converts the bearer proof into a proof-free trusted terminal marker as
  /// soon as a verified Auth deletion receipt is received.
  Future<void> markServerConfirmed(DataDeletionOperationContext context);

  Future<void> markServerConfirmedForRecovery(
    AccountDeletionRecoveryTarget target,
  );

  /// Converts a proof into a proof-free abandonment marker only while the
  /// operation is provably before its first remote deletion boundary.
  Future<void> markAbandonedBeforeRemote(DataDeletionOperationContext context);

  /// Erases the proof only after durable completion, or while abandoning an
  /// operation that provably never reached a remote deletion request.
  Future<void> clear(DataDeletionOperationContext context);

  Future<void> clearRecovery(AccountDeletionRecoveryTarget target);
}

enum AccountDeletionSecureOperationStatus {
  active,
  serverConfirmed,
  abandonedBeforeRemote,
}

typedef AccountDeletionRandomBytes = Uint8List Function(int length);

final class SecureAccountDeletionSessionProofStore
    implements AccountDeletionSessionProofStore {
  SecureAccountDeletionSessionProofStore({
    required AccountDeletionSecretStorage storage,
    AccountDeletionRandomBytes? randomBytes,
  }) : _storage = storage,
       _randomBytes = randomBytes ?? _cryptographicallySecureRandomBytes;

  final AccountDeletionSecretStorage _storage;
  final AccountDeletionRandomBytes _randomBytes;
  final Map<String, Future<void>> _keyBarriers = <String, Future<void>>{};

  @override
  Future<AccountDeletionSessionProof> createAfterReauthentication(
    DataDeletionOperationContext context,
  ) {
    final target = context.recoveryTarget;
    final key = _key(target);
    return _withKeyLock(key, () async {
      final existing = await _readRecord(key, target);
      if (existing != null) {
        if (existing.status != AccountDeletionSecureOperationStatus.active ||
            existing.proof == null) {
          throw const AccountDeletionSessionProofUnavailableException();
        }
        return existing.proof!;
      }

      final proof = _generateProof();
      final encoded = jsonEncode(<String, Object>{
        'version': 3,
        'operationId': context.operationId,
        'ownerScope': target.ownerScopeValue,
        'status': AccountDeletionSecureOperationStatus.active.name,
        'proof': proof.headerValue,
      });
      try {
        await _storage.write(key, encoded);
        final persisted = await _readRecord(key, target);
        if (persisted?.status != AccountDeletionSecureOperationStatus.active ||
            persisted?.proof?.headerValue != proof.headerValue) {
          throw const AccountDeletionSessionProofUnavailableException();
        }
        return persisted!.proof!;
      } on AccountDeletionSessionProofCorruptException {
        rethrow;
      } on AccountDeletionSessionProofUnavailableException {
        rethrow;
      } on Object {
        throw const AccountDeletionSessionProofUnavailableException();
      }
    });
  }

  @override
  Future<AccountDeletionSessionProof> requireExisting(
    DataDeletionOperationContext context,
  ) => requireExistingForRecovery(context.recoveryTarget);

  @override
  Future<AccountDeletionSessionProof> requireExistingForRecovery(
    AccountDeletionRecoveryTarget target,
  ) {
    final key = _key(target);
    return _withKeyLock(key, () async {
      final record = await _readRecord(key, target);
      if (record?.status != AccountDeletionSecureOperationStatus.active ||
          record?.proof == null) {
        throw const AccountDeletionSessionProofUnavailableException();
      }
      return record!.proof!;
    });
  }

  @override
  Future<AccountDeletionSecureOperationStatus> recoveryStatus(
    AccountDeletionRecoveryTarget target,
  ) {
    final key = _key(target);
    return _withKeyLock(key, () async {
      final record = await _readRecord(key, target);
      if (record == null) {
        throw const AccountDeletionSessionProofUnavailableException();
      }
      return record.status;
    });
  }

  @override
  Future<List<AccountDeletionRecoveryTarget>> recoveryTargets() async {
    late final Map<String, String> records;
    try {
      records = await _storage.readAll();
    } on Object {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    final targets = <AccountDeletionRecoveryTarget>[];
    final seen = <String>{};
    final entries =
        records.entries
            .where((entry) => entry.key.startsWith(_secureKeyPrefix))
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in entries) {
      if (!_secureKeyPattern.hasMatch(entry.key) || entry.value.length > 512) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      late final Object? decoded;
      try {
        decoded = jsonDecode(entry.value);
      } on Object {
        throw const AccountDeletionSessionProofCorruptException();
      }
      if (decoded is! Map<String, dynamic>) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      // Version 1/2 records predate self-describing recovery coordinates and
      // remain discoverable through their durable quarantine marker. Only v3
      // can safely recover a secure-only crash window.
      if (decoded['version'] == 1 || decoded['version'] == 2) {
        continue;
      }
      final operationId = decoded['operationId'];
      final ownerScopeValue = decoded['ownerScope'];
      if (decoded['version'] != 3 ||
          operationId is! String ||
          ownerScopeValue is! String) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      late final AccountDeletionRecoveryTarget target;
      try {
        target = AccountDeletionRecoveryTarget(
          operationId: operationId,
          ownerScopeValue: ownerScopeValue,
        );
      } on Object {
        throw const AccountDeletionSessionProofCorruptException();
      }
      if (_key(target) != entry.key) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      await _withKeyLock(entry.key, () async {
        if (await _readRecord(entry.key, target) == null) {
          throw const AccountDeletionSessionProofUnavailableException();
        }
      });
      final coordinate = '${target.ownerScopeValue}\u0000${target.operationId}';
      if (seen.add(coordinate)) {
        targets.add(target);
      }
    }
    return List<AccountDeletionRecoveryTarget>.unmodifiable(targets);
  }

  @override
  Future<void> markServerConfirmed(DataDeletionOperationContext context) =>
      markServerConfirmedForRecovery(context.recoveryTarget);

  @override
  Future<void> markServerConfirmedForRecovery(
    AccountDeletionRecoveryTarget target,
  ) => _markTerminal(
    target,
    AccountDeletionSecureOperationStatus.serverConfirmed,
  );

  @override
  Future<void> markAbandonedBeforeRemote(
    DataDeletionOperationContext context,
  ) async {
    final abandonedFrom = context.stage == DataDeletionStage.aborted
        ? context.abandonedFromStage
        : context.stage;
    if (abandonedFrom == null ||
        abandonedFrom.index >= DataDeletionStage.cloudDeleted.index) {
      throw StateError(
        'A remote account-deletion operation cannot be abandoned locally.',
      );
    }
    await _markTerminal(
      context.recoveryTarget,
      AccountDeletionSecureOperationStatus.abandonedBeforeRemote,
      abandonedFromStage: abandonedFrom,
    );
  }

  @override
  Future<void> clear(DataDeletionOperationContext context) {
    return clearRecovery(context.recoveryTarget);
  }

  @override
  Future<void> clearRecovery(AccountDeletionRecoveryTarget target) {
    final key = _key(target);
    return _withKeyLock(key, () async {
      try {
        await _storage.delete(key);
        if (await _storage.read(key) != null) {
          throw const AccountDeletionSessionProofUnavailableException();
        }
      } on AccountDeletionSessionProofUnavailableException {
        rethrow;
      } on Object {
        throw const AccountDeletionSessionProofUnavailableException();
      }
    });
  }

  Future<void> _markTerminal(
    AccountDeletionRecoveryTarget target,
    AccountDeletionSecureOperationStatus terminalStatus, {
    DataDeletionStage? abandonedFromStage,
  }) {
    if (terminalStatus == AccountDeletionSecureOperationStatus.active) {
      throw ArgumentError('A terminal secure deletion status is required.');
    }
    final key = _key(target);
    return _withKeyLock(key, () async {
      final existing = await _readRecord(key, target);
      if (existing == null) {
        throw const AccountDeletionSessionProofUnavailableException();
      }
      if (existing.status == terminalStatus) {
        return;
      }
      if (existing.status != AccountDeletionSecureOperationStatus.active ||
          existing.proof == null) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      if (terminalStatus ==
              AccountDeletionSecureOperationStatus.abandonedBeforeRemote &&
          (abandonedFromStage == null ||
              abandonedFromStage.index >=
                  DataDeletionStage.cloudDeleted.index)) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      final encoded = jsonEncode(<String, Object>{
        'version': 3,
        'operationId': target.operationId,
        'ownerScope': target.ownerScopeValue,
        'status': terminalStatus.name,
        if (abandonedFromStage != null)
          'abandonedFromStage': abandonedFromStage.name,
      });
      try {
        await _storage.write(key, encoded);
        final persisted = await _readRecord(key, target);
        if (persisted?.status != terminalStatus ||
            persisted?.proof != null ||
            persisted?.abandonedFromStage != abandonedFromStage) {
          throw const AccountDeletionSessionProofUnavailableException();
        }
      } on AccountDeletionSessionProofCorruptException {
        rethrow;
      } on AccountDeletionSessionProofUnavailableException {
        rethrow;
      } on Object {
        throw const AccountDeletionSessionProofUnavailableException();
      }
    });
  }

  Future<_SecureDeletionOperationRecord?> _readRecord(
    String key,
    AccountDeletionRecoveryTarget target,
  ) async {
    late final String? value;
    try {
      value = await _storage.read(key);
    } on Object {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    if (value == null) {
      return null;
    }
    if (value.length > 512) {
      throw const AccountDeletionSessionProofCorruptException();
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['operationId'] != target.operationId) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      // Legacy v1/v2 records are verified in place and deliberately are not
      // rewritten as a side effect of reading. Secure storage has no atomic
      // compare-and-swap operation, so a read-time rewrite could overwrite a
      // newer terminal/v3 value written by another store instance. A later
      // authorized state transition writes the canonical v3 schema normally.
      if (decoded['version'] == 1 &&
          decoded.length == 3 &&
          decoded['proof'] is String) {
        return _SecureDeletionOperationRecord(
          status: AccountDeletionSecureOperationStatus.active,
          proof: AccountDeletionSessionProof.parse(decoded['proof'] as String),
        );
      }
      final version = decoded['version'];
      if (version != 2 && version != 3) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      if (version == 3 && decoded['ownerScope'] != target.ownerScopeValue) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      final versionThreeField = version == 3 ? 1 : 0;
      final statusName = decoded['status'];
      final status = statusName is String
          ? AccountDeletionSecureOperationStatus.values
                .where((candidate) => candidate.name == statusName)
                .firstOrNull
          : null;
      if (status == null) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      if (status == AccountDeletionSecureOperationStatus.active) {
        if (decoded.length != 4 + versionThreeField ||
            decoded['proof'] is! String) {
          throw const AccountDeletionSessionProofCorruptException();
        }
        return _SecureDeletionOperationRecord(
          status: status,
          proof: AccountDeletionSessionProof.parse(decoded['proof'] as String),
        );
      }
      if (decoded.containsKey('proof')) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      if (status ==
          AccountDeletionSecureOperationStatus.abandonedBeforeRemote) {
        final abandonedFromName = decoded['abandonedFromStage'];
        final abandonedFrom = abandonedFromName is String
            ? DataDeletionStage.values
                  .where((candidate) => candidate.name == abandonedFromName)
                  .firstOrNull
            : null;
        if (decoded.length != 4 + versionThreeField ||
            abandonedFrom == null ||
            abandonedFrom.index >= DataDeletionStage.cloudDeleted.index) {
          throw const AccountDeletionSessionProofCorruptException();
        }
        return _SecureDeletionOperationRecord(
          status: status,
          abandonedFromStage: abandonedFrom,
        );
      }
      if (decoded.length != 3 + versionThreeField ||
          decoded.containsKey('abandonedFromStage')) {
        throw const AccountDeletionSessionProofCorruptException();
      }
      return _SecureDeletionOperationRecord(status: status);
    } on AccountDeletionSessionProofCorruptException {
      rethrow;
    } on Object {
      throw const AccountDeletionSessionProofCorruptException();
    }
  }

  AccountDeletionSessionProof _generateProof() {
    final bytes = _randomBytes(_proofByteLength);
    if (bytes.length != _proofByteLength) {
      throw const AccountDeletionSessionProofUnavailableException();
    }
    try {
      return AccountDeletionSessionProof.parse(
        base64UrlEncode(bytes).replaceAll('=', ''),
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<T> _withKeyLock<T>(String key, Future<T> Function() operation) {
    final previous = _keyBarriers[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    late final Future<void> barrier;
    barrier = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    _keyBarriers[key] = barrier;
    barrier.whenComplete(() {
      if (identical(_keyBarriers[key], barrier)) {
        _keyBarriers.remove(key);
      }
    });
    return result;
  }

  String _key(AccountDeletionRecoveryTarget target) {
    final ownerScope = target.ownerScopeValue;
    final operationId = target.operationId;
    final digest = sha256.convert(
      utf8.encode(
        'cashpilot.account-deletion-proof-key.v1\u0000'
        '$ownerScope\u0000$operationId',
      ),
    );
    return '$_secureKeyPrefix$digest';
  }
}

final class _SecureDeletionOperationRecord {
  const _SecureDeletionOperationRecord({
    required this.status,
    this.proof,
    this.abandonedFromStage,
  });

  final AccountDeletionSecureOperationStatus status;
  final AccountDeletionSessionProof? proof;
  final DataDeletionStage? abandonedFromStage;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

const int _proofByteLength = 32;
const String _secureKeyPrefix = 'cp_del_v1_';
final RegExp _secureKeyPattern = RegExp(r'^cp_del_v1_[a-f0-9]{64}$');

Uint8List _cryptographicallySecureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256), growable: false),
  );
}
