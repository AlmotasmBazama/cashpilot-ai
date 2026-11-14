import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../categories/domain/entities/category.dart';
import '../../../receipts/application/receipt_providers.dart';
import '../../application/providers/transactions_providers.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_history_page.dart';
import '../../domain/enums/transaction_type.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_form_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 300);
  static const _pageSize = 50;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _appliedSearchQuery = '';
  int _loadedLimit = _pageSize;
  _TransactionFilter _filter = _TransactionFilter.all;
  _TransactionSort _sort = _TransactionSort.newest;
  TransactionHistoryPage? _retainedPage;
  _TransactionHistoryScope? _retainedScope;
  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final historyRequest = _historyRequest;
    final transactionsState = ref.watch(
      transactionHistoryProvider(historyRequest),
    );
    final historyView = _resolveHistoryView(transactionsState);
    final historyPage = historyView.page;
    final accountsState = ref.watch(accountsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final receiptScanningEnabled = ref
        .watch(receiptFeatureConfigProvider)
        .enabled;

    return Scaffold(
      appBar: CPAppBar(
        title: l10n.transactionsTitle,
        subtitle: l10n.transactionsSubtitle,
        actions: [
          if (receiptScanningEnabled)
            IconButton(
              key: const Key('transactions_scan_receipt_button'),
              tooltip: l10n.scanReceipt,
              onPressed: () => context.push(AppRoutePaths.receiptCapture),
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          IconButton(
            tooltip: l10n.addIncome,
            onPressed: () => _openForm(TransactionType.income),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: l10n.transfer,
            onPressed: () => context.go(AppRoutePaths.transfer),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      floatingActionButton: CPFloatingActionButton(
        variant: CPFloatingActionButtonVariant.extended,
        icon: Icons.remove_circle_outline_rounded,
        label: l10n.addExpense,
        tooltip: l10n.addExpense,
        onPressed: () => _openForm(TransactionType.expense),
      ),
      body: historyPage == null
          ? historyView.isInitialLoading
                ? const _TransactionsLoading()
                : CPErrorView(
                    title: l10n.transactionsErrorTitle,
                    message: l10n.transactionsErrorMessage,
                    action: CPButton(
                      label: l10n.retry,
                      onPressed: () => unawaited(_refresh()),
                    ),
                  )
          : accountsState.when(
              data: (accountsResult) {
                return categoriesState.when(
                  data: (categoriesResult) {
                    return switch ((accountsResult, categoriesResult)) {
                      (
                        AppSuccess<List<Account>>(data: final accounts),
                        AppSuccess<List<Category>>(data: final categories),
                      ) =>
                        _TransactionsContent(
                          transactions: historyPage.transactions,
                          totalCount: historyPage.totalCount,
                          hasMore: historyPage.hasMore,
                          isLoadingMore: historyView.isLoadingMore,
                          loadMoreFailed: historyView.loadMoreFailed,
                          accounts: accounts,
                          categories: categories,
                          searchController: _searchController,
                          filter: _filter,
                          sort: _sort,
                          onFilterChanged: _onFilterChanged,
                          onSortChanged: _onSortChanged,
                          onSearchChanged: _onSearchChanged,
                          onLoadMore: _loadMore,
                          onRetryLoadMore: _retryLoadMore,
                          onRefresh: _refresh,
                        ),
                      _ => CPErrorView(
                        title: l10n.transactionsErrorTitle,
                        message: l10n.transactionsErrorMessage,
                        action: CPButton(
                          label: l10n.retry,
                          onPressed: () => unawaited(_refresh()),
                        ),
                      ),
                    };
                  },
                  error: (_, _) => CPErrorView(
                    title: l10n.transactionsErrorTitle,
                    message: l10n.transactionsErrorMessage,
                    action: CPButton(
                      label: l10n.retry,
                      onPressed: () => unawaited(_refresh()),
                    ),
                  ),
                  loading: () => const _TransactionsLoading(),
                );
              },
              error: (_, _) => CPErrorView(
                title: l10n.transactionsErrorTitle,
                message: l10n.transactionsErrorMessage,
                action: CPButton(
                  label: l10n.retry,
                  onPressed: () => unawaited(_refresh()),
                ),
              ),
              loading: () => const _TransactionsLoading(),
            ),
    );
  }

  _TransactionHistoryView _resolveHistoryView(
    AsyncValue<AppResult<TransactionHistoryPage>> state,
  ) {
    final scope = _historyScope;
    final successfulPage = switch (state) {
      AsyncData(value: AppSuccess<TransactionHistoryPage>(data: final page)) =>
        page,
      _ => null,
    };
    if (successfulPage != null) {
      _retainedScope = scope;
      _retainedPage = successfulPage;
      _isLoadingMore = false;
      _loadMoreFailed = false;
      return (
        page: successfulPage,
        isInitialLoading: false,
        isLoadingMore: false,
        loadMoreFailed: false,
      );
    }

    final retainedPage = _retainedScope == scope ? _retainedPage : null;
    if (retainedPage != null && (_isLoadingMore || _loadMoreFailed)) {
      if (state.isLoading) {
        return (
          page: retainedPage,
          isInitialLoading: false,
          isLoadingMore: true,
          loadMoreFailed: false,
        );
      }
      _isLoadingMore = false;
      _loadMoreFailed = true;
      return (
        page: retainedPage,
        isInitialLoading: false,
        isLoadingMore: false,
        loadMoreFailed: true,
      );
    }

    return (
      page: null,
      isInitialLoading: state.isLoading,
      isLoadingMore: false,
      loadMoreFailed: false,
    );
  }

  Future<void> _openForm(TransactionType type) async {
    final created = await TransactionFormSheet.show(context, type);
    if (mounted && created == true) {
      ref.invalidate(transactionHistoryProvider(_historyRequest));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).transactionCreatedMessage),
        ),
      );
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final normalized = value.trim().toLowerCase();
    if (normalized == _appliedSearchQuery) {
      return;
    }
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (mounted) {
        setState(() {
          _appliedSearchQuery = normalized;
          _resetPagination();
        });
      }
    });
  }

  void _onFilterChanged(_TransactionFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _resetPagination();
    });
  }

  void _onSortChanged(_TransactionSort sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _resetPagination();
    });
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreFailed = false;
      _loadedLimit += _pageSize;
    });
  }

  void _retryLoadMore() {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreFailed = false;
    });
    ref.invalidate(transactionHistoryProvider(_historyRequest));
  }

  Future<void> _refresh() async {
    if (_loadedLimit != _pageSize) {
      setState(_resetPagination);
    }
    final historyRequest = _historyRequest;
    ref
      ..invalidate(transactionHistoryProvider(historyRequest))
      ..invalidate(accountsProvider)
      ..invalidate(categoriesProvider);
    await Future.wait([
      ref.read(transactionHistoryProvider(historyRequest).future),
      ref.read(accountsProvider.future),
      ref.read(categoriesProvider.future),
    ]);
  }

  TransactionHistoryRequest get _historyRequest => (
    query: _appliedSearchQuery,
    filter: switch (_filter) {
      _TransactionFilter.all => TransactionHistoryFilter.all,
      _TransactionFilter.income => TransactionHistoryFilter.income,
      _TransactionFilter.expense => TransactionHistoryFilter.expense,
      _TransactionFilter.transfer => TransactionHistoryFilter.transfer,
      _TransactionFilter.pending => TransactionHistoryFilter.pending,
    },
    sort: switch (_sort) {
      _TransactionSort.newest => TransactionHistorySort.newest,
      _TransactionSort.oldest => TransactionHistorySort.oldest,
      _TransactionSort.amountHigh => TransactionHistorySort.amountHigh,
    },
    limit: _loadedLimit,
  );

  _TransactionHistoryScope get _historyScope => (
    query: _historyRequest.query,
    filter: _historyRequest.filter,
    sort: _historyRequest.sort,
  );

  void _resetPagination() {
    _loadedLimit = _pageSize;
    _retainedPage = null;
    _retainedScope = null;
    _isLoadingMore = false;
    _loadMoreFailed = false;
  }
}

