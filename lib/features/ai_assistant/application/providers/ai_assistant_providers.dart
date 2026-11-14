import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/firebase/app_check_token_probe.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/owner_scope/application/owner_scope_providers.dart';
import '../../../../core/owner_scope/application/scoped_app_database_session.dart';
import '../../../../core/owner_scope/domain/owner_scope.dart';
import '../../../budgets/application/providers/budgets_providers.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../../goals/application/providers/goals_providers.dart';
import '../../../transactions/application/providers/transactions_providers.dart';
import '../../../payees/application/providers/payees_providers.dart';
import '../../../auth/application/providers/auth_providers.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../services/ai_action_executor.dart';
import '../services/ai_transaction_mutation_draft_service.dart';
import '../services/ai_transaction_mutation_executor.dart';
import '../services/ai_prompt_send_guard.dart';
import '../../data/config/firebase_ai_config.dart';
import '../../data/config/ai_runtime_config.dart';
import '../../data/datasources/ai_provider_data_source.dart';
import '../../data/datasources/firebase_ai_provider_data_source.dart';
import '../../data/datasources/local_parser_only_ai_provider_data_source.dart';
import '../../data/datasources/mock_ai_provider_data_source.dart';
import '../../data/repositories/ai_repository_impl.dart';
import '../../data/repositories/gemini_repository.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_validation_result.dart';
import '../../domain/entities/ai_message.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/ai_request.dart';
import '../../domain/failures/ai_failure_codes.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/services/ai_action_context_builder.dart';
import '../../domain/services/ai_action_draft_factory.dart';
import '../../domain/services/ai_action_validator.dart';
import '../../domain/services/ai_intent_router.dart';
import '../../domain/services/financial_command_parser.dart';
import '../../domain/usecases/create_ai_action_draft.dart';
import '../../domain/usecases/get_available_ai_models.dart';
import '../../domain/usecases/parse_financial_command.dart';
import '../../domain/usecases/send_ai_message.dart';
import '../../domain/usecases/start_ai_conversation.dart';
import '../../domain/usecases/understand_ai_message.dart';
import '../ai_conversation_state.dart';
import 'ai_app_control_providers.dart';
import 'ai_agent_scope_providers.dart';

final aiRuntimeConfigProvider = Provider<AiRuntimeConfig>(
  (_) => AiRuntimeConfig.current,
  name: 'aiRuntimeConfigProvider',
);

final aiProviderTypeProvider = Provider<AiProviderMode>(
  (ref) => ref.watch(aiRuntimeConfigProvider).providerMode,
  name: 'aiProviderTypeProvider',
);

final aiModelConfigProvider = Provider<AiModelConfig>(
  (_) => AiModelConfig.current,
  name: 'aiModelConfigProvider',
);

final firebaseAiConfigProvider = Provider<FirebaseAiConfig>(
  (ref) => FirebaseAiConfig.fromModelConfig(ref.watch(aiModelConfigProvider)),
  name: 'firebaseAiConfigProvider',
);

final defaultAiModelIdProvider = Provider<String>(
  (ref) => switch (ref.watch(aiProviderTypeProvider)) {
    AiProviderMode.mock => MockAiProviderDataSource.defaultModelId,
    AiProviderMode.localParserOnly =>
      LocalParserOnlyAiProviderDataSource.modelId,
    AiProviderMode.firebaseGemini =>
      ref.watch(firebaseAiConfigProvider).defaultModelId,
  },
  name: 'defaultAiModelIdProvider',
);

final firebaseAiProviderDataSourceProvider =
    Provider<FirebaseAiProviderDataSource>(
      (ref) => FirebaseAiProviderDataSource(
        config: ref.watch(firebaseAiConfigProvider),
      ),
      name: 'firebaseAiProviderDataSourceProvider',
    );

final mockAiProviderDataSourceProvider = Provider<AiProviderDataSource>(
  (_) => const MockAiProviderDataSource(),
  name: 'mockAiProviderDataSourceProvider',
);

