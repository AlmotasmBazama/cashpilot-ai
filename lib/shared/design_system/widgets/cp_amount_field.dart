import 'package:flutter/material.dart';

import 'cp_text_field.dart';

class CPAmountField extends StatelessWidget {
  const CPAmountField({
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.currencyCode,
    this.prefix,
    this.suffix,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? currencyCode;
  final Widget? prefix;
  final Widget? suffix;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final suffixWidget =
        suffix ??
        (currencyCode == null || currencyCode!.isEmpty
            ? null
            : _CurrencySuffix(currencyCode: currencyCode!));

    return CPTextField(
      controller: controller,
      initialValue: initialValue,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      prefix: prefix,
      suffix: suffixWidget,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
    );
  }
}

class _CurrencySuffix extends StatelessWidget {
  const _CurrencySuffix({required this.currencyCode});

  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: Text(
        currencyCode,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
