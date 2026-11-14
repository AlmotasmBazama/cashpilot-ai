import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('deletion proof has no plaintext local-storage fallback', () {
    final source = File(
      'lib/features/data_deletion/data/datasources/'
      'account_deletion_session_proof_store.dart',
    ).readAsStringSync();

    expect(source, contains('flutter_secure_storage'));
    expect(source, isNot(contains('package:hive/')));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, contains('resetOnError: false'));
    expect(source, contains('migrateOnAlgorithmChange: false'));
    expect(source, contains('first_unlock_this_device'));
  });

  test('secure-storage platform requirements are committed', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(pubspec, contains('flutter_secure_storage: ^10.3.1'));
    expect(
      _effectiveAndroidMinSdk(gradle),
      greaterThanOrEqualTo(23),
      reason: 'flutter_secure_storage 10.x requires Android API 23 or newer.',
    );
    expect(manifest, contains('android:allowBackup="false"'));

    for (final path in <String>[
      'ios/Runner/RunnerDebug.entitlements',
      'ios/Runner/RunnerProfile.entitlements',
      'ios/Runner/Runner.entitlements',
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('keychain-access-groups'),
        reason: '$path must enable Keychain access for secure proof recovery.',
      );
    }
    for (final path in <String>[
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('com.apple.security.network.client'),
        reason: '$path must permit the authenticated deletion gateway call.',
      );
    }

    final iosProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      iosProject,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/RunnerDebug.entitlements;'),
    );
    expect(
      iosProject,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/RunnerProfile.entitlements;'),
    );
    expect(
      iosProject,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
  });

  test('Auth-null recovery is wired before routed feature providers', () {
    final app = File('lib/app/app.dart').readAsStringSync();
    final providers = File(
      'lib/features/data_deletion/application/data_deletion_providers.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/features/data_deletion/application/'
      'account_deletion_startup_recovery_coordinator.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/features/data_deletion/data/datasources/'
      'account_deletion_startup_recovery_gateway.dart',
    ).readAsStringSync();

    expect(
      app.indexOf('ref.watch(accountDeletionStartupRecoveryProvider)'),
      lessThan(app.indexOf('ref.watch(appRouterProvider)')),
    );
    expect(app, contains('if (recovery.isLoading)'));
    expect(app, contains('report.retained == 0 && report.rejected == 0'));
    expect(app, contains('return const _RoutedCashPilotApp()'));
    expect(app, contains('_retryAccountDeletionStartupRecovery(ref)'));
    expect(
      providers,
      contains('accountDeletionStartupRecoveryCoordinatorProvider'),
    );
    expect(providers, contains('ownerDeletionQuarantineStoreProvider'));
    expect(providers, contains('backupOperationFenceProvider'));
    expect(coordinator, isNot(contains('currentUser')));
    expect(gateway, isNot(contains("'Authorization'")));
  });
}

int _effectiveAndroidMinSdk(String gradle) {
  final explicit = RegExp(
    r'^\s*minSdk\s*=\s*(\d+)\s*$',
    multiLine: true,
  ).firstMatch(gradle);
  if (explicit != null) {
    return int.parse(explicit.group(1)!);
  }

  expect(
    gradle,
    contains('minSdk = flutter.minSdkVersion'),
    reason: 'The Android minSdk assignment must have a resolvable source.',
  );
  final extension = _flutterExtensionFile();
  final match = RegExp(
    r'\bval\s+minSdkVersion\s*:\s*Int\s*=\s*(\d+)',
  ).firstMatch(extension.readAsStringSync());
  expect(
    match,
    isNotNull,
    reason: 'Flutter minSdkVersion must be readable from FlutterExtension.kt.',
  );
  return int.parse(match!.group(1)!);
}

File _flutterExtensionFile() {
  final candidates = <String>[];
  final localProperties = File('android/local.properties');
  if (localProperties.existsSync()) {
    final match = RegExp(
      r'^\s*flutter\.sdk\s*=\s*(.+?)\s*$',
      multiLine: true,
    ).firstMatch(localProperties.readAsStringSync());
    if (match != null) {
      candidates.add(
        match
            .group(1)!
            .replaceAll(r'\\', String.fromCharCode(92))
            .replaceAll(r'\:', ':'),
      );
    }
  }
  final environmentRoot = Platform.environment['FLUTTER_ROOT'];
  if (environmentRoot != null && environmentRoot.trim().isNotEmpty) {
    candidates.add(environmentRoot.trim());
  }

  var executableRoot = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 4; i += 1) {
    executableRoot = executableRoot.parent;
  }
  candidates.add(executableRoot.path);

  for (final root in candidates.toSet()) {
    final candidate = File(
      path.join(
        root,
        'packages',
        'flutter_tools',
        'gradle',
        'src',
        'main',
        'kotlin',
        'FlutterExtension.kt',
      ),
    );
    if (candidate.existsSync()) {
      return candidate;
    }
  }
  throw StateError('Unable to resolve the Flutter SDK source directory.');
}