typedef _TransactionHistoryScope = ({
  String query,
  TransactionHistoryFilter filter,
  TransactionHistorySort sort,
});

typedef _TransactionHistoryView = ({
  TransactionHistoryPage? page,
  bool isInitialLoading,
  bool isLoadingMore,
  bool loadMoreFailed,
});

class _TransactionsContent extends StatelessWidget {
  const _TransactionsContent({
    required this.transactions,
    required this.totalCount,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreFailed,
    required this.accounts,
    required this.categories,
    required this.searchController,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onSearchChanged,
    required this.onLoadMore,
    required this.onRetryLoadMore,
    required this.onRefresh,
  });

  final List<Transaction> transactions;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;
  final List<Account> accounts;
  final List<Category> categories;
  final TextEditingController searchController;
  final _TransactionFilter filter;
  final _TransactionSort sort;
  final ValueChanged<_TransactionFilter> onFilterChanged;
  final ValueChanged<_TransactionSort> onSortChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryLoadMore;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountById = {for (final account in accounts) account.id: account};
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final entries = _entriesFor(context, transactions);
    final extraEntryCount = hasMore || isLoadingMore || loadMoreFailed ? 1 : 0;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FinanceScreenBody(
        child: ListView.builder(
          key: const Key('transactions_lazy_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount:
              1 + (transactions.isEmpty ? 1 : entries.length + extraEntryCount),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _TransactionsListHeader(
                searchController: searchController,
                filter: filter,
                sort: sort,
                loadedCount: transactions.length,
                totalCount: totalCount,
                onFilterChanged: onFilterChanged,
                onSortChanged: onSortChanged,
                onSearchChanged: onSearchChanged,
              );
            }
            if (transactions.isEmpty) {
              return CPEmptyState(
                icon: Icons.receipt_long_outlined,
                title: l10n.emptyTransactionsTitle,
                message: l10n.emptyTransactionsMessage,
              );
            }
            final entryIndex = index - 1;
            if (entryIndex == entries.length) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: CPSpacing.sm,
                  bottom: CPSpacing.bottomNavigationClearance,
                ),
                child: loadMoreFailed
                    ? Column(
                        key: const Key('transactions_load_more_error'),
                        children: [
                          Text(
                            l10n.transactionsErrorMessage,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: CPSpacing.sm),
                          CPButton(
                            key: const Key(
                              'transactions_load_more_retry_button',
                            ),
                            label: l10n.retry,
                            onPressed: onRetryLoadMore,
                            variant: CPButtonVariant.outline,
                            icon: Icons.refresh_rounded,
                            fullWidth: true,
                          ),
                        ],
                      )
                    : CPButton(
                        key: const Key('transactions_load_more_button'),
                        label: l10n.loadMoreTransactions,
                        onPressed: onLoadMore,
                        isLoading: isLoadingMore,
                        variant: CPButtonVariant.outline,
                        icon: Icons.expand_more_rounded,
                        fullWidth: true,
                      ),
              );
            }
            return switch (entries[entryIndex]) {
              _TransactionDateEntry(:final label) => Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: CPSpacing.sm,
                  bottom: CPSpacing.sm,
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TransactionItemEntry(:final transaction) => Padding(
                padding: const EdgeInsetsDirectional.only(bottom: CPSpacing.md),
                child: TransactionCard(
                  key: ValueKey('transaction-${transaction.id}'),
                  transaction: transaction,
                  accountName: accountById[transaction.accountId]?.name,
                  categoryName: categoryById[transaction.categoryId] == null
                      ? null
                      : CategoryLocalization.name(
                          l10n,
                          categoryById[transaction.categoryId]!,
                        ),
                  onTap: () => context.pushNamed(
                    AppRouteNames.transactionDetails,
                    pathParameters: {'transactionId': transaction.id},
                  ),
                ),
              ),
            };
          },
        ),
      ),
    );
  }

  List<_TransactionListEntry> _entriesFor(
    BuildContext context,
    List<Transaction> transactions,
  ) {
    final entries = <_TransactionListEntry>[];
    String? previousLabel;
    for (final transaction in transactions) {
      final label = MaterialLocalizations.of(
        context,
      ).formatFullDate(transaction.transactionDate.toLocal());
      if (label != previousLabel) {
        entries.add(_TransactionDateEntry(label));
        previousLabel = label;
      }
      entries.add(_TransactionItemEntry(transaction));
    }
    return entries;
  }
}

