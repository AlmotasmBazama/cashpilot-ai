import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/database/app_database_provider.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_command_runtime.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/app_agent/drift_app_agent_stores.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scoped_database_test_helper.dart';

const _userA = AuthUser(
  uid: 'synthetic-owner-a',
  emailVerified: true,
  isAnonymous: false,
);
const _userB = AuthUser(
  uid: 'synthetic-owner-b',
  emailVerified: true,
  isAnonymous: false,
);

void main() {
  test(
    'token refresh preserves the scoped session and same-UID relogin replaces it',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
      addTearDown(database.close);
      final auth = StreamController<AuthUser?>.broadcast();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith((_) => auth.stream),
          backupOperationFenceProvider.overrideWithValue(
            BackupOperationFence(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      const firstSession = AuthUser(
        uid: 'same-uid-owner',
        emailVerified: true,
        isAnonymous: false,
        authSessionGeneration: 7,
      );
      auth.add(firstSession);
      final initialSnapshot = await _waitForSnapshot(
        container,
        (snapshot) => snapshot.status == OwnerScopeStatus.safe,
      );
      final original = container.read(requiredScopedAppDatabaseSessionProvider);

      auth.add(firstSession.copyWith(email: 'refreshed@example.com'));
      await pumpEventQueue(times: 10);
      expect(
        container.read(requiredScopedAppDatabaseSessionProvider),
        same(original),
      );

      auth.add(
        firstSession.copyWith(
          email: 'new-login@example.com',
          authSessionGeneration: 8,
        ),
      );
      await _waitForSnapshot(
        container,
        (snapshot) =>
            snapshot.status == OwnerScopeStatus.safe &&
            !identical(snapshot.scope, initialSnapshot.scope),
      );
      await pumpEventQueue(times: 5);
      expect(
        container.read(scopedAppDatabaseSessionProvider),
        isNot(same(original)),
      );
      expect(original.isActive, isFalse);
    },
  );

  test(
    'tenant-scoped same-UID identities never expose a scoped session',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final auth = StreamController<AuthUser?>.broadcast();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith((_) => auth.stream),
          backupOperationFenceProvider.overrideWithValue(
            BackupOperationFence(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      for (final entry in const <(String, int)>[
        ('', 1),
        ('tenant-alpha', 2),
        ('tenant-beta', 3),
      ]) {
        auth.add(
          AuthUser(
            uid: 'shared-tenant-uid',
            emailVerified: true,
            isAnonymous: false,
            tenantId: entry.$1,
            authSessionGeneration: entry.$2,
          ),
        );
        final snapshot = await _waitForSnapshot(
          container,
          (value) => value.status == OwnerScopeStatus.corrupted,
        );
        expect(snapshot.scope, isNull);
        expect(container.read(scopedAppDatabaseSessionProvider), isNull);
      }
    },
  );

  test(
    'rapid A to B to A waits for old detach and preserves new A durable rows',
    () async {
      final database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      await database.customSelect('SELECT 1').get();
      addTearDown(database.close);
      final auth = StreamController<AuthUser?>.broadcast();
      addTearDown(auth.close);
      final operationFence = BackupOperationFence();
      final detacher = _DelayedFirstDetach(
        DriftOwnerScopeDetachService(database, operationFence),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith((_) => auth.stream),
          backupOperationFenceProvider.overrideWithValue(operationFence),
          ownerScopeDetachServiceProvider.overrideWithValue(detacher),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      auth.add(_userA);
      final initialA = await _waitForSnapshot(
        container,
        (snapshot) =>
            snapshot.status == OwnerScopeStatus.safe &&
            snapshot.scope?.id.value ==
                OwnerScopeDerivation.fromConfirmedFirebaseUid(
                  _userA.uid,
                ).id.value,
      );
      final scopeA = initialA.scope!.id.value;
      final old = await _seedConfirmedCommand(
        database,
        syntheticUid: _userA.uid,
        id: 'old-a-command',
      );
      await _insertPlan(
        database,
        scope: scopeA,
        id: 'old-a-plan',
        commandId: old.commandId,
      );

      auth
        ..add(_userB)
        ..add(_userA);
      await detacher.started.future;
      await pumpEventQueue();
      expect(
        container.read(confirmedOwnerScopeSnapshotProvider).status ==
            OwnerScopeStatus.safe,
        isFalse,
      );

      detacher.finishFirstDetach();
      final restoredA = await _waitForSnapshot(
        container,
        (snapshot) =>
            snapshot.status == OwnerScopeStatus.safe &&
            snapshot.scope?.id.value == scopeA &&
            snapshot.scope?.confirmedAt != initialA.scope?.confirmedAt,
      );
      expect(restoredA.scope?.id.value, scopeA);

      final current = await _seedConfirmedCommand(
        database,
        syntheticUid: _userA.uid,
        id: 'new-a-command',
      );
      await _insertPlan(
        database,
        scope: scopeA,
        id: 'new-a-plan',
        commandId: current.commandId,
      );
      await pumpEventQueue(times: 20);

      final oldCommand = await (database.select(
        database.aiAgentCommands,
      )..where((row) => row.id.equals(old.commandId))).getSingle();
      final newCommand = await (database.select(
        database.aiAgentCommands,
      )..where((row) => row.id.equals(current.commandId))).getSingle();
      final oldPlan = await (database.select(
        database.aiAgentPlans,
      )..where((row) => row.id.equals('old-a-plan'))).getSingle();
      final newPlan = await (database.select(
        database.aiAgentPlans,
      )..where((row) => row.id.equals('new-a-plan'))).getSingle();
      final oldProofRows = await (database.select(
        database.aiAgentConfirmationProofs,
      )..where((row) => row.commandId.equals(old.commandId))).get();
      final newProofRows = await (database.select(
        database.aiAgentConfirmationProofs,
      )..where((row) => row.commandId.equals(current.commandId))).get();

      expect(oldCommand.status, AppAgentCommandStatus.cancelled.name);
      expect(oldPlan.status, 'cancelled');
      expect(oldProofRows, isEmpty);
      expect(newCommand.status, AppAgentCommandStatus.confirmed.name);
      expect(newPlan.status, 'readyForPreview');
      expect(newProofRows, hasLength(1));

      final proofStore = DriftAppAgentConfirmationProofStore(
        scopedTestSession(database, syntheticFirebaseUid: _userA.uid),
      );
      expect(
        await proofStore.consumeProof(
          commandId: old.commandId,
          accountScope: scopeA,
          proof: old.authorityProof,
          method: old.method,
          now: DateTime.now().toUtc(),
        ),
        isFalse,
      );
      expect(
        await proofStore.consumeProof(
          commandId: current.commandId,
          accountScope: scopeA,
          proof: current.authorityProof,
          method: current.method,
          now: DateTime.now().toUtc(),
        ),
        isTrue,
      );
    },
  );

  test(
    'A writer drains before owner B is exposed and new A writers are closed',
    () async {
      final database = AppDatabase(
        executor: NativeDatabase.memory(),
        enforceOwnerScopeGuards: true,
      );
      await database.customSelect('SELECT 1').get();
      addTearDown(database.close);
      final auth = StreamController<AuthUser?>.broadcast();
      addTearDown(auth.close);
      final operationFence = BackupOperationFence();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith((_) => auth.stream),
          backupOperationFenceProvider.overrideWithValue(operationFence),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        confirmedOwnerScopeSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      auth.add(_userA);
      final initialA = await _waitForSnapshot(
        container,
        (snapshot) =>
            snapshot.status == OwnerScopeStatus.safe &&
            snapshot.scope?.id ==
                OwnerScopeDerivation.fromConfirmedFirebaseUid(_userA.uid).id,
      );
      final scopeA = initialA.scope!.id.value;
      final sessionA = container.read(requiredScopedAppDatabaseSessionProvider);
      final writerStarted = Completer<void>();
      final finishWriter = Completer<void>();
      final writer = sessionA.runGuardedWrite(() async {
        writerStarted.complete();
        await finishWriter.future;
      });
      await writerStarted.future;

      auth.add(_userB);
      await _waitUntil(() => operationFence.isFenced(scopeA));
      final whileDraining = container.read(confirmedOwnerScopeSnapshotProvider);
      expect(whileDraining.status, OwnerScopeStatus.initializing);
      expect(whileDraining.scope, isNull);
      expect(operationFence.tryAcquireWriter(scopeA), isNull);

      finishWriter.complete();
      await expectLater(writer, throwsA(isA<BackupWriterCancelledException>()));
      final ownerB = await _waitForSnapshot(
        container,
        (snapshot) =>
            snapshot.status == OwnerScopeStatus.safe &&
            snapshot.scope?.id ==
                OwnerScopeDerivation.fromConfirmedFirebaseUid(_userB.uid).id,
      );
      expect(ownerB.scope?.id.value, isNot(scopeA));
      expect(operationFence.isFenced(scopeA), isFalse);
    },
  );

  test('owner detach never releases an account-deletion fence', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    addTearDown(database.close);
    final operationFence = BackupOperationFence();
    final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
      _userA.uid,
    ).id.value;
    final deletionLease = await operationFence.fenceAndDrain(
      ownerScopeValue: scope,
      operationId: 'account-deletion-operation',
    );

    await DriftOwnerScopeDetachService(database, operationFence).detach(scope);

    expect(operationFence.isFenced(scope), isTrue);
    expect(operationFence.tryAcquireWriter(scope), isNull);
    deletionLease.release();
    expect(operationFence.isFenced(scope), isFalse);
  });
}

Future<OwnerScopeSnapshot> _waitForSnapshot(
  ProviderContainer container,
  bool Function(OwnerScopeSnapshot snapshot) predicate,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final snapshot = container.read(confirmedOwnerScopeSnapshotProvider);
    if (predicate(snapshot)) return snapshot;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Owner scope transition did not complete.');
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Expected owner transition state was not reached.');
}

Future<AppAgentConfirmation> _seedConfirmedCommand(
  AppDatabase database, {
  required String syntheticUid,
  required String id,
}) async {
  final session = scopedTestSession(
    database,
    syntheticFirebaseUid: syntheticUid,
  );
  final store = DriftAppAgentCommandStore(
    session: session,
    canonicalDescriptors: const <AppAgentModelProposalDescriptor>[
      AppAgentModelProposalDescriptor(
        toolId: 'createExpenseDraft',
        permission: AgentPermission.createDraft,
        risk: AgentActionRisk.medium,
        modelCallable: false,
      ),
    ],
  );
  final proofStore = DriftAppAgentConfirmationProofStore(session);
  final now = DateTime.now().toUtc();
  final command = AppAgentCommand(
    commandId: id,
    conversationId: 'conversation-$id',
    userAccountScope: session.ownerScopeValue,
    commandType: AppAgentCommandType.create,
    toolId: 'createExpenseDraft',
    normalizedArguments: const <String, Object?>{
      'amount': '10.00',
      'currency': 'LYD',
      'accountRef': 'opaque-account',
      'categoryRef': 'opaque-category',
    },
    permission: AgentPermission.createDraft,
    risk: AgentActionRisk.medium,
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 10)),
    status: AppAgentCommandStatus.readyForPreview,
  );
  await store.saveTrustedLocalCommand(command);
  await store.savePreview(
    preview: AppAgentPreview(
      commandId: id,
      title: 'Create expense',
      entityType: 'transaction',
      fields: const <AppAgentPreviewField>[
        AppAgentPreviewField(label: 'Amount', proposedValue: 'LYD 10.00'),
      ],
      risk: AgentActionRisk.medium,
      confirmationLevel: AppAgentConfirmationLevel.detailed,
      stateFingerprint: 'fingerprint-$id',
      createdAt: now,
    ),
    accountScope: session.ownerScopeValue,
  );
  final decision =
      await AppAgentConfirmationController(
        commandStore: store,
        proofStore: proofStore,
        clock: () => now.add(const Duration(seconds: 1)),
      ).confirm(
        commandId: id,
        accountScope: session.ownerScopeValue,
        method: AppAgentConfirmationMethod.primaryButton,
      );
  return decision.confirmation!;
}

