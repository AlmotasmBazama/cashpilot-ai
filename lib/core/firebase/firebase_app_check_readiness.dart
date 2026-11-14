import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_app_check_activation.dart';

const defaultFirebaseAppCheckReadinessTimeout = Duration(seconds: 12);
const defaultFirebaseAppCheckTokenAttemptTimeout = Duration(seconds: 2);
const defaultFirebaseAppCheckTokenRetryDelays = <Duration>[
  Duration.zero,
  Duration(milliseconds: 300),
  Duration(milliseconds: 700),
  Duration(milliseconds: 1500),
];

typedef FirebaseAppCheckTokenLoader =
    Future<String?> Function({required bool forceRefresh});
typedef FirebaseAppCheckReadinessDelay = Future<void> Function(Duration delay);

enum FirebaseAppCheckReadinessPhase {
  notStarted,
  activating,
  waitingForToken,
  ready,
  rejected,
  timedOut,
  unavailable,
}

enum FirebaseAppCheckReadinessFailureReason {
  activationUnavailable,
  tokenUnavailable,
  networkUnavailable,
  rejected,
  timedOut,
}

@immutable
final class FirebaseAppCheckReadinessState {
  const FirebaseAppCheckReadinessState._({
    required this.phase,
    this.failureReason,
    this.tokenAttempt = 0,
  });

  const FirebaseAppCheckReadinessState.notStarted()
    : this._(phase: FirebaseAppCheckReadinessPhase.notStarted);

  const FirebaseAppCheckReadinessState.activating()
    : this._(phase: FirebaseAppCheckReadinessPhase.activating);

  const FirebaseAppCheckReadinessState.waitingForToken(int tokenAttempt)
    : this._(
        phase: FirebaseAppCheckReadinessPhase.waitingForToken,
        tokenAttempt: tokenAttempt,
      );

  const FirebaseAppCheckReadinessState.ready()
    : this._(phase: FirebaseAppCheckReadinessPhase.ready);

  FirebaseAppCheckReadinessState.failed(
    FirebaseAppCheckReadinessFailureReason reason,
  ) : phase = switch (reason) {
        FirebaseAppCheckReadinessFailureReason.rejected =>
          FirebaseAppCheckReadinessPhase.rejected,
        FirebaseAppCheckReadinessFailureReason.timedOut =>
          FirebaseAppCheckReadinessPhase.timedOut,
        _ => FirebaseAppCheckReadinessPhase.unavailable,
      },
      failureReason = reason,
      tokenAttempt = 0;

  final FirebaseAppCheckReadinessPhase phase;
  final FirebaseAppCheckReadinessFailureReason? failureReason;
  final int tokenAttempt;

  bool get isReady => phase == FirebaseAppCheckReadinessPhase.ready;

  bool get retryable => switch (phase) {
    FirebaseAppCheckReadinessPhase.rejected ||
    FirebaseAppCheckReadinessPhase.timedOut ||
    FirebaseAppCheckReadinessPhase.unavailable => true,
    _ => false,
  };

  String get safeCode => switch (phase) {
    FirebaseAppCheckReadinessPhase.notStarted => 'appCheckNotStarted',
    FirebaseAppCheckReadinessPhase.activating => 'appCheckActivating',
    FirebaseAppCheckReadinessPhase.waitingForToken => 'appCheckWaitingForToken',
    FirebaseAppCheckReadinessPhase.ready => 'appCheckReady',
    FirebaseAppCheckReadinessPhase.rejected => 'appCheckRejected',
    FirebaseAppCheckReadinessPhase.timedOut => 'appCheckTimedOut',
    FirebaseAppCheckReadinessPhase.unavailable =>
      failureReason == FirebaseAppCheckReadinessFailureReason.networkUnavailable
          ? 'appCheckNetworkUnavailable'
          : 'appCheckUnavailable',
  };

  @override
  bool operator ==(Object other) =>
      other is FirebaseAppCheckReadinessState &&
      other.phase == phase &&
      other.failureReason == failureReason &&
      other.tokenAttempt == tokenAttempt;

