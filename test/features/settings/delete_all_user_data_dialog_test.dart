import 'dart:async';

import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/data_deletion/domain/entities/data_deletion_request.dart';
import 'package:cashpilot_ai/features/data_deletion/data_deletion_presentation.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'confirmed native lease survives absent profile without building auth graph',
    (tester) async {
      var currentAuthUserBuilds = 0;
      final observer = _RecordingProviderObserver();

      await tester.pumpWidget(
        ProviderScope(
          observers: <ProviderObserver>[observer],
          overrides: [
            nativeAuthSessionIdentityProvider.overrideWith(
              (_) => Stream<AuthSessionIdentity?>.value(_identity()),
            ),
            currentAuthUserProvider.overrideWith((_) {
              currentAuthUserBuilds += 1;
              return null;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: CPTheme.dark(),
            home: Scaffold(
              body: DeleteAllUserDataDialog(
                confirmationLease: _lease(
                  opaqueToken: 'opaque-profile-hydration-lease',
                  email: 'owner-a@example.com',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeleteAllUserDataDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('account-deletion-password')), findsOne);
      expect(currentAuthUserBuilds, 0);
      expect(
        observer.names.intersection(const <String>{
          'authStateProvider',
          'currentAuthUserProvider',
          'authRemoteDataSourceProvider',
          'profileRepositoryProvider',
        }),
        isEmpty,
      );
    },
  );

  testWidgets('permanent deletion is disabled until explicitly confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        child: DeleteAllUserDataDialog(
          confirmationLease: _lease(
            opaqueToken: 'opaque-lease',
            email: 'person@example.com',
          ),
        ),
      ),
    );

    final deleteButton = find.byKey(const ValueKey('delete-all-user-data'));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('confirm-account-data-deletion')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
  });

  testWidgets('guest confirmation fits a narrow Arabic layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        user: _user(isAnonymous: true),
        child: DeleteAllUserDataDialog(
          confirmationLease: _lease(
            opaqueToken: 'opaque-guest-lease',
            isAnonymous: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey('confirm-account-data-deletion')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final logout in <bool>[false, true]) {
    final transition = logout ? 'logout' : 'A to B switch';
    testWidgets('$transition wipes and dismisses with zero submission', (
      tester,
    ) async {
      final sessions = StreamController<AuthSessionIdentity?>.broadcast(
        sync: true,
      );
      addTearDown(sessions.close);
      var submissions = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nativeAuthSessionIdentityProvider.overrideWith(
              (_) => sessions.stream,
            ),
            // A stale hydrated profile must have no authority over the dialog.
            currentAuthUserProvider.overrideWithValue(_user()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: CPTheme.dark(),
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    final credentials =
                        await showDialog<AccountDeletionCredentials>(
                          context: context,
                          builder: (_) => DeleteAllUserDataDialog(
                            confirmationLease: _lease(
                              opaqueToken: 'opaque-race-lease',
                              email: 'owner-a@example.com',
                            ),
                          ),
                        );
                    if (credentials != null) {
                      submissions += 1;
                    }
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      sessions.add(_identity());
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('account-deletion-password')),
        'owner-a-secret',
      );

      sessions.add(logout ? null : _identity(uid: 'owner-b', generation: 2));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteAllUserDataDialog), findsNothing);
      expect(find.text('owner-a-secret'), findsNothing);
      expect(submissions, 0);
    });
  }
}

AuthUser _user({bool isAnonymous = false, int generation = 1}) => AuthUser(
  uid: 'owner-a',
  email: isAnonymous ? null : 'person@example.com',
  emailVerified: !isAnonymous,
  isAnonymous: isAnonymous,
  authSessionGeneration: generation,
);

AuthSessionIdentity _identity({
  String uid = 'owner-a',
  bool isAnonymous = false,
  int generation = 1,
}) => AuthSessionIdentity(
  uid: uid,
  isAnonymous: isAnonymous,
  authSessionGeneration: generation,
  tenantId: null,
);

AccountDeletionConfirmationLease _lease({
  required String opaqueToken,
  String? email,
  bool isAnonymous = false,
}) => AccountDeletionConfirmationLease(
  opaqueToken: opaqueToken,
  email: email,
  isAnonymous: isAnonymous,
  ownerScopeValue: OwnerScopeDerivation.fromConfirmedFirebaseUid(
    'owner-a',
  ).id.value,
  authSessionGeneration: 1,
);

Widget _app({required Locale locale, required Widget child, AuthUser? user}) =>
    ProviderScope(
      overrides: [
        nativeAuthSessionIdentityProvider.overrideWith(
          (_) => Stream<AuthSessionIdentity?>.value(
            (user ?? _user()).sessionIdentity,
          ),
        ),
        currentAuthUserProvider.overrideWithValue(user ?? _user()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.dark(),
        home: Scaffold(body: Center(child: child)),
      ),
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
