import 'package:firebase_ai/firebase_ai.dart' as firebase_ai;

enum FirebaseAiBackend { vertexAi, googleAi }

/// Selects the Firebase AI Logic API provider without changing the app-level
/// Firebase provider contract.
///
/// Vertex AI is the default because it uses the project's linked Cloud Billing
/// account. The Gemini Developer API remains an explicit override for projects
/// that maintain AI Studio prepayment credits.
final class FirebaseAiBackendConfig {
  const FirebaseAiBackendConfig({
    required this.backend,
    this.vertexLocation = 'global',
  });

  static const String backendDefine = 'CASH_PILOT_FIREBASE_AI_BACKEND';
  static const String vertexLocationDefine =
      'CASH_PILOT_FIREBASE_AI_VERTEX_LOCATION';

  static final FirebaseAiBackendConfig current =
      FirebaseAiBackendConfig.resolve(
        backendValue: const String.fromEnvironment(
          backendDefine,
          defaultValue: 'vertex',
        ),
        vertexLocationValue: const String.fromEnvironment(
          vertexLocationDefine,
          defaultValue: 'global',
        ),
      );

  final FirebaseAiBackend backend;
  final String vertexLocation;

  factory FirebaseAiBackendConfig.resolve({
    String backendValue = 'vertex',
    String vertexLocationValue = 'global',
  }) {
    final normalized = backendValue.trim().toLowerCase();
    final backend = switch (normalized) {
      'google' ||
      'googleai' ||
      'google_ai' ||
      'developer' ||
      'developer_api' => FirebaseAiBackend.googleAi,
      _ => FirebaseAiBackend.vertexAi,
    };
    // Gemini 3.x requires Vertex's global location. Fail closed to that
    // supported location instead of accepting a region that will reject it.
    final requestedLocation = vertexLocationValue.trim().toLowerCase();
    final location = requestedLocation == 'global'
        ? requestedLocation
        : 'global';
    return FirebaseAiBackendConfig(backend: backend, vertexLocation: location);
  }

  firebase_ai.FirebaseAI client() => switch (backend) {
    FirebaseAiBackend.vertexAi => firebase_ai.FirebaseAI.vertexAI(
      location: vertexLocation,
    ),
    FirebaseAiBackend.googleAi => firebase_ai.FirebaseAI.googleAI(),
  };
}
