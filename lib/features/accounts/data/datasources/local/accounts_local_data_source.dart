import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../domain/failures/account_failure_codes.dart';
import '../../dtos/account_dto.dart';
import '../../mappers/account_mapper.dart';

abstract interface class AccountsLocalDataSource {
  Future<T> runInTransaction<T>(Future<T> Function() operation);

  Future<AccountDto> createAccount(AccountDto account);

  Future<AccountDto> updateAccount(AccountDto account);

  Future<void> deleteAccount(String id);

  Future<List<AccountDto>> getAccounts({bool includeArchived = false});

  Future<AccountDto?> getAccountById(String id);
}

class DriftAccountsLocalDataSource implements AccountsLocalDataSource {
  const DriftAccountsLocalDataSource(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<AccountDto> createAccount(AccountDto account) async {
    return _session.runGuardedWrite(() async {
      if (Decimal.parse(account.balance) != Decimal.zero) {
        throw const AppException.validation(
          message:
              'An account must be inserted at zero before its opening ledger entry.',
          code: AccountFailureCodes.openingBalanceLedgerRequired,
        );
      }
      await _database
          .into(_database.accounts)
          .insert(account.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      return account;
    });
  }

  @override
  Future<void> deleteAccount(String id) async {
    await runInTransaction(() async {
      final existing = await _requiredOwnedAccount(id);
      await _assertClosable(existing);
      final deletedRows =
          await (_database.delete(_database.accounts)..where(
                (account) =>
                    account.ownerScopeId.equals(_scope) & account.id.equals(id),
              ))
              .go();

      if (deletedRows != 1) {
        throw const AppException.cache(
          message: 'Account not found for deletion.',
          code: AccountFailureCodes.notFound,
        );
      }
    });
  }

  @override
  Future<AccountDto?> getAccountById(String id) async {
    final row =
        await (_database.select(_database.accounts)..where(
              (account) =>
                  account.ownerScopeId.equals(_scope) & account.id.equals(id),
            ))
            .getSingleOrNull();

    return row?.toDto();
  }

  @override
  Future<List<AccountDto>> getAccounts({bool includeArchived = false}) async {
    final query = _database.select(_database.accounts);
    query.where((account) => account.ownerScopeId.equals(_scope));

    if (!includeArchived) {
      query.where((account) => account.isArchived.equals(false));
    }

    query.orderBy([
      (account) =>
          OrderingTerm(expression: account.createdAt, mode: OrderingMode.desc),
      (account) => OrderingTerm(expression: account.name),
    ]);

    final rows = await query.get();
    return rows.map((row) => row.toDto()).toList(growable: false);
  }

  @override
  Future<AccountDto> updateAccount(AccountDto account) async {
    return runInTransaction(() async {
      final existing = await _requiredOwnedAccount(account.id);
      if (existing.balance != account.balance ||
          existing.currencyCode != account.currencyCode ||
          existing.type != account.type ||
          existing.createdAt.toUtc() != account.createdAt.toUtc()) {
        throw const AppException.validation(
          message:
              'Account balance, currency, type, and creation time are immutable.',
          code: AccountFailureCodes.protectedFieldMutation,
        );
      }
      if (!existing.isArchived && account.isArchived) {
        await _assertClosable(existing);
      }

      final updatedRows =
          await (_database.update(_database.accounts)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.equals(account.id),
              ))
              .write(
                AccountsCompanion(
                  name: Value(account.name),
                  icon: Value(account.icon),
                  color: Value(account.color),
                  paymentMethodIds: Value(jsonEncode(account.paymentMethodIds)),
                  isArchived: Value(account.isArchived),
                  updatedAt: Value(account.updatedAt),
                ),
              );

      if (updatedRows != 1) {
        throw const AppException.cache(
          message: 'Account not found for update.',
          code: AccountFailureCodes.notFound,
        );
      }

      return (await _requiredOwnedAccount(account.id)).toDto();
    });
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) {
    return _session.runGuardedWrite(() => _database.transaction(operation));
  }

  Future<AccountRow> _requiredOwnedAccount(String id) async {
    final row =
        await (_database.select(_database.accounts)..where(
              (account) =>
                  account.ownerScopeId.equals(_scope) & account.id.equals(id),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const AppException.cache(
        message: 'Account not found.',
        code: AccountFailureCodes.notFound,
      );
    }
    return row;
  }

  Future<void> _assertClosable(AccountRow account) async {
    if (Decimal.parse(account.balance) != Decimal.zero) {
      throw const AppException.validation(
        message: 'Only an account with a zero balance can be closed.',
        code: AccountFailureCodes.nonZeroBalance,
      );
    }

    final transaction =
        await (_database.select(_database.transactions)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.accountId.equals(account.id),
              )
              ..limit(1))
            .getSingleOrNull();
    final payee =
        await (_database.select(_database.payees)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.defaultAccountId.equals(account.id),
              )
              ..limit(1))
            .getSingleOrNull();
    final goal =
        await (_database.select(_database.goals)
              ..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) &
                    row.linkedAccountId.equals(account.id),
              )
              ..limit(1))
            .getSingleOrNull();
    if (transaction != null || payee != null || goal != null) {
      throw const AppException.validation(
        message:
            'Remove or reassign all account dependencies before closing it.',
        code: AccountFailureCodes.hasDependencies,
      );
    }
  }
}
