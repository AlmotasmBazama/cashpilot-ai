import 'dart:async';

import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_agent_memory.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/ai_provider_egress_guard.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/agent/governed_ai_tool_registry.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_scope_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_operation_coordinator.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same UID and clock with a new auth generation revokes old tool memory and egress leases',
    () async {
      final fixedClock = DateTime.utc(2026, 8, 10, 12);
      final scope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        'owner-a',
        confirmedAt: fixedClock,
      );
      _TestOwnerScopeController.initialScope = scope;
      final container = ProviderContainer(
        overrides: [
          confirmedOwnerScopeSnapshotProvider.overrideWith(
            _TestOwnerScopeController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final bindingA1 = container.read(aiToolOwnerScopeBindingProvider)!;
      expect(bindingA1.epoch, 0);

      final fence = BackupOperationFence();
      final memoryLease = AiAgentMemoryOwnerLease.tryAcquire(
        binding: bindingA1,
        currentOwnerScope: () =>
            container.read(aiToolOwnerScopeBindingProvider),
        operationFence: fence,
      )!;
      addTearDown(memoryLease.release);

      final auth = _SameUidFirebaseAuth(_SameUidFirebaseUser());
      final authGuard = FirebaseAuthSessionEpochGuard(auth);
      addTearDown(() async {
        await authGuard.dispose();
        await auth.dispose();
      });
      auth.emitCurrent();
      final egress = FirebaseAiProviderEgressGuard(
        expectedAuthSession: const AuthSessionIdentity(
          uid: 'owner-a',
          isAnonymous: false,
          authSessionGeneration: 0,
          tenantId: null,
        ),
        expectedOwnerScope: bindingA1,
        currentOwnerScope: () =>
            container.read(aiToolOwnerScopeBindingProvider),
        memoryAccess: memoryLease.access,
        authSessionGuard: authGuard,
        authOperationCoordinator: FirebaseAuthOperationCoordinator(),
      );
      egress.assertActive();

      final toolStarted = Completer<void>();
      final releaseTool = Completer<void>();
      var toolCalls = 0;
      final registry = GovernedAiToolRegistry(
        tools: <RegisteredAiTool>[
          RegisteredAiTool(
            definition: const AiToolDefinition(
              name: 'same_uid_delayed_read',
              description: 'Synthetic generation-bound read.',
              permission: AgentPermission.readFinancialData,
            ),
            handler: (arguments, context) async {
              toolCalls += 1;
              toolStarted.complete();
              await releaseTool.future;
              return const AiToolResult(
                toolName: 'same_uid_delayed_read',
                data: <String, Object?>{'ok': true},
              );
            },
          ),
        ],
        permissionPolicy: const DefaultAiToolPermissionPolicy(),
        currentOwnerScope: () =>
            container.read(aiToolOwnerScopeBindingProvider),
      );
      final tool = registry.execute(
        const AiAgentToolCall(
          id: 'same-uid-old-generation',
          name: 'same_uid_delayed_read',
          arguments: <String, Object?>{},
        ),
        AiToolExecutionContext(
          locale: 'en',
          baseCurrencyCode: 'LYD',
          now: fixedClock,
          maxSearchResults: 5,
          ownerScope: bindingA1,
          financialDataScopeVerified: true,
        ),
      );
      await toolStarted.future;

      (container.read(confirmedOwnerScopeSnapshotProvider.notifier)
              as _TestOwnerScopeController)
          .setGeneration(1);
      auth.emitCurrent();
      await pumpEventQueue(times: 4);
      final bindingA2 = container.read(aiToolOwnerScopeBindingProvider)!;
      expect(bindingA2.accountScope, bindingA1.accountScope);
      expect(scope.confirmedAt, fixedClock);
      expect(bindingA2.epoch, 1);
      expect(bindingA2, isNot(bindingA1));

      expect(
        memoryLease.assertActive,
        throwsA(isA<AiAgentMemoryOwnerBindingChangedException>()),
      );
      expect(
        egress.assertActive,
        throwsA(isA<AiProviderEgressRevokedException>()),
      );
      releaseTool.complete();
      await expectLater(
        tool,
        throwsA(
          isA<AiToolFailure>().having(
            (failure) => failure.code,
            'code',
            'account_scope_changed',
          ),
        ),
      );
      expect(toolCalls, 1);
    },
  );
}

final class _TestOwnerScopeController extends ConfirmedOwnerScopeController {
  static late ConfirmedOwnerScope initialScope;

  @override
  OwnerScopeSnapshot build() => OwnerScopeSnapshot(
    status: OwnerScopeStatus.safe,
    scope: initialScope,
    authSessionGeneration: 0,
  );

  void setGeneration(int generation) {
    state = OwnerScopeSnapshot(
      status: OwnerScopeStatus.safe,
      scope: initialScope,
      authSessionGeneration: generation,
    );
  }
}

final class _SameUidFirebaseAuth implements firebase_auth.FirebaseAuth {
  _SameUidFirebaseAuth(this._user);

  final firebase_auth.User _user;
  final StreamController<firebase_auth.User?> _events =
      StreamController<firebase_auth.User?>.broadcast(sync: true);

  @override
  firebase_auth.User? get currentUser => _user;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _events.stream;

  void emitCurrent() => _events.add(_user);

  Future<void> dispose() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SameUidFirebaseUser implements firebase_auth.User {
  @override
  String get uid => 'owner-a';

  @override
  bool get isAnonymous => false;

  @override
  String? get tenantId => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
