import 'package:drift/drift.dart';

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();

  /// Opaque, locally-derived owner scope. Null is reserved for unclaimed
  /// pre-v15 rows and is rejected for all new production writes.
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();

  TextColumn get balance => text()();

  TextColumn get icon => text()();

  IntColumn get color => integer()();

  TextColumn get paymentMethodIds =>
      text().named('payment_method_ids').withDefault(const Constant('[]'))();

  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
