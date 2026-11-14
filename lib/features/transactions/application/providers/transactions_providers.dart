import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/sync_providers.dart';
import '../../../finance_engine/domain/repositories/account_balance_repository.dart';
import '../../../finance_engine/domain/repositories/exchange_rate_provider.dart';
import '../../../finance_engine/domain/repositories/finance_transaction_manager.dart';
import '../../../finance_engine/domain/services/balance_calculator.dart';
import '../../../finance_engine/domain/services/finance_validation_service.dart';
import '../../../finance_engine/domain/services/transaction_processor.dart';
import '../../../finance_engine/domain/services/transfer_processor.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../../payees/application/providers/payees_providers.dart';
import '../services/create_transaction_with_payee_usage.dart';
import '../../data/adapters/drift_account_balance_repository.dart';
import '../../data/adapters/drift_finance_transaction_manager.dart';
import '../../data/datasources/local/transactions_local_data_source.dart';
import '../../data/mappers/transaction_mapper.dart';
import '../../data/repositories/transactions_repository_impl.dart';
import '../../data/transaction_history_read_model.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_history_page.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/repositories/transactions_repository.dart';
import '../../domain/usecases/create_transaction.dart';
import '../../domain/usecases/create_transfer.dart';
import '../../domain/usecases/delete_transaction.dart';
import '../../domain/usecases/get_transaction.dart';
import '../../domain/usecases/get_transactions.dart';
import '../../domain/usecases/search_transactions.dart';
import '../../domain/usecases/update_transaction.dart';
import '../../domain/usecases/update_transaction_status.dart';
import '../../transaction_row_domain_mapper.dart';

final transactionRowDomainMapperProvider = Provider<TransactionRowDomainMapper>(
  (_) => const DriftTransactionRowDomainMapper(),
  name: 'transactionRowDomainMapperProvider',
);

final transactionsLocalDataSourceProvider =
    Provider<TransactionsLocalDataSource>(
      (ref) => DriftTransactionsLocalDataSource(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
      ),
      name: 'transactionsLocalDataSourceProvider',
    );

final transactionsFinanceTransactionManagerProvider =
    Provider<FinanceTransactionManager>(
      (ref) => DriftFinanceTransactionManager(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
      ),
      name: 'transactionsFinanceTransactionManagerProvider',
    );

final transactionsAccountBalanceRepositoryProvider =
    Provider<AccountBalanceRepository>(
      (ref) => DriftAccountBalanceRepository(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
      ),
      name: 'transactionsAccountBalanceRepositoryProvider',
    );

final transactionProcessorProvider = Provider<TransactionProcessor>(
  (ref) => TransactionProcessor(
    accountBalanceRepository: ref.watch(
      transactionsAccountBalanceRepositoryProvider,
    ),
    transactionManager: ref.watch(
      transactionsFinanceTransactionManagerProvider,
    ),
    balanceCalculator: const BalanceCalculator(),
    validationService: const FinanceValidationService(),
  ),
  name: 'transactionProcessorProvider',
);

final transferExchangeRateProvider = Provider<ExchangeRateProvider>(
  (ref) => ref.watch(storedExchangeRateProvider),
  name: 'transferExchangeRateProvider',
);

final transferProcessorProvider = Provider<TransferProcessor>(
  (ref) => TransferProcessor(
    accountBalanceRepository: ref.watch(
      transactionsAccountBalanceRepositoryProvider,
    ),
    transactionManager: ref.watch(
      transactionsFinanceTransactionManagerProvider,
    ),
    balanceCalculator: const BalanceCalculator(),
    validationService: const FinanceValidationService(),
    exchangeRateProvider: ref.watch(transferExchangeRateProvider),
  ),
  name: 'transferProcessorProvider',
);

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepositoryImpl(
    localDataSource: ref.watch(transactionsLocalDataSourceProvider),
    transactionProcessor: ref.watch(transactionProcessorProvider),
    transferProcessor: ref.watch(transferProcessorProvider),
    logger: ref.watch(appLoggerProvider),
    syncQueue: ref.watch(syncMutationQueueProvider),
  );
}, name: 'transactionsRepositoryProvider');

final createTransactionUseCaseProvider = Provider<CreateTransaction>(
  (ref) => CreateTransaction(ref.watch(transactionsRepositoryProvider)),
  name: 'createTransactionUseCaseProvider',
);

final createTransactionWithPayeeUsageProvider =
    Provider<CreateTransactionWithPayeeUsage>(
      (ref) => CreateTransactionWithPayeeUsage(
        createTransaction: ref.watch(createTransactionUseCaseProvider),
        touchPayeeLastUsed: ref.watch(touchPayeeLastUsedUseCaseProvider),
      ),
      name: 'createTransactionWithPayeeUsageProvider',
    );

