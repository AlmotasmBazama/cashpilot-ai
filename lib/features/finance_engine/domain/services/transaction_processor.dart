import '../entities/account_balance_state.dart';
import '../entities/processed_transaction.dart';
import '../entities/transaction_command.dart';
import '../enums/finance_transaction_direction.dart';
import '../exceptions/finance_exception.dart';
import '../repositories/account_balance_repository.dart';
import '../repositories/finance_transaction_manager.dart';
import 'balance_calculator.dart';
import 'finance_validation_service.dart';

class TransactionProcessor {
  const TransactionProcessor({
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

  Future<ProcessedTransaction> process(TransactionCommand command) {
    return _transactionManager.runInTransaction(() async {
      final account = await _requiredAccount(command.accountId);

      switch (command.direction) {
        case FinanceTransactionDirection.credit:
          _validationService.validateCredit(account, command.amount);
        case FinanceTransactionDirection.debit:
          _validationService.validateDebit(account, command.amount);
      }

      final processedAt = command.occurredAt ?? DateTime.now().toUtc();
      final updatedAccount = _balanceCalculator.applyTransaction(
        account,
        command.amount,
        direction: command.direction,
        occurredAt: processedAt,
      );

      await _accountBalanceRepository.save(updatedAccount);

      return ProcessedTransaction(
        accountId: account.accountId,
        direction: command.direction,
        amount: command.amount,
        previousBalance: account.money,
        newBalance: updatedAccount.money,
        processedAt: processedAt,
      );
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
