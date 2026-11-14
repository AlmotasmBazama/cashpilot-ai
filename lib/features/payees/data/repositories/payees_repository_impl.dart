import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/sync/application/sync_mutation_queue.dart';
import '../../../../core/sync/domain/sync_types.dart';
import '../../domain/entities/payee.dart';
import '../../domain/entities/payee_resolution.dart';
import '../../domain/enums/payee_type.dart';
import '../../domain/failures/payee_failure_codes.dart';
import '../../domain/repositories/payees_repository.dart';
import '../../domain/services/payee_name_normalizer.dart';
import '../../domain/services/payee_resolver.dart';
import '../datasources/local/payees_local_data_source.dart';
import '../mappers/payee_mapper.dart';

class PayeesRepositoryImpl implements PayeesRepository {
  const PayeesRepositoryImpl({
    required PayeesLocalDataSource localDataSource,
    required PayeeResolver resolver,
    required AppLogger logger,
    SyncMutationQueue? syncQueue,
  }) : _localDataSource = localDataSource,
       _resolver = resolver,
       _logger = logger,
       _syncQueue = syncQueue;

  final PayeesLocalDataSource _localDataSource;
  final PayeeResolver _resolver;
  final AppLogger _logger;
  final SyncMutationQueue? _syncQueue;

  @override
  Stream<AppResult<List<Payee>>> watchPayees({
    bool includeArchived = false,
    PayeeType? type,
  }) async* {
    try {
      await for (final items in _localDataSource.watchPayees(
        includeArchived: includeArchived,
        type: type,
      )) {
        yield AppResult.success(
          items.map((item) => item.toDomain()).toList(growable: false),
        );
      }
    } on Object catch (error, stackTrace) {
      _logger.error('Unable to watch payees.', error, stackTrace);
      yield const AppResult.failure(
        Failure(message: 'Unable to watch payees.'),
      );
    }
  }

