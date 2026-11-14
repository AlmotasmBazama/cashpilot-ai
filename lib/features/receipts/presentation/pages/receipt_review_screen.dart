import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/domain/currency/localized_decimal_parser.dart';
import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../../../payment_methods/payment_methods.dart' show PaymentMethod;
import '../../application/receipt_providers.dart';
import '../../application/receipt_review_providers.dart';
import '../../application/receipt_review_workflow.dart';
import '../../domain/entities/receipt_analysis_draft.dart';
import '../../domain/entities/receipt_line_item.dart';
import '../../domain/enums/image_retention_choice.dart';
import '../../domain/enums/receipt_document_type.dart';
import '../../domain/enums/receipt_payment_status.dart';
import '../../domain/enums/receipt_warning.dart';
import '../../domain/failures/receipt_failure_codes.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({required this.receiptId, super.key});

  final String receiptId;

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  final _merchantController = TextEditingController();
  final _dateController = TextEditingController();
  final _currencyController = TextEditingController();
  final _subtotalController = TextEditingController();
  final _taxController = TextEditingController();
  final _discountController = TextEditingController();
  final _tipController = TextEditingController();
  final _totalController = TextEditingController();
  final _accountAmountController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  ReceiptAnalysisDraft? _draft;
  String? _accountId;
  PaymentMethod _paymentMethod = PaymentMethod.other;
  bool _warningsAcknowledged = false;
  bool _isSaving = false;
  bool _isConfirming = false;

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _currencyController.dispose();
    _subtotalController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    _tipController.dispose();
    _totalController.dispose();
    _accountAmountController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draftState = ref.watch(receiptDraftProvider(widget.receiptId));
    final accountsState = ref.watch(accountsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: CPAppBar(
        title: l10n.receiptReviewTitle,
        subtitle: l10n.receiptReviewSubtitle,
      ),
      body: draftState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _error(l10n),
        data: (result) {
          if (result case AppSuccess(data: final loaded?)) {
            _initialize(loaded);
            return accountsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _error(l10n),
              data: (accountsResult) => categoriesState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _error(l10n),
                data: (categoriesResult) {
                  final accounts = switch (accountsResult) {
                    AppSuccess<List<Account>>(:final data) =>
                      data
                          .where((account) => !account.isArchived)
                          .toList(growable: false),
                    _ => const <Account>[],
                  };
                  final categories = switch (categoriesResult) {
                    AppSuccess<List<Category>>(:final data) =>
                      data
                          .where(
                            (category) =>
                                !category.isArchived &&
                                category.type == CategoryType.expense,
                          )
                          .toList(growable: false),
                    _ => const <Category>[],
                  };
                  return _content(
                    context,
                    l10n,
                    accounts: accounts,
                    categories: categories,
                  );
                },
              ),
            );
          }
          return _error(l10n);
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n, {
    required List<Account> accounts,
    required List<Category> categories,
  }) {
    final draft = _draft!;
    final selectedAccount = accounts
        .where((account) => account.id == _accountId)
        .firstOrNull;
    final crossCurrency =
        selectedAccount != null &&
        draft.currency?.toUpperCase() !=
            selectedAccount.currencyCode.toUpperCase();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(CPSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (draft.localImageReference case final reference?)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(reference),
                        height: 260,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  const SizedBox(height: CPSpacing.md),
                  _warningCard(context, l10n, draft),
                  const SizedBox(height: CPSpacing.md),
                  CPCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _merchantController,
                          decoration: InputDecoration(
                            labelText: l10n.receiptMerchant,
                          ),
                        ),
                        const SizedBox(height: CPSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  DropdownButtonFormField<ReceiptDocumentType>(
                                    initialValue: draft.documentType,
                                    decoration: InputDecoration(
                                      labelText: l10n.receiptDocumentType,
                                    ),
                                    items: ReceiptDocumentType.values
                                        .map(
                                          (type) => DropdownMenuItem(
                                            value: type,
                                            child: Text(type.storageValue),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _draft = draft.copyWith(
                                            documentType: value,
                                          );
                                        });
                                      }
                                    },
                                  ),
                            ),
                            const SizedBox(width: CPSpacing.md),
                            Expanded(
                              child:
                                  DropdownButtonFormField<ReceiptPaymentStatus>(
                                    initialValue: draft.paymentStatus,
                                    decoration: InputDecoration(
                                      labelText: l10n.receiptPaymentStatus,
                                    ),
                                    items: ReceiptPaymentStatus.values
                                        .map(
                                          (status) => DropdownMenuItem(
                                            value: status,
                                            child: Text(status.storageValue),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _draft = draft.copyWith(
                                            paymentStatus: value,
                                          );
                                        });
                                      }
                                    },
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CPSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dateController,
                                decoration: InputDecoration(
                                  labelText: l10n.receiptPurchaseDate,
                                  hintText: 'YYYY-MM-DD',
                                ),
                              ),
                            ),
                            const SizedBox(width: CPSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _currencyController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: l10n.currencyCode,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CPSpacing.md),
                        _moneyRow(
                          left: _subtotalController,
                          leftLabel: l10n.receiptSubtotal,
                          right: _taxController,
                          rightLabel: l10n.receiptTax,
                        ),
                        const SizedBox(height: CPSpacing.md),
                        _moneyRow(
                          left: _discountController,
                          leftLabel: l10n.receiptDiscount,
                          right: _tipController,
                          rightLabel: l10n.receiptTip,
                        ),
                        const SizedBox(height: CPSpacing.md),
                        TextFormField(
                          controller: _totalController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.receiptTotal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CPSpacing.md),
                  _lineItemsCard(context, l10n, categories),
                  const SizedBox(height: CPSpacing.md),
                  CPCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.receiptRetentionRequired,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        RadioGroup<ImageRetentionChoice>(
                          groupValue: draft.imageRetentionChoice,
                          onChanged: _setRetention,
                          child: Column(
                            children: [
                              RadioListTile<ImageRetentionChoice>(
                                value: ImageRetentionChoice.keepLocally,
                                title: Text(l10n.receiptKeepImage),
                              ),
                              RadioListTile<ImageRetentionChoice>(
                                value:
                                    ImageRetentionChoice.deleteAfterExtraction,
                                title: Text(l10n.receiptDeleteImage),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CPSpacing.md),
                  CPCard(
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _accountId,
                          decoration: InputDecoration(
                            labelText: l10n.accountName,
                          ),
                          items: accounts
                              .map(
                                (account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text(
                                    '${account.name} (${account.currencyCode})',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) =>
                              setState(() => _accountId = value),
                        ),
                        const SizedBox(height: CPSpacing.md),
                        DropdownButtonFormField<PaymentMethod>(
                          initialValue: _paymentMethod,
                          decoration: InputDecoration(
                            labelText: l10n.paymentMethod,
                          ),
                          items: PaymentMethod.values
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method,
                                  child: Text(method.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) => setState(
                            () => _paymentMethod = value ?? PaymentMethod.other,
                          ),
                        ),
                        if (crossCurrency) ...[
                          const SizedBox(height: CPSpacing.md),
                          TextFormField(
                            controller: _accountAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  '${l10n.amount} (${selectedAccount.currencyCode})',
                            ),
                          ),
                          const SizedBox(height: CPSpacing.md),
                          TextFormField(
                            controller: _exchangeRateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  '${draft.currency} → ${selectedAccount.currencyCode}',
                            ),
                          ),
                        ],
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _warningsAcknowledged,
                          title: Text(l10n.receiptWarningsAcknowledgement),
                          onChanged: (value) => setState(
                            () => _warningsAcknowledged = value ?? false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CPSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _save(context, l10n),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.receiptSaveDraft),
                  ),
                  const SizedBox(height: CPSpacing.md),
                  FilledButton.icon(
                    key: const Key('receipt_confirm_transaction_button'),
                    onPressed: _isConfirming || accounts.isEmpty
                        ? null
                        : () => _confirm(
                            context,
                            l10n,
                            accounts: accounts,
                            categories: categories,
                          ),
                    icon: _isConfirming
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(l10n.receiptConfirmTransaction),
                  ),
                  if (accounts.isEmpty) ...[
                    const SizedBox(height: CPSpacing.sm),
                    Text(l10n.receiptNoAccounts, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard(
    BuildContext context,
    AppLocalizations l10n,
    ReceiptAnalysisDraft draft,
  ) {
    if (draft.warnings.isEmpty && draft.duplicateCandidateIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return CPCard(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.receiptWarnings,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (draft.duplicateCandidateIds.isNotEmpty)
            Text(l10n.receiptDuplicateWarning),
          ...draft.warnings.map((warning) => Text('• ${warning.storageValue}')),
        ],
      ),
    );
  }

  Widget _lineItemsCard(
    BuildContext context,
    AppLocalizations l10n,
    List<Category> categories,
  ) {
    final items = _draft!.lineItems;
    return CPCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.receiptLineItems,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('receipt_add_line_item_button'),
                tooltip: l10n.receiptAddLineItem,
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: CPSpacing.md),
              child: Text(l10n.receiptNoItems),
            ),
          for (var index = 0; index < items.length; index++) ...[
            const Divider(height: CPSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey(
                      'receipt_item_description_${items[index].id}',
                    ),
                    initialValue: items[index].description,
                    decoration: InputDecoration(
                      labelText: '${l10n.receiptLineItems} ${index + 1}',
                    ),
                    onChanged: (value) => _updateItem(
                      index,
                      items[index].copyWith(
                        description: value,
                        normalizedDescription: value.trim().toLowerCase(),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: CPSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('receipt_item_category_${items[index].id}'),
                    initialValue:
                        categories.any(
                          (category) => category.id == items[index].categoryId,
                        )
                        ? items[index].categoryId
                        : null,
                    decoration: InputDecoration(labelText: l10n.category),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        _updateItem(
                          index,
                          items[index].copyWith(categoryId: value),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: CPSpacing.md),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    key: ValueKey('receipt_item_total_${items[index].id}'),
                    initialValue: items[index].totalPrice?.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.receiptTotal),
                    onChanged: (value) => _updateItem(
                      index,
                      items[index].copyWith(totalPrice: _decimal(value)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _moneyRow({
    required TextEditingController left,
    required String leftLabel,
    required TextEditingController right,
    required String rightLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: left,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: leftLabel),
          ),
        ),
        const SizedBox(width: CPSpacing.md),
        Expanded(
          child: TextFormField(
            controller: right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: rightLabel),
          ),
        ),
      ],
    );
  }

  void _initialize(ReceiptAnalysisDraft loaded) {
    if (_draft != null) {
      return;
    }
    _draft = loaded;
    _merchantController.text = loaded.merchantName ?? '';
    _dateController.text = loaded.purchaseDate == null
        ? ''
        : loaded.purchaseDate!.toIso8601String().split('T').first;
    _currencyController.text = loaded.currency ?? '';
    _subtotalController.text = loaded.subtotal?.toString() ?? '';
    _taxController.text = loaded.tax?.toString() ?? '';
    _discountController.text = loaded.discount?.toString() ?? '';
    _tipController.text = loaded.tip?.toString() ?? '';
    _totalController.text = loaded.total?.toString() ?? '';
  }

  void _updateItem(int index, ReceiptLineItem item) {
    final items = [..._draft!.lineItems];
    items[index] = item;
    setState(() => _draft = _draft!.copyWith(lineItems: items));
  }

  void _addItem() {
    final current = _draft!;
    final items = <ReceiptLineItem>[
      ...current.lineItems,
      ReceiptLineItem.create(
        receiptId: current.id,
        description: '',
        normalizedDescription: '',
        sortOrder: current.lineItems.length,
      ),
    ];
    setState(() => _draft = current.copyWith(lineItems: items));
  }

  void _removeItem(int index) {
    final items = [..._draft!.lineItems]..removeAt(index);
    final ordered = [
      for (var itemIndex = 0; itemIndex < items.length; itemIndex++)
        items[itemIndex].copyWith(sortOrder: itemIndex),
    ];
    setState(() => _draft = _draft!.copyWith(lineItems: ordered));
  }

  void _setRetention(ImageRetentionChoice? choice) {
    if (choice != null) {
      setState(() => _draft = _draft!.copyWith(imageRetentionChoice: choice));
    }
  }

  Future<ReceiptAnalysisDraft?> _save(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final workflow = ref.read(receiptReviewWorkflowProvider);
    final preparation = workflow.prepareDraft(
      ReceiptReviewDraftInput(
        current: _draft!,
        merchantNameText: _merchantController.text,
        purchaseDateText: _dateController.text,
        currencyText: _currencyController.text,
        subtotalText: _subtotalController.text,
        taxText: _taxController.text,
        discountText: _discountController.text,
        tipText: _tipController.text,
        totalText: _totalController.text,
      ),
    );
    if (preparation is! ReceiptReviewDraftReady) {
      _show(context, l10n.receiptNoItems);
      return null;
    }
    setState(() => _isSaving = true);
    final saved = await workflow.saveDraft(preparation);
    if (saved case AppSuccess<ReceiptAnalysisDraft>(:final data)) {
      if (!context.mounted) {
        return data;
      }
      setState(() {
        _draft = data;
        _isSaving = false;
      });
      _show(context, l10n.receiptSavedMessage);
      return data;
    }
    if (!context.mounted) {
      return null;
    }
    setState(() => _isSaving = false);
    _show(context, (saved as AppFailure<ReceiptAnalysisDraft>).failure.message);
    return null;
  }

  Future<void> _confirm(
    BuildContext context,
    AppLocalizations l10n, {
    required List<Account> accounts,
    required List<Category> categories,
  }) async {
    final saved = await _save(context, l10n);
    if (saved == null || !context.mounted) {
      return;
    }
    if (saved.imageRetentionChoice == ImageRetentionChoice.undecided) {
      _show(context, l10n.receiptRetentionRequired);
      return;
    }
    final account = accounts
        .where((candidate) => candidate.id == _accountId)
        .firstOrNull;
    if (account == null) {
      _show(context, l10n.receiptNoAccounts);
      return;
    }
    setState(() => _isConfirming = true);
    try {
      final result = await ref
          .read(receiptReviewWorkflowProvider)
          .confirm(
            ReceiptReviewConfirmationInput(
              saved: saved,
              account: account,
              categories: categories,
              paymentMethod: _paymentMethod,
              warningsAcknowledged: _warningsAcknowledged,
              accountAmountText: _accountAmountController.text,
              exchangeRateText: _exchangeRateController.text,
            ),
          );
      if (result case AppSuccess()) {
        ref.invalidate(transactionsProvider);
        if (context.mounted) {
          _show(context, l10n.receiptCreatedMessage);
          context.go(AppRoutePaths.transactions);
        }
      } else if (context.mounted) {
        _show(context, (result as AppFailure).failure.message);
      }
    } on ReceiptException catch (error) {
      if (context.mounted) {
        _show(context, error.safeMessage);
      }
    } on Object {
      if (context.mounted) {
        _show(context, l10n.aiActionInvalidMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  Widget _error(AppLocalizations l10n) {
    return CPErrorView(
      title: l10n.receiptReviewTitle,
      message: l10n.transactionsErrorMessage,
      action: CPButton(
        label: l10n.retry,
        onPressed: () => ref.invalidate(receiptDraftProvider(widget.receiptId)),
      ),
    );
  }

  Decimal? _decimal(String value) {
    return LocalizedDecimalParser.tryParse(value);
  }

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
