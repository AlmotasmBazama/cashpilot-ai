import 'dart:async';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/presentation/pages/login_screen.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/accessibility/acceptance_semantics.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'login exposes one safe idle ready submitting and typed failure marker',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(520, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rememberMeProvider.overrideWith((_) => false),
            authControllerProvider.overrideWith(_ControlledAuthController.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: CPTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder stateMarkers() => find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier?.startsWith(
                  'cashpilot_acceptance_login_state_',
                ) ==
                true,
      );
      final fields = find.byType(TextFormField);
      final submit = find.bySemanticsIdentifier(
        'cashpilot_acceptance_login_submit',
      );

      expect(cashPilotForceStopAcceptanceSemanticsEnabled, isTrue);
      expect(
        find.bySemanticsIdentifier('cashpilot_acceptance_login_state_idle'),
        findsOneWidget,
      );
      expect(stateMarkers(), findsOneWidget);

      await tester.enterText(fields.at(0), 'invalid');
      await tester.enterText(fields.at(1), '123');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();

      expect(
        find.bySemanticsIdentifier(
          'cashpilot_acceptance_login_state_failure_invalid_form',
        ),
        findsOneWidget,
      );
      expect(stateMarkers(), findsOneWidget);

      await tester.enterText(fields.at(0), 'acceptance@example.com');
      await tester.enterText(fields.at(1), 'SafePassword9');
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('cashpilot_acceptance_login_state_ready'),
        findsOneWidget,
      );
      expect(stateMarkers(), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      final controller =
          container.read(authControllerProvider.notifier)
              as _ControlledAuthController;
      await tester.tap(submit);
      await tester.pump();

      expect(
        find.bySemanticsIdentifier(
          'cashpilot_acceptance_login_state_submitting',
        ),
        findsOneWidget,
      );
      expect(stateMarkers(), findsOneWidget);

      controller.failure.complete(
        const Failure(message: 'Safe test failure.', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier(
          'cashpilot_acceptance_login_state_failure_permission_denied',
        ),
        findsOneWidget,
      );
      expect(stateMarkers(), findsOneWidget);
      expect(
        stateMarkers().evaluate().single.widget.toString(),
        isNot(contains('acceptance@example.com')),
      );
      expect(
        stateMarkers().evaluate().single.widget.toString(),
        isNot(contains('SafePassword9')),
      );
      semantics.dispose();
    },
  );
}

class _ControlledAuthController extends AuthController {
  final failure = Completer<Failure>();

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    state = const AsyncLoading<void>();
    final next = await failure.future;
    if (!ref.mounted) {
      return false;
    }
    state = AsyncError<void>(next, StackTrace.empty);
    return false;
  }
}
