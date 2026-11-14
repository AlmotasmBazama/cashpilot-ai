import 'dart:convert';
import 'dart:typed_data';

import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('secure account-deletion upgrade compatibility', () {
    test(
      'v1 active record is verified in place across an auth restart',
      () async {
        final storage = _MemorySecretStorage();
        final context = _context(
          uid: 'legacy-owner',
          operationId: 'legacy-operation-v1',
        );
        final originalStore = _store(storage, seed: 17);
        final proof = await originalStore.createAfterReauthentication(context);
        final key = storage.values.keys.single;
        final legacyValue = jsonEncode(<String, Object>{
          'version': 1,
          'operationId': context.operationId,
          'proof': proof.headerValue,
        });
        storage.values[key] = legacyValue;
        storage.resetActivity();

        final restartedStore = _store(storage, seed: 99);
        final restartedContext = _context(
          uid: 'legacy-owner',
          operationId: 'legacy-operation-v1',
          authSessionId: 'post-logout-session',
          authGeneration: 42,
        );

        expect(
          (await restartedStore.requireExisting(restartedContext)).headerValue,
          proof.headerValue,
        );
        expect(
          (await restartedStore.requireExisting(restartedContext)).headerValue,
          proof.headerValue,
        );
        expect(storage.values[key], legacyValue);
        expect(storage.writes, 0);
        expect(storage.deletes, 0);
      },
    );

    test(
      'v2 proof-free terminal records retain exact status and stage',
      () async {
        final storage = _MemorySecretStorage();
        final serverConfirmed = _context(
          uid: 'legacy-owner-a',
          operationId: 'legacy-operation-v2-confirmed',
        );
        final abandoned = _context(
          uid: 'legacy-owner-b',
          operationId: 'legacy-operation-v2-abandoned',
        );
        final store = _store(storage, seed: 21);
        await store.createAfterReauthentication(serverConfirmed);
        final confirmedKey = storage.values.keys.single;
        await store.createAfterReauthentication(abandoned);
        final abandonedKey = storage.values.keys.singleWhere(
          (candidate) => candidate != confirmedKey,
        );
        final confirmedValue = jsonEncode(<String, Object>{
          'version': 2,
          'operationId': serverConfirmed.operationId,
          'status': AccountDeletionSecureOperationStatus.serverConfirmed.name,
        });
        final abandonedValue = jsonEncode(<String, Object>{
          'version': 2,
          'operationId': abandoned.operationId,
          'status':
              AccountDeletionSecureOperationStatus.abandonedBeforeRemote.name,
          'abandonedFromStage': DataDeletionStage.reauthenticated.name,
        });
        storage.values[confirmedKey] = confirmedValue;
        storage.values[abandonedKey] = abandonedValue;
        storage.resetActivity();

        final restartedStore = _store(storage, seed: 88);

        expect(
          await restartedStore.recoveryStatus(serverConfirmed.recoveryTarget),
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );
        expect(
          await restartedStore.recoveryStatus(abandoned.recoveryTarget),
          AccountDeletionSecureOperationStatus.abandonedBeforeRemote,
        );
        expect(storage.values[confirmedKey], confirmedValue);
        expect(storage.values[abandonedKey], abandonedValue);
        expect(storage.writes, 0);
        expect(storage.deletes, 0);
      },
    );

    test(
      'newer v3 record remains byte-for-byte unchanged by verification',
      () async {
        final storage = _MemorySecretStorage();
        final context = _context(
          uid: 'current-owner',
          operationId: 'current-operation-v3',
        );
        final store = _store(storage, seed: 31);
        final proof = await store.createAfterReauthentication(context);
        final key = storage.values.keys.single;
        final currentValue = storage.values[key];
        storage.resetActivity();

        expect(
          (await store.requireExisting(context)).headerValue,
          proof.headerValue,
        );
        final targets = await store.recoveryTargets();
        expect(targets, hasLength(1));
        expect(targets.single.operationId, context.operationId);
        expect(
          targets.single.ownerScopeValue,
          context.recoveryTarget.ownerScopeValue,
        );
        expect(storage.values[key], currentValue);
        expect(storage.writes, 0);
        expect(storage.deletes, 0);
      },
    );

    test('corrupt legacy data stays unchanged and fails closed', () async {
      final storage = _MemorySecretStorage();
      final context = _context(
        uid: 'corrupt-owner',
        operationId: 'corrupt-operation-v1',
      );
      final store = _store(storage, seed: 41);
      await store.createAfterReauthentication(context);
      final key = storage.values.keys.single;
      final corruptValue = jsonEncode(<String, Object>{
        'version': 1,
        'operationId': context.operationId,
        'proof': 'not-a-canonical-deletion-proof',
      });
      storage.values[key] = corruptValue;
      storage.resetActivity();

      await expectLater(
        store.requireExisting(context),
        throwsA(isA<AccountDeletionSessionProofCorruptException>()),
      );
      expect(storage.values[key], corruptValue);
      expect(storage.writes, 0);
      expect(storage.deletes, 0);
    });

    test(
      'platform read failure never resets or rewrites secure state',
      () async {
        final storage = _MemorySecretStorage();
        final context = _context(
          uid: 'upgrade-owner',
          operationId: 'upgrade-algorithm-mismatch',
        );
        final store = _store(storage, seed: 51);
        await store.createAfterReauthentication(context);
        final beforeFailure = Map<String, String>.of(storage.values);
        storage
          ..resetActivity()
          ..readFailure = const _SyntheticSecureStorageReadFailure();

        await expectLater(
          store.requireExisting(context),
          throwsA(isA<AccountDeletionSessionProofUnavailableException>()),
        );
        expect(storage.values, beforeFailure);
        expect(storage.writes, 0);
        expect(storage.deletes, 0);
      },
    );

    test(
      'auth restart preserves recovery and deletion cleanup clears exact scope',
      () async {
        final storage = _MemorySecretStorage();
        final first = _context(
          uid: 'cleanup-owner-a',
          operationId: 'cleanup-operation-a',
        );
        final sibling = _context(
          uid: 'cleanup-owner-b',
          operationId: 'cleanup-operation-b',
        );
        final originalStore = _store(storage, seed: 61);
        final firstProof = await originalStore.createAfterReauthentication(
          first,
        );
        final firstKey = storage.values.keys.single;
        final siblingProof = await originalStore.createAfterReauthentication(
          sibling,
        );
        final siblingKey = storage.values.keys.singleWhere(
          (candidate) => candidate != firstKey,
        );
        final firstLegacyValue = jsonEncode(<String, Object>{
          'version': 1,
          'operationId': first.operationId,
          'proof': firstProof.headerValue,
        });
        final siblingLegacyValue = jsonEncode(<String, Object>{
          'version': 2,
          'operationId': sibling.operationId,
          'status': AccountDeletionSecureOperationStatus.active.name,
          'proof': siblingProof.headerValue,
        });
        storage.values[firstKey] = firstLegacyValue;
        storage.values[siblingKey] = siblingLegacyValue;
        storage.resetActivity();

        final restartedStore = _store(storage, seed: 77);
        expect(
          (await restartedStore.requireExisting(
            _context(
              uid: 'cleanup-owner-a',
              operationId: first.operationId,
              authSessionId: 'replacement-session',
              authGeneration: 7,
            ),
          )).headerValue,
          firstProof.headerValue,
        );

        await restartedStore.clearRecovery(first.recoveryTarget);

        expect(storage.values, isNot(contains(firstKey)));
        expect(storage.values[siblingKey], siblingLegacyValue);
        expect(
          (await restartedStore.requireExisting(sibling)).headerValue,
          siblingProof.headerValue,
        );
        expect(storage.writes, 0);
        expect(storage.deletes, 1);
      },
    );
  });
}

