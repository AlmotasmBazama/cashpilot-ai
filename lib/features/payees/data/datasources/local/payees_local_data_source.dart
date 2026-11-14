import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../domain/enums/payee_type.dart';
import '../../dtos/payee_dto.dart';
import '../../mappers/payee_mapper.dart';

abstract interface class PayeesLocalDataSource {
  Future<T> runInTransaction<T>(Future<T> Function() operation);
  Stream<List<PayeeDto>> watchPayees({
    bool includeArchived = false,
    PayeeType? type,
  });
  Future<List<PayeeDto>> getPayees({bool includeArchived = false});
  Future<PayeeDto?> getPayeeById(String id);
  Future<PayeeDto> createPayee(PayeeDto payee);
  Future<PayeeDto> updatePayee(PayeeDto payee);
  Future<bool> accountExists(String id);
  Future<bool> categoryExists(String id);
}

class DriftPayeesLocalDataSource implements PayeesLocalDataSource {
  const DriftPayeesLocalDataSource(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) =>
      _session.runGuardedWrite(() => _database.transaction(operation));

  @override
  Stream<List<PayeeDto>> watchPayees({
    bool includeArchived = false,
    PayeeType? type,
  }) {
    final query = _database.select(_database.payees);
    query.where((row) => row.ownerScopeId.equals(_scope));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    if (type != null) {
      query.where((row) => row.type.equals(type.storageValue));
    }
    query.orderBy([(row) => OrderingTerm(expression: row.name)]);
    return _session
        .guardStream(query.watch())
        .map((rows) => rows.map((row) => row.toDto()).toList(growable: false));
  }

  @override
  Future<List<PayeeDto>> getPayees({bool includeArchived = false}) async {
    final query = _database.select(_database.payees);
    query.where((row) => row.ownerScopeId.equals(_scope));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    query.orderBy([(row) => OrderingTerm(expression: row.name)]);
    final rows = await query.get();
    return rows.map((row) => row.toDto()).toList(growable: false);
  }

  @override
  Future<PayeeDto?> getPayeeById(String id) async {
    final row =
        await (_database.select(_database.payees)..where(
              (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
            ))
            .getSingleOrNull();
    return row?.toDto();
  }

  @override
  Future<PayeeDto> createPayee(PayeeDto payee) async {
    return _session.runGuardedWrite(() async {
      await _database
          .into(_database.payees)
          .insert(payee.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      return payee;
    });
  }

  @override
  Future<PayeeDto> updatePayee(PayeeDto payee) async {
    return _session.runGuardedWrite(() async {
      final count =
          await (_database.update(_database.payees)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.equals(payee.id),
              ))
              .write(payee.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      if (count == 0) {
        throw const AppException.cache(
          message: 'Payee not found.',
          code: 'payee_not_found',
        );
      }
      return payee;
    });
  }

  @override
  Future<bool> accountExists(String id) async {
    return await (_database.select(_database.accounts)..where(
              (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
            ))
            .getSingleOrNull() !=
        null;
  }

  @override
  Future<bool> categoryExists(String id) async {
    return await (_database.select(_database.categories)..where(
              (row) =>
                  row.id.equals(id) &
                  (row.ownerScopeId.equals(_scope) |
                      (row.ownerScopeId.isNull() & row.isDefault.equals(true))),
            ))
            .getSingleOrNull() !=
        null;
  }
}
