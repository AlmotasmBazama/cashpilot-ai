import 'dart:async';

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transient activation failure retries and recovers', () async {
    var calls = 0;
    final controller = FirebaseAppCheckActivationController(
      activator: _FakeActivator(() async {
        calls += 1;
        if (calls == 1) {
          throw StateError('simulated transient failure');
        }
      }),
      timeout: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);

    final failed = await controller.activate();
    expect(
      failed,
      const FirebaseAppCheckActivationState.unavailable(
        FirebaseAppCheckUnavailableReason.activationFailed,
      ),
    );
    expect(failed.retryable, isTrue);

    final recovered = await controller.retry();
    expect(recovered, const FirebaseAppCheckActivationState.available());
    expect(calls, 2);
  });

  test('concurrent activation requests share one SDK activation', () async {
    final pending = Completer<void>();
    var calls = 0;
    final controller = FirebaseAppCheckActivationController(
      activator: _FakeActivator(() {
        calls += 1;
        return pending.future;
      }),
      timeout: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);

    final first = controller.activate();
    final second = controller.activate();
    expect(calls, 1);
    expect(
      controller.state,
      const FirebaseAppCheckActivationState.initializing(),
    );

    pending.complete();
    expect(await first, const FirebaseAppCheckActivationState.available());
    expect(await second, const FirebaseAppCheckActivationState.available());
    expect(
      await controller.retry(),
      const FirebaseAppCheckActivationState.available(),
    );
    expect(calls, 1);
  });

  test(
    'timeout retry joins the pending activation without duplication',
    () async {
      final pending = Completer<void>();
      var calls = 0;
      final controller = FirebaseAppCheckActivationController(
        activator: _FakeActivator(() {
          calls += 1;
          return pending.future;
        }),
        timeout: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      final timedOut = await controller.activate();
      expect(
        timedOut,
        const FirebaseAppCheckActivationState.unavailable(
          FirebaseAppCheckUnavailableReason.timedOut,
        ),
      );
      final retry = controller.retry();
      expect(calls, 1);

      pending.complete();
      expect(await retry, const FirebaseAppCheckActivationState.available());
      expect(calls, 1);
    },
  );

  test(
    'missing Web release key is typed and not retried permanently',
    () async {
      var calls = 0;
      final controller = FirebaseAppCheckActivationController(
        activator: _FakeActivator(() async {
          calls += 1;
          throw const FirebaseAppCheckConfigurationException(
            FirebaseAppCheckUnavailableReason.webSiteKeyMissing,
          );
        }),
        timeout: const Duration(seconds: 1),
      );
      addTearDown(controller.dispose);

      final state = await controller.activate();
      expect(
        state,
        const FirebaseAppCheckActivationState.unavailable(
          FirebaseAppCheckUnavailableReason.webSiteKeyMissing,
        ),
      );
      expect(state.safeCode, 'firebase_app_check_web_site_key_missing');
      expect(state.retryable, isFalse);
      expect(
        await controller.retry(),
        const FirebaseAppCheckActivationState.unavailable(
          FirebaseAppCheckUnavailableReason.webSiteKeyMissing,
        ),
      );
      expect(calls, 1);
    },
  );

  test('state stream replays current typed activation state', () async {
    final pending = Completer<void>();
    final controller = FirebaseAppCheckActivationController(
      activator: _FakeActivator(() => pending.future),
      timeout: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);

    final activation = controller.activate();
    expect(
      await controller.states.first,
      const FirebaseAppCheckActivationState.initializing(),
    );

    pending.complete();
    await activation;
    expect(
      await controller.states.first,
      const FirebaseAppCheckActivationState.available(),
    );
  });
}

final class _FakeActivator implements FirebaseAppCheckActivator {
  const _FakeActivator(this._activate);

  final Future<void> Function() _activate;

  @override
  Future<void> activate() => _activate();
}
