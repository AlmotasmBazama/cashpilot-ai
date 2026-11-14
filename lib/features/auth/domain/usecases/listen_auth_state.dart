import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class ListenAuthState {
  const ListenAuthState(this._repository);

  final AuthRepository _repository;

  Stream<AuthUser?> call() => _repository.listenAuthState();
}
