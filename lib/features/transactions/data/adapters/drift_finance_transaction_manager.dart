import '../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../finance_engine/domain/repositories/finance_transaction_manager.dart';

class DriftFinanceTransactionManager implements FinanceTransactionManager {
  const DriftFinanceTransactionManager(this._session);

  final ScopedAppDatabaseSession _session;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) {
    return _session.runGuardedWrite(
      () => _session.database.transaction(operation),
    );
  }
}
