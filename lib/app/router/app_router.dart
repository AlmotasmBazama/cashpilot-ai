import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/providers/auth_providers.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/pages/email_verification_screen.dart';
import '../../features/auth/presentation/pages/forgot_password_screen.dart';
import '../../features/auth/presentation/pages/guest_mode_info_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/onboarding_screen.dart';
import '../../features/auth/presentation/pages/profile_completion_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/auth/presentation/pages/splash_screen.dart';
import '../../features/auth/presentation/pages/welcome_screen.dart';
import '../../features/accounts/presentation/pages/account_details_screen.dart';
import '../../features/accounts/presentation/pages/accounts_screen.dart';
import '../../features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import '../../features/app_shell/presentation/pages/app_shell_page.dart';
import '../../features/budgets/presentation/pages/budgets_screen.dart';
import '../../features/categories/presentation/pages/categories_screen.dart';
import '../../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../../features/goals/presentation/pages/goals_screen.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/reports/presentation/pages/reports_screen.dart';
import '../../features/receipts/presentation/pages/receipt_capture_screen.dart';
import '../../features/receipts/presentation/pages/receipt_review_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';
import '../../features/settings/presentation/pages/product_policy_screens.dart';
import '../../features/payees/presentation/pages/payee_details_screen.dart';
import '../../features/payees/presentation/pages/payees_screen.dart';
import '../../features/transactions/presentation/pages/transaction_details_screen.dart';
import '../../features/transactions/presentation/pages/transactions_screen.dart';
import '../../features/transactions/presentation/pages/transfer_screen.dart';
import '../../shared/presentation/pages/app_error_page.dart';
import 'app_route_paths.dart';
import 'navigation_transition_diagnostics.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AppRouterRefreshNotifier();
  final redirectState = AppRouterRedirectState(
    authState: ref.read(authStateProvider),
    onboardingCompleted: ref.read(onboardingCompletedProvider),
  );
  final diagnostics = ref.read(navigationTransitionDiagnosticsProvider);
  ref
    ..listen<AsyncValue<AuthUser?>>(authStateProvider, (_, next) {
      redirectState.updateAuth(next);
      refresh.notify();
    })
    ..listen<bool>(onboardingCompletedProvider, (_, next) {
      redirectState.updateOnboarding(next);
      refresh.notify();
    });

  late final GoRouter router;
  var previousPath = AppRoutePaths.splash;
  router = GoRouter(
    initialLocation: AppRoutePaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final decision = redirectDecisionForAppRoute(
        state.uri.path,
        authState: redirectState.authState,
        onboardingCompleted: redirectState.onboardingCompleted,
      );
      if (decision case final decision?) {
        diagnostics.markNextTransition(
          cause: decision.cause,
          safeReason: decision.safeReason,
          expectedPath: decision.path,
        );
      }
      return decision?.path;
    },
    routes: [
      GoRoute(
        path: AppRoutePaths.splash,
        name: AppRouteNames.splash,
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.onboarding,
        name: AppRouteNames.onboarding,
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.welcome,
        name: AppRouteNames.welcome,
        pageBuilder: (context, state) =>
            _fadePage(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.login,
        name: AppRouteNames.login,
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.register,
        name: AppRouteNames.register,
        pageBuilder: (context, state) =>
            _fadePage(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.forgotPassword,
        name: AppRouteNames.forgotPassword,
        pageBuilder: (context, state) =>
            _fadePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.emailVerification,
        name: AppRouteNames.emailVerification,
        pageBuilder: (context, state) =>
            _fadePage(state, const EmailVerificationScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.profileCompletion,
        name: AppRouteNames.profileCompletion,
        pageBuilder: (context, state) =>
            _fadePage(state, const ProfileCompletionScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.guestInfo,
        name: AppRouteNames.guestInfo,
        pageBuilder: (context, state) =>
            _fadePage(state, const GuestModeInfoScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.privacyPolicy,
        name: AppRouteNames.privacyPolicy,
        pageBuilder: (context, state) =>
            _fadePage(state, const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.termsOfUse,
        name: AppRouteNames.termsOfUse,
        pageBuilder: (context, state) =>
            _fadePage(state, const TermsOfUseScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.home,
        name: AppRouteNames.home,
        redirect: (_, _) => AppRoutePaths.dashboard,
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShellPage(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutePaths.dashboard,
            name: AppRouteNames.dashboard,
            pageBuilder: (context, state) =>
                _fadePage(state, const DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.accounts,
            name: AppRouteNames.accounts,
            pageBuilder: (context, state) =>
                _fadePage(state, const AccountsScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.accountDetails,
            name: AppRouteNames.accountDetails,
            pageBuilder: (context, state) => _fadePage(
              state,
              AccountDetailsScreen(
                accountId: state.pathParameters['accountId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutePaths.transactions,
            name: AppRouteNames.transactions,
            pageBuilder: (context, state) =>
                _fadePage(state, const TransactionsScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.transactionDetails,
            name: AppRouteNames.transactionDetails,
            pageBuilder: (context, state) => _fadePage(
              state,
              TransactionDetailsScreen(
                transactionId: state.pathParameters['transactionId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutePaths.categories,
            name: AppRouteNames.categories,
            pageBuilder: (context, state) =>
                _fadePage(state, const CategoriesScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.reports,
            name: AppRouteNames.reports,
            pageBuilder: (context, state) =>
                _fadePage(state, const ReportsScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.budgets,
            name: AppRouteNames.budgets,
            pageBuilder: (context, state) =>
                _fadePage(state, const BudgetsScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.goals,
            name: AppRouteNames.goals,
            pageBuilder: (context, state) =>
                _fadePage(state, const GoalsScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.payees,
            name: AppRouteNames.payees,
            pageBuilder: (context, state) =>
                _fadePage(state, const PayeesScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.payeeDetails,
            name: AppRouteNames.payeeDetails,
            pageBuilder: (context, state) => _fadePage(
              state,
              PayeeDetailsScreen(
                payeeId: state.pathParameters['payeeId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutePaths.aiAssistant,
            name: AppRouteNames.aiAssistant,
            pageBuilder: (context, state) =>
                _fadePage(state, const AiAssistantScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.transfer,
            name: AppRouteNames.transfer,
            pageBuilder: (context, state) =>
                _fadePage(state, const TransferScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.receiptCapture,
            name: AppRouteNames.receiptCapture,
            pageBuilder: (context, state) =>
                _fadePage(state, const ReceiptCaptureScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.receiptReview,
            name: AppRouteNames.receiptReview,
            pageBuilder: (context, state) => _fadePage(
              state,
              ReceiptReviewScreen(
                receiptId: state.pathParameters['receiptId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutePaths.settings,
            name: AppRouteNames.settings,
            pageBuilder: (context, state) =>
                _fadePage(state, const SettingsScreen()),
          ),
          GoRoute(
            path: AppRoutePaths.profile,
            name: AppRouteNames.profile,
            pageBuilder: (context, state) =>
                _fadePage(state, const ProfileScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppErrorPage(error: state.error),
  );

  void recordRouteChange() {
    final nextPath = router.routeInformationProvider.value.uri.path;
    diagnostics.recordLocationChange(
      previousPath: previousPath,
      nextPath: nextPath,
    );
    previousPath = nextPath;
  }

  router.routeInformationProvider.addListener(recordRouteChange);
  ref.onDispose(() {
    router.routeInformationProvider.removeListener(recordRouteChange);
    router.dispose();
    refresh.dispose();
  });
  return router;
}, name: 'appRouterProvider');

@immutable
class AppRouteRedirectDecision {
  const AppRouteRedirectDecision({
    required this.path,
    required this.cause,
    required this.safeReason,
  });

  final String path;
  final NavigationTransitionCause cause;
  final String safeReason;
}

class AppRouterRedirectState {
  AppRouterRedirectState({
    required AsyncValue<AuthUser?> authState,
    required bool onboardingCompleted,
  }) : _onboardingCompleted = onboardingCompleted {
    updateAuth(authState);
  }

  AsyncValue<AuthUser?> _authState = const AsyncLoading<AuthUser?>();
  bool _hasConfirmedAuth = false;
  bool _onboardingCompleted;

  AsyncValue<AuthUser?> get authState => _authState;
  bool get onboardingCompleted => _onboardingCompleted;

  void updateAuth(AsyncValue<AuthUser?> next) {
    if (next case AsyncData<AuthUser?>(:final value)) {
      _authState = AsyncData<AuthUser?>(value);
      _hasConfirmedAuth = true;
      return;
    }
    if (next case AsyncError<AuthUser?>()) {
      // A prior authenticated identity must never remain routable after the
      // authoritative Auth source fails. Preserve the error/loading boundary
      // so protected routes redirect to the safe splash state.
      _authState = next;
      _hasConfirmedAuth = false;
      return;
    }
    if (!_hasConfirmedAuth) {
      _authState = const AsyncLoading<AuthUser?>();
    }
  }

  void updateOnboarding(bool value) {
    _onboardingCompleted = value;
  }
}

AppRouteRedirectDecision? redirectDecisionForAppRoute(
  String path, {
  required AsyncValue<AuthUser?> authState,
  required bool onboardingCompleted,
}) {
  final AuthUser? user;
  if (authState case AsyncData<AuthUser?>(:final value)) {
    user = value;
  } else {
    return path == AppRoutePaths.splash
        ? null
        : const AppRouteRedirectDecision(
            path: AppRoutePaths.splash,
            cause: NavigationTransitionCause.authInitializing,
            safeReason: 'initial_auth_state_pending',
          );
  }

  if (user == null) {
    if (!onboardingCompleted && path != AppRoutePaths.onboarding) {
      return const AppRouteRedirectDecision(
        path: AppRoutePaths.onboarding,
        cause: NavigationTransitionCause.onboardingIncomplete,
        safeReason: 'onboarding_incomplete',
      );
    }

    if (onboardingCompleted && path == AppRoutePaths.onboarding) {
      return const AppRouteRedirectDecision(
        path: AppRoutePaths.welcome,
        cause: NavigationTransitionCause.authSignedOut,
        safeReason: 'signed_out_after_onboarding',
      );
    }

    if (path == AppRoutePaths.splash ||
        path == AppRoutePaths.home ||
        !_isPublicAuthPath(path)) {
      return const AppRouteRedirectDecision(
        path: AppRoutePaths.welcome,
        cause: NavigationTransitionCause.authSignedOut,
        safeReason: 'definitive_signed_out_state',
      );
    }

    return null;
  }

  if (user.needsEmailVerification) {
    return path == AppRoutePaths.emailVerification
        ? null
        : const AppRouteRedirectDecision(
            path: AppRoutePaths.emailVerification,
            cause: NavigationTransitionCause.emailVerificationRequired,
            safeReason: 'email_verification_required',
          );
  }

  if (!user.isAnonymous && !user.isProfileComplete) {
    return path == AppRoutePaths.profileCompletion
        ? null
        : const AppRouteRedirectDecision(
            path: AppRoutePaths.profileCompletion,
            cause: NavigationTransitionCause.profileCompletionRequired,
            safeReason: 'profile_completion_required',
          );
  }

  if (_isPublicAuthPath(path) ||
      path == AppRoutePaths.emailVerification ||
      path == AppRoutePaths.splash) {
    return const AppRouteRedirectDecision(
      path: AppRoutePaths.dashboard,
      cause: NavigationTransitionCause.authStateConfirmed,
      safeReason: 'authenticated_entry_route',
    );
  }

  return null;
}

class _AppRouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

bool _isPublicAuthPath(String path) {
  return {
    AppRoutePaths.onboarding,
    AppRoutePaths.welcome,
    AppRoutePaths.login,
    AppRoutePaths.register,
    AppRoutePaths.forgotPassword,
    AppRoutePaths.guestInfo,
    AppRoutePaths.privacyPolicy,
    AppRoutePaths.termsOfUse,
  }.contains(path);
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
  );
}
