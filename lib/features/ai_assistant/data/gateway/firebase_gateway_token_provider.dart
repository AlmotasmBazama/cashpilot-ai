import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/firebase/firebase_app_check_activation.dart';
import '../../../../core/firebase/firebase_app_check_readiness.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/gateway/ai_conversation_gateway.dart';

class AiGatewayTokens {
  const AiGatewayTokens({
    required this.firebaseIdToken,
    required this.appCheckToken,
  });

  final String firebaseIdToken;
  final String appCheckToken;
}

abstract interface class AiGatewayTokenProvider {
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  });
}

abstract interface class AiGatewayAppCheckRejectionReporter {
  void reportAppCheckRejected();
}

class FirebaseAiGatewayTokenProvider
    implements AiGatewayTokenProvider, AiGatewayAppCheckRejectionReporter {
  FirebaseAiGatewayTokenProvider({
    required FirebaseAuth auth,
    FirebaseAppCheckReadinessCoordinator? appCheckReadiness,
    FirebaseAppCheck? appCheck,
    this.tokenTimeout = const Duration(seconds: 10),
  }) : _auth = auth,
       _appCheckReadiness =
           appCheckReadiness ??
           FirebaseAppCheckReadinessCoordinator(
             activationController: defaultFirebaseAppCheckActivationController,
             tokenLoader: ({required forceRefresh}) =>
                 appCheck!.getToken(forceRefresh),
             totalTimeout: tokenTimeout,
             tokenAttemptTimeout: tokenTimeout,
           ),
       assert(appCheckReadiness != null || appCheck != null),
       assert(tokenTimeout > Duration.zero);

  final FirebaseAuth _auth;
  final FirebaseAppCheckReadinessCoordinator _appCheckReadiness;

  FirebaseAppCheckReadinessCoordinator get appCheckReadiness =>
      _appCheckReadiness;

  /// Bounds native verification calls before any gateway request can start.
  /// A timeout means verification was unreachable, not that a credential was
  /// rejected, so it maps to [AiGatewayFailureCode.appCheckTimedOut].
  final Duration tokenTimeout;

  @override
  Future<AiGatewayTokens> freshTokens({
    required AiProviderEgressGuard egressGuard,
  }) {
    return egressGuard.runSerializedAuthOperation(() async {
      egressGuard.assertActive();
      final user = _auth.currentUser;
      final expected = egressGuard.expectedAuthSession;
      if (user == null ||
          user.uid != expected.uid ||
          user.isAnonymous != expected.isAnonymous ||
          user.tenantId != expected.tenantId) {
        throw const AiProviderEgressRevokedException();
      }

      // Keep the guard immediately adjacent to both token-producing native
      // calls. Neither token may be silently acquired for a replacement user.
      egressGuard.assertActive();
      final idToken = await _freshIdToken(user);
      egressGuard.assertActive();
      if (idToken == null || idToken.trim().isEmpty) {
        throw const AiGatewayException(
          code: AiGatewayFailureCode.gatewayAuthenticationRequired,
          safeMessage: 'Firebase authentication could not be refreshed.',
        );
      }

      egressGuard.assertActive();
      final appCheckToken = await _readyAppCheckToken();
      egressGuard.assertActive();
      return AiGatewayTokens(
        firebaseIdToken: idToken,
        appCheckToken: appCheckToken,
      );
    });
  }

  @override
  void reportAppCheckRejected() => _appCheckReadiness.reportRejected();

  Future<String?> _freshIdToken(User user) async {
    try {
      return await user.getIdToken(true).timeout(tokenTimeout);
    } on FirebaseAuthException catch (error) {
      if (_isNetworkFailure(error.code, error.message)) {
        throw _networkFailure();
      }
      throw _authenticationFailure();
    } on TimeoutException {
      throw _authenticationFailure();
    } on Object catch (error) {
      if (_isNetworkFailure('', error.toString())) {
        throw _networkFailure();
      }
      throw _authenticationFailure();
    }
  }

  Future<String> _readyAppCheckToken() async {
    try {
      return await _appCheckReadiness.getToken();
    } on FirebaseAppCheckReadinessCancelledException {
      throw const AiProviderEgressRevokedException();
    } on FirebaseAppCheckReadinessException catch (failure) {
      throw switch (failure.reason) {
        FirebaseAppCheckReadinessFailureReason.rejected =>
          const AiGatewayException(
            code: AiGatewayFailureCode.appCheckRejected,
            safeMessage: 'Firebase App Check rejected this app instance.',
          ),
        FirebaseAppCheckReadinessFailureReason.timedOut =>
          const AiGatewayException(
            code: AiGatewayFailureCode.appCheckTimedOut,
            safeMessage: 'Firebase App Check readiness timed out.',
          ),
        FirebaseAppCheckReadinessFailureReason.networkUnavailable =>
          _networkFailure(),
        FirebaseAppCheckReadinessFailureReason.activationUnavailable ||
        FirebaseAppCheckReadinessFailureReason.tokenUnavailable =>
          _appCheckFailure(),
      };
    }
  }

  bool _isNetworkFailure(String code, String? message) {
    final normalized = '$code ${message ?? ''}'.toLowerCase();
    return const <String>[
      'network-request-failed',
      'network_error',
      'server-unreachable',
      'timeout',
      'timed out',
      'socket',
      'connection',
      'failed host lookup',
      'offline',
      'xmlhttprequest',
    ].any(normalized.contains);
  }

  AiGatewayException _authenticationFailure() => const AiGatewayException(
    code: AiGatewayFailureCode.authenticationNotReady,
    safeMessage: 'Firebase authentication is not ready.',
  );

  AiGatewayException _appCheckFailure() => const AiGatewayException(
    code: AiGatewayFailureCode.appCheckUnavailable,
    safeMessage: 'Firebase App Check is not ready.',
  );

  AiGatewayException _networkFailure() => const AiGatewayException(
    code: AiGatewayFailureCode.networkFailure,
    safeMessage: 'The verification service could not be reached.',
  );
}
