import 'package:cashpilot_ai/core/sync/application/sync_providers.dart';
import 'package:cashpilot_ai/core/sync/domain/sync_queue_item.dart';
import 'package:cashpilot_ai/features/auth/application/providers/auth_providers.dart';
import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:cashpilot_ai/features/settings/presentation/widgets/backup_sync_settings_section.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('backup settings render in RTL at 320px without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const user = AuthUser(
      uid: 'user-1',
      email: 'person@example.com',
      emailVerified: true,
      isAnonymous: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWithValue(user),
          backupEnabledProvider(user.uid).overrideWithValue(true),
          lastBackupAtProvider(
            user.uid,
          ).overrideWithValue(DateTime.utc(2026, 7, 14, 8, 30)),
          syncQueueStatsProvider(user.uid).overrideWith(
            (_) => Stream.value(
              const SyncQueueStats(pendingCount: 2, failedCount: 1),
            ),
          ),
        ],
        child: _app(locale: const Locale('ar')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackupSyncSettingsSection), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsWidgets);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest sees backup warning and disabled toggle', (tester) async {
    const guest = AuthUser(
      uid: 'guest-1',
      emailVerified: true,
      isAnonymous: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentAuthUserProvider.overrideWithValue(guest)],
        child: _app(locale: const Locale('en')),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNull);
    expect(
      find.text('Sign in with a non-guest account to use cloud backup.'),
      findsOneWidget,
    );
  });
}

Widget _app({required Locale locale}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: CPTheme.dark(),
  home: const Scaffold(
    body: SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: BackupSyncSettingsSection(),
    ),
  ),
);
