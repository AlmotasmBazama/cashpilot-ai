/// Serializes native authentication operations behind adjacent identity
/// assertions supplied by each caller.
abstract interface class AuthOperationCoordinator {
  Future<T> run<T>({
    required Future<T> Function() operation,
    void Function()? assertBefore,
    void Function(T result)? assertAfter,
  });
}
