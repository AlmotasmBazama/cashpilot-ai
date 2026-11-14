import 'package:drift/drift.dart';

@DataClassName('ReceiptLineItemRow')
class ReceiptLineItems extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get receiptId => text().named('receipt_id')();
  TextColumn get description => text()();
  TextColumn get normalizedDescription =>
      text().named('normalized_description')();
  TextColumn get quantity => text().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get unitPrice => text().named('unit_price').nullable()();
  TextColumn get discount => text().nullable()();
  TextColumn get tax => text().nullable()();
  TextColumn get totalPrice => text().named('total_price').nullable()();
  TextColumn get categoryId => text().named('category_id').nullable()();
  TextColumn get categoryHint => text().named('category_hint').nullable()();
  IntColumn get categoryConfidence =>
      integer().named('category_confidence').withDefault(const Constant(0))();
  TextColumn get categorySuggestionSource =>
      text().named('category_suggestion_source')();
  TextColumn get categoryAlternativesJson => text()
      .named('category_alternatives_json')
      .withDefault(const Constant('[]'))();
  TextColumn get skuOrBarcode => text().named('sku_or_barcode').nullable()();
  TextColumn get warningsJson =>
      text().named('warnings_json').withDefault(const Constant('[]'))();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
