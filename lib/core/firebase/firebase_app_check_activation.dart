import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../security/app_check_activation_status.dart';

export '../security/app_check_activation_status.dart'
    show
        AppCheckActivationPhase,
        AppCheckUnavailableReason,
        FirebaseAppCheckActivationPhase,
        FirebaseAppCheckUnavailableReason;

const defaultFirebaseAppCheckActivationTimeout = Duration(seconds: 10);

const _firebaseAppCheckDebugTokenWasSupplied = bool.hasEnvironment(
  'FIREBASE_APP_CHECK_DEBUG_TOKEN',
);
const firebaseAppCheckDebugToken = kReleaseMode
    ? ''
    : String.fromEnvironment('FIREBASE_APP_CHECK_DEBUG_TOKEN');
const _firebaseAppCheckRecaptchaEnterpriseSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY',
);

@immutable
final class FirebaseAppCheckActivationState {
  const FirebaseAppCheckActivationState._({required this.phase, this.reason});

  const FirebaseAppCheckActivationState.idle()
    : this._(phase: FirebaseAppCheckActivationPhase.idle);

  const FirebaseAppCheckActivationState.initializing()
    : this._(phase: FirebaseAppCheckActivationPhase.initializing);

  const FirebaseAppCheckActivationState.available()
    : this._(phase: FirebaseAppCheckActivationPhase.available);

  const FirebaseAppCheckActivationState.unavailable(
    FirebaseAppCheckUnavailableReason reason,
  ) : this._(
        phase: FirebaseAppCheckActivationPhase.unavailable,
        reason: reason,
      );

  final FirebaseAppCheckActivationPhase phase;
  final FirebaseAppCheckUnavailableReason? reason;

  bool get isAvailable => phase == FirebaseAppCheckActivationPhase.available;

  bool get retryable => switch (reason) {
    FirebaseAppCheckUnavailableReason.timedOut ||
    FirebaseAppCheckUnavailableReason.activationFailed => true,
    _ => false,
  };

  String get safeCode => switch ((phase, reason)) {
    (FirebaseAppCheckActivationPhase.idle, _) => 'firebase_app_check_idle',
    (FirebaseAppCheckActivationPhase.initializing, _) =>
      'firebase_app_check_initializing',
    (FirebaseAppCheckActivationPhase.available, _) =>
      'firebase_app_check_available',
    (
      FirebaseAppCheckActivationPhase.unavailable,
      FirebaseAppCheckUnavailableReason.releaseDebugTokenForbidden,
    ) =>
      'firebase_app_check_release_debug_token_forbidden',
    (
      FirebaseAppCheckActivationPhase.unavailable,
      FirebaseAppCheckUnavailableReason.webSiteKeyMissing,
    ) =>
      'firebase_app_check_web_site_key_missing',
    (
      FirebaseAppCheckActivationPhase.unavailable,
      FirebaseAppCheckUnavailableReason.unsupportedPlatform,
    ) =>
      'firebase_app_check_unsupported_platform',
    (
      FirebaseAppCheckActivationPhase.unavailable,
      FirebaseAppCheckUnavailableReason.timedOut,
    ) =>
      'firebase_app_check_timed_out',
    (
      FirebaseAppCheckActivationPhase.unavailable,
      FirebaseAppCheckUnavailableReason.activationFailed,
    ) =>
      'firebase_app_check_activation_failed',
    (FirebaseAppCheckActivationPhase.unavailable, null) =>
      'firebase_app_check_activation_failed',
  };

  @override
  bool operator ==(Object other) =>
      other is FirebaseAppCheckActivationState &&
      other.phase == phase &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(phase, reason);

  @override
  String toString() => safeCode;
}

abstract interface class FirebaseAppCheckActivator {
  Future<void> activate();
}

final class FirebaseAppCheckActivationController {
  FirebaseAppCheckActivationController({
    required FirebaseAppCheckActivator activator,
    this.timeout = defaultFirebaseAppCheckActivationTimeout,
  }) : _activator = activator,
       assert(timeout > Duration.zero);

  final FirebaseAppCheckActivator _activator;
  final Duration timeout;
  final StreamController<FirebaseAppCheckActivationState> _stateChanges =
      StreamController<FirebaseAppCheckActivationState>.broadcast(sync: true);

  FirebaseAppCheckActivationState _state =
      const FirebaseAppCheckActivationState.idle();
  Future<void>? _inFlight;
  bool _disposed = false;

  FirebaseAppCheckActivationState get state => _state;

  /// Replays the current state when observed, then emits every transition.
  Stream<FirebaseAppCheckActivationState> get states => Stream.multi((events) {
    events.add(_state);
    final subscription = _stateChanges.stream.listen(
      events.add,
      onError: events.addError,
      onDone: events.close,
    );
    events.onCancel = subscription.cancel;
  }, isBroadcast: true);

  /// Starts or joins activation and always resolves to a typed availability
  /// state. SDK/configuration errors never escape into required app startup.
  Future<FirebaseAppCheckActivationState> activate() {
    if (_disposed || _state.isAvailable) {
      return Future.value(_state);
    }
    if (_state.phase == FirebaseAppCheckActivationPhase.unavailable &&
        !_state.retryable &&
        _inFlight == null) {
      return Future.value(_state);
    }
    return _startOrJoin();
  }

