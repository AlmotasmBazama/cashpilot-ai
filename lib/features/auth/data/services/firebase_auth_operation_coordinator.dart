import 'dart:async';

import '../../domain/services/auth_operation_coordinator.dart';

/// Serializes every app-owned native Firebase Auth mutation/token operation.
///
/// Callers supply synchronous guards that run inside the serialized boundary,
/// immediately adjacent to the native SDK call. This prevents a queued
/// operation captured for A from dispatching after another app operation has
/// installed B as the global Firebase session.
final class FirebaseAuthOperationCoordinator
    implements AuthOperationCoordinator {
  Future<void> _barrier = Future<void>.value();

  @override
  Future<T> run<T>({
    required Future<T> Function() operation,
    void Function()? assertBefore,
    void Function(T result)? assertAfter,
  }) {
    final result = _barrier.then((_) async {
      assertBefore?.call();
      final value = await operation();
      assertAfter?.call(value);
      return value;
    });
    _barrier = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }
}
