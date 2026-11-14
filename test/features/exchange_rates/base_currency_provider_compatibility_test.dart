import 'dart:io';

import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart'
    as owner;
import 'package:cashpilot_ai/features/settings/application/base_currency_provider.dart'
    as legacy;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Settings path re-exports the exact currency providers', () {
    expect(
      identical(
        legacy.baseCurrencyControllerProvider,
        owner.baseCurrencyControllerProvider,
      ),
      isTrue,
    );
    expect(
      identical(
        legacy.effectiveBaseCurrencyCodeProvider,
        owner.effectiveBaseCurrencyCodeProvider,
      ),
      isTrue,
    );

    final compatibilitySource = File(
      'lib/features/settings/application/base_currency_provider.dart',
    ).readAsStringSync();
    expect(
      compatibilitySource,
      contains(
        "export '../../exchange_rates/application/base_currency_provider.dart';",
      ),
    );
    expect(compatibilitySource, isNot(contains('final baseCurrency')));
    expect(
      compatibilitySource,
      isNot(contains('class BaseCurrencyController')),
    );
  });
}
