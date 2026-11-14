import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../finance_engine/domain/entities/account_balance_state.dart';
import '../../../finance_engine/domain/exceptions/finance_exception.dart';
import '../../../finance_engine/domain/repositories/account_balance_repository.dart';

class DriftAccountBalanceRepository implements AccountBalanceRepository {
  const DriftAccountBalanceRepository(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<AccountBalanceState?> getById(String accountId) async {
    final account =
        await (_database.select(_database.accounts)..where(
              (row) =>
                  row.ownerScopeId.equals(_scope) & row.id.equals(accountId),
            ))
            .getSingleOrNull();

    if (account == null) {
      return null;
    }

    return AccountBalanceState(
      accountId: account.id,
      currencyCode: account.currencyCode,
      balance: Decimal.parse(account.balance),
      updatedAt: account.updatedAt,
    );
  }

  @override
  Future<void> save(AccountBalanceState account) async {
    await _session.runGuardedWrite(() async {
      final updatedRows = await _database.updateAccountBalanceProjection(
        ownerScopeId: _scope,
        accountId: account.accountId,
        balance: account.balance.toString(),
        updatedAt: account.updatedAt ?? DateTime.now().toUtc(),
      );

      if (updatedRows == 0) {
        throw FinanceException.accountNotFound(account.accountId);
      }
    });
  }
}
