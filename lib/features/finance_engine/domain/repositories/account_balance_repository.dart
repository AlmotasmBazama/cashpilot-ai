import '../entities/account_balance_state.dart';

abstract interface class AccountBalanceRepository {
  Future<AccountBalanceState?> getById(String accountId);

  Future<void> save(AccountBalanceState account);
}
