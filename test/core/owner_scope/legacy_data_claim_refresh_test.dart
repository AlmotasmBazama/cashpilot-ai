import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/database/app_database_provider.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_health_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';
import 'package:cashpilot_ai/core/sync/application/sync_mutation_queue.dart';
import 'package:cashpilot_ai/core/sync/application/sync_providers.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_types.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/transactions/application/providers/transactions_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'verified claim refreshes cached account category and transaction reads',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      await _seedLegacyFinancialGraph(database);

      const user = AuthUser(
        uid: 'legacy-refresh-owner',
        emailVerified: true,
        isAnonymous: false,
        authSessionGeneration: 7,
      );
      final ownerScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        user.uid,
      );
      final operationFence = BackupOperationFence();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          backupOperationFenceProvider.overrideWithValue(operationFence),
          currentAuthUserProvider.overrideWithValue(user),
          confirmedOwnerScopeProvider.overrideWithValue(ownerScope),
          scopedAppDatabaseSessionProvider.overrideWith((ref) {
            final session = ScopedAppDatabaseSession(
              database: database,
              scope: ownerScope,
              operationFence: operationFence,
            );
            ref.onDispose(session.invalidate);
            return session;
          }),
          ownerScopeHealthProvider.overrideWith((ref) {
            final session = ref.watch(scopedAppDatabaseSessionProvider);
            return OwnerScopeHealthService(database).evaluate(
              snapshot: OwnerScopeSnapshot(
                status: OwnerScopeStatus.safe,
                scope: ownerScope,
                authSessionGeneration: user.authSessionGeneration,
              ),
              session: session,
            );
          }),
          syncMutationQueueProvider.overrideWithValue(
            const _NoopSyncMutationQueue(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sessionBefore = container.read(scopedAppDatabaseSessionProvider);
      expect(sessionBefore, isNotNull);
      await container.read(legacyDataClaimControllerProvider.future);
      expect(_success(await container.read(accountsProvider.future)), isEmpty);
      expect(
        _success(
          await container.read(categoriesProvider.future),
        ).map((category) => category.id),
        isNot(contains('legacy-category')),
      );
      expect(
        _success(await container.read(transactionsProvider.future)),
        isEmpty,
      );
      expect(
        (await container.read(ownerScopeHealthProvider.future)).status,
        OwnerScopeStatus.legacyDataUnclaimed,
      );

      final claimed = await container
          .read(legacyDataClaimControllerProvider.notifier)
          .claim(protectedConfirmationAccepted: true);

      expect(claimed, isTrue);
      final sessionAfter = container.read(scopedAppDatabaseSessionProvider);
      expect(sessionAfter, isNotNull);
      expect(identical(sessionBefore, sessionAfter), isFalse);
      expect(
        _success(
          await container.read(accountsProvider.future),
        ).map((account) => account.id),
        <String>['legacy-account'],
      );
      expect(
        _success(
          await container.read(categoriesProvider.future),
        ).map((category) => category.id),
        contains('legacy-category'),
      );
      expect(
        _success(
          await container.read(transactionsProvider.future),
        ).map((transaction) => transaction.id),
        <String>['legacy-transaction'],
      );
      expect(
        (await container.read(ownerScopeHealthProvider.future)).status,
        OwnerScopeStatus.safe,
      );
    },
  );
}

List<T> _success<T>(AppResult<List<T>> result) => switch (result) {
  AppSuccess<List<T>>(:final data) => data,
  AppFailure<List<T>>() => fail('Expected a successful owner-scoped read.'),
};

Future<void> _seedLegacyFinancialGraph(AppDatabase database) async {
  await database.customStatement('''
    INSERT INTO accounts (
      id, name, type, currency_code, balance, icon, color,
      created_at, updated_at
    ) VALUES ('legacy-account', 'Legacy cash', 'cash', 'LYD', '10',
      'wallet', 1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO categories (
      id, name, type, icon, color, is_default, sort_order,
      created_at, updated_at
    ) VALUES ('legacy-category', 'Legacy income', 'income', 'income', 1, 0,
      1, 1, 1)
  ''');
  await database.customStatement('''
    INSERT INTO transactions (
      id, account_id, category_id, amount, currency_code, type,
      payment_method, source, status, transaction_date, created_at, updated_at
    ) VALUES (
      'legacy-transaction', 'legacy-account', 'legacy-category', '10', 'LYD',
      'income', 'cash', 'manual', 'posted', 1, 1, 1
    )
  ''');
}

final class _NoopSyncMutationQueue implements SyncMutationQueue {
  const _NoopSyncMutationQueue();

  @override
  Future<void> enqueueDelete(
    SyncEntityType entityType,
    String entityId,
  ) async {}

  @override
  Future<void> enqueueUpsert(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {}
}
