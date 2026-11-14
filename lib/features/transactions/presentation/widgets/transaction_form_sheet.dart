import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/categories_presentation.dart'
    show CategoryLocalization, CategoryVisuals;
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../finance_engine/domain/value_objects/money.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../payees/application/providers/payees_providers.dart';
import '../../../payees/domain/entities/payee.dart';
import '../../../payees/payees_presentation.dart' show PayeeTypeLabels;
import '../../../receipts/application/receipt_providers.dart';
import '../../application/providers/transactions_providers.dart';
import '../../domain/entities/transaction.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';
import '../support/transaction_ui_formatters.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    required this.type,
    this.existingTransaction,
    super.key,
  });

  final TransactionType type;
  final Transaction? existingTransaction;

  static Future<bool?> show(
    BuildContext context,
    TransactionType type, {
    Transaction? existingTransaction,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TransactionFormSheet(
        type: type,
        existingTransaction: existingTransaction,
      ),
    );
  }

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();
  Account? _selectedAccount;
  Category? _selectedCategory;
  Payee? _selectedPayee;
  PaymentMethod _paymentMethod = PaymentMethod.other;
  TransactionStatus _status = TransactionStatus.posted;
  IncomeSourceType? _selectedIncomeSourceType;
  DateTime _transactionDate = DateTime.now();
  bool _accountSelectedExplicitly = false;
  bool _categorySelectedExplicitly = false;
  bool _isSubmitting = false;
  bool _existingSelectionsResolved = false;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    if (existing == null) {
      return;
    }
    _amountController.text = existing.amount.amount.toString();
    _noteController.text = existing.note ?? '';
    _locationController.text = existing.location ?? '';
    _paymentMethod = existing.paymentMethod;
    _status = existing.status;
    _selectedIncomeSourceType = existing.incomeSourceType;
    _transactionDate = existing.transactionDate.toLocal();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountsState = ref.watch(accountsProvider);
    final categoriesState = ref.watch(categoriesByTypeProvider(_categoryType));
    final payeesState = ref.watch(payeesProvider);
    final receiptScanningEnabled = ref
        .watch(receiptFeatureConfigProvider)
        .enabled;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: CPSpacing.lg,
        end: CPSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CPSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CPSectionTitle(
              title: _isEditing
                  ? l10n.editTransaction
                  : widget.type == TransactionType.income
                  ? l10n.addIncome
                  : l10n.addExpense,
              padding: EdgeInsets.zero,
            ),
            if (!_isEditing &&
                widget.type == TransactionType.expense &&
                receiptScanningEnabled) ...[
              const SizedBox(height: CPSpacing.sm),
              CPButton(
                key: const Key('add_expense_scan_receipt_button'),
                label: l10n.scanReceipt,
                icon: Icons.document_scanner_outlined,
                variant: CPButtonVariant.tonal,
                fullWidth: true,
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop(false);
                  router.push(AppRoutePaths.receiptCapture);
                },
              ),
            ],
            const SizedBox(height: CPSpacing.lg),
            accountsState.when(
              data: (accountsResult) => categoriesState.when(
                data: (categoriesResult) => payeesState.when(
                  data: (payeesResult) => switch ((
                    accountsResult,
                    categoriesResult,
                    payeesResult,
                  )) {
                    (
                      AppSuccess<List<Account>>(data: final accounts),
                      AppSuccess<List<Category>>(data: final categories),
                      AppSuccess<List<Payee>>(data: final payees),
                    ) =>
                      _buildForm(context, accounts, categories, payees),
                    _ => CPErrorView(
                      title: l10n.transactionsErrorTitle,
                      message: l10n.transactionsErrorMessage,
                    ),
                  },
                  error: (_, _) => CPErrorView(
                    title: l10n.payeesErrorTitle,
                    message: l10n.transactionsErrorMessage,
                  ),
                  loading: () => const CPLoadingIndicator(),
                ),
                error: (_, _) => CPErrorView(
                  title: l10n.transactionsErrorTitle,
                  message: l10n.transactionsErrorMessage,
                ),
                loading: () => const CPLoadingIndicator(),
              ),
              error: (_, _) => CPErrorView(
                title: l10n.accountsErrorTitle,
                message: l10n.accountsErrorMessage,
              ),
              loading: () => const CPLoadingIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<Account> accounts,
    List<Category> categories,
    List<Payee> payees,
  ) {
    final l10n = AppLocalizations.of(context);
    final availableAccounts = accounts
        .where((account) => !account.isArchived)
        .toList(growable: false);
    final availableCategories = categories
        .where((category) => !category.isArchived)
        .toList(growable: false);
    final availablePayees = payees
        .where((payee) => !payee.isArchived)
        .toList(growable: false);
    if (!_existingSelectionsResolved) {
      final existing = widget.existingTransaction;
      if (existing != null) {
        _selectedAccount = availableAccounts
            .where((account) => account.id == existing.accountId)
            .firstOrNull;
        _selectedCategory = availableCategories
            .where((category) => category.id == existing.categoryId)
            .firstOrNull;
        _selectedPayee = availablePayees
            .where((payee) => payee.id == existing.payeeId)
            .firstOrNull;
        _accountSelectedExplicitly = true;
        _categorySelectedExplicitly = true;
      }
      _existingSelectionsResolved = true;
    }
    if (!_isEditing) {
      _selectedAccount ??= availableAccounts.isEmpty
          ? null
          : availableAccounts.first;
      _selectedCategory ??= availableCategories.isEmpty
          ? null
          : availableCategories.first;
    }

    if (availableAccounts.isEmpty || availableCategories.isEmpty) {
      return CPEmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.transactionPrerequisitesTitle,
        message: l10n.transactionPrerequisitesMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isEditing) ...[
          FinanceInfoCard(
            title: l10n.editTransaction,
            message: _status == TransactionStatus.posted
                ? l10n.postedTransactionEditHint
                : l10n.pendingTransactionEditHint,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: CPSpacing.md),
        ],
        CPAmountField(
          controller: _amountController,
          labelText: l10n.amount,
          currencyCode: _selectedAccount?.currencyCode,
        ),
        const SizedBox(height: CPSpacing.md),
        _ChoiceField(
          label: l10n.selectPayee,
          value: _selectedPayee?.name ?? l10n.noPayee,
          icon: Icons.person_pin_outlined,
          onTap: () async {
            final choice = await _showChoiceSheet<_PayeeChoice>(
              title: l10n.selectPayee,
              items: <_PayeeChoice>[
                const _PayeeChoice(null),
                ...availablePayees.map(_PayeeChoice.new),
              ],
              labelFor: (choice) => choice.payee?.name ?? l10n.noPayee,
              subtitleFor: (choice) => choice.payee == null
                  ? null
                  : PayeeTypeLabels.label(l10n, choice.payee!.type),
              iconFor: (choice) => choice.payee == null
                  ? Icons.person_off_outlined
                  : Icons.person_pin_outlined,
            );
            if (choice != null) {
              _selectPayee(
                choice.payee,
                availableAccounts,
                availableCategories,
              );
            }
          },
        ),
        const SizedBox(height: CPSpacing.md),
        _ChoiceField(
          label: l10n.accountName,
          value: _selectedAccount?.name ?? '',
          icon: Icons.account_balance_wallet_outlined,
          onTap: () async {
            final account = await _showChoiceSheet<Account>(
              title: l10n.accountName,
              items: availableAccounts,
              labelFor: (account) => account.name,
              subtitleFor: (account) => account.currencyCode,
              iconFor: (_) => Icons.account_balance_wallet_rounded,
            );
            if (account != null) {
              setState(() {
                _selectedAccount = account;
                _accountSelectedExplicitly = true;
              });
            }
          },
        ),
        const SizedBox(height: CPSpacing.md),
        _ChoiceField(
          label: l10n.category,
          value: _selectedCategory == null
              ? ''
              : CategoryLocalization.name(l10n, _selectedCategory!),
          icon: Icons.category_outlined,
          onTap: () async {
            final category = await _showChoiceSheet<Category>(
              title: l10n.category,
              items: availableCategories,
              labelFor: (category) => CategoryLocalization.name(l10n, category),
              subtitleFor: (category) =>
                  CategoryLocalization.typeLabel(l10n, category.type),
              iconFor: (category) =>
                  CategoryVisuals.iconForKey(category.icon.key),
            );
            if (category != null) {
              setState(() {
                _selectedCategory = category;
                _categorySelectedExplicitly = true;
              });
            }
          },
        ),
        if (widget.type == TransactionType.income) ...[
          const SizedBox(height: CPSpacing.md),
          _ChoiceField(
            key: const Key('manual_income_source_type_selector'),
            label: l10n.aiIncomeSourceType,
            value: _selectedIncomeSourceType == null
                ? l10n.aiIncomeSourceType
                : _incomeSourceTypeLabel(l10n, _selectedIncomeSourceType!),
            icon: Icons.call_received_rounded,
            onTap: () async {
              final sourceType = await _showChoiceSheet<IncomeSourceType>(
                title: l10n.aiIncomeSourceType,
                items: IncomeSourceType.values,
                labelFor: (type) => _incomeSourceTypeLabel(l10n, type),
                iconFor: (_) => Icons.call_received_rounded,
              );
              if (sourceType != null) {
                setState(() => _selectedIncomeSourceType = sourceType);
              }
            },
          ),
        ],
        const SizedBox(height: CPSpacing.md),
        _ChoiceField(
          label: l10n.paymentMethod,
          value: TransactionUiFormatters.paymentMethodLabel(
            _paymentMethod,
            l10n,
          ),
          icon: Icons.credit_card_rounded,
          onTap: () async {
            final method = await _showChoiceSheet<PaymentMethod>(
              title: l10n.paymentMethod,
              items: PaymentMethod.values,
              labelFor: (method) =>
                  TransactionUiFormatters.paymentMethodLabel(method, l10n),
              iconFor: (_) => Icons.payments_outlined,
            );
            if (method != null) {
              setState(() => _paymentMethod = method);
            }
          },
        ),
        const SizedBox(height: CPSpacing.md),
        _ChoiceField(
          label: l10n.status,
          value: TransactionUiFormatters.statusLabel(_status, l10n),
          icon: Icons.pending_actions_outlined,
          onTap: () async {
            final status = await _showChoiceSheet<TransactionStatus>(
              title: l10n.status,
              items: const <TransactionStatus>[
                TransactionStatus.pending,
                TransactionStatus.posted,
              ],
              labelFor: (status) =>
                  TransactionUiFormatters.statusLabel(status, l10n),
              iconFor: (_) => Icons.circle_outlined,
            );
            if (status != null) {
              setState(() => _status = status);
            }
          },
        ),
        const SizedBox(height: CPSpacing.md),
        _ChoiceField(
          label: l10n.transactionDate,
          value: MaterialLocalizations.of(
            context,
          ).formatMediumDate(_transactionDate),
          icon: Icons.calendar_today_outlined,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDate: _transactionDate,
            );
            if (date != null) {
              setState(() => _transactionDate = date);
            }
          },
        ),
        const SizedBox(height: CPSpacing.md),
        CPTextField(
          controller: _noteController,
          labelText: l10n.note,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: CPSpacing.md),
        CPTextField(
          controller: _locationController,
          labelText: l10n.location,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: CPSpacing.xl),
        Row(
          children: [
            Expanded(
              child: CPButton(
                label: l10n.cancel,
                variant: CPButtonVariant.ghost,
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: CPSpacing.sm),
            Expanded(
              child: CPButton(
                label: l10n.save,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _selectPayee(
    Payee? payee,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final defaultAccount = payee?.defaultAccountId == null
        ? null
        : accounts
              .where((account) => account.id == payee!.defaultAccountId)
              .firstOrNull;
    final defaultCategory = payee?.defaultCategoryId == null
        ? null
        : categories
              .where((category) => category.id == payee!.defaultCategoryId)
              .firstOrNull;
    setState(() {
      _selectedPayee = payee;
      if (!_accountSelectedExplicitly && defaultAccount != null) {
        _selectedAccount = defaultAccount;
      }
      if (!_categorySelectedExplicitly && defaultCategory != null) {
        _selectedCategory = defaultCategory;
      }
    });
  }

  Future<T?> _showChoiceSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T item) labelFor,
    required IconData Function(T item) iconFor,
    String? Function(T item)? subtitleFor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
            children: [
              CPSectionTitle(title: title, padding: EdgeInsets.zero),
              const SizedBox(height: CPSpacing.md),
              for (final item in items)
                CPListTile(
                  title: labelFor(item),
                  subtitle: subtitleFor?.call(item),
                  leading: Icon(iconFor(item)),
                  onTap: () => Navigator.of(context).pop(item),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final account = _selectedAccount;
    final category = _selectedCategory;
    final amount = LocalizedDecimalParser.tryParse(_amountController.text);

    if (account == null || category == null) {
      _showMessage(l10n.transactionPrerequisitesMessage);
      return;
    }

    if (amount == null || amount <= Decimal.zero) {
      _showMessage(l10n.invalidAmount);
      return;
    }

    if (widget.type == TransactionType.income &&
        _selectedIncomeSourceType == null) {
      _showMessage(l10n.aiIncomeSourceType);
      return;
    }

    setState(() => _isSubmitting = true);
    final draft = Transaction.create(
      accountId: account.id,
      categoryId: category.id,
      payeeId: _selectedPayee?.id,
      amount: Money(amount: amount, currencyCode: account.currencyCode),
      type: widget.type,
      paymentMethod: _paymentMethod,
      status: _status,
      incomeSourceType: widget.type == TransactionType.income
          ? _selectedIncomeSourceType
          : null,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      transactionDate: _transactionDate.toUtc(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
    );
    final existing = widget.existingTransaction;
    final transaction = existing == null
        ? draft
        : draft.copyWith(
            id: existing.id,
            source: existing.source,
            transferGroupId: existing.transferGroupId,
            exchangeRate: existing.exchangeRate,
            attachmentCount: existing.attachmentCount,
            aiConfidence: existing.aiConfidence,
            needsReview: existing.needsReview,
            createdAt: existing.createdAt,
            updatedAt: DateTime.now().toUtc(),
          );
    final result = existing == null
        ? await ref.read(createTransactionWithPayeeUsageProvider)(transaction)
        : await ref.read(updateTransactionUseCaseProvider)(transaction);

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    switch (result) {
      case AppSuccess<Transaction>():
        ref
          ..invalidate(transactionByIdProvider(transaction.id))
          ..invalidate(transactionsProvider)
          ..invalidate(accountsProvider)
          ..invalidate(payeesProvider)
          ..invalidate(allPayeesProvider);
        Navigator.of(context).pop(true);
      case AppFailure<Transaction>(:final failure):
        _showMessage(failure.message);
    }
  }

  CategoryType get _categoryType {
    return widget.type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _incomeSourceTypeLabel(
  AppLocalizations l10n,
  IncomeSourceType sourceType,
) {
  return switch (sourceType) {
    IncomeSourceType.salary => l10n.incomeSourceSalary,
    IncomeSourceType.freelance => l10n.incomeSourceFreelance,
    IncomeSourceType.businessRevenue => l10n.incomeSourceBusinessRevenue,
    IncomeSourceType.gift => l10n.incomeSourceGift,
    IncomeSourceType.debtRepayment => l10n.incomeSourceDebtRepayment,
    IncomeSourceType.allowance => l10n.incomeSourceAllowance,
    IncomeSourceType.refund => l10n.incomeSourceRefund,
    IncomeSourceType.sale => l10n.incomeSourceSale,
    IncomeSourceType.rentalIncome => l10n.incomeSourceRentalIncome,
    IncomeSourceType.governmentSupport => l10n.incomeSourceGovernmentSupport,
    IncomeSourceType.scholarship => l10n.incomeSourceScholarship,
    IncomeSourceType.investmentReturn => l10n.incomeSourceInvestmentReturn,
    IncomeSourceType.reimbursement => l10n.incomeSourceReimbursement,
    IncomeSourceType.prize => l10n.incomeSourcePrize,
    IncomeSourceType.loanProceeds => l10n.incomeSourceLoanProceeds,
    IncomeSourceType.externalTransfer => l10n.incomeSourceExternalTransfer,
    IncomeSourceType.other => l10n.incomeSourceOther,
  };
}

class _PayeeChoice {
  const _PayeeChoice(this.payee);

  final Payee? payee;
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CPTextField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      labelText: label,
      prefix: Icon(icon),
      readOnly: true,
      suffix: const Icon(Icons.keyboard_arrow_down_rounded),
      onTap: onTap,
    );
  }
}
