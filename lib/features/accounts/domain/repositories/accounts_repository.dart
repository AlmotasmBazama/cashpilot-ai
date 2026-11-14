import '../../../../core/error/result.dart';
import '../entities/account.dart';

abstract interface class AccountsRepository {
  Future<AppResult<Account>> createAccount(Account account);

  Future<AppResult<Account>> updateAccount(Account account);

  Future<AppResult<void>> deleteAccount(String id);

  Future<AppResult<List<Account>>> getAccounts({bool includeArchived = false});

  Future<AppResult<Account?>> getAccountById(String id);
}
