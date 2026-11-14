import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/core/sync/application/backup_operation_fence.dart';

ScopedAppDatabaseSession scopedTestSession(
  AppDatabase database, {
  String syntheticFirebaseUid = 'cashpilot-test-owner',
  BackupOperationFence? operationFence,
}) {
  return ScopedAppDatabaseSession(
    database: database,
    scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(
      syntheticFirebaseUid,
      confirmedAt: DateTime.utc(2026, 1, 1),
    ),
    operationFence: operationFence,
  );
}
