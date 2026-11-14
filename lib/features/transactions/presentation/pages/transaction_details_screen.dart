import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../categories/domain/entities/category.dart';
import '../../../payees/application/providers/payees_providers.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../application/providers/transactions_providers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/failures/transaction_failure_codes.dart';
import '../support/transaction_ui_formatters.dart';
import '../widgets/transaction_form_sheet.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final transactionState = ref.watch(transactionByIdProvider(transactionId));
    final accountsState = ref.watch(accountsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final transactionResult = transactionState.value;
    final transaction = transactionResult is AppSuccess<Transaction?>
        ? transactionResult.data
        : null;
    final payeeId = transaction?.payeeId;
    final payeeState = payeeId == null
        ? null
        : ref.watch(payeeByIdProvider(payeeId));
    final canCancelTransfer =
        transaction?.isTransfer == true &&
        (transaction?.status == TransactionStatus.pending ||
            transaction?.status == TransactionStatus.posted);
    final canEdit =
        transaction != null &&
        !transaction.isTransfer &&
        (transaction.status == TransactionStatus.pending ||
            transaction.status == TransactionStatus.posted);
    final canDelete =
        transaction != null &&
        (!transaction.isTransfer ||
            transaction.status == TransactionStatus.pending);

    return Scaffold(
      appBar: CPAppBar(
        title: l10n.transactionDetails,
        actions: [
          if (canEdit)
            IconButton(
              tooltip: l10n.editTransaction,
              onPressed: () => _edit(context, ref, transaction),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canCancelTransfer)
            IconButton(
              tooltip: l10n.cancelTransfer,
              onPressed: () => _confirmCancel(context, ref),
              icon: const Icon(Icons.block_rounded),
            ),
          if (canDelete)
            IconButton(
              tooltip: l10n.delete,
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: transactionState.when(
        data: (result) {
          switch (result) {
            case AppSuccess<Transaction?>(:final data):
              if (data == null) {
                return CPEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.transactionNotFound,
                  message: l10n.routeNotFoundMessage,
                );
              }

              return _DetailsContent(
                transaction: data,
                accountsState: accountsState,
                categoriesState: categoriesState,
                payeeState: payeeState,
              );
            case AppFailure<Transaction?>():
              return CPErrorView(
                title: l10n.transactionsErrorTitle,
                message: l10n.transactionsErrorMessage,
              );
          }
        },
        error: (_, _) => CPErrorView(
          title: l10n.transactionsErrorTitle,
          message: l10n.transactionsErrorMessage,
        ),
        loading: () => const CPLoadingIndicator(),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
    final updated = await TransactionFormSheet.show(
      context,
      transaction.type,
      existingTransaction: transaction,
    );
    if (updated != true || !context.mounted) {
      return;
    }
    ref
      ..invalidate(transactionByIdProvider(transaction.id))
      ..invalidate(transactionsProvider)
      ..invalidate(accountsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).transactionUpdatedMessage),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTransactionTitle),
        content: Text(l10n.deleteTransactionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref.read(deleteTransactionUseCaseProvider)(
      transactionId,
    );

    if (!context.mounted) {
      return;
    }

    switch (result) {
      case AppSuccess<void>():
        ref
          ..invalidate(transactionsProvider)
          ..invalidate(accountsProvider);
        context.pop();
      case AppFailure<void>(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_localizedFailure(failure, l10n))),
        );
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelTransfer),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref.read(updateTransactionStatusUseCaseProvider)(
      transactionId,
      TransactionStatus.cancelled,
    );

    if (!context.mounted) {
      return;
    }

    switch (result) {
      case AppSuccess<List<Transaction>>():
        ref
          ..invalidate(transactionByIdProvider(transactionId))
          ..invalidate(transactionsProvider)
          ..invalidate(accountsProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.transferCancelledMessage)));
      case AppFailure<List<Transaction>>():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.transferFailedMessage)));
    }
  }

  String _localizedFailure(Failure failure, AppLocalizations l10n) {
    return switch (failure.code) {
      TransactionFailureCodes.transferDirectEditNotAllowed =>
        l10n.transferCannotBeEditedMessage,
      TransactionFailureCodes.transferHardDeleteNotAllowed =>
        l10n.postedTransferCannotBeDeletedMessage,
      TransactionFailureCodes.transferGroupMissing =>
        l10n.transferCannotBeDeletedMessage,
      TransactionFailureCodes.transferGroupMalformed =>
        l10n.invalidTransferStateMessage,
      _ => failure.message,
    };
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({
    required this.transaction,
    required this.accountsState,
    required this.categoriesState,
    required this.payeeState,
  });

  final Transaction transaction;
  final AsyncValue<AppResult<List<Account>>> accountsState;
  final AsyncValue<AppResult<List<Category>>> categoriesState;
  final AsyncValue<AppResult<Payee?>>? payeeState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountName = _accountName();
    final categoryName = _categoryName(l10n);
    final payeeName = _payeeName();
    final color = TransactionUiFormatters.isDebit(transaction.type)
        ? context.cpColors.expense
        : context.cpColors.income;

    return FinanceScreenBody(
      child: ListView(
        children: [
          CPCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'transaction-icon-${transaction.id}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      TransactionUiFormatters.iconForType(transaction.type),
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: CPSpacing.lg),
                Text(
                  FinanceFormatters.money(transaction.amount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: CPSpacing.sm),
                FinanceStatusPill(
                  label: TransactionUiFormatters.statusLabel(
                    transaction.status,
                    l10n,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CPSpacing.lg),
          CPCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                CPListTile(
                  title: l10n.accountName,
                  trailing: Text(accountName ?? transaction.accountId),
                ),
                CPListTile(
                  title: l10n.category,
                  trailing: Text(categoryName ?? transaction.categoryId),
                ),
                if (transaction.payeeId case final payeeId?)
                  CPListTile(
                    title: l10n.selectPayee,
                    trailing: Text(payeeName ?? payeeId),
                  ),
                CPListTile(
                  title: l10n.transactionDate,
                  trailing: Text(
                    FinanceFormatters.fullDate(
                      transaction.transactionDate,
                      Localizations.localeOf(context).toString(),
                    ),
                  ),
                ),
                CPListTile(
                  title: l10n.paymentMethod,
                  trailing: Text(
                    TransactionUiFormatters.paymentMethodLabel(
                      transaction.paymentMethod,
                      l10n,
                    ),
                  ),
                ),
                CPListTile(
                  title: l10n.source,
                  trailing: Text(
                    TransactionUiFormatters.sourceLabel(
                      transaction.source,
                      l10n,
                    ),
                  ),
                ),
                if (transaction.transferGroupId case final groupId?)
                  CPListTile(title: l10n.transferReference, subtitle: groupId),
                if (transaction.note != null)
                  CPListTile(title: l10n.note, subtitle: transaction.note),
                if (transaction.location != null)
                  CPListTile(
                    title: l10n.location,
                    subtitle: transaction.location,
                  ),
              ],
            ),
          ),
          const SizedBox(height: CPSpacing.lg),
          FinanceInfoCard(
            title: l10n.aiReview,
            message: transaction.needsReview
                ? l10n.aiReviewNeeded
                : l10n.aiReviewNotNeeded,
            icon: Icons.auto_awesome_outlined,
            color: context.cpColors.insight,
          ),
        ],
      ),
    );
  }

  String? _accountName() {
    final result = accountsState.value;
    if (result is! AppSuccess<List<Account>>) {
      return null;
    }

    for (final account in result.data) {
      if (account.id == transaction.accountId) {
        return account.name;
      }
    }
    return null;
  }

  String? _categoryName(AppLocalizations l10n) {
    final result = categoriesState.value;
    if (result is! AppSuccess<List<Category>>) {
      return null;
    }

    for (final category in result.data) {
      if (category.id == transaction.categoryId) {
        return CategoryLocalization.name(l10n, category);
      }
    }
    return null;
  }

  String? _payeeName() {
    final result = payeeState?.value;
    return switch (result) {
      AppSuccess<Payee?>(:final data) => data?.name,
      _ => null,
    };
  }
}
