// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_gateway_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/gateway/firebase_gateway_token_provider.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'support/android_live_groq_app_check.dart';

const _expectedRequestsPerMinute = int.fromEnvironment(
  'CASH_PILOT_AI_RATE_LIMIT_PER_MINUTE',
  defaultValue: 20,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android proves exact Groq gateway rate limit and per-user isolation',
    (tester) async {
      expect(
        AiRuntimeConfig.current.resolvedConversationProviderPreference,
        AiConversationProviderPreference.groq,
      );
      expect(AiGatewayFeatureFlags.current.aiGroqGatewayEnabled, isTrue);
      expect(AiGatewayFeatureFlags.current.aiGroqToolSelectionEnabled, isFalse);
      final runtime = AiGatewayRuntimeConfig.current;
      final baseUri = runtime.baseUri;
      expect(baseUri, isNotNull);
      final gatewayBaseUri = baseUri!;
      expect(_expectedRequestsPerMinute, greaterThan(0));
      expect(_expectedRequestsPerMinute, lessThanOrEqualTo(60));

      await const DefaultFirebaseInitializer().initialize();
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );

      final auth = FirebaseAuth.instance;
      final appCheck = FirebaseAppCheck.instance;
      final httpClient = http.Client();
      final syntheticUsers = <_SyntheticUser>[];
      var deletedUsers = 0;
      var signedOut = false;
      try {
        await awaitRegisteredAndroidAppCheckToken(appCheck);
        final firstUser = await _createSyntheticUser(auth, label: 'rate-a');
        syntheticUsers.add(firstUser);
        final firstTokens = await _freshGatewayTokens(
          auth: auth,
          appCheck: appCheck,
          user: firstUser.user,
        );
        print(
          'ANDROID_GROQ_LIVE_RATE_AUTH userIndex=0 synthetic=true '
          'appCheckAvailable=true tokensIssued=true',
        );

        final rateWindow = Stopwatch()..start();
        for (var index = 0; index < _expectedRequestsPerMinute; index += 1) {
          final result = await _sendDisabledToolSelection(
            httpClient: httpClient,
            baseUri: gatewayBaseUri,
            clientVersion: runtime.clientVersion,
            tokens: firstTokens,
            sequence: index,
            userLabel: 'a',
          );
          expect(result.status, 503);
          expect(result.code, 'gatewayUnavailable');
          expect(result.retryAfterSeconds, isNull);
        }

        final limited = await _sendDisabledToolSelection(
          httpClient: httpClient,
          baseUri: gatewayBaseUri,
          clientVersion: runtime.clientVersion,
          tokens: firstTokens,
          sequence: _expectedRequestsPerMinute,
          userLabel: 'a',
        );
        expect(limited.status, 429);
        expect(limited.code, 'groqRateLimited');
        expect(limited.retryAfterSeconds, isNotNull);
        expect(limited.retryAfterSeconds!, greaterThan(0));
        expect(limited.retryAfterSeconds!, lessThanOrEqualTo(60));
        rateWindow.stop();
        expect(rateWindow.elapsed, lessThan(const Duration(minutes: 1)));
        print(
          'ANDROID_GROQ_LIVE_RATE_LIMIT userIndex=0 '
          'allowed=$_expectedRequestsPerMinute limitedRequest='
          '${_expectedRequestsPerMinute + 1} status=429 '
          'code=groqRateLimited retryAfterPresent=true '
          'withinWindow=true noGroq=true',
        );

        await auth.signOut();
        final secondUser = await _createSyntheticUser(auth, label: 'rate-b');
        syntheticUsers.add(secondUser);
        final secondTokens = await _freshGatewayTokens(
          auth: auth,
          appCheck: appCheck,
          user: secondUser.user,
        );
        print(
          'ANDROID_GROQ_LIVE_RATE_AUTH userIndex=1 synthetic=true '
          'appCheckAvailable=true tokensIssued=true',
        );

        final isolated = await _sendDisabledToolSelection(
          httpClient: httpClient,
          baseUri: gatewayBaseUri,
          clientVersion: runtime.clientVersion,
          tokens: secondTokens,
          sequence: 0,
          userLabel: 'b',
        );
        expect(isolated.status, 503);
        expect(isolated.code, 'gatewayUnavailable');
        expect(isolated.retryAfterSeconds, isNull);
        print(
          'ANDROID_GROQ_LIVE_RATE_ISOLATION userIndex=1 firstStatus=503 '
          'code=gatewayUnavailable isolated=true noGroq=true',
        );
        print(
          'ANDROID_GROQ_LIVE_RATE_ACCEPTANCE completed=true '
          'exactLimit=$_expectedRequestsPerMinute limitedStatus=429 '
          'retryAfterPresent=true perUserIsolation=true noGroq=true',
        );
      } finally {
        httpClient.close();
        for (final synthetic in syntheticUsers.reversed) {
          if (await _deleteSyntheticUser(auth, synthetic)) {
            deletedUsers += 1;
          }
        }
        try {
          await auth.signOut();
          signedOut = auth.currentUser == null;
        } on Object {
          signedOut = false;
        }
        print(
          'ANDROID_GROQ_LIVE_RATE_AUTH_CLEANUP attempted='
          '${syntheticUsers.length} deleted=$deletedUsers signedOut=$signedOut',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<AiGatewayTokens> _freshGatewayTokens({
  required FirebaseAuth auth,
  required FirebaseAppCheck appCheck,
  required User user,
}) {
  final guard = _LiveUserEgressGuard(auth: auth, expectedUser: user);
  return FirebaseAiGatewayTokenProvider(
    auth: auth,
    appCheck: appCheck,
  ).freshTokens(egressGuard: guard);
}

Future<_SafeGatewayResult> _sendDisabledToolSelection({
  required http.Client httpClient,
  required Uri baseUri,
  required String clientVersion,
  required AiGatewayTokens tokens,
  required int sequence,
  required String userLabel,
}) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final requestId = 'rate_${userLabel}_${stamp}_$sequence';
  final response = await httpClient
      .post(
        baseUri.resolve('/v1/ai/tool-selection'),
        headers: <String, String>{
          'Authorization': 'Bearer ${tokens.firebaseIdToken}',
          'X-Firebase-AppCheck': tokens.appCheckToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Request-ID': requestId,
        },
        body: jsonEncode(<String, Object?>{
          'requestId': requestId,
          'mode': 'governedToolSelection',
          'locale': 'en',
          'sanitizedMessages': <Map<String, String>>[
            <String, String>{
              'role': 'user',
              'content': 'Select one approved read-only financial tool.',
            },
          ],
          'allowedToolIds': <String>['get_dashboard_summary'],
          'timeoutClass': 'interactive',
          'clientVersion': clientVersion,
        }),
      )
      .timeout(const Duration(seconds: 10));
  String code = 'invalid';
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['failure'] is Map) {
      final failure = decoded['failure'] as Map;
      if (failure['code'] is String) {
        code = failure['code'] as String;
      }
    }
  } on FormatException {
    code = 'invalid';
  }
  final retryAfterSeconds = int.tryParse(
    response.headers['retry-after']?.trim() ?? '',
  );
  return _SafeGatewayResult(
    status: response.statusCode,
    code: code,
    retryAfterSeconds: retryAfterSeconds,
  );
}

