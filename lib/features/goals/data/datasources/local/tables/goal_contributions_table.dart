import 'package:drift/drift.dart';

@DataClassName('GoalContributionRow')
class GoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get goalId => text().named('goal_id')();
  TextColumn get amount => text()();
  TextColumn get currency => text()();
  TextColumn get creditedAmount => text().named('credited_amount')();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get linkedTransactionId =>
      text().named('linked_transaction_id').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get reversedAt => dateTime().named('reversed_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
