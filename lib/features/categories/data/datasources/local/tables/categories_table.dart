import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();

  /// Null is allowed only for immutable built-in reference categories and
  /// unclaimed legacy rows. Custom categories are always owner-scoped.
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get icon => text()();

  IntColumn get color => integer()();

  TextColumn get parentCategoryId =>
      text().named('parent_category_id').nullable()();

  BoolColumn get isDefault =>
      boolean().named('is_default').withDefault(const Constant(false))();

  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().named('sort_order')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
