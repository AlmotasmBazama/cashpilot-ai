// ignore_for_file: avoid_print

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'App Check debug provider uses configured token',
    (tester) async {
      if (firebaseAppCheckDebugToken.isEmpty) {
        fail(
          'Run this test with a registered App Check debug token using '
          '--dart-define or --dart-define-from-file.',
        );
      }

      print('APP_CHECK_DIAG configuredDebugToken=true');
      try {
        await const DefaultFirebaseInitializer().initialize();
      } on Object {
        fail(
          'App Check initialization failed. Verify the platform configuration, '
          'network access, provider selection, and registered debug token.',
        );
      }
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );
      print('APP_CHECK_DIAG initialized=true');

      String? token;
      try {
        token = await FirebaseAppCheck.instance.getToken(true);
      } on Object {
        fail(
          'App Check could not issue a token. Verify that the local debug token '
          'is registered for this Firebase app.',
        );
      }

      final tokenIssued = token?.trim().isNotEmpty == true;
      print('APP_CHECK_DIAG tokenIssued=$tokenIssued');
      expect(
        tokenIssued,
        isTrue,
        reason: 'App Check returned no usable token.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
