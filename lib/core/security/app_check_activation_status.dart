/// Phases for an App Check activation attempt.
///
/// The Firebase-prefixed declaration name preserves the observable identity of
/// the existing public enum. Domain-facing code uses [AppCheckActivationPhase]
/// so it does not depend on the Firebase adapter.
enum FirebaseAppCheckActivationPhase {
  idle,
  initializing,
  available,
  unavailable,
}

/// Domain-facing name for the framework-independent activation phase.
typedef AppCheckActivationPhase = FirebaseAppCheckActivationPhase;

/// Reasons why App Check activation is unavailable.
///
/// The Firebase-prefixed declaration name is retained for public compatibility;
/// domain-facing code uses [AppCheckUnavailableReason].
enum FirebaseAppCheckUnavailableReason {
  releaseDebugTokenForbidden,
  webSiteKeyMissing,
  unsupportedPlatform,
  timedOut,
  activationFailed,
}

/// Domain-facing name for the framework-independent unavailable reason.
typedef AppCheckUnavailableReason = FirebaseAppCheckUnavailableReason;
