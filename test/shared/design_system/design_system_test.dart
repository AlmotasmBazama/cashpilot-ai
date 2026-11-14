import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('theme exposes Material 3 and semantic finance colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CPTheme.light(),
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final colors = theme.extension<CPSemanticColors>();

            return Text(
              '${theme.useMaterial3}:${colors != null}:${colors?.income != colors?.expense}',
            );
          },
        ),
      ),
    );

    expect(find.text('true:true:true'), findsOneWidget);
  });

  test('redesign palette keeps light and dark surfaces distinct', () {
    final light = CPTheme.light().colorScheme;
    final dark = CPTheme.dark().colorScheme;

    expect(light.surfaceContainerLowest, CPColors.lightBackground);
    expect(light.surfaceContainerHigh, CPColors.lightSurface);
    expect(light.primary, CPColors.brandSeed);
    expect(dark.surfaceContainerLowest, CPColors.background);
    expect(dark.surfaceContainerHigh, CPColors.surface);
    expect(dark.primary, CPColors.brandAccent);
    expect(dark.surfaceContainerLowest, isNot(Colors.black));
  });

  testWidgets('shared widgets render in light and dark themes', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        designSystemApp(
          theme: brightness == Brightness.light
              ? CPTheme.light()
              : CPTheme.dark(),
          child: const _DesignSystemGallery(),
        ),
      );

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Empty title'), findsOneWidget);
      expect(find.byType(CPLoadingIndicator), findsOneWidget);
      expect(find.byType(CPSkeletonCard), findsOneWidget);
    }
  });

  testWidgets('representative widgets support LTR and RTL directions', (
    tester,
  ) async {
    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      await tester.pumpWidget(
        designSystemApp(
          textDirection: direction,
          child: Scaffold(
            appBar: CPAppBar(
              title: direction.name,
              subtitle: 'Subtitle',
              onBackPressed: () {},
            ),
            bottomNavigationBar: CPBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              items: const [
                CPNavigationItem(label: 'Home', icon: Icons.home_outlined),
                CPNavigationItem(label: 'Reports', icon: Icons.query_stats),
              ],
            ),
            body: const Column(
              children: [
                CPButton(
                  label: 'Direction',
                  icon: Icons.arrow_forward,
                  onPressed: _noop,
                ),
                CPAmountField(labelText: 'Amount', currencyCode: 'USD'),
                CPListTile(
                  title: 'Tile',
                  leading: Icon(Icons.account_balance_wallet_outlined),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text(direction.name), findsOneWidget);
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('Tile'), findsOneWidget);
      expect(find.byType(CPBottomNavigation), findsOneWidget);
    }
  });

  testWidgets('adaptive page behaves across supported width classes', (
    tester,
  ) async {
    for (final width in [390.0, 700.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        designSystemApp(
          child: const CPAdaptivePage(child: Text('Responsive body')),
        ),
      );

      expect(find.text('Responsive body'), findsOneWidget);
      expect(cpWindowSizeClassForWidth(width), isA<CPWindowSizeClass>());
    }
  });

  testWidgets('five-item bottom navigation stays readable at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CPTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: CPBottomNavigation(
            selectedIndex: 2,
            onDestinationSelected: (_) {},
            items: const [
              CPNavigationItem(label: 'Dashboard', icon: Icons.dashboard),
              CPNavigationItem(label: 'Accounts', icon: Icons.wallet),
              CPNavigationItem(label: 'Transactions', icon: Icons.receipt_long),
              CPNavigationItem(label: 'Reports', icon: Icons.query_stats),
              CPNavigationItem(label: 'Settings', icon: Icons.tune),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsOneWidget);
    final selectedSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .singleWhere((widget) => widget.properties.label == 'Transactions');
    expect(selectedSemantics.properties.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state scrolls instead of overflowing a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      designSystemApp(
        child: const Scaffold(
          body: SizedBox(
            height: 274,
            child: CPEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              message: 'Add an account to get started.',
              action: CPButton(label: 'Add account', onPressed: _noop),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
  });
}

Widget designSystemApp({
  required Widget child,
  ThemeData? theme,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MaterialApp(
    theme: theme ?? CPTheme.light(),
    home: Directionality(textDirection: textDirection, child: child),
  );
}

class _DesignSystemGallery extends StatelessWidget {
  const _DesignSystemGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CPAppBar(title: 'CashPilot'),
      floatingActionButton: const CPFloatingActionButton(
        onPressed: _noop,
        tooltip: 'Add',
      ),
      bottomNavigationBar: CPBottomNavigation(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        items: const [
          CPNavigationItem(label: 'Home', icon: Icons.home_outlined),
          CPNavigationItem(label: 'More', icon: Icons.more_horiz),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: const [
            CPSectionTitle(title: 'Section', subtitle: 'Reusable components'),
            CPCard(child: Text('Card')),
            CPButton(label: 'Primary', onPressed: _noop),
            CPButton(
              label: 'Danger',
              variant: CPButtonVariant.danger,
              onPressed: _noop,
            ),
            CPTextField(labelText: 'Name', hintText: 'Category name'),
            CPAmountField(labelText: 'Amount', currencyCode: 'USD'),
            CPListTile(title: 'List tile', subtitle: 'Subtitle'),
            CPEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Empty title',
              message: 'Nothing here yet.',
            ),
            CPLoadingIndicator(label: 'Loading'),
            CPSkeletonCard(height: 140, compact: true),
            CPErrorView(title: 'Error', message: 'Something went wrong.'),
          ],
        ),
      ),
    );
  }
}

void _noop() {}