final localParserOnlyAiProviderDataSourceProvider =
    Provider<AiProviderDataSource>(
      (_) => const LocalParserOnlyAiProviderDataSource(),
      name: 'localParserOnlyAiProviderDataSourceProvider',
    );

final aiProviderDataSourceProvider = Provider<AiProviderDataSource>(
  (ref) => switch (ref.watch(aiProviderTypeProvider)) {
    AiProviderMode.mock => ref.watch(mockAiProviderDataSourceProvider),
    AiProviderMode.localParserOnly => ref.watch(
      localParserOnlyAiProviderDataSourceProvider,
    ),
    AiProviderMode.firebaseGemini => ref.watch(
      firebaseAiProviderDataSourceProvider,
    ),
  },
  name: 'aiProviderDataSourceProvider',
);

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final providerDataSource = ref.watch(aiProviderDataSourceProvider);
  if (providerDataSource case final FirebaseAiProviderDataSource dataSource) {
    return GeminiRepository(
      providerDataSource: dataSource,
      logger: ref.watch(appLoggerProvider),
    );
  }

  return AiRepositoryImpl(
    providerDataSource: providerDataSource,
    logger: ref.watch(appLoggerProvider),
  );
}, name: 'aiRepositoryProvider');

final getAvailableAiModelsUseCaseProvider = Provider<GetAvailableAiModels>(
  (ref) => GetAvailableAiModels(ref.watch(aiRepositoryProvider)),
  name: 'getAvailableAiModelsUseCaseProvider',
);

final sendAiMessageUseCaseProvider = Provider<SendAiMessage>(
  (ref) => SendAiMessage(ref.watch(aiRepositoryProvider)),
  name: 'sendAiMessageUseCaseProvider',
);

final startAiConversationUseCaseProvider = Provider<StartAiConversation>(
  (_) => const StartAiConversation(),
  name: 'startAiConversationUseCaseProvider',
);

final financialCommandParserProvider = Provider<FinancialCommandParser>(
  (ref) => FinancialCommandParser(
    timeZoneName:
        ref.watch(currentAuthUserProvider)?.timezone ?? 'Africa/Tripoli',
  ),
  name: 'financialCommandParserProvider',
);

final appCheckTokenProbeProvider = Provider<AppCheckTokenProbe>(
  (_) => const FirebaseAppCheckTokenProbe(),
  name: 'appCheckTokenProbeProvider',
);

final parseFinancialCommandUseCaseProvider = Provider<ParseFinancialCommand>(
  (ref) => ParseFinancialCommand(ref.watch(financialCommandParserProvider)),
  name: 'parseFinancialCommandUseCaseProvider',
);

final aiActionDraftFactoryProvider = Provider<AiActionDraftFactory>(
  (_) => const AiActionDraftFactory(),
  name: 'aiActionDraftFactoryProvider',
);

final aiActionContextBuilderProvider = Provider<AiActionContextBuilder>(
  (_) => const AiActionContextBuilder(),
  name: 'aiActionContextBuilderProvider',
);

final aiActionValidatorProvider = Provider<AiActionValidator>(
  (_) => const AiActionValidator(),
  name: 'aiActionValidatorProvider',
);

final aiIntentRouterProvider = Provider<AiIntentRouter>(
  (_) => const AiIntentRouter(),
  name: 'aiIntentRouterProvider',
);

final aiTransactionMutationDraftRepositoryProvider =
    Provider<AiTransactionMutationDraftService>(
      (ref) => AiTransactionMutationDraftService(
        transactions: ref.watch(transactionsRepositoryProvider),
        commandStore: ref.watch(appAgentCommandStoreProvider),
        executionStore: ref.watch(appAgentDurableExecutionStoreProvider),
        currentScope: () => ref.read(aiAgentAccountScopeProvider),
        currentTimeZone: () =>
            ref.read(currentAuthUserProvider)?.timezone ?? 'Africa/Tripoli',
      ),
      name: 'aiTransactionMutationDraftRepositoryProvider',
    );

