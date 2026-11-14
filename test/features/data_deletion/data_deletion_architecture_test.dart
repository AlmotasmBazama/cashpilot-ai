import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account deletion has no legacy AuthController bypass', () {
    const legacyFiles = <String>[
      'lib/features/auth/application/providers/auth_providers.dart',
      'lib/features/auth/domain/repositories/auth_repository.dart',
      'lib/features/auth/data/repositories/auth_repository_impl.dart',
      'lib/features/auth/data/datasources/firebase_auth_data_source.dart',
    ];

    for (final path in legacyFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('deleteAccount(')),
        reason: '$path must delegate destructive deletion to data_deletion.',
      );
    }
    expect(
      File(
        'lib/features/auth/domain/usecases/delete_auth_account.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('cloud deletion does not rely on a fixed child allowlist', () {
    final source = File(
      'lib/features/data_deletion/data/datasources/cloud_user_data_deletion_data_source.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('backupCollections')));
    expect(source, contains('verifiedEmpty'));
    expect(source, contains('/v1/account-deletion/recursive'));
  });
}
