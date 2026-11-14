import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/transactions_presentation.dart'
    show TransactionCard;
import '../../application/providers/payees_providers.dart';
import '../../domain/entities/payee.dart';
import '../support/payee_type_labels.dart';
import '../widgets/payee_form_sheet.dart';

class PayeeDetailsScreen extends ConsumerWidget {
  const PayeeDetailsScreen({required this.payeeId, super.key});

  final String payeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final payeeState = ref.watch(payeeByIdProvider(payeeId));
    final transactionsState = ref.watch(transactionsByPayeeProvider(payeeId));
    final accountsState = ref.watch(accountsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final payee = switch (payeeState.value) {
      AppSuccess<Payee?>(:final data) => data,
      _ => null,
    };
    return Scaffold(
      appBar: CPAppBar(
        title: l10n.payeeDetails,
        actions: [
          if (payee != null)
            IconButton(
              tooltip: l10n.editPayee,
              onPressed: () async {
                await PayeeFormSheet.show(context, payee: payee);
                ref.invalidate(payeeByIdProvider(payeeId));
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (payee != null)
            IconButton(
              tooltip: payee.isArchived ? l10n.restorePayee : l10n.archivePayee,
              onPressed: () => _toggleArchive(context, ref, payee),
              icon: Icon(
                payee.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
            ),
        ],
      ),
      body: payeeState.when(
        data: (result) => switch (result) {
          AppSuccess<Payee?>(data: final data) when data != null =>
            _PayeeDetailsContent(
              payee: data,
              transactionsState: transactionsState,
              accountsState: accountsState,
              categoriesState: categoriesState,
            ),
          AppSuccess<Payee?>() => CPEmptyState(
            icon: Icons.person_off_outlined,
            title: l10n.payeeNotFound,
            message: l10n.routeNotFoundMessage,
          ),
          AppFailure<Payee?>() => CPErrorView(
            title: l10n.payeesErrorTitle,
            message: l10n.transactionsErrorMessage,
          ),
        },
        error: (_, _) => CPErrorView(
          title: l10n.payeesErrorTitle,
          message: l10n.transactionsErrorMessage,
        ),
        loading: () => const CPLoadingIndicator(),
      ),
    );
  }

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    Payee payee,
  ) async {
    final result = payee.isArchived
        ? await ref.read(restorePayeeUseCaseProvider)(payee.id)
        : await ref.read(archivePayeeUseCaseProvider)(payee.id);
    if (!context.mounted) {
      return;
    }
    switch (result) {
      case AppSuccess<Payee>():
        ref.invalidate(payeeByIdProvider(payee.id));
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              payee.isArchived
                  ? l10n.payeeRestoredMessage
                  : l10n.payeeArchivedMessage,
            ),
          ),
        );
      case AppFailure<Payee>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _PayeeDetailsContent extends StatelessWidget {
  const _PayeeDetailsContent({
    required this.payee,
    required this.transactionsState,
    required this.accountsState,
    required this.categoriesState,
  });

  final Payee payee;
  final AsyncValue<AppResult<List<Transaction>>> transactionsState;
  final AsyncValue<AppResult<List<Account>>> accountsState;
  final AsyncValue<AppResult<List<Category>>> categoriesState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transactions = switch (transactionsState.value) {
      AppSuccess<List<Transaction>>(:final data) => data,
      _ => const <Transaction>[],
    };
    final accounts = switch (accountsState.value) {
      AppSuccess<List<Account>>(:final data) => data,
      _ => const <Account>[],
    };
    final categories = switch (categoriesState.value) {
      AppSuccess<List<Category>>(:final data) => data,
      _ => const <Category>[],
    };
    final accountName = accounts
        .where((account) => account.id == payee.defaultAccountId)
        .map((account) => account.name)
        .firstOrNull;
    final categoryName = categories
        .where((category) => category.id == payee.defaultCategoryId)
        .map((category) => category.name)
        .firstOrNull;
    return FinanceScreenBody(
      child: ListView(
        children: [
          CPCard(
            variant: CPCardVariant.elevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(payee.name.characters.first.toUpperCase()),
                ),
                const SizedBox(height: CPSpacing.md),
                Text(
                  payee.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: CPSpacing.sm),
                Wrap(
                  spacing: CPSpacing.sm,
                  runSpacing: CPSpacing.sm,
                  children: [
                    FinanceStatusPill(
                      label: PayeeTypeLabels.label(l10n, payee.type),
                    ),
                    if (payee.isArchived)
                      FinanceStatusPill(label: l10n.archivedPayee),
                  ],
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
                  title: l10n.payeeAliases,
                  subtitle: payee.aliases.isEmpty
                      ? l10n.zero
                      : payee.aliases.join(' · '),
                ),
                CPListTile(
                  title: l10n.payeeDefaultCategory,
                  subtitle: categoryName ?? l10n.noDefaultSelection,
                ),
                CPListTile(
                  title: l10n.payeeDefaultAccount,
                  subtitle: accountName ?? l10n.noDefaultSelection,
                ),
                CPListTile(
                  title: l10n.lastUsed,
                  subtitle: payee.lastUsedAt == null
                      ? l10n.neverUsed
                      : FinanceFormatters.fullDate(
                          payee.lastUsedAt!,
                          Localizations.localeOf(context).toString(),
                        ),
                ),
                if (payee.notes != null)
                  CPListTile(title: l10n.payeeNotes, subtitle: payee.notes),
              ],
            ),
          ),
          const SizedBox(height: CPSpacing.xl),
          CPSectionTitle(
            title: l10n.relatedTransactions,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: CPSpacing.md),
          if (transactions.isEmpty)
            CPEmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.emptyTransactionsTitle,
              message: l10n.emptyTransactionsMessage,
            )
          else
            for (final transaction in transactions) ...[
              TransactionCard(
                transaction: transaction,
                onTap: () => context.pushNamed(
                  AppRouteNames.transactionDetails,
                  pathParameters: {'transactionId': transaction.id},
                ),
              ),
              const SizedBox(height: CPSpacing.md),
            ],
        ],
      ),
    );
  }
}
