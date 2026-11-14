import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/storage/owner_scoped_storage_keys.dart';
import 'package:cashpilot_ai/core/storage/settings_keys.dart';
import 'package:cashpilot_ai/core/storage/settings_local_data_source.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/owner_deletion_quarantine_store.dart';
import 'package:cashpilot_ai/core/sync/data/sync_preferences_local_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/hive_ai_app_control_settings_store.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_operation_coordinator.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_oauth_credential_provider.dart';
import 'package:cashpilot_ai/features/auth/data/datasources/firebase_auth_data_source.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_auth_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_session_proof_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/cloud_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/data_deletion_operation_state_store.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/deletion_preferences_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/local_user_data_deletion_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/receipt_file_deletion_journal.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_local_image_store.dart';
import 'package:cashpilot_ai/features/receipts/data/services/receipt_privacy_consent_store.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cloud_firestore;
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;

void main() {
  test('owner scope rejects whitespace UID collisions', () {
    final canonical = OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a');

    expect(canonical.id.value, hasLength(64));
    expect(
      () => OwnerScopeDerivation.fromConfirmedFirebaseUid(' owner-a'),
      throwsArgumentError,
    );
    expect(
      () => OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a '),
      throwsArgumentError,
    );
    expect(
      () => OwnerScopeDerivation.fromConfirmedFirebaseUid('   '),
      throwsArgumentError,
    );
    final nonCanonicalAuth = _FirebaseAuth(
      _FirebaseUser(uid: ' owner-a', idToken: 'token'),
    );
    addTearDown(nonCanonicalAuth.dispose);
    expect(
      () => FirebaseAuthIdentityPolicy.assertSupportedUser(
        nonCanonicalAuth.currentUser!,
      ),
      throwsArgumentError,
    );
  });

  test(
    'tenant-scoped same-UID sessions expose no owner data or deletion session',
    () async {
      for (final tenantId in const ['', 'tenant-alpha', 'tenant-beta']) {
        final auth = _FirebaseAuth(
          _FirebaseUser(
            uid: 'shared-tenant-uid',
            idToken: 'tenant-token',
            tenantId: tenantId,
          ),
        );
        addTearDown(auth.dispose);
        final firestore = _CountingFirebaseFirestore();
        final overlay = _MemoryCompletedDeletionOverlay();
        addTearDown(overlay.dispose);
        final sessionGuard = FirebaseAuthSessionEpochGuard(auth);
        addTearDown(sessionGuard.dispose);
        final source = FirebaseAuthDataSource(
          auth: auth,
          firestore: firestore,
          googleSignIn: GoogleSignIn.instance,
          logger: AppLogger.instance,
          completedDeletionOverlay: overlay,
          sessionGuard: sessionGuard,
        );

        expect(await source.getCurrentUser(), isNull);
        expect(firestore.accesses, 0);
        final deletionSource = FirebaseAccountDeletionAuthDataSource(
          auth: auth,
          sessionGuard: sessionGuard,
          completedDeletionOverlay: overlay,
          operationCoordinator: FirebaseAuthOperationCoordinator(),
          oauthCredentialProvider: _UnavailableOAuthCredentialProvider(),
        );
        addTearDown(deletionSource.dispose);
        await expectLater(
          deletionSource.issueConfirmationLease(),
          throwsA(isA<AccountDeletionIdentityChangedException>()),
        );
      }
    },
  );

  test('delayed A profile lookup cannot emit A after owner B', () async {
    final auth = _FirebaseAuth(
      _FirebaseUser(uid: 'owner-a', idToken: 'token-a'),
    );
    final guard = FirebaseAuthSessionEpochGuard(auth);
    final overlay = _MemoryCompletedDeletionOverlay();
    final firestore = _DelayedProfileFirebaseFirestore('owner-a');
    final source = FirebaseAuthDataSource(
      auth: auth,
      firestore: firestore,
      googleSignIn: GoogleSignIn.instance,
      logger: AppLogger.instance,
      completedDeletionOverlay: overlay,
      sessionGuard: guard,
    );
    addTearDown(() async {
      await guard.dispose();
      await overlay.dispose();
      await auth.dispose();
    });
    final seen = <String?>[];
    final subscription = source.listenAuthState().listen(
      (user) => seen.add(user?.uid),
    );
    addTearDown(subscription.cancel);
    await firestore.delayedReadStarted.future;

    auth.replaceCurrentUser(_FirebaseUser(uid: 'owner-b', idToken: 'token-b'));
    await pumpEventQueue(times: 10);
    final firstB = seen.indexOf('owner-b');
    expect(firstB, greaterThanOrEqualTo(0));

    firestore.releaseDelayedRead.complete();
    await pumpEventQueue(times: 10);

    expect(seen.skip(firstB + 1), isNot(contains('owner-a')));
    expect(seen.last, 'owner-b');
  });

  test(
    'profile read outage never publishes an auth-only incomplete identity',
    () async {
      final auth = _FirebaseAuth(
        _FirebaseUser(uid: 'owner-a', idToken: 'token-a'),
      );
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = _MemoryCompletedDeletionOverlay();
      final firestore = _DelayedProfileFirebaseFirestore(
        'owner-a',
        failReads: true,
      );
      final source = FirebaseAuthDataSource(
        auth: auth,
        firestore: firestore,
        googleSignIn: GoogleSignIn.instance,
        logger: AppLogger.instance,
        completedDeletionOverlay: overlay,
        sessionGuard: guard,
      );
      addTearDown(() async {
        await source.dispose();
        await guard.dispose();
        await overlay.dispose();
        await auth.dispose();
      });
      final seen = <String?>[];
      final errors = <Object>[];
      final subscription = source.listenAuthState().listen(
        (user) => seen.add(user?.uid),
        onError: (Object error) => errors.add(error),
      );
      addTearDown(subscription.cancel);
      await firestore.delayedReadStarted.future;
      firestore.releaseDelayedRead.complete();
      await pumpEventQueue(times: 8);

      expect(seen.whereType<String>(), isEmpty);
      expect(seen, isNotEmpty);
      expect(seen.last, isNull);
      expect(errors, isNotEmpty);
    },
  );

  test(
    'userChanges-before-authState publishes the new generation exactly once',
    () async {
      final auth = _FirebaseAuth(
        _FirebaseUser(uid: 'owner-a', idToken: 'token-a'),
      );
      final guard = FirebaseAuthSessionEpochGuard(auth);
      auth.emitCurrentAuthState();
      final overlay = _MemoryCompletedDeletionOverlay();
      final source = FirebaseAuthDataSource(
        auth: auth,
        firestore: _CountingFirebaseFirestore(),
        googleSignIn: GoogleSignIn.instance,
        logger: AppLogger.instance,
        completedDeletionOverlay: overlay,
        sessionGuard: guard,
      );
      addTearDown(() async {
        await guard.dispose();
        await overlay.dispose();
        await auth.dispose();
      });
      final generations = <int>[];
      final subscription = source.listenAuthState().listen((user) {
        if (user != null) generations.add(user.authSessionGeneration);
      });
      addTearDown(subscription.cancel);
      await pumpEventQueue(times: 5);
      final initialGeneration = guard.currentSnapshot()!.generation;

      auth.replaceViaUserChangesOnly(
        _FirebaseUser(uid: 'owner-a', idToken: 'new-session-token-a'),
      );
      await pumpEventQueue(times: 2);
      expect(guard.currentSnapshot()!.generation, initialGeneration);
      auth.emitCurrentAuthState();
      await pumpEventQueue(times: 5);

      expect(guard.currentSnapshot()!.generation, initialGeneration + 1);
      expect(generations, contains(initialGeneration + 1));

      auth.replaceViaUserChangesOnly(
        _FirebaseUser(uid: 'owner-b', idToken: 'token-b'),
      );
      final polledGeneration = guard.currentSnapshot()!.generation;
      auth.emitCurrentAuthState();
      expect(guard.currentSnapshot()!.generation, polledGeneration);
    },
  );

  test(
    'unsupported B fails closed before owner overlay and never retains A',
    () async {
      final auth = _FirebaseAuth(
        _FirebaseUser(uid: 'owner-a', idToken: 'token-a'),
      );
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = _CanonicalUidAssertingOverlay();
      final source = FirebaseAuthDataSource(
        auth: auth,
        firestore: _CountingFirebaseFirestore(),
        googleSignIn: GoogleSignIn.instance,
        logger: AppLogger.instance,
        completedDeletionOverlay: overlay,
        sessionGuard: guard,
      );
      addTearDown(() async {
        await source.dispose();
        await guard.dispose();
        await overlay.dispose();
        await auth.dispose();
      });
      final seen = <String?>[];
      final errors = <Object>[];
      final subscription = source.listenAuthState().listen(
        (user) => seen.add(user?.uid),
        onError: (Object error) => errors.add(error),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue(times: 5);
      expect(seen, contains('owner-a'));

      auth.replaceCurrentUser(
        _FirebaseUser(uid: ' owner-b', idToken: 'token-b'),
      );
      await pumpEventQueue(times: 5);

      expect(errors, isEmpty);
      expect(seen.last, isNull);
      expect(seen.skip(seen.lastIndexOf(null) + 1), isNot(contains('owner-a')));
      expect(overlay.invalidUidCalls, 0);
    },
  );

  test('native Auth source completion revokes A before stream close', () async {
    final auth = _FirebaseAuth(
      _FirebaseUser(uid: 'owner-a', idToken: 'token-a'),
    );
    final guard = FirebaseAuthSessionEpochGuard(auth);
    final overlay = _MemoryCompletedDeletionOverlay();
    final source = FirebaseAuthDataSource(
      auth: auth,
      firestore: _CountingFirebaseFirestore(),
      googleSignIn: GoogleSignIn.instance,
      logger: AppLogger.instance,
      completedDeletionOverlay: overlay,
      sessionGuard: guard,
    );
    addTearDown(() async {
      await source.dispose();
      await guard.dispose();
      await overlay.dispose();
      await auth.dispose();
    });
    final seen = <String?>[];
    final done = Completer<void>();
    source.listenAuthState().listen(
      (user) => seen.add(user?.uid),
      onDone: done.complete,
    );
    await pumpEventQueue(times: 5);
    expect(seen, contains('owner-a'));

    await auth.closeAuthStateOnly();
    await done.future;

    expect(seen.last, isNull);
  });

  test('polled C revokes A and rejects an older queued B auth event', () async {
    final auth = _FirebaseAuth(
      _FirebaseUser(uid: 'owner-a', idToken: 'token-a'),
    );
    final guard = FirebaseAuthSessionEpochGuard(auth);
    final overlay = _MemoryCompletedDeletionOverlay();
    final source = FirebaseAuthDataSource(
      auth: auth,
      firestore: _CountingFirebaseFirestore(),
      googleSignIn: GoogleSignIn.instance,
      logger: AppLogger.instance,
      completedDeletionOverlay: overlay,
      sessionGuard: guard,
    );
    addTearDown(() async {
      await source.dispose();
      await guard.dispose();
      await overlay.dispose();
      await auth.dispose();
    });
    final seen = <String?>[];
    final subscription = source.listenAuthState().listen(
      (user) => seen.add(user?.uid),
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue(times: 5);
    expect(seen, contains('owner-a'));

    final queuedB = _FirebaseUser(uid: 'owner-b', idToken: 'token-b');
    final currentC = _FirebaseUser(uid: 'owner-c', idToken: 'token-c');
    auth.setCurrentUserWithoutEvent(currentC);
    final cSnapshot = guard.currentSnapshot();
    expect(cSnapshot?.fingerprint.uid, 'owner-c');
    await pumpEventQueue(times: 2);
    final revocationIndex = seen.lastIndexOf(null);
    expect(revocationIndex, greaterThanOrEqualTo(0));

    auth.emitAuthStateFor(queuedB);
    await pumpEventQueue(times: 3);
    expect(seen.skip(revocationIndex + 1), isEmpty);

    auth.emitAuthStateFor(currentC);
    await pumpEventQueue(times: 5);
    expect(seen.skip(revocationIndex + 1), isNot(contains('owner-a')));
    expect(seen.skip(revocationIndex + 1), isNot(contains('owner-b')));
    expect(seen.last, 'owner-c');
  });

  test(
    'Auth stream error makes every deletion mutation boundary fail closed',
    () async {
      final user = _FirebaseUser(uid: 'owner-a', idToken: 'token-a');
      final auth = _FirebaseAuth(user);
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = _MemoryCompletedDeletionOverlay();
      final deletionAuth = FirebaseAccountDeletionAuthDataSource(
        auth: auth,
        sessionGuard: guard,
        completedDeletionOverlay: overlay,
        operationCoordinator: FirebaseAuthOperationCoordinator(),
        oauthCredentialProvider: _UnavailableOAuthCredentialProvider(),
      );
      addTearDown(() async {
        await deletionAuth.dispose();
        await guard.dispose();
        await overlay.dispose();
        await auth.dispose();
      });
      auth.emitCurrentAuthState();
      final lease = await deletionAuth.issueConfirmationLease();
      final identity = await deletionAuth.captureSession(lease);
      final context = DataDeletionOperationContext.captured(
        operationId: '01989f80-4e00-7000-8000-000000000099',
        identity: identity,
        startedAtUtc: DateTime.utc(2026, 8, 10),
      );
      final snapshot = guard.currentSnapshot()!;

      auth.emitAuthError(StateError('native auth stream failed'));
      await pumpEventQueue(times: 2);

      expect(guard.currentSnapshot(), isNull);
      expect(guard.matches(snapshot), isFalse);
      await expectLater(
        deletionAuth.revalidate(context),
        throwsA(isA<AccountDeletionIdentityChangedException>()),
      );
      await expectLater(
        deletionAuth.freshIdToken(context),
        throwsA(isA<AccountDeletionIdentityChangedException>()),
      );
      expect(user.tokenRequests, 0);
    },
  );

  test(
    'profile command captured for A cannot write A fields after B becomes current',
    () async {
      final updateStarted = Completer<void>();
      final releaseUpdate = Completer<void>();
      final userA = _FirebaseUser(
        uid: 'owner-a',
        idToken: 'token-a',
        updateDisplayNameStarted: updateStarted,
        releaseDisplayNameUpdate: releaseUpdate,
      );
      final auth = _FirebaseAuth(userA);
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = _MemoryCompletedDeletionOverlay();
      final firestore = _CountingFirebaseFirestore();
      final source = FirebaseAuthDataSource(
        auth: auth,
        firestore: firestore,
        googleSignIn: GoogleSignIn.instance,
        logger: AppLogger.instance,
        completedDeletionOverlay: overlay,
        sessionGuard: guard,
      );
      addTearDown(() async {
        await source.dispose();
        await guard.dispose();
        await overlay.dispose();
        await auth.dispose();
      });
      auth.emitCurrentAuthState();
      final generation = guard.currentSnapshot()!.generation;

      final update = source.completeProfile(
        expectedSession: AuthSessionIdentity(
          uid: 'owner-a',
          isAnonymous: false,
          authSessionGeneration: generation,
          tenantId: null,
        ),
        displayName: 'Owner A',
        currency: 'USD',
        language: 'en',
        country: 'US',
        timezone: 'UTC',
      );
      await updateStarted.future;
      auth.replaceCurrentUser(
        _FirebaseUser(uid: 'owner-b', idToken: 'token-b'),
      );
      releaseUpdate.complete();

      await expectLater(
        update,
        throwsA(
          isA<firebase_auth.FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'auth-session-changed',
          ),
        ),
      );
      expect(firestore.accesses, 0);
    },
  );

  test('typed owner keys match every production owner-scoped store', () {
    final identity = _identity('owner-a');
    final keys = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
      firebaseUid: identity.userId,
      ownerScope: identity.ownerScope,
    );
    final assistantScopeHash = sha256
        .convert(utf8.encode(identity.ownerScope.id.value))
        .toString();

    expect(
      keys.receiptAiPrivacyConsent,
      SettingsKeys.receiptAiPrivacyConsentForScopeHash(
        identity.ownerScope.id.value,
      ),
    );
    expect(
      keys.aiAgentMemory,
      SettingsKeys.aiAgentMemoryForScopeHash(assistantScopeHash),
    );
    expect(
      keys.aiAgentMemoryPersistence,
      SettingsKeys.aiAgentMemoryPersistenceForScopeHash(assistantScopeHash),
    );
    expect(
      keys.aiAppControlPolicy,
      '${SettingsKeys.aiAppControlPolicyPrefix}$assistantScopeHash',
    );
    expect(keys.values.join('|'), isNot(contains(identity.userId)));
  });

  test(
    'production preference writers are exactly covered by owner deletion',
    () async {
      final fixture = await _hiveFixture('production-writer-keys');
      addTearDown(fixture.dispose);
      final identityA = _identity('owner-a');
      final identityB = _identity('owner-b');
      final keysA = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: identityA.userId,
        ownerScope: identityA.ownerScope,
      );
      final keysB = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
        firebaseUid: identityB.userId,
        ownerScope: identityB.ownerScope,
      );
      final settings = SettingsLocalDataSource(fixture.box);
      final appControl = HiveAiAppControlSettingsStore(fixture.box);
      final operationFence = BackupOperationFence();

      Future<void> writeEveryOwnerPreference(
        TrustedDeletionIdentity identity, {
        required String baseCurrencyCode,
        required String memoryText,
      }) async {
        final keys = OwnerScopedStorageKeys.fromConfirmedFirebaseIdentity(
          firebaseUid: identity.userId,
          ownerScope: identity.ownerScope,
        );
        await settings.saveOwnerBaseCurrencyCode(
          identity.ownerScope,
          baseCurrencyCode,
        );
        await settings.saveAiAgentMemoryPersistenceEnabled(
          accountScope: identity.ownerScope.id.value,
          enabled: true,
        );
        await HiveAiAgentMemoryStore(
          settingsBox: fixture.box,
          persistenceEnabled: true,
          accountScope: keys.assistantScopeHash,
        ).save(
          AiAgentSessionMemory(
            messages: <AiAgentMessage>[
              AiAgentMessage(
                role: AiAgentMessageRole.user,
                content: memoryText,
                createdAt: DateTime.utc(2026, 8, 10),
              ),
            ],
          ),
        );
        await appControl.save(
          keys.assistantScopeHash,
          const AiAppControlSettings.conservative(),
        );
        await ReceiptPrivacyConsentStore(
          box: fixture.box,
          ownerScope: identity.ownerScope,
          operationFence: operationFence,
        ).accept();
        final sync = SyncPreferencesLocalDataSource(
          fixture.box,
          operationFence: operationFence,
        );
        await sync.saveBackupEnabled(identity.userId, true);
        await sync.saveInitialSnapshotComplete(identity.userId, true);
        await sync.saveLastBackupAt(identity.userId, DateTime.utc(2026, 8, 10));
      }

      await writeEveryOwnerPreference(
        identityA,
        baseCurrencyCode: 'USD',
        memoryText: 'owner A memory',
      );
      await writeEveryOwnerPreference(
        identityB,
        baseCurrencyCode: 'EUR',
        memoryText: 'owner B memory',
      );

      for (final key in keysA.accountDeletionPreferenceKeys) {
        expect(fixture.box.containsKey(key), isTrue, reason: key);
      }
      final ownerBValues = <String, Object?>{
        for (final key in keysB.accountDeletionPreferenceKeys)
          key: fixture.box.get(key),
      };
      expect(ownerBValues.values, everyElement(isNotNull));

      await HiveDeletionPreferencesDataSource(
        fixture.box,
      ).clearForIdentity(identityA);

      for (final key in keysA.accountDeletionPreferenceKeys) {
        expect(fixture.box.containsKey(key), isFalse, reason: key);
      }
      for (final key in keysB.accountDeletionPreferenceKeys) {
        expect(fixture.box.get(key), ownerBValues[key], reason: key);
      }
    },
  );

  test(
    'real sync preference writer keys are all removed by deletion',
    () async {
      final fixture = await _hiveFixture('sync-writer-keys');
      addTearDown(fixture.dispose);
      final identity = _identity('owner-a');
      final sync = SyncPreferencesLocalDataSource(
        fixture.box,
        operationFence: BackupOperationFence(),
      );

      await sync.saveBackupEnabled(identity.userId, true);
      await sync.saveInitialSnapshotComplete(identity.userId, true);
      await sync.saveLastBackupAt(identity.userId, DateTime.utc(2026, 8, 10));
      expect(sync.readBackupEnabled(identity.userId), isTrue);
      expect(sync.readConsentGeneration(identity.userId), 1);
      expect(sync.readInitialSnapshotComplete(identity.userId), isTrue);

      await HiveDeletionPreferencesDataSource(
        fixture.box,
      ).clearForIdentity(identity);

      expect(sync.readBackupEnabled(identity.userId), isFalse);
      expect(sync.readConsentGeneration(identity.userId), 0);
      expect(sync.readInitialSnapshotComplete(identity.userId), isFalse);
      expect(sync.readLastBackupAt(identity.userId), isNull);
    },
  );

  test(
    'durable operation state resumes without persisting the Firebase uid',
    () async {
      final fixture = await _hiveFixture('operation-state');
      addTearDown(fixture.dispose);
      final identity = _identity('private-firebase-uid');
      final context = DataDeletionOperationContext.captured(
        operationId: '01989f80-4e00-7000-8000-000000000001',
        identity: identity,
        startedAtUtc: DateTime.utc(2026, 8, 10, 9),
        idempotencyState: DataDeletionIdempotencyState.newOperation,
      );
      final store = HiveDataDeletionOperationStateStore(fixture.box);

      await store.checkpoint(
        context.advance(DataDeletionStage.reauthenticated),
      );
      final resumed = await store.read(identity);

      expect(resumed?.operationId, context.operationId);
      expect(resumed?.lastCompletedStage, DataDeletionStage.reauthenticated);
      expect(
        jsonEncode({
          'keys': fixture.box.keys.toList(),
          'values': fixture.box.values.toList(),
        }),
        isNot(contains(identity.userId)),
      );
    },
  );

  test(
    'corrupt deletion checkpoint fails closed instead of starting over',
    () async {
      final fixture = await _hiveFixture('corrupt-operation-state');
      addTearDown(fixture.dispose);
      final identity = _identity('owner-a');
      final key = OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        identity.ownerScope,
      ).dataDeletionOperationState;
      await fixture.box.put(key, '{invalid');

      await expectLater(
        HiveDataDeletionOperationStateStore(fixture.box).read(identity),
        throwsA(isA<DataDeletionOperationStateCorruptException>()),
      );
    },
  );

  test(
    'Hive terminal deletion stages are never accepted as completion authority',
    () async {
      final fixture = await _hiveFixture('forged-terminal-operation-state');
      addTearDown(fixture.dispose);
      final identity = _identity('owner-a');
      final key = OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        identity.ownerScope,
      ).dataDeletionOperationState;
      final store = HiveDataDeletionOperationStateStore(fixture.box);

      for (final terminal in <DataDeletionStage>[
        DataDeletionStage.authDeleted,
        DataDeletionStage.aborted,
      ]) {
        await fixture.box.put(
          key,
          jsonEncode(<String, Object>{
            'version': 1,
            'operationId': 'forged-terminal-operation',
            'startedAtUtc': DateTime.utc(2026, 8, 10).toIso8601String(),
            'lastCompletedStage': terminal.name,
          }),
        );
        await expectLater(
          store.read(identity),
          throwsA(isA<DataDeletionOperationStateCorruptException>()),
        );
      }

      final captured = DataDeletionOperationContext.captured(
        operationId: 'terminal-checkpoint-operation',
        identity: identity,
        startedAtUtc: DateTime.utc(2026, 8, 10),
      );
      final authDeleted = DataDeletionOperationContext(
        operationId: captured.operationId,
        identity: identity,
        stage: DataDeletionStage.authDeleted,
        startedAtUtc: captured.startedAtUtc,
        idempotencyState: captured.idempotencyState,
      );
      await expectLater(
        store.checkpoint(authDeleted),
        throwsA(isA<DataDeletionOperationStateCorruptException>()),
      );
    },
  );

  test(
    'concurrent operation claims keep one restart-consistent operation id',
    () async {
      final fixture = await _hiveFixture('operation-claim-race');
      addTearDown(fixture.dispose);
      final identity = _identity('owner-a');
      final stateStore = HiveDataDeletionOperationStateStore(fixture.box);

      final claims = await Future.wait(<Future<DataDeletionOperationClaim>>[
        stateStore.claim(
          identity,
          proposedOperationId: 'operation-claim-a',
          proposedStartedAtUtc: DateTime.utc(2026, 8, 10, 1),
        ),
        stateStore.claim(
          identity,
          proposedOperationId: 'operation-claim-b',
          proposedStartedAtUtc: DateTime.utc(2026, 8, 10, 2),
        ),
      ]);

      expect(
        claims.map((claim) => claim.operation.operationId).toSet(),
        hasLength(1),
      );
      expect(claims.where((claim) => claim.wasCreated), hasLength(1));
      final operationId = claims.first.operation.operationId;
      final quarantineStore = HiveOwnerDeletionQuarantineStore(fixture.box);
      final fence = BackupOperationFence(quarantineStore: quarantineStore);
      final deletionLease = await fence.fenceAndDrain(
        ownerScopeValue: identity.ownerScope.id.value,
        operationId: operationId,
        durable: true,
      );
      deletionLease.retainQuarantine();

      final restartedState = await HiveDataDeletionOperationStateStore(
        fixture.box,
      ).read(identity);
      final restartedFence = BackupOperationFence(
        quarantineStore: quarantineStore,
      );
      expect(restartedState?.operationId, operationId);
      expect(
        () => restartedFence.assertDeletionOperation(
          ownerScopeValue: identity.ownerScope.id.value,
          operationId: operationId,
        ),
        returnsNormally,
      );

      final conflictingContext = DataDeletionOperationContext.captured(
        operationId: 'operation-conflict',
        identity: identity,
        startedAtUtc: DateTime.utc(2026, 8, 10, 3),
      );
      await expectLater(
        stateStore.checkpoint(conflictingContext),
        throwsA(isA<DataDeletionOperationConflictException>()),
      );
      expect((await stateStore.read(identity))?.operationId, operationId);
    },
  );

  test(
    'same operation is resumable only after the active lease finishes',
    () async {
      final scope = _identity('owner-a').ownerScope.id.value;
      final fence = BackupOperationFence();
      final first = await fence.fenceAndDrain(
        ownerScopeValue: scope,
        operationId: '01989f80-4e00-7000-8000-000000000011',
        durable: true,
      );

      await expectLater(
        fence.fenceAndDrain(
          ownerScopeValue: scope,
          operationId: '01989f80-4e00-7000-8000-000000000011',
          durable: true,
        ),
        throwsStateError,
      );
      first.retainQuarantine();
      final resumed = await fence.fenceAndDrain(
        ownerScopeValue: scope,
        operationId: '01989f80-4e00-7000-8000-000000000011',
        durable: true,
      );
      resumed.retainQuarantine();
      expect(fence.isFenced(scope), isTrue);
    },
  );

  test(
    'durable quarantine survives restart and blocks delayed account and transaction writes',
    () async {
      final fixture = await _hiveFixture('durable-quarantine');
      addTearDown(fixture.dispose);
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      await database.customSelect('SELECT 1').get();
      final identity = _identity('owner-a');
      final scope = identity.ownerScope.id.value;
      final store = HiveOwnerDeletionQuarantineStore(fixture.box);
      final firstFence = BackupOperationFence(quarantineStore: store);
      final session = ScopedAppDatabaseSession(
        database: database,
        scope: identity.ownerScope,
        operationFence: firstFence,
      );
      final started = Completer<void>();
      final continueWrite = Completer<void>();
      final delayedAccountWrite = session.runGuardedWrite(() async {
        started.complete();
        await continueWrite.future;
        await session.database.customStatement(
          '''
          INSERT INTO accounts (
            id, owner_scope_id, name, type, currency_code, balance,
            icon, color, created_at, updated_at
          ) VALUES (?, ?, 'Delayed', 'cash', 'USD', '0', 'wallet', 1, 1, 1)
        ''',
          ['delayed-account', scope],
        );
      });
      await started.future;

      final deletion = firstFence.fenceAndDrain(
        ownerScopeValue: scope,
        operationId: '01989f80-4e00-7000-8000-000000000010',
        durable: true,
      );
      while (!firstFence.isFenced(scope)) {
        await Future<void>.delayed(Duration.zero);
      }
      continueWrite.complete();
      await expectLater(
        delayedAccountWrite,
        throwsA(isA<OwnerScopeException>()),
      );
      await deletion;
      expect(firstFence.tryAcquireWriter(scope), isNull);

      final restartedFence = BackupOperationFence(quarantineStore: store);
      final restartedSession = ScopedAppDatabaseSession(
        database: database,
        scope: identity.ownerScope,
        operationFence: restartedFence,
      );
      expect(restartedFence.isFenced(scope), isTrue);
      expect(restartedFence.tryAcquireWriter(scope), isNull);
      expect(
        () => restartedSession.database,
        throwsA(
          isA<OwnerScopeException>().having(
            (error) => error.failure,
            'failure',
            OwnerScopeFailure.deletionQuarantined,
          ),
        ),
      );
      var transactionWriteRan = false;
      await expectLater(
        restartedSession.runGuardedWrite(() async {
          transactionWriteRan = true;
        }),
        throwsA(isA<OwnerScopeException>()),
      );
      expect(transactionWriteRan, isFalse);
      final row = await database
          .customSelect(
            "SELECT COUNT(*) AS count FROM accounts WHERE id = 'delayed-account'",
          )
          .getSingle();
      expect(row.read<int>('count'), 0);
      expect(
        () => restartedFence.fenceAndDrain(
          ownerScopeValue: scope,
          operationId: '01989f80-4e00-7000-8000-000000000099',
          durable: true,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'writer drain is bounded and rolls back an unstarted quarantine',
    () async {
      final fixture = await _hiveFixture('quarantine-drain-timeout');
      addTearDown(fixture.dispose);
      final store = HiveOwnerDeletionQuarantineStore(fixture.box);
      final fence = BackupOperationFence(
        quarantineStore: store,
        drainTimeout: const Duration(milliseconds: 20),
      );
      final scope = _identity('owner-a').ownerScope.id.value;
      final writer = fence.tryAcquireWriter(scope)!;

      await expectLater(
        fence.fenceAndDrain(
          ownerScopeValue: scope,
          operationId: 'operation-timeout',
          durable: true,
        ),
        throwsA(isA<TimeoutException>()),
      );

      expect(fence.isFenced(scope), isFalse);
      expect(store.restore(), isEmpty);
      expect(
        () => writer.assertActive(),
        throwsA(isA<BackupWriterCancelledException>()),
      );
      writer.release();
      final replacementWriter = fence.tryAcquireWriter(scope);
      expect(replacementWriter, isNotNull);
      replacementWriter!.release();
    },
  );

  test(
    'receipt journal retains opaque work after failure and retries',
    () async {
      final fixture = await _hiveFixture('receipt-journal');
      addTearDown(fixture.dispose);
      final context = _context('owner-a', 'operation-retry');
      final imageStore = ReceiptLocalImageStore(
        ownerScopeValue: context.identity.ownerScope.id.value,
        baseDirectory: () async => fixture.directory,
      );
      final imagePath = await imageStore.write('receipt-a', const [1, 2, 3]);
      var failOnce = true;
      final journal = HiveReceiptFileDeletionJournal(
        fixture.box,
        receiptImageStore: imageStore,
        beforeDelete: (_) async {
          if (failOnce) {
            failOnce = false;
            throw StateError('simulated file failure');
          }
        },
      );
      await journal.stage(context, [imagePath]);
      expect(() => journal.drain(context), throwsStateError);
      expect(await File(imagePath).exists(), isTrue);
      expect(fixture.box.values.join('|'), isNot(contains(imagePath)));
      expect(await journal.drain(context), 1);
      expect(await File(imagePath).exists(), isFalse);
      expect(await journal.drain(context), 0);
    },
  );

  test(
    'receipt row and file survive a post-journal transaction failure',
    () async {
      final fixture = await _hiveFixture('receipt-drift-rollback');
      addTearDown(fixture.dispose);
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final context = _context('owner-a', 'operation-drift-rollback');
      final operationFence = BackupOperationFence();
      final session = ScopedAppDatabaseSession(
        database: database,
        scope: context.identity.ownerScope,
        operationFence: operationFence,
      );
      final deletionLease = await operationFence.fenceAndDrain(
        ownerScopeValue: session.ownerScopeValue,
        operationId: context.operationId,
      );
      addTearDown(deletionLease.release);
      final imageStore = ReceiptLocalImageStore(
        ownerScopeValue: session.ownerScopeValue,
        baseDirectory: () async => fixture.directory,
      );
      final imagePath = await imageStore.write('receipt-drift-rollback', const [
        1,
        2,
        3,
      ]);
      final now = DateTime.utc(2026, 8, 10);
      await database
          .into(database.receipts)
          .insert(
            ReceiptsCompanion.insert(
              id: 'receipt-drift-rollback',
              ownerScopeId: Value(session.ownerScopeValue),
              documentType: 'receipt',
              paymentStatus: 'paid',
              imageRetentionChoice: 'localOnly',
              localImageReference: Value(imagePath),
              status: 'draft',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final journal = HiveReceiptFileDeletionJournal(
        fixture.box,
        receiptImageStore: imageStore,
      );
      final local = DriftLocalUserDataDeletionDataSource(
        session,
        receiptFileJournal: journal,
      );
      const triggerName = 'fail_receipt_delete_after_journal_stage';
      await database.customStatement('''
        CREATE TEMP TRIGGER $triggerName
        BEFORE DELETE ON receipts
        BEGIN
          SELECT RAISE(ABORT, 'simulated receipt transaction failure');
        END
      ''');

      await expectLater(
        local.deleteLocalDatabase(context),
        throwsA(isA<Exception>()),
      );

      final journalKey = OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        context.identity.ownerScope,
      ).receiptFileDeletionJournal(context.operationId);
      expect(fixture.box.containsKey(journalKey), isTrue);
      expect(fixture.box.values.join('|'), isNot(contains(imagePath)));
      expect(
        await (database.select(
          database.receipts,
        )..where((row) => row.id.equals('receipt-drift-rollback'))).get(),
        hasLength(1),
      );
      expect(await File(imagePath).exists(), isTrue);

      await database.customStatement('DROP TRIGGER $triggerName');
      expect(await local.deleteLocalDatabase(context), 1);
      expect(
        await (database.select(
          database.receipts,
        )..where((row) => row.id.equals('receipt-drift-rollback'))).get(),
        isEmpty,
      );
      expect(await File(imagePath).exists(), isTrue);
      expect(await local.deleteReceiptFiles(context), 1);
      expect(await File(imagePath).exists(), isFalse);
    },
  );

  test(
    'receipt deletion includes pre-row orphans and preserves another owner',
    () async {
      final fixture = await _hiveFixture('receipt-orphans');
      addTearDown(fixture.dispose);
      final contextA = _context('owner-a', 'operation-orphans');
      final contextB = _context('owner-b', 'operation-owner-b');
      final storeA = ReceiptLocalImageStore(
        ownerScopeValue: contextA.identity.ownerScope.id.value,
        baseDirectory: () async => fixture.directory,
      );
      final storeB = ReceiptLocalImageStore(
        ownerScopeValue: contextB.identity.ownerScope.id.value,
        baseDirectory: () async => fixture.directory,
      );
      final orphanA = await storeA.write('orphan-before-row', const [1]);
      final imageB = await storeB.write('owner-b-image', const [2]);
      final journal = HiveReceiptFileDeletionJournal(
        fixture.box,
        receiptImageStore: storeA,
      );

      await journal.stage(contextA, const <String?>[]);
      expect(await journal.drain(contextA), 1);

      expect(await File(orphanA).exists(), isFalse);
      expect(await File(imageB).exists(), isTrue);
    },
  );

  test(
    'receipt deletion removes only referenced legacy images for the owner',
    () async {
      final fixture = await _hiveFixture('receipt-legacy-images');
      addTearDown(fixture.dispose);
      final contextA = _context('owner-a', 'operation-legacy-images');
      final legacyDirectory = Directory(
        path.join(fixture.directory.path, 'receipt_images'),
      );
      await legacyDirectory.create(recursive: true);
      final legacyA = File(
        path.join(
          legacyDirectory.path,
          '${sha256.convert('legacy-a'.codeUnits)}.jpg',
        ),
      );
      final legacyB = File(
        path.join(
          legacyDirectory.path,
          '${sha256.convert('legacy-b'.codeUnits)}.jpg',
        ),
      );
      await legacyA.writeAsBytes(const [1], flush: true);
      await legacyB.writeAsBytes(const [2], flush: true);
      final storeA = ReceiptLocalImageStore(
        ownerScopeValue: contextA.identity.ownerScope.id.value,
        baseDirectory: () async => fixture.directory,
      );
      final journal = HiveReceiptFileDeletionJournal(
        fixture.box,
        receiptImageStore: storeA,
      );

      await journal.stage(contextA, <String?>[legacyA.path]);
      expect(await journal.drain(contextA), 1);

      expect(await legacyA.exists(), isFalse);
      expect(await legacyB.exists(), isTrue);
    },
  );

  test(
    'retry journal cannot delete a legacy image still referenced by B',
    () async {
      final fixture = await _hiveFixture('receipt-shared-legacy-retry');
      addTearDown(fixture.dispose);
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final contextA = _context('owner-a', 'operation-shared-legacy');
      final contextB = _context('owner-b', 'operation-owner-b');
      final legacyDirectory = Directory(
        path.join(fixture.directory.path, 'receipt_images'),
      );
      await legacyDirectory.create(recursive: true);
      final sharedFile = File(
        path.join(
          legacyDirectory.path,
          '${sha256.convert('shared-legacy'.codeUnits)}.jpg',
        ),
      );
      final ownerAOnlyFile = File(
        path.join(
          legacyDirectory.path,
          '${sha256.convert('owner-a-only'.codeUnits)}.jpg',
        ),
      );
      await sharedFile.writeAsBytes(const [1], flush: true);
      await ownerAOnlyFile.writeAsBytes(const [2], flush: true);
      final now = DateTime.utc(2026, 8, 10);
      Future<void> insertReceipt({
        required String id,
        required String scope,
        required String imagePath,
      }) {
        return database
            .into(database.receipts)
            .insert(
              ReceiptsCompanion.insert(
                id: id,
                ownerScopeId: Value(scope),
                documentType: 'receipt',
                paymentStatus: 'paid',
                imageRetentionChoice: 'localOnly',
                localImageReference: Value(imagePath),
                status: 'draft',
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await insertReceipt(
        id: 'a-shared',
        scope: contextA.identity.ownerScope.id.value,
        imagePath: sharedFile.path,
      );
      await insertReceipt(
        id: 'a-only',
        scope: contextA.identity.ownerScope.id.value,
        imagePath: ownerAOnlyFile.path,
      );
      await insertReceipt(
        id: 'b-shared',
        scope: contextB.identity.ownerScope.id.value,
        imagePath: sharedFile.path,
      );

      final fence = BackupOperationFence();
      final sessionA = ScopedAppDatabaseSession(
        database: database,
        scope: contextA.identity.ownerScope,
        operationFence: fence,
      );
      final deletionLease = await fence.fenceAndDrain(
        ownerScopeValue: sessionA.ownerScopeValue,
        operationId: contextA.operationId,
      );
      addTearDown(deletionLease.release);
      var failOnce = true;
      final imageStore = ReceiptLocalImageStore(
        ownerScopeValue: sessionA.ownerScopeValue,
        baseDirectory: () async => fixture.directory,
      );
      final journal = HiveReceiptFileDeletionJournal(
        fixture.box,
        receiptImageStore: imageStore,
        beforeDelete: (_) async {
          if (failOnce) {
            failOnce = false;
            throw StateError('simulated retry boundary');
          }
        },
      );
      final local = DriftLocalUserDataDeletionDataSource(
        sessionA,
        receiptFileJournal: journal,
      );

      await local.deleteLocalDatabase(contextA);
      // Simulate a journal written by an older attempt before shared-reference
      // protection existed. The current retry must sanitize it again.
      await journal.stage(contextA, <String?>[
        sharedFile.path,
        ownerAOnlyFile.path,
      ]);
      await expectLater(local.deleteReceiptFiles(contextA), throwsStateError);
      expect(await sharedFile.exists(), isTrue);
      expect(await ownerAOnlyFile.exists(), isTrue);

      expect(await local.deleteReceiptFiles(contextA), 1);
      expect(await sharedFile.exists(), isTrue);
      expect(await ownerAOnlyFile.exists(), isFalse);
      final remainingB = await (database.select(
        database.receipts,
      )..where((row) => row.id.equals('b-shared'))).getSingleOrNull();
      expect(remainingB, isNotNull);
    },
  );

  test(
    'large receipt journals are chunked and repeatedly drain safely',
    () async {
      final fixture = await _hiveFixture('receipt-large-journal');
      addTearDown(fixture.dispose);
      final context = _context('owner-a', 'operation-large-journal');
      final ownerDirectory = Directory(
        path.join(
          fixture.directory.path,
          'receipt_images',
          context.identity.ownerScope.id.value,
        ),
      );
      await ownerDirectory.create(recursive: true);
      final legacyTokens = <String>[];
      for (var index = 0; index < 1025; index += 1) {
        final filename = '${sha256.convert('receipt-$index'.codeUnits)}.jpg';
        legacyTokens.add(filename);
        await File(
          path.join(ownerDirectory.path, filename),
        ).writeAsBytes(const [1]);
      }
      final store = ReceiptLocalImageStore(
        ownerScopeValue: context.identity.ownerScope.id.value,
        baseDirectory: () async => fixture.directory,
      );
      final journal = HiveReceiptFileDeletionJournal(
        fixture.box,
        receiptImageStore: store,
      );
      final journalKey = OwnerScopedStorageKeys.fromConfirmedOwnerScope(
        context.identity.ownerScope,
      ).receiptFileDeletionJournal(context.operationId);
      final oversizedLegacyJournal = jsonEncode(<String, Object>{
        'version': 1,
        'tokens': legacyTokens,
      });
      expect(oversizedLegacyJournal.length, greaterThan(64 * 1024));
      await fixture.box.put(journalKey, oversizedLegacyJournal);

      await journal.stage(context, const <String?>[]);

      expect(
        fixture.box.values.whereType<String>().every(
          (value) => value.length <= 64 * 1024,
        ),
        isTrue,
      );
      expect(await journal.drain(context), 1025);
      expect(await journal.drain(context), 0);
      expect(fixture.box.keys, isEmpty);
    },
  );

  test('corrupt or oversized receipt journal fails closed', () async {
    final fixture = await _hiveFixture('receipt-corrupt-journal');
    addTearDown(fixture.dispose);
    final context = _context('owner-a', 'operation-corrupt');
    final store = ReceiptLocalImageStore(
      ownerScopeValue: context.identity.ownerScope.id.value,
      baseDirectory: () async => fixture.directory,
    );
    final journal = HiveReceiptFileDeletionJournal(
      fixture.box,
      receiptImageStore: store,
    );
    final key = OwnerScopedStorageKeys.fromConfirmedOwnerScope(
      context.identity.ownerScope,
    ).receiptFileDeletionJournal(context.operationId);
    await fixture.box.put(key, '{not-json');
    await expectLater(
      journal.stage(context, const <String?>[]),
      throwsStateError,
    );
    await fixture.box.put(key, List.filled(64 * 1024 + 1, 'x').join());
    await expectLater(journal.drain(context), throwsStateError);
  });

  test('unknown future receipt staging files fail before journaling', () async {
    final fixture = await _hiveFixture('receipt-unknown-staging-file');
    addTearDown(fixture.dispose);
    final context = _context('owner-a', 'operation-unknown-staging');
    final ownerDirectory = Directory(
      path.join(
        fixture.directory.path,
        'receipt_images',
        context.identity.ownerScope.id.value,
      ),
    );
    await ownerDirectory.create(recursive: true);
    final unknown = File(path.join(ownerDirectory.path, 'capture.staging'));
    await unknown.writeAsBytes(const [1]);
    final journal = HiveReceiptFileDeletionJournal(
      fixture.box,
      receiptImageStore: ReceiptLocalImageStore(
        ownerScopeValue: context.identity.ownerScope.id.value,
        baseDirectory: () async => fixture.directory,
      ),
    );

    await expectLater(
      journal.stage(context, const <String?>[]),
      throwsStateError,
    );

    expect(await unknown.exists(), isTrue);
    expect(fixture.box.keys, isEmpty);
  });

  test(
    'completed deletion overlay hides cached A, preserves a new session, and survives restart',
    () async {
      final fixture = await _hiveFixture('completed-overlay');
      addTearDown(fixture.dispose);
      final userA = _FirebaseUser(uid: 'owner-a', idToken: 'token-a');
      final auth = _FirebaseAuth(userA, freshWrapperOnRead: true);
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = HiveCompletedAccountDeletionOverlay(
        box: fixture.box,
        sessionGuard: guard,
      );
      addTearDown(() async {
        await overlay.dispose();
        await guard.dispose();
        await auth.dispose();
      });
      auth.emitCurrentAuthState();
      final snapshot = guard.currentSnapshot()!;
      var overlayEvents = 0;
      final subscription = overlay.changes.listen((_) => overlayEvents += 1);
      addTearDown(subscription.cancel);

      await overlay.markCompleted(
        ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a'),
        capturedAuthGeneration: snapshot.generation,
        operationId: 'operation-overlay-a',
      );

      expect(overlayEvents, 1);
      expect(overlay.shouldSuppress(auth.currentUser), isTrue);

      final replacementA = _FirebaseUser(
        uid: 'owner-a',
        idToken: 'new-session-token-a',
      );
      auth.replaceCurrentUser(replacementA);
      expect(overlay.shouldSuppress(auth.currentUser), isFalse);

      final restartedAuth = _FirebaseAuth(
        _FirebaseUser(uid: 'owner-a', idToken: 'cached-token-a'),
        freshWrapperOnRead: true,
      );
      final restartedGuard = FirebaseAuthSessionEpochGuard(restartedAuth);
      final restartedOverlay = HiveCompletedAccountDeletionOverlay(
        box: fixture.box,
        sessionGuard: restartedGuard,
      );
      addTearDown(() async {
        await restartedOverlay.dispose();
        await restartedGuard.dispose();
        await restartedAuth.dispose();
      });
      restartedAuth.emitCurrentAuthState();

      expect(
        restartedOverlay.shouldSuppress(restartedAuth.currentUser),
        isTrue,
      );
    },
  );

  test(
    'failed durable completion write still suppresses cached A in memory',
    () async {
      final fixture = await _hiveFixture('failed-completed-overlay');
      addTearDown(fixture.dispose);
      final auth = _FirebaseAuth(
        _FirebaseUser(uid: 'owner-a', idToken: 'token-a'),
      );
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = HiveCompletedAccountDeletionOverlay(
        box: fixture.box,
        sessionGuard: guard,
      );
      addTearDown(() async {
        await overlay.dispose();
        await guard.dispose();
        await auth.dispose();
      });
      auth.emitCurrentAuthState();
      final snapshot = guard.currentSnapshot()!;
      var overlayEvents = 0;
      final subscription = overlay.changes.listen((_) => overlayEvents += 1);
      addTearDown(subscription.cancel);
      await fixture.box.close();

      await expectLater(
        overlay.markCompleted(
          ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid('owner-a'),
          capturedAuthGeneration: snapshot.generation,
          operationId: 'operation-overlay-failure',
        ),
        throwsA(anything),
      );

      expect(overlayEvents, 1);
      expect(overlay.shouldSuppress(auth.currentUser), isTrue);
    },
  );

  test(
    'cloud gateway sends no uid and requires verified recursive deletion',
    () async {
      late http.Request captured;
      final context = _context('owner-a', 'operation-cloud');
      final source = HttpRecursiveCloudUserDataDeletionDataSource(
        config: AccountDeletionGatewayConfig(
          baseUri: Uri.parse('https://gateway.example'),
        ),
        tokenProvider: const _Tokens(),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'operationId': context.operationId,
              'status': 'completed',
              'verifiedEmpty': true,
              'deletedDocuments': 7,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final receipt = await source.deleteUserData(context);

      expect(captured.url.path, '/v1/account-deletion/recursive');
      expect(captured.body, isNot(contains(context.identity.userId)));
      expect(jsonDecode(captured.body), {
        'operationId': context.operationId,
        'targetOwnerScope': context.identity.ownerScope.id.value,
      });
      expect(receipt.verifiedEmpty, isTrue);
      expect(receipt.deletedDocuments, 7);
    },
  );

  test(
    'cloud gateway fails closed when server cannot verify emptiness',
    () async {
      final context = _context('owner-a', 'operation-unverified');
      final source = HttpRecursiveCloudUserDataDeletionDataSource(
        config: AccountDeletionGatewayConfig(
          baseUri: Uri.parse('https://gateway.example'),
        ),
        tokenProvider: const _Tokens(),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'operationId': context.operationId,
              'status': 'pending',
              'verifiedEmpty': false,
              'deletedDocuments': 0,
            }),
            202,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      expect(() => source.deleteUserData(context), throwsStateError);
    },
  );

  test(
    'fresh same-session wrappers work and same-uid auth event is stale',
    () async {
      final capturedUser = _FirebaseUser(
        uid: 'owner-a',
        idToken: 'captured-user-token',
      );
      final replacementUser = _FirebaseUser(
        uid: 'owner-a',
        idToken: 'replacement-user-token',
      );
      final auth = _FirebaseAuth(capturedUser, freshWrapperOnRead: true);
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final overlay = _MemoryCompletedDeletionOverlay();
      auth.emitCurrentAuthState();
      final source = FirebaseAccountDeletionAuthDataSource(
        auth: auth,
        sessionGuard: guard,
        completedDeletionOverlay: overlay,
        operationCoordinator: FirebaseAuthOperationCoordinator(),
        oauthCredentialProvider: _UnavailableOAuthCredentialProvider(),
      );
      addTearDown(() async {
        await source.dispose();
        await guard.dispose();
        await overlay.dispose();
        await auth.dispose();
      });
      final lease = await source.issueConfirmationLease();
      final identity = await source.captureSession(lease);
      final context = DataDeletionOperationContext.captured(
        operationId: 'operation-captured-token',
        identity: identity,
        startedAtUtc: DateTime.utc(2026, 8, 10),
      );

      expect(await source.freshIdToken(context), 'captured-user-token');
      expect(capturedUser.tokenRequests, 1);
      expect(replacementUser.tokenRequests, 0);

      auth.replaceCurrentUser(replacementUser);

      expect(
        () => source.assertSessionCurrent(context),
        throwsA(isA<AccountDeletionIdentityChangedException>()),
      );
      expect(replacementUser.tokenRequests, 0);
    },
  );

  test(
    'same-uid session replacement at paused dispatch boundary makes zero gateway calls',
    () async {
      final context = _context('owner-a', 'operation-paused-boundary');
      final tokenProvider = _PausedBoundaryTokens();
      var gatewayCalls = 0;
      final source = HttpRecursiveCloudUserDataDeletionDataSource(
        config: AccountDeletionGatewayConfig(
          baseUri: Uri.parse('https://gateway.example'),
        ),
        tokenProvider: tokenProvider,
        httpClient: MockClient((_) async {
          gatewayCalls += 1;
          return http.Response('{}', 500);
        }),
      );

      final deletion = source.deleteUserData(context);
      await tokenProvider.tokenMintStarted.future;
      tokenProvider.replaceWithSameUidSession();
      tokenProvider.releaseMint.complete();

      await expectLater(deletion, throwsStateError);
      expect(gatewayCalls, 0);
    },
  );

  test(
    'auth gateway sends only the opaque target and requires verified receipt',
    () async {
      late http.Request captured;
      final context = _context('owner-a', 'operation-auth-delete');
      final source = HttpAccountAuthDeletionDataSource(
        config: AccountDeletionGatewayConfig(
          baseUri: Uri.parse('https://gateway.example'),
        ),
        tokenProvider: const _Tokens(),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'operationId': context.operationId,
              'status': 'completed',
              'authDeleted': true,
              'alreadyDeleted': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final receipt = await source.deleteAuthAccount(context);

      expect(captured.url.path, '/v1/account-deletion/auth');
      expect(captured.body, isNot(contains(context.identity.userId)));
      expect(jsonDecode(captured.body), {
        'operationId': context.operationId,
        'targetOwnerScope': context.identity.ownerScope.id.value,
      });
      expect(receipt.authDeleted, isTrue);
      expect(receipt.alreadyDeleted, isFalse);
    },
  );

  test(
    'server commitment rejects a native B token before Auth mutation',
    () async {
      final context = _context('owner-a', 'operation-native-token-escape');
      var authMutations = 0;
      final source = HttpAccountAuthDeletionDataSource(
        config: AccountDeletionGatewayConfig(
          baseUri: Uri.parse('https://gateway.example'),
        ),
        tokenProvider: const _Tokens(authToken: 'token-for-owner-b'),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final bearerBelongsToB =
              request.headers['authorization'] == 'Bearer token-for-owner-b';
          final committedToA =
              body['targetOwnerScope'] == context.identity.ownerScope.id.value;
          if (bearerBelongsToB && committedToA) {
            return http.Response(
              '{"error":"identity_commitment_mismatch"}',
              409,
            );
          }
          authMutations += 1;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(source.deleteAuthAccount(context), throwsStateError);
      expect(authMutations, 0);
    },
  );

  test('account deletion transport requires HTTPS except debug loopback', () {
    expect(
      () => AccountDeletionGatewayConfig(
        baseUri: Uri.parse('http://gateway.example'),
      ).recursiveDeletionEndpoint,
      throwsStateError,
    );
    expect(
      AccountDeletionGatewayConfig(
        baseUri: Uri.parse('http://127.0.0.1:8080'),
      ).recursiveDeletionEndpoint.scheme,
      'http',
    );
  });
}

final class _Tokens implements AccountDeletionGatewayTokenProvider {
  const _Tokens({this.authToken = 'auth-token'});

  final String authToken;

  @override
  Future<AccountDeletionGatewayTokens> freshTokens(
    DataDeletionOperationContext context,
  ) async => AccountDeletionGatewayTokens(
    authToken: authToken,
    appCheckToken: 'app-check-token',
    deletionSessionProof: AccountDeletionSessionProof.parse(
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    ),
  );

  @override
  Future<AccountDeletionGatewayTokens> finalizationRecoveryTokens(
    DataDeletionOperationContext context,
  ) => freshTokens(context);

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) {}
}

final class _PausedBoundaryTokens
    implements AccountDeletionGatewayTokenProvider {
  final Object _capturedSession = Object();
  late Object _currentSession = _capturedSession;
  final Completer<void> tokenMintStarted = Completer<void>();
  final Completer<void> releaseMint = Completer<void>();

  void replaceWithSameUidSession() {
    _currentSession = Object();
  }

  @override
  Future<AccountDeletionGatewayTokens> freshTokens(
    DataDeletionOperationContext context,
  ) async {
    tokenMintStarted.complete();
    await releaseMint.future;
    return AccountDeletionGatewayTokens(
      authToken: 'captured-auth-token',
      appCheckToken: 'app-check-token',
      deletionSessionProof: AccountDeletionSessionProof.parse(
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      ),
    );
  }

  @override
  Future<AccountDeletionGatewayTokens> finalizationRecoveryTokens(
    DataDeletionOperationContext context,
  ) => freshTokens(context);

  @override
  void assertSessionCurrent(DataDeletionOperationContext context) {
    if (!identical(_capturedSession, _currentSession)) {
      throw StateError('The authenticated deletion identity changed.');
    }
  }
}

final class _FirebaseAuth implements firebase_auth.FirebaseAuth {
  _FirebaseAuth(this._currentUser, {this.freshWrapperOnRead = false});

  firebase_auth.User? _currentUser;
  final bool freshWrapperOnRead;
  final StreamController<firebase_auth.User?> _authStates =
      StreamController<firebase_auth.User?>.broadcast(sync: true);
  final StreamController<firebase_auth.User?> _userStates =
      StreamController<firebase_auth.User?>.broadcast(sync: true);

  @override
  firebase_auth.User? get currentUser {
    final user = _currentUser;
    if (freshWrapperOnRead && user is _FirebaseUser) {
      return user.freshWrapper();
    }
    return user;
  }

  @override
  Stream<firebase_auth.User?> authStateChanges() => _authStates.stream;

  @override
  Stream<firebase_auth.User?> userChanges() => _userStates.stream;

  void replaceCurrentUser(firebase_auth.User user) {
    _currentUser = user;
    _authStates.add(currentUser);
    _userStates.add(currentUser);
  }

  void replaceViaUserChangesOnly(firebase_auth.User user) {
    _currentUser = user;
    _userStates.add(currentUser);
  }

  void emitCurrentAuthState() => _authStates.add(currentUser);

  void setCurrentUserWithoutEvent(firebase_auth.User? user) {
    _currentUser = user;
  }

  void emitAuthStateFor(firebase_auth.User? user) => _authStates.add(user);

  void emitAuthError(Object error) => _authStates.addError(error);

  Future<void> closeAuthStateOnly() => _authStates.close();

  Future<void> dispose() async {
    if (!_authStates.isClosed) {
      await _authStates.close();
    }
    if (!_userStates.isClosed) {
      await _userStates.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FirebaseUser implements firebase_auth.User {
  _FirebaseUser({
    required String uid,
    required String idToken,
    this.tenantId,
    this.updateDisplayNameStarted,
    this.releaseDisplayNameUpdate,
  }) : _state = _FirebaseUserState(uid: uid, idToken: idToken);

  _FirebaseUser.fromState(
    this._state, {
    this.tenantId,
    this.updateDisplayNameStarted,
    this.releaseDisplayNameUpdate,
  });

  final _FirebaseUserState _state;
  final Completer<void>? updateDisplayNameStarted;
  final Completer<void>? releaseDisplayNameUpdate;

  @override
  String get uid => _state.uid;

  String get idToken => _state.idToken;

  int get tokenRequests => _state.tokenRequests;

  _FirebaseUser freshWrapper() => _FirebaseUser.fromState(
    _state,
    tenantId: tenantId,
    updateDisplayNameStarted: updateDisplayNameStarted,
    releaseDisplayNameUpdate: releaseDisplayNameUpdate,
  );

  @override
  String? get email => 'person@example.com';

  @override
  bool get emailVerified => true;

  @override
  String? get displayName => null;

  @override
  String? get photoURL => null;

  @override
  firebase_auth.UserMetadata get metadata => _state.metadata;

  @override
  bool get isAnonymous => false;

  @override
  final String? tenantId;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    _state.tokenRequests += 1;
    return idToken;
  }

  @override
  Future<void> updateDisplayName(String? displayName) async {
    final started = updateDisplayNameStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    await releaseDisplayNameUpdate?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FirebaseUserState {
  _FirebaseUserState({required this.uid, required this.idToken});

  final String uid;
  final String idToken;
  final firebase_auth.UserMetadata metadata = _FirebaseUserMetadata();
  var tokenRequests = 0;
}

final class _FirebaseUserMetadata extends firebase_auth.UserMetadata {
  _FirebaseUserMetadata() : super(0, 0);
}

final class _CountingFirebaseFirestore
    implements cloud_firestore.FirebaseFirestore {
  var accesses = 0;

  @override
  cloud_firestore.CollectionReference<Map<String, dynamic>> collection(
    String collectionPath,
  ) {
    accesses += 1;
    return _HydratedProfileCollection(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    accesses += 1;
    return super.noSuchMethod(invocation);
  }
}

// ignore: subtype_of_sealed_class
final class _HydratedProfileCollection
    implements cloud_firestore.CollectionReference<Map<String, dynamic>> {
  const _HydratedProfileCollection(this.firestore);

  @override
  final _CountingFirebaseFirestore firestore;

  @override
  cloud_firestore.DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _HydratedProfileDocument(firestore, path ?? 'unknown');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
final class _HydratedProfileDocument
    implements cloud_firestore.DocumentReference<Map<String, dynamic>> {
  const _HydratedProfileDocument(this.firestore, this.id);

  @override
  final _CountingFirebaseFirestore firestore;

  @override
  final String id;

  @override
  Future<cloud_firestore.DocumentSnapshot<Map<String, dynamic>>> get([
    cloud_firestore.GetOptions? options,
  ]) async {
    firestore.accesses += 1;
    return _HydratedProfileSnapshot(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
final class _HydratedProfileSnapshot
    implements cloud_firestore.DocumentSnapshot<Map<String, dynamic>> {
  const _HydratedProfileSnapshot(this.id);

  @override
  final String id;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => const <String, dynamic>{
    'currency': 'LYD',
    'language': 'en',
    'country': 'LY',
    'timezone': 'UTC',
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedProfileFirebaseFirestore
    implements cloud_firestore.FirebaseFirestore {
  _DelayedProfileFirebaseFirestore(this.delayedUid, {this.failReads = false});

  final String delayedUid;
  final bool failReads;
  final Completer<void> delayedReadStarted = Completer<void>();
  final Completer<void> releaseDelayedRead = Completer<void>();

  @override
  cloud_firestore.CollectionReference<Map<String, dynamic>> collection(
    String collectionPath,
  ) => _DelayedProfileCollection(this);

  Future<cloud_firestore.DocumentSnapshot<Map<String, dynamic>>> read(
    String? uid,
  ) async {
    if (uid == delayedUid) {
      if (!delayedReadStarted.isCompleted) {
        delayedReadStarted.complete();
      }
      await releaseDelayedRead.future;
    }
    if (failReads) {
      throw StateError('Synthetic profile read failure.');
    }
    return _HydratedProfileSnapshot(uid ?? 'unknown');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
final class _DelayedProfileCollection
    implements cloud_firestore.CollectionReference<Map<String, dynamic>> {
  const _DelayedProfileCollection(this.firestore);

  @override
  final _DelayedProfileFirebaseFirestore firestore;

  @override
  cloud_firestore.DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _DelayedProfileDocument(firestore, path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
final class _DelayedProfileDocument
    implements cloud_firestore.DocumentReference<Map<String, dynamic>> {
  const _DelayedProfileDocument(this.firestore, this.uid);

  @override
  final _DelayedProfileFirebaseFirestore firestore;
  final String? uid;

  @override
  Future<cloud_firestore.DocumentSnapshot<Map<String, dynamic>>> get([
    cloud_firestore.GetOptions? options,
  ]) => firestore.read(uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MemoryCompletedDeletionOverlay
    implements CompletedAccountDeletionOverlay {
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool shouldSuppress(firebase_auth.User? user) => false;

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) => false;

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

final class _CanonicalUidAssertingOverlay
    implements CompletedAccountDeletionOverlay {
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  var invalidUidCalls = 0;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool shouldSuppress(firebase_auth.User? user) {
    if (user != null) {
      try {
        OwnerScopeDerivation.fromConfirmedFirebaseUid(user.uid);
      } on Object {
        invalidUidCalls++;
        rethrow;
      }
    }
    return false;
  }

  @override
  bool hasTrustedCompletion({
    required String operationId,
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
  }) => false;

  @override
  Future<void> markCompleted({
    required ConfirmedOwnerScope ownerScope,
    required int capturedAuthGeneration,
    required String operationId,
  }) async {}

  Future<void> dispose() => _changes.close();
}

TrustedDeletionIdentity _identity(String uid) => TrustedDeletionIdentity(
  authSessionId: 'session-$uid',
  authStateGeneration: 1,
  userId: uid,
  isAnonymous: false,
  ownerScope: OwnerScopeDerivation.fromConfirmedFirebaseUid(uid),
);

DataDeletionOperationContext _context(String uid, String operationId) =>
    DataDeletionOperationContext.captured(
      operationId: operationId,
      identity: _identity(uid),
      startedAtUtc: DateTime.utc(2026, 8, 10),
      idempotencyState: DataDeletionIdempotencyState.newOperation,
    );

Future<_HiveFixture> _hiveFixture(String name) async {
  final directory = await Directory.systemTemp.createTemp('cashpilot-$name-');
  Hive.init(directory.path);
  final box = await Hive.openBox<dynamic>(name);
  return _HiveFixture(directory, box);
}

final class _HiveFixture {
  const _HiveFixture(this.directory, this.box);

  final Directory directory;
  final Box<dynamic> box;

  Future<void> dispose() async {
    await box.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

final class _UnavailableOAuthCredentialProvider
    implements FirebaseOAuthCredentialProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
