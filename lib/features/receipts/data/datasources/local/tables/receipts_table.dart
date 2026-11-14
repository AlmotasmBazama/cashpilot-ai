import 'package:drift/drift.dart';

@DataClassName('ReceiptRow')
class Receipts extends Table {
  TextColumn get id => text()();
  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();
  TextColumn get documentType => text().named('document_type')();
  TextColumn get paymentStatus => text().named('payment_status')();
  TextColumn get merchantName => text().named('merchant_name').nullable()();
  TextColumn get merchantPayeeId =>
      text().named('merchant_payee_id').nullable()();
  TextColumn get merchantAddress =>
      text().named('merchant_address').nullable()();
  TextColumn get merchantTaxId => text().named('merchant_tax_id').nullable()();
  TextColumn get receiptNumber => text().named('receipt_number').nullable()();
  TextColumn get invoiceNumber => text().named('invoice_number').nullable()();
  DateTimeColumn get purchaseDate =>
      dateTime().named('purchase_date').nullable()();
  DateTimeColumn get dueDate => dateTime().named('due_date').nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get subtotal => text().nullable()();
  TextColumn get tax => text().nullable()();
  TextColumn get discount => text().nullable()();
  TextColumn get serviceCharge => text().named('service_charge').nullable()();
  TextColumn get tip => text().nullable()();
  TextColumn get otherFees => text().named('other_fees').nullable()();
  TextColumn get total => text().nullable()();
  TextColumn get amountPaid => text().named('amount_paid').nullable()();
  TextColumn get amountDue => text().named('amount_due').nullable()();
  TextColumn get paymentMethodHint =>
      text().named('payment_method_hint').nullable()();
  TextColumn get accountHint => text().named('account_hint').nullable()();
  IntColumn get confidence => integer().withDefault(const Constant(0))();
  TextColumn get warningsJson =>
      text().named('warnings_json').withDefault(const Constant('[]'))();
  TextColumn get duplicateCandidateIdsJson => text()
      .named('duplicate_candidate_ids_json')
      .withDefault(const Constant('[]'))();
  TextColumn get imageRetentionChoice =>
      text().named('image_retention_choice')();
  TextColumn get localImageReference =>
      text().named('local_image_reference').nullable()();
  TextColumn get imageHash => text().named('image_hash').nullable()();
  TextColumn get status => text()();
  TextColumn get linkedTransactionId =>
      text().named('linked_transaction_id').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
