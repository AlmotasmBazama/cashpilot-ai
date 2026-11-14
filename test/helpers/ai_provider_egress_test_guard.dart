import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';

const testAiProviderEgressGuard = TestAiProviderEgressGuard();

final class TestAiProviderEgressGuard implements AiProviderEgressGuard {
  const TestAiProviderEgressGuard();

  @override
  AuthSessionIdentity get expectedAuthSession => const AuthSessionIdentity(
    uid: 'test-user',
    isAnonymous: false,
    authSessionGeneration: 1,
    tenantId: null,
  );

  @override
  void assertActive() {}

  @override
  Future<T> runSerializedAuthOperation<T>(Future<T> Function() operation) =>
      operation();
}
