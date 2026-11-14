import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_suggestion.dart';
import '../../../income_sources/domain/entities/income_source_suggestion.dart';
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../app_agent/app_agent_reconciliation_service.dart';
import '../app_agent/durable_ai_action_bridge.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/agent/assistant_navigation_policy.dart';
import '../../domain/app_agent/app_agent_models.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_action_validation_result.dart';
import '../../domain/entities/ai_intent.dart';
import '../../domain/entities/ai_understanding_result.dart';
import '../../domain/failures/ai_failure_codes.dart';
import '../../domain/services/ai_intent_router.dart';
import '../../domain/usecases/understand_ai_message.dart';
import 'ai_assistant_durable_draft_coordinator.dart';
import 'ai_assistant_send_lifecycle_coordinator.dart';
import 'ai_financial_understanding_coordinator.dart';

typedef AiAssistantWorkflowEmissionSink =
    void Function(AiAssistantWorkflowEmission emission);
typedef AiAssistantWorkflowFrameBarrier = Future<void> Function();
typedef AiAssistantUnderstandingUseCaseReader = UnderstandAiMessage Function();
typedef AiAssistantFinancialCoordinatorReader =
    AiFinancialUnderstandingCoordinator Function();

abstract interface class AiAssistantAgentSessionPort {
  bool get agentEnabled;

  String get baseCurrencyCode;

  Future<AiAgentResponse?> send({
    required String content,
    required String locale,
    required String baseCurrencyCode,
  });

  Future<AiAgentResponse?> retry();

  Future<void> clear();

  Future<void> startNew();

  void cancel();

  AiAssistantRequestCancellation captureCancellation();

  void recordLocalUserMessage(String content);

  void recordLocalAssistantMessage(String content);
}

enum AiAssistantOwnerScopeReadiness { safe, legacyUnclaimed, unavailable }

abstract interface class AiAssistantActionPolicyPort {
  bool get appControlEnabled;

  int get configurationRevision;

  AiAssistantOwnerScopeReadiness get ownerScopeReadiness;

  Future<bool> readOwnerScopeSafe();

  Failure ownerUnavailableDraftFailure();

  Failure ownerUnavailableExecutionFailure(AiAction action);

  Failure? failureForIntent(AiIntent intent);

  Failure? failureForAction(
    AiAction action, {
    int? expectedConfigurationRevision,
  });

  Failure? executionFailureForAction(
    AiAction action, {
    int? expectedConfigurationRevision,
  });

  bool allowsAction(AiAction action);
}

abstract interface class AiAssistantDraftValidatorPort {
  AiActionValidationResult validate(AiAction action);
}

abstract interface class AiAssistantRecoveryPort {
  Future<AppAgentStartupReconciliationSummary> readStartupReconciliation();

  AiActionDurableRuntime readRuntime();

  bool tryConsume(AppAgentExecutionResult result);
}

abstract interface class AiAssistantFinancialReadInvalidator {
  void invalidateAfterVerifiedExecution();
}

final class AiAssistantWorkflowCopy {
  const AiAssistantWorkflowCopy({
    required this.recordIncomeOffer,
    required this.recordTransactionOffer,
    required this.recordIncomeOfferCancelled,
    required this.accountClarificationMessage,
    required this.expenseAccountClarificationMessage,
    required this.ambiguousPayeeMessage,
    required this.exchangeRateClarificationMessage,
    required this.categoryClarificationMessage,
    required this.goalClarificationMessage,
    required this.unknownIntentClarificationMessage,
    required this.actionConfirmationMessage,
    required this.incomeMissingDetails,
    required this.actionInvalidMessage,
    required this.explicitConfirmationText,
  });

  final String recordIncomeOffer;
  final String recordTransactionOffer;
  final String recordIncomeOfferCancelled;
  final String accountClarificationMessage;
  final String expenseAccountClarificationMessage;
  final String ambiguousPayeeMessage;
  final String exchangeRateClarificationMessage;
  final String categoryClarificationMessage;
  final String goalClarificationMessage;
  final String unknownIntentClarificationMessage;
  final String actionConfirmationMessage;
  final String incomeMissingDetails;
  final String actionInvalidMessage;
  final String explicitConfirmationText;
}

final class AiAssistantSubmitCommand {
  const AiAssistantSubmitCommand({
    required this.message,
    required this.locale,
    required this.copy,
  });

  final String message;
  final String locale;
  final AiAssistantWorkflowCopy copy;
}

final class AiAssistantPendingRecordOffer {
  const AiAssistantPendingRecordOffer({
    required this.input,
    required this.intent,
  });

  final String input;
  final AiIntent intent;
}

sealed class AiAssistantPendingLegacyAction {
  const AiAssistantPendingLegacyAction();
}

final class AiAssistantPendingLegacyInput
    extends AiAssistantPendingLegacyAction {
  const AiAssistantPendingLegacyInput({
    required this.input,
    required this.intent,
  });

  final String input;
  final AiIntent intent;
}

final class AiAssistantPendingLegacyDraft
    extends AiAssistantPendingLegacyAction {
  const AiAssistantPendingLegacyDraft(this.action);

  final AiAction action;
}

const _workflowAbsent = Object();

final class AiAssistantVerifiedAction {
  const AiAssistantVerifiedAction({required this.action, required this.result});

  final AiAction action;
  final AppAgentExecutionResult result;
}

final class AiAssistantConversationWorkflowState {
  AiAssistantConversationWorkflowState({
    this.draft,
    this.validation,
    this.understanding,
    List<Category> availableCategories = const <Category>[],
    List<Account> availableAccounts = const <Account>[],
    this.failure,
    this.submittedMessage,
    this.isParsing = false,
    this.isLoadingFinancialContext = false,
    this.pendingRecordOffer,
    this.pendingLegacyAction,
    this.legacyDataReadyToResume = false,
    this.verifiedAction,
  }) : availableCategories = List<Category>.unmodifiable(availableCategories),
       availableAccounts = List<Account>.unmodifiable(availableAccounts);

  final AiActionDraft? draft;
  final AiActionValidationResult? validation;
  final AiUnderstandingResult? understanding;
  final List<Category> availableCategories;
  final List<Account> availableAccounts;
  final Failure? failure;
  final String? submittedMessage;
  final bool isParsing;
  final bool isLoadingFinancialContext;
  final AiAssistantPendingRecordOffer? pendingRecordOffer;
  final AiAssistantPendingLegacyAction? pendingLegacyAction;
  final bool legacyDataReadyToResume;
  final AiAssistantVerifiedAction? verifiedAction;

