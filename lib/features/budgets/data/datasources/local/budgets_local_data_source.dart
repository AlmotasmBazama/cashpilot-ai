import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../dtos/budget_dto.dart';
import '../../mappers/budget_mapper.dart';

abstract interface class BudgetsLocalDataSource {
  Stream<List<BudgetDto>> watchBudgets({bool includeArchived = false});
  Future<List<BudgetDto>> getBudgets({bool includeArchived = false});
  Future<BudgetDto?> getBudgetById(String id);
  Future<BudgetDto> createBudget(BudgetDto budget);
  Future<BudgetDto> updateBudget(BudgetDto budget);
}

class DriftBudgetsLocalDataSource implements BudgetsLocalDataSource {
  const DriftBudgetsLocalDataSource(this._session);

  final ScopedAppDatabaseSession _session;
  AppDatabase get _database => _session.database;
  String get _scope => _session.ownerScopeValue;

  @override
  Stream<List<BudgetDto>> watchBudgets({bool includeArchived = false}) {
    final query = _database.select(_database.budgets);
    query.where((row) => row.ownerScopeId.equals(_scope));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    _order(query);
    return _session
        .guardStream(query.watch())
        .map((rows) => rows.map((row) => row.toDto()).toList(growable: false));
  }

  @override
  Future<List<BudgetDto>> getBudgets({bool includeArchived = false}) async {
    final query = _database.select(_database.budgets);
    query.where((row) => row.ownerScopeId.equals(_scope));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    _order(query);
    return (await query.get())
        .map((row) => row.toDto())
        .toList(growable: false);
  }

  @override
  Future<BudgetDto?> getBudgetById(String id) async {
    final row =
        await (_database.select(_database.budgets)..where(
              (row) => row.ownerScopeId.equals(_scope) & row.id.equals(id),
            ))
            .getSingleOrNull();
    return row?.toDto();
  }

  @override
  Future<BudgetDto> createBudget(BudgetDto budget) async {
    return _session.runGuardedWrite(() async {
      await _database
          .into(_database.budgets)
          .insert(budget.toCompanion().copyWith(ownerScopeId: Value(_scope)));
      return budget;
    });
  }

  @override
  Future<BudgetDto> updateBudget(BudgetDto budget) async {
    return _session.runGuardedWrite(() async {
      final count =
          await (_database.update(_database.budgets)..where(
                (row) =>
                    row.ownerScopeId.equals(_scope) & row.id.equals(budget.id),
              ))
              .write(
                budget.toCompanion().copyWith(ownerScopeId: Value(_scope)),
              );
      if (count == 0) {
        throw const AppException.cache(
          message: 'Budget not found.',
          code: 'budget_not_found',
        );
      }
      return budget;
    });
  }

  void _order(SimpleSelectStatement<$BudgetsTable, BudgetRow> query) {
    query.orderBy([
      (row) => OrderingTerm(expression: row.isActive, mode: OrderingMode.desc),
      (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
    ]);
  }
}
