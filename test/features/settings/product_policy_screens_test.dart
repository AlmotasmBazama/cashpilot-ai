import 'package:cashpilot_ai/features/settings/presentation/pages/product_policy_screens.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('privacy placeholder renders in narrow RTL layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(locale: const Locale('ar'), home: const PrivacyPolicyScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('terms placeholder exposes neutral product sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(locale: const Locale('en'), home: const TermsOfUseScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Financial information'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({required Locale locale, required Widget home}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: CPTheme.dark(),
  home: home,
);
