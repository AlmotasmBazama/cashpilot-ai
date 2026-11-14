import 'dart:async';

import 'package:cashpilot_ai/app/di/goal_linked_accounts_composition.dart'
    as composition;
import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/goals/application/models/goal_linked_account_option.dart';
import 'package:cashpilot_ai/features/goals/application/providers/goal_linked_account_options_provider.dart'
    as compatibility;
import 'package:cashpilot_ai/features/goals/application/providers/goals_providers.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal_contribution.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal_progress.dart';
import 'package:cashpilot_ai/features/goals/domain/enums/goal_status.dart';
import 'package:cashpilot_ai/features/goals/goals.dart' as public_api;
import 'package:cashpilot_ai/features/goals/presentation/pages/goals_screen.dart';
import 'package:cashpilot_ai/features/goals/presentation/widgets/goal_contribution_sheet.dart';
import 'package:cashpilot_ai/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:cashpilot_ai/shared/presentation/widgets/finance_ui_components.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'linked-account provider keeps identity, fields, order, and invalidation',
    () async {
      var revision = 0;
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          accountsProvider.overrideWith((_) async {
            calls++;
            return AppResult<List<Account>>.success(<Account>[
              _account('first-$revision', 'First $revision'),
              _account(
                'second-$revision',
                'Second $revision',
                isArchived: true,
              ),
            ]);
          }),
        ],
      );
      addTearDown(container.dispose);

      expect(
        identical(
          composition.goalLinkedAccountOptionsProvider,
          compatibility.goalLinkedAccountOptionsProvider,
        ),
        isTrue,
      );
      expect(
        identical(
          composition.goalLinkedAccountOptionsProvider,
          public_api.goalLinkedAccountOptionsProvider,
        ),
        isTrue,
      );
      expect(
        composition.goalLinkedAccountOptionsProvider.name,
        'goalLinkedAccountOptionsProvider',
      );

      final first = _linkedAccountSuccess(
        await container.read(
          compatibility.goalLinkedAccountOptionsProvider.future,
        ),
      );
      revision = 1;
      container.invalidate(accountsProvider);
      final second = _linkedAccountSuccess(
        await container.read(
          compatibility.goalLinkedAccountOptionsProvider.future,
        ),
      );

      expect(first, const <GoalLinkedAccountOption>[
        GoalLinkedAccountOption(
          id: 'first-0',
          name: 'First 0',
          isArchived: false,
        ),
        GoalLinkedAccountOption(
          id: 'second-0',
          name: 'Second 0',
          isArchived: true,
        ),
      ]);
      expect(second, const <GoalLinkedAccountOption>[
        GoalLinkedAccountOption(
          id: 'first-1',
          name: 'First 1',
          isArchived: false,
        ),
        GoalLinkedAccountOption(
          id: 'second-1',
          name: 'Second 1',
          isArchived: true,
        ),
      ]);
      expect(calls, 2);
    },
  );

  testWidgets(
    'linked-account dropdown keeps source order and filters archived accounts',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
            accountsProvider.overrideWith(
              (_) async => AppResult<List<Account>>.success(<Account>[
                _account('z-account', 'Zulu account'),
                _account(
                  'archived-account',
                  'Archived account',
                  isArchived: true,
                ),
                _account('a-account', 'Alpha account'),
              ]),
            ),
          ],
          child: _app(
            locale: const Locale('en'),
            child: const Scaffold(body: GoalFormSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_linkedAccountLabels(tester), <String>[
        'No linked account',
        'Zulu account',
        'Alpha account',
      ]);
      expect(find.text('Archived account'), findsNothing);
    },
  );

  testWidgets('linked-account dropdown treats loading and failure as empty', (
    tester,
  ) async {
    final pending = Completer<AppResult<List<Account>>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
          accountsProvider.overrideWith((_) => pending.future),
        ],
        child: _app(
          locale: const Locale('en'),
          child: const Scaffold(body: GoalFormSheet()),
        ),
      ),
    );
    await tester.pump();

    expect(_linkedAccountLabels(tester), <String>['No linked account']);

    pending.complete(
      const AppResult<List<Account>>.failure(
        Failure(message: 'Accounts unavailable.', code: 'accounts'),
      ),
    );
    await tester.pumpAndSettle();

    expect(_linkedAccountLabels(tester), <String>['No linked account']);
  });

  testWidgets('linked archived account remains visible in card and details', (
    tester,
  ) async {
    final goal = _goal(
      title: 'Linked goal',
      linkedAccountId: 'archived-account',
    );
    final progress = GoalProgress(
      goal: goal,
      currentAmount: Decimal.fromInt(750),
      remainingAmount: Decimal.fromInt(2250),
      progressPercent: Decimal.fromInt(25),
      daysRemaining: 90,
      monthlyNeeded: Decimal.fromInt(750),
      status: GoalStatus.active,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allGoalProgressProvider.overrideWith(
            (_) async =>
                AppResult<List<GoalProgress>>.success(<GoalProgress>[progress]),
          ),
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success(<Account>[
              _account('archived-account', 'Archived vault', isArchived: true),
            ]),
          ),
          goalContributionsProvider.overrideWith(
            (_, _) => Stream<AppResult<List<GoalContribution>>>.value(
              const AppResult<List<GoalContribution>>.success(
                <GoalContribution>[],
              ),
            ),
          ),
        ],
        child: _app(locale: const Locale('en'), child: const GoalsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Linked goal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Archived vault'), findsOneWidget);
    await tester.tap(find.text('Linked goal'));
    await tester.pumpAndSettle();

    expect(find.text('Goal details'), findsOneWidget);
    expect(find.text('Linked account'), findsNWidgets(2));
    expect(find.text('Archived vault'), findsNWidgets(2));
  });

  testWidgets('goals list renders without overflow at 320px in RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final goal = _goal();
    final progress = GoalProgress(
      goal: goal,
      currentAmount: Decimal.fromInt(750),
      remainingAmount: Decimal.fromInt(2250),
      progressPercent: Decimal.fromInt(25),
      daysRemaining: 90,
      monthlyNeeded: Decimal.fromInt(750),
      status: GoalStatus.active,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allGoalProgressProvider.overrideWith(
            (_) async => AppResult<List<GoalProgress>>.success([progress]),
          ),
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success(const []),
          ),
        ],
        child: _app(locale: const Locale('ar'), child: const GoalsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('حاسوب محمول'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('حاسوب محمول'), findsOneWidget);
    expect(find.byType(FinanceProgressBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add goal validates title and target', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success(const []),
          ),
        ],
        child: _app(
          locale: const Locale('en'),
          child: const Scaffold(body: GoalFormSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(CPButton, 'Save'));
    await tester.tap(find.widgetWithText(CPButton, 'Save'));
    await tester.pump();

    expect(find.text('Goal title'), findsWidgets);
    expect(
      find.text('Enter a target amount greater than zero.'),
      findsOneWidget,
    );
  });

  testWidgets('add contribution validates amount', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD')],
        child: _app(
          locale: const Locale('en'),
          child: Scaffold(body: GoalContributionSheet(goal: _goal())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(CPButton, 'Add contribution'),
    );
    await tester.tap(find.widgetWithText(CPButton, 'Add contribution'));
    await tester.pump();

    expect(
      find.text('Enter a contribution greater than zero.'),
      findsOneWidget,
    );
  });
}