class _TransactionsListHeader extends StatelessWidget {
  const _TransactionsListHeader({
    required this.searchController,
    required this.filter,
    required this.sort,
    required this.loadedCount,
    required this.totalCount,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final _TransactionFilter filter;
  final _TransactionSort sort;
  final int loadedCount;
  final int totalCount;
  final ValueChanged<_TransactionFilter> onFilterChanged;
  final ValueChanged<_TransactionSort> onSortChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CPTextField(
          controller: searchController,
          labelText: l10n.searchTransactions,
          prefix: const Icon(Icons.search_rounded),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: CPSpacing.md),
        Wrap(
          spacing: CPSpacing.xxs,
          runSpacing: CPSpacing.xxs,
          children: [
            for (final value in _TransactionFilter.values)
              ChoiceChip(
                label: Text(_filterLabel(l10n, value)),
                selected: filter == value,
                onSelected: (_) => onFilterChanged(value),
              ),
            PopupMenuButton<_TransactionSort>(
              tooltip: l10n.sort,
              onSelected: onSortChanged,
              itemBuilder: (context) => [
                for (final value in _TransactionSort.values)
                  PopupMenuItem(
                    value: value,
                    child: Text(_sortLabel(l10n, value)),
                  ),
              ],
              child: FinanceStatusPill(
                label: _sortLabel(l10n, sort),
                icon: Icons.sort_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: CPSpacing.lg),
        Row(
          children: [
            Text(
              l10n.resultsLabel,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            FinanceStatusPill(
              label: l10n.transactionsLoadedCount(loadedCount, totalCount),
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: CPSpacing.lg),
      ],
    );
  }

  String _filterLabel(AppLocalizations l10n, _TransactionFilter value) {
    return switch (value) {
      _TransactionFilter.all => l10n.all,
      _TransactionFilter.income => l10n.income,
      _TransactionFilter.expense => l10n.expense,
      _TransactionFilter.transfer => l10n.transfer,
      _TransactionFilter.pending => l10n.pending,
    };
  }

  String _sortLabel(AppLocalizations l10n, _TransactionSort value) {
    return switch (value) {
      _TransactionSort.newest => l10n.sortNewest,
      _TransactionSort.oldest => l10n.sortOldest,
      _TransactionSort.amountHigh => l10n.sortAmountHigh,
    };
  }
}

sealed class _TransactionListEntry {
  const _TransactionListEntry();
}

final class _TransactionDateEntry extends _TransactionListEntry {
  const _TransactionDateEntry(this.label);

  final String label;
}

final class _TransactionItemEntry extends _TransactionListEntry {
  const _TransactionItemEntry(this.transaction);

  final Transaction transaction;
}

class _TransactionsLoading extends StatelessWidget {
  const _TransactionsLoading();

  @override
  Widget build(BuildContext context) {
    return FinanceScreenBody(
      child: ListView(
        children: const [
          CPSkeletonCard(height: 56),
          SizedBox(height: CPSpacing.md),
          CPSkeletonCard(height: 44),
          SizedBox(height: CPSpacing.xl),
          CPSkeletonCard(height: 104),
          SizedBox(height: CPSpacing.md),
          CPSkeletonCard(height: 104),
          SizedBox(height: CPSpacing.md),
          CPSkeletonCard(height: 104),
        ],
      ),
    );
  }
}

enum _TransactionFilter { all, income, expense, transfer, pending }

enum _TransactionSort { newest, oldest, amountHigh }
