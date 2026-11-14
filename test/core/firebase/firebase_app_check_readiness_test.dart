import 'dart:async';

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_readiness.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default token retry schedule is immediate then bounded backoff', () {
    expect(defaultFirebaseAppCheckTokenRetryDelays, const <Duration>[
      Duration.zero,
      Duration(milliseconds: 300),
      Duration(milliseconds: 700),
      Duration(milliseconds: 1500),
    ]);
    expect(
      defaultFirebaseAppCheckReadinessTimeout,
      const Duration(seconds: 12),
    );
  });

  test('activation completes before the first token attempt', () async {
    final activationGate = Completer<void>();
    var activationCalls = 0;
    var tokenCalls = 0;
    final activation = FirebaseAppCheckActivationController(
      activator: _CallbackActivator(() {
        activationCalls += 1;
        return activationGate.future;
      }),
      timeout: const Duration(seconds: 1),
    );
    final coordinator = _coordinator(
      activation: activation,
      tokenLoader: ({required forceRefresh}) async {
        tokenCalls += 1;
        return 'usable-app-check-token';
      },
    );
    addTearDown(activation.dispose);
    addTearDown(coordinator.dispose);

    final pending = coordinator.getToken();
    await Future<void>.delayed(Duration.zero);

    expect(activationCalls, 1);
    expect(tokenCalls, 0);
    expect(coordinator.state.phase, FirebaseAppCheckReadinessPhase.activating);

    activationGate.complete();
    expect(await pending, 'usable-app-check-token');
    expect(tokenCalls, 1);
    expect(coordinator.state, const FirebaseAppCheckReadinessState.ready());
  });

  test(
    'transient activation failure is retried before token acquisition',
    () async {
      var activationCalls = 0;
      var tokenCalls = 0;
      final activation = FirebaseAppCheckActivationController(
        activator: _CallbackActivator(() async {
          activationCalls += 1;
          if (activationCalls == 1) {
            throw StateError('simulated activation failure');
          }
        }),
        timeout: const Duration(seconds: 1),
      );
      final coordinator = _coordinator(
        activation: activation,
        tokenLoader: ({required forceRefresh}) async {
          tokenCalls += 1;
          return 'usable-app-check-token';
        },
      );
      addTearDown(activation.dispose);
      addTearDown(coordinator.dispose);

      expect(await coordinator.getToken(), 'usable-app-check-token');
      expect(activationCalls, 2);
      expect(tokenCalls, 1);
    },
  );

  test('first unavailable token is retried and the second succeeds', () async {
    var tokenCalls = 0;
    final activation = _readyActivation();
    final coordinator = _coordinator(
      activation: activation,
      tokenLoader: ({required forceRefresh}) async {
        tokenCalls += 1;
        return tokenCalls == 1 ? null : 'usable-app-check-token';
      },
      retryDelays: const <Duration>[Duration.zero, Duration.zero],
    );
    addTearDown(activation.dispose);
    addTearDown(coordinator.dispose);

    expect(await coordinator.getToken(), 'usable-app-check-token');
    expect(tokenCalls, 2);
    expect(coordinator.state, const FirebaseAppCheckReadinessState.ready());
  });

  test('multiple transient token failures recover within the bound', () async {
    var tokenCalls = 0;
    final activation = _readyActivation();
    final coordinator = _coordinator(
      activation: activation,
      tokenLoader: ({required forceRefresh}) async {
        tokenCalls += 1;
        if (tokenCalls < 4) {
          throw FirebaseException(
            plugin: 'firebase_app_check',
            code: 'token-error',
          );
        }
        return 'usable-app-check-token';
      },
      retryDelays: const <Duration>[
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ],
    );
    addTearDown(activation.dispose);
    addTearDown(coordinator.dispose);

    expect(await coordinator.getToken(), 'usable-app-check-token');
    expect(tokenCalls, 4);
  });

  test('never-completing token acquisition times out and terminates', () async {
    final tokenGate = Completer<String?>();
    final activation = _readyActivation();
    final coordinator = _coordinator(
      activation: activation,
      tokenLoader: ({required forceRefresh}) => tokenGate.future,
      retryDelays: const <Duration>[Duration.zero],
      tokenAttemptTimeout: const Duration(milliseconds: 5),
      totalTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(activation.dispose);
    addTearDown(coordinator.dispose);

    await expectLater(
      coordinator.getToken(),
      throwsA(
        isA<FirebaseAppCheckReadinessException>().having(
          (failure) => failure.reason,
          'reason',
          FirebaseAppCheckReadinessFailureReason.timedOut,
        ),
      ),
    );
    expect(coordinator.state.phase, FirebaseAppCheckReadinessPhase.timedOut);
    tokenGate.complete(null);
  });

  test('confirmed rejection does not enter the retry loop', () async {
    var tokenCalls = 0;
    final activation = _readyActivation();
    final coordinator = _coordinator(
      activation: activation,
      tokenLoader: ({required forceRefresh}) async {
        tokenCalls += 1;
        throw FirebaseException(
          plugin: 'firebase_app_check',
          code: 'permission-denied',
        );
      },
      retryDelays: const <Duration>[
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ],
    );
    addTearDown(activation.dispose);
    addTearDown(coordinator.dispose);

    await expectLater(
      coordinator.getToken(),
      throwsA(
        isA<FirebaseAppCheckReadinessException>().having(
          (failure) => failure.reason,
          'reason',
          FirebaseAppCheckReadinessFailureReason.rejected,
        ),
      ),
    );
    expect(tokenCalls, 1);
    expect(coordinator.state.phase, FirebaseAppCheckReadinessPhase.rejected);
  });

  test(
    'native unknown error with status 403 is a confirmed rejection',
    () async {
      var tokenCalls = 0;
      final activation = _readyActivation();
      final coordinator = _coordinator(
        activation: activation,
        tokenLoader: ({required forceRefresh}) async {
          tokenCalls += 1;
          throw FirebaseException(
            plugin: 'firebase_app_check',
            code: 'unknown',
            message: 'attestation request returned status 403',
          );
        },
        retryDelays: const <Duration>[Duration.zero, Duration.zero],
      );
      addTearDown(activation.dispose);
      addTearDown(coordinator.dispose);

      await expectLater(
        coordinator.getToken(),
        throwsA(
          isA<FirebaseAppCheckReadinessException>().having(
            (failure) => failure.safeCode,
            'safeCode',
            'appCheckRejected',
          ),
        ),
      );
      expect(tokenCalls, 1);
      expect(coordinator.state.phase, FirebaseAppCheckReadinessPhase.rejected);
    },
  );

  test('concurrent callers share activation and token acquisition', () async {
    final tokenGate = Completer<String?>();
    var tokenCalls = 0;
    final activation = _readyActivation();
    final coordinator = _coordinator(
      activation: activation,
      tokenLoader: ({required forceRefresh}) {
        tokenCalls += 1;
        return tokenGate.future;
      },
    );
    addTearDown(activation.dispose);
    addTearDown(coordinator.dispose);

    final first = coordinator.getToken();
    final second = coordinator.getToken();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(tokenCalls, 1);

    tokenGate.complete('shared-app-check-token');
    expect(await Future.wait(<Future<String>>[first, second]), <String>[
      'shared-app-check-token',
      'shared-app-check-token',
    ]);
    expect(tokenCalls, 1);
  });

  test(
    'explicit retry resets a reported rejection without prefetching',
    () async {
      var tokenCalls = 0;
      final activation = _readyActivation();
      final coordinator = _coordinator(
        activation: activation,
        tokenLoader: ({required forceRefresh}) async {
          tokenCalls += 1;
          return 'new-app-check-token';
        },
      );
      addTearDown(activation.dispose);
      addTearDown(coordinator.dispose);

      coordinator.reportRejected();
      expect(coordinator.state.phase, FirebaseAppCheckReadinessPhase.rejected);
      coordinator.requestRetry();
      expect(
        coordinator.state.phase,
        FirebaseAppCheckReadinessPhase.notStarted,
      );
      expect(tokenCalls, 0);

      expect(await coordinator.getToken(), 'new-app-check-token');
      expect(tokenCalls, 1);
    },
  );

  test(
    'an older gateway rejection cannot cancel a newer shared refresh',
    () async {
      final refreshedToken = Completer<String?>();
      var tokenCalls = 0;
      final activation = _readyActivation();
      final coordinator = _coordinator(
        activation: activation,
        tokenLoader: ({required forceRefresh}) {
          tokenCalls += 1;
          return refreshedToken.future;
        },
      );
      addTearDown(activation.dispose);
      addTearDown(coordinator.dispose);

      final pending = coordinator.getToken();
      await Future<void>.delayed(Duration.zero);
      expect(
        coordinator.state.phase,
        FirebaseAppCheckReadinessPhase.waitingForToken,
      );

      // This represents a slower HTTP response rejecting a token from an
      // earlier request while Chat/Settings already share a newer refresh.
      coordinator.reportRejected();
      expect(
        coordinator.state.phase,
        FirebaseAppCheckReadinessPhase.waitingForToken,
      );

      refreshedToken.complete('newer-app-check-token');
      expect(await pending, 'newer-app-check-token');
      expect(tokenCalls, 1);
      expect(coordinator.state.phase, FirebaseAppCheckReadinessPhase.ready);
    },
  );

  test('disposed wait cannot publish ready or enable late egress', () async {
    final tokenGate = Completer<String?>();
    final activation = _readyActivation();
    final coordinator = _coordinator(
      activation: activation,
      tokenLoader: ({required forceRefresh}) => tokenGate.future,
    );
    addTearDown(activation.dispose);

    final pending = coordinator.getToken();
    await Future<void>.delayed(Duration.zero);
    coordinator.dispose();
    tokenGate.complete('late-app-check-token');

    await expectLater(
      pending,
      throwsA(isA<FirebaseAppCheckReadinessCancelledException>()),
    );
    expect(coordinator.state.isReady, isFalse);
  });

  test(
    'a newly constructed process coordinator starts with fresh state',
    () async {
      final firstActivation = _readyActivation();
      final first = _coordinator(
        activation: firstActivation,
        tokenLoader: ({required forceRefresh}) async => 'first-token',
      );
      first.reportRejected();
      expect(first.state.phase, FirebaseAppCheckReadinessPhase.rejected);
      first.dispose();
      await firstActivation.dispose();

      final reopenedActivation = _readyActivation();
      final reopened = _coordinator(
        activation: reopenedActivation,
        tokenLoader: ({required forceRefresh}) async => 'reopened-token',
      );
      addTearDown(reopened.dispose);
      addTearDown(reopenedActivation.dispose);

      expect(reopened.state.phase, FirebaseAppCheckReadinessPhase.notStarted);
      expect(await reopened.getToken(), 'reopened-token');
      expect(reopened.state.phase, FirebaseAppCheckReadinessPhase.ready);
    },
  );
}

FirebaseAppCheckActivationController _readyActivation() {
  return FirebaseAppCheckActivationController(
    activator: const _CallbackActivator(_completeActivation),
    timeout: const Duration(seconds: 1),
  );
}

FirebaseAppCheckReadinessCoordinator _coordinator({
  required FirebaseAppCheckActivationController activation,
  required FirebaseAppCheckTokenLoader tokenLoader,
  List<Duration> retryDelays = const <Duration>[Duration.zero],
  Duration tokenAttemptTimeout = const Duration(seconds: 1),
  Duration totalTimeout = const Duration(seconds: 2),
}) {
  return FirebaseAppCheckReadinessCoordinator(
    activationController: activation,
    tokenLoader: tokenLoader,
    tokenRetryDelays: retryDelays,
    tokenAttemptTimeout: tokenAttemptTimeout,
    totalTimeout: totalTimeout,
    delay: (_) async {},
  );
}

Future<void> _completeActivation() async {}

final class _CallbackActivator implements FirebaseAppCheckActivator {
  const _CallbackActivator(this.callback);

  final Future<void> Function() callback;

  @override
  Future<void> activate() => callback();
}