Widget _app({required Locale locale, required Widget child}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: CPTheme.dark(),
  home: child,
);

List<String> _linkedAccountLabels(WidgetTester tester) {
  final field = tester.widget<DropdownButton<String>>(
    find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButton<String> &&
          widget.items!.any(
            (item) =>
                item.child is Text &&
                (item.child as Text).data == 'No linked account',
          ),
    ),
  );
  return field.items!
      .map((item) => (item.child as Text).data!)
      .toList(growable: false);
}

List<GoalLinkedAccountOption> _linkedAccountSuccess(
  AppResult<List<GoalLinkedAccountOption>> result,
) => switch (result) {
  AppSuccess<List<GoalLinkedAccountOption>>(:final data) => data,
  AppFailure<List<GoalLinkedAccountOption>>(:final failure) =>
    throw TestFailure(failure.message),
};

Account _account(String id, String name, {bool isArchived = false}) =>
    Account.create(
      id: id,
      name: name,
      type: AccountType.cash,
      currencyCode: 'LYD',
      balance: Decimal.zero,
      icon: 'wallet',
      color: 0xFF123456,
      isArchived: isArchived,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Goal _goal({String title = 'حاسوب محمول', String? linkedAccountId}) =>
    Goal.create(
      title: title,
      targetAmount: Decimal.fromInt(3000),
      currentAmount: Decimal.fromInt(750),
      currency: 'LYD',
      linkedAccountId: linkedAccountId,
      targetDate: DateTime.utc(2026, 10, 12),
    );