  Future<FirebaseAppCheckActivationState> retry() {
    if (_disposed ||
        _state.isAvailable ||
        (_state.phase == FirebaseAppCheckActivationPhase.unavailable &&
            !_state.retryable &&
            _inFlight == null)) {
      return Future.value(_state);
    }
    return _startOrJoin();
  }

  Future<FirebaseAppCheckActivationState> _startOrJoin() {
    final operation = _inFlight ?? _start();
    _publish(const FirebaseAppCheckActivationState.initializing());
    return operation
        .then((_) => _state, onError: (Object _, StackTrace _) => _state)
        .timeout(
          timeout,
          onTimeout: () {
            if (identical(_inFlight, operation)) {
              _publish(
                const FirebaseAppCheckActivationState.unavailable(
                  FirebaseAppCheckUnavailableReason.timedOut,
                ),
              );
            }
            return _state;
          },
        );
  }

  Future<void> _start() {
    final operation = Future<void>.sync(_activator.activate);
    _inFlight = operation;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_inFlight, operation)) {
            _inFlight = null;
            _publish(const FirebaseAppCheckActivationState.available());
          }
        },
        onError: (Object error, StackTrace _) {
          if (identical(_inFlight, operation)) {
            _inFlight = null;
            _publish(
              FirebaseAppCheckActivationState.unavailable(
                error is FirebaseAppCheckConfigurationException
                    ? error.reason
                    : FirebaseAppCheckUnavailableReason.activationFailed,
              ),
            );
          }
        },
      ),
    );
    return operation;
  }

  void _publish(FirebaseAppCheckActivationState next) {
    if (_disposed || next == _state) {
      return;
    }
    _state = next;
    _stateChanges.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _stateChanges.close();
  }
}

final class FirebaseAppCheckConfigurationException implements Exception {
  const FirebaseAppCheckConfigurationException(this.reason);

  final FirebaseAppCheckUnavailableReason reason;

  @override
  String toString() => 'Firebase App Check is unavailable (${reason.name}).';
}

final class DefaultFirebaseAppCheckActivator
    implements FirebaseAppCheckActivator {
  const DefaultFirebaseAppCheckActivator();

  @override
  Future<void> activate() {
    if (_defaultAppCheckActivated) {
      return Future.value();
    }
    final pending = _defaultAppCheckActivationInFlight;
    if (pending != null) {
      return pending;
    }
    final operation = Future<void>.sync(_activateOnce);
    _defaultAppCheckActivationInFlight = operation;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_defaultAppCheckActivationInFlight, operation)) {
            _defaultAppCheckActivated = true;
            _defaultAppCheckActivationInFlight = null;
          }
        },
        onError: (Object _, StackTrace _) {
          if (identical(_defaultAppCheckActivationInFlight, operation)) {
            _defaultAppCheckActivationInFlight = null;
          }
        },
      ),
    );
    return operation;
  }

  Future<void> _activateOnce() async {
    if (kReleaseMode && _firebaseAppCheckDebugTokenWasSupplied) {
      throw const FirebaseAppCheckConfigurationException(
        FirebaseAppCheckUnavailableReason.releaseDebugTokenForbidden,
      );
    }
    if (kReleaseMode &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows) {
      throw const FirebaseAppCheckConfigurationException(
        FirebaseAppCheckUnavailableReason.unsupportedPlatform,
      );
    }

    final androidProvider = kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : firebaseAppCheckDebugToken.isEmpty
        ? const AndroidDebugProvider()
        : const AndroidDebugProvider(debugToken: firebaseAppCheckDebugToken);
    final appleProvider = kReleaseMode
        ? const AppleAppAttestWithDeviceCheckFallbackProvider()
        : firebaseAppCheckDebugToken.isEmpty
        ? const AppleDebugProvider()
        : const AppleDebugProvider(debugToken: firebaseAppCheckDebugToken);
    final WebProvider? webProvider = kIsWeb
        ? kReleaseMode
              ? _productionWebProvider()
              : firebaseAppCheckDebugToken.isEmpty
              ? WebDebugProvider()
              : WebDebugProvider(debugToken: firebaseAppCheckDebugToken)
        : null;

    await FirebaseAppCheck.instance.activate(
      providerWeb: webProvider,
      providerAndroid: androidProvider,
      providerApple: appleProvider,
      providerWindows: firebaseAppCheckDebugToken.isEmpty
          ? const WindowsDebugProvider()
          : const WindowsDebugProvider(debugToken: firebaseAppCheckDebugToken),
    );
  }
}

WebProvider _productionWebProvider() {
  if (_firebaseAppCheckRecaptchaEnterpriseSiteKey.isEmpty) {
    throw const FirebaseAppCheckConfigurationException(
      FirebaseAppCheckUnavailableReason.webSiteKeyMissing,
    );
  }
  return ReCaptchaEnterpriseProvider(
    _firebaseAppCheckRecaptchaEnterpriseSiteKey,
  );
}

var _defaultAppCheckActivated = false;
Future<void>? _defaultAppCheckActivationInFlight;

final defaultFirebaseAppCheckActivationController =
    FirebaseAppCheckActivationController(
      activator: const DefaultFirebaseAppCheckActivator(),
    );
