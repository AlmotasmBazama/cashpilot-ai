import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

export 'firebase_app_check_activation.dart' show firebaseAppCheckDebugToken;

abstract interface class FirebaseInitializer {
  /// Initializes Firebase Core only. App Check activation is an independent,
  /// observable capability and must not be awaited by required app startup.
  Future<void> initialize();
}

final class DefaultFirebaseInitializer implements FirebaseInitializer {
  const DefaultFirebaseInitializer();

  @override
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }
}
