import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/core/firebase/app_check_token_probe.dart';
import 'package:cashpilot_ai/core/owner_scope/application/legacy_data_claim_service.dart';
import 'package:cashpilot_ai/core/owner_scope/application/owner_scope_providers.dart';
import 'package:cashpilot_ai/core/owner_scope/domain/owner_scope.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/app_agent_reconciliation_service.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_assistant_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_durable_action_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/durable_ai_action_bridge.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_agent_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/app_agent/effective_ai_app_control_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/providers/ai_app_control_providers.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_connection_diagnostic.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_action_executor.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_agent_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_app_control_feature_flags.dart';
import 'package:cashpilot_ai/features/ai_assistant/data/config/ai_runtime_config.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/ai_app_control_settings.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/app_agent/app_agent_policy.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_agent_models.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/agent/ai_tool_contracts.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_validation_result.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/failures/ai_failure_codes.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_context_builder.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_draft_factory.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/create_ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/pages/ai_assistant_screen.dart';
import 'package:cashpilot_ai/features/ai_assistant/presentation/widgets/ai_action_confirmation_card.dart';
import 'package:cashpilot_ai/features/budgets/application/providers/budgets_providers.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget_progress.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/providers/exchange_rates_providers.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/entities/stored_exchange_rate.dart';
import 'package:cashpilot_ai/features/goals/application/providers/goals_providers.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal_progress.dart';
import 'package:cashpilot_ai/features/insights/application/providers/insights_providers.dart';
import 'package:cashpilot_ai/features/insights/domain/entities/financial_insight.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/payees/application/providers/payees_providers.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/base_currency_provider.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/accessibility/acceptance_semantics.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerBindingA = AiToolOwnerScopeBinding(
  accountScope:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  epoch: 1,
);
const _ownerBindingB = AiToolOwnerScopeBinding(
  accountScope:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  epoch: 2,
);
final _testOwnerBindingProvider = StateProvider<AiToolOwnerScopeBinding?>(
  (_) => _ownerBindingA,
);
final _testOwnerScopeHealthProvider = StateProvider<OwnerScopeHealth>(
  (_) => const OwnerScopeHealth(status: OwnerScopeStatus.safe),
);
final _testLegacyInventoryProvider = StateProvider<LegacyDataInventory>(
  (_) => LegacyDataInventory(const <String, int>{}),
);