final createTransferUseCaseProvider = Provider<CreateTransfer>(
  (ref) => CreateTransfer(ref.watch(transactionsRepositoryProvider)),
  name: 'createTransferUseCaseProvider',
);

final updateTransactionUseCaseProvider = Provider<UpdateTransaction>(
  (ref) => UpdateTransaction(ref.watch(transactionsRepositoryProvider)),
  name: 'updateTransactionUseCaseProvider',
);

final updateTransactionStatusUseCaseProvider =
    Provider<UpdateTransactionStatus>(
      (ref) =>
          UpdateTransactionStatus(ref.watch(transactionsRepositoryProvider)),
      name: 'updateTransactionStatusUseCaseProvider',
    );

final deleteTransactionUseCaseProvider = Provider<DeleteTransaction>(
  (ref) => DeleteTransaction(ref.watch(transactionsRepositoryProvider)),
  name: 'deleteTransactionUseCaseProvider',
);

final getTransactionUseCaseProvider = Provider<GetTransaction>(
  (ref) => GetTransaction(ref.watch(transactionsRepositoryProvider)),
  name: 'getTransactionUseCaseProvider',
);

final getTransactionsUseCaseProvider = Provider<GetTransactions>(
  (ref) => GetTransactions(ref.watch(transactionsRepositoryProvider)),
  name: 'getTransactionsUseCaseProvider',
);

final searchTransactionsUseCaseProvider = Provider<SearchTransactions>(
  (ref) => SearchTransactions(ref.watch(transactionsRepositoryProvider)),
  name: 'searchTransactionsUseCaseProvider',
);

final transactionsProvider = FutureProvider<AppResult<List<Transaction>>>(
  (ref) => ref.watch(getTransactionsUseCaseProvider)(),
  name: 'transactionsProvider',
);

final transactionHistoryReadModelProvider =
    Provider<TransactionHistoryReadModel>(
      (ref) => TransactionHistoryReadModel(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
      ),
      name: 'transactionHistoryReadModelProvider',
    );

final transactionHistoryProvider = StreamProvider.autoDispose
    .family<AppResult<TransactionHistoryPage>, TransactionHistoryRequest>(
      (ref, request) =>
          ref.watch(transactionHistoryReadModelProvider).watch(request),
      name: 'transactionHistoryProvider',
    );

final transactionByIdProvider =
    FutureProvider.family<AppResult<Transaction?>, String>(
      (ref, id) => ref.watch(getTransactionUseCaseProvider)(id),
      name: 'transactionByIdProvider',
    );

final transactionsByAccountProvider =
    FutureProvider.family<AppResult<List<Transaction>>, String>(
      (ref, accountId) =>
          ref.watch(getTransactionsUseCaseProvider)(accountId: accountId),
      name: 'transactionsByAccountProvider',
    );

final transactionsByPayeeProvider =
    FutureProvider.family<AppResult<List<Transaction>>, String>(
      (ref, payeeId) =>
          ref.watch(getTransactionsUseCaseProvider)(payeeId: payeeId),
      name: 'transactionsByPayeeProvider',
    );

final transactionsByTransferGroupProvider =
    FutureProvider.family<AppResult<List<Transaction>>, String>(
      (ref, transferGroupId) => ref.watch(getTransactionsUseCaseProvider)(
        transferGroupId: transferGroupId,
      ),
      name: 'transactionsByTransferGroupProvider',
    );

enum TransactionSearchFilter { all, income, expense, transfer, pending }

typedef TransactionSearchRequest = ({
  String query,
  TransactionSearchFilter filter,
});

final searchTransactionsProvider = FutureProvider.autoDispose
    .family<AppResult<List<Transaction>>, TransactionSearchRequest>((
      ref,
      request,
    ) {
      final transactionTypes = switch (request.filter) {
        TransactionSearchFilter.income => const <TransactionType>{
          TransactionType.income,
        },
        TransactionSearchFilter.expense => const <TransactionType>{
          TransactionType.expense,
        },
        TransactionSearchFilter.transfer => const <TransactionType>{
          TransactionType.transferIn,
          TransactionType.transferOut,
        },
        TransactionSearchFilter.all || TransactionSearchFilter.pending => null,
      };
      final status = request.filter == TransactionSearchFilter.pending
          ? TransactionStatus.pending
          : null;
      return ref.watch(searchTransactionsUseCaseProvider)(
        request.query,
        transactionTypes: transactionTypes,
        status: status,
      );
    }, name: 'searchTransactionsProvider');
