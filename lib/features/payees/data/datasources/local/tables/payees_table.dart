import 'package:drift/drift.dart';

@DataClassName('PayeeRow')
class Payees extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().named('normalized_name')();
  TextColumn get type => text().withDefault(const Constant('other'))();
  TextColumn get aliases => text().withDefault(const Constant('[]'))();
  TextColumn get defaultCategoryId =>
      text().named('default_category_id').nullable()();
  TextColumn get defaultAccountId =>
      text().named('default_account_id').nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get lastUsedAt =>
      dateTime().named('last_used_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
