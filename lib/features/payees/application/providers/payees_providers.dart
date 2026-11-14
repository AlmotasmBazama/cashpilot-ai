import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/sync/application/sync_providers.dart';
import '../../data/datasources/local/payees_local_data_source.dart';
import '../../data/repositories/payees_repository_impl.dart';
import '../../domain/entities/payee.dart';
import '../../domain/repositories/payees_repository.dart';
import '../../domain/services/payee_resolver.dart';
import '../../domain/usecases/archive_payee.dart';
import '../../domain/usecases/create_payee.dart';
import '../../domain/usecases/get_payee_by_id.dart';
import '../../domain/usecases/resolve_payee.dart';
import '../../domain/usecases/restore_payee.dart';
import '../../domain/usecases/search_payees.dart';
import '../../domain/usecases/touch_payee_last_used.dart';
import '../../domain/usecases/update_payee.dart';
import '../../domain/usecases/watch_payees.dart';

final payeeResolverProvider = Provider<PayeeResolver>(
  (_) => const PayeeResolver(),
  name: 'payeeResolverProvider',
);

final payeesLocalDataSourceProvider = Provider<PayeesLocalDataSource>(
  (ref) => DriftPayeesLocalDataSource(
    ref.watch(requiredScopedAppDatabaseSessionProvider),
  ),
  name: 'payeesLocalDataSourceProvider',
);

final payeesRepositoryProvider = Provider<PayeesRepository>(
  (ref) => PayeesRepositoryImpl(
    localDataSource: ref.watch(payeesLocalDataSourceProvider),
    resolver: ref.watch(payeeResolverProvider),
    logger: ref.watch(appLoggerProvider),
    syncQueue: ref.watch(syncMutationQueueProvider),
  ),
  name: 'payeesRepositoryProvider',
);

final watchPayeesUseCaseProvider = Provider<WatchPayees>(
  (ref) => WatchPayees(ref.watch(payeesRepositoryProvider)),
  name: 'watchPayeesUseCaseProvider',
);
final getPayeeByIdUseCaseProvider = Provider<GetPayeeById>(
  (ref) => GetPayeeById(ref.watch(payeesRepositoryProvider)),
  name: 'getPayeeByIdUseCaseProvider',
);
final searchPayeesUseCaseProvider = Provider<SearchPayees>(
  (ref) => SearchPayees(ref.watch(payeesRepositoryProvider)),
  name: 'searchPayeesUseCaseProvider',
);
final createPayeeUseCaseProvider = Provider<CreatePayee>(
  (ref) => CreatePayee(ref.watch(payeesRepositoryProvider)),
  name: 'createPayeeUseCaseProvider',
);
final updatePayeeUseCaseProvider = Provider<UpdatePayee>(
  (ref) => UpdatePayee(ref.watch(payeesRepositoryProvider)),
  name: 'updatePayeeUseCaseProvider',
);
final archivePayeeUseCaseProvider = Provider<ArchivePayee>(
  (ref) => ArchivePayee(ref.watch(payeesRepositoryProvider)),
  name: 'archivePayeeUseCaseProvider',
);
final restorePayeeUseCaseProvider = Provider<RestorePayee>(
  (ref) => RestorePayee(ref.watch(payeesRepositoryProvider)),
  name: 'restorePayeeUseCaseProvider',
);
final resolvePayeeUseCaseProvider = Provider<ResolvePayee>(
  (ref) => ResolvePayee(ref.watch(payeesRepositoryProvider)),
  name: 'resolvePayeeUseCaseProvider',
);
final touchPayeeLastUsedUseCaseProvider = Provider<TouchPayeeLastUsed>(
  (ref) => TouchPayeeLastUsed(ref.watch(payeesRepositoryProvider)),
  name: 'touchPayeeLastUsedUseCaseProvider',
);

final payeesProvider = StreamProvider<AppResult<List<Payee>>>(
  (ref) => ref.watch(watchPayeesUseCaseProvider)(),
  name: 'payeesProvider',
);
final allPayeesProvider = StreamProvider<AppResult<List<Payee>>>(
  (ref) => ref.watch(watchPayeesUseCaseProvider)(includeArchived: true),
  name: 'allPayeesProvider',
);
final payeeByIdProvider = FutureProvider.family<AppResult<Payee?>, String>(
  (ref, id) => ref.watch(getPayeeByIdUseCaseProvider)(id),
  name: 'payeeByIdProvider',
);
final searchPayeesProvider =
    FutureProvider.family<AppResult<List<Payee>>, String>(
      (ref, query) => ref.watch(searchPayeesUseCaseProvider)(query),
      name: 'searchPayeesProvider',
    );
