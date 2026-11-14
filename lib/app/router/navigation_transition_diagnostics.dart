import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationTransitionDiagnosticsProvider =
    Provider<NavigationTransitionDiagnostics>(
      (_) => NavigationTransitionDiagnostics(),
      name: 'navigationTransitionDiagnosticsProvider',
    );

enum NavigationTransitionCause {
  userTap,
  explicitAssistantNavigationTool,
  authInitializing,
  authStateConfirmed,
  authSignedOut,
  onboardingIncomplete,
  emailVerificationRequired,
  profileCompletionRequired,
  unknownUnexpected,
}

@immutable
class NavigationTransitionRecord {
  const NavigationTransitionRecord({
    required this.previousPath,
    required this.nextPath,
    required this.cause,
    required this.safeReason,
    required this.duringAiSend,
  });

  final String previousPath;
  final String nextPath;
  final NavigationTransitionCause cause;
  final String safeReason;
  final bool duringAiSend;
}

class NavigationTransitionDiagnostics {
  final List<NavigationTransitionRecord> _records =
      <NavigationTransitionRecord>[];
  NavigationTransitionCause? _pendingCause;
  String? _pendingReason;
  String? _pendingPath;
  int _activeAiSends = 0;

  List<NavigationTransitionRecord> get records =>
      List<NavigationTransitionRecord>.unmodifiable(_records);

  bool get hasUnexpectedAiSendTransition => _records.any(
    (record) =>
        record.duringAiSend &&
        record.cause == NavigationTransitionCause.unknownUnexpected,
  );

  void beginAiSend() {
    if (!kDebugMode) {
      return;
    }
    _activeAiSends += 1;
  }

  void endAiSend() {
    if (!kDebugMode) {
      return;
    }
    if (_activeAiSends > 0) {
      _activeAiSends -= 1;
    }
  }

  void markNextTransition({
    required NavigationTransitionCause cause,
    required String safeReason,
    String? expectedPath,
  }) {
    if (!kDebugMode) {
      return;
    }
    _pendingCause = cause;
    _pendingReason = safeReason;
    _pendingPath = expectedPath;
  }

  void recordLocationChange({
    required String previousPath,
    required String nextPath,
  }) {
    if (!kDebugMode || previousPath == nextPath) {
      return;
    }
    final hasMatchingPendingPath =
        _pendingPath == null || _pendingPath == nextPath;
    final cause = hasMatchingPendingPath ? _pendingCause : null;
    final reason = hasMatchingPendingPath ? _pendingReason : null;
    final resolvedCause =
        cause ??
        (_activeAiSends > 0
            ? NavigationTransitionCause.unknownUnexpected
            : NavigationTransitionCause.userTap);
    final record = NavigationTransitionRecord(
      previousPath: previousPath,
      nextPath: nextPath,
      cause: resolvedCause,
      safeReason:
          reason ??
          (_activeAiSends > 0
              ? 'route_changed_during_ai_send'
              : 'explicit_user_navigation'),
      duringAiSend: _activeAiSends > 0,
    );
    _records.add(record);
    debugPrint(
      '[Navigation] ${record.previousPath} -> ${record.nextPath}; '
      'cause=${record.cause.name}; reason=${record.safeReason}',
    );
    _pendingCause = null;
    _pendingReason = null;
    _pendingPath = null;
  }

  @visibleForTesting
  void clear() {
    _records.clear();
    _pendingCause = null;
    _pendingReason = null;
    _pendingPath = null;
    _activeAiSends = 0;
  }
}