  AiAssistantConversationWorkflowState copyWith({
    Object? draft = _workflowAbsent,
    Object? validation = _workflowAbsent,
    Object? understanding = _workflowAbsent,
    List<Category>? availableCategories,
    List<Account>? availableAccounts,
    Object? failure = _workflowAbsent,
    Object? submittedMessage = _workflowAbsent,
    bool? isParsing,
    bool? isLoadingFinancialContext,
    Object? pendingRecordOffer = _workflowAbsent,
    Object? pendingLegacyAction = _workflowAbsent,
    bool? legacyDataReadyToResume,
    Object? verifiedAction = _workflowAbsent,
  }) {
    return AiAssistantConversationWorkflowState(
      draft: identical(draft, _workflowAbsent)
          ? this.draft
          : draft as AiActionDraft?,
      validation: identical(validation, _workflowAbsent)
          ? this.validation
          : validation as AiActionValidationResult?,
      understanding: identical(understanding, _workflowAbsent)
          ? this.understanding
          : understanding as AiUnderstandingResult?,
      availableCategories: availableCategories ?? this.availableCategories,
      availableAccounts: availableAccounts ?? this.availableAccounts,
      failure: identical(failure, _workflowAbsent)
          ? this.failure
          : failure as Failure?,
      submittedMessage: identical(submittedMessage, _workflowAbsent)
          ? this.submittedMessage
          : submittedMessage as String?,
      isParsing: isParsing ?? this.isParsing,
      isLoadingFinancialContext:
          isLoadingFinancialContext ?? this.isLoadingFinancialContext,
      pendingRecordOffer: identical(pendingRecordOffer, _workflowAbsent)
          ? this.pendingRecordOffer
          : pendingRecordOffer as AiAssistantPendingRecordOffer?,
      pendingLegacyAction: identical(pendingLegacyAction, _workflowAbsent)
          ? this.pendingLegacyAction
          : pendingLegacyAction as AiAssistantPendingLegacyAction?,
      legacyDataReadyToResume:
          legacyDataReadyToResume ?? this.legacyDataReadyToResume,
      verifiedAction: identical(verifiedAction, _workflowAbsent)
          ? this.verifiedAction
          : verifiedAction as AiAssistantVerifiedAction?,
    );
  }
}

sealed class AiAssistantWorkflowEffect {
  const AiAssistantWorkflowEffect();
}

final class AiAssistantWorkflowClearComposer extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowClearComposer();
}

final class AiAssistantWorkflowReplaceComposer
    extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowReplaceComposer(this.text);

  final String text;
}

final class AiAssistantWorkflowUnfocus extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowUnfocus();
}

final class AiAssistantWorkflowRevealLatest extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowRevealLatest({this.force = false});

  final bool force;
}

final class AiAssistantWorkflowShowFailureSnack
    extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowShowFailureSnack(this.failure);

  final Failure failure;
}

enum AiAssistantWorkflowNotice {
  actionConfirmed,
  actionCancelled,
  financialDraftRejected,
}

final class AiAssistantWorkflowShowNotice extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowShowNotice(this.notice);

  final AiAssistantWorkflowNotice notice;
}

enum AiAssistantWorkflowSendBoundary { begin, end }

final class AiAssistantWorkflowSendBoundaryEffect
    extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowSendBoundaryEffect(this.boundary);

  final AiAssistantWorkflowSendBoundary boundary;
}

final class AiAssistantWorkflowNavigate extends AiAssistantWorkflowEffect {
  const AiAssistantWorkflowNavigate({
    required this.path,
    required this.safeReason,
  });

  final String path;
  final String safeReason;
}

final class AiAssistantWorkflowEmission {
  AiAssistantWorkflowEmission(
    this.state, [
    List<AiAssistantWorkflowEffect> effects =
        const <AiAssistantWorkflowEffect>[],
  ]) : effects = List<AiAssistantWorkflowEffect>.unmodifiable(effects);

  final AiAssistantConversationWorkflowState state;
  final List<AiAssistantWorkflowEffect> effects;
}

final class AiAssistantConversationWorkflowControllerFactory {
  const AiAssistantConversationWorkflowControllerFactory();

  AiAssistantConversationWorkflowController create({
    required AiToolOwnerScopeBinding? initialOwnerBinding,
    required AiAssistantOwnerBindingReader readOwnerBinding,
    required AiAssistantMountedReader isMounted,
    required AiAssistantSendLifecycleCoordinatorFactory sendLifecycleFactory,
    required AiAssistantDurableDraftCoordinatorFactory durableDraftFactory,
    required AiIntentRouter intentRouter,
    required AiAssistantUnderstandingUseCaseReader readUnderstandingUseCase,
    required AiAssistantFinancialCoordinatorReader readFinancialCoordinator,
    required AiAssistantAgentSessionPort agentSession,
    required AiAssistantActionPolicyPort actionPolicy,
    required AiAssistantDraftValidatorPort draftValidator,
    required AiAssistantRecoveryPort recovery,
    required AiAssistantFinancialReadInvalidator financialReadInvalidator,
    required AiAssistantWorkflowEmissionSink publish,
    required AiAssistantWorkflowFrameBarrier waitForRenderedFrame,
  }) {
    return AiAssistantConversationWorkflowController(
      sendLifecycle: sendLifecycleFactory.create(
        initialOwnerBinding: initialOwnerBinding,
        readOwnerBinding: readOwnerBinding,
        isMounted: isMounted,
      ),
      durableDraftCoordinator: durableDraftFactory.create(),
      intentRouter: intentRouter,
      readUnderstandingUseCase: readUnderstandingUseCase,
      readFinancialCoordinator: readFinancialCoordinator,
      agentSession: agentSession,
      actionPolicy: actionPolicy,
      draftValidator: draftValidator,
      recovery: recovery,
      financialReadInvalidator: financialReadInvalidator,
      publish: publish,
      waitForRenderedFrame: waitForRenderedFrame,
      isMounted: isMounted,
    );
  }
}

