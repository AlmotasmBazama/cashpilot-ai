import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_runtime_status.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_provider_route_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = AiProviderRouteResolver();

  test('configured auto route selects Groq and bounded Firebase fallback', () {
    final plan = resolver.resolveGeneralConversation(
      _inputs(firebaseTextFallbackEnabled: true),
    );

    expect(plan.primaryProvider, AiActiveProvider.groq);
    expect(plan.primaryAvailable, isTrue);
    expect(plan.preflightProvider, AiActiveProvider.groq);
    expect(plan.fallbackProvider, AiActiveProvider.firebase);
    expect(plan.fallbackAvailable, isTrue);
    expect(plan.fallbackPolicy, AiRuntimeFallbackPolicy.firebaseBeforeContent);
  });

  test('missing Groq URL selects configured Firebase preflight fallback', () {
    final plan = resolver.resolveGeneralConversation(
      _inputs(groqConfigured: false, firebaseTextFallbackEnabled: true),
    );

    expect(plan.primaryProvider, AiActiveProvider.groq);
    expect(plan.primaryAvailable, isFalse);
    expect(
      plan.primaryUnavailableReason,
      AiUnavailableReason.gatewayUrlMissing,
    );
    expect(plan.preflightProvider, AiActiveProvider.firebase);
    expect(plan.routeAvailable, isTrue);
  });

  test('explicit Groq never silently selects Firebase without fallback', () {
    final plan = resolver.resolveGeneralConversation(
      _inputs(
        preference: AiRuntimeProviderPreference.groq,
        groqConfigured: false,
      ),
    );

    expect(plan.primaryProvider, AiActiveProvider.groq);
    expect(plan.preflightProvider, AiActiveProvider.none);
    expect(plan.fallbackProvider, isNull);
    expect(plan.routeUnavailableReason, AiUnavailableReason.gatewayUrlMissing);
  });

  test('Firebase selection shares typed auth and App Check preflight', () {
    final unauthenticated = resolver.resolveGeneralConversation(
      _inputs(
        preference: AiRuntimeProviderPreference.firebase,
        authenticated: false,
      ),
    );
    final appCheckBlocked = resolver.resolveGeneralConversation(
      _inputs(
        preference: AiRuntimeProviderPreference.firebase,
        appCheckAvailable: false,
      ),
    );

    expect(
      unauthenticated.routeUnavailableReason,
      AiUnavailableReason.authenticationRequired,
    );
    expect(
      appCheckBlocked.routeUnavailableReason,
      AiUnavailableReason.appCheckUnavailable,
    );
  });

  test('explicit Groq flags are part of the shared route plan', () {
    final plan = resolver.resolveGeneralConversation(
      _inputs(
        preference: AiRuntimeProviderPreference.groq,
        groqGatewayEnabled: false,
      ),
    );

    expect(plan.primaryProvider, AiActiveProvider.groq);
    expect(plan.primaryAvailable, isFalse);
    expect(plan.routeUnavailableReason, AiUnavailableReason.gatewayDisabled);
  });

  test(
    'Groq awaits retryable App Check startup but Firebase stays blocked',
    () {
      final groq = resolver.resolveGeneralConversation(
        _inputs(appCheckAvailable: false, appCheckAttemptable: true),
      );
      final firebase = resolver.resolveGeneralConversation(
        _inputs(
          preference: AiRuntimeProviderPreference.firebase,
          appCheckAvailable: false,
          appCheckAttemptable: true,
        ),
      );

      expect(groq.preflightProvider, AiActiveProvider.groq);
      expect(groq.routeAvailable, isTrue);
      expect(firebase.preflightProvider, AiActiveProvider.none);
      expect(
        firebase.routeUnavailableReason,
        AiUnavailableReason.appCheckUnavailable,
      );
    },
  );
}

AiProviderRouteInputs _inputs({
  AiRuntimeProviderPreference preference = AiRuntimeProviderPreference.auto,
  bool agentEnabled = true,
  bool groqGatewayEnabled = true,
  bool groqGeneralChatEnabled = true,
  bool groqConfigured = true,
  bool remotePreflightReady = true,
  bool firebaseTextFallbackEnabled = false,
  bool firebaseConversationReady = true,
  bool platformConfigured = true,
  bool firebaseInitialized = true,
  bool appCheckAvailable = true,
  bool? appCheckAttemptable,
  bool authenticated = true,
}) => AiProviderRouteInputs(
  preference: preference,
  agentEnabled: agentEnabled,
  groqGatewayEnabled: groqGatewayEnabled,
  groqGeneralChatEnabled: groqGeneralChatEnabled,
  groqConfigured: groqConfigured,
  remotePreflightReady: remotePreflightReady,
  firebaseTextFallbackEnabled: firebaseTextFallbackEnabled,
  firebaseConversationReady: firebaseConversationReady,
  platformConfigured: platformConfigured,
  firebaseInitialized: firebaseInitialized,
  appCheckAvailable: appCheckAvailable,
  appCheckAttemptable: appCheckAttemptable ?? appCheckAvailable,
  authenticated: authenticated,
);
