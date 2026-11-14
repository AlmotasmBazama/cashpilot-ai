import 'dart:async';

import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_operation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'queued A native operation is rejected when B is current at dispatch',
    () async {
      final coordinator = FirebaseAuthOperationCoordinator();
      final blockerStarted = Completer<void>();
      final releaseBlocker = Completer<void>();
      var currentOwner = 'A';
      var staleNativeCalls = 0;

      final blocker = coordinator.run<void>(
        operation: () async {
          blockerStarted.complete();
          await releaseBlocker.future;
        },
      );
      await blockerStarted.future;
      final staleA = coordinator.run<void>(
        assertBefore: () {
          if (currentOwner != 'A') {
            throw StateError('captured Auth owner changed');
          }
        },
        operation: () async {
          staleNativeCalls += 1;
        },
      );

      currentOwner = 'B';
      releaseBlocker.complete();
      await blocker;
      await expectLater(staleA, throwsStateError);
      expect(staleNativeCalls, 0);

      var bNativeCalls = 0;
      await coordinator.run<void>(
        assertBefore: () {
          if (currentOwner != 'B') throw StateError('B is not current');
        },
        operation: () async {
          bNativeCalls += 1;
        },
      );
      expect(bNativeCalls, 1);
    },
  );
}
