import 'package:decimal/decimal.dart';

import '../entities/account_balance_state.dart';
import '../entities/processed_transfer.dart';
import '../entities/transfer_command.dart';
import '../exceptions/finance_exception.dart';
import '../repositories/account_balance_repository.dart';
import '../repositories/exchange_rate_provider.dart';
import '../repositories/finance_transaction_manager.dart';
import '../value_objects/exchange_rate.dart';
import '../value_objects/money.dart';
import 'balance_calculator.dart';
import 'finance_validation_service.dart';

class TransferProcessor {
  const TransferProcessor({
    required AccountBalanceRepository accountBalanceRepository,
    required FinanceTransactionManager transactionManager,
    required BalanceCalculator balanceCalculator,
    required FinanceValidationService validationService,
    required ExchangeRateProvider exchangeRateProvider,
  }) : _accountBalanceRepository = accountBalanceRepository,
       _transactionManager = transactionManager,
       _balanceCalculator = balanceCalculator,
       _validationService = validationService,
       _exchangeRateProvider = exchangeRateProvider;

  final AccountBalanceRepository _accountBalanceRepository;
  final FinanceTransactionManager _transactionManager;
  final BalanceCalculator _balanceCalculator;
  final FinanceValidationService _validationService;
  final ExchangeRateProvider _exchangeRateProvider;

  Future<ProcessedTransfer> process(TransferCommand command) {
    return _transactionManager.runInTransaction(() async {
      final prepared = await preview(command);
      final updatedSource = _balanceCalculator.debit(
        prepared.sourceAccount,
        prepared.sourceAmount,
        occurredAt: prepared.processedAt,
      );
      final updatedTarget = _balanceCalculator.credit(
        prepared.targetAccount,
        prepared.targetAmount,
        occurredAt: prepared.processedAt,
      );

      await _accountBalanceRepository.save(updatedSource);
      await _accountBalanceRepository.save(updatedTarget);

      return ProcessedTransfer(
        sourceAccountId: prepared.sourceAccount.accountId,
        targetAccountId: prepared.targetAccount.accountId,
        sourceAmount: prepared.sourceAmount,
        targetAmount: prepared.targetAmount,
        sourcePreviousBalance: prepared.sourceAccount.money,
        sourceNewBalance: updatedSource.money,
        targetPreviousBalance: prepared.targetAccount.money,
        targetNewBalance: updatedTarget.money,
        exchangeRate: prepared.exchangeRate,
        processedAt: prepared.processedAt,
      );
    });
  }

  Future<ProcessedTransfer> reverse(TransferCommand command) {
    return _transactionManager.runInTransaction(() async {
      if (command.sourceAccountId == command.targetAccountId) {
        throw const FinanceException.sameAccountTransfer();
      }

      _validationService.validateAmount(command.sourceAmount);
      final sourceAccount = await _requiredAccount(command.sourceAccountId);
      final targetAccount = await _requiredAccount(command.targetAccountId);
      final processedAt = command.occurredAt ?? DateTime.now().toUtc();
      final exchangeRate = await _resolveExchangeRate(
        command: command,
        sourceAccount: sourceAccount,
        targetAccount: targetAccount,
        at: processedAt,
      );
      final targetAmount =
          command.targetAmount ??
          _balanceCalculator.convert(command.sourceAmount, exchangeRate);

      _validateExplicitAmountRateConsistency(
        command: command,
        targetAmount: targetAmount,
        exchangeRate: exchangeRate,
      );

      _validationService.validateTransferReversal(
        sourceAccount: sourceAccount,
        targetAccount: targetAccount,
        sourceAmount: command.sourceAmount,
        targetAmount: targetAmount,
        exchangeRate: exchangeRate,
      );

      final updatedSource = _balanceCalculator.credit(
        sourceAccount,
        command.sourceAmount,
        occurredAt: processedAt,
      );
      final updatedTarget = _balanceCalculator.debit(
        targetAccount,
        targetAmount,
        occurredAt: processedAt,
      );

      await _accountBalanceRepository.save(updatedSource);
      await _accountBalanceRepository.save(updatedTarget);

      return ProcessedTransfer(
        sourceAccountId: sourceAccount.accountId,
        targetAccountId: targetAccount.accountId,
        sourceAmount: command.sourceAmount,
        targetAmount: targetAmount,
        sourcePreviousBalance: sourceAccount.money,
        sourceNewBalance: updatedSource.money,
        targetPreviousBalance: targetAccount.money,
        targetNewBalance: updatedTarget.money,
        exchangeRate: exchangeRate,
        processedAt: processedAt,
      );
    });
  }

