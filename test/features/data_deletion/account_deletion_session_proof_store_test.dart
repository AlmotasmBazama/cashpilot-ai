import 'dart:typed_data';

import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('secure account-deletion session proof', () {
    test(
      'creates one canonical 256-bit proof and verifies persistence',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: (length) =>
              Uint8List.fromList(List<int>.generate(length, (index) => index)),
        );
        final context = _context(uid: 'owner-a', operationId: 'operation-0001');

        final first = await store.createAfterReauthentication(context);
        final second = await store.requireExisting(context);

        expect(first.headerValue, hasLength(43));
        expect(first.headerValue, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
        expect(second.headerValue, first.headerValue);
        expect(storage.writes, 1);
        expect(storage.values, hasLength(1));
        expect(storage.values.keys.single, isNot(contains('owner-a')));
        expect(
          storage.values.keys.single,
          isNot(contains(context.identity.ownerScope.id.value)),
        );
        expect(storage.values.values.single, isNot(contains('owner-a')));
        // The secure v3 record is self-describing only with the opaque owner
        // commitment needed by route-free crash recovery; it never stores UID.
        expect(
          storage.values.values.single,
          contains(context.identity.ownerScope.id.value),
        );
      },
    );

    test(
      'survives restart and auth-generation change for the same operation',
      () async {
        final storage = _MemorySecretStorage();
        final original = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(11),
        );
        final context = _context(uid: 'owner-a', operationId: 'operation-0002');
        final created = await original.createAfterReauthentication(context);

        final restarted = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(22),
        );
        final resumed = await restarted.requireExisting(
          _context(
            uid: 'owner-a',
            operationId: 'operation-0002',
            authSessionId: 'new-auth-session',
            authGeneration: 99,
          ),
        );

        expect(resumed.headerValue, created.headerValue);
        expect(storage.writes, 1);
      },
    );

    test('rotates for every new operation and isolates owners', () async {
      final storage = _MemorySecretStorage();
      var seed = 1;
      final store = SecureAccountDeletionSessionProofStore(
        storage: storage,
        randomBytes: (length) =>
            Uint8List(length)..fillRange(0, length, seed++),
      );

      final a1 = await store.createAfterReauthentication(
        _context(uid: 'owner-a', operationId: 'operation-a-0001'),
      );
      final a2 = await store.createAfterReauthentication(
        _context(uid: 'owner-a', operationId: 'operation-a-0002'),
      );
      final b1 = await store.createAfterReauthentication(
        _context(uid: 'owner-b', operationId: 'operation-a-0001'),
      );

      expect({a1.headerValue, a2.headerValue, b1.headerValue}, hasLength(3));
      expect(storage.values, hasLength(3));
    });

    test(
      'never invents a proof when a resumed operation is missing it',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(3),
        );

        await expectLater(
          store.requireExisting(
            _context(uid: 'owner-a', operationId: 'operation-0003'),
          ),
          throwsA(isA<AccountDeletionSessionProofUnavailableException>()),
        );
        expect(storage.writes, 0);
      },
    );

    test(
      'fails closed on corrupt secure storage without replacing it',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(4),
        );
        final context = _context(uid: 'owner-a', operationId: 'operation-0004');
        storage.onRead = (_) =>
            '{"version":1,"operationId":"operation-0004",'
            '"proof":"padded====================================="}';

        await expectLater(
          store.createAfterReauthentication(context),
          throwsA(isA<AccountDeletionSessionProofCorruptException>()),
        );
        expect(storage.writes, 0);
      },
    );

    test(
      'does not return a newly generated proof unless read-back matches',
      () async {
        final storage = _MemorySecretStorage()..dropWrites = true;
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(5),
        );

        await expectLater(
          store.createAfterReauthentication(
            _context(uid: 'owner-a', operationId: 'operation-0005'),
          ),
          throwsA(isA<AccountDeletionSessionProofUnavailableException>()),
        );
      },
    );

    test(
      'clears only the exact owner operation and verifies deletion',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(6),
        );
        final first = _context(uid: 'owner-a', operationId: 'operation-0006');
        final other = _context(uid: 'owner-a', operationId: 'operation-0007');
        await store.createAfterReauthentication(first);
        await store.createAfterReauthentication(other);

        await store.clear(first);

        await expectLater(
          store.requireExisting(first),
          throwsA(isA<AccountDeletionSessionProofUnavailableException>()),
        );
        expect((await store.requireExisting(other)).headerValue, isNotEmpty);
        expect(storage.values, hasLength(1));
      },
    );

    test(
      'server confirmation becomes a proof-free trusted recovery marker',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(7),
        );
        final context = _context(uid: 'owner-a', operationId: 'operation-0008');
        await store.createAfterReauthentication(context);

        await store.markServerConfirmed(context);

        expect(
          await store.recoveryStatus(context.recoveryTarget),
          AccountDeletionSecureOperationStatus.serverConfirmed,
        );
        expect(storage.values.values.single, isNot(contains('proof')));
        await expectLater(
          store.requireExisting(context),
          throwsA(isA<AccountDeletionSessionProofUnavailableException>()),
        );
      },
    );

    test(
      'enumerates exact v3 targets after durable quarantine was cleared',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(10),
        );
        final first = _context(
          uid: 'owner-a',
          operationId: 'operation-enumerate-a',
        );
        final second = _context(
          uid: 'owner-b',
          operationId: 'operation-enumerate-b',
        );
        await store.createAfterReauthentication(first);
        await store.createAfterReauthentication(second);
        await store.markServerConfirmed(first);

        expect(
          (await store.recoveryTargets()).map(
            (target) => '${target.ownerScopeValue}:${target.operationId}',
          ),
          containsAll(<String>[
            '${first.recoveryTarget.ownerScopeValue}:operation-enumerate-a',
            '${second.recoveryTarget.ownerScopeValue}:operation-enumerate-b',
          ]),
        );
      },
    );

    test(
      'secure target enumeration rejects a mismatched self-description',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(12),
        );
        final context = _context(
          uid: 'owner-a',
          operationId: 'operation-enumerate-corrupt',
        );
        await store.createAfterReauthentication(context);
        final key = storage.values.keys.single;
        storage.values[key] = storage.values[key]!.replaceFirst(
          context.identity.ownerScope.id.value,
          OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-b').id.value,
        );

        await expectLater(
          store.recoveryTargets(),
          throwsA(isA<AccountDeletionSessionProofCorruptException>()),
        );
      },
    );

    test(
      'pre-remote abandonment is secure and cannot overwrite a remote stage',
      () async {
        final storage = _MemorySecretStorage();
        final store = SecureAccountDeletionSessionProofStore(
          storage: storage,
          randomBytes: _filled(8),
        );
        final reauthenticated = _context(
          uid: 'owner-a',
          operationId: 'operation-0009',
        ).advance(DataDeletionStage.reauthenticated);
        await store.createAfterReauthentication(reauthenticated);

        await store.markAbandonedBeforeRemote(reauthenticated);

        expect(
          await store.recoveryStatus(reauthenticated.recoveryTarget),
          AccountDeletionSecureOperationStatus.abandonedBeforeRemote,
        );
        expect(storage.values.values.single, isNot(contains('proof')));

        final remote = _context(uid: 'owner-b', operationId: 'operation-0010')
            .advance(DataDeletionStage.reauthenticated)
            .advance(DataDeletionStage.backupFenced)
            .advance(DataDeletionStage.writersVerified)
            .advance(DataDeletionStage.cloudDeleted);
        await store.createAfterReauthentication(remote);
        await expectLater(
          store.markAbandonedBeforeRemote(remote),
          throwsStateError,
        );
        expect(
          await store.recoveryStatus(remote.recoveryTarget),
          AccountDeletionSecureOperationStatus.active,
        );
      },
    );

    test('recovery lookup is exact and corrupt status fails closed', () async {
      final storage = _MemorySecretStorage();
      final store = SecureAccountDeletionSessionProofStore(
        storage: storage,
        randomBytes: _filled(9),
      );
      final context = _context(uid: 'owner-a', operationId: 'operation-0011');
      await store.createAfterReauthentication(context);

      await expectLater(
        store.recoveryStatus(
          AccountDeletionRecoveryTarget(
            operationId: 'operation-0012',
            ownerScopeValue: context.identity.ownerScope.id.value,
          ),
        ),
        throwsA(isA<AccountDeletionSessionProofUnavailableException>()),
      );

      storage.onRead = (_) =>
          '{"version":2,"operationId":"operation-0011",'
          '"status":"forged"}';
      await expectLater(
        store.recoveryStatus(context.recoveryTarget),
        throwsA(isA<AccountDeletionSessionProofCorruptException>()),
      );
    });

    test('redacts proof from diagnostics and rejects non-canonical values', () {
      final valid = AccountDeletionSessionProof.parse(
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      );
      expect(valid.toString(), isNot(contains(valid.headerValue)));
      for (final invalid in <String>[
        '',
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+',
      ]) {
        expect(
          () => AccountDeletionSessionProof.parse(invalid),
          throwsA(isA<AccountDeletionSessionProofCorruptException>()),
        );
      }
    });
  });
}

Uint8List Function(int) _filled(int value) =>
    (length) => Uint8List(length)..fillRange(0, length, value);

DataDeletionOperationContext _context({
  required String uid,
  required String operationId,
  String authSessionId = 'auth-session',
  int authGeneration = 1,
}) {
  return DataDeletionOperationContext.captured(
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
}

final class _MemorySecretStorage implements AccountDeletionSecretStorage {
  final Map<String, String> values = <String, String>{};
  String? Function(String key)? onRead;
  bool dropWrites = false;
  int writes = 0;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => onRead?.call(key) ?? values[key];

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async {
    writes += 1;
    if (!dropWrites) {
      values[key] = value;
    }
  }
}
