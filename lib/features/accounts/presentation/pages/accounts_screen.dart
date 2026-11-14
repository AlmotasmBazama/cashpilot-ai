import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../application/providers/accounts_providers.dart';
import '../../domain/entities/account.dart';
import '../widgets/account_card.dart';
import '../widgets/accounts_empty_state.dart';
import '../widgets/accounts_error_state.dart';
import '../widgets/accounts_loading_state.dart';
import '../widgets/add_account_bottom_sheet.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/edit_account_bottom_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accountsState = ref.watch(accountsProvider);

    return Scaffold(
      appBar: CPAppBar(
        title: l10n.accountsScreenTitle,
        subtitle: l10n.accountsScreenSubtitle,
      ),
      floatingActionButton: CPFloatingActionButton(
        tooltip: l10n.addAccount,
        onPressed: () => _showAddAccountSheet(context),
      ),
      body: accountsState.when(
        data: (result) {
          return result.when(
            success: (accounts) => _AccountsContent(accounts: accounts),
            failure: (_) => AccountsErrorState(
              onRetry: () => ref.invalidate(accountsProvider),
            ),
          );
        },
        error: (_, _) =>
            AccountsErrorState(onRetry: () => ref.invalidate(accountsProvider)),
        loading: () => const AccountsLoadingState(),
      ),
    );
  }

  Future<void> _showAddAccountSheet(BuildContext context) async {
    final didCreate = await AddAccountBottomSheet.show(context);
    if (context.mounted && didCreate == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).accountCreatedMessage),
        ),
      );
    }
  }
}

class _AccountsContent extends ConsumerWidget {
  const _AccountsContent({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (accounts.isEmpty) {
      return AccountsEmptyState(
        onAddPressed: () {
          unawaited(AddAccountBottomSheet.show(context));
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(accountsProvider);
        await ref.read(accountsProvider.future);
      },
      child: CPAdaptivePage(
        child: Column(
          children: [
            _AccountsOverview(accounts: accounts),
            const SizedBox(height: CPSpacing.lg),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = switch (cpWindowSizeClassForWidth(
                    constraints.maxWidth,
                  )) {
                    CPWindowSizeClass.compact => 1,
                    CPWindowSizeClass.medium => 2,
                    CPWindowSizeClass.expanded => 3,
                  };

                  if (columns == 1) {
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: CPSpacing.md),
                      itemBuilder: (context, index) =>
                          _DismissibleAccountCard(account: accounts[index]),
                    );
                  }

                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: accounts.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: CPSpacing.lg,
                      crossAxisSpacing: CPSpacing.lg,
                      childAspectRatio: columns == 2 ? 1.44 : 1.34,
                    ),
                    itemBuilder: (context, index) =>
                        _DismissibleAccountCard(account: accounts[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsOverview extends StatelessWidget {
  const _AccountsOverview({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeCount = accounts.where((account) => !account.isArchived).length;
    final archivedCount = accounts.length - activeCount;
    final currencyCount = accounts
        .map((account) => account.currencyCode.toUpperCase())
        .toSet()
        .length;
    final items = <_PortfolioStatData>[
      _PortfolioStatData(
        label: l10n.activeAccountsLabel,
        value: activeCount.toString(),
        icon: Icons.account_balance_wallet_outlined,
        color: context.cpColors.success,
      ),
      _PortfolioStatData(
        label: l10n.archivedAccountsLabel,
        value: archivedCount.toString(),
        icon: Icons.inventory_2_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      _PortfolioStatData(
        label: l10n.trackedCurrenciesLabel,
        value: currencyCount.toString(),
        icon: Icons.currency_exchange_rounded,
        color: context.cpColors.transfer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return SizedBox(
            height: 92,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const SizedBox(width: CPSpacing.xs),
                  Expanded(child: _PortfolioStat(data: items[index])),
                ],
              ],
            ),
          );
        }

        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(width: CPSpacing.md),
              Expanded(child: _PortfolioStat(data: items[index])),
            ],
          ],
        );
      },
    );
  }
}

class _PortfolioStatData {
  const _PortfolioStatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _PortfolioStat extends StatelessWidget {
  const _PortfolioStat({required this.data});

  final _PortfolioStatData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(CPRadius.lg),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 128;
          final details = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                data.label,
                maxLines: compact ? 2 : 1,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );

          if (compact) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(data.icon, color: data.color, size: 20),
                const SizedBox(height: CPSpacing.xxs),
                details,
              ],
            );
          }

          return Row(
            children: [
              Icon(data.icon, color: data.color, size: 22),
              const SizedBox(width: CPSpacing.sm),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _DismissibleAccountCard extends ConsumerWidget {
  const _DismissibleAccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Dismissible(
      key: ValueKey(account.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _archive(context, ref),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: CPSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(CPRadius.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.archive_rounded),
            const SizedBox(height: CPSpacing.xs),
            Text(l10n.archiveAccount),
          ],
        ),
      ),
      child: AccountCard(
        account: account,
        onTap: () => context.pushNamed(
          AppRouteNames.accountDetails,
          pathParameters: {'accountId': account.id},
        ),
        onEdit: () => _edit(context),
        onDelete: () => _delete(context),
      ),
    );
  }

  Future<bool> _archive(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(updateAccountUseCaseProvider)(
      account.copyWith(isArchived: true, updatedAt: DateTime.now().toUtc()),
    );

    if (!context.mounted) {
      return false;
    }

    switch (result) {
      case AppSuccess<Account>():
        ref.invalidate(accountsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).accountArchivedMessage),
          ),
        );
        return true;
      case AppFailure<Account>(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
        return false;
    }
  }

  Future<void> _edit(BuildContext context) async {
    final didUpdate = await EditAccountBottomSheet.show(context, account);
    if (context.mounted && didUpdate == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).accountUpdatedMessage),
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final didDelete = await DeleteAccountDialog.show(context, account);
    if (context.mounted && didDelete == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).accountDeletedMessage),
        ),
      );
    }
  }
}
