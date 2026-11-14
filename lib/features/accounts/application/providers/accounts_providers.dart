import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/sync_providers.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../services/transactions_opening_balance_ledger.dart';
import '../../data/datasources/local/accounts_local_data_source.dart';
import '../../data/repositories/accounts_repository_impl.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../../domain/repositories/opening_balance_ledger.dart';
import '../../domain/usecases/create_account.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/get_account_by_id.dart';
import '../../domain/usecases/get_accounts.dart';
import '../../domain/usecases/update_account.dart';

final accountsLocalDataSourceProvider = Provider<AccountsLocalDataSource>(
  (ref) => DriftAccountsLocalDataSource(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'accountsLocalDataSourceProvider',
);

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepositoryImpl(
    localDataSource: ref.watch(accountsLocalDataSourceProvider),
    openingBalanceLedger: ref.watch(_accountOpeningBalanceLedgerProvider),
    logger: ref.watch(appLoggerProvider),
    syncQueue: ref.watch(syncMutationQueueProvider),
  );
}, name: 'accountsRepositoryProvider');

final _accountOpeningBalanceLedgerProvider = Provider<OpeningBalanceLedger>(
  (ref) => TransactionsOpeningBalanceLedger(
    createTransaction: ref.watch(createTransactionUseCaseProvider),
    getDefaultCategories: ref.watch(getDefaultCategoriesUseCaseProvider),
  ),
  name: 'accountOpeningBalanceLedgerProvider',
);

final createAccountUseCaseProvider = Provider<CreateAccount>(
  (ref) => CreateAccount(ref.watch(accountsRepositoryProvider)),
  name: 'createAccountUseCaseProvider',
);

final updateAccountUseCaseProvider = Provider<UpdateAccount>(
  (ref) => UpdateAccount(ref.watch(accountsRepositoryProvider)),
  name: 'updateAccountUseCaseProvider',
);

final deleteAccountUseCaseProvider = Provider<DeleteAccount>(
  (ref) => DeleteAccount(ref.watch(accountsRepositoryProvider)),
  name: 'deleteAccountUseCaseProvider',
);

final getAccountsUseCaseProvider = Provider<GetAccounts>(
  (ref) => GetAccounts(ref.watch(accountsRepositoryProvider)),
  name: 'getAccountsUseCaseProvider',
);

final getAccountByIdUseCaseProvider = Provider<GetAccountById>(
  (ref) => GetAccountById(ref.watch(accountsRepositoryProvider)),
  name: 'getAccountByIdUseCaseProvider',
);

final accountsProvider = FutureProvider<AppResult<List<Account>>>(
  (ref) => ref.watch(getAccountsUseCaseProvider)(),
  name: 'accountsProvider',
);

final accountByIdProvider = FutureProvider.family<AppResult<Account?>, String>((
  ref,
  id,
) {
  return ref.watch(getAccountByIdUseCaseProvider)(id);
}, name: 'accountByIdProvider');
