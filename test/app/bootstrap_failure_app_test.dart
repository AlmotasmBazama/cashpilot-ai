import 'package:cashpilot_ai/app/bootstrap_failure_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap failure is friendly, localized, and retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var retryCount = 0;

    await tester.pumpWidget(
      BootstrapFailureApp(
        locale: const Locale('ar'),
        onRetry: () async {
          retryCount++;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(retryCount, 1);
    expect(tester.takeException(), isNull);
  });
}
