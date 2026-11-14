import 'dart:async';

import 'package:cashpilot_ai/app/startup_initializer.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required startup completes local storage before Firebase', () async {
    final events = <String>[];
    final initializer = StartupInitializer(
      initializeLocalStorage: () async => events.add('local'),
      firebaseInitializer: _FakeFirebaseInitializer(
        () async => events.add('firebase'),
      ),
      appCheckActivationController: _availableAppCheckController(),
      timeout: const Duration(seconds: 1),
    );

    await initializer.initialize();

    expect(events, <String>['local', 'firebase']);
  });

  test('hung Firebase startup ends with a typed bounded failure', () async {
    final firebase = Completer<void>();
    final initializer = StartupInitializer(
      initializeLocalStorage: () async {},
      firebaseInitializer: _FakeFirebaseInitializer(() => firebase.future),
      appCheckActivationController: _availableAppCheckController(),
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      initializer.initialize(),
      throwsA(isA<StartupInitializationTimeoutException>()),
    );
  });

  test('retry shares initialization still pending after a timeout', () async {
    final localStorage = Completer<void>();
    var localCalls = 0;
    var firebaseCalls = 0;
    final initializer = StartupInitializer(
      initializeLocalStorage: () {
        localCalls += 1;
        return localStorage.future;
      },
      firebaseInitializer: _FakeFirebaseInitializer(() async {
        firebaseCalls += 1;
      }),
      appCheckActivationController: _availableAppCheckController(),
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      initializer.initialize(),
      throwsA(isA<StartupInitializationTimeoutException>()),
    );

    final retry = initializer.initialize();
    expect(localCalls, 1);
    localStorage.complete();
    await retry;

    expect(localCalls, 1);
    expect(firebaseCalls, 1);
  });

  test('App Check activation failure cannot fail required startup', () async {
    final controller = FirebaseAppCheckActivationController(
      activator: _FakeAppCheckActivator(
        () async => throw StateError('simulated activation failure'),
      ),
      timeout: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    final initializer = StartupInitializer(
      initializeLocalStorage: () async {},
      firebaseInitializer: _FakeFirebaseInitializer(() async {}),
      appCheckActivationController: controller,
      timeout: const Duration(seconds: 1),
    );

    await expectLater(initializer.initialize(), completes);
    final state = await initializer.activateAppCheck();

    expect(state.phase, FirebaseAppCheckActivationPhase.unavailable);
    expect(state.reason, FirebaseAppCheckUnavailableReason.activationFailed);
    expect(state.retryable, isTrue);
  });

  test('hung App Check activation cannot delay required startup', () async {
    final pending = Completer<void>();
    final controller = FirebaseAppCheckActivationController(
      activator: _FakeAppCheckActivator(() => pending.future),
      timeout: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    final initializer = StartupInitializer(
      initializeLocalStorage: () async {},
      firebaseInitializer: _FakeFirebaseInitializer(() async {}),
      appCheckActivationController: controller,
      timeout: const Duration(seconds: 1),
    );

    await expectLater(initializer.initialize(), completes);
    final state = await initializer.activateAppCheck();

    expect(
      state,
      const FirebaseAppCheckActivationState.unavailable(
        FirebaseAppCheckUnavailableReason.timedOut,
      ),
    );
    pending.complete();
  });
}

final class _FakeFirebaseInitializer implements FirebaseInitializer {
  const _FakeFirebaseInitializer(this._initialize);

  final Future<void> Function() _initialize;

  @override
  Future<void> initialize() => _initialize();
}

FirebaseAppCheckActivationController _availableAppCheckController() =>
    FirebaseAppCheckActivationController(
      activator: _FakeAppCheckActivator(() async {}),
    );

final class _FakeAppCheckActivator implements FirebaseAppCheckActivator {
  const _FakeAppCheckActivator(this._activate);

  final Future<void> Function() _activate;

  @override
  Future<void> activate() => _activate();
}
