import 'package:cashpilot_ai/features/app_shell/presentation/pages/app_shell_page.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/accessibility/acceptance_semantics.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'authenticated shell acceptance root covers compact tablet and desktop',
    (tester) async {
      final semantics = tester.ensureSemantics();
      expect(kReleaseMode, isFalse);
      expect(cashPilotForceStopAcceptanceSemanticsEnabled, isTrue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final size in const <Size>[
        Size(400, 800),
        Size(800, 800),
        Size(1200, 800),
      ]) {
        tester.view.physicalSize = size;
        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: <RouteBase>[
            GoRoute(
              path: '/dashboard',
              builder: (_, _) =>
                  const AppShellPage(child: ColoredBox(color: Colors.white)),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: CPTheme.light(),
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier(
            'cashpilot_acceptance_authenticated_shell',
          ),
          findsOneWidget,
          reason: 'The acceptance root must cover width ${size.width}.',
        );
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Transactions'), findsOneWidget);
        expect(find.text('AI Assistant'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Accounts'), findsNothing);
        expect(find.text('Reports'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
      }
      semantics.dispose();
    },
  );
}
