import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_prompt_send_guard.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/failures/ai_failure_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prevents a second send while a request is in flight', () {
    final guard = AiPromptSendGuard();

    expect(guard.tryStart('first'), isNull);
    expect(guard.tryStart('second'), AiFailureCodes.requestInFlight);
  });

  test('prevents a normalized identical prompt inside duplicate window', () {
    var now = DateTime(2026, 7, 19, 12);
    final guard = AiPromptSendGuard(clock: () => now);

    expect(guard.tryStart('  Record   5 LYD  '), isNull);
    guard.complete();
    now = now.add(const Duration(seconds: 2));

    expect(guard.tryStart('record 5 lyd'), AiFailureCodes.duplicatePrompt);
  });

  test('allows the same prompt after the duplicate window', () {
    var now = DateTime(2026, 7, 19, 12);
    final guard = AiPromptSendGuard(clock: () => now);

    expect(guard.tryStart('Record 5 LYD'), isNull);
    guard.complete();
    now = now.add(const Duration(seconds: 6));

    expect(guard.tryStart('Record 5 LYD'), isNull);
  });

  test('debounces a different prompt sent immediately after completion', () {
    var now = DateTime(2026, 7, 19, 12);
    final guard = AiPromptSendGuard(clock: () => now);

    expect(guard.tryStart('first'), isNull);
    guard.complete();
    now = now.add(const Duration(milliseconds: 100));

    expect(guard.tryStart('second'), AiFailureCodes.requestTooFast);
  });
}
