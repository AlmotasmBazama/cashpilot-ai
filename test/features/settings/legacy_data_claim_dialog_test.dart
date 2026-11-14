import 'dart:io';

import 'package:cashpilot_ai/core/owner_scope/application/legacy_data_claim_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/settings/presentation/widgets/legacy_data_claim_section.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('English dialog requires explicit owner confirmation', (
    tester,
  ) async {
    final controller = _FakeLegacyDataClaimController(succeeds: true);
    await tester.pumpWidget(
      _app(locale: const Locale('en'), controller: controller),
    );

    await tester.tap(find.byKey(const Key('open_claim_dialog')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm local data claim'), findsOneWidget);
    expect(
      find.text('I confirm that this local data belongs to this account.'),
      findsOneWidget,
    );
    var confirm = tester.widget<FilledButton>(
      find.byKey(const Key('confirm_claim_legacy_local_data')),
    );
    expect(confirm.onPressed, isNull);
    expect(controller.claimCalls, 0);

    await tester.tap(find.byKey(const Key('confirm_legacy_local_data_owner')));
    await tester.pump();
    confirm = tester.widget<FilledButton>(
      find.byKey(const Key('confirm_claim_legacy_local_data')),
    );
    expect(confirm.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('confirm_claim_legacy_local_data')));
    await tester.pumpAndSettle();

    expect(controller.claimCalls, 1);
    expect(controller.lastProtectedConfirmation, isTrue);
    expect(find.text('result:true'), findsOneWidget);
  });

  testWidgets('Arabic dialog cancel returns false and performs no claim', (
    tester,
  ) async {
    final controller = _FakeLegacyDataClaimController(succeeds: true);
    await tester.pumpWidget(
      _app(locale: const Locale('ar'), controller: controller),
    );

    await tester.tap(find.byKey(const Key('open_claim_dialog')));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد ربط البيانات المحلية'), findsOneWidget);
    expect(
      find.text('أؤكد أن هذه البيانات المحلية تخص هذا الحساب.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cancel_legacy_local_data_claim')));
    await tester.pumpAndSettle();

    expect(controller.claimCalls, 0);
    expect(find.text('result:false'), findsOneWidget);
  });

  for (final localeAndTitle in const <(Locale, String)>[
    (Locale('en'), 'Claim local legacy data'),
    (Locale('ar'), 'ربط البيانات المحلية'),
  ]) {
    testWidgets('claim section is visible for legacy health in '
        '${localeAndTitle.$1.languageCode}', (tester) async {
      await tester.pumpWidget(
        _app(
          locale: localeAndTitle.$1,
          controller: _FakeLegacyDataClaimController(succeeds: true),
          home: const LegacyDataClaimSection(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(localeAndTitle.$2), findsOneWidget);
      expect(find.byKey(const Key('claim_legacy_local_data')), findsOneWidget);
    });
  }

  test('legacy claim is the first conditional section in Settings', () {
    final source = File(
      'lib/features/settings/presentation/pages/settings_screen.dart',
    ).readAsStringSync();
    final claimIndex = source.indexOf('const LegacyDataClaimSection()');
    final accountIndex = source.indexOf('title: l10n.account');

    expect(claimIndex, greaterThanOrEqualTo(0));
    expect(claimIndex, lessThan(accountIndex));
    expect('const LegacyDataClaimSection()'.allMatches(source), hasLength(1));
  });
}

Widget _app({
  required Locale locale,
  required _FakeLegacyDataClaimController controller,
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      ownerScopeHealthProvider.overrideWith(
        (ref) async => const OwnerScopeHealth(
          status: OwnerScopeStatus.legacyDataUnclaimed,
          failure: OwnerScopeFailure.legacyDataRequiresClaim,
        ),
      ),
      legacyDataInventoryProvider.overrideWith(
        (ref) async => LegacyDataInventory(const <String, int>{'accounts': 2}),
      ),
      legacyDataClaimControllerProvider.overrideWith(() => controller),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CPTheme.light(),
      home: home ?? const _DialogHost(),
    ),
  );
}

final class _DialogHost extends StatefulWidget {
  const _DialogHost();

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

final class _DialogHostState extends State<_DialogHost> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(
            key: const Key('open_claim_dialog'),
            onPressed: () async {
              final result = await showLegacyDataClaimDialog(context);
              if (!mounted) return;
              setState(() => _result = result);
            },
            child: const Text('open'),
          ),
          Text('result:${_result ?? 'pending'}'),
        ],
      ),
    );
  }
}

final class _FakeLegacyDataClaimController extends LegacyDataClaimController {
  _FakeLegacyDataClaimController({required this.succeeds});

  final bool succeeds;
  var claimCalls = 0;
  bool? lastProtectedConfirmation;

  @override
  Future<LegacyDataClaimResult?> build() async => null;

  @override
  Future<bool> claim({required bool protectedConfirmationAccepted}) async {
    claimCalls += 1;
    lastProtectedConfirmation = protectedConfirmationAccepted;
    if (succeeds) {
      state = const AsyncData(
        LegacyDataClaimResult(claimedCount: 2, auditId: 'test-audit'),
      );
    }
    return succeeds;
  }
}