final class AiAssistantConversationWorkflowController {
  AiAssistantConversationWorkflowController({
    required AiAssistantSendLifecycleCoordinator sendLifecycle,
    required AiAssistantDurableDraftCoordinator durableDraftCoordinator,
    required AiIntentRouter intentRouter,
    required AiAssistantUnderstandingUseCaseReader readUnderstandingUseCase,
    required AiAssistantFinancialCoordinatorReader readFinancialCoordinator,
    required AiAssistantAgentSessionPort agentSession,
    required AiAssistantActionPolicyPort actionPolicy,
    required AiAssistantDraftValidatorPort draftValidator,
    required AiAssistantRecoveryPort recovery,
    required AiAssistantFinancialReadInvalidator financialReadInvalidator,
    required AiAssistantWorkflowEmissionSink publish,
    required AiAssistantWorkflowFrameBarrier waitForRenderedFrame,
    required AiAssistantMountedReader isMounted,
  }) : _sendLifecycle = sendLifecycle,
       _durableDraftCoordinator = durableDraftCoordinator,
       _intentRouter = intentRouter,
       _readUnderstandingUseCase = readUnderstandingUseCase,
       _readFinancialCoordinator = readFinancialCoordinator,
       _agentSession = agentSession,
       _actionPolicy = actionPolicy,
       _draftValidator = draftValidator,
       _recovery = recovery,
       _financialReadInvalidator = financialReadInvalidator,
       _publish = publish,
       _waitForRenderedFrame = waitForRenderedFrame,
       _isMounted = isMounted;

  final AiAssistantSendLifecycleCoordinator _sendLifecycle;
  final AiAssistantDurableDraftCoordinator _durableDraftCoordinator;
  final AiIntentRouter _intentRouter;
  final AiAssistantUnderstandingUseCaseReader _readUnderstandingUseCase;
  final AiAssistantFinancialCoordinatorReader _readFinancialCoordinator;
  final AiAssistantAgentSessionPort _agentSession;
  final AiAssistantActionPolicyPort _actionPolicy;
  final AiAssistantDraftValidatorPort _draftValidator;
  final AiAssistantRecoveryPort _recovery;
  final AiAssistantFinancialReadInvalidator _financialReadInvalidator;
  final AiAssistantWorkflowEmissionSink _publish;
  final AiAssistantWorkflowFrameBarrier _waitForRenderedFrame;
  final AiAssistantMountedReader _isMounted;

  AiAssistantConversationWorkflowState _state =
      AiAssistantConversationWorkflowState();

  AiAssistantConversationWorkflowState get state => _state;

  bool get hasActiveOperation => _sendLifecycle.hasActiveOperation;

  AiAssistantRequestCancellation? detachCancellationForDispose() =>
      _sendLifecycle.detachCancellationForDispose();

  void cancelForLifecycleTransition() {
    _sendLifecycle.invalidateAndCancelActiveOperation();
    _agentSession.cancel();
    if (_isMounted() &&
        (_state.isParsing || _state.isLoadingFinancialContext)) {
      _emit(
        _state.copyWith(isParsing: false, isLoadingFinancialContext: false),
      );
    }
  }

  bool handleOwnerBindingChanged(
    AiToolOwnerScopeBinding? previous,
    AiToolOwnerScopeBinding? next,
  ) {
    if (!_sendLifecycle.handleOwnerBindingChanged(previous, next)) return false;
    _clearOwnerBoundState(cancelCapturedDraft: true);
    return next != null && _isMounted();
  }

  void _emit(
    AiAssistantConversationWorkflowState next, {
    List<AiAssistantWorkflowEffect> effects =
        const <AiAssistantWorkflowEffect>[],
  }) {
    _state = next;
    _publish(AiAssistantWorkflowEmission(next, effects));
  }

  bool _isCurrent(AiAssistantOwnerOperation operation) =>
      _sendLifecycle.isCurrent(operation);

  AiAssistantOwnerOperation? _beginOperation({
    required bool requireConfirmedOwner,
    bool supersedeExisting = true,
  }) => _sendLifecycle.beginOwnerOperation(
    requireConfirmedOwner: requireConfirmedOwner,
    supersedeExisting: supersedeExisting,
  );

