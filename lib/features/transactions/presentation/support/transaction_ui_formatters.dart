import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../../domain/enums/transaction_source.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';

abstract final class TransactionUiFormatters {
  static String typeLabel(TransactionType type, [AppLocalizations? l10n]) {
    if (l10n != null) {
      return switch (type) {
        TransactionType.expense => l10n.transactionTypeExpense,
        TransactionType.income => l10n.transactionTypeIncome,
        TransactionType.transferOut => l10n.transactionTypeTransferOut,
        TransactionType.transferIn => l10n.transactionTypeTransferIn,
      };
    }

    return switch (type) {
      TransactionType.expense => 'Expense',
      TransactionType.income => 'Income',
      TransactionType.transferOut => 'Transfer out',
      TransactionType.transferIn => 'Transfer in',
    };
  }

  static String statusLabel(
    TransactionStatus status, [
    AppLocalizations? l10n,
  ]) {
    if (l10n != null) {
      return switch (status) {
        TransactionStatus.pending => l10n.transactionStatusPending,
        TransactionStatus.posted => l10n.transactionStatusPosted,
        TransactionStatus.cancelled => l10n.transactionStatusCancelled,
        TransactionStatus.failed => l10n.transactionStatusFailed,
      };
    }

    return switch (status) {
      TransactionStatus.pending => 'Pending',
      TransactionStatus.posted => 'Posted',
      TransactionStatus.cancelled => 'Cancelled',
      TransactionStatus.failed => 'Failed',
    };
  }

  static String paymentMethodLabel(
    PaymentMethod method, [
    AppLocalizations? l10n,
  ]) {
    if (l10n != null) {
      return switch (method) {
        PaymentMethod.cash => l10n.paymentMethodCash,
        PaymentMethod.debitCard => l10n.paymentMethodDebitCard,
        PaymentMethod.creditCard => l10n.paymentMethodCreditCard,
        PaymentMethod.bankTransfer => l10n.paymentMethodBankTransfer,
        PaymentMethod.digitalWallet => l10n.paymentMethodDigitalWallet,
        PaymentMethod.edfaly => l10n.paymentMethodEdfaly,
        PaymentMethod.masrafiPay => l10n.paymentMethodMasrafiPay,
        PaymentMethod.mobiCash => l10n.paymentMethodMobiCash,
        PaymentMethod.yusrPay => l10n.paymentMethodYusrPay,
        PaymentMethod.check => l10n.paymentMethodCheck,
        PaymentMethod.crypto => l10n.paymentMethodCrypto,
        PaymentMethod.other => l10n.paymentMethodOther,
      };
    }

    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.debitCard => 'Debit card',
      PaymentMethod.creditCard => 'Credit card',
      PaymentMethod.bankTransfer => 'Bank transfer',
      PaymentMethod.digitalWallet => 'Digital wallet',
      PaymentMethod.edfaly => 'Edfaly',
      PaymentMethod.masrafiPay => 'Masrafi Pay',
      PaymentMethod.mobiCash => 'Mobi Cash',
      PaymentMethod.yusrPay => 'Yusr Pay',
      PaymentMethod.check => 'Check',
      PaymentMethod.crypto => 'Crypto',
      PaymentMethod.other => 'Other',
    };
  }

  static String sourceLabel(
    TransactionSource source, [
    AppLocalizations? l10n,
  ]) {
    if (l10n != null) {
      return switch (source) {
        TransactionSource.manual => l10n.transactionSourceManual,
        TransactionSource.imported => l10n.transactionSourceImported,
        TransactionSource.recurring => l10n.transactionSourceRecurring,
        TransactionSource.aiGenerated => l10n.transactionSourceAiGenerated,
        TransactionSource.cloudSync => l10n.transactionSourceCloudSync,
        TransactionSource.system => l10n.transactionSourceSystem,
      };
    }

    return switch (source) {
      TransactionSource.manual => 'Manual',
      TransactionSource.imported => 'Imported',
      TransactionSource.recurring => 'Recurring',
      TransactionSource.aiGenerated => 'AI generated',
      TransactionSource.cloudSync => 'Cloud sync',
      TransactionSource.system => 'System',
    };
  }

  static IconData iconForType(TransactionType type) {
    return switch (type) {
      TransactionType.expense => Icons.arrow_upward_rounded,
      TransactionType.income => Icons.arrow_downward_rounded,
      TransactionType.transferOut ||
      TransactionType.transferIn => Icons.swap_horiz_rounded,
    };
  }

  static bool isDebit(TransactionType type) {
    return type == TransactionType.expense ||
        type == TransactionType.transferOut;
  }
}