final createAiActionDraftUseCaseProvider = Provider<CreateAiActionDraft>(
  (ref) => CreateAiActionDraft(
    aiRepository: ref.watch(aiRepositoryProvider),
    parser: ref.watch(financialCommandParserProvider),
    draftFactory: ref.watch(aiActionDraftFactoryProvider),
    contextBuilder: ref.watch(aiActionContextBuilderProvider),
    convertMoney: ref.watch(convertMoneyUseCaseProvider),
    transactionMutationDraftRepository: ref.watch(
      aiTransactionMutationDraftRepositoryProvider,
    ),
  ),
  name: 'createAiActionDraftUseCaseProvider',
);

final understandAiMessageUseCaseProvider = Provider<UnderstandAiMessage>(
  (ref) => UnderstandAiMessage(
    createActionDraft: ref.watch(createAiActionDraftUseCaseProvider),
    intentRouter: ref.watch(aiIntentRouterProvider),
  ),
  name: 'understandAiMessageUseCaseProvider',
);

final aiActionExecutorProvider = Provider<AiActionExecutor>(
  (ref) => AiActionExecutor(
    createTransaction: ref.watch(createTransactionUseCaseProvider),
    createTransfer: ref.watch(createTransferUseCaseProvider),
    createBudget: ref.watch(createBudgetUseCaseProvider),
    createGoal: ref.watch(createGoalUseCaseProvider),
    addGoalContribution: ref.watch(addGoalContributionUseCaseProvider),
    validator: ref.watch(aiActionValidatorProvider),
    touchPayeeLastUsed: ref.watch(touchPayeeLastUsedUseCaseProvider),
  ),
  name: 'aiActionExecutorProvider',
);

final aiTransactionMutationExecutorProvider =
    Provider<AiTransactionMutationExecutor>(
      (ref) => AiTransactionMutationExecutor(
        updateTransaction: ref.watch(updateTransactionUseCaseProvider),
        deleteTransaction: ref.watch(deleteTransactionUseCaseProvider),
        updateTransactionStatus: ref.watch(
          updateTransactionStatusUseCaseProvider,
        ),
        createTransaction: ref.watch(createTransactionUseCaseProvider),
        getTransaction: ref.watch(getTransactionUseCaseProvider),
      ),
      name: 'aiTransactionMutationExecutorProvider',
    );

final aiActionValidationProvider =
    Provider.family<AiActionValidationResult, AiAction>(
      (ref, action) => ref.watch(aiActionValidatorProvider).validate(action),
      name: 'aiActionValidationProvider',
    );

final availableAiModelsProvider = FutureProvider<AppResult<List<AiModel>>>(
  (ref) => ref.watch(getAvailableAiModelsUseCaseProvider)(),
  name: 'availableAiModelsProvider',
);

final aiConversationControllerProvider =
    NotifierProvider.autoDispose<AiConversationController, AiConversationState>(
      AiConversationController.new,
      name: 'aiConversationControllerProvider',
    );

class AiConversationController extends Notifier<AiConversationState> {
  AiPromptSendGuard _sendGuard = AiPromptSendGuard();
  var _operationVersion = 0;

  @override
  AiConversationState build() {
    ref.watch(currentAuthUserProvider);
    ref.watch(scopedAppDatabaseSessionProvider);
    _operationVersion += 1;
    _sendGuard = AiPromptSendGuard();
    final dataSource = ref.watch(aiProviderDataSourceProvider);
    final conversation = ref.watch(startAiConversationUseCaseProvider)(
      modelId: ref.watch(defaultAiModelIdProvider),
      metadata: const <String, Object?>{
        'source': 'aiConversationControllerProvider',
      },
    );

    return AiConversationState(
      conversation: conversation,
      providerType: dataSource.providerType,
    );
  }

