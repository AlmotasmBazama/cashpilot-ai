import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/cash_pilot_app_version.dart';
import '../core/logging/app_logger.dart';
import '../core/storage/hive_box_names.dart';
import '../core/firebase/firebase_app_check_activation.dart';
import '../core/firebase/firebase_initializer.dart';
import 'app.dart';
import 'bootstrap_failure_app.dart';
import 'di/app_provider_observer.dart';
import 'startup_initializer.dart';

final _startupInitializer = StartupInitializer(
  initializeLocalStorage: _initializeLocalStorage,
  firebaseInitializer: const DefaultFirebaseInitializer(),
  appCheckActivationController: defaultFirebaseAppCheckActivationController,
);

Future<void> bootstrap() async {
  final logger = AppLogger.instance;

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        logger.error(
          'Flutter framework error',
          details.exception,
          details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        logger.fatal('Uncaught platform error', error, stackTrace);
        return true;
      };

      try {
        await _startupInitializer.initialize();
      } on Object catch (error, stackTrace) {
        logger.fatal('Application initialization failed.', error, stackTrace);
        runApp(BootstrapFailureApp(onRetry: bootstrap));
        return;
      }

      if (!kReleaseMode) {
        logger.debug(
          'AI runtime platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} '
          'applicationId=${defaultTargetPlatform == TargetPlatform.android ? 'com.example.cashpilot_ai' : 'not_android'} '
          'version=${CashPilotAppVersion.version} '
          'build=${CashPilotAppVersion.buildNumber} '
          'firebaseInitialized=${Firebase.apps.isNotEmpty}',
        );
      }

      unawaited(
        _startupInitializer.activateAppCheck().then((state) {
          if (!kReleaseMode) {
            logger.debug('AI runtime appCheck=${state.safeCode}');
          }
          if (!state.isAvailable) {
            logger.warning(
              'Firebase App Check is unavailable (${state.safeCode}).',
            );
          }
        }),
      );

      runApp(
        ProviderScope(
          observers: [AppProviderObserver(logger)],
          child: const CashPilotApp(),
        ),
      );
    },
    (error, stackTrace) {
      logger.fatal('Uncaught zone error', error, stackTrace);
    },
  );
}

Future<void> _initializeLocalStorage() async {
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(HiveBoxNames.settings);
}
