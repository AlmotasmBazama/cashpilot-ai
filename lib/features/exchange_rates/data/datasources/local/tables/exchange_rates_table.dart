import 'package:drift/drift.dart';

@DataClassName('ExchangeRateRow')
class ExchangeRates extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get baseCurrency => text().named('base_currency')();
  TextColumn get quoteCurrency => text().named('quote_currency')();
  TextColumn get rate => text()();
  TextColumn get source => text()();
  DateTimeColumn get fetchedAt => dateTime().named('fetched_at')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