Future<void> _insertPlan(
  AppDatabase database, {
  required String scope,
  required String id,
  required String commandId,
}) async {
  final now = DateTime.now().toUtc();
  await database
      .into(database.aiAgentPlans)
      .insert(
        AiAgentPlansCompanion.insert(
          id: id,
          ownerScopeId: scope,
          conversationId: 'conversation-$id',
          status: 'readyForPreview',
          expiresAt: now.add(const Duration(minutes: 10)),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await database
      .into(database.aiAgentPlanSteps)
      .insert(
        AiAgentPlanStepsCompanion.insert(
          id: '$id-step',
          ownerScopeId: scope,
          planId: id,
          commandId: commandId,
          position: 0,
          status: 'readyForPreview',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

final class _DelayedFirstDetach implements OwnerScopeDetachService {
  _DelayedFirstDetach(this._delegate);

  final OwnerScopeDetachService _delegate;
  final Completer<void> started = Completer<void>();
  final Completer<void> _finish = Completer<void>();
  int calls = 0;

  void finishFirstDetach() => _finish.complete();

  @override
  Future<void> detach(String ownerScopeValue) async {
    calls += 1;
    if (calls == 1) {
      started.complete();
      await _finish.future;
    }
    await _delegate.detach(ownerScopeValue);
  }
}