  @override
  int get hashCode => Object.hash(phase, failureReason, tokenAttempt);

  @override
  String toString() => safeCode;
}

final class FirebaseAppCheckReadinessException implements Exception {
  const FirebaseAppCheckReadinessException(this.reason);

  final FirebaseAppCheckReadinessFailureReason reason;

  String get safeCode => switch (reason) {
    FirebaseAppCheckReadinessFailureReason.activationUnavailable ||
    FirebaseAppCheckReadinessFailureReason.tokenUnavailable =>
      'appCheckUnavailable',
    FirebaseAppCheckReadinessFailureReason.networkUnavailable =>
      'appCheckNetworkUnavailable',
    FirebaseAppCheckReadinessFailureReason.rejected => 'appCheckRejected',
    FirebaseAppCheckReadinessFailureReason.timedOut => 'appCheckTimedOut',
  };

  @override
  String toString() => 'FirebaseAppCheckReadinessException($safeCode)';
}

final class FirebaseAppCheckReadinessCancelledException implements Exception {
  const FirebaseAppCheckReadinessCancelledException();

  @override
  String toString() => 'Firebase App Check readiness wait was cancelled.';
}

/// The single process-memory gate between App Check startup and remote AI.
///
/// It joins the bootstrap activation operation, retries only token acquisition
/// failures that can be transient, and never retries an HTTP rejection. The
/// latter is reported by the gateway through [reportRejected]. No token or raw
/// SDK error is retained in state or diagnostics.
final class FirebaseAppCheckReadinessCoordinator {
  FirebaseAppCheckReadinessCoordinator({
    required FirebaseAppCheckActivationController activationController,
    required FirebaseAppCheckTokenLoader tokenLoader,
    this.totalTimeout = defaultFirebaseAppCheckReadinessTimeout,
    this.tokenAttemptTimeout = defaultFirebaseAppCheckTokenAttemptTimeout,
    List<Duration> tokenRetryDelays = defaultFirebaseAppCheckTokenRetryDelays,
    FirebaseAppCheckReadinessDelay delay = _defaultDelay,
    void Function(String safeEvent)? safeDiagnosticLog,
  }) : _activationController = activationController,
       _tokenLoader = tokenLoader,
       tokenRetryDelays = List<Duration>.unmodifiable(tokenRetryDelays),
       _delay = delay,
       _safeDiagnosticLog = safeDiagnosticLog,
       assert(totalTimeout > Duration.zero),
       assert(tokenAttemptTimeout > Duration.zero),
       assert(tokenRetryDelays.isNotEmpty),
       assert(tokenRetryDelays.every((value) => value >= Duration.zero));

  final FirebaseAppCheckActivationController _activationController;
  final FirebaseAppCheckTokenLoader _tokenLoader;
  final Duration totalTimeout;
  final Duration tokenAttemptTimeout;
  final List<Duration> tokenRetryDelays;
  final FirebaseAppCheckReadinessDelay _delay;
  final void Function(String safeEvent)? _safeDiagnosticLog;
  final StreamController<FirebaseAppCheckReadinessState> _stateChanges =
      StreamController<FirebaseAppCheckReadinessState>.broadcast(sync: true);

  FirebaseAppCheckReadinessState _state =
      const FirebaseAppCheckReadinessState.notStarted();
  Future<String>? _inFlight;
  var _operationGeneration = 0;
  var _disposed = false;

  FirebaseAppCheckReadinessState get state => _state;

  Stream<FirebaseAppCheckReadinessState> get states => Stream.multi((events) {
    events.add(_state);
    final subscription = _stateChanges.stream.listen(
      events.add,
      onError: events.addError,
      onDone: events.close,
    );
    events.onCancel = subscription.cancel;
  }, isBroadcast: true);

  /// Obtains one usable token after activation. Concurrent callers join the
  /// same bounded native operation instead of multiplying token requests.
  Future<String> getToken() {
    if (_disposed) {
      return Future<String>.error(
        const FirebaseAppCheckReadinessCancelledException(),
      );
    }
    final pending = _inFlight;
    if (pending != null) return pending;

    final generation = ++_operationGeneration;
    final operation = _obtainToken(generation);
    _inFlight = operation;
    unawaited(
      operation.then<void>(
        (_) => _clearOperation(operation),
        onError: (Object _, StackTrace _) => _clearOperation(operation),
      ),
    );
    return operation;
  }

