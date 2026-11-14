import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedExports = <String, Map<String, Set<String>>>{
    'lib/features/accounts/accounts_presentation.dart': {
      'presentation/support/account_type_labels.dart': {'AccountTypeLabels'},
      'presentation/support/account_visuals.dart': {'AccountVisuals'},
    },
    'lib/features/categories/categories_presentation.dart': {
      'presentation/support/category_localization.dart': {
        'CategoryLocalization',
      },
      'presentation/support/category_visuals.dart': {'CategoryVisuals'},
    },
    'lib/features/data_deletion/data_deletion_presentation.dart': {
      'presentation/widgets/delete_all_user_data_dialog.dart': {
        'AccountDeletionCredentials',
        'DeleteAllUserDataDialog',
      },
    },
    'lib/features/exchange_rates/exchange_rates_presentation.dart': {
      'presentation/widgets/exchange_rates_settings_section.dart': {
        'ExchangeRatesSettingsSection',
      },
    },
    'lib/features/payees/payees_presentation.dart': {
      'presentation/support/payee_type_labels.dart': {'PayeeTypeLabels'},
    },
    'lib/features/transactions/transactions_presentation.dart': {
      'presentation/support/transaction_ui_formatters.dart': {
        'TransactionUiFormatters',
      },
      'presentation/widgets/transaction_card.dart': {'TransactionCard'},
      'presentation/widgets/transaction_form_sheet.dart': {
        'TransactionFormSheet',
      },
    },
    'lib/features/settings/settings_presentation.dart': {
      'presentation/widgets/legacy_data_claim_section.dart': {
        'showLegacyDataClaimDialog',
      },
    },
  };

  test('public presentation facades expose only their intentional API', () {
    for (final MapEntry(:key, :value) in expectedExports.entries) {
      final source = File(key).readAsStringSync();
      final directives = RegExp(
        r"export\s+'([^']+)'\s+show\s+([^;]+);",
        multiLine: true,
      ).allMatches(source);
      final actual = <String, Set<String>>{
        for (final directive in directives)
          directive.group(1)!: directive
              .group(2)!
              .split(',')
              .map((symbol) => symbol.trim())
              .toSet(),
      };

      expect(actual, value, reason: '$key must remain a narrow public API.');
      expect(
        source
            .replaceAll(RegExp(r"export\s+'[^']+'\s+show\s+[^;]+;"), '')
            .trim(),
        isEmpty,
        reason: '$key must contain export directives only.',
      );
      expect(
        actual.keys,
        everyElement(startsWith('presentation/')),
        reason: '$key must expose presentation code only.',
      );
    }
  });

  test('the existing insights public API exposes FinancialInsightCard', () {
    final source = File(
      'lib/features/insights/insights.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("export 'presentation/widgets/financial_insight_card.dart';"),
    );
  });

  test('the former Settings deletion-dialog path stays source compatible', () {
    final source = File(
      'lib/features/settings/presentation/widgets/'
      'delete_all_user_data_dialog.dart',
    ).readAsStringSync();

    expect(
      source.trim(),
      "export '../../../data_deletion/data_deletion_presentation.dart'\n"
      '    show AccountDeletionCredentials, DeleteAllUserDataDialog;',
    );
  });
}
