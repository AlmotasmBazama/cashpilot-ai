import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/enums/transaction_type.dart';
import '../../../transactions/transactions_presentation.dart'
    show TransactionCard;
import '../../../payment_methods/domain/defaults/libyan_payment_method_catalog.dart';
import '../../../payment_methods/domain/entities/payment_method_definition.dart';
import '../../application/providers/accounts_providers.dart';
import '../../domain/entities/account.dart';
import '../support/account_type_labels.dart';
import '../support/account_visuals.dart';
import '../widgets/edit_account_bottom_sheet.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accountState = ref.watch(accountByIdProvider(accountId));
    final transactionsState = ref.watch(
      transactionsByAccountProvider(accountId),
    );

    return Scaffold(
      appBar: CPAppBar(
        title: l10n.accountDetailsTitle,
        actions: [
          IconButton(
            tooltip: l10n.editAccount,
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: l10n.archiveAccount,
            onPressed: () => _archive(context, ref),
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
      body: accountState.when(
        data: (result) {
          switch (result) {
            case AppSuccess<Account?>(:final data):
              if (data == null) {
                return CPEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.accountNotFound,
                  message: l10n.routeNotFoundMessage,
                );
              }

              return transactionsState.when(
                data: (transactionsResult) {
                  switch (transactionsResult) {
                    case AppSuccess<List<Transaction>>(
                      data: final transactions,
                    ):
                      return _AccountDetailsContent(
                        account: data,
                        transactions: transactions,
                      );
                    case AppFailure<List<Transaction>>():
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
              );
            case AppFailure<Account?>():
              return CPErrorView(
                title: l10n.accountsErrorTitle,
                message: l10n.accountsErrorMessage,
              );
          }
        },
        error: (_, _) => CPErrorView(
          title: l10n.accountsErrorTitle,
          message: l10n.accountsErrorMessage,
        ),
        loading: () => const CPLoadingIndicator(),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(accountByIdProvider(accountId).future);
    if (!context.mounted) {
      return;
    }

    switch (result) {
      case AppSuccess<Account?>(:final data):
        if (data == null) {
          return;
        }
        await EditAccountBottomSheet.show(context, data);
        ref.invalidate(accountByIdProvider(accountId));
      case AppFailure<Account?>():
        return;
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(accountByIdProvider(accountId).future);
    if (!context.mounted) {
      return;
    }

    switch (result) {
      case AppSuccess<Account?>(:final data):
        if (data == null) {
          return;
        }
        final updated = await ref.read(updateAccountUseCaseProvider)(
          data.copyWith(isArchived: true, updatedAt: DateTime.now().toUtc()),
        );
        if (!context.mounted) {
          return;
        }
        switch (updated) {
          case AppSuccess<Account>():
            ref
              ..invalidate(accountsProvider)
              ..invalidate(accountByIdProvider(accountId));
            context.go(AppRoutePaths.accounts);
          case AppFailure<Account>(:final failure):
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      case AppFailure<Account?>():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.accountsErrorMessage)));
    }
  }
}

class _AccountDetailsContent extends StatelessWidget {
  const _AccountDetailsContent({
    required this.account,
    required this.transactions,
  });

  final Account account;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final income = _sum(TransactionType.income);
    final expense = _sum(TransactionType.expense);
    final transfer = _sumTransfers();
    final trend = _trend();
    final paymentMethods = account.paymentMethodIds
        .map(LibyanPaymentMethodCatalog.findById)
        .whereType<PaymentMethodDefinition>()
        .toList(growable: false);

    return FinanceScreenBody(
      child: ListView(
        children: [
          CPCard(
            variant: CPCardVariant.elevated,
            backgroundColor: CPColors.brandPanel,
            accentColor: Color(account.color),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(CPRadius.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Icon(
                    AccountVisuals.iconForKey(account.icon),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: CPSpacing.lg),
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: CPSpacing.sm),
                AnimatedSwitcher(
                  duration: CPDurations.normal,
                  child: Text(
                    FinanceFormatters.amountWithCurrency(
                      account.balance,
                      account.currencyCode,
                    ),
                    key: ValueKey(account.balance),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: CPSpacing.md),
                Wrap(
                  spacing: CPSpacing.sm,
                  runSpacing: CPSpacing.sm,
                  children: [
                    FinanceStatusPill(
                      label: account.currencyCode,
                      icon: Icons.payments_outlined,
                    ),
                    FinanceStatusPill(
                      label: AccountTypeLabels.label(l10n, account.type),
                      icon: Icons.account_balance_outlined,
                    ),
                    for (final method in paymentMethods)
                      FinanceStatusPill(
                        label: method.displayName,
                        icon: Icons.payments_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: CPSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 3 : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: CPSpacing.md,
                mainAxisSpacing: CPSpacing.md,
                childAspectRatio: columns == 1 ? 2.8 : 1.6,
                children: [
                  FinanceMetricCard(
                    label: l10n.income,
                    value: FinanceFormatters.amountWithCurrency(
                      income,
                      account.currencyCode,
                    ),
                    icon: Icons.arrow_downward_rounded,
                    accentColor: context.cpColors.income,
                  ),
                  FinanceMetricCard(
                    label: l10n.expense,
                    value: FinanceFormatters.amountWithCurrency(
                      expense,
                      account.currencyCode,
                    ),
                    icon: Icons.arrow_upward_rounded,
                    accentColor: context.cpColors.expense,
                  ),
                  FinanceMetricCard(
                    label: l10n.transferHistory,
                    value: FinanceFormatters.amountWithCurrency(
                      transfer,
                      account.currencyCode,
                    ),
                    icon: Icons.swap_horiz_rounded,
                    accentColor: context.cpColors.transfer,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: CPSpacing.xl),
          FinanceSection(
            title: l10n.statistics,
            subtitle: l10n.accountStatisticsSubtitle,
            child: CPCard(child: FinanceMiniBars(values: trend)),
          ),
          const SizedBox(height: CPSpacing.xl),
          FinanceSection(
            title: l10n.transactionsTitle,
            action: CPButton(
              label: l10n.viewAll,
              variant: CPButtonVariant.ghost,
              onPressed: () => context.go(AppRoutePaths.transactions),
            ),
            child: transactions.isEmpty
                ? CPEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: l10n.emptyTransactionsTitle,
                    message: l10n.emptyTransactionsMessage,
                  )
                : Column(
                    children: [
                      for (final transaction
                          in transactions.take(8).toList(growable: false)) ...[
                        TransactionCard(
                          transaction: transaction,
                          accountName: account.name,
                          onTap: () => context.pushNamed(
                            AppRouteNames.transactionDetails,
                            pathParameters: {'transactionId': transaction.id},
                          ),
                        ),
                        const SizedBox(height: CPSpacing.md),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Decimal _sum(TransactionType type) {
    return transactions
        .where((transaction) => transaction.type == type)
        .fold<Decimal>(
          Decimal.zero,
          (total, transaction) => total + transaction.amount.amount,
        );
  }

  Decimal _sumTransfers() {
    return transactions
        .where(
          (transaction) =>
              transaction.type == TransactionType.transferIn ||
              transaction.type == TransactionType.transferOut,
        )
        .fold<Decimal>(
          Decimal.zero,
          (total, transaction) => total + transaction.amount.amount,
        );
  }

  List<Decimal> _trend() {
    final now = DateTime.now().toUtc();
    return [
      for (var index = 0; index < 6; index++)
        transactions
            .where((transaction) {
              final date = transaction.transactionDate.toUtc();
              final month = DateTime.utc(now.year, now.month - (5 - index));
              return date.year == month.year && date.month == month.month;
            })
            .fold<Decimal>(
              Decimal.zero,
              (total, transaction) => total + transaction.amount.amount,
            ),
    ];
  }
}
