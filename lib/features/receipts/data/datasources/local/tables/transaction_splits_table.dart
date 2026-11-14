import 'package:drift/drift.dart';

@DataClassName('TransactionSplitRow')
class TransactionSplits extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get receiptId => text().named('receipt_id')();
  TextColumn get transactionId => text().named('transaction_id').nullable()();
  TextColumn get draftId => text().named('draft_id').nullable()();
  TextColumn get categoryId => text().named('category_id')();
  TextColumn get amount => text()();
  TextColumn get sourceReceiptItemIdsJson => text()
      .named('source_receipt_item_ids_json')
      .withDefault(const Constant('[]'))();
  TextColumn get description => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
