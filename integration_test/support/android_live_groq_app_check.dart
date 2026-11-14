// ignore_for_file: avoid_print

import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';

/// Gives the host runner a bounded window to register a newly generated
/// Android debug token. Token values and provider exceptions never leave this
/// function.
Future<void> awaitRegisteredAndroidAppCheckToken(
  FirebaseAppCheck appCheck, {
  int maxAttempts = 24,
  Duration attemptTimeout = const Duration(seconds: 3),
  Duration retryDelay = const Duration(milliseconds: 500),
}) async {
  if (maxAttempts <= 0) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts');
  }
  print(
    'ANDROID_GROQ_LIVE_APPCHECK_BOOTSTRAP '
    'activationAvailable=true tokenPending=true',
  );

  for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      final token = await appCheck.getToken(true).timeout(attemptTimeout);
      if (token != null && token.trim().isNotEmpty) {
        print(
          'ANDROID_GROQ_LIVE_APPCHECK_READY tokenIssued=true '
          'attempts=$attempt',
        );
        return;
      }
    } on Object {
      // A fresh debug token is expected to fail until the host registers it.
    }
    if (attempt < maxAttempts) {
      await Future<void>.delayed(retryDelay);
    }
  }

  throw StateError(
    'Android App Check registration did not complete within the bounded retry.',
  );
}
