import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_route_paths.dart';
import '../../../../app/router/navigation_transition_diagnostics.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/owner_scope/presentation/legacy_data_claim_dialog.dart'
    show showLegacyDataClaimDialog;
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/accessibility/acceptance_semantics.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../../shared/presentation/widgets/finance_ui_components.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../budgets/application/providers/budgets_providers.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../../goals/application/providers/goals_providers.dart';
import '../../../insights/domain/entities/financial_insight.dart';
import '../../../insights/insights.dart' show FinancialInsightCard;
import '../../../income_sources/domain/enums/income_source_type.dart';
import '../../../payees/application/providers/payees_providers.dart';
import '../../../transactions/domain/enums/transaction_status.dart';
import '../../../receipts/application/receipt_providers.dart';
import '../../application/providers/ai_agent_providers.dart';
import '../../application/providers/ai_assistant_providers.dart';
import '../../application/services/ai_action_executor.dart';
import '../../application/services/ai_assistant_conversation_workflow_controller.dart';
import '../../domain/agent/ai_agent_models.dart';
import '../../domain/agent/ai_tool_contracts.dart';
import '../../domain/app_agent/app_agent_policy.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/entities/ai_action_draft.dart';
import '../../domain/entities/ai_capability.dart';
import '../../domain/entities/ai_understanding_result.dart';
import '../../domain/services/ai_intent_router.dart';
import '../widgets/ai_action_confirmation_card.dart';
import '../widgets/ai_verified_action_card.dart';
import '../widgets/google_search_entry_point.dart';
import '../support/ai_failure_localizer.dart';
import '../support/ai_assistant_workflow_composition.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showJumpToLatest = false;
  bool _acceptancePromptPrepared = false;
  bool _acceptanceSmallTalkSubmitted = false;
  late String _financialTimeZoneName;
  late final AiAssistantConversationWorkflowController _workflow;
  late final NavigationTransitionDiagnostics _navigationDiagnostics;
  ProviderSubscription<AiToolOwnerScopeBinding?>? _ownerBindingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationDiagnostics = ref.read(navigationTransitionDiagnosticsProvider);
    final initialOwnerBinding = ref.read(aiToolOwnerScopeBindingProvider);
    _workflow = composeAiAssistantConversationWorkflowController(
      ref: ref,
      initialOwnerBinding: initialOwnerBinding,
      isMounted: () => mounted,
      publish: _applyWorkflowEmission,
      waitForRenderedFrame: () => WidgetsBinding.instance.endOfFrame,
    );
    _financialTimeZoneName = ref
        .read(financialCommandParserProvider)
        .timeZoneName;
    _ownerBindingSubscription = ref.listenManual<AiToolOwnerScopeBinding?>(
      aiToolOwnerScopeBindingProvider,
      _handleOwnerBindingChanged,
    );
    _scrollController.addListener(_handleScrollPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreDurableDraft());
    });
  }

  @override
  void dispose() {
    final cancelActiveRequest = _workflow.detachCancellationForDispose();
    WidgetsBinding.instance.removeObserver(this);
    _ownerBindingSubscription?.close();
    _scrollController.removeListener(_handleScrollPosition);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
    if (cancelActiveRequest != null) {
      // Riverpod rejects synchronous provider mutations from dispose. A
      // microtask runs after the lifecycle callback while still cancelling
      // before a later provider/network event can deliver another chunk.
      unawaited(Future<void>.microtask(cancelActiveRequest));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _cancelForLifecycleTransition();
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _cancelForLifecycleTransition() {
    _workflow.cancelForLifecycleTransition();
  }

  void _handleOwnerBindingChanged(
    AiToolOwnerScopeBinding? previous,
    AiToolOwnerScopeBinding? next,
  ) {
    if (!_workflow.handleOwnerBindingChanged(previous, next)) return;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(aiToolOwnerScopeBindingProvider) == next) {
          unawaited(_restoreDurableDraft());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workflowState = _workflow.state;
    // Keep the financial context subscriptions stable for the lifetime of this
    // screen. Starting them conditionally from the loading build can cause a
    // synchronously emitted first value to dirty the widget during that build.
    ref
      ..watch(payeesProvider)
      ..watch(exchangeRatesProvider)
      ..watch(budgetProgressProvider)
      ..watch(allGoalsProvider)
      ..watch(allGoalProgressProvider);
    final agentIsSending = ref.watch(
      aiAgentControllerProvider.select((state) => state.isSending),
    );
    final hasAgentMessages = ref.watch(
      aiAgentControllerProvider.select((state) => state.messages.isNotEmpty),
    );
    final hasAgentError = ref.watch(
      aiAgentControllerProvider.select((state) => state.errorMessage != null),
    );
    final acceptanceStateIdentifier =
        cashPilotForceStopAcceptanceSemanticsEnabled
        ? ref.watch(
            aiAgentControllerProvider.select(_forceStopAcceptanceIdentifier),
          )
        : '';
    return Scaffold(
      appBar: CPAppBar(
        title: l10n.appTitle,
        subtitle: l10n.aiAssistantSubtitle,
        actions: <Widget>[
          IconButton(
            key: const Key('ai_assistant_new_conversation'),
            tooltip: l10n.aiNewConversation,
            onPressed: _startNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            key: const Key('ai_assistant_clear_conversation'),
            tooltip: l10n.aiClearConversation,
            onPressed:
                (workflowState.submittedMessage == null && !hasAgentMessages) ||
                    workflowState.isParsing ||
                    agentIsSending
                ? null
                : _confirmClearConversation,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: FinanceScreenBody(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: cashPilotForceStopAcceptanceSemantics(
                      identifier: acceptanceStateIdentifier,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsetsDirectional.only(
                          top: CPSpacing.sm,
                          bottom: CPSpacing.xxl,
                        ),
                        children: [
                          if (workflowState.submittedMessage == null &&
                              !hasAgentMessages &&
                              workflowState.draft == null &&
                              workflowState.understanding == null &&
                              workflowState.failure == null &&
                              !workflowState.isParsing)
                            _AiChatWelcome(onSuggestedPrompt: _fillPrompt),
                          if (hasAgentMessages ||
                              agentIsSending ||
                              hasAgentError)
                            Consumer(
                              builder: (context, ref, _) {
                                return _AiAgentConversation(
                                  state: ref.watch(aiAgentControllerProvider),
                                  onSuggestedPrompt: _fillPrompt,
                                  onRetry: () =>
                                      unawaited(_retryAgentResponse()),
                                  diagnosticsEnabled: ref
                                      .watch(aiRuntimeConfigProvider)
                                      .diagnosticsEnabled,
                                );
                              },
                            ),
                          if (hasAgentMessages)
                            const SizedBox(height: CPSpacing.xl),
                          if (workflowState.submittedMessage != null ||
                              workflowState.verifiedAction != null)
                            Column(
                              key: const Key('ai_assistant_conversation_state'),
                              children: [
                                if (workflowState.isParsing)
                                  _AiThinkingBubble(
                                    key: const Key('ai_assistant_loading'),
                                    label: l10n.aiThinking,
                                  )
                                else if (workflowState.failure
                                    case final failure?)
                                  failure.code ==
                                              AppAgentFailureCodes
                                                  .legacyDataUnresolved &&
                                          workflowState.pendingLegacyAction !=
                                              null
                                      ? _AiLegacyDataResolutionCard(
                                          key: const Key(
                                            'ai_legacy_data_resolution_card',
                                          ),
                                          readyToResume: workflowState
                                              .legacyDataReadyToResume,
                                          onPressed:
                                              workflowState
                                                  .legacyDataReadyToResume
                                              ? () => unawaited(
                                                  _resumePendingLegacyFinancialAction(),
                                                )
                                              : () => unawaited(
                                                  _linkLegacyDataForPendingAction(),
                                                ),
                                        )
                                      : _isFinancialControlSettingsFailure(
                                          failure,
                                        )
                                      ? _AiFinancialActionsDisabledCard(
                                          key: const Key(
                                            'ai_assistant_failure',
                                          ),
                                          onOpenSettings: () => context.push(
                                            AppRoutePaths.settings,
                                          ),
                                        )
                                      : _AiFailureBubble(
                                          key: const Key(
                                            'ai_assistant_failure',
                                          ),
                                          message: _localizedFailure(
                                            failure,
                                            l10n,
                                          ),
                                        )
                                else if (workflowState.understanding
                                    case final AiConversationalUnderstanding
                                        response)
                                  _AiAssistantResponseBubble(
                                    key: const Key(
                                      'ai_assistant_conversation_response',
                                    ),
                                    title: l10n.aiAssistantResponseTitle,
                                    message: _localizedConversationResponse(
                                      response.responseKey,
                                      l10n,
                                    ),
                                  )
                                else if (workflowState.understanding
                                    case final AiUnsupportedUnderstanding
                                        response)
                                  _AiAssistantResponseBubble(
                                    key: const Key(
                                      'ai_assistant_unsupported_response',
                                    ),
                                    title: l10n.aiAssistantResponseTitle,
                                    message: _localizedConversationResponse(
                                      response.responseKey,
                                      l10n,
                                    ),
                                  )
                                else if (workflowState.understanding
                                    case final AiFinancialQuestionUnderstanding
                                        response
                                    when response.draft.action
                                        is AskQuestionAction)
                                  _AiAssistantResponseBubble(
                                    key: const Key(
                                      'ai_assistant_financial_answer',
                                    ),
                                    title: l10n.aiActionQuestionTitle,
                                    message:
                                        l10n.aiFinancialQuestionLocalResponse,
                                  )
                                else if (workflowState.understanding
                                    case AiClarificationUnderstanding(
                                      draft: AiActionDraft(
                                        action: ClarificationRequiredAction(
                                          :final message,
                                        ),
                                      ),
                                    ))
                                  _AiAssistantResponseBubble(
                                    key: const Key(
                                      'ai_assistant_clarification_response',
                                    ),
                                    title: l10n.aiClarificationTitle,
                                    message: message,
                                  )
                                else if (workflowState.verifiedAction
                                    case final verifiedAction?)
                                  AiVerifiedActionCard(
                                    key: const Key(
                                      'ai_assistant_verified_action',
                                    ),
                                    verifiedAction: verifiedAction,
                                    onUndo: _requestUndo,
                                    timeZoneName: _financialTimeZoneName,
                                  )
                                else if (workflowState.draft != null &&
                                    workflowState.validation != null)
                                  AiActionConfirmationCard(
                                    key: const Key('ai_assistant_result'),
                                    draft: workflowState.draft!,
                                    validation: workflowState.validation!,
                                    // The callback performs the authoritative
                                    // current-policy check. Keeping it present
                                    // lets an explicit Confirm surface the
                                    // exact safe denial instead of silently
                                    // disabling an otherwise complete preview.
                                    onConfirm: _confirmAction,
                                    onEdit: _editAction,
                                    onCancel: _cancelAction,
                                    categories:
                                        workflowState.availableCategories,
                                    accounts: workflowState.availableAccounts,
                                    onCategoryChanged: _changeDraftCategory,
                                    onAccountChanged: _changeDraftAccount,
                                    onIncomeSourceTypeChanged:
                                        _changeDraftIncomeSourceType,
                                    onIncomeSourceNameChanged:
                                        _changeDraftIncomeSourceName,
                                    onTransactionDateChanged:
                                        _changeDraftTransactionDate,
                                    onTransactionStatusChanged:
                                        _changeDraftTransactionStatus,
                                    timeZoneName: _financialTimeZoneName,
                                  ),
                                const SizedBox(height: CPSpacing.xl),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_showJumpToLatest)
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: CPSpacing.sm,
                      child: Center(
                        child: ActionChip(
                          key: const Key('ai_assistant_jump_to_latest'),
                          avatar: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                          label: Text(l10n.aiJumpToLatest),
                          onPressed: () => _revealLatestResponse(force: true),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: CPSpacing.sm),
            SafeArea(
              top: false,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsetsDirectional.all(CPSpacing.xs),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    if (ref.watch(receiptFeatureConfigProvider).enabled)
                      IconButton(
                        key: const Key('ai_assistant_scan_receipt_button'),
                        tooltip: l10n.scanReceipt,
                        onPressed: () =>
                            context.push(AppRoutePaths.receiptCapture),
                        icon: const Icon(Icons.attach_file_rounded),
                      ),
                    Expanded(
                      child: cashPilotForceStopAcceptanceSemantics(
                        identifier: 'cashpilot_acceptance_ai_small_talk',
                        onLongPress:
                            !_acceptanceSmallTalkSubmitted &&
                                !agentIsSending &&
                                !workflowState.isParsing &&
                                _messageController.text.isEmpty
                            ? _submitSmallTalkAcceptancePrompt
                            : null,
                        child: CPTextField(
                          key: const Key('ai_assistant_composer'),
                          semanticsIdentifier:
                              cashPilotForceStopAcceptanceIdentifier(
                                'cashpilot_acceptance_ai_composer',
                              ),
                          controller: _messageController,
                          hintText: l10n.askAiHint,
                          textInputAction: TextInputAction.send,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) => _submitMessage(),
                        ),
                      ),
                    ),
                    _MicrophoneButton(onPressed: _showPendingMessage),
                    const SizedBox(width: CPSpacing.xs),
                    cashPilotForceStopAcceptanceSemantics(
                      identifier: 'cashpilot_acceptance_ai_send',
                      onLongPress:
                          !agentIsSending &&
                              !workflowState.isParsing &&
                              !_acceptancePromptPrepared &&
                              _messageController.text.isEmpty
                          ? _prepareForceStopAcceptancePrompt
                          : null,
                      child: IconButton.filled(
                        key: const Key('ai_assistant_send_button'),
                        tooltip: agentIsSending
                            ? l10n.aiStopGenerating
                            : l10n.send,
                        onPressed: agentIsSending
                            ? () => ref
                                  .read(aiAgentControllerProvider.notifier)
                                  .cancel()
                            : _messageController.text.trim().isEmpty ||
                                  workflowState.isParsing
                            ? null
                            : _submitMessage,
                        icon: agentIsSending
                            ? const Icon(Icons.stop_rounded)
                            : workflowState.isParsing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyWorkflowEmission(AiAssistantWorkflowEmission emission) {
    for (final effect in emission.effects) {
      if (effect case AiAssistantWorkflowSendBoundaryEffect(:final boundary)) {
        switch (boundary) {
          case AiAssistantWorkflowSendBoundary.begin:
            _navigationDiagnostics.beginAiSend();
          case AiAssistantWorkflowSendBoundary.end:
            _navigationDiagnostics.endAiSend();
        }
      }
    }
    if (!mounted) return;
    setState(() {
      for (final effect in emission.effects) {
        switch (effect) {
          case AiAssistantWorkflowClearComposer():
            _messageController.clear();
          case AiAssistantWorkflowReplaceComposer(:final text):
            _messageController.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
          case _:
            break;
        }
      }
    });
    for (final effect in emission.effects) {
      switch (effect) {
        case AiAssistantWorkflowClearComposer() ||
            AiAssistantWorkflowReplaceComposer() ||
            AiAssistantWorkflowSendBoundaryEffect():
          break;
        case AiAssistantWorkflowUnfocus():
          FocusScope.of(context).unfocus();
        case AiAssistantWorkflowRevealLatest(:final force):
          _revealLatestResponse(force: force);
        case AiAssistantWorkflowShowFailureSnack(:final failure):
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_localizedFailure(failure, l10n)),
              action: failure.code == AiActionFailureCodes.executionFailed
                  ? SnackBarAction(
                      label: l10n.retry,
                      onPressed: () => unawaited(_workflow.retryFailedDraft()),
                    )
                  : null,
            ),
          );
        case AiAssistantWorkflowShowNotice(:final notice):
          final l10n = AppLocalizations.of(context);
          final message = switch (notice) {
            AiAssistantWorkflowNotice.actionConfirmed =>
              l10n.aiActionConfirmedMessage,
            AiAssistantWorkflowNotice.actionCancelled =>
              l10n.aiActionCancelledMessage,
            AiAssistantWorkflowNotice.financialDraftRejected =>
              l10n.aiFinancialPreviewRejected,
          };
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        case AiAssistantWorkflowNavigate(:final path, :final safeReason):
          _navigationDiagnostics.markNextTransition(
            cause: NavigationTransitionCause.explicitAssistantNavigationTool,
            safeReason: safeReason,
            expectedPath: path,
          );
          context.push(path);
      }
    }
  }

  void _showPendingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).aiAssistantPendingSnack),
      ),
    );
  }

  void _fillPrompt(String prompt) {
    setState(() {
      _messageController.text = prompt;
      _messageController.selection = TextSelection.collapsed(
        offset: prompt.length,
      );
    });
  }

  void _prepareForceStopAcceptancePrompt() {
    final workflowState = _workflow.state;
    if (!cashPilotForceStopAcceptanceSemanticsEnabled ||
        _acceptancePromptPrepared ||
        workflowState.isParsing ||
        ref.read(aiAgentControllerProvider).isSending ||
        _messageController.text.isNotEmpty) {
      return;
    }
    setState(() {
      _acceptancePromptPrepared = true;
      _messageController.value = TextEditingValue(
        text: cashPilotForceStopAcceptanceArabicPrompt,
        selection: TextSelection.collapsed(
          offset: cashPilotForceStopAcceptanceArabicPrompt.length,
        ),
      );
    });
  }

  void _submitSmallTalkAcceptancePrompt() {
    final agentState = ref.read(aiAgentControllerProvider);
    final workflowState = _workflow.state;
    if (!cashPilotForceStopAcceptanceSemanticsEnabled ||
        _acceptanceSmallTalkSubmitted ||
        workflowState.isParsing ||
        agentState.isSending ||
        agentState.messages.isNotEmpty ||
        workflowState.submittedMessage != null ||
        workflowState.draft != null ||
        workflowState.understanding != null ||
        workflowState.failure != null ||
        _messageController.text.isNotEmpty) {
      return;
    }
    setState(() {
      _acceptanceSmallTalkSubmitted = true;
      _messageController.value = const TextEditingValue(
        text: cashPilotAppCheckAcceptanceSmallTalkPrompt,
        selection: TextSelection.collapsed(
          offset: cashPilotAppCheckAcceptanceSmallTalkPrompt.length,
        ),
      );
    });
    unawaited(_submitMessage());
  }

  AiAssistantWorkflowCopy _workflowCopy() {
    final l10n = AppLocalizations.of(context);
    return AiAssistantWorkflowCopy(
      recordIncomeOffer: l10n.aiRecordIncomeOffer,
      recordTransactionOffer: l10n.aiRecordTransactionOffer,
      recordIncomeOfferCancelled: l10n.aiRecordIncomeOfferCancelled,
      accountClarificationMessage: l10n.aiAmbiguousAccountMessage,
      expenseAccountClarificationMessage: l10n.aiExpenseAccountClarification,
      ambiguousPayeeMessage: l10n.ambiguousPayee,
      exchangeRateClarificationMessage: l10n.addRateToContinue,
      categoryClarificationMessage: l10n.selectCategory,
      goalClarificationMessage: l10n.selectGoal,
      unknownIntentClarificationMessage: l10n.aiUnsupportedPromptMessage,
      actionConfirmationMessage: l10n.aiActionConfirmationMessage,
      incomeMissingDetails: l10n.aiIncomeMissingDetails,
      actionInvalidMessage: l10n.aiActionInvalidMessage,
      explicitConfirmationText:
          Localizations.localeOf(context).languageCode == 'ar'
          ? '\u0646\u0639\u0645'
          : 'yes',
    );
  }

  Future<void> _submitMessage() {
    return _workflow.submit(
      AiAssistantSubmitCommand(
        message: _messageController.text.trim(),
        locale: Localizations.localeOf(context).toLanguageTag(),
        copy: _workflowCopy(),
      ),
    );
  }

  void _requestUndo() {
    _messageController.text =
        Localizations.localeOf(context).languageCode == 'ar' ? 'تراجع' : 'undo';
    unawaited(_submitMessage());
  }

  Future<void> _startNewConversation() => _workflow.startNewConversation();

  Future<void> _retryAgentResponse() => _workflow.retryAgentResponse();

  Future<void> _confirmClearConversation() {
    final l10n = AppLocalizations.of(context);
    return _workflow.confirmAndClear(
      showDialog: () => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.aiClearConversation),
          content: Text(l10n.aiClearConversationConfirmation),
          actions: <Widget>[
            TextButton(
              key: const Key('ai_clear_conversation_cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('ai_clear_conversation_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.aiClearConversation),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _linkLegacyDataForPendingAction() {
    return _workflow.linkLegacyData(
      showClaimDialog: () => showLegacyDataClaimDialog(context),
    );
  }

  Future<void> _resumePendingLegacyFinancialAction() {
    return _workflow.resumeLegacyAction(
      locale: Localizations.localeOf(context).toLanguageTag(),
      copy: _workflowCopy(),
    );
  }

  Future<void> _restoreDurableDraft() {
    final l10n = AppLocalizations.of(context);
    return _workflow.restoreDurableDraft(
      confirmedMessage: l10n.aiActionConfirmedMessage,
      invalidMessage: l10n.aiActionInvalidMessage,
    );
  }

  Future<void> _confirmAction() => _workflow.confirmDraft();

  void _editAction() => _workflow.editDraft();

  void _cancelAction() => _workflow.cancelDraft();

  void _changeDraftCategory(Category category) =>
      _workflow.changeDraftCategory(category);

  void _changeDraftAccount(Account account) =>
      _workflow.changeDraftAccount(account);

  void _changeDraftIncomeSourceType(IncomeSourceType sourceType) =>
      _workflow.changeDraftIncomeSourceType(sourceType);

  void _changeDraftIncomeSourceName(String sourceName) =>
      _workflow.changeDraftIncomeSourceName(sourceName);

  void _changeDraftTransactionDate(DateTime transactionDate) =>
      _workflow.changeDraftTransactionDate(transactionDate);

  void _changeDraftTransactionStatus(TransactionStatus status) =>
      _workflow.changeDraftTransactionStatus(status);

  void _revealLatestResponse({bool force = false}) {
    if (!force && _showJumpToLatest) return;
    void scrollAfterLayout(int remainingPasses) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final target = _scrollController.position.maxScrollExtent;
        if (remainingPasses == 1) {
          _scrollController.animateTo(
            target,
            duration: CPDurations.normal,
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(target);
        }
        if (remainingPasses > 1) {
          scrollAfterLayout(remainingPasses - 1);
        }
      });
    }

    scrollAfterLayout(3);
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final show = position.maxScrollExtent - position.pixels > 180;
    if (show != _showJumpToLatest && mounted) {
      setState(() => _showJumpToLatest = show);
    }
  }

  String _localizedFailure(Failure failure, AppLocalizations l10n) {
    final appControlMessage = switch (failure.code) {
      AppAgentFailureCodes.appControlOff => l10n.aiControlOffFailure,
      AppAgentFailureCodes.transactionDraftsDisabled =>
        l10n.aiTransactionDraftsDisabledFailure,
      AppAgentFailureCodes.confirmedExecutionDisabled =>
        l10n.aiConfirmedExecutionDisabledFailure,
      AppAgentFailureCodes.ownerScopeNotReady =>
        l10n.aiOwnerScopeNotReadyFailure,
      AppAgentFailureCodes.legacyDataUnresolved =>
        l10n.aiLegacyDataUnresolvedFailure,
      AppAgentFailureCodes.legacyPolicyUnresolved =>
        l10n.aiLegacyPolicyUnresolvedFailure,
      AppAgentFailureCodes.staleAppControlConfiguration =>
        l10n.aiStaleControlFailure,
      AppAgentFailureCodes.permissionDenied =>
        l10n.aiGenericDraftPermissionFailure,
      AppAgentFailureCodes.stalePreview => l10n.aiStalePreviewFailure,
      AppAgentFailureCodes.duplicateExecutionPrevented =>
        l10n.aiDuplicateExecutionFailure,
      AppAgentFailureCodes.verificationFailed =>
        l10n.aiFinancialVerificationFailure,
      AppAgentFailureCodes.validationFailed ||
      AiActionFailureCodes.invalid => l10n.aiInvalidFinancialDraftFailure,
      AiActionFailureCodes.executionFailed => l10n.aiFinancialWriteFailure,
      _ => null,
    };
    if (appControlMessage != null) {
      return appControlMessage;
    }
    return localizedAiFailure(l10n, failure);
  }

  bool _isFinancialControlSettingsFailure(Failure failure) =>
      failure.code == AppAgentFailureCodes.appControlOff ||
      failure.code == AppAgentFailureCodes.transactionDraftsDisabled;

  String _localizedConversationResponse(
    AiConversationResponseKey responseKey,
    AppLocalizations l10n,
  ) {
    return switch (responseKey) {
      AiConversationResponseKey.greeting => l10n.aiGreetingResponse,
      AiConversationResponseKey.smallTalk => l10n.aiSmallTalkResponse,
      AiConversationResponseKey.help => l10n.aiHelpResponse,
      AiConversationResponseKey.capabilities => l10n.aiCapabilitiesResponse,
      AiConversationResponseKey.unsupported =>
        l10n.aiUnsupportedConversationResponse,
      AiConversationResponseKey.destructiveBlocked =>
        l10n.aiDestructiveRequestBlockedResponse,
    };
  }
}

class _AiChatWelcome extends StatelessWidget {
  const _AiChatWelcome({required this.onSuggestedPrompt});

  final ValueChanged<String> onSuggestedPrompt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: CPSpacing.md,
        vertical: CPSpacing.xl,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
            decoration: BoxDecoration(
              color: context.cpColors.aiContainer,
              shape: BoxShape.circle,
            ),
            child: const CPBrandMark(ai: true),
          ),
          const SizedBox(height: CPSpacing.md),
          Text(
            l10n.emptyConversationTitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CPSpacing.xs),
          Text(
            l10n.emptyConversationMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: CPSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: CPSpacing.sm,
            runSpacing: CPSpacing.sm,
            children: [
              SmartSuggestionChip(
                label: l10n.promptWhatIsInflation,
                onPressed: () => onSuggestedPrompt(l10n.promptWhatIsInflation),
              ),
              SmartSuggestionChip(
                label: l10n.promptCurrentLibyaEconomy,
                onPressed: () =>
                    onSuggestedPrompt(l10n.promptCurrentLibyaEconomy),
              ),
              SmartSuggestionChip(
                label: l10n.promptAnalyzeSpending,
                onPressed: () => onSuggestedPrompt(l10n.promptAnalyzeSpending),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiAgentConversation extends StatelessWidget {
  const _AiAgentConversation({
    required this.state,
    required this.onSuggestedPrompt,
    required this.onRetry,
    required this.diagnosticsEnabled,
  });

  final AiAgentConversationState state;
  final ValueChanged<String> onSuggestedPrompt;
  final VoidCallback onRetry;
  final bool diagnosticsEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final response = state.lastResponse;
    final latestUserIndex = state.messages.lastIndexWhere(
      (message) => message.role == AiAgentMessageRole.user,
    );
    final hasEvidence =
        response != null &&
        (response.evidence.isNotEmpty ||
            response.sources.isNotEmpty ||
            response.searchEntryPointRenderedContent != null ||
            response.responseDate != null ||
            response.isPartial);
    final conversation = Column(
      key: const Key('ai_agent_conversation'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < state.messages.length; index++) ...[
          if (state.messages[index].role == AiAgentMessageRole.user)
            _UserMessageBubble(
              key: index == latestUserIndex
                  ? const Key('ai_assistant_user_message')
                  : ValueKey<String>('ai_assistant_user_message_$index'),
              message: state.messages[index].content,
            )
          else
            _AiAssistantResponseBubble(
              key: ValueKey<String>('ai_assistant_message_$index'),
              message: state.messages[index].content,
            ),
          if (index != state.messages.length - 1)
            const SizedBox(height: CPSpacing.md),
        ],
        if (state.isSending) ...[
          if (state.messages.isNotEmpty) const SizedBox(height: CPSpacing.md),
          _AiThinkingBubble(
            key: const Key('ai_agent_loading'),
            label: _activityLabel(l10n),
          ),
        ],
        if (state.errorMessage case final error?) ...[
          const SizedBox(height: CPSpacing.md),
          _AiAssistantResponseBubble(message: error),
        ],
        if (state.retryable && !state.isSending) ...[
          const SizedBox(height: CPSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: cashPilotForceStopAcceptanceSemantics(
              identifier: 'cashpilot_acceptance_ai_retry',
              child: OutlinedButton.icon(
                key: const Key('ai_agent_retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.aiRetryResponse),
              ),
            ),
          ),
        ],
        if (diagnosticsEnabled &&
            response?.kind == AiAgentResponseKind.failure &&
            response!.warnings.isNotEmpty) ...[
          const SizedBox(height: CPSpacing.xs),
          Text(
            '${l10n.aiDiagnosticCodeLabel}: ${response.warnings.join(', ')}',
            key: const Key('ai_safe_failure_code'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (response != null && !state.isSending && hasEvidence) ...[
          const SizedBox(height: CPSpacing.md),
          _AiAgentEvidencePanel(response: response),
        ],
        if (response != null && !state.isSending) ...[
          if (response.followUpPrompts.isNotEmpty) ...[
            const SizedBox(height: CPSpacing.sm),
            Wrap(
              spacing: CPSpacing.sm,
              runSpacing: CPSpacing.sm,
              children: response.followUpPrompts
                  .map(
                    (prompt) => SmartSuggestionChip(
                      label: prompt,
                      onPressed: () => onSuggestedPrompt(prompt),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ],
    );
    return conversation;
  }

  String _activityLabel(AppLocalizations l10n) {
    final latest = state.messages
        .where((message) => message.role == AiAgentMessageRole.user)
        .lastOrNull;
    if (latest == null) {
      return l10n.aiThinking;
    }
    final target = const AiIntentRouter().route(latest.content).target;
    return switch (target) {
      AssistantRouteTarget.groundedCurrentKnowledge =>
        l10n.aiSearchingCurrentInformation,
      AssistantRouteTarget.personalFinancialAnalysis =>
        latest.content.contains('قارن') ||
                latest.content.toLowerCase().contains('compare')
            ? l10n.aiComparingPeriods
            : l10n.aiReviewingYourData,
      AssistantRouteTarget.financialAction => l10n.aiPreparingDraft,
      _ => l10n.aiThinking,
    };
  }
}

String _forceStopAcceptanceIdentifier(AiAgentConversationState state) {
  final messageCount = state.messages.length;
  if (state.isSending) {
    return 'cashpilot_ai_acceptance_sending_$messageCount';
  }
  final response = state.lastResponse;
  if (state.errorMessage != null ||
      (response != null && response.kind != AiAgentResponseKind.answer)) {
    final failureKind = switch (state.unavailableReason) {
      AiUnavailableReason.appCheckUnavailable => 'appcheck_unavailable',
      AiUnavailableReason.appCheckTimedOut => 'appcheck_timed_out',
      AiUnavailableReason.appCheckRejected => 'appcheck_rejected',
      AiUnavailableReason.authenticationNotReady => 'authentication_not_ready',
      AiUnavailableReason.authenticationRequired => 'authentication_required',
      AiUnavailableReason.offline => 'offline',
      AiUnavailableReason.gatewayUnreachable => 'gateway_unreachable',
      AiUnavailableReason.providerTimedOut => 'provider_timed_out',
      AiUnavailableReason.rateLimited => 'rate_limited',
      _ => 'generic',
    };
    return 'cashpilot_ai_acceptance_failure_${failureKind}_$messageCount';
  }
  if (response?.kind == AiAgentResponseKind.answer) {
    return 'cashpilot_ai_acceptance_answer_complete_$messageCount';
  }
  return 'cashpilot_ai_acceptance_idle_$messageCount';
}

class _AiAgentEvidencePanel extends StatelessWidget {
  const _AiAgentEvidencePanel({required this.response});

  final AiAgentResponse response;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final grounded = response.sources.isNotEmpty;
    return Container(
      key: const Key('ai_agent_evidence_panel'),
      padding: const EdgeInsetsDirectional.all(CPSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(CPRadius.sm),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                grounded
                    ? Icons.travel_explore_rounded
                    : response.isPartial
                    ? Icons.info_outline_rounded
                    : Icons.verified_user_outlined,
                size: 18,
                color: response.isPartial
                    ? colorScheme.tertiary
                    : colorScheme.primary,
              ),
              const SizedBox(width: CPSpacing.sm),
              Expanded(
                child: Text(
                  grounded
                      ? l10n.aiSources
                      : response.isPartial
                      ? l10n.aiUnableVerifyCurrent
                      : response.evidence.any(
                          (evidence) =>
                              evidence.toolName == 'get_monthly_comparison',
                        )
                      ? l10n.aiEvidenceComparedPrior
                      : l10n.aiEvidenceCurrentMonth,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          if (response.responseDate case final date?) ...[
            const SizedBox(height: CPSpacing.xs),
            Text(
              '${l10n.aiUpdatedAsOf} ${DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).format(date.toLocal())}',
              key: const Key('ai_grounded_response_date'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (response.evidence.isNotEmpty) ...[
            const SizedBox(height: CPSpacing.sm),
            Wrap(
              spacing: CPSpacing.xs,
              runSpacing: CPSpacing.xs,
              children: [
                for (final evidence in response.evidence)
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: CPSpacing.sm,
                      vertical: CPSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(CPRadius.full),
                    ),
                    child: Text(
                      evidence.summary,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
          ],
          if (response.sources.isNotEmpty) ...[
            const SizedBox(height: CPSpacing.sm),
            for (final source in response.sources)
              InkWell(
                key: Key('ai_grounded_source_${source.uri}'),
                borderRadius: BorderRadius.circular(CPRadius.xs),
                onTap: () async {
                  await launchUrl(
                    source.uri,
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: CPSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.open_in_new_rounded, size: 16),
                      const SizedBox(width: CPSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              source.domain,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (response.searchEntryPointRenderedContent
              case final renderedContent?) ...[
            const SizedBox(height: CPSpacing.sm),
            GoogleSearchEntryPoint(
              key: const Key('ai_google_search_entry_point'),
              renderedContent: renderedContent,
              unavailableLabel: l10n.aiSearchEntryUnavailable,
            ),
          ],
          if (grounded) ...[
            const SizedBox(height: CPSpacing.sm),
            Text(
              l10n.aiCurrentInfoMayChange,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (response.actionDraft != null) ...[
            const SizedBox(height: CPSpacing.sm),
            Text(
              l10n.aiActionConfirmationMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Retained for compatibility with downstream branded layouts.
// ignore: unused_element
class _AiInsightCards extends StatelessWidget {
  const _AiInsightCards({required this.state, required this.categories});

  final AsyncValue<AppResult<List<FinancialInsight>>> state;
  final Map<String, Category> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CPSectionTitle(
          title: l10n.financialInsights,
          subtitle: l10n.financialInsightsSubtitle,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: CPSpacing.md),
        state.when(
          loading: () => const CPSkeletonCard(height: 180),
          error: (_, _) => _empty(l10n),
          data: (result) => switch (result) {
            AppSuccess<List<FinancialInsight>>(data: final values)
                when values.isNotEmpty =>
              LayoutBuilder(
                builder: (context, constraints) {
                  final shown = values.take(2).toList(growable: false);
                  final cards = [
                    for (final insight in shown)
                      FinancialInsightCard(
                        insight: insight,
                        categories: categories,
                        compact: true,
                      ),
                  ];
                  if (constraints.maxWidth <= 760 || cards.length == 1) {
                    return Column(
                      children: [
                        for (var index = 0; index < cards.length; index++) ...[
                          cards[index],
                          if (index < cards.length - 1)
                            const SizedBox(height: CPSpacing.md),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards.first),
                      const SizedBox(width: CPSpacing.md),
                      Expanded(child: cards.last),
                    ],
                  );
                },
              ),
            AppSuccess<List<FinancialInsight>>() => _empty(l10n),
            AppFailure<List<FinancialInsight>>() => _empty(l10n),
          },
        ),
      ],
    );
  }

  Widget _empty(AppLocalizations l10n) => FinanceInfoCard(
    title: l10n.noInsightsTitle,
    message: l10n.noInsightsMessage,
    icon: Icons.auto_graph_rounded,
  );
}

// Retained for compatibility with downstream branded layouts.
// ignore: unused_element
class _AiAssistantHero extends StatelessWidget {
  const _AiAssistantHero({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CPCard(
      variant: CPCardVariant.elevated,
      backgroundColor: CPColors.aiPanel,
      accentColor: context.cpColors.ai,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(CPSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final mark = Container(
                  width: compact ? 64 : 86,
                  height: compact ? 64 : 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(CPRadius.sm),
                    boxShadow: [
                      BoxShadow(
                        color: context.cpColors.ai.withValues(alpha: 0.20),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(CPSpacing.sm),
                    child: const CPBrandMark(ai: true),
                  ),
                );
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AIAccentBadge(
                      label: AppLocalizations.of(context).aiReadyBadge,
                    ),
                    const SizedBox(height: CPSpacing.lg),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: CPSpacing.sm),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      mark,
                      const SizedBox(height: CPSpacing.lg),
                      copy,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: CPSpacing.xl),
                    mark,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final proportionalWidth = constraints.maxWidth * 0.82;
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: proportionalWidth > 680 ? 680 : proportionalWidth,
            ),
            child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: CPSpacing.md,
                vertical: CPSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(CPRadius.lg),
                  topEnd: Radius.circular(CPRadius.lg),
                  bottomStart: Radius.circular(CPRadius.lg),
                  bottomEnd: Radius.circular(CPRadius.xs),
                ),
              ),
              child: Directionality(
                textDirection: _messageDirection(message),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AiAssistantResponseBubble extends StatelessWidget {
  const _AiAssistantResponseBubble({
    super.key,
    this.title,
    required this.message,
  });

  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 16,
      height: 1.5,
    );
    return Semantics(
      liveRegion: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final proportionalWidth = constraints.maxWidth * 0.92;
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: proportionalWidth > 760 ? 760 : proportionalWidth,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    padding: const EdgeInsetsDirectional.all(6),
                    decoration: BoxDecoration(
                      color: context.cpColors.aiContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const CPBrandMark(ai: true),
                  ),
                  const SizedBox(width: CPSpacing.sm),
                  Expanded(
                    child: Directionality(
                      textDirection: _messageDirection(message),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            key: const Key('ai_assistant_markdown_message'),
                            data: message,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: textStyle,
                              h1: textStyle?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                              h2: textStyle?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                              h3: textStyle?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              listBullet: textStyle,
                              code: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 15,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                  ),
                            ),
                            onTapLink: (_, href, _) async {
                              final uri = Uri.tryParse(href ?? '');
                              if (uri != null &&
                                  <String>{
                                    'https',
                                    'http',
                                  }.contains(uri.scheme)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 17,
                              tooltip: l10n.aiCopyResponse,
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: message),
                              ),
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

TextDirection _messageDirection(String message) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(message)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

class _AiThinkingBubble extends StatelessWidget {
  const _AiThinkingBubble({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: CPSpacing.md,
          vertical: CPSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.cpColors.aiContainer.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(CPRadius.sm),
          border: Border.all(
            color: context.cpColors.ai.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.cpColors.ai,
              ),
            ),
            const SizedBox(width: CPSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.cpColors.onAiContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiFailureBubble extends StatelessWidget {
  const _AiFailureBubble({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: CPSpacing.lg,
              vertical: CPSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(CPRadius.sm),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiFinancialActionsDisabledCard extends StatelessWidget {
  const _AiFinancialActionsDisabledCard({
    super.key,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.cpColors;
    return Semantics(
      liveRegion: true,
      container: true,
      label:
          '${l10n.aiFinancialActionsDisabledTitle} '
          '${l10n.aiFinancialActionsDisabledBody}',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: CPCard(
            key: const Key('ai_financial_actions_disabled_card'),
            accentColor: colors.ai,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lock_outline_rounded, color: colors.ai),
                    const SizedBox(width: CPSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.aiFinancialActionsDisabledTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CPSpacing.sm),
                Text(
                  l10n.aiFinancialActionsDisabledBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: CPSpacing.md),
                CPButton(
                  key: const Key('ai_open_ai_settings'),
                  label: l10n.aiOpenAiSettings,
                  icon: Icons.settings_outlined,
                  variant: CPButtonVariant.tonal,
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiLegacyDataResolutionCard extends StatelessWidget {
  const _AiLegacyDataResolutionCard({
    super.key,
    required this.readyToResume,
    required this.onPressed,
  });

  final bool readyToResume;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = context.cpColors;
    final title = readyToResume
        ? (isArabic ? 'تم ربط البيانات المحلية' : 'Local data is linked')
        : (isArabic
              ? 'تحتاج البيانات المحلية إلى تأكيدك'
              : 'Local data needs your confirmation');
    final message = readyToResume
        ? (isArabic
              ? 'يمكنك الآن متابعة إنشاء المسودة. لن يُنفذ أي إجراء مالي حتى تراجع المعاينة وتضغط على تأكيد.'
              : 'You can now continue creating the draft. No financial action will run until you review the preview and press Confirm.')
        : (isArabic
              ? 'وجد CashPilot بيانات محلية من إصدار أقدم. اربطها فقط بعد التأكد أنها تخص هذا الحساب. لن تُرسل البيانات إلى الذكاء الاصطناعي ولن يُنفذ أي إجراء مالي تلقائياً.'
              : 'CashPilot found local data from an older app version. Link it only after confirming that it belongs to this account. No data is sent to AI, and no financial action will run automatically.');
    final actionLabel = readyToResume
        ? (isArabic ? 'متابعة المسودة' : 'Continue draft')
        : (isArabic ? 'ربط البيانات المحلية' : 'Link local data');

    return Semantics(
      liveRegion: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: const EdgeInsetsDirectional.all(CPSpacing.lg),
            decoration: BoxDecoration(
              color: colors.infoContainer,
              borderRadius: BorderRadius.circular(CPRadius.sm),
              border: Border.all(color: colors.info.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.link_rounded, color: colors.onInfoContainer),
                    const SizedBox(width: CPSpacing.sm),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onInfoContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CPSpacing.sm),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onInfoContainer,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: CPSpacing.md),
                CPButton(
                  key: Key(
                    readyToResume
                        ? 'ai_legacy_data_resume_action'
                        : 'ai_legacy_data_link_action',
                  ),
                  label: actionLabel,
                  icon: readyToResume
                      ? Icons.description_outlined
                      : Icons.verified_user_outlined,
                  variant: CPButtonVariant.tonal,
                  onPressed: onPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MicrophoneButton extends StatelessWidget {
  const _MicrophoneButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: CPDurations.slow,
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: IconButton.filledTonal(
        tooltip: AppLocalizations.of(context).voiceInput,
        onPressed: onPressed,
        icon: const Icon(Icons.mic_none_rounded),
      ),
    );
  }
}
