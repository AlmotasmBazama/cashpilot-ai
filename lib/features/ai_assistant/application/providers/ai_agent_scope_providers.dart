import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../domain/agent/ai_tool_contracts.dart';

/// Trusted AI lease derived only from the confirmed authentication snapshot.
/// The epoch changes with a new confirmed session, including a same-user
/// sign-out/sign-in cycle, so old asynchronous work cannot rejoin it.
final aiToolOwnerScopeBindingProvider = Provider<AiToolOwnerScopeBinding?>((
  ref,
) {
  final snapshot = ref.watch(confirmedOwnerScopeSnapshotProvider);
  final scope = snapshot.scope;
  final authSessionGeneration = snapshot.authSessionGeneration;
  if (snapshot.status != OwnerScopeStatus.safe ||
      scope == null ||
      authSessionGeneration == null) {
    return null;
  }
  return AiToolOwnerScopeBinding(
    accountScope: scope.id.value,
    epoch: authSessionGeneration,
  );
}, name: 'aiToolOwnerScopeBindingProvider');

final aiAgentAccountScopeProvider = Provider<String?>(
  (ref) => ref.watch(aiToolOwnerScopeBindingProvider)?.accountScope,
  name: 'aiAgentAccountScopeProvider',
);
