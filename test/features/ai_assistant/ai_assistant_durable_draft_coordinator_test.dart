import 'dart:async';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/durable_ai_action_bridge.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_assistant_durable_draft_coordinator.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_validation_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiAssistantDurableDraftCoordinator.prepare', () {
    test(
      'persists, fences, reauthorizes the captured revision, then binds',
      () async {
        final events = <String>[];
        final runtime = _RecordingRuntime(events: events, name: 'new');
        final coordinator = AiAssistantDurableDraftCoordinator();
        final draft = _draft('draft-a');

        final outcome = await coordinator.prepare(
          draft: draft,
          validation: AiActionValidationResult.valid(draft.action),
          isDurableFinancialCreate: true,
          policyRevision: 41,
          isCurrent: () {
            events.add('current');
            return true;
          },
          readRuntime: () {
            events.add('read-runtime');
            return runtime;
          },
          readPermissionFailure: (revision) {
            events.add('authorize:$revision');
            expect(coordinator.visibleRuntime, isNull);
            expect(coordinator.visiblePolicyRevision, isNull);
            return null;
          },
        );

        expect(events, <String>[
          'read-runtime',
          'new.persist:draft-a',
          'current',
          'authorize:41',
        ]);
        expect(
          outcome,
          isA<AiAssistantDurableDraftReady>()
              .having((value) => value.runtime, 'runtime', same(runtime))
              .having((value) => value.policyRevision, 'policyRevision', 41),
        );
        expect(coordinator.visibleRuntime, same(runtime));
        expect(coordinator.visiblePolicyRevision, 41);
      },
    );

    test('does not persist a draft that is invalid or non-durable', () async {
      for (final scenario
          in <({AiActionValidationResult validation, bool durable})>[
            (
              validation: const AiActionValidationResult.invalid('invalid'),
              durable: true,
            ),
            (
              validation: AiActionValidationResult.valid(_action('valid')),
              durable: false,
            ),
          ]) {
        final coordinator = AiAssistantDurableDraftCoordinator();
        var authorizationCalls = 0;

        final outcome = await coordinator.prepare(
          draft: _draft('draft-${scenario.durable}'),
          validation: scenario.validation,
          isDurableFinancialCreate: scenario.durable,
          policyRevision: 5,
          isCurrent: () => true,
          readRuntime: () => throw StateError('runtime must not be read'),
          readPermissionFailure: (revision) {
            authorizationCalls += 1;
            expect(revision, 5);
            return null;
          },
        );

        expect(outcome, isA<AiAssistantDurableDraftReady>());
        expect(authorizationCalls, 1);
        expect(coordinator.visibleRuntime, isNull);
        expect(coordinator.visiblePolicyRevision, 5);
      }
    });

    test('returns the exact safe failure when persistence fails', () async {
      final oldRuntime = _RecordingRuntime(name: 'old');
      final runtime = _RecordingRuntime(
        name: 'new',
        persistError: StateError('disk unavailable'),
      );
      final coordinator = AiAssistantDurableDraftCoordinator()
        ..bindVisibleDraft(runtime: oldRuntime, policyRevision: 11);
      var authorizationCalls = 0;

      final outcome = await coordinator.prepare(
        draft: _draft('draft-a'),
        validation: AiActionValidationResult.valid(_action('valid')),
        isDurableFinancialCreate: true,
        policyRevision: 12,
        isCurrent: () => true,
        readRuntime: () => runtime,
        readPermissionFailure: (_) {
          authorizationCalls += 1;
          return null;
        },
      );

      expect(
        outcome,
        isA<AiAssistantDurableDraftPersistenceFailed>()
            .having(
              (value) => value.failure.message,
              'message',
              'The financial draft could not be saved safely.',
            )
            .having(
              (value) => value.failure.code,
              'code',
              AppAgentFailureCodes.validationFailed,
            ),
      );
      expect(authorizationCalls, 0);
      expect(coordinator.visibleRuntime, same(oldRuntime));
      expect(coordinator.visiblePolicyRevision, 11);
    });

    test(
      'cancels the persisted runtime when reauthorization rejects it',
      () async {
        const denial = Failure(message: 'Policy changed.', code: 'denied');
        final events = <String>[];
        final runtime = _RecordingRuntime(events: events, name: 'new');
        final coordinator = AiAssistantDurableDraftCoordinator();
        final draft = _draft('draft-a');

        final outcome = await coordinator.prepare(
          draft: draft,
          validation: AiActionValidationResult.valid(draft.action),
          isDurableFinancialCreate: true,
          policyRevision: 9,
          isCurrent: () {
            events.add('current');
            return true;
          },
          readRuntime: () {
            events.add('read-runtime');
            return runtime;
          },
          readPermissionFailure: (revision) {
            events.add('authorize:$revision');
            return denial;
          },
        );

        expect(events, <String>[
          'read-runtime',
          'new.persist:draft-a',
          'current',
          'authorize:9',
          'new.cancel:draft-a',
          'current',
        ]);
        expect(
          outcome,
          isA<AiAssistantDurableDraftPermissionRejected>().having(
            (value) => value.failure,
            'failure',
            denial,
          ),
        );
        expect(coordinator.visibleRuntime, isNull);
        expect(coordinator.visiblePolicyRevision, isNull);
      },
    );

    test(
      'fences a late denial cancellation before publishing rejection',
      () async {
        const denial = Failure(message: 'Policy changed.', code: 'denied');
        final cancelStarted = Completer<void>();
        final cancelGate = Completer<void>();
        var current = true;
        final oldRuntime = _RecordingRuntime(name: 'old');
        final newRuntime = _RecordingRuntime(
          name: 'new',
          onCancel: (_) async {
            cancelStarted.complete();
            await cancelGate.future;
          },
        );
        final coordinator = AiAssistantDurableDraftCoordinator()
          ..bindVisibleDraft(runtime: oldRuntime, policyRevision: 2);
        final draft = _draft('draft-a');

        final future = coordinator.prepare(
          draft: draft,
          validation: AiActionValidationResult.valid(draft.action),
          isDurableFinancialCreate: true,
          policyRevision: 3,
          isCurrent: () => current,
          readRuntime: () => newRuntime,
          readPermissionFailure: (_) => denial,
        );
        await cancelStarted.future;
        current = false;
        cancelGate.complete();

        expect(await future, isA<AiAssistantDurableDraftSuperseded>());
        expect(coordinator.visibleRuntime, same(oldRuntime));
        expect(coordinator.visiblePolicyRevision, 2);
      },
    );

    test('a late persist is fenced before authorization and binding', () async {
      final persistStarted = Completer<void>();
      final persistGate = Completer<void>();
      var current = true;
      var authorizationCalls = 0;
      final runtime = _RecordingRuntime(
        name: 'new',
        onPersist: (_) async {
          persistStarted.complete();
          await persistGate.future;
        },
      );
      final coordinator = AiAssistantDurableDraftCoordinator();
      final draft = _draft('draft-a');

      final future = coordinator.prepare(
        draft: draft,
        validation: AiActionValidationResult.valid(draft.action),
        isDurableFinancialCreate: true,
        policyRevision: 3,
        isCurrent: () => current,
        readRuntime: () => runtime,
        readPermissionFailure: (_) {
          authorizationCalls += 1;
          return null;
        },
      );
      await persistStarted.future;
      current = false;
      persistGate.complete();

      expect(await future, isA<AiAssistantDurableDraftSuperseded>());
      expect(authorizationCalls, 0);
      expect(coordinator.visibleRuntime, isNull);
      expect(coordinator.visiblePolicyRevision, isNull);
    });
  });

  group('AiAssistantDurableDraftCoordinator.revise', () {
    test(
      'checks permission before cancelling and clears a rejected binding',
      () async {
        const denial = Failure(message: 'Policy changed.', code: 'denied');
        final events = <String>[];
        final oldRuntime = _RecordingRuntime(events: events, name: 'old');
        final coordinator = AiAssistantDurableDraftCoordinator()
          ..bindVisibleDraft(runtime: oldRuntime, policyRevision: 27);
        final previousDraft = _draft('draft-old');
        final updatedDraft = _draft('draft-new');

        final outcome = await coordinator.revise(
          previousDraft: previousDraft,
          updatedDraft: updatedDraft,
          validation: AiActionValidationResult.valid(updatedDraft.action),
          isDurableFinancialCreate: true,
          isCurrent: () {
            events.add('current');
            return true;
          },
          readRuntime: () => throw StateError('new runtime must not be read'),
          readPermissionFailure: (revision) {
            events.add('authorize:$revision');
            return denial;
          },
        );

        expect(events, <String>[
          'authorize:27',
          'old.cancel:draft-old',
          'current',
        ]);
        expect(
          outcome,
          isA<AiAssistantDurableDraftPermissionRejected>().having(
            (value) => value.failure,
            'failure',
            denial,
          ),
        );
        expect(coordinator.visibleRuntime, isNull);
        expect(coordinator.visiblePolicyRevision, isNull);
      },
    );

    test(
      'cancels old, persists new, and preserves the visible policy revision',
      () async {
        final events = <String>[];
        final oldRuntime = _RecordingRuntime(events: events, name: 'old');
        final newRuntime = _RecordingRuntime(events: events, name: 'new');
        final coordinator = AiAssistantDurableDraftCoordinator()
          ..bindVisibleDraft(runtime: oldRuntime, policyRevision: 31);
        final previousDraft = _draft('draft-old');
        final updatedDraft = _draft('draft-new');

        final outcome = await coordinator.revise(
          previousDraft: previousDraft,
          updatedDraft: updatedDraft,
          validation: AiActionValidationResult.valid(updatedDraft.action),
          isDurableFinancialCreate: true,
          isCurrent: () {
            events.add('current');
            return true;
          },
          readRuntime: () {
            events.add('read-runtime');
            return newRuntime;
          },
          readPermissionFailure: (revision) {
            events.add('authorize:$revision');
            return null;
          },
        );

        expect(events, <String>[
          'authorize:31',
          'old.cancel:draft-old',
          'current',
          'read-runtime',
          'new.persist:draft-new',
          'current',
          'current',
        ]);
        expect(
          outcome,
          isA<AiAssistantDurableDraftReady>()
              .having((value) => value.runtime, 'runtime', same(newRuntime))
              .having((value) => value.policyRevision, 'policyRevision', 31),
        );
        expect(coordinator.visibleRuntime, same(newRuntime));
        expect(coordinator.visiblePolicyRevision, 31);
      },
    );

    test(
      'fences old cancellation before reading a replacement runtime',
      () async {
        final cancelStarted = Completer<void>();
        final cancelGate = Completer<void>();
        var current = true;
        var runtimeReads = 0;
        final oldRuntime = _RecordingRuntime(
          name: 'old',
          onCancel: (_) async {
            cancelStarted.complete();
            await cancelGate.future;
          },
        );
        final newRuntime = _RecordingRuntime(name: 'new');
        final coordinator = AiAssistantDurableDraftCoordinator()
          ..bindVisibleDraft(runtime: oldRuntime, policyRevision: 31);
        final previousDraft = _draft('draft-old');
        final updatedDraft = _draft('draft-new');

        final future = coordinator.revise(
          previousDraft: previousDraft,
          updatedDraft: updatedDraft,
          validation: AiActionValidationResult.valid(updatedDraft.action),
          isDurableFinancialCreate: true,
          isCurrent: () => current,
          readRuntime: () {
            runtimeReads += 1;
            return newRuntime;
          },
          readPermissionFailure: (_) => null,
        );
        await cancelStarted.future;
        current = false;
        cancelGate.complete();

        expect(await future, isA<AiAssistantDurableDraftSuperseded>());
        expect(runtimeReads, 0);
        expect(coordinator.visibleRuntime, same(oldRuntime));
        expect(coordinator.visiblePolicyRevision, 31);
      },
    );

    test(
      'persistence failure keeps the cancelled binding and exact failure',
      () async {
        final oldRuntime = _RecordingRuntime(name: 'old');
        final newRuntime = _RecordingRuntime(
          name: 'new',
          persistError: StateError('disk unavailable'),
        );
        final coordinator = AiAssistantDurableDraftCoordinator()
          ..bindVisibleDraft(runtime: oldRuntime, policyRevision: 17);
        final previousDraft = _draft('draft-old');
        final updatedDraft = _draft('draft-new');

        final outcome = await coordinator.revise(
          previousDraft: previousDraft,
          updatedDraft: updatedDraft,
          validation: AiActionValidationResult.valid(updatedDraft.action),
          isDurableFinancialCreate: true,
          isCurrent: () => true,
          readRuntime: () => newRuntime,
          readPermissionFailure: (_) => null,
        );

        expect(oldRuntime.cancelledIds, <String>['draft-old']);
        expect(
          outcome,
          isA<AiAssistantDurableDraftPersistenceFailed>()
              .having(
                (value) => value.failure.message,
                'message',
                'The revised financial draft could not be saved safely.',
              )
              .having(
                (value) => value.failure.code,
                'code',
                AppAgentFailureCodes.validationFailed,
              ),
        );
        expect(coordinator.visibleRuntime, same(oldRuntime));
        expect(coordinator.visiblePolicyRevision, 17);
      },
    );

    test(
      'a late revised persist cannot replace the captured old binding',
      () async {
        final persistStarted = Completer<void>();
        final persistGate = Completer<void>();
        var current = true;
        final oldRuntime = _RecordingRuntime(name: 'old');
        final newRuntime = _RecordingRuntime(
          name: 'new',
          onPersist: (_) async {
            persistStarted.complete();
            await persistGate.future;
          },
        );
        final coordinator = AiAssistantDurableDraftCoordinator()
          ..bindVisibleDraft(runtime: oldRuntime, policyRevision: 23);
        final previousDraft = _draft('draft-old');
        final updatedDraft = _draft('draft-new');

        final future = coordinator.revise(
          previousDraft: previousDraft,
          updatedDraft: updatedDraft,
          validation: AiActionValidationResult.valid(updatedDraft.action),
          isDurableFinancialCreate: true,
          isCurrent: () => current,
          readRuntime: () => newRuntime,
          readPermissionFailure: (_) => null,
        );
        await persistStarted.future;
        current = false;
        persistGate.complete();

        expect(await future, isA<AiAssistantDurableDraftSuperseded>());
        expect(oldRuntime.cancelledIds, <String>['draft-old']);
        expect(coordinator.visibleRuntime, same(oldRuntime));
        expect(coordinator.visiblePolicyRevision, 23);
      },
    );
  });
}

