abstract interface class FinanceTransactionManager {
  Future<T> runInTransaction<T>(Future<T> Function() operation);
}

class NoopFinanceTransactionManager implements FinanceTransactionManager {
  const NoopFinanceTransactionManager();

  @override
  Future<T> runInTransaction<T>(Future<T> Function() operation) {
    return operation();
  }
}
