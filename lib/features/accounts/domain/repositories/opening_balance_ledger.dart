import 'package:decimal/decimal.dart';

/// Financial application boundary for recording a new account's opening
/// balance. Implementations must post exactly one durable ledger entry and
/// apply its balance effect through the Finance Engine.
abstract interface class OpeningBalanceLedger {
  Future<void> postOpeningBalance({
    required String accountId,
    required Decimal amount,
    required String currencyCode,
    required DateTime occurredAt,
  });
}