  void _clearOwnerBoundState({required bool cancelCapturedDraft}) {
    final draft = _state.draft;
    final runtime = _durableDraftCoordinator.clearVisibleDraftBinding();
    if (cancelCapturedDraft && draft != null && runtime != null) {
      unawaited(_cancelDurableDraft(draft.id, runtime: runtime));
    }
    _emit(
      AiAssistantConversationWorkflowState(),
      effects: const <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowClearComposer(),
      ],
    );
  }

  void _showFinancialRecordOffer({
    required String message,
    required AiIntent intent,
    required AiAssistantWorkflowCopy copy,
  }) {
    final existingDraft = _state.draft;
    if (existingDraft != null) {
      unawaited(
        _cancelDurableDraft(
          existingDraft.id,
          runtime: _durableDraftCoordinator.visibleRuntime,
        ),
      );
    }
    _durableDraftCoordinator.clearVisibleDraftBinding();
    _agentSession
      ..recordLocalUserMessage(message)
      ..recordLocalAssistantMessage(
        intent == AiIntent.createIncome
            ? copy.recordIncomeOffer
            : copy.recordTransactionOffer,
      );
    _emit(
      AiAssistantConversationWorkflowState(
        pendingRecordOffer: AiAssistantPendingRecordOffer(
          input: message,
          intent: intent,
        ),
      ),
      effects: const <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowClearComposer(),
        AiAssistantWorkflowUnfocus(),
        AiAssistantWorkflowRevealLatest(),
      ],
    );
    _sendLifecycle.completeAdmission();
  }

  void _completeRecordOfferDecline({
    required String message,
    required AiAssistantWorkflowCopy copy,
  }) {
    _agentSession
      ..recordLocalUserMessage(message)
      ..recordLocalAssistantMessage(copy.recordIncomeOfferCancelled);
    _emit(
      AiAssistantConversationWorkflowState(),
      effects: const <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowClearComposer(),
        AiAssistantWorkflowUnfocus(),
        AiAssistantWorkflowRevealLatest(),
      ],
    );
    _sendLifecycle.completeAdmission();
  }

  Future<void> submit(AiAssistantSubmitCommand command) async {
    if (_state.isParsing) return;
    final message = command.message.trim();
    if (message.isEmpty) return;

    final admission = _sendLifecycle.tryAdmit(message);
    if (admission case AiAssistantSendRejected(:final code)) {
      _emit(
        _state,
        effects: <AiAssistantWorkflowEffect>[
          AiAssistantWorkflowShowFailureSnack(
            Failure(message: 'AI request was not sent.', code: code),
          ),
        ],
      );
      return;
    }

    final route = _intentRouter.route(
      message,
      awaitingFinancialClarification:
          _state.understanding is AiClarificationUnderstanding,
    );
    final pendingRecordOffer = _state.pendingRecordOffer;
    final recordOfferDecision = pendingRecordOffer == null
        ? FinancialRecordOfferDecision.none
        : _intentRouter.recordOfferDecisionFor(message);
    if (pendingRecordOffer != null &&
        recordOfferDecision == FinancialRecordOfferDecision.decline) {
      _completeRecordOfferDecline(message: message, copy: command.copy);
      return;
    }
    if (route.isFinancialRecordOffer &&
        route.recordOfferDecision == FinancialRecordOfferDecision.none) {
      _showFinancialRecordOffer(
        message: message,
        intent: route.intent,
        copy: command.copy,
      );
      return;
    }

    final confirmsPendingRecordOffer =
        pendingRecordOffer != null &&
        (recordOfferDecision == FinancialRecordOfferDecision.accept ||
            (route.isExplicitMutationRequest &&
                (route.intent == pendingRecordOffer.intent ||
                    route.intent == AiIntent.clarificationResponse)));
    final effectiveIntent = confirmsPendingRecordOffer
        ? pendingRecordOffer.intent
        : route.intent;
    final isFinancialAction =
        confirmsPendingRecordOffer ||
        route.target == AssistantRouteTarget.financialAction;
    final financialInput = confirmsPendingRecordOffer
        ? pendingRecordOffer.input
        : message;
    final resumableAction = isFinancialAction
        ? AiAssistantPendingLegacyInput(
            input: financialInput,
            intent: effectiveIntent,
          )
        : null;
    final useAgent =
        route.target == AssistantRouteTarget.directConversation ||
        (!isFinancialAction && _agentSession.agentEnabled);
    final operation = _beginOperation(requireConfirmedOwner: isFinancialAction);
    if (operation == null) {
      final failure = _actionPolicy.ownerUnavailableDraftFailure();
      _agentSession.recordLocalUserMessage(message);
      _sendLifecycle.completeAdmission();
      _emit(
        AiAssistantConversationWorkflowState(
          submittedMessage: message,
          failure: failure,
        ),
        effects: const <AiAssistantWorkflowEffect>[
          AiAssistantWorkflowClearComposer(),
          AiAssistantWorkflowUnfocus(),
          AiAssistantWorkflowRevealLatest(),
        ],
      );
      return;
    }
    _sendLifecycle.activateOperation(operation);
    final clarificationAccounts = _state.availableAccounts;
    final clarificationCategories = _state.availableCategories;
    final existingDraft = _state.draft;
    if (existingDraft != null) {
      final runtime = _durableDraftCoordinator.visibleRuntime;
      if (runtime != null) {
        unawaited(_cancelDurableDraft(existingDraft.id, runtime: runtime));
      }
    }
    _durableDraftCoordinator.clearVisibleDraftBinding();
    _emit(
      AiAssistantConversationWorkflowState(
        isParsing: true,
        submittedMessage: useAgent ? null : message,
      ),
      effects: const <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowClearComposer(),
        AiAssistantWorkflowUnfocus(),
        AiAssistantWorkflowRevealLatest(),
        AiAssistantWorkflowSendBoundaryEffect(
          AiAssistantWorkflowSendBoundary.begin,
        ),
      ],
    );

    try {
      if (useAgent) {
        _sendLifecycle.setActiveRequestCancellation(
          _agentSession.captureCancellation(),
        );
        final response = await _agentSession.send(
          content: message,
          locale: command.locale,
          baseCurrencyCode: _agentSession.baseCurrencyCode,
        );
        if (!_isCurrent(operation) || !_isMounted()) return;
        if (AssistantNavigationPolicy.isApprovedResponse(
          isAppNavigationRoute:
              route.target == AssistantRouteTarget.appNavigation,
          selectedToolName: route.navigationToolId,
          response: response,
        )) {
          _emit(
            _state,
            effects: <AiAssistantWorkflowEffect>[
              AiAssistantWorkflowNavigate(
                path: response!.navigationPath!,
                safeReason: 'approved_local_navigation_tool',
              ),
            ],
          );
        }
        return;
      }

      _agentSession.recordLocalUserMessage(message);
      if (isFinancialAction) {
        final permissionFailure = _actionPolicy.failureForIntent(
          effectiveIntent,
        );
        if (permissionFailure != null) {
          _preserveLegacyAction(permissionFailure, resumableAction);
          _showFailure(permissionFailure);
          return;
        }
      }

      final understandingUseCase = _readUnderstandingUseCase();
      if (route.intent == AiIntent.clarificationResponse &&
          clarificationAccounts.isNotEmpty &&
          clarificationCategories.isNotEmpty) {
        final result = await understandingUseCase(
          input: financialInput,
          accounts: clarificationAccounts,
          categories: clarificationCategories,
          baseCurrencyCode: _agentSession.baseCurrencyCode,
          locale: command.locale,
          accountClarificationMessage: command.copy.accountClarificationMessage,
          expenseAccountClarificationMessage:
              command.copy.expenseAccountClarificationMessage,
          ambiguousPayeeMessage: command.copy.ambiguousPayeeMessage,
          exchangeRateClarificationMessage:
              command.copy.exchangeRateClarificationMessage,
          categoryClarificationMessage:
              command.copy.categoryClarificationMessage,
          goalClarificationMessage: command.copy.goalClarificationMessage,
          unknownIntentClarificationMessage:
              command.copy.unknownIntentClarificationMessage,
        );
        if (!_isCurrent(operation)) return;
        switch (result) {
          case AppSuccess<AiUnderstandingResult>(:final data):
            await _applyUnderstanding(
              data,
              operation: operation,
              resumableAction: resumableAction,
              copy: command.copy,
            );
          case AppFailure<AiUnderstandingResult>(:final failure):
            _showFailure(failure, operation: operation);
        }
        return;
      }
      final localUnderstanding = confirmsPendingRecordOffer
          ? null
          : understandingUseCase.understandLocally(message);
      if (localUnderstanding != null) {
        await _applyUnderstanding(
          localUnderstanding,
          operation: operation,
          resumableAction: resumableAction,
          copy: command.copy,
        );
        return;
      }

      _emit(_state.copyWith(isLoadingFinancialContext: true));
      await _waitForRenderedFrame();
      if (!_isCurrent(operation)) return;
      final outcome = await _readFinancialCoordinator().understand(
        understandingUseCase: understandingUseCase,
        request: AiFinancialUnderstandingRequest(
          input: financialInput,
          locale: command.locale,
          accountClarificationMessage: command.copy.accountClarificationMessage,
          expenseAccountClarificationMessage:
              command.copy.expenseAccountClarificationMessage,
          ambiguousPayeeMessage: command.copy.ambiguousPayeeMessage,
          exchangeRateClarificationMessage:
              command.copy.exchangeRateClarificationMessage,
          categoryClarificationMessage:
              command.copy.categoryClarificationMessage,
          goalClarificationMessage: command.copy.goalClarificationMessage,
          unknownIntentClarificationMessage:
              command.copy.unknownIntentClarificationMessage,
          explicitlyConfirmedMutation: confirmsPendingRecordOffer,
        ),
        isCurrent: () => _isCurrent(operation),
      );
      switch (outcome) {
        case AiFinancialUnderstandingSuperseded():
          return;
        case AiFinancialUnderstandingCompleted(
          :final understanding,
          :final accounts,
          :final categories,
        ):
          _state = _state.copyWith(
            availableCategories: categories,
            availableAccounts: accounts,
          );
          await _applyUnderstanding(
            understanding,
            operation: operation,
            resumableAction: resumableAction,
            copy: command.copy,
          );
        case AiFinancialUnderstandingFailed(:final failure):
          _showFailure(failure, operation: operation);
      }
    } on Object {
      if (_isCurrent(operation)) {
        _showFailure(
          const Failure(
            message: 'AI request failed safely.',
            code: AiFailureCodes.unknown,
          ),
          operation: operation,
        );
      }
    } finally {
      final finish = _sendLifecycle.finishOperation(
        operation,
        cleanup: AiAssistantActiveOperationCleanup.send,
      );
      if (finish.isCurrent) {
        _emit(
          _state.copyWith(isParsing: false, isLoadingFinancialContext: false),
          effects: const <AiAssistantWorkflowEffect>[
            AiAssistantWorkflowSendBoundaryEffect(
              AiAssistantWorkflowSendBoundary.end,
            ),
            AiAssistantWorkflowRevealLatest(),
          ],
        );
      } else {
        _publish(
          AiAssistantWorkflowEmission(_state, const <AiAssistantWorkflowEffect>[
            AiAssistantWorkflowSendBoundaryEffect(
              AiAssistantWorkflowSendBoundary.end,
            ),
          ]),
        );
      }
    }
  }

  Future<void> startNewConversation() async {
    _sendLifecycle.invalidateAndCancelActiveOperation();
    _clearOwnerBoundState(cancelCapturedDraft: true);
    await _agentSession.startNew();
  }

  Future<void> retryAgentResponse() async {
    if (_state.isParsing) return;
    final operation = _beginOperation(requireConfirmedOwner: false)!;
    _sendLifecycle.activateOperation(operation);
    _sendLifecycle.setActiveRequestCancellation(
      _agentSession.captureCancellation(),
    );
    _emit(_state.copyWith(isParsing: true));
    try {
      await _agentSession.retry();
    } finally {
      final finish = _sendLifecycle.finishOperation(
        operation,
        cleanup: AiAssistantActiveOperationCleanup.retry,
      );
      if (finish.isCurrent) {
        _emit(
          _state.copyWith(isParsing: false),
          effects: const <AiAssistantWorkflowEffect>[
            AiAssistantWorkflowRevealLatest(),
          ],
        );
      }
    }
  }

  Future<void> confirmAndClear({
    required Future<bool?> Function() showDialog,
  }) async {
    final operation = _beginOperation(requireConfirmedOwner: false)!;
    final confirmed = await showDialog();
    if (!_isCurrent(operation) || confirmed != true) return;
    await _agentSession.clear();
    if (!_isCurrent(operation)) return;
    _clearOwnerBoundState(cancelCapturedDraft: true);
  }

  void _showFailure(Failure failure, {AiAssistantOwnerOperation? operation}) {
    if (!_isMounted() || (operation != null && !_isCurrent(operation))) return;
    _emit(
      _state.copyWith(
        failure: failure,
        draft: null,
        validation: null,
        understanding: null,
      ),
    );
  }

  void _preserveLegacyAction(
    Failure failure,
    AiAssistantPendingLegacyAction? action,
  ) {
    if (failure.code != AppAgentFailureCodes.legacyDataUnresolved ||
        action == null) {
      return;
    }
    _state = _state.copyWith(
      pendingLegacyAction: action,
      legacyDataReadyToResume: false,
    );
  }

  Future<void> linkLegacyData({
    required Future<bool> Function() showClaimDialog,
  }) async {
    final pending = _state.pendingLegacyAction;
    if (pending == null || _state.legacyDataReadyToResume) return;
    final operation = _beginOperation(requireConfirmedOwner: true);
    if (operation == null) {
      _showFailure(_actionPolicy.ownerUnavailableDraftFailure());
      return;
    }
    final claimedAndSafe = await showClaimDialog();
    if (!_isCurrent(operation) || !claimedAndSafe) return;
    bool verifiedSafe;
    try {
      verifiedSafe = await _actionPolicy.readOwnerScopeSafe();
    } on Object {
      verifiedSafe = false;
    }
    if (!_isCurrent(operation)) return;
    if (!verifiedSafe) {
      _showFailure(
        _actionPolicy.ownerUnavailableDraftFailure(),
        operation: operation,
      );
      return;
    }
    if (!_isMounted() || !identical(_state.pendingLegacyAction, pending)) {
      return;
    }
    _emit(
      _state.copyWith(legacyDataReadyToResume: true),
      effects: const <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowRevealLatest(),
      ],
    );
  }

  Future<void> resumeLegacyAction({
    required String locale,
    required AiAssistantWorkflowCopy copy,
  }) async {
    if (_state.isParsing || !_state.legacyDataReadyToResume) return;
    final pending = _state.pendingLegacyAction;
    if (pending == null) return;
    final operation = _beginOperation(requireConfirmedOwner: true);
    if (operation == null) {
      _state = _state.copyWith(legacyDataReadyToResume: false);
      _showFailure(_actionPolicy.ownerUnavailableDraftFailure());
      return;
    }
    final readiness = _actionPolicy.ownerScopeReadiness;
    if (readiness != AiAssistantOwnerScopeReadiness.safe) {
      final failure =
          readiness == AiAssistantOwnerScopeReadiness.legacyUnclaimed
          ? _failureForStillUnresolvedLegacy(pending)
          : _actionPolicy.ownerUnavailableDraftFailure();
      _state = _state.copyWith(legacyDataReadyToResume: false);
      _preserveLegacyAction(failure, pending);
      _showFailure(failure);
      return;
    }

    if (pending case AiAssistantPendingLegacyDraft(:final action)) {
      _sendLifecycle.activateOperation(operation);
      _emit(
        _state.copyWith(
          isParsing: true,
          failure: null,
          draft: null,
          validation: null,
          understanding: null,
        ),
        effects: const <AiAssistantWorkflowEffect>[
          AiAssistantWorkflowRevealLatest(),
        ],
      );
      try {
        await _applyUnderstanding(
          AiFinancialActionUnderstanding(
            draft: AiActionDraft.create(action: action),
          ),
          operation: operation,
          resumableAction: pending,
          copy: copy,
        );
        if (_isCurrent(operation) &&
            _state.draft != null &&
            _state.failure == null) {
          _emit(
            _state.copyWith(
              pendingLegacyAction: null,
              legacyDataReadyToResume: false,
            ),
          );
        }
      } finally {
        final finish = _sendLifecycle.finishOperation(
          operation,
          cleanup: AiAssistantActiveOperationCleanup.operationOnly,
        );
        if (finish.isCurrent) {
          _emit(
            _state.copyWith(isParsing: false),
            effects: const <AiAssistantWorkflowEffect>[
              AiAssistantWorkflowRevealLatest(),
            ],
          );
        }
      }
      return;
    }

    final inputPending = pending as AiAssistantPendingLegacyInput;
    _emit(
      _state.copyWith(
        pendingRecordOffer: AiAssistantPendingRecordOffer(
          input: inputPending.input,
          intent: inputPending.intent,
        ),
        failure: null,
        legacyDataReadyToResume: false,
      ),
      effects: <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowReplaceComposer(copy.explicitConfirmationText),
      ],
    );
    _sendLifecycle.resetAdmission();
    await submit(
      AiAssistantSubmitCommand(
        message: copy.explicitConfirmationText,
        locale: locale,
        copy: copy,
      ),
    );
  }

  Failure _failureForStillUnresolvedLegacy(
    AiAssistantPendingLegacyAction pending,
  ) {
    final action = switch (pending) {
      AiAssistantPendingLegacyDraft(:final action) => action,
      _ => null,
    };
    return action == null
        ? _actionPolicy.failureForIntent(AiIntent.createIncome) ??
              _actionPolicy.ownerUnavailableDraftFailure()
        : _actionPolicy.failureForAction(action) ??
              _actionPolicy.ownerUnavailableDraftFailure();
  }

  Future<void> _applyUnderstanding(
    AiUnderstandingResult understanding, {
    required AiAssistantOwnerOperation operation,
    required AiAssistantWorkflowCopy copy,
    AiAssistantPendingLegacyAction? resumableAction,
  }) async {
    if (!_isCurrent(operation)) return;
    final draft = switch (understanding) {
      AiFinancialActionUnderstanding(:final draft) ||
      AiFinancialQuestionUnderstanding(:final draft) ||
      AiClarificationUnderstanding(:final draft) => draft,
      _ => null,
    };
    if (draft != null) {
      final permissionFailure = _actionPolicy.failureForAction(draft.action);
      if (permissionFailure != null) {
        _preserveLegacyAction(
          permissionFailure,
          resumableAction ?? AiAssistantPendingLegacyDraft(draft.action),
        );
        _showFailure(permissionFailure);
        return;
      }
    }
    final validation = draft == null
        ? null
        : _draftValidator.validate(draft.action);
    if (draft != null && validation != null) {
      final durableOutcome = await _durableDraftCoordinator.prepare(
        draft: draft,
        validation: validation,
        isDurableFinancialCreate: _isDurableFinancialCreate(draft.action),
        policyRevision: _actionPolicy.configurationRevision,
        isCurrent: () => _isCurrent(operation),
        readRuntime: _recovery.readRuntime,
        readPermissionFailure: (expectedRevision) =>
            _actionPolicy.failureForAction(
              draft.action,
              expectedConfigurationRevision: expectedRevision,
            ),
      );
      switch (durableOutcome) {
        case AiAssistantDurableDraftSuperseded():
          return;
        case AiAssistantDurableDraftPersistenceFailed(:final failure):
          _showFailure(failure, operation: operation);
          return;
        case AiAssistantDurableDraftPermissionRejected(:final failure):
          _preserveLegacyAction(
            failure,
            resumableAction ?? AiAssistantPendingLegacyDraft(draft.action),
          );
          _showFailure(failure, operation: operation);
          return;
        case AiAssistantDurableDraftReady():
          break;
      }
    } else {
      _durableDraftCoordinator.bindVisibleDraft(
        runtime: null,
        policyRevision: null,
      );
    }
    if (!_isMounted() || !_isCurrent(operation)) return;
    _emit(
      _state.copyWith(
        understanding: understanding,
        draft: draft,
        validation: validation,
        failure: null,
      ),
    );
    // Clarifications already render as the active workflow response. Recording
    // the same text in the local agent transcript would show it twice.
    if (draft != null && draft.action is! ClarificationRequiredAction) {
      final compactFinancialPreview =
          validation?.isValid == true &&
          _isDurableFinancialCreate(draft.action);
      // A complete transaction preview is the one and only confirmation UI.
      // Do not add a second assistant message asking the user to confirm it.
      if (!compactFinancialPreview) {
        _agentSession.recordLocalAssistantMessage(
          validation?.isValid == true
              ? copy.actionConfirmationMessage
              : draft.action is CreateIncomeDraft
              ? copy.incomeMissingDetails
              : validation?.message ?? copy.actionInvalidMessage,
        );
      }
    }
  }

  Future<void> confirmDraft() async {
    final draft = _state.draft;
    if (draft == null ||
        draft.status != AiActionExecutionStatus.awaitingConfirmation) {
      return;
    }
    final operation = _beginOperation(requireConfirmedOwner: true);
    if (operation == null) {
      final failure = _actionPolicy.ownerUnavailableExecutionFailure(
        draft.action,
      );
      _clearOwnerBoundState(cancelCapturedDraft: true);
      _emit(
        _state,
        effects: <AiAssistantWorkflowEffect>[
          AiAssistantWorkflowShowFailureSnack(failure),
        ],
      );
      return;
    }
    await _durableDraftCoordinator.confirm(
      draft: draft,
      isCurrent: () => _isCurrent(operation),
      isMounted: _isMounted,
      readFallbackRuntime: _recovery.readRuntime,
      readDraftPermissionFailure: (expectedRevision) =>
          _actionPolicy.failureForAction(
            draft.action,
            expectedConfigurationRevision: expectedRevision,
          ),
      readExecutionPermissionFailure: (expectedRevision) =>
          _actionPolicy.executionFailureForAction(
            draft.action,
            expectedConfigurationRevision: expectedRevision,
          ),
      readCurrentExecutionPermissionFailure: () =>
          _actionPolicy.executionFailureForAction(draft.action),
      preserveLegacyAction: (failure) => _preserveLegacyAction(
        failure,
        AiAssistantPendingLegacyDraft(draft.action),
      ),
      markExecuting: () {
        _emit(
          _state.copyWith(
            draft: draft.withStatus(AiActionExecutionStatus.executing),
          ),
        );
      },
      invalidateFinancialReads:
          _financialReadInvalidator.invalidateAfterVerifiedExecution,
      publishVerifiedSuccess: (result) {
        _emit(
          AiAssistantConversationWorkflowState(
            verifiedAction: AiAssistantVerifiedAction(
              action: draft.action,
              result: result,
            ),
          ),
          effects: const <AiAssistantWorkflowEffect>[
            AiAssistantWorkflowClearComposer(),
            AiAssistantWorkflowShowNotice(
              AiAssistantWorkflowNotice.actionConfirmed,
            ),
          ],
        );
      },
      publishPreflightFailure: _showFailure,
      publishLegacyFailure: (failure) =>
          _showFailure(failure, operation: operation),
      publishExecutionFailure: (failure) {
        _emit(
          _state.copyWith(
            draft: draft.withStatus(AiActionExecutionStatus.failed),
          ),
          effects: <AiAssistantWorkflowEffect>[
            AiAssistantWorkflowShowFailureSnack(failure),
          ],
        );
      },
    );
  }

  Future<void> retryFailedDraft() async {
    final failedDraft = _state.draft;
    if (failedDraft == null ||
        failedDraft.status != AiActionExecutionStatus.failed ||
        !_isDurableFinancialCreate(failedDraft.action) ||
        _state.isParsing) {
      return;
    }
    final operation = _beginOperation(requireConfirmedOwner: true);
    if (operation == null) {
      _showFailure(_actionPolicy.ownerUnavailableDraftFailure());
      return;
    }
    _emit(_state.copyWith(isParsing: true, failure: null));
    await _cancelDurableDraft(
      failedDraft.id,
      runtime: _durableDraftCoordinator.visibleRuntime,
    );
    if (!_isCurrent(operation)) return;
    _durableDraftCoordinator.clearVisibleDraftBinding();

    final permissionFailure = _actionPolicy.failureForAction(
      failedDraft.action,
    );
    if (permissionFailure != null) {
      _showFailure(permissionFailure, operation: operation);
      return;
    }
    final retryDraft = AiActionDraft.create(action: failedDraft.action);
    final validation = _draftValidator.validate(retryDraft.action);
    final durableOutcome = await _durableDraftCoordinator.prepare(
      draft: retryDraft,
      validation: validation,
      isDurableFinancialCreate: true,
      policyRevision: _actionPolicy.configurationRevision,
      isCurrent: () => _isCurrent(operation),
      readRuntime: _recovery.readRuntime,
      readPermissionFailure: (expectedRevision) =>
          _actionPolicy.failureForAction(
            retryDraft.action,
            expectedConfigurationRevision: expectedRevision,
          ),
    );
    if (!_isCurrent(operation)) return;
    switch (durableOutcome) {
      case AiAssistantDurableDraftReady():
        _emit(
          _state.copyWith(
            draft: retryDraft,
            validation: validation,
            failure: null,
            isParsing: false,
          ),
          effects: const <AiAssistantWorkflowEffect>[
            AiAssistantWorkflowRevealLatest(),
          ],
        );
      case AiAssistantDurableDraftPersistenceFailed(:final failure) ||
          AiAssistantDurableDraftPermissionRejected(:final failure):
        _showFailure(failure, operation: operation);
      case AiAssistantDurableDraftSuperseded():
        return;
    }
  }

  void editDraft() {
    final draft = _state.draft;
    final text = _textForAction(draft?.action);
    if (draft != null) {
      unawaited(
        _cancelDurableDraft(
          draft.id,
          runtime: _durableDraftCoordinator.visibleRuntime,
        ),
      );
    }
    _durableDraftCoordinator.clearVisibleDraftBinding();
    _emit(
      AiAssistantConversationWorkflowState(),
      effects: <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowReplaceComposer(text),
      ],
    );
  }

  void cancelDraft() {
    final draft = _state.draft;
    final isFinancialCreate =
        draft?.action is CreateExpenseDraft ||
        draft?.action is CreateIncomeDraft;
    if (draft != null) {
      unawaited(
        _cancelDurableDraft(
          draft.id,
          runtime: _durableDraftCoordinator.visibleRuntime,
        ),
      );
    }
    _durableDraftCoordinator.clearVisibleDraftBinding();
    _emit(
      AiAssistantConversationWorkflowState(),
      effects: <AiAssistantWorkflowEffect>[
        AiAssistantWorkflowShowNotice(
          isFinancialCreate
              ? AiAssistantWorkflowNotice.financialDraftRejected
              : AiAssistantWorkflowNotice.actionCancelled,
        ),
      ],
    );
  }

  Future<void> restoreDurableDraft({
    required String confirmedMessage,
    required String invalidMessage,
  }) async {
    if (_sendLifecycle.hasActiveOperation || _state.isParsing) return;
    final operation = _beginOperation(
      requireConfirmedOwner: true,
      supersedeExisting: false,
    );
    if (operation == null) return;
    await _durableDraftCoordinator.recover(
      enabled: _actionPolicy.appControlEnabled,
      isCurrent: () => _isCurrent(operation),
      isMounted: _isMounted,
      readStartupReconciliation: _recovery.readStartupReconciliation,
      readRuntime: _recovery.readRuntime,
      tryConsumeRecoveryResult: _recovery.tryConsume,
      publishRecoveryResult: (result) {
        _agentSession.recordLocalAssistantMessage(
          result.verified && result.status == AppAgentCommandStatus.succeeded
              ? confirmedMessage
              : invalidMessage,
        );
      },
      waitForRenderedFrame: _waitForRenderedFrame,
      allowsAction: _actionPolicy.allowsAction,
      validateAction: _draftValidator.validate,
      publishRestoredDraft: (restored, validation, failure) {
        _emit(
          _state.copyWith(
            draft: restored,
            validation: validation,
            failure: failure,
          ),
        );
      },
      readPolicyRevision: () => _actionPolicy.configurationRevision,
    );
  }

  void changeDraftCategory(Category category) {
    final draft = _state.draft;
    if (draft == null) return;
    final action = switch (draft.action) {
      CreateExpenseDraft(:final transactionDraft) => CreateExpenseDraft(
        transactionDraft.copyWith(
          category: category,
          categorySuggestion: CategorySuggestion(
            categoryId: category.id,
            categoryHint: category.name,
            confidence: 100,
            source: CategorySuggestionSource.explicitUserInput,
          ),
        ),
      ),
      CreateIncomeDraft(:final transactionDraft) => CreateIncomeDraft(
        transactionDraft.copyWith(
          category: category,
          categorySuggestion: CategorySuggestion(
            categoryId: category.id,
            categoryHint: category.name,
            confidence: 100,
            source: CategorySuggestionSource.explicitUserInput,
          ),
        ),
      ),
      _ => null,
    };
    if (action != null) unawaited(_applyEditedAction(draft, action));
  }

  void changeDraftAccount(Account account) {
    final draft = _state.draft;
    if (draft == null) return;
    final action = switch (draft.action) {
      CreateExpenseDraft(:final transactionDraft) => CreateExpenseDraft(
        transactionDraft.copyWith(account: account),
      ),
      CreateIncomeDraft(:final transactionDraft) => CreateIncomeDraft(
        transactionDraft.copyWith(
          account: account,
          incomeSourceSuggestion: transactionDraft.incomeSourceSuggestion
              ?.copyWith(
                destinationAccountId: account.id,
                destinationAccountHint: account.name,
              ),
        ),
      ),
      _ => null,
    };
    if (action != null) unawaited(_applyEditedAction(draft, action));
  }

  void changeDraftIncomeSourceType(IncomeSourceType sourceType) {
    final draft = _state.draft;
    if (draft?.action case CreateIncomeDraft(:final transactionDraft)) {
      final suggestion =
          transactionDraft.incomeSourceSuggestion ??
          IncomeSourceSuggestion(
            sourceType: sourceType,
            confidence: 100,
            source: IncomeSourceSuggestionSource.explicitUserInput,
            requiresClarification: false,
          );
      unawaited(
        _applyEditedAction(
          draft!,
          CreateIncomeDraft(
            transactionDraft.copyWith(
              incomeSourceSuggestion: suggestion.copyWith(
                sourceType: sourceType,
                confidence: 100,
                source: IncomeSourceSuggestionSource.explicitUserInput,
                requiresClarification: false,
              ),
            ),
          ),
        ),
      );
    }
  }

  void changeDraftIncomeSourceName(String sourceName) {
    final draft = _state.draft;
    if (draft?.action case CreateIncomeDraft(:final transactionDraft)) {
      final suggestion =
          transactionDraft.incomeSourceSuggestion ??
          IncomeSourceSuggestion(
            sourceType: IncomeSourceType.other,
            sourceNameHint: sourceName,
            confidence: 0,
            source: IncomeSourceSuggestionSource.fallback,
            requiresClarification: true,
          );
      unawaited(
        _applyEditedAction(
          draft!,
          CreateIncomeDraft(
            transactionDraft.copyWith(
              incomeSourceSuggestion: suggestion.copyWith(
                sourceNameHint: sourceName,
              ),
            ),
          ),
        ),
      );
    }
  }

  void changeDraftTransactionDate(DateTime transactionDate) {
    final draft = _state.draft;
    if (draft == null) return;
    final action = switch (draft.action) {
      CreateExpenseDraft(:final transactionDraft) => CreateExpenseDraft(
        transactionDraft.copyWith(transactionDate: transactionDate),
      ),
      CreateIncomeDraft(:final transactionDraft) => CreateIncomeDraft(
        transactionDraft.copyWith(transactionDate: transactionDate),
      ),
      _ => null,
    };
    if (action != null) unawaited(_applyEditedAction(draft, action));
  }

  void changeDraftTransactionStatus(TransactionStatus status) {
    final draft = _state.draft;
    if (draft == null) return;
    final action = switch (draft.action) {
      CreateExpenseDraft(:final transactionDraft) => CreateExpenseDraft(
        transactionDraft.copyWith(status: status),
      ),
      CreateIncomeDraft(:final transactionDraft) => CreateIncomeDraft(
        transactionDraft.copyWith(status: status),
      ),
      _ => null,
    };
    if (action != null) unawaited(_applyEditedAction(draft, action));
  }

  Future<void> _applyEditedAction(
    AiActionDraft previousDraft,
    AiAction action,
  ) async {
    final operation = _beginOperation(requireConfirmedOwner: true);
    if (operation == null) {
      _clearOwnerBoundState(cancelCapturedDraft: true);
      return;
    }
    final validation = _draftValidator.validate(action);
    final updatedDraft = AiActionDraft.create(action: action);
    final outcome = await _durableDraftCoordinator.revise(
      previousDraft: previousDraft,
      updatedDraft: updatedDraft,
      validation: validation,
      isDurableFinancialCreate: _isDurableFinancialCreate(action),
      isCurrent: () => _isCurrent(operation),
      readRuntime: _recovery.readRuntime,
      readPermissionFailure: (expectedRevision) =>
          _actionPolicy.failureForAction(
            action,
            expectedConfigurationRevision: expectedRevision,
          ),
    );
    switch (outcome) {
      case AiAssistantDurableDraftSuperseded():
        return;
      case AiAssistantDurableDraftPermissionRejected(:final failure):
      case AiAssistantDurableDraftPersistenceFailed(:final failure):
        _showFailure(failure, operation: operation);
        return;
      case AiAssistantDurableDraftReady():
        if (!_isCurrent(operation)) return;
        _emit(
          _state.copyWith(
            draft: updatedDraft,
            understanding: AiFinancialActionUnderstanding(draft: updatedDraft),
            validation: validation,
          ),
        );
    }
  }

  Future<void> _cancelDurableDraft(
    String commandId, {
    AiActionDurableRuntime? runtime,
  }) {
    return _durableDraftCoordinator.cancel(
      commandId,
      runtime: runtime,
      readFallbackRuntime: _recovery.readRuntime,
    );
  }

  bool _isDurableFinancialCreate(AiAction action) => switch (action) {
    CreateExpenseDraft() ||
    CreateIncomeDraft() ||
    CreateTransferDraft() ||
    CreateBudgetDraft() ||
    CreateGoalDraft() ||
    AddGoalContributionDraft() => true,
    UpdateTransactionDraft() ||
    DeleteTransactionDraft() ||
    UndoAiActionDraft() => true,
    _ => false,
  };

  String _textForAction(AiAction? action) {
    return switch (action) {
      CreateExpenseDraft(:final transactionDraft) ||
      CreateIncomeDraft(:final transactionDraft) => transactionDraft.note,
      CreateTransferDraft(:final note) => note ?? _state.submittedMessage ?? '',
      UpdateTransactionDraft() ||
      DeleteTransactionDraft() ||
      UndoAiActionDraft() => _state.submittedMessage ?? '',
      AskQuestionAction(:final question) => question,
      CurrencyConversionAnswerAction() ||
      BudgetProgressAnswerAction() ||
      GoalProgressAnswerAction() ||
      BlockedAiAction() ||
      null => _state.submittedMessage ?? '',
      CreateBudgetDraft(:final budget) => budget.name,
      CreateGoalDraft(:final goal) => goal.title,
      AddGoalContributionDraft(:final goal) => goal.title,
      ClarificationRequiredAction(:final message) => message,
      CreateCategoryDraft(:final name) => name,
    };
  }
}
