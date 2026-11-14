enum AuthTraceStage {
  requestStarted,
  persistenceConfigured,
  providerResponded,
  profileBootstrapCompleted,
  profileHydrationCompleted,
  completed,
  failed,
}

/// Emits only correlation, operation, stage, and elapsed time.
///
/// User IDs, emails, credentials, tokens, and profile values are deliberately
/// absent so production diagnostics can measure the auth waterfall safely.
final class AuthPerformanceTrace {
  AuthPerformanceTrace.start({
    required this.operation,
    required void Function(String message) log,
    Stopwatch? stopwatch,
  }) : correlationId = 'auth-${_nextCorrelationId++}',
       _log = log,
       _stopwatch = stopwatch ?? Stopwatch() {
    _stopwatch.start();
    mark(AuthTraceStage.requestStarted);
  }

  static int _nextCorrelationId = 1;

  final String operation;
  final String correlationId;
  final void Function(String message) _log;
  final Stopwatch _stopwatch;

  void mark(AuthTraceStage stage) {
    _log(
      'auth_trace correlation=$correlationId operation=$operation '
      'stage=${stage.name} elapsed_ms=${_stopwatch.elapsedMilliseconds}',
    );
  }
}
