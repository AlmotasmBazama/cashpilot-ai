import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/auth/presentation/pages/profile_completion_screen.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

final _profileTestUserProvider = StateProvider<AuthUser?>((ref) => null);

void main() {
  testWidgets(
    'incomplete B replaces every form value retained from incomplete A',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final userA = _user(
        uid: 'owner-a',
        generation: 1,
        displayName: 'Alice',
        country: 'US',
        timezone: 'America/New_York',
        currency: 'USD',
        language: 'en',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _profileTestUserProvider.overrideWith((ref) => userA),
            currentAuthUserProvider.overrideWith(
              (ref) => ref.watch(_profileTestUserProvider),
            ),
            authStateProvider.overrideWith(
              (ref) =>
                  Stream<AuthUser?>.value(ref.watch(_profileTestUserProvider)),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: CPTheme.dark(),
            home: const ProfileCompletionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));
      expect(_textAt(tester, fields, 0), 'Alice');
      await tester.enterText(fields.at(0), 'private A draft');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileCompletionScreen)),
      );
      container.read(_profileTestUserProvider.notifier).state = _user(
        uid: 'owner-b',
        generation: 2,
        displayName: 'Bob',
        country: 'CA',
        timezone: 'America/Toronto',
        currency: 'EUR',
        language: 'ar',
      );
      await tester.pumpAndSettle();

      expect(_textAt(tester, fields, 0), 'Bob');
      expect(_textAt(tester, fields, 1), 'CA');
      expect(_textAt(tester, fields, 2), 'America/Toronto');
      expect(find.text('private A draft'), findsNothing);
      final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdowns.map((widget) => widget.initialValue), ['EUR', 'ar']);
    },
  );

  testWidgets('auth profile outage renders no editable completion form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<AuthUser?>.error(
              StateError('profile hydration unavailable'),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: CPTheme.dark(),
          home: const ProfileCompletionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-auth-hydration-pending')),
      findsOneWidget,
    );
  });
}

String _textAt(WidgetTester tester, Finder fields, int index) =>
    tester.widget<TextFormField>(fields.at(index)).controller!.text;

AuthUser _user({
  required String uid,
  required int generation,
  required String displayName,
  required String country,
  required String timezone,
  required String currency,
  required String language,
}) => AuthUser(
  uid: uid,
  email: '$uid@example.com',
  displayName: displayName,
  emailVerified: true,
  isAnonymous: false,
  authSessionGeneration: generation,
  country: country,
  timezone: timezone,
  currency: currency,
  language: language,
);
