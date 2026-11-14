import 'package:drift/drift.dart';

@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();

  TextColumn get ownerScopeId => text().named('owner_scope_id').nullable()();

  TextColumn get accountId => text().named('account_id')();

  TextColumn get categoryId => text().named('category_id')();

  TextColumn get payeeId => text().named('payee_id').nullable()();

  TextColumn get amount => text()();

  TextColumn get currencyCode => text().named('currency_code')();

  TextColumn get type => text()();

  TextColumn get paymentMethod => text().named('payment_method')();

  TextColumn get source => text()();

  TextColumn get status => text()();

  TextColumn get incomeSourceType =>
      text().named('income_source_type').nullable()();

  TextColumn get transferGroupId =>
      text().named('transfer_group_id').nullable()();

  /// SHA-256 of the canonical owner-scoped transfer creation intent. New
  /// transfer pairs store the same value on both legs so the committed pair
  /// is also the durable idempotency record. Null is reserved for legacy rows.
  TextColumn get transferPayloadFingerprint =>
      text().named('transfer_payload_fingerprint').nullable()();

  TextColumn get exchangeRateFromCurrencyCode =>
      text().named('exchange_rate_from_currency_code').nullable()();

  TextColumn get exchangeRateToCurrencyCode =>
      text().named('exchange_rate_to_currency_code').nullable()();

  TextColumn get exchangeRate => text().named('exchange_rate').nullable()();

  DateTimeColumn get exchangeRateAsOf =>
      dateTime().named('exchange_rate_as_of').nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get transactionDate => dateTime().named('transaction_date')();

  TextColumn get location => text().nullable()();

  IntColumn get attachmentCount =>
      integer().named('attachment_count').withDefault(const Constant(0))();

  IntColumn get aiConfidence => integer().named('ai_confidence').nullable()();

  BoolColumn get needsReview =>
      boolean().named('needs_review').withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