final class _SafeGatewayResult {
  const _SafeGatewayResult({
    required this.status,
    required this.code,
    required this.retryAfterSeconds,
  });

  final int status;
  final String code;
  final int? retryAfterSeconds;
}

final class _SyntheticUser {
  const _SyntheticUser({
    required this.user,
    required this.email,
    required this.password,
  });

  final User user;
  final String email;
  final String password;
}

Future<_SyntheticUser> _createSyntheticUser(
  FirebaseAuth auth, {
  required String label,
}) async {
  if (auth.currentUser != null) {
    await auth.signOut();
  }
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'cashpilot-groq-$label-$stamp@example.com';
  final password = 'Cp!${stamp}Az9';
  final credential = await auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  final user = credential.user;
  if (user == null) {
    throw StateError('Synthetic Firebase Auth user was not created.');
  }
  return _SyntheticUser(user: user, email: email, password: password);
}

Future<bool> _deleteSyntheticUser(
  FirebaseAuth auth,
  _SyntheticUser synthetic,
) async {
  try {
    var cleanupUser = auth.currentUser;
    if (cleanupUser?.uid != synthetic.user.uid) {
      await auth.signInWithEmailAndPassword(
        email: synthetic.email,
        password: synthetic.password,
      );
      cleanupUser = auth.currentUser;
    }
    if (cleanupUser?.uid != synthetic.user.uid) {
      return false;
    }
    await cleanupUser!.delete();
    return true;
  } on Object {
    return false;
  }
}

final class _LiveUserEgressGuard implements AiProviderEgressGuard {
  _LiveUserEgressGuard({required this.auth, required User expectedUser})
    : expectedAuthSession = AuthSessionIdentity(
        uid: expectedUser.uid,
        isAnonymous: expectedUser.isAnonymous,
        authSessionGeneration: 1,
        tenantId: expectedUser.tenantId,
      );

  final FirebaseAuth auth;

  @override
  final AuthSessionIdentity expectedAuthSession;

  @override
  void assertActive() {
    final current = auth.currentUser;
    if (current == null ||
        current.uid != expectedAuthSession.uid ||
        current.isAnonymous != expectedAuthSession.isAnonymous ||
        current.tenantId != expectedAuthSession.tenantId) {
      throw const AiProviderEgressRevokedException();
    }
  }

  @override
  Future<T> runSerializedAuthOperation<T>(
    Future<T> Function() operation,
  ) async {
    assertActive();
    final result = await operation();
    assertActive();
    return result;
  }
}
