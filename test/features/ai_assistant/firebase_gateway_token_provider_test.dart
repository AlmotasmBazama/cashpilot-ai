import 'dart:async';

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_readiness.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/gateway/ai_conversation_gateway.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/ai_provider_egress_test_guard.dart';

void main() {
  test('raw Auth refresh rejection maps to gateway auth required', () async {
    final provider = _provider(
      idTokenError: FirebaseAuthException(code: 'user-token-expired'),
    );

    await expectLater(
      provider.freshTokens(egressGuard: testAiProviderEgressGuard),
      throwsA(_gatewayFailure(AiGatewayFailureCode.authenticationNotReady)),
    );
  });

  test('raw Auth network failure maps to gateway unavailable', () async {
    final provider = _provider(
      idTokenError: FirebaseAuthException(code: 'network-request-failed'),
    );

    await expectLater(
      provider.freshTokens(egressGuard: testAiProviderEgressGuard),
      throwsA(_gatewayFailure(AiGatewayFailureCode.networkFailure)),
    );
  });

  test('never-completing Auth refresh is bounded and typed safely', () async {
    final pending = Completer<String?>();
    final provider = _provider(
      idTokenFuture: pending.future,
      tokenTimeout: const Duration(milliseconds: 2),
    );

    await expectLater(
      provider.freshTokens(egressGuard: testAiProviderEgressGuard),
      throwsA(_gatewayFailure(AiGatewayFailureCode.authenticationNotReady)),
    );
  });

  test('raw transient App Check failure maps to unavailable', () async {
    final provider = _provider(
      appCheckError: FirebaseException(
        plugin: 'firebase_app_check',
        code: 'token-error',
      ),
    );

    await expectLater(
      provider.freshTokens(egressGuard: testAiProviderEgressGuard),
      throwsA(_gatewayFailure(AiGatewayFailureCode.appCheckUnavailable)),
    );
  });

  test('confirmed App Check rejection remains distinct', () async {
    final provider = _provider(
      appCheckError: FirebaseException(
        plugin: 'firebase_app_check',
        code: 'permission-denied',
      ),
    );

    await expectLater(
      provider.freshTokens(egressGuard: testAiProviderEgressGuard),
      throwsA(_gatewayFailure(AiGatewayFailureCode.appCheckRejected)),
    );
  });

  test('raw App Check network failure maps to gateway unavailable', () async {
    final provider = _provider(
      appCheckError: FirebaseException(
        plugin: 'firebase_app_check',
        code: 'server-unreachable',
      ),
    );

    await expectLater(
      provider.freshTokens(egressGuard: testAiProviderEgressGuard),
      throwsA(_gatewayFailure(AiGatewayFailureCode.networkFailure)),
    );
  });

  test(
    'never-completing App Check refresh is bounded and typed safely',
    () async {
      final pending = Completer<String?>();
      final provider = _provider(
        appCheckFuture: pending.future,
        tokenTimeout: const Duration(milliseconds: 2),
      );

      await expectLater(
        provider.freshTokens(egressGuard: testAiProviderEgressGuard),
        throwsA(_gatewayFailure(AiGatewayFailureCode.appCheckTimedOut)),
      );
    },
  );

  test(
    'valid native tokens are returned without exposing raw failures',
    () async {
      final provider = _provider();

      final tokens = await provider.freshTokens(
        egressGuard: testAiProviderEgressGuard,
      );

      expect(tokens.firebaseIdToken, 'firebase-id-token');
      expect(tokens.appCheckToken, 'app-check-token');
    },
  );

  test('revocation while waiting prevents late token egress', () async {
    final appCheckGate = Completer<String?>();
    final guard = _RevocableEgressGuard();
    final provider = _provider(appCheckFuture: appCheckGate.future);

    final pending = provider.freshTokens(egressGuard: guard);
    await Future<void>.delayed(Duration.zero);
    guard.active = false;
    appCheckGate.complete('late-app-check-token');

    await expectLater(
      pending,
      throwsA(isA<AiProviderEgressRevokedException>()),
    );
  });
}

FirebaseAiGatewayTokenProvider _provider({
  Object? idTokenError,
  Object? appCheckError,
  Future<String?>? idTokenFuture,
  Future<String?>? appCheckFuture,
  Duration tokenTimeout = const Duration(seconds: 10),
}) {
  final appCheck = _FakeFirebaseAppCheck(
    error: appCheckError,
    tokenFuture: appCheckFuture,
  );
  final activation = FirebaseAppCheckActivationController(
    activator: const _ReadyActivator(),
    timeout: tokenTimeout,
  );
  final readiness = FirebaseAppCheckReadinessCoordinator(
    activationController: activation,
    tokenLoader: ({required forceRefresh}) => appCheck.getToken(forceRefresh),
    totalTimeout: tokenTimeout,
    tokenAttemptTimeout: tokenTimeout,
    tokenRetryDelays: const <Duration>[Duration.zero],
  );
  return FirebaseAiGatewayTokenProvider(
    auth: _FakeFirebaseAuth(
      _FakeFirebaseUser(error: idTokenError, tokenFuture: idTokenFuture),
    ),
    appCheckReadiness: readiness,
    tokenTimeout: tokenTimeout,
  );
}

Matcher _gatewayFailure(AiGatewayFailureCode code) => isA<AiGatewayException>()
    .having((failure) => failure.code, 'code', code)
    .having(
      (failure) => failure.toString(),
      'safe string',
      isNot(contains('firebase-id-token')),
    );

final class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.user);

  final User user;

  @override
  User? get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeFirebaseUser implements User {
  _FakeFirebaseUser({this.error, this.tokenFuture});

  final Object? error;
  final Future<String?>? tokenFuture;

  @override
  String get uid => 'test-user';

  @override
  bool get isAnonymous => false;

  @override
  String? get tenantId => null;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (error case final error?) throw error;
    if (tokenFuture case final tokenFuture?) return tokenFuture;
    return 'firebase-id-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeFirebaseAppCheck implements FirebaseAppCheck {
  _FakeFirebaseAppCheck({this.error, this.tokenFuture});

  final Object? error;
  final Future<String?>? tokenFuture;

  @override
  Future<String?> getToken([bool? forceRefresh]) async {
    if (error case final error?) throw error;
    if (tokenFuture case final tokenFuture?) return tokenFuture;
    return 'app-check-token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ReadyActivator implements FirebaseAppCheckActivator {
  const _ReadyActivator();

  @override
  Future<void> activate() async {}
}

final class _RevocableEgressGuard implements AiProviderEgressGuard {
  var active = true;

  @override
  AuthSessionIdentity get expectedAuthSession => const AuthSessionIdentity(
    uid: 'test-user',
    isAnonymous: false,
    authSessionGeneration: 1,
    tenantId: null,
  );

  @override
  void assertActive() {
    if (!active) throw const AiProviderEgressRevokedException();
  }

  @override
  Future<T> runSerializedAuthOperation<T>(Future<T> Function() operation) {
    assertActive();
    return operation();
  }
}
