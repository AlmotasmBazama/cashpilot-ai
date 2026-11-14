import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_assistant_send_lifecycle_coordinator.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_prompt_send_guard.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/failures/ai_failure_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ownerA = AiToolOwnerScopeBinding(
    accountScope:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    epoch: 1,
  );
  const ownerB = AiToolOwnerScopeBinding(
    accountScope:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    epoch: 2,
  );

  group('AiAssistantSendLifecycleCoordinator', () {
    test(
      'admits one send and releases admission only for its active token',
      () {
        var now = DateTime(2026, 8, 17, 12);
        AiToolOwnerScopeBinding? binding = ownerA;
        final coordinator = AiAssistantSendLifecycleCoordinator(
          initialOwnerBinding: binding,
          readOwnerBinding: () => binding,
          isMounted: () => true,
          promptSendGuard: AiPromptSendGuard(clock: () => now),
        );

        expect(coordinator.tryAdmit('first'), isA<AiAssistantSendAdmitted>());
        expect(
          coordinator.tryAdmit('overlap'),
          isA<AiAssistantSendRejected>().having(
            (result) => result.code,
            'code',
            AiFailureCodes.requestInFlight,
          ),
        );
        final operation = coordinator.beginOwnerOperation(
          requireConfirmedOwner: true,
        )!;
        coordinator.activateOperation(operation);

        final finish = coordinator.finishOperation(
          operation,
          cleanup: AiAssistantActiveOperationCleanup.send,
        );

        expect(finish.releasedActiveOperation, isTrue);
        expect(finish.isCurrent, isTrue);
        now = now.add(const Duration(seconds: 1));
        expect(coordinator.tryAdmit('second'), isA<AiAssistantSendAdmitted>());
      },
    );

    test(
      'lifecycle invalidation cancels once, resets admission, and fences stale work',
      () {
        AiToolOwnerScopeBinding? binding = ownerA;
        var cancellationCalls = 0;
        final coordinator = AiAssistantSendLifecycleCoordinator(
          initialOwnerBinding: binding,
          readOwnerBinding: () => binding,
          isMounted: () => true,
        );
        expect(coordinator.tryAdmit('send'), isA<AiAssistantSendAdmitted>());
        final operation = coordinator.beginOwnerOperation(
          requireConfirmedOwner: true,
        )!;
        coordinator.activateOperation(operation);
        coordinator.setActiveRequestCancellation(() => cancellationCalls += 1);

        coordinator.invalidateAndCancelActiveOperation();
        coordinator.invalidateAndCancelActiveOperation();

        expect(cancellationCalls, 1);
        expect(coordinator.hasActiveOperation, isFalse);
        expect(coordinator.isCurrent(operation), isFalse);
        expect(coordinator.tryAdmit('send'), isA<AiAssistantSendAdmitted>());
      },
    );

    test(
      'owner switch cancels A and never treats its result as current for B',
      () {
        AiToolOwnerScopeBinding? binding = ownerA;
        var cancellationCalls = 0;
        final coordinator = AiAssistantSendLifecycleCoordinator(
          initialOwnerBinding: binding,
          readOwnerBinding: () => binding,
          isMounted: () => true,
        );
        final ownerAOperation = coordinator.beginOwnerOperation(
          requireConfirmedOwner: true,
        )!;
        coordinator.activateOperation(ownerAOperation);
        coordinator.setActiveRequestCancellation(() => cancellationCalls += 1);

        binding = ownerB;
        expect(coordinator.handleOwnerBindingChanged(ownerA, ownerB), isTrue);
        final staleFinish = coordinator.finishOperation(
          ownerAOperation,
          cleanup: AiAssistantActiveOperationCleanup.send,
        );
        final ownerBOperation = coordinator.beginOwnerOperation(
          requireConfirmedOwner: true,
        )!;

        expect(cancellationCalls, 1);
        expect(staleFinish.releasedActiveOperation, isFalse);
        expect(staleFinish.isCurrent, isFalse);
        expect(coordinator.isCurrent(ownerAOperation), isFalse);
        expect(coordinator.isCurrent(ownerBOperation), isTrue);
      },
    );

    test('stale finally cannot release or cancel a newer active operation', () {
      AiToolOwnerScopeBinding? binding = ownerA;
      var newerCancellationCalls = 0;
      final coordinator = AiAssistantSendLifecycleCoordinator(
        initialOwnerBinding: binding,
        readOwnerBinding: () => binding,
        isMounted: () => true,
      );
      final older = coordinator.beginOwnerOperation(
        requireConfirmedOwner: true,
      )!;
      coordinator.activateOperation(older);
      final newer = coordinator.beginOwnerOperation(
        requireConfirmedOwner: true,
      )!;
      coordinator.activateOperation(newer);
      coordinator.setActiveRequestCancellation(
        () => newerCancellationCalls += 1,
      );

      final staleFinish = coordinator.finishOperation(
        older,
        cleanup: AiAssistantActiveOperationCleanup.send,
      );

      expect(staleFinish.releasedActiveOperation, isFalse);
      expect(staleFinish.isCurrent, isFalse);
      expect(coordinator.hasActiveOperation, isTrue);
      coordinator.invalidateAndCancelActiveOperation();
      expect(newerCancellationCalls, 1);
      expect(coordinator.isCurrent(newer), isFalse);
    });

    test('unmounted or failed owner reads suppress result publication', () {
      var mounted = true;
      var readFails = false;
      final coordinator = AiAssistantSendLifecycleCoordinator(
        initialOwnerBinding: ownerA,
        readOwnerBinding: () {
          if (readFails) throw StateError('owner session unavailable');
          return ownerA;
        },
        isMounted: () => mounted,
      );
      final operation = coordinator.beginOwnerOperation(
        requireConfirmedOwner: true,
      )!;

      readFails = true;
      expect(coordinator.isCurrent(operation), isFalse);
      readFails = false;
      mounted = false;
      expect(coordinator.isCurrent(operation), isFalse);
    });
  });
}
