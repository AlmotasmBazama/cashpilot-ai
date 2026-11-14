import 'dart:async';

import 'package:cashpilot_ai/core/database/app_database.dart';
import 'package:cashpilot_ai/core/owner_scope/application/legacy_data_claim_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/application/scoped_app_database_session.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _claimAuthProvider = StateProvider<AuthUser?>((ref) => null);
final _claimSessionProvider = StateProvider<ScopedAppDatabaseSession?>(
  (ref) => null,
);

void main() {
  test('current-owner claim invalidates inventory and health', () async {
    final fixture = _LegacyClaimFixture();
    addTearDown(fixture.dispose);
    await fixture.initialize('owner-a', generation: 1);

    final claim = fixture.controller.claim(protectedConfirmationAccepted: true);
    await fixture.service.started.future;
    fixture.service.result.complete(
      const LegacyDataClaimResult(claimedCount: 3, auditId: 'audit-a'),
    );

    expect(await claim, isTrue);
    await fixture.container.read(legacyDataInventoryProvider.future);
    await fixture.container.read(ownerScopeHealthProvider.future);
    final state = fixture.container.read(legacyDataClaimControllerProvider);
    expect(state.value?.auditId, 'audit-a');
    expect(fixture.inventoryBuilds, 2);
    expect(fixture.healthBuilds, 3);
  });

  test('paused A claim success is discarded after B becomes current', () async {
    final fixture = _LegacyClaimFixture();
    addTearDown(fixture.dispose);
    await fixture.initialize('owner-a', generation: 1);

    final claim = fixture.controller.claim(protectedConfirmationAccepted: true);
    await fixture.service.started.future;
    await fixture.switchOwner('owner-b', generation: 2);
    fixture.service.result.complete(
      const LegacyDataClaimResult(claimedCount: 3, auditId: 'audit-a'),
    );

    expect(await claim, isFalse);
    await fixture.pump();
    final state = fixture.container.read(legacyDataClaimControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value, isNull);
    expect(fixture.inventoryBuilds, 1);
    expect(fixture.healthBuilds, 1);
  });

  test(
    'paused claim is discarded after same owner starts a new auth session',
    () async {
      final fixture = _LegacyClaimFixture();
      addTearDown(fixture.dispose);
      await fixture.initialize('owner-a', generation: 1);

      final claim = fixture.controller.claim(
        protectedConfirmationAccepted: true,
      );
      await fixture.service.started.future;
      await fixture.switchOwner('owner-a', generation: 2);
      fixture.service.result.complete(
        const LegacyDataClaimResult(claimedCount: 3, auditId: 'stale-audit'),
      );

      expect(await claim, isFalse);
      await fixture.pump();
      final state = fixture.container.read(legacyDataClaimControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value, isNull);
      expect(fixture.inventoryBuilds, 1);
      expect(fixture.healthBuilds, 1);
    },
  );

  test('paused A claim error is discarded after logout', () async {
    final fixture = _LegacyClaimFixture();
    addTearDown(fixture.dispose);
    await fixture.initialize('owner-a', generation: 7);

    final claim = fixture.controller.claim(protectedConfirmationAccepted: true);
    await fixture.service.started.future;
    await fixture.logout();
    fixture.service.result.completeError(StateError('late private A error'));

    expect(await claim, isFalse);
    await fixture.pump();
    final state = fixture.container.read(legacyDataClaimControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.value, isNull);
    expect(fixture.inventoryBuilds, 1);
    expect(fixture.healthBuilds, 1);
  });
}

final class _LegacyClaimFixture {
  _LegacyClaimFixture() {
    database = AppDatabase(executor: NativeDatabase.memory());
    service = _ControlledLegacyDataClaimService(database);
    container = ProviderContainer(
      overrides: [
        currentAuthUserProvider.overrideWith(
          (ref) => ref.watch(_claimAuthProvider),
        ),
        scopedAppDatabaseSessionProvider.overrideWith(
          (ref) => ref.watch(_claimSessionProvider),
        ),
        legacyDataClaimServiceProvider.overrideWithValue(service),
        legacyDataInventoryProvider.overrideWith((ref) async {
          inventoryBuilds += 1;
          return LegacyDataInventory(const <String, int>{});
        }),
        ownerScopeHealthProvider.overrideWith((ref) async {
          healthBuilds += 1;
          return const OwnerScopeHealth(status: OwnerScopeStatus.safe);
        }),
      ],
    );
    claimSubscription = container.listen(
      legacyDataClaimControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    inventorySubscription = container.listen(
      legacyDataInventoryProvider,
      (_, _) {},
      fireImmediately: true,
    );
    healthSubscription = container.listen(
      ownerScopeHealthProvider,
      (_, _) {},
      fireImmediately: true,
    );
  }

  late final AppDatabase database;
  late final _ControlledLegacyDataClaimService service;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<LegacyDataClaimResult?>>
  claimSubscription;
  late final ProviderSubscription<AsyncValue<LegacyDataInventory>>
  inventorySubscription;
  late final ProviderSubscription<AsyncValue<OwnerScopeHealth>>
  healthSubscription;
  ScopedAppDatabaseSession? activeSession;
  var inventoryBuilds = 0;
  var healthBuilds = 0;

  LegacyDataClaimController get controller =>
      container.read(legacyDataClaimControllerProvider.notifier);

  Future<void> initialize(String uid, {required int generation}) async {
    await _setOwner(uid, generation: generation);
    await container.read(legacyDataClaimControllerProvider.future);
    await container.read(legacyDataInventoryProvider.future);
    await container.read(ownerScopeHealthProvider.future);
  }

  Future<void> switchOwner(String uid, {required int generation}) async {
    activeSession?.invalidate();
    await _setOwner(uid, generation: generation);
    await pump();
  }

  Future<void> logout() async {
    activeSession?.invalidate();
    activeSession = null;
    container.read(_claimAuthProvider.notifier).state = null;
    container.read(_claimSessionProvider.notifier).state = null;
    await pump();
  }

  Future<void> _setOwner(String uid, {required int generation}) async {
    final session = ScopedAppDatabaseSession(
      database: database,
      scope: OwnerScopeDerivation.fromConfirmedFirebaseUid(uid),
    );
    activeSession = session;
    container.read(_claimAuthProvider.notifier).state = AuthUser(
      uid: uid,
      emailVerified: true,
      isAnonymous: false,
      authSessionGeneration: generation,
    );
    container.read(_claimSessionProvider.notifier).state = session;
    await pump();
  }

  Future<void> pump() async {
    for (var index = 0; index < 8; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    claimSubscription.close();
    inventorySubscription.close();
    healthSubscription.close();
    container.dispose();
    await database.close();
  }
}

final class _ControlledLegacyDataClaimService extends LegacyDataClaimService {
  _ControlledLegacyDataClaimService(AppDatabase database)
    : super(
        session: ScopedAppDatabaseSession(
          database: database,
          scope: OwnerScopeDerivation.fromConfirmedFirebaseUid('unused'),
        ),
        currentConfirmedScope: () => null,
      );

  final Completer<void> started = Completer<void>();
  final Completer<LegacyDataClaimResult> result =
      Completer<LegacyDataClaimResult>();

  @override
  Future<LegacyDataClaimResult> claim({
    required bool protectedConfirmationAccepted,
  }) {
    started.complete();
    return result.future;
  }
}
