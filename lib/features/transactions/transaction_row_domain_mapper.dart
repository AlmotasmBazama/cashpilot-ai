import '../../core/database/app_database.dart';
import 'domain/entities/transaction.dart';

/// Public Transactions boundary for data read models that already hold a
/// persisted transaction row.
///
/// The Drift implementation remains owned by Transactions. Other features
/// depend only on this narrow mapping contract instead of importing private
/// Transactions data code.
abstract interface class TransactionRowDomainMapper {
  Transaction map(TransactionRow row);
}
