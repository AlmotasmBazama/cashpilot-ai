// ignore_for_file: avoid_print

import 'package:cashpilot_ai/core/firebase/app_check_token_probe.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_connection_diagnostic.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/firebase_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/repositories/gemini_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_connection_diagnostic.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live Firebase AI passes the safe structured connection diagnostic',
    (tester) async {
      final runtimeConfig = AiRuntimeConfig.current;
      if (runtimeConfig.providerMode != AiProviderMode.firebaseGemini) {
        fail(
          'Run this test with '
          '--dart-define=CASH_PILOT_AI_PROVIDER=firebaseGemini.',
        );
      }
      if (firebaseAppCheckDebugToken.isEmpty) {
        fail(
          'Run this test with a registered App Check debug token using '
          '--dart-define or --dart-define-from-file.',
        );
      }

      try {
        await const DefaultFirebaseInitializer().initialize();
      } on Object {
        fail(
          'Firebase/App Check initialization failed. Verify the platform '
          'configuration, network access, and registered debug token.',
        );
      }

      final modelConfig = AiModelConfig.current;
      expect(modelConfig.structuredOutputEnabled, isTrue);
      final firebaseConfig = FirebaseAiConfig.fromModelConfig(modelConfig);
      final diagnostic = AiConnectionDiagnostic(
        runtimeConfig: runtimeConfig,
        modelConfig: modelConfig,
        repository: GeminiRepository(
          providerDataSource: FirebaseAiProviderDataSource(
            config: firebaseConfig,
          ),
          logger: AppLogger.instance,
        ),
        localParser: const FinancialCommandParser(),
        appCheckTokenProbe: const FirebaseAppCheckTokenProbe(),
      );

      late final AiConnectionDiagnosticResult result;
      try {
        result = await diagnostic();
      } on Object {
        fail('The safe Firebase AI connection diagnostic failed unexpectedly.');
      }
      final providerReady =
          result.status == AiConnectionDiagnosticStatus.providerReady;
      print(
        'FIREBASE_AI_DIAG completed=true '
        'providerReady=$providerReady '
        'providerAttempted=${result.providerAttempted} '
        'providerResponded=${result.providerResponded} '
        'appCheckReady=${result.appCheckReady == true}',
      );

      expect(
        result.status,
        AiConnectionDiagnosticStatus.providerReady,
        reason:
            'Safe diagnostic failed with code '
            '${result.failureCode ?? 'ai_unknown'}.',
      );
      expect(result.providerAttempted, isTrue);
      expect(result.providerResponded, isTrue);
      expect(result.appCheckReady, isTrue);
      expect(result.failureCode, isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
