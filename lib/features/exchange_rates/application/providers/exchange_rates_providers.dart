import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/sync_providers.dart';
import '../../../finance_engine/domain/repositories/exchange_rate_provider.dart';
import '../../../finance_engine/domain/value_objects/exchange_rate.dart';
import '../../data/adapters/stored_exchange_rate_provider.dart';
import '../../data/datasources/local/exchange_rates_local_data_source.dart';
import '../../data/repositories/exchange_rate_repository_impl.dart';
import '../../domain/entities/stored_exchange_rate.dart';
import '../../domain/repositories/exchange_rate_repository.dart';
import '../../domain/usecases/archive_exchange_rate.dart';
import '../../domain/usecases/convert_money.dart';
import '../../domain/usecases/get_exchange_rate.dart';
import '../../domain/usecases/get_latest_exchange_rate.dart';
import '../../domain/usecases/get_rates_for_base_currency.dart';
import '../../domain/usecases/upsert_exchange_rate.dart';
import '../../domain/usecases/watch_exchange_rates.dart';

final exchangeRatesLocalDataSourceProvider =
    Provider<ExchangeRatesLocalDataSource>(
      (ref) => DriftExchangeRatesLocalDataSource(
        ref.watch(requiredScopedAppDatabaseSessionProvider),
      ),
      name: 'exchangeRatesLocalDataSourceProvider',
    );

final exchangeRateRepositoryProvider = Provider<ExchangeRateRepository>(
  (ref) => ExchangeRateRepositoryImpl(
    localDataSource: ref.watch(exchangeRatesLocalDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
    syncQueue: ref.watch(syncMutationQueueProvider),
  ),
  name: 'exchangeRateRepositoryProvider',
);

final watchExchangeRatesUseCaseProvider = Provider<WatchExchangeRates>(
  (ref) => WatchExchangeRates(ref.watch(exchangeRateRepositoryProvider)),
  name: 'watchExchangeRatesUseCaseProvider',
);
final getExchangeRateUseCaseProvider = Provider<GetExchangeRate>(
  (ref) => GetExchangeRate(ref.watch(exchangeRateRepositoryProvider)),
  name: 'getExchangeRateUseCaseProvider',
);
final getLatestExchangeRateUseCaseProvider = Provider<GetLatestExchangeRate>(
  (ref) => GetLatestExchangeRate(ref.watch(exchangeRateRepositoryProvider)),
  name: 'getLatestExchangeRateUseCaseProvider',
);
final getRatesForBaseCurrencyUseCaseProvider =
    Provider<GetRatesForBaseCurrency>(
      (ref) =>
          GetRatesForBaseCurrency(ref.watch(exchangeRateRepositoryProvider)),
      name: 'getRatesForBaseCurrencyUseCaseProvider',
    );
final upsertExchangeRateUseCaseProvider = Provider<UpsertExchangeRate>(
  (ref) => UpsertExchangeRate(ref.watch(exchangeRateRepositoryProvider)),
  name: 'upsertExchangeRateUseCaseProvider',
);
final archiveExchangeRateUseCaseProvider = Provider<ArchiveExchangeRate>(
  (ref) => ArchiveExchangeRate(ref.watch(exchangeRateRepositoryProvider)),
  name: 'archiveExchangeRateUseCaseProvider',
);
final convertMoneyUseCaseProvider = Provider<ConvertMoney>(
  (ref) => ConvertMoney(ref.watch(exchangeRateRepositoryProvider)),
  name: 'convertMoneyUseCaseProvider',
);

final storedExchangeRateProvider = Provider<ExchangeRateProvider>(
  (ref) =>
      StoredExchangeRateProvider(ref.watch(exchangeRateRepositoryProvider)),
  name: 'storedExchangeRateProvider',
);

final exchangeRatesProvider =
    StreamProvider<AppResult<List<StoredExchangeRate>>>(
      (ref) => ref.watch(watchExchangeRatesUseCaseProvider)(),
      name: 'exchangeRatesProvider',
    );

final allExchangeRatesProvider =
    StreamProvider<AppResult<List<StoredExchangeRate>>>(
      (ref) =>
          ref.watch(watchExchangeRatesUseCaseProvider)(includeArchived: true),
      name: 'allExchangeRatesProvider',
    );

final latestExchangeRateProvider =
    FutureProvider.family<AppResult<ExchangeRate?>, ({String from, String to})>(
      (ref, pair) {
        return ref.watch(getLatestExchangeRateUseCaseProvider)(
          pair.from,
          pair.to,
        );
      },
      name: 'latestExchangeRateProvider',
    );