  @override
  Future<AppResult<Payee?>> getPayeeById(String id) async {
    try {
      return AppResult.success(
        (await _localDataSource.getPayeeById(id))?.toDomain(),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to load payee.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<List<Payee>>> searchPayees(
    String query, {
    bool includeArchived = false,
  }) async {
    try {
      final normalized = PayeeNameNormalizer.normalize(query);
      final compact = PayeeNameNormalizer.compact(query);
      final payees = (await _localDataSource.getPayees(
        includeArchived: includeArchived,
      )).map((item) => item.toDomain());
      return AppResult.success(
        payees
            .where((payee) {
              final values = <String>[payee.name, ...payee.aliases];
              return values.any((value) {
                final valueNormalized = PayeeNameNormalizer.normalize(value);
                return valueNormalized.contains(normalized) ||
                    PayeeNameNormalizer.compact(value).contains(compact);
              });
            })
            .toList(growable: false),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to search payees.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Payee>> createPayee(Payee payee) => _save(payee);

  @override
  Future<AppResult<Payee>> updatePayee(Payee payee) =>
      _save(payee, update: true);

  Future<AppResult<Payee>> _save(Payee payee, {bool update = false}) async {
    try {
      final normalized = Payee.create(
        id: payee.id,
        name: payee.name,
        type: payee.type,
        aliases: payee.aliases,
        defaultCategoryId: payee.defaultCategoryId,
        defaultAccountId: payee.defaultAccountId,
        notes: payee.notes,
        lastUsedAt: payee.lastUsedAt,
        createdAt: payee.createdAt,
        updatedAt: DateTime.now().toUtc(),
        archivedAt: payee.archivedAt,
      );
      final stored = await _localDataSource.runInTransaction(() async {
        await _validate(normalized, update: update);
        return update
            ? _localDataSource.updatePayee(normalized.toDto())
            : _localDataSource.createPayee(normalized.toDto());
      });
      final result = stored.toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to save payee.', error, stackTrace);
    }
  }

  Future<void> _validate(Payee payee, {required bool update}) async {
    if (update && await _localDataSource.getPayeeById(payee.id) == null) {
      throw const PayeeValidationException(
        code: PayeeFailureCodes.notFound,
        message: 'Payee not found.',
      );
    }
    if (payee.defaultAccountId case final id?
        when !await _localDataSource.accountExists(id)) {
      throw const PayeeValidationException(
        code: PayeeFailureCodes.defaultAccountNotFound,
        message: 'Default account was not found.',
      );
    }
    if (payee.defaultCategoryId case final id?
        when !await _localDataSource.categoryExists(id)) {
      throw const PayeeValidationException(
        code: PayeeFailureCodes.defaultCategoryNotFound,
        message: 'Default category was not found.',
      );
    }

    final candidateName = PayeeNameNormalizer.compact(payee.name);
    final candidateAliases = payee.aliases
        .map(PayeeNameNormalizer.compact)
        .toSet();
    for (final dto in await _localDataSource.getPayees(includeArchived: true)) {
      final existing = dto.toDomain();
      if (existing.id == payee.id) {
        continue;
      }
      final existingName = PayeeNameNormalizer.compact(existing.name);
      final existingAliases = existing.aliases
          .map(PayeeNameNormalizer.compact)
          .toSet();
      if (existingName == candidateName) {
        throw const PayeeValidationException(
          code: PayeeFailureCodes.duplicateName,
          message: 'A payee with this name already exists.',
        );
      }
      if (candidateAliases.contains(existingName) ||
          existingAliases.contains(candidateName) ||
          candidateAliases.intersection(existingAliases).isNotEmpty) {
        throw const PayeeValidationException(
          code: PayeeFailureCodes.duplicateAlias,
          message: 'A payee alias is already assigned.',
        );
      }
    }
  }

  @override
  Future<AppResult<Payee>> archivePayee(String id) =>
      _changeArchive(id, archive: true);

  @override
  Future<AppResult<Payee>> restorePayee(String id) =>
      _changeArchive(id, archive: false);

  Future<AppResult<Payee>> _changeArchive(
    String id, {
    required bool archive,
  }) async {
    try {
      final existing = await _localDataSource.getPayeeById(id);
      if (existing == null) {
        throw const PayeeValidationException(
          code: PayeeFailureCodes.notFound,
          message: 'Payee not found.',
        );
      }
      final now = DateTime.now().toUtc();
      final updated = existing.copyWith(
        archivedAt: archive ? now : null,
        updatedAt: now,
      );
      final result = (await _localDataSource.updatePayee(updated)).toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure(
        'Unable to update payee archive status.',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<AppResult<PayeeResolution>> resolvePayee(
    String query, {
    bool includeArchived = false,
  }) async {
    try {
      final payees = (await _localDataSource.getPayees(
        includeArchived: includeArchived,
      )).map((item) => item.toDomain()).toList(growable: false);
      return AppResult.success(
        _resolver.resolve(query, payees, includeArchived: includeArchived),
      );
    } on Object catch (error, stackTrace) {
      return _failure('Unable to resolve payee.', error, stackTrace);
    }
  }

  @override
  Future<AppResult<Payee>> touchLastUsed(String id, DateTime usedAt) async {
    try {
      final existing = await _localDataSource.getPayeeById(id);
      if (existing == null) {
        throw const PayeeValidationException(
          code: PayeeFailureCodes.notFound,
          message: 'Payee not found.',
        );
      }
      final candidate = usedAt.toUtc();
      final current = existing.lastUsedAt?.toUtc();
      if (current != null && !candidate.isAfter(current)) {
        return AppResult.success(existing.toDomain());
      }
      final updated = existing.copyWith(
        lastUsedAt: candidate,
        updatedAt: DateTime.now().toUtc(),
      );
      final result = (await _localDataSource.updatePayee(updated)).toDomain();
      await _queueUpsert(result);
      return AppResult.success(result);
    } on Object catch (error, stackTrace) {
      return _failure('Unable to update payee usage.', error, stackTrace);
    }
  }

  AppResult<T> _failure<T>(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(message, error, stackTrace);
    return switch (error) {
      PayeeValidationException(:final code, :final message) =>
        AppResult.failure(Failure(message: message, code: code)),
      AppException(:final code, :final message) => AppResult.failure(
        Failure(message: message, code: code),
      ),
      _ => AppResult.failure(Failure(message: message)),
    };
  }

  Future<void> _queueUpsert(Payee payee) {
    return enqueueSyncUpsertBestEffort(
      queue: _syncQueue,
      entityType: SyncEntityType.payee,
      entityId: payee.id,
      payload: payee.toJson(),
      logger: _logger,
    );
  }
}