  /// Marks an explicit user retry. Token acquisition remains in [getToken],
  /// so Retry never prefetches one token and sends with another.
  void requestRetry() {
    if (_disposed || _inFlight != null) return;
    _operationGeneration++;
    _publish(const FirebaseAppCheckReadinessState.notStarted());
    _diagnose('retry_requested');
  }

  /// Records an authoritative gateway rejection. This method does not start
  /// another token or HTTP attempt; only a later explicit request may retry.
  void reportRejected() {
    if (_disposed) return;
    // A different caller may already be refreshing App Check after the token
    // that the gateway rejected was issued. That newer single-flight operation
    // supersedes the older rejection; cancelling it here would surface an
    // unrelated egress-revoked failure to Chat or the Settings probe.
    if (_inFlight != null) {
      _diagnose('stale_rejection_ignored');
      return;
    }
    _publish(
      FirebaseAppCheckReadinessState.failed(
        FirebaseAppCheckReadinessFailureReason.rejected,
      ),
    );
    _diagnose('rejected');
  }

  Future<String> _obtainToken(int generation) async {
    final stopwatch = Stopwatch()..start();
    try {
      await _ensureActivated(generation, stopwatch);
      var lastFailure = FirebaseAppCheckReadinessFailureReason.tokenUnavailable;

      for (var index = 0; index < tokenRetryDelays.length; index++) {
        _ensureCurrent(generation);
        final retryDelay = tokenRetryDelays[index];
        if (retryDelay > Duration.zero) {
          try {
            await _boundedWait<void>(_delay(retryDelay), stopwatch: stopwatch);
          } on TimeoutException {
            _fail(generation, FirebaseAppCheckReadinessFailureReason.timedOut);
          }
        }
        _ensureCurrent(generation);
        final attempt = index + 1;
        _publish(
          FirebaseAppCheckReadinessState.waitingForToken(attempt),
          operationGeneration: generation,
        );
        _diagnose('token_attempt_started_$attempt', elapsed: stopwatch.elapsed);
        try {
          final token = await _boundedWait<String?>(
            _tokenLoader(forceRefresh: true),
            stopwatch: stopwatch,
            perAttemptTimeout: tokenAttemptTimeout,
          );
          _ensureCurrent(generation);
          if (token != null && token.trim().isNotEmpty) {
            _publish(
              const FirebaseAppCheckReadinessState.ready(),
              operationGeneration: generation,
            );
            _diagnose('token_completed', elapsed: stopwatch.elapsed);
            return token;
          }
          lastFailure = FirebaseAppCheckReadinessFailureReason.tokenUnavailable;
        } on TimeoutException {
          lastFailure = FirebaseAppCheckReadinessFailureReason.timedOut;
        } on FirebaseAppCheckReadinessCancelledException {
          rethrow;
        } on Object catch (error) {
          if (_isConfirmedRejection(error)) {
            _fail(generation, FirebaseAppCheckReadinessFailureReason.rejected);
          }
          lastFailure = _isNetworkFailure(error)
              ? FirebaseAppCheckReadinessFailureReason.networkUnavailable
              : FirebaseAppCheckReadinessFailureReason.tokenUnavailable;
        }
      }

      _fail(generation, lastFailure);
    } finally {
      stopwatch.stop();
    }
  }

