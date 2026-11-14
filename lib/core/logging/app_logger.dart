import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../owner_scope/domain/owner_scope.dart';

final appLoggerProvider = Provider<AppLogger>(
  (ref) => AppLogger.instance,
  name: 'appLoggerProvider',
);

final class AppLogger {
  AppLogger._({LogOutput? output})
    : _logger = Logger(
        printer: SimplePrinter(colors: false, printTime: true),
        output: output,
      );

  AppLogger.forTesting(LogOutput output) : this._(output: output);

  static final AppLogger instance = AppLogger._();

  final Logger _logger;

  void debug(String message) => _logger.d(_safeMessage(message));

  void info(String message) => _logger.i(_safeMessage(message));

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.w(
      _safeMessage(message),
      error: _safeErrorLabel(error),
      stackTrace: stackTrace,
    );
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(
      _safeMessage(message),
      error: _safeErrorLabel(error),
      stackTrace: stackTrace,
    );
  }

  void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.f(
      _safeMessage(message),
      error: _safeErrorLabel(error),
      stackTrace: stackTrace,
    );
  }
}

Object? _safeErrorLabel(Object? error) {
  if (error == null) return null;
  if (error is OwnerScopeException) {
    return 'Redacted error (OwnerScopeException:${error.failure.name})';
  }
  return 'Redacted error (${error.runtimeType})';
}

String _safeMessage(String message) {
  var result = message
      .replaceAll(_emailPattern, '[redacted-email]')
      .replaceAll(_apiKeyPattern, '[redacted-key]')
      .replaceAll(_jwtPattern, '[redacted-token]');
  result = result.replaceAllMapped(
    _credentialAssignmentPattern,
    (match) => '${match.group(1)}[redacted]',
  );
  result = result.replaceAllMapped(
    _uidAssignmentPattern,
    (match) => '${match.group(1)}[redacted]',
  );
  result = result.replaceAllMapped(_phoneCandidatePattern, (match) {
    final candidate = match.group(0)!;
    return _phoneDigitPattern.allMatches(candidate).length >= 7
        ? '[redacted-phone]'
        : candidate;
  });
  const maxSafeLogMessageLength = 500;
  return result.length <= maxSafeLogMessageLength
      ? result
      : '${result.substring(0, maxSafeLogMessageLength)}…';
}

final _emailPattern = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');
final _apiKeyPattern = RegExp(r'AIza[0-9A-Za-z_-]{20,}|sk-[0-9A-Za-z_-]{20,}');
final _jwtPattern = RegExp(
  r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}',
);
final _credentialAssignmentPattern = RegExp(
  r'\b((?:bearer|token|secret|api[_ -]?key)\s*(?:[:=]\s*|\s+))[^\s,;]+',
  caseSensitive: false,
);
final _uidAssignmentPattern = RegExp(
  r'\b((?:uid|user[_ -]?id)\s*[:=]\s*)[^\s,;]+',
  caseSensitive: false,
);
final _phoneDigitPattern = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');
final _phoneCandidatePattern = RegExp(
  r'[0-9\u0660-\u0669\u06F0-\u06F9]'
  r'[0-9\u0660-\u0669\u06F0-\u06F9 ()+.-]{5,}'
  r'[0-9\u0660-\u0669\u06F0-\u06F9]',
);
