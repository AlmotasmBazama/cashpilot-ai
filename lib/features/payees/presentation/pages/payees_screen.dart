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
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization;
import '../../../categories/domain/entities/category.dart';
import '../../application/providers/payees_providers.dart';
import '../../domain/entities/payee.dart';
import '../../domain/enums/payee_type.dart';
import '../../domain/services/payee_name_normalizer.dart';
import '../support/payee_type_labels.dart';
import '../widgets/payee_form_sheet.dart';

class PayeesScreen extends ConsumerStatefulWidget {
  const PayeesScreen({super.key});

  @override
  ConsumerState<PayeesScreen> createState() => _PayeesScreenState();
}

class _PayeesScreenState extends ConsumerState<PayeesScreen> {
  final _searchController = TextEditingController();
  PayeeType? _type;
  bool _includeArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(allPayeesProvider);
    final accounts = _accounts(ref.watch(accountsProvider));
    final categories = _categories(ref.watch(categoriesProvider));
    return Scaffold(
      appBar: CPAppBar(title: l10n.payeesTitle, subtitle: l10n.payeesSubtitle),
      floatingActionButton: CPFloatingActionButton(
        tooltip: l10n.addPayee,
        onPressed: () => PayeeFormSheet.show(context),
        icon: Icons.add_rounded,
      ),
      body: state.when(
        data: (result) => switch (result) {
          AppSuccess<List<Payee>>(:final data) => _content(
            context,
            data,
            accounts,
            categories,
          ),
          AppFailure<List<Payee>>() => CPErrorView(
            title: l10n.payeesErrorTitle,
            message: l10n.transactionsErrorMessage,
          ),
        },
        error: (_, _) => CPErrorView(
          title: l10n.payeesErrorTitle,
          message: l10n.transactionsErrorMessage,
        ),
        loading: _loading,
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<Payee> allPayees,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final l10n = AppLocalizations.of(context);
    final query = PayeeNameNormalizer.normalize(_searchController.text);
    final payees = allPayees
        .where((payee) {
          if (!_includeArchived && payee.isArchived) {
            return false;
          }
          if (_type != null && payee.type != _type) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return <String>[payee.name, ...payee.aliases].any(
            (value) => PayeeNameNormalizer.normalize(value).contains(query),
          );
        })
        .toList(growable: false);
    return FinanceScreenBody(
      child: ListView(
        children: [
          CPTextField(
            controller: _searchController,
            labelText: l10n.searchPayees,
            prefix: const Icon(Icons.search_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CPSpacing.md),
          Wrap(
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<PayeeType?>(
                  isExpanded: true,
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l10n.filterByType),
                  items: [
                    DropdownMenuItem<PayeeType?>(
                      value: null,
                      child: Text(l10n.allPayeeTypes),
                    ),
                    for (final type in PayeeType.values)
                      DropdownMenuItem<PayeeType?>(
                        value: type,
                        child: Text(PayeeTypeLabels.label(l10n, type)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _type = value),
                ),
              ),
              FilterChip(
                label: Text(l10n.includeArchivedPayees),
                selected: _includeArchived,
                onSelected: (value) => setState(() => _includeArchived = value),
              ),
            ],
          ),
          const SizedBox(height: CPSpacing.xl),
          if (payees.isEmpty)
            CPEmptyState(
              icon: Icons.storefront_outlined,
              title: l10n.emptyPayeesTitle,
              message: l10n.emptyPayeesMessage,
              action: CPButton(
                label: l10n.addPayee,
                onPressed: () => PayeeFormSheet.show(context),
              ),
            )
          else
            for (final payee in payees) ...[
              _PayeeCard(
                payee: payee,
                accountName: _accountName(payee.defaultAccountId, accounts),
                categoryName: _categoryName(
                  context,
                  payee.defaultCategoryId,
                  categories,
                ),
                icon: _icon(payee.type),
                onTap: () => context.pushNamed(
                  AppRouteNames.payeeDetails,
                  pathParameters: {'payeeId': payee.id},
                ),
              ),
              const SizedBox(height: CPSpacing.md),
            ],
        ],
      ),
    );
  }

  Widget _loading() {
    return FinanceScreenBody(
      child: ListView(
        children: const [
          CPSkeletonCard(height: 72, compact: true),
          SizedBox(height: CPSpacing.lg),
          CPSkeletonCard(height: 180),
          SizedBox(height: CPSpacing.md),
          CPSkeletonCard(height: 180),
        ],
      ),
    );
  }

  List<Account> _accounts(AsyncValue<AppResult<List<Account>>> state) {
    return switch (state.value) {
      AppSuccess<List<Account>>(:final data) => data,
      _ => const <Account>[],
    };
  }

  List<Category> _categories(AsyncValue<AppResult<List<Category>>> state) {
    return switch (state.value) {
      AppSuccess<List<Category>>(:final data) => data,
      _ => const <Category>[],
    };
  }

  String? _accountName(String? id, List<Account> accounts) {
    if (id == null) {
      return null;
    }
    return accounts
        .where((account) => account.id == id)
        .map((account) => account.name)
        .firstOrNull;
  }

  String? _categoryName(
    BuildContext context,
    String? id,
    List<Category> categories,
  ) {
    if (id == null) {
      return null;
    }
    final category = categories.where((item) => item.id == id).firstOrNull;
    return category == null
        ? null
        : CategoryLocalization.name(AppLocalizations.of(context), category);
  }

  IconData _icon(PayeeType type) => switch (type) {
    PayeeType.person => Icons.person_rounded,
    PayeeType.merchant => Icons.storefront_rounded,
    PayeeType.employer => Icons.business_rounded,
    PayeeType.bank => Icons.account_balance_rounded,
    PayeeType.paymentService => Icons.payments_rounded,
    PayeeType.utility => Icons.bolt_rounded,
    PayeeType.school => Icons.school_rounded,
    PayeeType.telecom => Icons.phone_android_rounded,
    PayeeType.government => Icons.account_balance_outlined,
    PayeeType.other => Icons.person_pin_rounded,
  };
}

class _PayeeCard extends StatelessWidget {
  const _PayeeCard({
    required this.payee,
    required this.accountName,
    required this.categoryName,
    required this.icon,
    required this.onTap,
  });

  final Payee payee;
  final String? accountName;
  final String? categoryName;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final lastUsed = payee.lastUsedAt == null
        ? l10n.neverUsed
        : FinanceFormatters.compactDate(payee.lastUsedAt!, localeName);
    return CPCard(
      variant: CPCardVariant.interactive,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: CPSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: CPSpacing.xxs),
                    Text(
                      '${PayeeTypeLabels.label(l10n, payee.type)} · ${l10n.lastUsed}: $lastUsed',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CPSpacing.sm),
              if (payee.isArchived)
                FinanceStatusPill(label: l10n.archivedPayee)
              else
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
            ],
          ),
          if (payee.aliases.isNotEmpty) ...[
            const SizedBox(height: CPSpacing.md),
            Text(
              '${l10n.payeeAliases}: ${payee.aliases.join(' · ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: CPSpacing.sm),
          FinanceDetailRow(
            label: l10n.payeeDefaultCategory,
            value:
                categoryName ??
                payee.defaultCategoryId ??
                l10n.noDefaultSelection,
            icon: Icons.category_outlined,
          ),
          FinanceDetailRow(
            label: l10n.payeeDefaultAccount,
            value:
                accountName ??
                payee.defaultAccountId ??
                l10n.noDefaultSelection,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }
}
