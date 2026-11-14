import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../payment_methods/domain/defaults/libyan_payment_method_catalog.dart';
import '../../domain/enums/account_type.dart';
import '../support/account_type_labels.dart';
import '../support/account_visuals.dart';

class AccountTypeField extends StatelessWidget {
  const AccountTypeField({required this.value, this.onChanged, super.key});

  final AccountType value;
  final ValueChanged<AccountType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CPTextField(
      key: ValueKey(value.storageValue),
      labelText: l10n.accountType,
      initialValue: AccountTypeLabels.label(l10n, value),
      readOnly: true,
      suffix: onChanged == null ? null : const Icon(Icons.expand_more_rounded),
      onTap: onChanged == null
          ? null
          : () async {
              final selected = await showModalBottomSheet<AccountType>(
                context: context,
                showDragHandle: true,
                builder: (context) => _AccountTypePicker(selected: value),
              );

              if (selected != null) {
                onChanged?.call(selected);
              }
            },
    );
  }
}

class AccountIconField extends StatelessWidget {
  const AccountIconField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = AccountVisuals.icons.firstWhere(
      (option) => option.key == value,
      orElse: () => AccountVisuals.icons.first,
    );

    return CPTextField(
      key: ValueKey(value),
      labelText: l10n.accountIcon,
      initialValue: selected.label,
      readOnly: true,
      prefix: Icon(selected.icon),
      suffix: const Icon(Icons.expand_more_rounded),
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => _AccountIconPicker(selectedKey: value),
        );

        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

class AccountColorField extends StatelessWidget {
  const AccountColorField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.accountColor, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: CPSpacing.sm),
        Wrap(
          spacing: CPSpacing.sm,
          runSpacing: CPSpacing.sm,
          children: [
            for (final colorValue in AccountVisuals.colors)
              _ColorSwatch(
                colorValue: colorValue,
                isSelected: value == colorValue,
                onTap: () => onChanged(colorValue),
              ),
          ],
        ),
      ],
    );
  }
}

class AccountPaymentMethodsField extends StatelessWidget {
  const AccountPaymentMethodsField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = value.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.accountPaymentMethods,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: CPSpacing.xs),
        Text(
          l10n.accountPaymentMethodsHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: CPSpacing.sm),
        Wrap(
          spacing: CPSpacing.sm,
          runSpacing: CPSpacing.sm,
          children: [
            for (final method in LibyanPaymentMethodCatalog.methods)
              FilterChip(
                label: Text(method.displayName),
                avatar: const Icon(Icons.payments_outlined, size: 18),
                selected: selected.contains(method.id),
                onSelected: (isSelected) {
                  final next = {...selected};
                  if (isSelected) {
                    next.add(method.id);
                  } else {
                    next.remove(method.id);
                  }

                  onChanged(next.toList(growable: false)..sort());
                },
              ),
          ],
        ),
      ],
    );
  }
}

List<TextInputFormatter> get currencyFormatters => [
  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
  LengthLimitingTextInputFormatter(3),
  TextInputFormatter.withFunction((oldValue, newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }),
];

class _AccountTypePicker extends StatelessWidget {
  const _AccountTypePicker({required this.selected});

  final AccountType selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: CPSpacing.page,
        children: [
          for (final type in AccountType.values)
            CPListTile(
              title: AccountTypeLabels.label(l10n, type),
              selected: type == selected,
              trailing: type == selected
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(context).pop(type),
            ),
        ],
      ),
    );
  }
}

class _AccountIconPicker extends StatelessWidget {
  const _AccountIconPicker({required this.selectedKey});

  final String selectedKey;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: CPSpacing.page,
        childAspectRatio: 3.6,
        mainAxisSpacing: CPSpacing.sm,
        crossAxisSpacing: CPSpacing.sm,
        children: [
          for (final option in AccountVisuals.icons)
            CPCard(
              variant: CPCardVariant.interactive,
              onTap: () => Navigator.of(context).pop(option.key),
              child: Row(
                children: [
                  Icon(option.icon),
                  const SizedBox(width: CPSpacing.sm),
                  Expanded(child: Text(option.label)),
                  if (option.key == selectedKey)
                    const Icon(Icons.check_rounded),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.colorValue,
    required this.isSelected,
    required this.onTap,
  });

  final int colorValue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CPRadius.full),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: isSelected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}
