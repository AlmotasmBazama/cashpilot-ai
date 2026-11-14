import 'dart:async';

import 'package:cashpilot_ai/app/router/app_route_paths.dart';
import 'package:cashpilot_ai/app/router/app_router.dart';
import 'package:cashpilot_ai/app/router/navigation_transition_diagnostics.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'confirmed signed-in state survives loading but fails closed on error',
    () {
      final state = AppRouterRedirectState(
        authState: const AsyncData<AuthUser?>(_signedInUser),
        onboardingCompleted: true,
      );

      state.updateAuth(const AsyncLoading<AuthUser?>());
      expect(
        redirectDecisionForAppRoute(
          AppRoutePaths.aiAssistant,
          authState: state.authState,
          onboardingCompleted: state.onboardingCompleted,
        ),
        isNull,
      );

      state.updateAuth(
        AsyncError<AuthUser?>(StateError('refresh'), StackTrace.empty),
      );
      final decision = redirectDecisionForAppRoute(
        AppRoutePaths.aiAssistant,
        authState: state.authState,
        onboardingCompleted: state.onboardingCompleted,
      );
      expect(decision?.path, AppRoutePaths.splash);
      expect(decision?.cause, NavigationTransitionCause.authInitializing);
    },
  );

  test('definitive sign-out redirects a protected AI route', () {
    final decision = redirectDecisionForAppRoute(
      AppRoutePaths.aiAssistant,
      authState: const AsyncData<AuthUser?>(null),
      onboardingCompleted: true,
    );

    expect(decision?.path, AppRoutePaths.welcome);
    expect(decision?.cause, NavigationTransitionCause.authSignedOut);
  });

  test('auth emissions do not reconstruct the GoRouter instance', () async {
    final authEvents = StreamController<AuthUser?>();
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((_) => authEvents.stream),
        onboardingCompletedProvider.overrideWith((_) => true),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    final initialRouter = container.read(appRouterProvider);
    authEvents.add(_signedInUser);
    await Future<void>.delayed(Duration.zero);
    final refreshedRouter = container.read(appRouterProvider);

    expect(identical(initialRouter, refreshedRouter), isTrue);
  });

  test('unknown route movement during an AI send is diagnosed', () {
    final diagnostics = NavigationTransitionDiagnostics()..beginAiSend();

    diagnostics.recordLocationChange(
      previousPath: AppRoutePaths.aiAssistant,
      nextPath: AppRoutePaths.dashboard,
    );
    diagnostics.endAiSend();

    expect(diagnostics.hasUnexpectedAiSendTransition, isTrue);
    expect(
      diagnostics.records.single.cause,
      NavigationTransitionCause.unknownUnexpected,
    );
  });

  test('approved assistant navigation is not diagnosed as unexpected', () {
    final diagnostics = NavigationTransitionDiagnostics()
      ..beginAiSend()
      ..markNextTransition(
        cause: NavigationTransitionCause.explicitAssistantNavigationTool,
        safeReason: 'approved_local_navigation_tool',
        expectedPath: AppRoutePaths.accounts,
      );

    diagnostics.recordLocationChange(
      previousPath: AppRoutePaths.aiAssistant,
      nextPath: AppRoutePaths.accounts,
    );
    diagnostics.endAiSend();

    expect(diagnostics.hasUnexpectedAiSendTransition, isFalse);
  });
}

const _signedInUser = AuthUser(
  uid: 'synthetic-account',
  email: 'test@example.invalid',
  displayName: 'Test User',
  emailVerified: true,
  isAnonymous: false,
  currency: 'LYD',
  language: 'en',
  country: 'LY',
  timezone: 'Africa/Tripoli',
);
