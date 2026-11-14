import 'dart:async';
import 'dart:io';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_operation_coordinator.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_auth_session_guard.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_oauth_credential_provider.dart';
import 'package:cashpilot_ai/features/auth/data/services/firebase_restricted_auth_session_restorer.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_authenticated_continuation.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_restricted_auth.dart';
import 'package:cashpilot_ai/features/data_deletion/application/account_deletion_startup_recovery_coordinator.dart';
import 'package:cashpilot_ai/features/data_deletion/application/data_deletion_providers.dart';
import 'package:cashpilot_ai/features/data_deletion/data/datasources/account_deletion_auth_data_source.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_operation_context.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_request.dart';
import 'package:cashpilot_ai/features/data_deletion/presentation/account_deletion_continuation_app.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'raw restricted auth waits for ordered fresh exact-owner event',
    () async {
      final auth = _RestrictedFirebaseAuth(
        currentUser: _FirebaseUser('owner-b'),
        signInUser: _FirebaseUser('owner-a'),
      );
      final guard = FirebaseAuthSessionEpochGuard(auth);
      addTearDown(() async {
        await guard.dispose();
        await auth.dispose();
      });
      final service = _accountDeletionRestrictedAuth(
        auth: auth,
        sessionGuard: guard,
        operationCoordinator: FirebaseAuthOperationCoordinator(),
        oauthCredentialProvider: _NoopOAuthCredentialProvider(),
      );
      var completed = false;

      final restoring = service
          .signInWithEmail(
            email: 'owner-a@example.com',
            password: 'owner-a-password',
            targets: <AccountDeletionRecoveryTarget>[_target],
          )
          .then((value) {
            completed = true;
            return value;
          });
      await auth.signInStarted.future;
      await pumpEventQueue();

      expect(completed, isFalse);
      auth.emitCurrentAuthState();
      final identity = await restoring;

      expect(identity?.uid, 'owner-a');
      expect(identity?.authSessionGeneration, greaterThan(0));
      expect(
        OwnerScopeDerivation.fromConfirmedFirebaseUid(identity!.uid).id.value,
        _target.ownerScopeValue,
      );
    },
  );

  test('raw restricted auth signs an unexpected account back out', () async {
    final auth = _RestrictedFirebaseAuth(
      currentUser: _FirebaseUser('owner-b'),
      signInUser: _FirebaseUser('owner-c'),
      emitSignInEvent: true,
    );
    final guard = FirebaseAuthSessionEpochGuard(auth);
    addTearDown(() async {
      await guard.dispose();
      await auth.dispose();
    });
    final service = _accountDeletionRestrictedAuth(
      auth: auth,
      sessionGuard: guard,
      operationCoordinator: FirebaseAuthOperationCoordinator(),
      oauthCredentialProvider: _NoopOAuthCredentialProvider(),
    );

    final identity = await service.signInWithEmail(
      email: 'owner-c@example.com',
      password: 'owner-c-password',
      targets: <AccountDeletionRecoveryTarget>[_target],
    );

    expect(identity, isNull);
    expect(auth.currentUser, isNull);
    expect(auth.signInCalls, 1);
  });

  test(
    'OAuth identity switch before native mutex performs zero sign-in',
    () async {
      final auth = _RestrictedFirebaseAuth(
        currentUser: _FirebaseUser('owner-b'),
        signInUser: _FirebaseUser('owner-a'),
      );
      final guard = FirebaseAuthSessionEpochGuard(auth);
      final oauth = _ControlledOAuthCredentialProvider();
      addTearDown(() async {
        await guard.dispose();
        await auth.dispose();
      });
      final service = _accountDeletionRestrictedAuth(
        auth: auth,
        sessionGuard: guard,
        operationCoordinator: FirebaseAuthOperationCoordinator(),
        oauthCredentialProvider: oauth,
      );

      final restoring = service.signInWithGoogle(
        targets: <AccountDeletionRecoveryTarget>[_target],
      );
      await oauth.googleStarted.future;
      auth.replaceCurrentUser(_FirebaseUser('owner-c'));
      oauth.completeGoogle();

      expect(await restoring, isNull);
      expect(auth.credentialSignInCalls, 0);
      expect(auth.currentUser?.uid, 'owner-c');
    },
  );

  testWidgets(
    'cached B can only use restricted auth and never constructs deletion graph',
    (tester) async {
      final sessions = StreamController<AuthSessionIdentity?>.broadcast(
        sync: true,
      );
      addTearDown(sessions.close);
      final deletionAuth = _TrackingDeletionAuthDataSource();
      final continuation = _continuation(deletionAuth);
      final restrictedAuth = _FakeRestrictedAuth(
        onEmail: () async {
          final wrongB = _identity(uid: 'owner-b', generation: 2);
          sessions.add(wrongB);
          return wrongB;
        },
      );
      final observer = _RecordingProviderObserver();

      await tester.pumpWidget(
        _app(
          sessions: sessions.stream,
          restrictedAuth: restrictedAuth,
          continuation: continuation,
          observer: observer,
        ),
      );
      await tester.pump();
      sessions.add(_identity(uid: 'owner-b'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('account-deletion-recovery-login')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('continue-account-deletion')), findsNothing);
      expect(deletionAuth.issueLeaseCalls, 0);
      expect(deletionAuth.deleteCalls, 0);
      expect(observer.names.intersection(_forbiddenProviderGraph), isEmpty);

      await tester.enterText(
        find.byKey(const Key('account-deletion-continuation-email')),
        'owner-b@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('account-deletion-continuation-password')),
        'wrong-owner-password',
      );
      await tester.tap(
        find.byKey(const Key('account-deletion-recovery-login')),
      );
      await tester.pumpAndSettle();

      expect(restrictedAuth.emailCalls, 1);
      expect(deletionAuth.issueLeaseCalls, 0);
      expect(deletionAuth.deleteCalls, 0);
      expect(find.byKey(const Key('continue-account-deletion')), findsNothing);
    },
  );

  testWidgets(
    'lease waits for fresh exact A event and A to B dialog race deletes nothing',
    (tester) async {
      final sessions = StreamController<AuthSessionIdentity?>.broadcast(
        sync: true,
      );
      addTearDown(sessions.close);
      final freshA = _identity(generation: 3);
      final deletionAuth = _TrackingDeletionAuthDataSource(
        lease: _lease(generation: freshA.authSessionGeneration),
      );
      final continuation = _continuation(deletionAuth);
      final restrictedAuth = _FakeRestrictedAuth(onEmail: () async => freshA);

      await tester.pumpWidget(
        _app(
          sessions: sessions.stream,
          restrictedAuth: restrictedAuth,
          continuation: continuation,
        ),
      );
      await tester.pump();
      sessions.add(_identity(uid: 'owner-b'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('account-deletion-continuation-email')),
        'owner-a@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('account-deletion-continuation-password')),
        'owner-a-password',
      );
      await tester.tap(
        find.byKey(const Key('account-deletion-recovery-login')),
      );
      await tester.pumpAndSettle();

      // The sign-in return value alone has no authority. The ordered native
      // session event with the exact generation must arrive first.
      expect(find.byKey(const Key('continue-account-deletion')), findsNothing);
      expect(deletionAuth.issueLeaseCalls, 0);

      sessions.add(freshA);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('continue-account-deletion')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('continue-account-deletion')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(deletionAuth.issueLeaseCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);

      sessions.add(_identity(uid: 'owner-b', generation: 4));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(deletionAuth.deleteCalls, 0);
      expect(deletionAuth.releaseLeaseCalls, 1);
    },
  );

  test('continuation shell has no routed or owner-data imports', () {
    final source = File(
      'lib/features/data_deletion/presentation/'
      'account_deletion_continuation_app.dart',
    ).readAsStringSync();
    for (final forbidden in <String>[
      'app_router.dart',
      'currentAuthUserProvider',
      'authStateProvider',
      'authControllerProvider',
      'profileRepositoryProvider',
      'accountsProvider',
      'transactionsProvider',
      'aiAgent',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'continuation executor has no hydrated or required-owner dependency',
    () {
      final source = File(
        'lib/features/data_deletion/application/data_deletion_providers.dart',
      ).readAsStringSync();
      final start = source.indexOf(
        'final accountDeletionAuthenticatedContinuationProvider',
      );
      final end = source.indexOf(
        'AppResult<DataDeletionReport> _continuationIdentityFailure',
        start,
      );
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final factory = source.substring(start, end);
      for (final forbidden in <String>[
        'requiredScopedAppDatabaseSessionProvider',
        'deleteAllUserDataUseCaseProvider',
        'authStateProvider',
        'currentAuthUserProvider',
        'confirmedOwnerScopeSnapshotProvider',
      ]) {
        expect(factory, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(factory, contains('ScopedAppDatabaseSession('));
      expect(factory, contains('session.invalidate()'));
    },
  );

  test('native identity provider is guard-only and skips hydrated auth', () {
    final source = File(
      'lib/features/auth/application/providers/auth_providers.dart',
    ).readAsStringSync();
    final start = source.indexOf('final nativeAuthSessionIdentityProvider');
    final end = source.indexOf('final rememberMeProvider', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final provider = source.substring(start, end);
    expect(provider, contains('firebaseAuthSessionEpochGuardProvider'));
    expect(provider, isNot(contains('ref.watch(authStateProvider)')));
    expect(provider, isNot(contains('profileRepositoryProvider')));
  });
}

final _target = AccountDeletionRecoveryTarget(
  operationId: '01900000-0000-7000-8000-000000000222',
  ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
    'owner-a',
  ).id.value,
);

const _cleanReport = AccountDeletionStartupRecoveryReport(
  completed: 1,
  retained: 0,
  rejected: 0,
);

const _forbiddenProviderGraph = <String>{
  'appRouterProvider',
  'authStateProvider',
  'currentAuthUserProvider',
  'authControllerProvider',
  'authRemoteDataSourceProvider',
  'profileRepositoryProvider',
  'accountsProvider',
  'transactionsProvider',
  'aiAgentMemoryStoreProvider',
  'accountDeletionAuthenticatedContinuationProvider',
  'requiredScopedAppDatabaseSessionProvider',
  'deleteAllUserDataUseCaseProvider',
  'dataDeletionRepositoryProvider',
};

AccountDeletionRestrictedAuth _accountDeletionRestrictedAuth({
  required firebase_auth.FirebaseAuth auth,
  required FirebaseAuthSessionEpochGuard sessionGuard,
  required FirebaseAuthOperationCoordinator operationCoordinator,
  required FirebaseOAuthCredentialProvider oauthCredentialProvider,
}) => AccountDeletionRestrictedAuthAdapter(
  sessionRestorer: FirebaseRestrictedAuthSessionRestorer(
    auth: auth,
    sessionGuard: sessionGuard,
    operationCoordinator: operationCoordinator,
    oauthCredentialProvider: oauthCredentialProvider,
  ),
);

Widget _app({
  required Stream<AuthSessionIdentity?> sessions,
  required AccountDeletionRestrictedAuth restrictedAuth,
  required AccountDeletionAuthenticatedContinuation continuation,
  ProviderObserver? observer,
}) => ProviderScope(
  observers: observer == null ? const [] : <ProviderObserver>[observer],
  overrides: [
    nativeAuthSessionIdentityProvider.overrideWith((_) => sessions),
    accountDeletionRestrictedAuthProvider.overrideWithValue(restrictedAuth),
    accountDeletionAuthenticatedContinuationProvider.overrideWithValue(
      continuation,
    ),
    accountDeletionStartupRecoveryProvider.overrideWith(
      (_) async => _cleanReport,
    ),
  ],
  child: AccountDeletionContinuationApp(
    targets: <AccountDeletionRecoveryTarget>[_target],
  ),
);

AccountDeletionAuthenticatedContinuation _continuation(
  _TrackingDeletionAuthDataSource auth,
) => AccountDeletionAuthenticatedContinuation(
  authDataSource: auth,
  deleteAll: (request) async {
    auth.deleteCalls += 1;
    return const AppResult<DataDeletionReport>.failure(
      Failure(message: 'synthetic failure', code: 'synthetic_failure'),
    );
  },
);

final class _FakeRestrictedAuth implements AccountDeletionRestrictedAuth {
  _FakeRestrictedAuth({
    required Future<AuthSessionIdentity?> Function() onEmail,
  }) : _onEmail = onEmail;

  final Future<AuthSessionIdentity?> Function() _onEmail;
  var emailCalls = 0;

  @override
  Future<AuthSessionIdentity?> signInWithEmail({
    required String email,
    required String password,
    required List<AccountDeletionRecoveryTarget> targets,
  }) {
    emailCalls += 1;
    return _onEmail();
  }

  @override
  Future<AuthSessionIdentity?> signInWithApple({
    required List<AccountDeletionRecoveryTarget> targets,
  }) async => null;

  @override
  Future<AuthSessionIdentity?> signInWithGoogle({
    required List<AccountDeletionRecoveryTarget> targets,
  }) async => null;
}

final class _TrackingDeletionAuthDataSource
    implements AccountDeletionAuthDataSource {
  _TrackingDeletionAuthDataSource({AccountDeletionConfirmationLease? lease})
    : lease = lease ?? _lease();

  final AccountDeletionConfirmationLease lease;
  var issueLeaseCalls = 0;
  var releaseLeaseCalls = 0;
  var deleteCalls = 0;

  @override
  Future<AccountDeletionConfirmationLease> issueConfirmationLease() async {
    issueLeaseCalls += 1;
    return lease;
  }

  @override
  void releaseConfirmationLease(AccountDeletionConfirmationLease lease) {
    releaseLeaseCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccountDeletionConfirmationLease _lease({int generation = 1}) =>
    AccountDeletionConfirmationLease(
      opaqueToken: 'restricted-continuation-lease-$generation',
      email: 'owner-a@example.com',
      isAnonymous: false,
      ownerScopeValue: _target.ownerScopeValue,
      authSessionGeneration: generation,
    );

AuthSessionIdentity _identity({String uid = 'owner-a', int generation = 1}) =>
    AuthSessionIdentity(
      uid: uid,
      isAnonymous: false,
      authSessionGeneration: generation,
      tenantId: null,
    );

final class _RecordingProviderObserver extends ProviderObserver {
  final Set<String> names = <String>{};

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final name = context.provider.name;
    if (name != null) {
      names.add(name);
    }
  }
}

final class _RestrictedFirebaseAuth implements firebase_auth.FirebaseAuth {
  _RestrictedFirebaseAuth({
    required firebase_auth.User? currentUser,
    required this.signInUser,
    this.emitSignInEvent = false,
  }) : _currentUser = currentUser;

  firebase_auth.User? _currentUser;
  final firebase_auth.User signInUser;
  final bool emitSignInEvent;
  final StreamController<firebase_auth.User?> _authStates =
      StreamController<firebase_auth.User?>.broadcast(sync: true);
  final Completer<void> signInStarted = Completer<void>();
  var signInCalls = 0;
  var credentialSignInCalls = 0;

  @override
  firebase_auth.User? get currentUser => _currentUser;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _authStates.stream;

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStates.add(null);
  }

  @override
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    _currentUser = signInUser;
    if (!signInStarted.isCompleted) {
      signInStarted.complete();
    }
    if (emitSignInEvent) {
      _authStates.add(_currentUser);
    }
    return _FirebaseUserCredential(signInUser);
  }

  @override
  Future<firebase_auth.UserCredential> signInWithCredential(
    firebase_auth.AuthCredential credential,
  ) async {
    credentialSignInCalls += 1;
    _currentUser = signInUser;
    if (emitSignInEvent) {
      _authStates.add(_currentUser);
    }
    return _FirebaseUserCredential(signInUser);
  }

  void emitCurrentAuthState() => _authStates.add(_currentUser);

  void replaceCurrentUser(firebase_auth.User? user) {
    _currentUser = user;
    _authStates.add(user);
  }

  Future<void> dispose() => _authStates.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FirebaseUser implements firebase_auth.User {
  const _FirebaseUser(this.uid);

  @override
  final String uid;

  @override
  bool get isAnonymous => false;

  @override
  String? get tenantId => null;

  @override
  String? get email => '$uid@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FirebaseUserCredential implements firebase_auth.UserCredential {
  const _FirebaseUserCredential(this.user);

  @override
  final firebase_auth.User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _NoopOAuthCredentialProvider
    implements FirebaseOAuthCredentialProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ControlledOAuthCredentialProvider
    implements FirebaseOAuthCredentialProvider {
  final Completer<void> googleStarted = Completer<void>();
  final Completer<FirebaseOAuthCredentialResult> _google =
      Completer<FirebaseOAuthCredentialResult>();

  void completeGoogle() {
    if (!_google.isCompleted) {
      _google.complete(
        FirebaseOAuthCredentialResult(credential: _FirebaseAuthCredential()),
      );
    }
  }

  @override
  Future<FirebaseOAuthCredentialResult> acquireGoogleCredential() {
    if (!googleStarted.isCompleted) {
      googleStarted.complete();
    }
    return _google.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FirebaseAuthCredential implements firebase_auth.AuthCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
