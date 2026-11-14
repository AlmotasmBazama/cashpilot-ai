import 'package:drift/drift.dart';

@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get type => text()();
  TextColumn get targetAmount => text().named('target_amount')();
  TextColumn get currentAmount => text().named('current_amount')();
  TextColumn get currency => text()();
  TextColumn get linkedAccountId =>
      text().named('linked_account_id').nullable()();
  DateTimeColumn get targetDate => dateTime().named('target_date').nullable()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();
  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
