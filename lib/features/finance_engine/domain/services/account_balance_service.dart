import '../entities/account_balance_state.dart';
import '../exceptions/finance_exception.dart';
import '../repositories/account_balance_repository.dart';
import '../repositories/finance_transaction_manager.dart';
import '../value_objects/money.dart';
import 'balance_calculator.dart';
import 'finance_validation_service.dart';

class AccountBalanceService {
  const AccountBalanceService({
    required AccountBalanceRepository accountBalanceRepository,
    required FinanceTransactionManager transactionManager,
    required BalanceCalculator balanceCalculator,
    required FinanceValidationService validationService,
  }) : _accountBalanceRepository = accountBalanceRepository,
       _transactionManager = transactionManager,
       _balanceCalculator = balanceCalculator,
       _validationService = validationService;

  final AccountBalanceRepository _accountBalanceRepository;
  final FinanceTransactionManager _transactionManager;
  final BalanceCalculator _balanceCalculator;
  final FinanceValidationService _validationService;

  Future<AccountBalanceState> getBalance(String accountId) {
    return _transactionManager.runInTransaction(() async {
      final account = await _accountBalanceRepository.getById(accountId);
      if (account == null) {
        throw FinanceException.accountNotFound(accountId);
      }

      _validationService.validateAccountConfiguration(account);
      return account;
    });
  }

  Future<AccountBalanceState> credit(
    String accountId,
    Money amount, {
    DateTime? occurredAt,
  }) {
    return _transactionManager.runInTransaction(() async {
      final account = await _requiredAccount(accountId);
      _validationService.validateCredit(account, amount);

      final updated = _balanceCalculator.credit(
        account,
        amount,
        occurredAt: occurredAt,
      );

      await _accountBalanceRepository.save(updated);
      return updated;
    });
  }

  Future<AccountBalanceState> debit(
    String accountId,
    Money amount, {
    DateTime? occurredAt,
  }) {
    return _transactionManager.runInTransaction(() async {
      final account = await _requiredAccount(accountId);
      _validationService.validateDebit(account, amount);

      final updated = _balanceCalculator.debit(
        account,
        amount,
        occurredAt: occurredAt,
      );

      await _accountBalanceRepository.save(updated);
      return updated;
    });
  }

  Future<AccountBalanceState> replaceBalance(AccountBalanceState account) {
    return _transactionManager.runInTransaction(() async {
      _validationService.validateAccountConfiguration(account);
      await _accountBalanceRepository.save(account);
      return account;
    });
  }

  Future<AccountBalanceState> _requiredAccount(String accountId) async {
    final account = await _accountBalanceRepository.getById(accountId);
    if (account == null) {
      throw FinanceException.accountNotFound(accountId);
    }

    return account;
  }
}
