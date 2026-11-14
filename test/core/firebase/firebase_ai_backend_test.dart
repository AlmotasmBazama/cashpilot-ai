import 'package:cashpilot_ai/core/firebase/firebase_ai_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vertex global is the fail-closed Firebase AI default', () {
    final config = FirebaseAiBackendConfig.resolve();

    expect(config.backend, FirebaseAiBackend.vertexAi);
    expect(config.vertexLocation, 'global');
  });

  test('Gemini Developer API remains an explicit override', () {
    for (final value in <String>[
      'google',
      'googleAI',
      'google_ai',
      'developer',
    ]) {
      expect(
        FirebaseAiBackendConfig.resolve(backendValue: value).backend,
        FirebaseAiBackend.googleAi,
        reason: value,
      );
    }
  });

  test('unsupported Vertex regions fail closed to global', () {
    final config = FirebaseAiBackendConfig.resolve(
      backendValue: 'vertex',
      vertexLocationValue: 'us-central1',
    );

    expect(config.backend, FirebaseAiBackend.vertexAi);
    expect(config.vertexLocation, 'global');
  });
}