void main() {
  testWidgets(
    'non-release prompt hook is empty by default and never replaces a draft',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _unknownJson),
      );
      await _pumpAssistant(tester, repository, withoutOwner: true);

      expect(cashPilotForceStopAcceptanceSemanticsEnabled, isTrue);
      final composer = find.byKey(const Key('ai_assistant_composer'));
      final send = find.byKey(const Key('ai_assistant_send_button'));
      CPTextField composerWidget() => tester.widget<CPTextField>(composer);

      expect(composerWidget().controller!.text, isEmpty);
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('cashpilot_acceptance_ai_send'),
            )
            .getSemanticsData()
            .hasAction(SemanticsAction.longPress),
        isTrue,
      );
      await tester.tap(send);
      await tester.pump();
      expect(composerWidget().controller!.text, isEmpty);
      expect(repository.sendMessageCalls, 0);

      await tester.enterText(composer, 'preserve this draft');
      await tester.pump();
      await _holdAcceptanceSend(tester, send);
      await tester.pump();
      expect(composerWidget().controller!.text, 'preserve this draft');

      await tester.enterText(composer, '');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      await _holdAcceptanceSend(tester, send);
      await tester.pump();

      expect(
        composerWidget().controller!.text,
        cashPilotForceStopAcceptanceArabicPrompt,
      );
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      expect(repository.sendMessageCalls, 0);

      await tester.enterText(composer, 'second draft');
      await tester.pump();
      await _holdAcceptanceSend(tester, send);
      await tester.pump();
      expect(composerWidget().controller!.text, 'second draft');
      expect(repository.sendMessageCalls, 0);
      semantics.dispose();
    },
  );

  testWidgets(
    'composer keeps focus and accepts a second character after first-character rebuild',
    (tester) async {
      final repository = _RecordingAiRepository(
        (_) => throw StateError('Typing must not submit a provider request.'),
      );
      await _pumpAssistant(tester, repository, withoutOwner: true);

      final composer = find.byKey(const Key('ai_assistant_composer'));
      Finder editable() =>
          find.descendant(of: composer, matching: find.byType(EditableText));
      EditableText editableWidget() => tester.widget<EditableText>(editable());

      await tester.tap(composer);
      await tester.pump();
      expect(editableWidget().focusNode.hasFocus, isTrue);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'a',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();

      expect(tester.widget<CPTextField>(composer).controller!.text, 'a');
      expect(editableWidget().focusNode.hasFocus, isTrue);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ab',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();

      expect(tester.widget<CPTextField>(composer).controller!.text, 'ab');
      expect(editableWidget().focusNode.hasFocus, isTrue);
      expect(repository.sendMessageCalls, 0);
    },
  );

  testWidgets(
    'send icon submits Arabic once and shows user, loading, and draft states',
    (tester) async {
      final gate = Completer<AppResult<AiResponse>>();
      final repository = _RecordingAiRepository((_) => gate.future);
      await _pumpAssistant(tester, repository, locale: const Locale('ar'));

      await tester.enterText(
        find.byKey(const Key('ai_assistant_composer')),
        'سجل مصروف 5 دينار للحليب نقدا',
      );
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('ai_assistant_send_button')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('ai_assistant_user_message'), skipOffstage: false)
            .evaluate()
            .isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('ai_assistant_user_message')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai_assistant_loading')), findsOneWidget);
      await _pumpUntil(tester, () => repository.sendMessageCalls == 1);
      expect(repository.sendMessageCalls, 1);

      gate.complete(repository.success(_expenseJson));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_assistant_loading')), findsNothing);
      expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);
      expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
    },
  );

  testWidgets('keyboard greeting uses the local conversation path', (
    tester,
  ) async {
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _unknownJson),
    );
    await _pumpAssistant(tester, repository, withoutOwner: true);

    await tester.enterText(
      find.byKey(const Key('ai_assistant_composer')),
      'hello',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _pumpUntil(
      tester,
      () => find
          .byKey(const ValueKey<String>('ai_assistant_message_1'))
          .evaluate()
          .isNotEmpty,
    );

    final context = tester.element(find.byType(AiAssistantScreen));
    final expected = AppLocalizations.of(context).aiLocalGreeting;
    final assistantBubble = find.byKey(
      const ValueKey<String>('ai_assistant_message_1'),
    );
    final renderedReply = find.descendant(
      of: assistantBubble,
      matching: find.byType(MarkdownBody),
    );
    expect(repository.sendMessageCalls, 0);
    expect(find.byKey(const Key('ai_assistant_user_message')), findsOneWidget);
    expect(assistantBubble, findsOneWidget);
    expect(renderedReply, findsOneWidget);
    expect(tester.widget<MarkdownBody>(renderedReply).data, expected);
    expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
    expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
  });

  testWidgets('Arabic greeting renders a localized conversational reply', (
    tester,
  ) async {
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _unknownJson),
    );
    await _pumpAssistant(
      tester,
      repository,
      locale: const Locale('ar'),
      withoutOwner: true,
    );

    await _sendWithIcon(tester, 'مرحبا');

    final context = tester.element(find.byType(AiAssistantScreen));
    final expected = AppLocalizations.of(context).aiLocalGreeting;
    final assistantBubble = find.byKey(
      const ValueKey<String>('ai_assistant_message_1'),
    );
    final renderedReply = find.descendant(
      of: assistantBubble,
      matching: find.byType(MarkdownBody),
    );
    expect(assistantBubble, findsOneWidget);
    expect(renderedReply, findsOneWidget);
    expect(tester.widget<MarkdownBody>(renderedReply).data, expected);
    expect(repository.sendMessageCalls, 0);
    expect(find.byKey(const Key('ai_agent_loading')), findsNothing);
  });

  testWidgets('invalid structured output falls back to a visible draft', (
    tester,
  ) async {
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, '{"intent":}'),
    );
    await _pumpAssistant(tester, repository);

    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    expect(repository.sendMessageCalls, 1);
    expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);
    expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
  });

  testWidgets('typed provider failure renders a persistent localized error', (
    tester,
  ) async {
    final repository = _RecordingAiRepository(
      (_) async => const AppResult.failure(
        Failure(
          message: 'Provider details must not be shown.',
          code: AiFailureCodes.networkFailure,
        ),
      ),
    );
    await _pumpAssistant(tester, repository);

    await _sendWithIcon(tester, 'How much did I spend this month?');

    final context = tester.element(find.byType(AiAssistantScreen));
    final expected = AppLocalizations.of(context).aiNetworkFailureMessage;
    expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
    expect(find.text(expected), findsOneWidget);
    expect(find.text('Provider details must not be shown.'), findsNothing);
    expect(find.byKey(const Key('ai_assistant_loading')), findsNothing);
  });

  testWidgets(
    'optional budget and goal context failures remain empty-context fallbacks',
    (tester) async {
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _expenseJson),
      );
      await _pumpAssistant(
        tester,
        repository,
        budgetProgressLoader: (_) async => const AppResult.failure(
          Failure(message: 'Budget context is unavailable.'),
        ),
        goalsLoader: (_) => Stream.value(
          const AppResult.failure(
            Failure(message: 'Goal context is unavailable.'),
          ),
        ),
        goalProgressLoader: (_) async => const AppResult.failure(
          Failure(message: 'Goal progress is unavailable.'),
        ),
      );

      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );

      expect(repository.sendMessageCalls, 1);
      expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);
      expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
    },
  );

  testWidgets(
    'required context failures keep accounts-first mapping and block provider',
    (tester) async {
      var categoryReads = 0;
      final repository = _RecordingAiRepository(
        (_) => throw StateError('Required context failure must block egress.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        accountsLoader: (_) async => const AppResult.failure(
          Failure(
            message: 'Account details must not be shown.',
            code: AiFailureCodes.networkFailure,
          ),
        ),
        categoriesLoader: (_) async {
          categoryReads += 1;
          return const AppResult.failure(
            Failure(
              message: 'Category details must not be shown.',
              code: AiFailureCodes.providerUnavailable,
            ),
          );
        },
      );

      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );

      final context = tester.element(find.byType(AiAssistantScreen));
      expect(categoryReads, 1);
      expect(repository.sendMessageCalls, 0);
      expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
      expect(
        find.text(AppLocalizations.of(context).aiNetworkFailureMessage),
        findsOneWidget,
      );
      expect(find.text('Account details must not be shown.'), findsNothing);
      expect(find.text('Category details must not be shown.'), findsNothing);
    },
  );

  testWidgets('connection diagnostic does not lock the normal composer', (
    tester,
  ) async {
    final repository = _RecordingAiRepository((request) async {
      final content = request.metadata['diagnostic'] == true
          ? '{"intent":"unknown","requiresConfirmation":false}'
          : _expenseJson;
      return _successFor(request, content);
    });
    final diagnostic = AiConnectionDiagnostic(
      runtimeConfig: const AiRuntimeConfig(
        providerMode: AiProviderMode.firebaseGemini,
        diagnosticsEnabled: true,
      ),
      modelConfig: const AiModelConfig(
        modelName: 'fake-gemini',
        temperature: 0.1,
        maxOutputTokens: 512,
        structuredOutputEnabled: true,
        streamingEnabled: false,
        requestTimeout: Duration(seconds: 20),
      ),
      repository: repository,
      localParser: const FinancialCommandParser(),
      appCheckTokenProbe: const _ReadyTokenProbe(),
    );

    await diagnostic();
    expect(repository.sendMessageCalls, 1);

    await _pumpAssistant(tester, repository);
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    expect(repository.sendMessageCalls, 2);
    expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);
  });

  testWidgets(
    'in-flight duplicate is blocked and a later different request succeeds',
    (tester) async {
      final first = Completer<AppResult<AiResponse>>();
      late _RecordingAiRepository repository;
      repository = _RecordingAiRepository((request) {
        if (repository.sendMessageCalls == 1) {
          return first.future;
        }
        return Future.value(_successFor(request, _expenseJson));
      });
      await _pumpAssistant(tester, repository);

      await tester.enterText(
        find.byKey(const Key('ai_assistant_composer')),
        'How much did I spend this month?',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('ai_assistant_send_button')),
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await _pumpUntil(tester, () => repository.sendMessageCalls == 1);
      expect(repository.sendMessageCalls, 1);

      await tester.enterText(
        find.byKey(const Key('ai_assistant_composer')),
        'record I paid 6 LYD with cash for bread as an expense',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(repository.sendMessageCalls, 1);

      first.complete(
        const AppResult.failure(
          Failure(
            message: 'Request timed out safely.',
            code: AiFailureCodes.networkFailure,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai_assistant_loading')), findsNothing);
      expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 550)),
      );
      await _sendWithIcon(
        tester,
        'record I paid 7 LYD with cash for eggs as an expense',
      );

      expect(repository.sendMessageCalls, 2);
      expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);
      expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
    },
  );

  testWidgets(
    'denied draft category fails in-page without reaching a provider',
    (tester) async {
      final repository = _RecordingAiRepository(
        (_) => throw StateError('A blocked draft must not reach a provider.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        appControlPolicy: _transactionDraftPolicy,
      );

      await _sendWithIcon(
        tester,
        'Set budget 500 LYD for groceries this month',
      );

      expect(repository.sendMessageCalls, 0);
      expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      expect(find.text(l10n.aiGenericDraftPermissionFailure), findsOneWidget);
    },
  );

  for (final scenario in <({String name, String input, Locale locale})>[
    (
      name: 'English',
      input: 'my friend sent me 1000 LYD',
      locale: const Locale('en'),
    ),
    (name: 'Arabic', input: 'وصلني ألف دينار', locale: const Locale('ar')),
    (name: 'Libyan', input: 'صاحبي عطاني 300', locale: const Locale('ar')),
  ]) {
    testWidgets(
      '${scenario.name} declarative income checks policy before loading context',
      (tester) async {
        var accountReads = 0;
        var categoryReads = 0;
        final repository = _RecordingAiRepository(
          (_) => throw StateError(
            'A denied declarative draft must not reach a provider.',
          ),
        );
        await _pumpAssistant(
          tester,
          repository,
          locale: scenario.locale,
          appControlPolicy: _blockedAppControlPolicy,
          withoutOwner: true,
          accountsLoader: (_) async {
            accountReads += 1;
            return const AppResult<List<Account>>.success(<Account>[]);
          },
          categoriesLoader: (_) async {
            categoryReads += 1;
            return const AppResult<List<Category>>.success(<Category>[]);
          },
        );
        await _sendWithIcon(tester, scenario.input);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(AiAssistantScreen)),
        );
        expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
        expect(find.text(l10n.aiOwnerScopeNotReadyFailure), findsOneWidget);
        expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
        expect(repository.sendMessageCalls, 0);
        expect(accountReads, 0);
        expect(categoryReads, 0);
      },
    );
  }

  for (final scenario
      in <({String name, String input, Locale locale, String actionLabel})>[
        (
          name: 'English',
          input: 'my friend sent me 1000 LYD',
          locale: const Locale('en'),
          actionLabel: 'Link local data',
        ),
        (
          name: 'Arabic',
          input: 'وصلني ألف دينار',
          locale: const Locale('ar'),
          actionLabel: 'ربط البيانات المحلية',
        ),
        (
          name: 'Libyan',
          input: 'صاحبي عطاني 300',
          locale: const Locale('ar'),
          actionLabel: 'ربط البيانات المحلية',
        ),
      ]) {
    testWidgets(
      '${scenario.name} legacy-data denial is a normal actionable assistant card',
      (tester) async {
        var accountReads = 0;
        final repository = _RecordingAiRepository(
          (_) => throw StateError(
            'An unresolved owner scope must not reach a provider.',
          ),
        );
        await _pumpAssistant(
          tester,
          repository,
          locale: scenario.locale,
          ownerScopeHealth: const OwnerScopeHealth(
            status: OwnerScopeStatus.legacyDataUnclaimed,
            failure: OwnerScopeFailure.legacyDataRequiresClaim,
          ),
          accountsLoader: (_) async {
            accountReads += 1;
            return const AppResult<List<Account>>.success(<Account>[]);
          },
        );
        final baselineAccountReads = accountReads;

        await _submitAndWaitFor(
          tester,
          scenario.input,
          () => find
              .byKey(const Key('ai_legacy_data_resolution_card'))
              .evaluate()
              .isNotEmpty,
        );

        expect(
          find.byKey(const Key('ai_legacy_data_resolution_card')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
        expect(find.text(scenario.actionLabel), findsOneWidget);
        expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
        expect(repository.sendMessageCalls, 0);
        expect(accountReads, baselineAccountReads);
      },
    );
  }

  testWidgets(
    'declining a record offer clears it without policy, context, or provider work',
    (tester) async {
      var accountReads = 0;
      var categoryReads = 0;
      final repository = _RecordingAiRepository(
        (_) => throw StateError(
          'Declining a declarative offer must not reach a provider.',
        ),
      );
      await _pumpAssistant(
        tester,
        repository,
        withoutOwner: true,
        appControlPolicy: _blockedAppControlPolicy,
        accountsLoader: (_) async {
          accountReads += 1;
          return const AppResult<List<Account>>.success(<Account>[]);
        },
        categoriesLoader: (_) async {
          categoryReads += 1;
          return const AppResult<List<Category>>.success(<Category>[]);
        },
      );

      await _sendWithIcon(tester, '1000 LYD');
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      bool cancelledReplyIsVisible() => find
          .byWidgetPredicate(
            (widget) =>
                widget is MarkdownBody &&
                widget.data == l10n.aiRecordIncomeOfferCancelled,
          )
          .evaluate()
          .isNotEmpty;

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 550)),
      );
      await _submitAndWaitFor(tester, 'no', cancelledReplyIsVisible);

      expect(cancelledReplyIsVisible(), isTrue);
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
      expect(repository.sendMessageCalls, 0);
      expect(accountReads, 0);
      expect(categoryReads, 0);
    },
  );

  testWidgets(
    'protected legacy claim preserves intent and requires a separate draft-resume action',
    (tester) async {
      final durableRuntime = _PolicyRaceDurableRuntime(
        onConfirm: () => throw StateError('Resume must not execute a draft.'),
      );
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _incomeJson),
      );
      await _pumpAssistant(
        tester,
        repository,
        durableRuntime: durableRuntime,
        ownerScopeHealth: const OwnerScopeHealth(
          status: OwnerScopeStatus.legacyDataUnclaimed,
          failure: OwnerScopeFailure.legacyDataRequiresClaim,
        ),
        legacyInventory: LegacyDataInventory(const <String, int>{
          'transactions': 1,
        }),
        successfulLegacyClaim: true,
      );

      await _submitAndWaitFor(
        tester,
        'my friend sent me 1000 LYD',
        () => find
            .byKey(const Key('ai_legacy_data_resolution_card'))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.byKey(const Key('ai_legacy_data_resolution_card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('ai_legacy_data_link_action')));
      await tester.pumpAndSettle();
      final confirmClaim = find.byKey(
        const Key('confirm_claim_legacy_local_data'),
      );
      expect(confirmClaim, findsOneWidget);
      expect(tester.widget<FilledButton>(confirmClaim).onPressed, isNull);

      await tester.tap(find.byKey(const Key('cancel_legacy_local_data_claim')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai_legacy_data_link_action')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(durableRuntime.confirmCalls, 0);

      await tester.tap(find.byKey(const Key('ai_legacy_data_link_action')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('confirm_legacy_local_data_owner')),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmClaim).onPressed, isNotNull);
      await tester.tap(confirmClaim);
      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('ai_legacy_data_resume_action'))
            .evaluate()
            .isNotEmpty,
      );

      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(durableRuntime.confirmCalls, 0);

      await tester.tap(find.byKey(const Key('ai_legacy_data_resume_action')));
      await _pumpUntil(
        tester,
        () =>
            find.byKey(const Key('ai_assistant_result')).evaluate().isNotEmpty,
      );

      final card = tester.widget<AiActionConfirmationCard>(
        find.byKey(const Key('ai_assistant_result')),
      );
      expect(card.draft.action, isA<CreateIncomeDraft>());
      final action = card.draft.action as CreateIncomeDraft;
      expect(action.transactionDraft.amount.amount, Decimal.fromInt(1000));
      expect(durableRuntime.confirmCalls, 0);
      expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
    },
  );

  testWidgets('from-draft legacy recovery resumes without reparsing', (
    tester,
  ) async {
    final durableRuntime = _RecordingDurableWorkflowRuntime();
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(
      tester,
      repository,
      durableRuntime: durableRuntime,
      legacyInventory: LegacyDataInventory(const <String, int>{
        'transactions': 1,
      }),
      successfulLegacyClaim: true,
    );
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    final originalCard = _currentActionCard(tester);
    final originalDraft = originalCard.draft;
    final originalAction = originalDraft.action as CreateExpenseDraft;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    _setOwnerHealth(
      container,
      const OwnerScopeHealth(
        status: OwnerScopeStatus.legacyDataUnclaimed,
        failure: OwnerScopeFailure.legacyDataRequiresClaim,
      ),
    );
    container.read(_testLegacyInventoryProvider.notifier).state =
        LegacyDataInventory(const <String, int>{'transactions': 1});
    await container.read(ownerScopeHealthProvider.future);
    await tester.pumpAndSettle();

    _currentActionCard(tester).onConfirm!();
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('ai_legacy_data_resolution_card'))
          .evaluate()
          .isNotEmpty,
    );
    expect(durableRuntime.cancelledCommandIds, <String>[originalDraft.id]);

    await _claimLegacyDataAndWaitForResume(tester);
    await tester.tap(find.byKey(const Key('ai_legacy_data_resume_action')));
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('ai_assistant_result')).evaluate().isNotEmpty,
    );

    final resumedAction =
        _currentActionCard(tester).draft.action as CreateExpenseDraft;
    expect(
      resumedAction.transactionDraft.amount,
      originalAction.transactionDraft.amount,
    );
    expect(
      resumedAction.transactionDraft.note,
      originalAction.transactionDraft.note,
    );
    expect(
      resumedAction.transactionDraft.account.id,
      originalAction.transactionDraft.account.id,
    );
    expect(
      resumedAction.transactionDraft.category?.id,
      originalAction.transactionDraft.category?.id,
    );
    expect(repository.sendMessageCalls, 1);
    expect(durableRuntime.persistedDrafts, hasLength(2));
    expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
  });

  testWidgets('clear conversation discards a pending legacy action', (
    tester,
  ) async {
    final repository = _RecordingAiRepository(
      (_) =>
          throw StateError('Clearing legacy state must not reach a provider.'),
    );
    await _pumpAssistant(
      tester,
      repository,
      agentOrchestrator: const _NoOpAiAgentOrchestrator(),
      ownerScopeHealth: const OwnerScopeHealth(
        status: OwnerScopeStatus.legacyDataUnclaimed,
        failure: OwnerScopeFailure.legacyDataRequiresClaim,
      ),
    );
    await _submitAndWaitFor(
      tester,
      'my friend sent me 1000 LYD',
      () => find
          .byKey(const Key('ai_legacy_data_resolution_card'))
          .evaluate()
          .isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('ai_assistant_clear_conversation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_clear_conversation_confirm')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ai_legacy_data_resolution_card')),
      findsNothing,
    );
    expect(find.byKey(const Key('ai_legacy_data_link_action')), findsNothing);
    expect(find.byKey(const Key('ai_legacy_data_resume_action')), findsNothing);
    expect(repository.sendMessageCalls, 0);
  });

  testWidgets(
    'owner switch during a protected claim cannot publish a resume action',
    (tester) async {
      final claimStarted = Completer<void>();
      final claimGate = Completer<bool>();
      final repository = _RecordingAiRepository(
        (_) => throw StateError('A stale legacy claim must not reparse.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        ownerScopeHealth: const OwnerScopeHealth(
          status: OwnerScopeStatus.legacyDataUnclaimed,
          failure: OwnerScopeFailure.legacyDataRequiresClaim,
        ),
        legacyInventory: LegacyDataInventory(const <String, int>{
          'transactions': 1,
        }),
        legacyClaimControllerBuilder: () =>
            _GatedLegacyDataClaimController(claimStarted, claimGate),
      );
      await _submitAndWaitFor(
        tester,
        'my friend sent me 1000 LYD',
        () => find
            .byKey(const Key('ai_legacy_data_resolution_card'))
            .evaluate()
            .isNotEmpty,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiAssistantScreen)),
      );

      await tester.tap(find.byKey(const Key('ai_legacy_data_link_action')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('confirm_legacy_local_data_owner')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('confirm_claim_legacy_local_data')),
      );
      await _pumpUntil(tester, () => claimStarted.isCompleted);

      container.read(_testOwnerBindingProvider.notifier).state = _ownerBindingB;
      _setOwnerHealth(
        container,
        const OwnerScopeHealth(status: OwnerScopeStatus.safe),
      );
      await tester.pump();
      claimGate.complete(true);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ai_legacy_data_resolution_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('ai_legacy_data_resume_action')),
        findsNothing,
      );
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(repository.sendMessageCalls, 0);
    },
  );

  testWidgets(
    'explicit income request under disabled policy shows the permission message',
    (tester) async {
      var accountReads = 0;
      final repository = _RecordingAiRepository(
        (_) =>
            throw StateError('A prohibited request must not reach a provider.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        appControlPolicy: _blockedAppControlPolicy,
        accountsLoader: (_) async {
          accountReads += 1;
          return const AppResult<List<Account>>.success(<Account>[]);
        },
      );

      await _sendWithIcon(tester, 'record 1000 LYD as income');

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
      expect(
        find.byKey(const Key('ai_financial_actions_disabled_card')),
        findsOneWidget,
      );
      expect(find.text(l10n.aiFinancialActionsDisabledTitle), findsOneWidget);
      expect(find.text(l10n.aiFinancialActionsDisabledBody), findsOneWidget);
      expect(find.text(l10n.aiOpenAiSettings), findsOneWidget);
      expect(find.text(l10n.aiControlOffFailure), findsNothing);
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(repository.sendMessageCalls, 0);
      expect(accountReads, 0);
    },
  );

  testWidgets(
    'Read Only blocks quick entry before context and shows AI Settings card',
    (tester) async {
      var accountReads = 0;
      final repository = _RecordingAiRepository(
        (_) => throw StateError('Read Only must block before provider egress.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        appControlPolicy: _readOnlyAppControlPolicy,
        accountsLoader: (_) async {
          accountReads += 1;
          return const AppResult<List<Account>>.success(<Account>[]);
        },
      );

      await _sendWithIcon(tester, 'milk 5 dinar');

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      expect(
        find.byKey(const Key('ai_financial_actions_disabled_card')),
        findsOneWidget,
      );
      expect(find.text(l10n.aiOpenAiSettings), findsOneWidget);
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(repository.sendMessageCalls, 0);
      expect(accountReads, 0);
    },
  );

  testWidgets(
    'milk quick entry renders one compact preview with no redundant question',
    (tester) async {
      final durableRuntime = _RecordingDurableWorkflowRuntime();
      final repository = _RecordingAiRepository(
        (_) => throw StateError('Deterministic quick entry must stay local.'),
      );
      await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);

      await _sendWithIcon(tester, 'milk 5 dinar');

      final context = tester.element(find.byType(AiAssistantScreen));
      final l10n = AppLocalizations.of(context);
      final cardFinder = find.byKey(const Key('ai_assistant_result'));
      final card = tester.widget<AiActionConfirmationCard>(cardFinder);
      final action = card.draft.action as CreateExpenseDraft;
      expect(action.transactionDraft.amount.amount, Decimal.fromInt(5));
      expect(action.transactionDraft.amount.amount.toStringAsFixed(3), '5.000');
      expect(action.transactionDraft.itemDescription, 'Milk');
      expect(action.transactionDraft.category?.name, 'Groceries');
      expect(action.transactionDraft.account.name, 'Cash');
      expect(action.transactionDraft.transactionDate, isNotNull);
      expect(repository.sendMessageCalls, 0);
      expect(durableRuntime.persistedDrafts, hasLength(1));
      expect(
        find.descendant(of: cardFinder, matching: find.byType(CPButton)),
        findsNWidgets(2),
      );
      expect(find.text(l10n.aiFinancialPreviewReject), findsOneWidget);
      expect(find.text(l10n.aiFinancialPreviewConfirm), findsOneWidget);
      expect(find.text(l10n.aiRecordTransactionOffer), findsNothing);
      expect(find.text(l10n.aiActionConfirmationMessage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MarkdownBody &&
              (widget.data == l10n.aiRecordTransactionOffer ||
                  widget.data == l10n.aiActionConfirmationMessage),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'explicit financial action without an owner shows owner-scope denial',
    (tester) async {
      var accountReads = 0;
      final repository = _RecordingAiRepository(
        (_) => throw StateError('A missing owner must not reach a provider.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        withoutOwner: true,
        accountsLoader: (_) async {
          accountReads += 1;
          return const AppResult<List<Account>>.success(<Account>[]);
        },
      );

      await _sendWithIcon(tester, 'record 150 LYD as income');

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
      expect(find.text(l10n.aiOwnerScopeNotReadyFailure), findsOneWidget);
      expect(repository.sendMessageCalls, 0);
      expect(accountReads, 0);
    },
  );

  testWidgets(
    'clear declarative income without an owner shows owner-scope denial',
    (tester) async {
      var accountReads = 0;
      final repository = _RecordingAiRepository(
        (_) => throw StateError('A missing owner must not reach a provider.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        withoutOwner: true,
        accountsLoader: (_) async {
          accountReads += 1;
          return const AppResult<List<Account>>.success(<Account>[]);
        },
      );
      await _submitAndWaitFor(
        tester,
        'my friend gave me 150 LYD',
        () =>
            find.byKey(const Key('ai_assistant_failure')).evaluate().isNotEmpty,
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
      expect(find.text(l10n.aiOwnerScopeNotReadyFailure), findsOneWidget);
      expect(repository.sendMessageCalls, 0);
      expect(accountReads, 0);
    },
  );

  testWidgets(
    'clear declarative income creates an incomplete typed draft directly',
    (tester) async {
      var accountReads = 0;
      var categoryReads = 0;
      final repository = _RecordingAiRepository(
        (_) => throw StateError(
          'A locally parsed confirmed offer must not reach a provider.',
        ),
      );
      await _pumpAssistant(
        tester,
        repository,
        accountsLoader: (ref) async {
          accountReads += 1;
          return AppResult<List<Account>>.success(<Account>[
            Account.create(
              id: 'available-cash',
              name: 'Available Cash',
              type: AccountType.cash,
              currencyCode: 'LYD',
              balance: Decimal.zero,
              icon: 'cash',
              color: 0xFF4F46E5,
            ),
          ]);
        },
        categoriesLoader: (_) async {
          categoryReads += 1;
          return AppResult<List<Category>>.success(buildDefaultCategories());
        },
      );
      await _submitAndWaitFor(
        tester,
        'my friend sent me 1000 LYD',
        () =>
            find.byKey(const Key('ai_assistant_result')).evaluate().isNotEmpty,
      );

      final card = tester.widget<AiActionConfirmationCard>(
        find.byKey(const Key('ai_assistant_result')),
      );
      expect(card.draft.action, isA<CreateIncomeDraft>());
      expect(
        card.validation.status,
        AiActionValidationStatus.needsClarification,
      );
      final action = card.draft.action as CreateIncomeDraft;
      final transaction = action.transactionDraft;
      expect(transaction.amount.amount, Decimal.fromInt(1000));
      expect(transaction.amount.currencyCode, 'LYD');
      expect(transaction.account.id, AiTransactionDraft.unresolvedAccountId);
      expect(transaction.category, isNull);
      expect(transaction.incomeSourceSuggestion?.requiresClarification, isTrue);
      expect(transaction.transactionDate, isNull);

      expect(
        find.byKey(const Key('ai_destination_account_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ai_income_source_type_selector')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai_category_selector')), findsOneWidget);
      expect(
        find.byKey(const Key('ai_transaction_date_selector')),
        findsOneWidget,
      );
      final context = tester.element(find.byType(AiAssistantScreen));
      final l10n = AppLocalizations.of(context);
      final confirm = tester.widget<CPButton>(
        find.widgetWithText(CPButton, l10n.confirm),
      );
      expect(confirm.onPressed, isNull);
      expect(repository.sendMessageCalls, 0);
      expect(accountReads, 1);
      expect(categoryReads, 1);
    },
  );

  for (final scenario in <({String name, String input, Locale locale})>[
    (
      name: 'English',
      input: 'my friend gave me 150 LYD because today is my birthday',
      locale: const Locale('en'),
    ),
    (
      name: 'Arabic',
      input: 'وصلني 150 دينار اليوم هدية عيد ميلادي',
      locale: const Locale('ar'),
    ),
    (
      name: 'Libyan',
      input: 'صاحبي عطاني 150 دينار هدية عيد ميلادي',
      locale: const Locale('ar'),
    ),
  ]) {
    testWidgets(
      '${scenario.name} direct proposal reads the current enabled policy',
      (tester) async {
        final repository = _RecordingAiRepository(
          (_) => throw StateError(
            'A locally parsed direct proposal must not reach a provider.',
          ),
        );
        await _pumpAssistant(
          tester,
          repository,
          locale: scenario.locale,
          useMutableAppControlPolicy: true,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AiAssistantScreen)),
        );
        container.read(_testAppControlPolicyProvider.notifier).state =
            _fullControlPolicyAtRevision2;
        await tester.pump();
        await _submitAndWaitFor(
          tester,
          scenario.input,
          () =>
              find
                  .byKey(const Key('ai_assistant_result'))
                  .evaluate()
                  .isNotEmpty ||
              find
                  .byKey(const Key('ai_assistant_failure'))
                  .evaluate()
                  .isNotEmpty,
        );

        expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);
        expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
        final card = tester.widget<AiActionConfirmationCard>(
          find.byKey(const Key('ai_assistant_result')),
        );
        expect(card.draft.action, isA<CreateIncomeDraft>());
        expect(repository.sendMessageCalls, 0);
      },
    );
  }

  testWidgets('Edit restores the exact note and cancels the bound command', (
    tester,
  ) async {
    final durableRuntime = _RecordingDurableWorkflowRuntime();
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    final card = _currentActionCard(tester);
    final draft = card.draft;
    final expectedText =
        (draft.action as CreateExpenseDraft).transactionDraft.note;
    card.onEdit();
    await _pumpUntil(
      tester,
      () =>
          durableRuntime.cancelledCommandIds.contains(draft.id) &&
          find.byKey(const Key('ai_assistant_result')).evaluate().isEmpty,
    );

    final composer = tester.widget<CPTextField>(
      find.byKey(const Key('ai_assistant_composer')),
    );
    expect(composer.controller!.text, expectedText);
    expect(composer.controller!.selection.baseOffset, expectedText.length);
    expect(composer.controller!.selection.extentOffset, expectedText.length);
    expect(durableRuntime.cancelledCommandIds, <String>[draft.id]);
    expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
  });

  testWidgets(
    'income draft editors preserve account, category, source, date, and status',
    (tester) async {
      final selectedAccount = Account.create(
        id: 'selected-income-account',
        name: 'Selected Income Account',
        type: AccountType.cash,
        currencyCode: 'LYD',
        balance: Decimal.zero,
        icon: 'cash',
        color: 0xFF4F46E5,
      );
      final durableRuntime = _RecordingDurableWorkflowRuntime();
      final repository = _RecordingAiRepository(
        (_) => throw StateError('A confirmed local offer must not reparse.'),
      );
      await _pumpAssistant(
        tester,
        repository,
        durableRuntime: durableRuntime,
        accountsLoader: (_) async =>
            AppResult<List<Account>>.success(<Account>[selectedAccount]),
      );
      await _submitAndWaitFor(
        tester,
        'my friend sent me 1000 LYD',
        () =>
            find.byKey(const Key('ai_assistant_result')).evaluate().isNotEmpty,
      );

      var card = _currentActionCard(tester);
      final selectedCategory = card.categories.firstWhere(
        (category) => category.type.name == 'income',
      );
      card.onAccountChanged!(selectedAccount);
      await _pumpUntil(tester, () {
        final action = _currentActionCard(tester).draft.action;
        return action is CreateIncomeDraft &&
            action.transactionDraft.account.id == selectedAccount.id;
      });

      card = _currentActionCard(tester);
      card.onCategoryChanged!(selectedCategory);
      await _pumpUntil(tester, () {
        final action = _currentActionCard(tester).draft.action;
        return action is CreateIncomeDraft &&
            action.transactionDraft.category?.id == selectedCategory.id;
      });

      card = _currentActionCard(tester);
      card.onIncomeSourceTypeChanged!(IncomeSourceType.gift);
      await _pumpUntil(tester, () {
        final action = _currentActionCard(tester).draft.action;
        return action is CreateIncomeDraft &&
            action.transactionDraft.incomeSourceSuggestion?.sourceType ==
                IncomeSourceType.gift;
      });

      card = _currentActionCard(tester);
      card.onIncomeSourceNameChanged!('Exact Family Gift');
      await _pumpUntil(tester, () {
        final action = _currentActionCard(tester).draft.action;
        return action is CreateIncomeDraft &&
            action.transactionDraft.incomeSourceSuggestion?.sourceNameHint ==
                'Exact Family Gift';
      });

      final selectedDate = DateTime.utc(2026, 8, 16, 9, 30);
      card = _currentActionCard(tester);
      card.onTransactionDateChanged!(selectedDate);
      await _pumpUntil(tester, () {
        final action = _currentActionCard(tester).draft.action;
        return action is CreateIncomeDraft &&
            action.transactionDraft.transactionDate == selectedDate;
      });

      card = _currentActionCard(tester);
      card.onTransactionStatusChanged!(TransactionStatus.pending);
      await _pumpUntil(tester, () {
        final action = _currentActionCard(tester).draft.action;
        return action is CreateIncomeDraft &&
            action.transactionDraft.status == TransactionStatus.pending;
      });

      final action =
          _currentActionCard(tester).draft.action as CreateIncomeDraft;
      expect(action.transactionDraft.account.id, selectedAccount.id);
      expect(action.transactionDraft.category?.id, selectedCategory.id);
      expect(
        action.transactionDraft.incomeSourceSuggestion?.sourceType,
        IncomeSourceType.gift,
      );
      expect(
        action.transactionDraft.incomeSourceSuggestion?.sourceNameHint,
        'Exact Family Gift',
      );
      expect(action.transactionDraft.transactionDate, selectedDate);
      expect(action.transactionDraft.status, TransactionStatus.pending);
      expect(repository.sendMessageCalls, 0);
    },
  );

  testWidgets(
    'draft revision cancels old before persist new and surfaces persist failure',
    (tester) async {
      var failNextPersist = false;
      final durableRuntime = _RecordingDurableWorkflowRuntime(
        onPersist: (_) async {
          if (failNextPersist) {
            throw StateError('synthetic revised-persist failure');
          }
        },
      );
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _expenseJson),
      );
      await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );

      final original = _currentActionCard(tester);
      final replacementCategory = original.categories.firstWhere(
        (category) =>
            category.id !=
            (original.draft.action as CreateExpenseDraft)
                .transactionDraft
                .category
                ?.id,
      );
      durableRuntime.events.clear();
      original.onCategoryChanged!(replacementCategory);
      await _pumpUntil(
        tester,
        () => durableRuntime.persistedDrafts.length == 2,
      );

      final revised = _currentActionCard(tester);
      expect(durableRuntime.events.take(2), <String>[
        'cancel:${original.draft.id}',
        'persist:${revised.draft.id}',
      ]);
      expect(
        (revised.draft.action as CreateExpenseDraft)
            .transactionDraft
            .category
            ?.id,
        replacementCategory.id,
      );

      failNextPersist = true;
      durableRuntime.events.clear();
      revised.onTransactionStatusChanged!(TransactionStatus.pending);
      await _pumpUntil(
        tester,
        () =>
            find.byKey(const Key('ai_assistant_failure')).evaluate().isNotEmpty,
      );

      expect(
        durableRuntime.events.take(2),
        orderedEquals(<Object>[
          'cancel:${revised.draft.id}',
          startsWith('persist:'),
        ]),
      );
      expect(durableRuntime.persistedDrafts, hasLength(2));
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
    },
  );

  testWidgets('owner switch fences a revision whose persist completes late', (
    tester,
  ) async {
    final persistStarted = Completer<void>();
    final persistGate = Completer<void>();
    var blockNextPersist = false;
    final durableRuntime = _RecordingDurableWorkflowRuntime(
      onPersist: (_) async {
        if (!blockNextPersist) return;
        if (!persistStarted.isCompleted) persistStarted.complete();
        await persistGate.future;
      },
    );
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    blockNextPersist = true;
    _currentActionCard(tester).onTransactionStatusChanged!(
      TransactionStatus.pending,
    );
    await _pumpUntil(tester, () => persistStarted.isCompleted);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    container.read(_testOwnerBindingProvider.notifier).state = _ownerBindingB;
    await tester.pump();
    persistGate.complete();
    await tester.pumpAndSettle();

    expect(durableRuntime.persistedDrafts, hasLength(2));
    expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
    expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
    expect(container.read(_testOwnerBindingProvider), _ownerBindingB);
  });

  testWidgets(
    'durable confirmation executes and acknowledges exactly once across retry',
    (tester) async {
      final durableRuntime = _RecordingDurableWorkflowRuntime();
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _expenseJson),
      );
      await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );

      final context = tester.element(find.byType(AiAssistantScreen));
      final l10n = AppLocalizations.of(context);
      final confirmButton = find.widgetWithText(
        CPButton,
        l10n.aiFinancialPreviewConfirm,
      );
      await tester.ensureVisible(confirmButton);
      final capturedConfirm = tester.widget<CPButton>(confirmButton).onPressed!;

      capturedConfirm();
      capturedConfirm();
      await tester.pumpAndSettle();
      capturedConfirm();
      await tester.pump();

      final commandId = durableRuntime.persistedDrafts.single.id;
      expect(durableRuntime.confirmedCommandIds, <String>[commandId]);
      expect(durableRuntime.acknowledgedCommandIds, <String>[commandId]);
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(
        find.byKey(const Key('ai_assistant_verified_action')),
        findsOneWidget,
      );
      expect(find.text(l10n.aiActionConfirmedMessage), findsOneWidget);
    },
  );

  testWidgets('durable cancellation clears the preview and cancels once', (
    tester,
  ) async {
    final durableRuntime = _RecordingDurableWorkflowRuntime();
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    final context = tester.element(find.byType(AiAssistantScreen));
    final l10n = AppLocalizations.of(context);
    final cancelButton = find.widgetWithText(
      CPButton,
      l10n.aiFinancialPreviewReject,
    );
    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    final commandId = durableRuntime.persistedDrafts.single.id;
    expect(durableRuntime.cancelledCommandIds, <String>[commandId]);
    expect(durableRuntime.confirmedCommandIds, isEmpty);
    expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
    expect(find.text(l10n.aiFinancialPreviewRejected), findsOneWidget);
  });

  testWidgets('durable execution failure keeps a failed draft for review', (
    tester,
  ) async {
    final durableRuntime = _RecordingDurableWorkflowRuntime(
      onConfirm: (commandId) async => AppAgentExecutionResult(
        commandId: commandId,
        status: AppAgentCommandStatus.failed,
        verified: false,
        entityType: 'transaction',
        affectedCount: 0,
        completedAt: DateTime.utc(2026, 8, 17, 12),
        safeFailureCode: AppAgentFailureCodes.verificationFailed,
      ),
    );
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    final context = tester.element(find.byType(AiAssistantScreen));
    final l10n = AppLocalizations.of(context);
    final confirmButton = find.widgetWithText(
      CPButton,
      l10n.aiFinancialPreviewConfirm,
    );
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    final card = tester.widget<AiActionConfirmationCard>(
      find.byKey(const Key('ai_assistant_result')),
    );
    expect(card.draft.status, AiActionExecutionStatus.failed);
    expect(durableRuntime.confirmedCommandIds, hasLength(1));
    expect(durableRuntime.acknowledgedCommandIds, isEmpty);
    expect(find.text(l10n.aiFinancialVerificationFailure), findsOneWidget);
  });

  testWidgets('unexpected durable throw leaves no stuck confirmation state', (
    tester,
  ) async {
    final durableRuntime = _RecordingDurableWorkflowRuntime(
      onConfirm: (commandId) async =>
          throw StateError('synthetic durable execution failure'),
    );
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );

    final context = tester.element(find.byType(AiAssistantScreen));
    final l10n = AppLocalizations.of(context);
    final confirmButton = find.widgetWithText(
      CPButton,
      l10n.aiFinancialPreviewConfirm,
    );
    await tester.ensureVisible(confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    final card = tester.widget<AiActionConfirmationCard>(
      find.byKey(const Key('ai_assistant_result')),
    );
    final settledConfirm = tester.widget<CPButton>(
      find.byKey(const Key('ai_financial_preview_confirm')),
    );
    expect(card.draft.status, AiActionExecutionStatus.failed);
    expect(durableRuntime.confirmedCommandIds, hasLength(1));
    expect(settledConfirm.isLoading, isFalse);
    expect(settledConfirm.onPressed, isNull);
    expect(find.text(l10n.aiFinancialWriteFailure), findsOneWidget);
  });

  testWidgets(
    'database write failure offers retry without saving or bypassing confirm',
    (tester) async {
      var attempts = 0;
      final durableRuntime = _RecordingDurableWorkflowRuntime(
        onConfirm: (commandId) async {
          attempts += 1;
          if (attempts == 1) {
            return AppAgentExecutionResult(
              commandId: commandId,
              status: AppAgentCommandStatus.failed,
              verified: false,
              entityType: 'transaction',
              affectedCount: 0,
              completedAt: DateTime.utc(2026, 8, 17, 12),
              safeFailureCode: AiActionFailureCodes.executionFailed,
            );
          }
          return _verifiedDurableSuccess(commandId);
        },
      );
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _expenseJson),
      );
      await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      final firstConfirm = find.widgetWithText(
        CPButton,
        l10n.aiFinancialPreviewConfirm,
      );
      await tester.ensureVisible(firstConfirm);
      await tester.pumpAndSettle();
      await tester.tap(firstConfirm);
      await tester.pumpAndSettle();

      expect(find.text(l10n.aiFinancialWriteFailure), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(durableRuntime.acknowledgedCommandIds, isEmpty);

      await tester.tap(find.text(l10n.retry));
      await _pumpUntil(
        tester,
        () => durableRuntime.persistedDrafts.length == 2,
      );
      expect(durableRuntime.confirmedCommandIds, hasLength(1));
      expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);

      final confirmAgain = find.widgetWithText(
        CPButton,
        l10n.aiFinancialPreviewConfirm,
      );
      await tester.ensureVisible(confirmAgain);
      await tester.pumpAndSettle();
      await tester.tap(confirmAgain);
      await tester.pumpAndSettle();

      expect(durableRuntime.confirmedCommandIds, hasLength(2));
      expect(durableRuntime.acknowledgedCommandIds, hasLength(1));
      expect(
        find.byKey(const Key('ai_assistant_verified_action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'owner switch during durable confirmation suppresses stale success publish',
    (tester) async {
      final confirmGate = Completer<AppAgentExecutionResult>();
      final durableRuntime = _RecordingDurableWorkflowRuntime(
        onConfirm: (_) => confirmGate.future,
      );
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _expenseJson),
      );
      await _pumpAssistant(tester, repository, durableRuntime: durableRuntime);
      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );

      final context = tester.element(find.byType(AiAssistantScreen));
      final l10n = AppLocalizations.of(context);
      final confirmButton = find.widgetWithText(
        CPButton,
        l10n.aiFinancialPreviewConfirm,
      );
      await tester.ensureVisible(confirmButton);
      final capturedConfirm = tester.widget<CPButton>(confirmButton).onPressed!;
      capturedConfirm();
      await tester.pump();
      expect(durableRuntime.confirmedCommandIds, hasLength(1));

      final container = ProviderScope.containerOf(context);
      container.read(_testOwnerBindingProvider.notifier).state = _ownerBindingB;
      await tester.pump();
      final commandId = durableRuntime.confirmedCommandIds.single;
      confirmGate.complete(_verifiedDurableSuccess(commandId));
      await tester.pumpAndSettle();

      expect(durableRuntime.acknowledgedCommandIds, isEmpty);
      expect(durableRuntime.cancelledCommandIds, <String>[commandId]);
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
      expect(find.text(l10n.aiActionConfirmedMessage), findsNothing);
    },
  );

  testWidgets(
    'preview bound to an older policy revision gets a stale configuration denial',
    (tester) async {
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _expenseJson),
      );
      await _pumpAssistant(
        tester,
        repository,
        useMutableAppControlPolicy: true,
      );
      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );
      expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiAssistantScreen)),
      );
      container.read(_testAppControlPolicyProvider.notifier).state =
          _fullControlPolicyAtRevision2;
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      final confirmButton = find.widgetWithText(
        CPButton,
        l10n.aiFinancialPreviewConfirm,
      );
      await tester.ensureVisible(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(repository.sendMessageCalls, 1);
      expect(find.byKey(const Key('ai_assistant_failure')), findsOneWidget);
      expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
      expect(find.text(l10n.aiStaleControlFailure), findsOneWidget);
    },
  );

  testWidgets(
    'late durable permission denial is translated using current execution policy',
    (tester) async {
      late ProviderContainer container;
      final durableRuntime = _PolicyRaceDurableRuntime(
        onConfirm: () {
          container.read(_testAppControlPolicyProvider.notifier).state =
              _confirmedExecutionDisabledPolicyAtRevision2;
        },
      );
      final repository = _RecordingAiRepository(
        (request) async => _successFor(request, _expenseJson),
      );
      await _pumpAssistant(
        tester,
        repository,
        useMutableAppControlPolicy: true,
        durableRuntime: durableRuntime,
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(AiAssistantScreen)),
      );
      await _sendWithIcon(
        tester,
        'record I bought milk for 5 LYD with cash as an expense',
      );
      expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);

      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiAssistantScreen)),
      );
      final confirmButton = find.widgetWithText(
        CPButton,
        l10n.aiFinancialPreviewConfirm,
      );
      await tester.ensureVisible(confirmButton);
      await tester.pumpAndSettle();
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(durableRuntime.confirmCalls, 1);
      expect(
        find.text(l10n.aiConfirmedExecutionDisabledFailure),
        findsOneWidget,
      );
      expect(find.text(l10n.aiGenericDraftPermissionFailure), findsNothing);
    },
  );

  testWidgets('Confirm with a newly missing owner surfaces typed denial', (
    tester,
  ) async {
    var ownerAvailable = true;
    final durableRuntime = _PolicyRaceDurableRuntime(
      onConfirm: () => throw StateError('Execution must not start.'),
    );
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(
      tester,
      repository,
      durableRuntime: durableRuntime,
      ownerBindingReader: () => ownerAvailable ? _ownerBindingA : null,
    );
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AiAssistantScreen)),
    );
    final confirmButton = find.widgetWithText(
      CPButton,
      l10n.aiFinancialPreviewConfirm,
    );
    final capturedConfirm = tester.widget<CPButton>(confirmButton).onPressed!;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    ownerAvailable = false;
    container.invalidate(aiToolOwnerScopeBindingProvider);
    capturedConfirm();
    await tester.pumpAndSettle();

    expect(durableRuntime.confirmCalls, 0);
    expect(find.text(l10n.aiOwnerScopeNotReadyFailure), findsOneWidget);
  });

  testWidgets('logout clears a visible owner A financial preview', (
    tester,
  ) async {
    final repository = _RecordingAiRepository(
      (request) async => _successFor(request, _expenseJson),
    );
    await _pumpAssistant(tester, repository);
    await _sendWithIcon(
      tester,
      'record I bought milk for 5 LYD with cash as an expense',
    );
    expect(find.byKey(const Key('ai_assistant_result')), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    container.read(_testOwnerBindingProvider.notifier).state = null;
    await tester.pump();

    expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
    expect(find.byKey(const Key('ai_assistant_loading')), findsNothing);
  });

  testWidgets('late owner A provider result cannot recreate a draft for B', (
    tester,
  ) async {
    final gate = Completer<AppResult<AiResponse>>();
    final repository = _RecordingAiRepository((_) => gate.future);
    await _pumpAssistant(tester, repository);

    await tester.enterText(
      find.byKey(const Key('ai_assistant_composer')),
      'record I bought milk for 5 LYD with cash as an expense',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('ai_assistant_send_button')),
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await _pumpUntil(tester, () => repository.sendMessageCalls == 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    container.read(_testOwnerBindingProvider.notifier).state = _ownerBindingB;
    await tester.pump();
    gate.complete(repository.success(_expenseJson));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
    expect(find.byKey(const Key('ai_assistant_failure')), findsNothing);
    expect(find.byKey(const Key('ai_assistant_loading')), findsNothing);
  });

  testWidgets('owner switch at an await boundary never resolves B context', (
    tester,
  ) async {
    final accountsStarted = Completer<void>();
    final accountsGate = Completer<AppResult<List<Account>>>();
    var ownerBIsCurrent = false;
    var ownerBCategoryReads = 0;
    final repository = _RecordingAiRepository(
      (_) => throw StateError('A stale operation must not reach the model.'),
    );
    await _pumpAssistant(
      tester,
      repository,
      accountsLoader: (_) {
        if (!accountsStarted.isCompleted) accountsStarted.complete();
        return accountsGate.future;
      },
      categoriesLoader: (_) async {
        if (ownerBIsCurrent) ownerBCategoryReads += 1;
        return AppResult<List<Category>>.success(buildDefaultCategories());
      },
    );

    await tester.enterText(
      find.byKey(const Key('ai_assistant_composer')),
      'record I bought milk for 5 LYD with cash as an expense',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('ai_assistant_send_button')),
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await _pumpUntil(tester, () => accountsStarted.isCompleted);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    ownerBIsCurrent = true;
    container.read(_testOwnerBindingProvider.notifier).state = _ownerBindingB;
    await tester.pump();
    accountsGate.complete(const AppResult<List<Account>>.success(<Account>[]));
    await tester.pumpAndSettle();

    expect(ownerBCategoryReads, 0);
    expect(repository.sendMessageCalls, 0);
    expect(find.byKey(const Key('ai_assistant_result')), findsNothing);
  });

  testWidgets(
    'manual-review recovery stays visible before UI delivery is acknowledged',
    (tester) async {
      final recoveryGate = Completer<AppAgentStartupReconciliationSummary>();
      var recoveryWasVisibleWhenAcknowledged = false;
      late String safeRecoveryMessage;
      final durableRuntime = _RecordingRecoveryDurableRuntime(
        onAcknowledge: (_) {
          recoveryWasVisibleWhenAcknowledged = find
              .text(safeRecoveryMessage)
              .evaluate()
              .isNotEmpty;
        },
      );
      final repository = _RecordingAiRepository(
        (_) => throw StateError('Recovery must not call the model.'),
      );

      await _pumpAssistant(
        tester,
        repository,
        durableRuntime: durableRuntime,
        startupRecovery: recoveryGate.future,
      );
      final context = tester.element(find.byType(AiAssistantScreen));
      safeRecoveryMessage = AppLocalizations.of(context).aiActionInvalidMessage;

      expect(durableRuntime.acknowledgedCommandIds, isEmpty);
      expect(find.text(safeRecoveryMessage), findsNothing);

      recoveryGate.complete(
        AppAgentStartupReconciliationSummary(
          inspectedCount: 1,
          confirmedPendingCount: 0,
          verifiedSucceededCount: 0,
          verifiedNotExecutedCount: 0,
          stillInProgressCount: 0,
          inconsistentCount: 0,
          requiresManualReviewCount: 1,
          reconciledResults: <AppAgentExecutionResult>[
            AppAgentExecutionResult(
              commandId: 'manual-review-command',
              status: AppAgentCommandStatus.failed,
              verified: false,
              entityType: 'financialEntity',
              affectedCount: 0,
              completedAt: DateTime.utc(2026, 8, 10, 12),
              safeFailureCode: AppAgentFailureCodes.recoveryManualReview,
            ),
          ],
        ),
      );

      await _pumpUntil(
        tester,
        () => durableRuntime.acknowledgedCommandIds.isNotEmpty,
      );

      expect(find.text(safeRecoveryMessage), findsOneWidget);
      expect(
        find.text(AppAgentFailureCodes.recoveryManualReview),
        findsNothing,
      );
      expect(recoveryWasVisibleWhenAcknowledged, isTrue);
      expect(durableRuntime.acknowledgedCommandIds, <String>[
        'manual-review-command',
      ]);

      await tester.pump();
      expect(find.text(safeRecoveryMessage), findsOneWidget);
      expect(repository.sendMessageCalls, 0);
    },
  );
}

Future<void> _pumpAssistant(
  WidgetTester tester,
  AiRepository repository, {
  Locale locale = const Locale('en'),
  EffectiveAiAppControlPolicy appControlPolicy = _transactionDraftPolicy,
  bool useMutableAppControlPolicy = false,
  AiActionDurableRuntime durableRuntime = const _NoOpDurableRuntime(),
  Future<AppAgentStartupReconciliationSummary>? startupRecovery,
  Future<AppResult<List<Account>>> Function(Ref ref)? accountsLoader,
  Future<AppResult<List<Category>>> Function(Ref ref)? categoriesLoader,
  Future<AppResult<List<BudgetProgress>>> Function(Ref ref)?
  budgetProgressLoader,
  Stream<AppResult<List<Goal>>> Function(Ref ref)? goalsLoader,
  Future<AppResult<List<GoalProgress>>> Function(Ref ref)? goalProgressLoader,
  AiToolOwnerScopeBinding? Function()? ownerBindingReader,
  AiAgentOrchestrator? agentOrchestrator,
  bool withoutOwner = false,
  OwnerScopeHealth ownerScopeHealth = const OwnerScopeHealth(
    status: OwnerScopeStatus.safe,
  ),
  LegacyDataInventory? legacyInventory,
  bool successfulLegacyClaim = false,
  LegacyDataClaimController Function()? legacyClaimControllerBuilder,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final account = Account.create(
    id: 'cash',
    name: 'Cash',
    type: AccountType.cash,
    currencyCode: 'LYD',
    balance: Decimal.zero,
    icon: 'cash',
    color: 0xFF4F46E5,
  );
  final categories = buildDefaultCategories();
  final initialLegacyInventory =
      legacyInventory ?? LegacyDataInventory(const <String, int>{});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        _testOwnerScopeHealthProvider.overrideWith((_) => ownerScopeHealth),
        _testLegacyInventoryProvider.overrideWith(
          (_) => initialLegacyInventory,
        ),
        ownerScopeHealthProvider.overrideWith(
          (ref) async => ref.watch(_testOwnerScopeHealthProvider),
        ),
        if (legacyInventory != null)
          legacyDataInventoryProvider.overrideWith(
            (ref) async => ref.watch(_testLegacyInventoryProvider),
          ),
        if (legacyClaimControllerBuilder != null)
          legacyDataClaimControllerProvider.overrideWith(
            legacyClaimControllerBuilder,
          )
        else if (successfulLegacyClaim)
          legacyDataClaimControllerProvider.overrideWith(
            _SuccessfulLegacyDataClaimController.new,
          ),
        if (ownerBindingReader != null)
          aiToolOwnerScopeBindingProvider.overrideWith(
            (_) => ownerBindingReader(),
          )
        else if (withoutOwner)
          aiToolOwnerScopeBindingProvider.overrideWithValue(null)
        else
          aiToolOwnerScopeBindingProvider.overrideWith(
            (ref) => ref.watch(_testOwnerBindingProvider),
          ),
        aiAgentAccountScopeProvider.overrideWithValue(
          withoutOwner ? null : 'test-account',
        ),
        if (agentOrchestrator != null)
          aiAgentOrchestratorProvider.overrideWithValue(agentOrchestrator),
        durableAiActionBridgeProvider.overrideWithValue(durableRuntime),
        if (startupRecovery != null) ...[
          aiAppControlFeatureFlagsProvider.overrideWithValue(
            _allAppControlFlags,
          ),
          appAgentStartupReconciliationProvider.overrideWith(
            (_) => startupRecovery,
          ),
        ],
        effectiveAiAppControlPolicyProvider.overrideWith(
          (ref) => useMutableAppControlPolicy
              ? ref.watch(_testAppControlPolicyProvider)
              : appControlPolicy,
        ),
        aiAgentFeatureFlagsProvider.overrideWithValue(
          const AiAgentFeatureFlags(
            agentEnabled: false,
            readOnlyToolsEnabled: true,
            draftToolsEnabled: true,
            conversationMemoryEnabled: true,
            complexPlanningEnabled: false,
          ),
        ),
        aiRepositoryProvider.overrideWithValue(repository),
        createAiActionDraftUseCaseProvider.overrideWithValue(
          CreateAiActionDraft(
            aiRepository: repository,
            parser: const FinancialCommandParser(),
            draftFactory: const AiActionDraftFactory(),
            contextBuilder: const AiActionContextBuilder(),
          ),
        ),
        effectiveBaseCurrencyCodeProvider.overrideWithValue('LYD'),
        accountsProvider.overrideWith(
          accountsLoader ??
              (_) async => AppResult<List<Account>>.success(<Account>[account]),
        ),
        categoriesProvider.overrideWith(
          categoriesLoader ??
              (_) async => AppResult<List<Category>>.success(categories),
        ),
        payeesProvider.overrideWith(
          (_) => Stream.value(const AppResult<List<Payee>>.success(<Payee>[])),
        ),
        exchangeRatesProvider.overrideWith(
          (_) => Stream.value(
            const AppResult<List<StoredExchangeRate>>.success(
              <StoredExchangeRate>[],
            ),
          ),
        ),
        budgetProgressProvider.overrideWith(
          budgetProgressLoader ??
              (_) async => const AppResult<List<BudgetProgress>>.success(
                <BudgetProgress>[],
              ),
        ),
        allGoalsProvider.overrideWith(
          goalsLoader ??
              (_) =>
                  Stream.value(const AppResult<List<Goal>>.success(<Goal>[])),
        ),
        allGoalProgressProvider.overrideWith(
          goalProgressLoader ??
              (_) async =>
                  const AppResult<List<GoalProgress>>.success(<GoalProgress>[]),
        ),
        financialInsightsProvider.overrideWith(
          (_) async => const AppResult<List<FinancialInsight>>.success(
            <FinancialInsight>[],
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.dark(),
        home: const AiAssistantScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AiAssistantScreen)),
  );
  await container.read(ownerScopeHealthProvider.future);
  await tester.pumpAndSettle();
}

AiActionConfirmationCard _currentActionCard(WidgetTester tester) {
  return tester.widget<AiActionConfirmationCard>(
    find.byKey(const Key('ai_assistant_result')),
  );
}

void _setOwnerHealth(ProviderContainer container, OwnerScopeHealth health) {
  container.read(_testOwnerScopeHealthProvider.notifier).state = health;
}

Future<void> _claimLegacyDataAndWaitForResume(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ai_legacy_data_link_action')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm_legacy_local_data_owner')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('confirm_claim_legacy_local_data')));
  await _pumpUntil(
    tester,
    () => find
        .byKey(const Key('ai_legacy_data_resume_action'))
        .evaluate()
        .isNotEmpty,
  );
}

