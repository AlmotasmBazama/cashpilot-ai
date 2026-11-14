import 'package:cashpilot_ai/features/auth/domain/services/auth_performance_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth trace logs only safe correlation-stage timing fields', () {
    final messages = <String>[];
    final trace = AuthPerformanceTrace.start(
      operation: 'sign_in',
      log: messages.add,
    );

    trace
      ..mark(AuthTraceStage.providerResponded)
      ..mark(AuthTraceStage.profileBootstrapCompleted)
      ..mark(AuthTraceStage.completed);

    expect(messages, hasLength(4));
    expect(messages.every((message) => message.contains('auth_trace')), isTrue);
    expect(
      messages.every((message) => message.contains('operation=sign_in')),
      isTrue,
    );
    expect(
      messages.every((message) => message.contains('elapsed_ms=')),
      isTrue,
    );
    expect(messages.join(' '), isNot(contains('@')));
    expect(messages.join(' '), isNot(contains('token')));
    expect(messages.join(' '), isNot(contains('password')));
  });
}
