import 'dart:async';

import '../core/firebase/firebase_app_check_activation.dart';
import '../core/firebase/firebase_initializer.dart';

const defaultStartupInitializationTimeout = Duration(seconds: 20);

/// Runs required local storage and Firebase Core bootstrap as one bounded,
/// single-flight operation. App Check has a separate typed activation state so
/// its external configuration cannot replace the whole app with a failure UI.
final class StartupInitializer {
  StartupInitializer({
    required Future<void> Function() initializeLocalStorage,
    required FirebaseInitializer firebaseInitializer,
    required FirebaseAppCheckActivationController appCheckActivationController,
    this.timeout = defaultStartupInitializationTimeout,
  }) : _initializeLocalStorage = initializeLocalStorage,
       _firebaseInitializer = firebaseInitializer,
       _appCheckActivationController = appCheckActivationController,
       assert(timeout > Duration.zero);

  final Future<void> Function() _initializeLocalStorage;
  final FirebaseInitializer _firebaseInitializer;
  final FirebaseAppCheckActivationController _appCheckActivationController;
  final Duration timeout;

  Future<void>? _inFlight;

  Future<void> initialize() {
    final operation = _inFlight ?? _start();
    return operation.timeout(
      timeout,
      onTimeout: () => throw const StartupInitializationTimeoutException(),
    );
  }

  /// This future is intentionally not part of [initialize]. It never throws;
  /// callers may observe or retry its typed state without blocking first paint.
  Future<FirebaseAppCheckActivationState> activateAppCheck() =>
      _appCheckActivationController.activate();

  Future<void> _start() {
    final operation = _initializeOnce();
    _inFlight = operation;
    unawaited(
      operation.then<void>(
        (_) => _clear(operation),
        onError: (Object _, StackTrace _) => _clear(operation),
      ),
    );
    return operation;
  }

  Future<void> _initializeOnce() async {
    await _initializeLocalStorage();
    await _firebaseInitializer.initialize();
  }

  void _clear(Future<void> operation) {
    if (identical(_inFlight, operation)) {
      _inFlight = null;
    }
  }
}

final class StartupInitializationTimeoutException implements Exception {
  const StartupInitializationTimeoutException();

  @override
  String toString() => 'Required application initialization timed out.';
}
