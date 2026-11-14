import 'package:cashpilot_ai/app/router/app_route_paths.dart';
import 'package:cashpilot_ai/app/router/app_router.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('public route constants', () {
    test('path literals remain compatible', () {
      expect(
        <String, String>{
          'home': AppRoutePaths.home,
          'splash': AppRoutePaths.splash,
          'onboarding': AppRoutePaths.onboarding,
          'welcome': AppRoutePaths.welcome,
          'login': AppRoutePaths.login,
          'register': AppRoutePaths.register,
          'forgotPassword': AppRoutePaths.forgotPassword,
          'emailVerification': AppRoutePaths.emailVerification,
          'profileCompletion': AppRoutePaths.profileCompletion,
          'guestInfo': AppRoutePaths.guestInfo,
          'dashboard': AppRoutePaths.dashboard,
          'accounts': AppRoutePaths.accounts,
          'accountDetails': AppRoutePaths.accountDetails,
          'transactions': AppRoutePaths.transactions,
          'transactionDetails': AppRoutePaths.transactionDetails,
          'categories': AppRoutePaths.categories,
          'reports': AppRoutePaths.reports,
          'budgets': AppRoutePaths.budgets,
          'goals': AppRoutePaths.goals,
          'payees': AppRoutePaths.payees,
          'payeeDetails': AppRoutePaths.payeeDetails,
          'aiAssistant': AppRoutePaths.aiAssistant,
          'transfer': AppRoutePaths.transfer,
          'receiptCapture': AppRoutePaths.receiptCapture,
          'receiptReview': AppRoutePaths.receiptReview,
          'settings': AppRoutePaths.settings,
          'profile': AppRoutePaths.profile,
          'privacyPolicy': AppRoutePaths.privacyPolicy,
          'termsOfUse': AppRoutePaths.termsOfUse,
        },
        <String, String>{
          'home': '/',
          'splash': '/splash',
          'onboarding': '/onboarding',
          'welcome': '/welcome',
          'login': '/login',
          'register': '/register',
          'forgotPassword': '/forgot-password',
          'emailVerification': '/email-verification',
          'profileCompletion': '/profile-completion',
          'guestInfo': '/guest',
          'dashboard': '/dashboard',
          'accounts': '/accounts',
          'accountDetails': '/accounts/:accountId',
          'transactions': '/transactions',
          'transactionDetails': '/transactions/:transactionId',
          'categories': '/categories',
          'reports': '/reports',
          'budgets': '/budgets',
          'goals': '/goals',
          'payees': '/payees',
          'payeeDetails': '/payees/:payeeId',
          'aiAssistant': '/ai-assistant',
          'transfer': '/transfer',
          'receiptCapture': '/receipts/scan',
          'receiptReview': '/receipts/:receiptId/review',
          'settings': '/settings',
          'profile': '/profile',
          'privacyPolicy': '/privacy',
          'termsOfUse': '/terms',
        },
      );
      expect(
        AppRoutePaths.receiptReviewPath('receipt-42'),
        '/receipts/receipt-42/review',
      );
    });

    test('name literals remain compatible', () {
      expect(
        <String, String>{
          'home': AppRouteNames.home,
          'splash': AppRouteNames.splash,
          'onboarding': AppRouteNames.onboarding,
          'welcome': AppRouteNames.welcome,
          'login': AppRouteNames.login,
          'register': AppRouteNames.register,
          'forgotPassword': AppRouteNames.forgotPassword,
          'emailVerification': AppRouteNames.emailVerification,
          'profileCompletion': AppRouteNames.profileCompletion,
          'guestInfo': AppRouteNames.guestInfo,
          'dashboard': AppRouteNames.dashboard,
          'accounts': AppRouteNames.accounts,
          'accountDetails': AppRouteNames.accountDetails,
          'transactions': AppRouteNames.transactions,
          'transactionDetails': AppRouteNames.transactionDetails,
          'categories': AppRouteNames.categories,
          'reports': AppRouteNames.reports,
          'budgets': AppRouteNames.budgets,
          'goals': AppRouteNames.goals,
          'payees': AppRouteNames.payees,
          'payeeDetails': AppRouteNames.payeeDetails,
          'aiAssistant': AppRouteNames.aiAssistant,
          'transfer': AppRouteNames.transfer,
          'receiptCapture': AppRouteNames.receiptCapture,
          'receiptReview': AppRouteNames.receiptReview,
          'settings': AppRouteNames.settings,
          'profile': AppRouteNames.profile,
          'privacyPolicy': AppRouteNames.privacyPolicy,
          'termsOfUse': AppRouteNames.termsOfUse,
        },
        <String, String>{
          'home': 'home',
          'splash': 'splash',
          'onboarding': 'onboarding',
          'welcome': 'welcome',
          'login': 'login',
          'register': 'register',
          'forgotPassword': 'forgotPassword',
          'emailVerification': 'emailVerification',
          'profileCompletion': 'profileCompletion',
          'guestInfo': 'guestInfo',
          'dashboard': 'dashboard',
          'accounts': 'accounts',
          'accountDetails': 'accountDetails',
          'transactions': 'transactions',
          'transactionDetails': 'transactionDetails',
          'categories': 'categories',
          'reports': 'reports',
          'budgets': 'budgets',
          'goals': 'goals',
          'payees': 'payees',
          'payeeDetails': 'payeeDetails',
          'aiAssistant': 'aiAssistant',
          'transfer': 'transfer',
          'receiptCapture': 'receiptCapture',
          'receiptReview': 'receiptReview',
          'settings': 'settings',
          'profile': 'profile',
          'privacyPolicy': 'privacyPolicy',
          'termsOfUse': 'termsOfUse',
        },
      );
    });
  });

  group('configured route mappings', () {
    late ProviderContainer container;
    late GoRouter router;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((_) => Stream.value(_completeUser)),
          onboardingCompletedProvider.overrideWith((_) => true),
        ],
      );
      router = container.read(appRouterProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('selected public names stay mapped to their paths', () {
      final configuredByName = <String, String>{
        for (final route in RouteBase.routesRecursively(
          router.configuration.routes,
        ).whereType<GoRoute>())
          ?route.name: route.path,
      };

      expect(configuredByName, containsPair(AppRouteNames.home, '/'));
      expect(
        configuredByName,
        containsPair(AppRouteNames.dashboard, '/dashboard'),
      );
      expect(
        configuredByName,
        containsPair(AppRouteNames.accountDetails, '/accounts/:accountId'),
      );
      expect(
        configuredByName,
        containsPair(
          AppRouteNames.transactionDetails,
          '/transactions/:transactionId',
        ),
      );
      expect(
        configuredByName,
        containsPair(AppRouteNames.payeeDetails, '/payees/:payeeId'),
      );
      expect(
        configuredByName,
        containsPair(
          AppRouteNames.receiptReview,
          '/receipts/:receiptId/review',
        ),
      );
      expect(
        configuredByName,
        containsPair(AppRouteNames.privacyPolicy, '/privacy'),
      );
      expect(
        configuredByName,
        containsPair(AppRouteNames.termsOfUse, '/terms'),
      );
    });

    test('dynamic named locations preserve path parameter placement', () {
      expect(
        router.namedLocation(
          AppRouteNames.accountDetails,
          pathParameters: const {'accountId': 'account-42'},
        ),
        '/accounts/account-42',
      );
      expect(
        router.namedLocation(
          AppRouteNames.transactionDetails,
          pathParameters: const {'transactionId': 'transaction-42'},
        ),
        '/transactions/transaction-42',
      );
      expect(
        router.namedLocation(
          AppRouteNames.receiptReview,
          pathParameters: const {'receiptId': 'receipt-42'},
        ),
        '/receipts/receipt-42/review',
      );
    });
  });

  group('redirect destinations', () {
    test('authentication initialization fails closed to splash', () {
      expect(
        _redirectPath(
          AppRoutePaths.dashboard,
          authState: const AsyncLoading<AuthUser?>(),
        ),
        AppRoutePaths.splash,
      );
      expect(
        _redirectPath(
          AppRoutePaths.splash,
          authState: const AsyncLoading<AuthUser?>(),
        ),
        isNull,
      );
    });

    test('signed-out destinations preserve the onboarding boundary', () {
      expect(
        _redirectPath(
          AppRoutePaths.dashboard,
          authState: const AsyncData<AuthUser?>(null),
          onboardingCompleted: false,
        ),
        AppRoutePaths.onboarding,
      );
      expect(
        _redirectPath(
          AppRoutePaths.dashboard,
          authState: const AsyncData<AuthUser?>(null),
        ),
        AppRoutePaths.welcome,
      );
      expect(
        _redirectPath(
          AppRoutePaths.login,
          authState: const AsyncData<AuthUser?>(null),
        ),
        isNull,
      );
    });

    test('account readiness gates keep their current destinations', () {
      expect(
        _redirectPath(
          AppRoutePaths.dashboard,
          authState: const AsyncData<AuthUser?>(_unverifiedUser),
        ),
        AppRoutePaths.emailVerification,
      );
      expect(
        _redirectPath(
          AppRoutePaths.dashboard,
          authState: const AsyncData<AuthUser?>(_incompleteProfileUser),
        ),
        AppRoutePaths.profileCompletion,
      );
    });

    test('ready users leave entry routes and retain protected routes', () {
      expect(
        _redirectPath(
          AppRoutePaths.login,
          authState: const AsyncData<AuthUser?>(_completeUser),
        ),
        AppRoutePaths.dashboard,
      );
      expect(
        _redirectPath(
          AppRoutePaths.aiAssistant,
          authState: const AsyncData<AuthUser?>(_completeUser),
        ),
        isNull,
      );
    });
  });
}

String? _redirectPath(
  String path, {
  required AsyncValue<AuthUser?> authState,
  bool onboardingCompleted = true,
}) => redirectDecisionForAppRoute(
  path,
  authState: authState,
  onboardingCompleted: onboardingCompleted,
)?.path;

const _unverifiedUser = AuthUser(
  uid: 'unverified-user',
  email: 'unverified@example.invalid',
  emailVerified: false,
  isAnonymous: false,
);

const _incompleteProfileUser = AuthUser(
  uid: 'incomplete-profile-user',
  email: 'incomplete@example.invalid',
  emailVerified: true,
  isAnonymous: false,
);

const _completeUser = AuthUser(
  uid: 'complete-user',
  email: 'complete@example.invalid',
  displayName: 'Complete User',
  emailVerified: true,
  isAnonymous: false,
  currency: 'LYD',
  language: 'en',
  country: 'LY',
  timezone: 'Africa/Tripoli',
);
