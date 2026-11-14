import 'dart:async';

import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/storage/settings_local_data_source.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'own sign-in transition before use-case completion still reports success',
    () async {
      final fixture = _AuthControllerFixture();
      addTearDown(fixture.dispose);
      await fixture.emit(null);

      final signIn = fixture.controller.signIn(
        email: 'owner-b@example.com',
        password: 'secret',
        rememberMe: true,
      );
      final userB = _user('owner-b', 1);
      await fixture.emit(userB);
      fixture.repository.signInResult.complete(AppResult.success(userB));

      expect(await signIn, isTrue);
      expect(fixture.settings.savedRememberMe, isTrue);
    },
  );

  test(
    'wrong-user auth event cannot be accepted as the pending sign-in result',
    () async {
      final fixture = _AuthControllerFixture();
      addTearDown(fixture.dispose);
      await fixture.emit(null);

      final signIn = fixture.controller.signIn(
        email: 'owner-a@example.com',
        password: 'secret',
        rememberMe: true,
      );
      await fixture.emit(_user('owner-b', 1));
      fixture.repository.signInResult.complete(
        AppResult.success(_user('owner-a', 2)),
      );

      expect(await signIn, isFalse);
      expect(fixture.settings.savedRememberMe, isNull);
    },
  );

  test(
    'own sign-out null transition before completion still clears A memory',
    () async {
      final fixture = _AuthControllerFixture();
      addTearDown(fixture.dispose);
      final userA = _user('owner-a', 3);
      await fixture.emit(userA);

      final signOut = fixture.controller.signOut();
      await fixture.emit(null);
      fixture.repository.signOutResult.complete(
        const AppResult<void>.success(null),
      );

      expect(await signOut, isTrue);
      expect(fixture.settings.clearedAccountScopes, hasLength(1));
    },
  );

  test(
    'foreign A to B transition discards a stale profile completion',
    () async {
      final fixture = _AuthControllerFixture();
      addTearDown(fixture.dispose);
      final userA = _user('owner-a', 4);
      await fixture.emit(userA);

      final completion = fixture.controller.completeProfile(
        expectedSession: userA.sessionIdentity,
        displayName: 'Owner A',
        currency: 'USD',
        language: 'en',
        country: 'US',
        timezone: 'UTC',
      );
      await fixture.emit(null);
      await fixture.emit(_user('owner-b', 5));
      fixture.repository.profileResult.complete(AppResult.success(userA));

      expect(await completion, isFalse);
    },
  );
}

final class _AuthControllerFixture {
  _AuthControllerFixture()
    : repository = _ControlledAuthRepository(),
      settings = _MemorySettingsLocalDataSource(),
      authEvents = StreamController<AuthUser?>.broadcast(sync: true) {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        settingsLocalDataSourceProvider.overrideWithValue(settings),
        authStateProvider.overrideWith((ref) => authEvents.stream),
      ],
    );
    subscription = container.listen(
      authControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
  }

  final _ControlledAuthRepository repository;
  final _MemorySettingsLocalDataSource settings;
  final StreamController<AuthUser?> authEvents;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<void>> subscription;

  AuthController get controller =>
      container.read(authControllerProvider.notifier);

  Future<void> emit(AuthUser? user) async {
    authEvents.add(user);
    for (var index = 0; index < 6; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    await authEvents.close();
  }
}

final class _ControlledAuthRepository implements AuthRepository {
  final Completer<AppResult<AuthUser>> signInResult = Completer();
  final Completer<AppResult<AuthUser>> profileResult = Completer();
  final Completer<AppResult<void>> signOutResult = Completer();

  @override
  Future<AppResult<AuthUser>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) => signInResult.future;

  @override
  Future<AppResult<AuthUser>> completeProfile({
    required AuthSessionIdentity expectedSession,
    required String displayName,
    required String currency,
    required String language,
    required String country,
    required String timezone,
  }) => profileResult.future;

  @override
  Future<AppResult<void>> signOut() => signOutResult.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MemorySettingsLocalDataSource extends SettingsLocalDataSource {
  _MemorySettingsLocalDataSource() : super(_NoopBox());

  bool? savedRememberMe;
  final List<String> clearedAccountScopes = <String>[];

  @override
  bool readRememberMe() => false;

  @override
  Future<void> saveRememberMe(bool rememberMe) async {
    savedRememberMe = rememberMe;
  }

  @override
  Future<void> clearAiAgentMemory({required String accountScope}) async {
    clearedAccountScopes.add(accountScope);
  }
}

final class _NoopBox implements Box<dynamic> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthUser _user(String uid, int generation) => AuthUser(
  uid: uid,
  email: '$uid@example.com',
  emailVerified: true,
  isAnonymous: false,
  authSessionGeneration: generation,
);
