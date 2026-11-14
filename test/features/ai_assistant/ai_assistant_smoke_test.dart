import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI assistant renders at 320px in RTL without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (_) async => const AppResult<List<Category>>.success([]),
          ),
          financialInsightsProvider.overrideWith(
            (_) async => const AppResult<List<FinancialInsight>>.success([]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: CPTheme.dark(),
          home: const AiAssistantScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AiAssistantScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