  Future<PreparedTransfer> preview(TransferCommand command) async {
    if (command.sourceAccountId == command.targetAccountId) {
      throw const FinanceException.sameAccountTransfer();
    }

    _validationService.validateAmount(command.sourceAmount);

    final sourceAccount = await _requiredAccount(command.sourceAccountId);
    final targetAccount = await _requiredAccount(command.targetAccountId);
    final processedAt = command.occurredAt ?? DateTime.now().toUtc();
    final exchangeRate = await _resolveExchangeRate(
      command: command,
      sourceAccount: sourceAccount,
      targetAccount: targetAccount,
      at: processedAt,
    );
    final targetAmount =
        command.targetAmount ??
        _balanceCalculator.convert(command.sourceAmount, exchangeRate);

    _validateExplicitAmountRateConsistency(
      command: command,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
    );

    _validationService.validateTransfer(
      sourceAccount: sourceAccount,
      targetAccount: targetAccount,
      sourceAmount: command.sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
    );

    return PreparedTransfer(
      sourceAccount: sourceAccount,
      targetAccount: targetAccount,
      sourceAmount: command.sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
      processedAt: processedAt,
    );
  }

  Future<ExchangeRate> _resolveExchangeRate({
    required TransferCommand command,
    required AccountBalanceState sourceAccount,
    required AccountBalanceState targetAccount,
    DateTime? at,
  }) async {
    if (command.exchangeRate case final exchangeRate?) {
      // TODO: Persist an exchange-rate provider/source once that metadata is
      // part of the ExchangeRate contract.
      return exchangeRate.asOf == null
          ? exchangeRate.copyWith(asOf: at)
          : exchangeRate;
    }

    if (command.targetAmount case final targetAmount?) {
      final rate = (targetAmount.amount / command.sourceAmount.amount)
          .toDecimal(scaleOnInfinitePrecision: 12);
      return ExchangeRate(
        fromCurrencyCode: command.sourceAmount.currencyCode,
        toCurrencyCode: targetAmount.currencyCode,
        rate: rate,
        asOf: at,
      );
    }

    return _exchangeRateProvider.getExchangeRate(
      fromCurrencyCode: sourceAccount.currencyCode,
      toCurrencyCode: targetAccount.currencyCode,
      at: at,
    );
  }

  void _validateExplicitAmountRateConsistency({
    required TransferCommand command,
    required Money targetAmount,
    required ExchangeRate exchangeRate,
  }) {
    if (command.targetAmount == null || command.exchangeRate == null) {
      return;
    }

    _validationService.validateTransferAmountRateConsistency(
      sourceAmount: command.sourceAmount,
      targetAmount: targetAmount,
      exchangeRate: exchangeRate,
    );
  }

  Future<AccountBalanceState> _requiredAccount(String accountId) async {
    final account = await _accountBalanceRepository.getById(accountId);
    if (account == null) {
      throw FinanceException.accountNotFound(accountId);
    }

    return account;
  }
}

class PreparedTransfer {
  const PreparedTransfer({
    required this.sourceAccount,
    required this.targetAccount,
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRate,
    required this.processedAt,
  });

  final AccountBalanceState sourceAccount;
  final AccountBalanceState targetAccount;
  final Money sourceAmount;
  final Money targetAmount;
  final ExchangeRate exchangeRate;
  final DateTime processedAt;
}