Future<void> _sendWithIcon(WidgetTester tester, String input) async {
  await tester.enterText(find.byKey(const Key('ai_assistant_composer')), input);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('ai_assistant_send_button')));
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await tester.pump();
  await _pumpUntil(tester, () {
    return find.byKey(const Key('ai_assistant_result')).evaluate().isNotEmpty ||
        find.byKey(const Key('ai_assistant_failure')).evaluate().isNotEmpty ||
        find
            .byKey(const Key('ai_legacy_data_resolution_card'))
            .evaluate()
            .isNotEmpty ||
        find
            .byKey(const ValueKey<String>('ai_assistant_message_1'))
            .evaluate()
            .isNotEmpty ||
        find
            .byKey(const Key('ai_assistant_conversation_response'))
            .evaluate()
            .isNotEmpty ||
        find
            .byKey(const Key('ai_assistant_unsupported_response'))
            .evaluate()
            .isNotEmpty;
  });
}

Future<void> _submitAndWaitFor(
  WidgetTester tester,
  String input,
  bool Function() condition,
) async {
  await tester.enterText(find.byKey(const Key('ai_assistant_composer')), input);
  await tester.pump();
  final send = find.byKey(const Key('ai_assistant_send_button'));
  await tester.ensureVisible(send);
  await tester.tap(send);
  await tester.pump();
  await _pumpUntil(tester, condition);
}

