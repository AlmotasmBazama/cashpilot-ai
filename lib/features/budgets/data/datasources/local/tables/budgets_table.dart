import 'package:drift/drift.dart';

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().named('category_id')();
  TextColumn get amount => text()();
  TextColumn get currency => text()();
  TextColumn get periodType => text().named('period_type')();
  DateTimeColumn get startDate => dateTime().named('start_date')();
  DateTimeColumn get endDate => dateTime().named('end_date')();
  IntColumn get alertThresholdPercent =>
      integer().named('alert_threshold_percent')();
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
