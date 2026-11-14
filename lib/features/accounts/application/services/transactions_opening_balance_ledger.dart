import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/domain/usecases/get_default_categories.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../../../transactions/domain/enums/transaction_source.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/domain/usecases/create_transaction.dart';
import '../../domain/failures/account_failure_codes.dart';
import '../../domain/repositories/opening_balance_ledger.dart';

final class TransactionsOpeningBalanceLedger implements OpeningBalanceLedger {
  const TransactionsOpeningBalanceLedger({
    required CreateTransaction createTransaction,
    required GetDefaultCategories getDefaultCategories,
  }) : _createTransaction = createTransaction,
       _getDefaultCategories = getDefaultCategories;

  static const entryNote = 'Opening balance';
  static const _otherIncomeCategoryId = '01900000-0000-7000-8000-000000000028';
  static const _operationNamePrefix =
      'https://cashpilot.local/ledger/opening-balance/';

  final CreateTransaction _createTransaction;
  final GetDefaultCategories _getDefaultCategories;

  static String transactionIdForAccount(String accountId) {
    return const Uuid().v5(
      Namespace.url.value,
      '$_operationNamePrefix$accountId',
    );
  }

  @override
  Future<void> postOpeningBalance({
    required String accountId,
    required Decimal amount,
    required String currencyCode,
    required DateTime occurredAt,
  }) async {
    if (amount <= Decimal.zero) {
      throw const AppException.validation(
        message: 'Opening balance entries must be greater than zero.',
        code: AccountFailureCodes.negativeOpeningBalance,
      );
    }

    final categoriesResult = await _getDefaultCategories(
      type: CategoryType.income,
    );
    final categories = switch (categoriesResult) {
      AppSuccess<List<Category>>(:final data) => data,
      AppFailure<List<Category>>(:final failure) =>
        throw AppException.validation(
          message: failure.message,
          code: failure.code ?? AccountFailureCodes.openingBalanceEntryFailed,
        ),
    };
    final categoryExists = categories.any(
      (category) => category.id == _otherIncomeCategoryId,
    );
    if (!categoryExists) {
      throw const AppException.validation(
        message: 'Opening balance ledger category is unavailable.',
        code: AccountFailureCodes.openingBalanceEntryFailed,
      );
    }

    final result = await _createTransaction(
      Transaction.create(
        id: transactionIdForAccount(accountId),
        accountId: accountId,
        categoryId: _otherIncomeCategoryId,
        amount: Money(amount: amount, currencyCode: currencyCode),
        type: TransactionType.income,
        paymentMethod: PaymentMethod.other,
        source: TransactionSource.system,
        status: TransactionStatus.posted,
        note: entryNote,
        transactionDate: occurredAt,
        createdAt: occurredAt,
        updatedAt: occurredAt,
      ),
    );
    switch (result) {
      case AppSuccess<Transaction>():
        return;
      case AppFailure<Transaction>(:final failure):
        throw AppException.validation(
          message: failure.message,
          code: failure.code ?? AccountFailureCodes.openingBalanceEntryFailed,
        );
    }
  }
}