Future<void> _holdAcceptanceSend(WidgetTester tester, Finder send) async {
  final gesture = await tester.startGesture(tester.getCenter(send));
  await tester.pump(const Duration(milliseconds: 800));
  await gesture.up();
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 500 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    condition(),
    isTrue,
    reason:
        'Expected assistant state was not reached. '
        'user=${find.byKey(const Key('ai_assistant_user_message')).evaluate().length}, '
        'loading=${find.byKey(const Key('ai_assistant_loading')).evaluate().length}, '
        'result=${find.byKey(const Key('ai_assistant_result')).evaluate().length}, '
        'failure=${find.byKey(const Key('ai_assistant_failure')).evaluate().length}, '
        'legacy=${find.byKey(const Key('ai_legacy_data_resolution_card')).evaluate().length}, '
        'conversation=${find.byKey(const Key('ai_assistant_conversation_response')).evaluate().length}, '
        'unsupported=${find.byKey(const Key('ai_assistant_unsupported_response')).evaluate().length}',
  );
}

const _expenseJson =
    '{"intent":"create_expense","confidence":"0.92","amount":"5",'
    '"currency":"LYD","description":"milk","categoryHint":"Food",'
    '"accountHint":"Cash","requiresConfirmation":true}';

const _incomeJson =
    '{"intent":"create_income","confidence":"0.92","amount":"1000",'
    '"currency":"LYD","description":"income",'
    '"requiresConfirmation":true}';

