/// Process-wide owner-scoped mutex for account-deletion execution.
///
/// Repository providers may be rebuilt as owner database sessions transition.
/// The coordinator deliberately has no owner/provider dependency, so a rebuilt
/// repository cannot overlap and invalidate the durable operation owned by an
/// earlier instance.
final class AccountDeletionExecutionCoordinator {
  final Set<String> _activeOwnerScopes = <String>{};

  AccountDeletionExecutionLease? tryAcquire(String ownerScopeValue) {
    final scope = ownerScopeValue.trim();
    if (scope.isEmpty || !_activeOwnerScopes.add(scope)) {
      return null;
    }
    return AccountDeletionExecutionLease._(
      () => _activeOwnerScopes.remove(scope),
    );
  }
}

final class AccountDeletionExecutionLease {
  AccountDeletionExecutionLease._(this._release);

  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
