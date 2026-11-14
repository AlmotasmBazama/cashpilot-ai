import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart'
    as firebase;
import 'package:cashpilot_ai/core/security/app_check_activation_status.dart'
    as core;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Firebase phase name aliases the framework-independent type', () {
    const core.AppCheckActivationPhase phaseFromLegacy =
        firebase.FirebaseAppCheckActivationPhase.available;
    const firebase.FirebaseAppCheckActivationPhase phaseFromCore =
        core.AppCheckActivationPhase.unavailable;

    expect(phaseFromLegacy, core.AppCheckActivationPhase.available);
    expect(phaseFromCore, firebase.FirebaseAppCheckActivationPhase.unavailable);
    expect(
      firebase.FirebaseAppCheckActivationPhase.values,
      orderedEquals(core.AppCheckActivationPhase.values),
    );
    expect(
      phaseFromLegacy.toString(),
      'FirebaseAppCheckActivationPhase.available',
    );
    expect(
      phaseFromLegacy.runtimeType,
      firebase.FirebaseAppCheckActivationPhase,
    );
  });

  test(
    'legacy Firebase reason name aliases the framework-independent type',
    () {
      const core.AppCheckUnavailableReason reasonFromLegacy =
          firebase.FirebaseAppCheckUnavailableReason.timedOut;
      const firebase.FirebaseAppCheckUnavailableReason reasonFromCore =
          core.AppCheckUnavailableReason.activationFailed;

      expect(reasonFromLegacy, core.AppCheckUnavailableReason.timedOut);
      expect(
        reasonFromCore,
        firebase.FirebaseAppCheckUnavailableReason.activationFailed,
      );
      expect(
        firebase.FirebaseAppCheckUnavailableReason.values,
        orderedEquals(core.AppCheckUnavailableReason.values),
      );
      expect(
        reasonFromLegacy.toString(),
        'FirebaseAppCheckUnavailableReason.timedOut',
      );
      expect(
        reasonFromLegacy.runtimeType,
        firebase.FirebaseAppCheckUnavailableReason,
      );
    },
  );

  test('legacy activation state retains safe-code behavior', () {
    const state = firebase.FirebaseAppCheckActivationState.unavailable(
      firebase.FirebaseAppCheckUnavailableReason.timedOut,
    );

    expect(state.phase, core.AppCheckActivationPhase.unavailable);
    expect(state.reason, core.AppCheckUnavailableReason.timedOut);
    expect(state.retryable, isTrue);
    expect(state.safeCode, 'firebase_app_check_timed_out');
  });
}
