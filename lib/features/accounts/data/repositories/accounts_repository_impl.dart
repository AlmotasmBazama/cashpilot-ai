import 'package:decimal/decimal.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../domain/entities/account.dart';
import '../../domain/failures/account_failure_codes.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../../domain/repositories/opening_balance_ledger.dart';
import '../datasources/local/accounts_local_data_source.dart';
import '../mappers/account_mapper.dart';

class AccountsRepositoryImpl implements AccountsRepository {
  const AccountsRepositoryImpl({
    required AccountsLocalDataSource localDataSource,
    required OpeningBalanceLedger openingBalanceLedger,
    required AppLogger logger,
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _openingBalanceLedger = openingBalanceLedger,
       _logger = logger,
       _syncQueue = syncQueue;

  final AccountsLocalDataSource _localDataSource;
  final OpeningBalanceLedger _openingBalanceLedger;
  final AppLogger _logger;
  final SyncMutationQueue? _syncQueue;

  @override
  Future<AppResult<Account>> createAccount(Account account) async {
    try {
      if (account.balance < Decimal.zero) {
        throw const AppException.validation(
          message: 'A negative opening balance is not supported.',
          code: AccountFailureCodes.negativeOpeningBalance,
        );
      }
      final created = await _localDataSource.runInTransaction(() async {
        final zeroAccount = account.copyWith(balance: Decimal.zero);
        await _localDataSource.createAccount(zeroAccount.toDto());
        if (account.balance > Decimal.zero) {
          await _openingBalanceLedger.postOpeningBalance(
            accountId: account.id,
            amount: account.balance,
            currencyCode: account.currencyCode,
            occurredAt: account.createdAt,
          );
        }
        final stored = await _localDataSource.getAccountById(account.id);
        if (stored == null) {
          throw const AppException.cache(
            message: 'Created account could not be loaded.',
            code: AccountFailureCodes.notFound,
          );
        }
        return stored;
      });
      final result = created.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to create account.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<void>> deleteAccount(String id) async {
    try {
      await _localDataSource.deleteAccount(id);
      await enqueueSyncDeleteBestEffort(
        queue: _syncQueue,
        entityType: SyncEntityType.account,
        entityId: id,
        logger: _logger,
      );
      return const AppResult.success(null);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to delete account.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Account?>> getAccountById(String id) async {
    try {
      final account = await _localDataSource.getAccountById(id);
      return AppResult.success(account?.toDomain());
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load account.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Account>>> getAccounts({
    bool includeArchived = false,
  }) async {
    try {
      final accounts = await _localDataSource.getAccounts(
        includeArchived: includeArchived,
      );

      return AppResult.success(
        accounts.map((account) => account.toDomain()).toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load accounts.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Account>> updateAccount(Account account) async {
    try {
      final updated = await _localDataSource.updateAccount(account.toDto());
      final result = updated.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to update account.', error, stackTrace);
    }
  }

  AppResult<T> _failure<T>(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(message, error, stackTrace);
    if (error is AppException) {
      return AppResult.failure(
        Failure(message: error.message, code: error.code),
      );
    }
    return AppResult.failure(Failure(message: message));
  }

  Future<void> _queueUpsert(Account account) {
    return enqueueSyncUpsertBestEffort(
      queue: _syncQueue,
      entityType: SyncEntityType.account,
      entityId: account.id,
      payload: account.toJson(),
      logger: _logger,
    );
  }
}
