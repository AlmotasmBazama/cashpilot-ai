import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/firebase/firebase_initializer.dart';
import 'package:cashpilot_ai/core/firebase/firebase_app_check_activation.dart';
import 'package:cashpilot_ai/core/logging/app_logger.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/firebase_ai_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/datasources/firebase_ai_provider_data_source.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/repositories/gemini_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_understanding_result.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_context_builder.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_draft_factory.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/create_ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/understand_ai_message.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'live Firebase AI chat separates conversation and classifies categories',
    (tester) async {
      if (AiRuntimeConfig.current.providerMode !=
          AiProviderMode.firebaseGemini) {
        fail('The live Firebase Gemini provider is not selected.');
      }
      if (firebaseAppCheckDebugToken.isEmpty) {
        fail('A registered App Check debug token was not supplied.');
      }

      await const DefaultFirebaseInitializer().initialize();
      final appCheckState = await defaultFirebaseAppCheckActivationController
          .activate();
      expect(
        appCheckState.isAvailable,
        isTrue,
        reason: 'App Check activation failed: ${appCheckState.safeCode}',
      );
      final modelConfig = AiModelConfig.current;
      expect(modelConfig.structuredOutputEnabled, isTrue);

      final liveRepository = GeminiRepository(
        providerDataSource: FirebaseAiProviderDataSource(
          config: FirebaseAiConfig.fromModelConfig(modelConfig),
        ),
        logger: AppLogger.instance,
      );
      final repository = _RecordingAiRepository(liveRepository);
      final understand = UnderstandAiMessage(
        createActionDraft: CreateAiActionDraft(
          aiRepository: repository,
          parser: const FinancialCommandParser(),
          draftFactory: const AiActionDraftFactory(),
          contextBuilder: const AiActionContextBuilder(),
        ),
      );
      final account = Account.create(
        id: 'smoke-test-cash',
        name: 'Cash',
        type: AccountType.cash,
        currencyCode: 'LYD',
        balance: Decimal.zero,
        icon: 'cash',
        color: 0xFF4F46E5,
      );

      final greeting = understand.understandLocally('مرحبا');
      expect(greeting, isA<AiConversationalUnderstanding>());
      expect(repository.sendCalls, 0);

      final milkResult = await understand(
        input: _safeMilkPrompt,
        accounts: <Account>[account],
        categories: buildDefaultCategories(),
        baseCurrencyCode: 'LYD',
        locale: 'ar',
        accountClarificationMessage: 'Which account should be used?',
        unknownIntentClarificationMessage:
            'Describe a supported financial question or draft.',
      );

      expect(repository.sendCalls, 1);
      expect(repository.providerSucceeded, isTrue);
      final milkDraft = switch (milkResult) {
        AppSuccess<AiUnderstandingResult>(
          data: AiFinancialActionUnderstanding(:final draft),
        ) =>
          draft,
        AppSuccess<AiUnderstandingResult>() => fail(
          'The milk request did not produce a reviewable action draft.',
        ),
        AppFailure<AiUnderstandingResult>(:final failure) => fail(
          'The chat pipeline failed safely with code '
          '${failure.code ?? 'ai_unknown'}.',
        ),
      };
      final milkAction = milkDraft.action;
      expect(milkAction, isA<CreateExpenseDraft>());
      expect(
        (milkAction as CreateExpenseDraft).transactionDraft.category?.name,
        'Groceries',
      );
      expect(
        milkDraft.status,
        isNot(
          anyOf(
            AiActionExecutionStatus.executing,
            AiActionExecutionStatus.executed,
          ),
        ),
      );

      final detergentResult = await understand(
        input: _safeDetergentPrompt,
        accounts: <Account>[account],
        categories: buildDefaultCategories(),
        baseCurrencyCode: 'LYD',
        locale: 'ar',
        accountClarificationMessage: 'Which account should be used?',
      );
      expect(repository.sendCalls, 2);
      final detergentDraft = switch (detergentResult) {
        AppSuccess<AiUnderstandingResult>(
          data: AiFinancialActionUnderstanding(:final draft),
        ) =>
          draft,
        AppSuccess<AiUnderstandingResult>() => fail(
          'The household request did not produce a reviewable action draft.',
        ),
        AppFailure<AiUnderstandingResult>(:final failure) => fail(
          'The household pipeline failed safely with code '
          '${failure.code ?? 'ai_unknown'}.',
        ),
      };
      final detergentAction = detergentDraft.action;
      expect(detergentAction, isA<CreateExpenseDraft>());
      expect(
        (detergentAction as CreateExpenseDraft).transactionDraft.category?.name,
        'Home',
      );

      final blocked = understand.understandLocally('نفذ بدون تأكيد');
      expect(blocked, isA<AiUnsupportedUnderstanding>());
      expect(repository.sendCalls, 2);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

const _safeMilkPrompt = 'اشتريت حليب ب5 كاش';
const _safeDetergentPrompt = 'اشتريت مسحوق غسيل ب15 كاش';

class _RecordingAiRepository implements AiRepository {
  _RecordingAiRepository(this._delegate);

  final AiRepository _delegate;
  int sendCalls = 0;
  bool providerSucceeded = false;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() {
    return _delegate.getAvailableModels();
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    sendCalls += 1;
    final result = await _delegate.sendMessage(request);
    providerSucceeded = result is AppSuccess<AiResponse>;
    return result;
  }
}