  Future<void> _ensureActivated(int generation, Stopwatch stopwatch) async {
    var activation = _activationController.state;
    if (activation.isAvailable) return;

    // One bounded retry covers a transient bootstrap activation failure. An
    // initializing activation is joined by the controller and never duplicated.
    for (var attempt = 0; attempt < 2; attempt++) {
      _ensureCurrent(generation);
      _publish(
        const FirebaseAppCheckReadinessState.activating(),
        operationGeneration: generation,
      );
      _diagnose('activation_started', elapsed: stopwatch.elapsed);
      try {
        activation = await _boundedWait<FirebaseAppCheckActivationState>(
          activation.phase == FirebaseAppCheckActivationPhase.unavailable &&
                  activation.retryable
              ? _activationController.retry()
              : _activationController.activate(),
          stopwatch: stopwatch,
        );
      } on TimeoutException {
        _fail(generation, FirebaseAppCheckReadinessFailureReason.timedOut);
      }
      _ensureCurrent(generation);
      if (activation.isAvailable) {
        _diagnose('activation_completed', elapsed: stopwatch.elapsed);
        return;
      }
      final timedOut =
          activation.reason == FirebaseAppCheckUnavailableReason.timedOut;
      if (!activation.retryable || attempt == 1) {
        _fail(
          generation,
          timedOut
              ? FirebaseAppCheckReadinessFailureReason.timedOut
              : FirebaseAppCheckReadinessFailureReason.activationUnavailable,
        );
      }
      try {
        await _boundedWait<void>(
          _delay(const Duration(milliseconds: 300)),
          stopwatch: stopwatch,
        );
      } on TimeoutException {
        _fail(generation, FirebaseAppCheckReadinessFailureReason.timedOut);
      }
    }
  }

  Future<T> _boundedWait<T>(
    Future<T> future, {
    required Stopwatch stopwatch,
    Duration? perAttemptTimeout,
  }) {
    final remaining = totalTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      return Future<T>.error(TimeoutException('App Check readiness timeout'));
    }
    final timeout = perAttemptTimeout != null && perAttemptTimeout < remaining
        ? perAttemptTimeout
        : remaining;
    return future.timeout(timeout);
  }

  Never _fail(int generation, FirebaseAppCheckReadinessFailureReason reason) {
    _ensureCurrent(generation);
    _publish(
      FirebaseAppCheckReadinessState.failed(reason),
      operationGeneration: generation,
    );
    _diagnose(FirebaseAppCheckReadinessException(reason).safeCode);
    throw FirebaseAppCheckReadinessException(reason);
  }

  void _ensureCurrent(int generation) {
    if (_disposed || generation != _operationGeneration) {
      throw const FirebaseAppCheckReadinessCancelledException();
    }
  }

  void _clearOperation(Future<String> operation) {
    if (identical(_inFlight, operation)) _inFlight = null;
  }

  void _publish(
    FirebaseAppCheckReadinessState next, {
    int? operationGeneration,
  }) {
    if (_disposed ||
        (operationGeneration != null &&
            operationGeneration != _operationGeneration) ||
        next == _state) {
      return;
    }
    _state = next;
    _stateChanges.add(next);
  }

  void _diagnose(String event, {Duration? elapsed}) {
    _safeDiagnosticLog?.call(
      'firebase_app_check_readiness event=$event'
      '${elapsed == null ? '' : ' elapsedMs=${elapsed.inMilliseconds}'}',
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operationGeneration++;
    unawaited(_stateChanges.close());
  }
}

Future<void> _defaultDelay(Duration delay) => Future<void>.delayed(delay);

bool _isConfirmedRejection(Object error) {
  final normalized = switch (error) {
    FirebaseException(:final code, :final message) =>
      '$code ${message ?? ''}'.toLowerCase(),
    _ => error.toString().toLowerCase(),
  };
  final namedRejection = const <String>[
    'app-check-rejected',
    'app_check_rejected',
    'invalid-token',
    'permission-denied',
    'unauthorized',
    'forbidden',
    'http 403',
  ].any(normalized.contains);
  return namedRejection ||
      RegExp(r'(^|[^0-9])403([^0-9]|$)').hasMatch(normalized);
}

bool _isNetworkFailure(Object error) {
  final normalized = switch (error) {
    FirebaseException(:final code, :final message) =>
      '$code ${message ?? ''}'.toLowerCase(),
    _ => error.toString().toLowerCase(),
  };
  return const <String>[
    'network-request-failed',
    'network_error',
    'server-unreachable',
    'socket',
    'connection',
    'failed host lookup',
    'offline',
    'xmlhttprequest',
  ].any(normalized.contains);
}
