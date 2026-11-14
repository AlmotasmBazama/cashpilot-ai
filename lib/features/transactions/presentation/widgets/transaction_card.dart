import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/formatters/finance_formatters.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/enums/transaction_status.dart';
import '../../domain/enums/transaction_type.dart';
import '../support/transaction_ui_formatters.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({
    required this.transaction,
    required this.onTap,
    this.accountName,
    this.categoryName,
    super.key,
  });

  final Transaction transaction;
  final String? accountName;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, transaction.type);
    final l10n = AppLocalizations.of(context);
    final amountPrefix = TransactionUiFormatters.isDebit(transaction.type)
        ? '-'
        : '+';
    final subtitle = [
      if (categoryName?.trim().isNotEmpty == true) categoryName!.trim(),
      if (accountName?.trim().isNotEmpty == true) accountName!.trim(),
    ].join(' / ');
    final isTransfer =
        transaction.type == TransactionType.transferIn ||
        transaction.type == TransactionType.transferOut;

    return CPCard(
      variant: CPCardVariant.interactive,
      onTap: onTap,
      accentColor: color,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: EdgeInsets.zero,
      child: CPListTile(
        leading: Hero(
          tag: 'transaction-icon-${transaction.id}',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(CPRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              TransactionUiFormatters.iconForType(transaction.type),
              color: color,
            ),
          ),
        ),
        title: transaction.note?.trim().isNotEmpty == true
            ? transaction.note!.trim()
            : categoryName ??
                  TransactionUiFormatters.typeLabel(transaction.type, l10n),
        subtitle: subtitle.isEmpty ? null : subtitle,
        supportingText: FinanceFormatters.fullDate(
          transaction.transactionDate,
          Localizations.localeOf(context).toString(),
        ),
        trailing: SizedBox(
          width: 132,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: CPDurations.normal,
                child: FinanceAmountText(
                  key: ValueKey(transaction.amount),
                  value:
                      '$amountPrefix${FinanceFormatters.money(transaction.amount)}',
                  color: color,
                  alignment: AlignmentDirectional.centerEnd,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: CPSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isTransfer) ...[
                    Icon(Icons.link_rounded, size: 15, color: color),
                    const SizedBox(width: CPSpacing.xs),
                  ],
                  Flexible(
                    child: _StatusDot(status: transaction.status, l10n: l10n),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFor(BuildContext context, TransactionType type) {
    final cpColors = context.cpColors;
    return switch (type) {
      TransactionType.income => cpColors.income,
      TransactionType.expense => cpColors.expense,
      TransactionType.transferIn ||
      TransactionType.transferOut => cpColors.transfer,
    };
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status, required this.l10n});

  final TransactionStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TransactionStatus.posted => context.cpColors.success,
      TransactionStatus.pending => context.cpColors.warning,
      TransactionStatus.cancelled => Theme.of(context).colorScheme.outline,
      TransactionStatus.failed => Theme.of(context).colorScheme.error,
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: CPSpacing.sm,
        vertical: CPSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CPRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: CPSpacing.xs),
          Text(
            TransactionUiFormatters.statusLabel(status, l10n),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