const _unknownJson =
    '{"intent":"unknown","requiresConfirmation":false,'
    '"description":"unsupported"}';

AppResult<AiResponse> _successFor(AiRequest request, String content) {
  return AppResult.success(
    AiResponse(
      message: AiMessage.assistant(
        conversationId: request.conversationId,
        content: content,
      ),
      providerType: AiProviderType.gemini,
      modelId: 'fake-gemini',
      finishReason: AiFinishReason.complete,
      tokenUsage: const AiTokenUsage(inputTokens: 0, outputTokens: 0),
    ),
  );
}

AppAgentExecutionResult _verifiedDurableSuccess(String commandId) {
  return AppAgentExecutionResult(
    commandId: commandId,
    status: AppAgentCommandStatus.succeeded,
    verified: true,
    entityType: 'transaction',
    affectedCount: 1,
    completedAt: DateTime.utc(2026, 8, 17, 12),
  );
}

class _RecordingAiRepository implements AiRepository {
  _RecordingAiRepository(this._send);

  final Future<AppResult<AiResponse>> Function(AiRequest request) _send;
  int sendMessageCalls = 0;
  AiRequest? lastRequest;

  AppResult<AiResponse> success(String content) {
    final request = lastRequest;
    if (request == null) {
      throw StateError('No request has started.');
    }
    return _successFor(request, content);
  }

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async {
    return AppResult.success(<AiModel>[
      AiModel(
        id: 'fake-gemini',
        providerType: AiProviderType.gemini,
        displayName: 'Fake Gemini',
        capabilities: const <AiCapability>[AiCapability.transactionParsing],
        isDefault: true,
      ),
    ]);
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) {
    sendMessageCalls += 1;
    lastRequest = request;
    return _send(request);
  }
}

