import 'package:drift/drift.dart';

/// System-internal, privacy-safe record of explicit legacy ownership claims.
/// It contains no Firebase UID and no financial row contents.
@DataClassName('OwnerScopeMigrationAuditRow')
class OwnerScopeMigrationAudits extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id')();
  TextColumn get status => text()();
  TextColumn get boundedCountsJson => text().named('bounded_counts_json')();
  TextColumn get safeFailureCode =>
      text().named('safe_failure_code').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
