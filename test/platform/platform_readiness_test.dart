import 'dart:convert';
import 'dart:io';

import 'package:cashpilot_ai/firebase_options.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FlutterFire Web mapping preserves the Android registration', () {
    final web = DefaultFirebaseOptions.web;
    expect(web.apiKey, isNotEmpty);
    expect(web.appId, startsWith('1:102802326815:web:'));
    expect(web.messagingSenderId, '102802326815');
    expect(web.projectId, 'cashpilot-ai-a6b49');
    expect(web.authDomain, 'cashpilot-ai-a6b49.firebaseapp.com');

    final firebaseJson =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final flutter = firebaseJson['flutter'] as Map<String, dynamic>;
    final platforms = flutter['platforms'] as Map<String, dynamic>;
    final android = platforms['android'] as Map<String, dynamic>;
    final androidBuilds =
        android['buildConfigurations'] as Map<String, dynamic>;
    final androidDefault = androidBuilds['.'] as Map<String, dynamic>;
    final dart = platforms['dart'] as Map<String, dynamic>;
    final generated = dart['lib/firebase_options.dart'] as Map<String, dynamic>;
    final configurations = generated['configurations'] as Map<String, dynamic>;

    expect(
      androidDefault['appId'],
      '1:102802326815:android:6c62d29c46586279841c2a',
    );
    expect(androidDefault['fileOutput'], 'android/app/google-services.json');
    expect(configurations['android'], androidDefault['appId']);
    expect(configurations['web'], web.appId);
  });

  test('Drift Web runtime assets match the locked package releases', () {
    final databaseSource = File(
      'lib/core/database/app_database.dart',
    ).readAsStringSync();
    expect(databaseSource, contains("Uri.parse('sqlite3.wasm')"));
    expect(databaseSource, contains("Uri.parse('drift_worker.js')"));

    _expectSha256(
      'web/sqlite3.wasm',
      'cfab48c6bbb718552ec19bc4f1365e19185311b72e4739cc19ef7333758304d3',
    );
    _expectSha256(
      'web/drift_worker.js',
      'b8b9f88cdfa0582eedacf3b55f6133b7d9bea7c8e74d4dc019a380da9976a7a8',
    );
  });
}

void _expectSha256(String filePath, String expected) {
  final file = File(filePath);
  expect(
    file.existsSync(),
    isTrue,
    reason: '$filePath must be shipped on Web.',
  );
  expect(sha256.convert(file.readAsBytesSync()).toString(), expected);
}