class _ReadyTokenProbe implements AppCheckTokenProbe {
  const _ReadyTokenProbe();

  @override
  Future<bool> hasValidToken() async => true;
}

const _allAppControlFlags = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  confirmedExecutionEnabled: true,
  updateDraftsEnabled: false,
  archiveDraftsEnabled: false,
  multiStepPlansEnabled: false,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);

const _confirmedExecutionDisabledFlags = AiAppControlFeatureFlags(
  appControlEnabled: true,
  readToolsEnabled: true,
  navigationToolsEnabled: true,
  createDraftsEnabled: true,
  confirmedExecutionEnabled: false,
  updateDraftsEnabled: false,
  archiveDraftsEnabled: false,
  multiStepPlansEnabled: false,
  agentAuditEnabled: true,
  localDatasetScopeVerified: true,
);

const _transactionDraftPolicy = EffectiveAiAppControlPolicy(
  flags: _allAppControlFlags,
  settings: AiAppControlSettings(
    level: AiAppControlLevel.draftChanges,
    allowFinancialAnalysis: false,
    allowNavigation: false,
    allowTransactionDrafts: true,
    allowBudgetAndGoalDrafts: false,
    allowAccountCategoryPayeeDrafts: false,
    allowRecurringDrafts: false,
    allowMultiStepPlans: false,
    requireConfirmationForEveryChange: true,
  ),
  hasAuthenticatedScope: true,
  runtimeOwnerScopeSafe: true,
  provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  configurationRevision: 1,
);