AiAction _action(String name) => CreateCategoryDraft(name: name);

AiActionDraft _draft(String id) => AiActionDraft.create(
  action: _action(id),
  id: id,
  createdAt: DateTime.utc(2026, 8, 17, 12),
);

final class _RecordingRuntime implements AiActionDurableRuntime {
  _RecordingRuntime({
    required this.name,
    List<String>? events,
    this.onPersist,
    this.onCancel,
    this.persistError,
  }) : events = events ?? <String>[];

  final String name;
  final List<String> events;
  final Future<void> Function(AiActionDraft draft)? onPersist;
  final Future<void> Function(String commandId)? onCancel;
  final Object? persistError;
  final List<String> cancelledIds = <String>[];

  @override
  Future<AppAgentCommand> persistDraft(AiActionDraft draft) async {
    events.add('$name.persist:${draft.id}');
    await onPersist?.call(draft);
    final error = persistError;
    if (error != null) throw error;
    return AppAgentCommand(
      commandId: draft.id,
      conversationId: 'test',
      userAccountScope: 'test-account',
      commandType: AppAgentCommandType.create,
      toolId: 'createCategoryDraft',
      normalizedArguments: const <String, Object?>{},
      permission: AgentPermission.createDraft,
      risk: AgentActionRisk.low,
      createdAt: draft.createdAt,
      expiresAt: draft.createdAt.add(const Duration(minutes: 1)),
      status: AppAgentCommandStatus.awaitingConfirmation,
    );
  }

  @override
  Future<void> cancel(String commandId) async {
    events.add('$name.cancel:$commandId');
    cancelledIds.add(commandId);
    await onCancel?.call(commandId);
  }

  @override
  Future<AppAgentExecutionResult> confirmAndExecute(String commandId) {
    throw UnimplementedError();
  }

  @override
  Future<AiActionDraft?> restoreLatestPendingDraft() async => null;

  @override
  Future<void> acknowledgeRecoveryResult(String commandId) async {}
}
