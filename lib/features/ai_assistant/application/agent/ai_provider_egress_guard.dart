import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../auth/auth_contracts.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/agent/ai_agent_contracts.dart';
import '../../domain/agent/ai_tool_contracts.dart';

/// Firebase/session implementation of the per-request provider egress fence.
///
/// The expected identity and owner binding are captured once. Every check uses
/// the native Auth epoch guard plus the already-acquired AI memory lease, so a
/// late request cannot silently adopt a replacement global Firebase user.
final class FirebaseAiProviderEgressGuard implements AiProviderEgressGuard {
  FirebaseAiProviderEgressGuard({
    required this.expectedAuthSession,
    required AiToolOwnerScopeBinding? expectedOwnerScope,
    required AiToolOwnerScopeReader currentOwnerScope,
    required AiAgentMemoryAccess memoryAccess,
    required AuthSessionEpochReader authSessionGuard,
    required AuthOperationCoordinator authOperationCoordinator,
  }) : _expectedOwnerScope = expectedOwnerScope,
       _currentOwnerScope = currentOwnerScope,
       _memoryAccess = memoryAccess,
       _authSessionGuard = authSessionGuard,
       _authOperationCoordinator = authOperationCoordinator,
       _expectedAuthSnapshot = AuthSessionSnapshot(
         fingerprint: AuthSessionFingerprint(
           uid: expectedAuthSession.uid,
           isAnonymous: expectedAuthSession.isAnonymous,
           tenantId: expectedAuthSession.tenantId,
         ),
         generation: expectedAuthSession.authSessionGeneration,
       ) {
    if (memoryAccess.ownerScope != expectedOwnerScope) {
      throw const AiProviderEgressRevokedException();
    }
    if (expectedOwnerScope != null) {
      String derivedOwnerScope;
      try {
        derivedOwnerScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
          expectedAuthSession.uid,
        ).id.value;
      } on Object {
        throw const AiProviderEgressRevokedException();
      }
      if (expectedOwnerScope.accountScope != derivedOwnerScope ||
          expectedOwnerScope.epoch !=
              expectedAuthSession.authSessionGeneration) {
        throw const AiProviderEgressRevokedException();
      }
    }
    assertActive();
  }

  @override
  final AuthSessionIdentity expectedAuthSession;
  final AiToolOwnerScopeBinding? _expectedOwnerScope;
  final AiToolOwnerScopeReader _currentOwnerScope;
  final AiAgentMemoryAccess _memoryAccess;
  final AuthSessionEpochReader _authSessionGuard;
  final AuthOperationCoordinator _authOperationCoordinator;
  final AuthSessionSnapshot _expectedAuthSnapshot;

  @override
  void assertActive() {
    try {
      _memoryAccess.assertActive();
      final expectedOwnerScope = _expectedOwnerScope;
      if (_currentOwnerScope() != expectedOwnerScope ||
          !_authSessionGuard.matches(_expectedAuthSnapshot)) {
        throw const AiProviderEgressRevokedException();
      }
    } on AiProviderEgressRevokedException {
      rethrow;
    } on Object {
      throw const AiProviderEgressRevokedException();
    }
  }

  @override
  Future<T> runSerializedAuthOperation<T>(Future<T> Function() operation) {
    return _authOperationCoordinator.run<T>(
      operation: operation,
      assertBefore: assertActive,
      assertAfter: (_) => assertActive(),
    );
  }
}