SecureAccountDeletionSessionProofStore _store(
  AccountDeletionSecretStorage storage, {
  required int seed,
}) => SecureAccountDeletionSessionProofStore(
  storage: storage,
  randomBytes: (length) => Uint8List(length)..fillRange(0, length, seed),
);

DataDeletionOperationContext _context({
  required String uid,
  required String operationId,
  String authSessionId = 'auth-session',
  int authGeneration = 1,
}) => DataDeletionOperationContext.captured(
  operationId: operationId,
  identity: TrustedDeletionIdentity(
    authSessionId: authSessionId,
    authStateGeneration: authGeneration,
    userId: uid,
    isAnonymous: false,
    ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(uid),
  ),
  startedAtUtc: DateTime.utc(2026),
);

final class _MemorySecretStorage implements AccountDeletionSecretStorage {
  final Map<String, String> values = <String, String>{};
  Object? readFailure;
  int writes = 0;
  int deletes = 0;

  void resetActivity() {
    writes = 0;
    deletes = 0;
  }

  @override
  Future<void> delete(String key) async {
    deletes += 1;
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    final failure = readFailure;
    if (failure != null) {
      throw failure;
    }
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async {
    writes += 1;
    values[key] = value;
  }
}

final class _SyntheticSecureStorageReadFailure implements Exception {
  const _SyntheticSecureStorageReadFailure();
}
