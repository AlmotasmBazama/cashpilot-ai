import '../../domain/failures/ai_failure_codes.dart';

typedef AiGuardClock = DateTime Function();

class AiPromptSendGuard {
  AiPromptSendGuard({
    AiGuardClock? clock,
    this.debounceWindow = const Duration(milliseconds: 500),
    this.duplicateWindow = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now;

  final AiGuardClock _clock;
  final Duration debounceWindow;
  final Duration duplicateWindow;

  bool _isInFlight = false;
  String? _lastPrompt;
  DateTime? _lastStartedAt;

  bool get isInFlight => _isInFlight;

  String? tryStart(String prompt) {
    if (_isInFlight) {
      return AiFailureCodes.requestInFlight;
    }

    final normalized = _normalize(prompt);
    final now = _clock();
    final lastStartedAt = _lastStartedAt;
    if (lastStartedAt != null) {
      final elapsed = now.difference(lastStartedAt);
      if (normalized == _lastPrompt && elapsed < duplicateWindow) {
        return AiFailureCodes.duplicatePrompt;
      }
      if (elapsed < debounceWindow) {
        return AiFailureCodes.requestTooFast;
      }
    }

    _isInFlight = true;
    _lastPrompt = normalized;
    _lastStartedAt = now;
    return null;
  }

  void complete() {
    _isInFlight = false;
  }

  void reset() {
    _isInFlight = false;
    _lastPrompt = null;
    _lastStartedAt = null;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