const _blockedAppControlPolicy = EffectiveAiAppControlPolicy(
  flags: _allAppControlFlags,
  settings: AiAppControlSettings.conservative(),
  hasAuthenticatedScope: true,
  runtimeOwnerScopeSafe: true,
  provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  configurationRevision: 1,
);

const _readOnlyAppControlPolicy = EffectiveAiAppControlPolicy(
  flags: _allAppControlFlags,
  settings: AiAppControlSettings.forLevel(
    AiAppControlLevel.readOnly,
    provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  ),
  hasAuthenticatedScope: true,
  runtimeOwnerScopeSafe: true,
  provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  configurationRevision: 1,
);

const _fullControlPolicyAtRevision2 = EffectiveAiAppControlPolicy(
  flags: _allAppControlFlags,
  settings: AiAppControlSettings.forLevel(
    AiAppControlLevel.fullControl,
    provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  ),
  hasAuthenticatedScope: true,
  runtimeOwnerScopeSafe: true,
  provenance: AiAppControlPolicyProvenance.persistedUserSelection,
  configurationRevision: 2,
);

const _confirmedExecutionDisabledPolicyAtRevision2 =
    EffectiveAiAppControlPolicy(
      flags: _confirmedExecutionDisabledFlags,
      settings: AiAppControlSettings.forLevel(
        AiAppControlLevel.fullControl,
        provenance: AiAppControlPolicyProvenance.persistedUserSelection,
      ),
      hasAuthenticatedScope: true,
      runtimeOwnerScopeSafe: true,
      provenance: AiAppControlPolicyProvenance.persistedUserSelection,
      configurationRevision: 2,
    );