  Future<AppResult<AiMessage>> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const AppResult.failure(
        Failure(message: 'AI message cannot be empty.'),
      );
    }
    final ownerBinding = _captureOwnerBinding();
    if (ownerBinding == null) {
      return _ownerSessionChanged();
    }
    final operationGuard = _sendGuard;
    final rejectionCode = operationGuard.tryStart(trimmed);
    if (rejectionCode != null) {
      return AppResult.failure(
        Failure(message: 'AI request was not sent.', code: rejectionCode),
      );
    }
    final operationVersion = ++_operationVersion;

    final userMessage = AiMessage.user(
      conversationId: state.conversation.id,
      content: trimmed,
    );
    final conversationWithUser = state.conversation.addMessage(userMessage);
    state = state.copyWith(
      conversation: conversationWithUser,
      isSending: true,
      clearFailure: true,
    );

    try {
      final result = await ref.read(sendAiMessageUseCaseProvider)(
        AiRequest(
          conversationId: conversationWithUser.id,
          modelId: conversationWithUser.modelId,
          messages: conversationWithUser.messages,
          metadata: const <String, Object?>{
            'source': 'aiConversationControllerProvider',
          },
        ),
      );

      if (!_isOwnerBindingCurrent(ownerBinding, operationVersion)) {
        return _ownerSessionChanged();
      }

      return switch (result) {
        AppSuccess(:final data) => _complete(data.message),
        AppFailure(:final failure) => _fail(failure),
      };
    } on Object {
      if (!_isOwnerBindingCurrent(ownerBinding, operationVersion)) {
        return _ownerSessionChanged();
      }
      return _fail(
        const Failure(
          message: 'AI request failed safely.',
          code: AiFailureCodes.unknown,
        ),
      );
    } finally {
      operationGuard.complete();
    }
  }

  AppResult<AiMessage> _complete(AiMessage assistantMessage) {
    state = state.copyWith(
      conversation: state.conversation.addMessage(assistantMessage),
      isSending: false,
      clearFailure: true,
    );

    return AppResult.success(assistantMessage);
  }

  AppResult<AiMessage> _fail(Failure failure) {
    state = state.copyWith(isSending: false, failure: failure);
    return AppResult.failure(failure);
  }

  void reset() {
    _operationVersion += 1;
    _sendGuard = AiPromptSendGuard();
    final dataSource = ref.read(aiProviderDataSourceProvider);
    state = AiConversationState(
      conversation: ref.read(startAiConversationUseCaseProvider)(
        modelId: ref.read(defaultAiModelIdProvider),
      ),
      providerType: dataSource.providerType,
    );
  }

  _AiConversationOwnerBinding? _captureOwnerBinding() {
    final user = ref.read(currentAuthUserProvider);
    final session = ref.read(scopedAppDatabaseSessionProvider);
    if (user == null || session == null || !session.isActive) {
      return null;
    }
    try {
      final expectedScope = OwnerScopeDerivation.fromConfirmedFirebaseUid(
        user.uid,
      );
      if (session.ownerScopeValue != expectedScope.id.value) {
        return null;
      }
    } on Object {
      return null;
    }
    return _AiConversationOwnerBinding(
      authSession: user.sessionIdentity,
      databaseSession: session,
    );
  }

  bool _isOwnerBindingCurrent(
    _AiConversationOwnerBinding expected,
    int operationVersion,
  ) {
    if (!ref.mounted || operationVersion != _operationVersion) {
      return false;
    }
    final currentUser = ref.read(currentAuthUserProvider);
    final currentSession = ref.read(scopedAppDatabaseSessionProvider);
    if (!expected.authSession.matches(currentUser) ||
        !identical(expected.databaseSession, currentSession) ||
        !expected.databaseSession.isActive) {
      return false;
    }
    try {
      return expected.databaseSession.ownerScopeValue ==
          OwnerScopeDerivation.fromConfirmedFirebaseUid(
            expected.authSession.uid,
          ).id.value;
    } on Object {
      return false;
    }
  }

  AppResult<AiMessage> _ownerSessionChanged() {
    return const AppResult.failure(
      Failure(
        message: 'A current confirmed account is required.',
        code: 'ai_owner_session_changed',
      ),
    );
  }
}

final class _AiConversationOwnerBinding {
  const _AiConversationOwnerBinding({
    required this.authSession,
    required this.databaseSession,
  });

  final AuthSessionIdentity authSession;
  final ScopedAppDatabaseSession databaseSession;
}
