import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/widgets.dart';

/// Debug-only Android entrypoint used to obtain the SDK-managed App Check
/// device token without passing its secret through Flutter or Gradle flags.
///
/// The native debug provider owns and logs the token. This harness never reads,
/// prints, persists, or transmits the token itself. Registration and revocation
/// are performed externally by the acceptance runner.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const DefaultFirebaseInitializer().initialize();
  await defaultFirebaseAppCheckActivationController.activate();
  try {
    await FirebaseAppCheck.instance.getToken(true);
  } on Object {
    // An unregistered debug token is expected during the discovery launch.
  }
  runApp(const SizedBox.shrink());
}
