import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../payment_methods/domain/defaults/libyan_payment_method_catalog.dart';
import '../../../payment_methods/domain/entities/payment_method_definition.dart';
import '../../domain/entities/account.dart';
import '../support/account_formatters.dart';
import '../support/account_type_labels.dart';
import '../support/account_visuals.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.account,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final Account account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = Color(account.color);
    final l10n = AppLocalizations.of(context);
    final paymentMethods = account.paymentMethodIds
        .map(LibyanPaymentMethodCatalog.findById)
        .whereType<PaymentMethodDefinition>()
        .map((method) => method.displayName)
        .join(', ');

    return Opacity(
      opacity: account.isArchived ? 0.72 : 1,
      child: CPCard(
        variant: CPCardVariant.interactive,
        onTap: onTap,
        accentColor: color,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final compactHeight =
                192.0 + ((textScale - 1).clamp(0.0, 0.5) * 48);
            final height = constraints.hasBoundedHeight
                ? constraints.maxHeight
                : compactHeight;

            return SizedBox(
              height: height,
              child: Stack(
                children: [
                  PositionedDirectional(
                    top: -48,
                    end: -36,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.all(CPSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _AccountIcon(color: color, iconKey: account.icon),
                            if (account.isArchived) ...[
                              const SizedBox(width: CPSpacing.sm),
                              Flexible(
                                child: Container(
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                        horizontal: CPSpacing.sm,
                                        vertical: CPSpacing.xxs,
                                      ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(
                                      CPRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.archivedAccountLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            PopupMenuButton<_AccountAction>(
                              tooltip: l10n.moreActions,
                              onSelected: (action) {
                                switch (action) {
                                  case _AccountAction.edit:
                                    onEdit();
                                  case _AccountAction.delete:
                                    onDelete();
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: _AccountAction.edit,
                                  child: Text(l10n.editAccount),
                                ),
                                PopupMenuItem(
                                  value: _AccountAction.delete,
                                  child: Text(l10n.deleteAccount),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: CPSpacing.xs),
                        Text(
                          [
                            AccountTypeLabels.label(l10n, account.type),
                            AccountFormatters.currency(account.currencyCode),
                            if (paymentMethods.isNotEmpty) paymentMethods,
                          ].join(' / '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: CPSpacing.sm),
                        AnimatedSwitcher(
                          duration: CPDurations.normal,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.12),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: FittedBox(
                            key: ValueKey(account.balance),
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              AccountFormatters.amount(account.balance),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(height: CPSpacing.xs),
                        Text(
                          account.currencyCode.toUpperCase(),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _AccountAction { edit, delete }

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.color, required this.iconKey});

  final Color color;
  final String iconKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(CPRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Icon(AccountVisuals.iconForKey(iconKey), color: color),
    );
  }
}
