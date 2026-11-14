import 'dart:async';

import '../../domain/agent/ai_agent_models.dart';

abstract interface class AiAgentResponseStreamDeadline {
  Stream<AiAgentResponse> enforce(
    Stream<AiAgentResponse> source, {
    required Duration timeout,
    required AiAgentResponse timeoutResponse,
  });
}

/// Enforces the response delivery deadline without awaiting cancellation from
/// a non-cooperative provider stream.
final class DefaultAiAgentResponseStreamDeadline
    implements AiAgentResponseStreamDeadline {
  const DefaultAiAgentResponseStreamDeadline();

  @override
  Stream<AiAgentResponse> enforce(
    Stream<AiAgentResponse> source, {
    required Duration timeout,
    required AiAgentResponse timeoutResponse,
  }) {
    late final StreamController<AiAgentResponse> controller;
    StreamSubscription<AiAgentResponse>? subscription;
    Timer? timer;
    var finished = false;

    void detachSource() {
      final active = subscription;
      subscription = null;
      if (active != null) unawaited(active.cancel());
    }

    void finish() {
      if (finished) return;
      finished = true;
      timer?.cancel();
      unawaited(controller.close());
    }

    controller = StreamController<AiAgentResponse>(
      sync: true,
      onListen: () {
        timer = Timer(timeout, () {
          if (finished) return;
          controller.add(timeoutResponse);
          finish();
          detachSource();
        });
        subscription = source.listen(
          (response) {
            if (!finished) controller.add(response);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (finished) return;
            controller.addError(error, stackTrace);
            finish();
          },
          onDone: finish,
          cancelOnError: true,
        );
      },
      onCancel: () {
        finished = true;
        timer?.cancel();
        detachSource();
      },
    );
    return controller.stream;
  }
}