final _testAppControlPolicyProvider =
    StateProvider<EffectiveAiAppControlPolicy>((_) => _transactionDraftPolicy);

class _SuccessfulLegacyDataClaimController extends LegacyDataClaimController {
  @override
  Future<LegacyDataClaimResult?> build() async => null;

  @override
  Future<bool> claim({required bool protectedConfirmationAccepted}) async {
    if (!protectedConfirmationAccepted || state.isLoading) return false;
    state = const AsyncLoading<LegacyDataClaimResult?>();
    await Future<void>.delayed(Duration.zero);
    ref.read(_testOwnerScopeHealthProvider.notifier).state =
        const OwnerScopeHealth(status: OwnerScopeStatus.safe);
    ref.read(_testLegacyInventoryProvider.notifier).state = LegacyDataInventory(
      const <String, int>{},
    );
    state = const AsyncData<LegacyDataClaimResult?>(
      LegacyDataClaimResult(claimedCount: 1, auditId: 'safe-test-claim'),
    );
    return true;
  }
}

class _GatedLegacyDataClaimController extends LegacyDataClaimController {
  _GatedLegacyDataClaimController(this.started, this.gate);

  final Completer<void> started;
  final Completer<bool> gate;

  @override
  Future<LegacyDataClaimResult?> build() async => null;

  @override
  Future<bool> claim({required bool protectedConfirmationAccepted}) async {
    if (!protectedConfirmationAccepted || state.isLoading) return false;
    state = const AsyncLoading<LegacyDataClaimResult?>();
    if (!started.isCompleted) started.complete();
    final succeeded = await gate.future;
    state = succeeded
        ? const AsyncData<LegacyDataClaimResult?>(
            LegacyDataClaimResult(claimedCount: 1, auditId: 'gated-test-claim'),
          )
        : AsyncError<LegacyDataClaimResult?>(
            StateError('gated claim rejected'),
            StackTrace.current,
          );
    return succeeded;
  }
}

class _NoOpAiAgentOrchestrator implements AiAgentOrchestrator {
  const _NoOpAiAgentOrchestrator();

  @override
  Future<AiAgentResponse> respond(AiAgentRequest request) async {
    return const AiAgentResponse(
      kind: AiAgentResponseKind.answer,
      message: 'No-op test response',
    );
  }

  @override
  Future<void> clearConversation() async {}

  @override
  Future<void> startNewConversation() async {}
}

class _NoOpDurableRuntime implements AiActionDurableRuntime {
  const _NoOpDurableRuntime();

  @override
  Future<void> acknowledgeRecoveryResult(String commandId) async {}

  @override
  Future<AppAgentExecutionResult> confirmAndExecute(String commandId) async {
    return AppAgentExecutionResult(
      commandId: commandId,
      status: AppAgentCommandStatus.failed,
      verified: false,
      entityType: 'test',
      affectedCount: 0,
      completedAt: DateTime.now().toUtc(),
      safeFailureCode: 'test_not_executed',
    );
  }

  @override
  Future<void> cancel(String commandId) async {}

  @override
  Future<AppAgentCommand> persistDraft(AiActionDraft draft) async {
    return AppAgentCommand(
      commandId: draft.id,
      conversationId: 'test',
      userAccountScope: 'test-account',
      commandType: AppAgentCommandType.create,
      toolId: 'createExpenseDraft',
      normalizedArguments: const <String, Object?>{},
      permission: AgentPermission.createDraft,
      risk: AgentActionRisk.low,
      createdAt: draft.createdAt,
      expiresAt: draft.createdAt.add(const Duration(minutes: 1)),
      status: AppAgentCommandStatus.awaitingConfirmation,
    );
  }

  @override
  Future<AiActionDraft?> restoreLatestPendingDraft() async => null;
}

class _RecordingDurableWorkflowRuntime extends _NoOpDurableRuntime {
  _RecordingDurableWorkflowRuntime({this.onConfirm, this.onPersist});

  final Future<AppAgentExecutionResult> Function(String commandId)? onConfirm;
  final Future<void> Function(AiActionDraft draft)? onPersist;
  final List<AiActionDraft> persistedDrafts = <AiActionDraft>[];
  final List<String> confirmedCommandIds = <String>[];
  final List<String> cancelledCommandIds = <String>[];
  final List<String> acknowledgedCommandIds = <String>[];
  final List<String> events = <String>[];

  @override
  Future<AppAgentCommand> persistDraft(AiActionDraft draft) async {
    events.add('persist:${draft.id}');
    await onPersist?.call(draft);
    persistedDrafts.add(draft);
    return super.persistDraft(draft);
  }

  @override
  Future<AppAgentExecutionResult> confirmAndExecute(String commandId) async {
    confirmedCommandIds.add(commandId);
    return onConfirm?.call(commandId) ?? _verifiedDurableSuccess(commandId);
  }

  @override
  Future<void> cancel(String commandId) async {
    events.add('cancel:$commandId');
    cancelledCommandIds.add(commandId);
  }

  @override
  Future<void> acknowledgeRecoveryResult(String commandId) async {
    acknowledgedCommandIds.add(commandId);
  }
}

class _PolicyRaceDurableRuntime extends _NoOpDurableRuntime {
  _PolicyRaceDurableRuntime({required this.onConfirm});

  final VoidCallback onConfirm;
  int confirmCalls = 0;

  @override
  Future<AppAgentExecutionResult> confirmAndExecute(String commandId) async {
    confirmCalls += 1;
    onConfirm();
    return AppAgentExecutionResult(
      commandId: commandId,
      status: AppAgentCommandStatus.failed,
      verified: false,
      entityType: 'test',
      affectedCount: 0,
      completedAt: DateTime.now().toUtc(),
      safeFailureCode: AppAgentFailureCodes.permissionDenied,
    );
  }
}

class _RecordingRecoveryDurableRuntime extends _NoOpDurableRuntime {
  _RecordingRecoveryDurableRuntime({required this.onAcknowledge});

  final void Function(String commandId) onAcknowledge;
  final List<String> acknowledgedCommandIds = <String>[];

  @override
  Future<void> acknowledgeRecoveryResult(String commandId) async {
    onAcknowledge(commandId);
    acknowledgedCommandIds.add(commandId);
  }
}
