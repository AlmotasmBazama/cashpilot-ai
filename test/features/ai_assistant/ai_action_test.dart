import 'dart:async';
import 'dart:convert';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/application/services/ai_action_executor.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_action_validation_result.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_capability.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_message.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_model.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_provider_type.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_request.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_response.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/entities/ai_transaction_draft.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/repositories/ai_repository.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_context_builder.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_draft_factory.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/ai_action_validator.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/services/financial_command_parser.dart';
import 'package:cashpilot_ai/features/ai_assistant/domain/usecases/create_ai_action_draft.dart';
import 'package:cashpilot_ai/features/categories/domain/defaults/default_category_definitions.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget.dart';
import 'package:cashpilot_ai/features/budgets/domain/entities/budget_progress.dart';
import 'package:cashpilot_ai/features/budgets/domain/enums/budget_period_type.dart';
import 'package:cashpilot_ai/features/budgets/domain/enums/budget_status.dart';
import 'package:cashpilot_ai/features/budgets/domain/repositories/budget_repository.dart';
import 'package:cashpilot_ai/features/budgets/domain/usecases/create_budget.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/entities/stored_exchange_rate.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/repositories/exchange_rate_repository.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/usecases/convert_money.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal.dart';
import 'package:cashpilot_ai/features/goals/domain/entities/goal_progress.dart';
import 'package:cashpilot_ai/features/goals/domain/enums/goal_status.dart';
import 'package:cashpilot_ai/features/goals/domain/enums/goal_type.dart';
import 'package:cashpilot_ai/features/goals/domain/repositories/goal_repository.dart';
import 'package:cashpilot_ai/features/goals/domain/usecases/add_goal_contribution.dart';
import 'package:cashpilot_ai/features/goals/domain/usecases/create_goal.dart';
import 'package:cashpilot_ai/features/income_sources/domain/entities/income_source_suggestion.dart';
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/payees/domain/enums/payee_type.dart';
import 'package:cashpilot_ai/features/payees/domain/repositories/payees_repository.dart';
import 'package:cashpilot_ai/features/payees/domain/usecases/touch_payee_last_used.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/create_transfer_command.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/created_transfer.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/payment_method.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transfer.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = AiActionValidator();

  group('AI action draft creation', () {
    test('creates an identified awaiting-confirmation envelope', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(responseText: expenseJson()),
        input: 'I bought milk for 5 LYD with cash',
      );

      expect(draft.id, isNotEmpty);
      expect(draft.action, isA<CreateExpenseDraft>());
      expect(draft.status, AiActionExecutionStatus.awaitingConfirmation);
      expect(draft.createdAt.isUtc, isTrue);
      expect(draft.updatedAt, draft.createdAt);
      expect(validator.validate(draft.action).isValid, isTrue);
    });

    test('Arabic expense command creates a valid draft', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","confidence":"0.92","amount":"5","currency":"LYD","description":"حليب","categoryHint":"Groceries","accountHint":"ادفع لي","requiresConfirmation":true}',
        ),
        input: 'اشتريت حليب بـ5 دنانير ودفعت عن طريق ادفع لي',
        accounts: <Account>[
          account(id: 'tdb', paymentMethodIds: <String>['edfaly']),
        ],
      );

      final action = draft.action as CreateExpenseDraft;
      expect(action.transactionDraft.amount.amount, Decimal.parse('5'));
      expect(action.transactionDraft.paymentMethod, PaymentMethod.edfaly);
      expect(action.transactionDraft.account.id, 'tdb');
    });

    test('ambiguous account returns clarification safely', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository.failure(),
        input: 'I bought milk for 5 LYD',
        accounts: <Account>[
          account(id: 'cash'),
          account(id: 'bank', name: 'Bank'),
        ],
      );

      expect(draft.action, isA<ClarificationRequiredAction>());
      expect(draft.status, AiActionExecutionStatus.draft);
      expect(validator.validate(draft.action).isValid, isFalse);
    });

    test(
      'model account hint cannot select an account by database id',
      () async {
        const opaqueAccountId = 'acc_4e0d3f60bdf94a85843fbcd8';
        final draft = await createDraft(
          aiRepository: FakeAiRepository(
            responseText: expenseJson().replaceFirst(
              '"accountHint":"Cash"',
              '"accountHint":"$opaqueAccountId"',
            ),
          ),
          input: 'Record a 5 LYD milk expense',
          accounts: <Account>[
            account(id: opaqueAccountId, name: 'Daily cash'),
            account(id: 'savings-account', name: 'Savings'),
          ],
        );

        expect(draft.action, isA<ClarificationRequiredAction>());
        expect(draft.status, AiActionExecutionStatus.draft);
        expect(validator.validate(draft.action).isValid, isFalse);
      },
    );
  });

  group('AI exchange rate integration', () {
    final accounts = <Account>[
      account(id: 'usd', name: 'Dollar account', currencyCode: 'USD'),
      account(id: 'lyd', name: 'Dinar account', currencyCode: 'LYD'),
    ];
    const transferJson =
        '{"intent":"create_transfer","amount":"100","currency":"USD",'
        '"description":"currency transfer","sourceAccountHint":"Dollar account",'
        '"destinationAccountHint":"Dinar account","requiresConfirmation":true}';

    test('explicit user rate creates a confirmed transfer draft', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText: transferJson.replaceFirst(
            '"requiresConfirmation"',
            '"exchangeRate":"7.5","requiresConfirmation"',
          ),
        ),
        input:
            'Transfer 100 USD from Dollar account to Dinar account at rate 7.5',
        accounts: accounts,
      );

      final action = draft.action as CreateTransferDraft;
      expect(action.exchangeRate?.rate, Decimal.parse('7.5'));
      expect(action.destinationAmount?.amount, Decimal.parse('750.0'));
      expect(draft.status, AiActionExecutionStatus.awaitingConfirmation);
    });

    test('stored manual rate creates a valid transfer draft', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(responseText: transferJson),
        input: 'Transfer 100 USD from Dollar account to Dinar account',
        accounts: accounts,
        exchangeRates: <StoredExchangeRate>[
          StoredExchangeRate.create(
            baseCurrency: 'USD',
            quoteCurrency: 'LYD',
            rate: Decimal.parse('7.5'),
          ),
        ],
      );

      final action = draft.action as CreateTransferDraft;
      expect(action.exchangeRate?.rate, Decimal.parse('7.5'));
      expect(action.destinationAmount?.amount, Decimal.parse('750.0'));
      expect(validator.validate(action).isValid, isTrue);
    });

    test('missing rate requests clarification and never guesses', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText: transferJson.replaceFirst(
            '"requiresConfirmation"',
            '"exchangeRate":"7.5","requiresConfirmation"',
          ),
        ),
        input: 'Transfer 100 USD from Dollar account to Dinar account',
        accounts: accounts,
      );

      expect(draft.action, isA<ClarificationRequiredAction>());
      expect(draft.status, AiActionExecutionStatus.draft);
    });

    test(
      'Arabic conversion question uses local ConvertMoney use case',
      () async {
        final aiRepository = FakeAiRepository.failure();
        final draft = await createDraft(
          aiRepository: aiRepository,
          input: 'كم تساوي 100 دولار بالدينار؟',
          accounts: accounts,
          convertMoney: ConvertMoney(_FixedConversionRepository()),
        );

        final action = draft.action as CurrencyConversionAnswerAction;
        expect(action.sourceAmount.amount, Decimal.fromInt(100));
        expect(action.sourceAmount.currencyCode, 'USD');
        expect(action.convertedAmount.amount, Decimal.fromInt(750));
        expect(action.convertedAmount.currencyCode, 'LYD');
        expect(action.requiresConfirmation, isFalse);
        expect(aiRepository.sendMessageCalls, 0);
      },
    );

    test('conversion question without a rate asks for one', () async {
      final aiRepository = FakeAiRepository.failure();
      final draft = await createDraft(
        aiRepository: aiRepository,
        input: 'How much is 100 USD in LYD?',
        accounts: accounts,
        convertMoney: ConvertMoney(_MissingConversionRepository()),
      );

      expect(draft.action, isA<ClarificationRequiredAction>());
      expect(aiRepository.sendMessageCalls, 0);
    });
  });

  group('AI budget integration', () {
    const budgetJson =
        '{"intent":"create_budget","amount":"500","currency":"LYD",'
        '"description":"food budget","categoryHint":"Groceries",'
        '"periodType":"monthly","requiresConfirmation":true}';

    test('Arabic and English prompts create confirmed budget drafts', () async {
      for (final input in <String>[
        'حطلي ميزانية 500 دينار للأكل هذا الشهر',
        'Create a 500 LYD groceries budget this month',
      ]) {
        final draft = await createDraft(
          aiRepository: FakeAiRepository(responseText: budgetJson),
          input: input,
        );

        final action = draft.action as CreateBudgetDraft;
        expect(action.budget.amount, Decimal.fromInt(500));
        expect(action.budget.periodType, BudgetPeriodType.monthly);
        expect(action.category.name, 'Groceries');
        expect(draft.status, AiActionExecutionStatus.awaitingConfirmation);
      }
    });

    test('unknown budget category requests clarification', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText: budgetJson.replaceFirst('Groceries', 'Unknown area'),
        ),
        input: 'Create a 500 LYD budget for an unknown area',
      );

      expect(draft.action, isA<ClarificationRequiredAction>());
    });

    test('budget draft cannot execute without confirmation', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(responseText: budgetJson),
        input: 'Create a 500 LYD groceries budget this month',
      );
      final budgets = _RecordingBudgetRepository();
      final result = await executorFor(
        RecordingTransactionsRepository(),
        createBudget: CreateBudget(budgets),
      ).execute(draft, confirmed: false);

      expect(result, isA<AppFailure<AiActionExecutionResult>>());
      expect(budgets.createCalls, 0);
    });

    test('budget progress question is answered locally', () async {
      final aiRepository = FakeAiRepository.failure();
      final groceries = buildDefaultCategories().firstWhere(
        (category) => category.name == 'Groceries',
      );
      final value = Budget.create(
        name: 'Groceries',
        categoryId: groceries.id,
        amount: Decimal.fromInt(500),
        currency: 'LYD',
        periodType: BudgetPeriodType.monthly,
        startDate: DateTime.utc(2026, 7, 1),
        endDate: DateTime.utc(2026, 8, 1),
      );
      final progress = BudgetProgress(
        budget: value,
        spentAmount: Decimal.fromInt(120),
        remainingAmount: Decimal.fromInt(380),
        progressPercent: Decimal.fromInt(24),
        status: BudgetStatus.onTrack,
        periodStart: value.startDate,
        periodEnd: value.endDate,
        missingRateWarnings: const [],
      );

      final draft = await createDraft(
        aiRepository: aiRepository,
        input: 'كم صرفت من ميزانية Groceries؟',
        budgetProgress: <BudgetProgress>[progress],
      );

      final action = draft.action as BudgetProgressAnswerAction;
      expect(action.progress.spentAmount, Decimal.fromInt(120));
      expect(action.requiresConfirmation, isFalse);
      expect(aiRepository.sendMessageCalls, 0);
    });
  });

  group('AI goal integration', () {
    const goalJson =
        '{"intent":"create_goal","amount":"3000","currency":"LYD",'
        '"description":"Laptop","goalHint":"Laptop",'
        '"goalType":"purchase","dateText":"6 months",'
        '"requiresConfirmation":true}';

    test('Arabic and English prompts create confirmed goal drafts', () async {
      for (final input in <String>[
        'نبي نجمع 3000 دينار للابتوب خلال 6 شهور',
        'Create a 3000 LYD laptop goal for six months',
      ]) {
        final draft = await createDraft(
          aiRepository: FakeAiRepository(responseText: goalJson),
          input: input,
        );

        final action = draft.action as CreateGoalDraft;
        expect(action.goal.title, 'Laptop');
        expect(action.goal.targetAmount, Decimal.fromInt(3000));
        expect(action.goal.type, GoalType.purchase);
        expect(action.goal.targetDate, isNotNull);
        expect(draft.status, AiActionExecutionStatus.awaitingConfirmation);
      }
    });

    test('add contribution creates a tracking-only confirmed draft', () async {
      final travel = goalValue(title: 'Travel');
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"add_goal_contribution","amount":"100","currency":"LYD","description":"Travel contribution","goalHint":"Travel","requiresConfirmation":true}',
        ),
        input: 'زود 100 دينار لهدف السفر',
        goals: <Goal>[travel],
      );

      final action = draft.action as AddGoalContributionDraft;
      expect(action.goal.id, travel.id);
      expect(action.contribution.amount, Decimal.fromInt(100));
      expect(action.changesMoney, isFalse);
      expect(action.requiresConfirmation, isTrue);
    });

    test('ambiguous goal contribution requests clarification', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"add_goal_contribution","amount":"100","currency":"LYD","description":"goal contribution","goalHint":"Unknown","requiresConfirmation":true}',
        ),
        input: 'Add 100 LYD to my goal',
        goals: <Goal>[
          goalValue(title: 'Travel'),
          goalValue(title: 'Laptop'),
        ],
      );

      expect(draft.action, isA<ClarificationRequiredAction>());
    });

    test('goal progress question is answered locally', () async {
      final aiRepository = FakeAiRepository.failure();
      final goal = goalValue(title: 'Travel', current: Decimal.fromInt(400));
      final progress = GoalProgress(
        goal: goal,
        currentAmount: Decimal.fromInt(400),
        remainingAmount: Decimal.fromInt(2600),
        progressPercent: Decimal.parse('13.33333333'),
        daysRemaining: 120,
        monthlyNeeded: Decimal.fromInt(650),
        status: GoalStatus.active,
      );
      final draft = await createDraft(
        aiRepository: aiRepository,
        input: 'What is the progress of my Travel goal?',
        goals: <Goal>[goal],
        goalProgress: <GoalProgress>[progress],
      );

      final action = draft.action as GoalProgressAnswerAction;
      expect(action.progress.currentAmount, Decimal.fromInt(400));
      expect(action.requiresConfirmation, isFalse);
      expect(aiRepository.sendMessageCalls, 0);
    });

    test('goal draft cannot execute without confirmation', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(responseText: goalJson),
        input: 'Create a laptop goal',
      );
      final goals = _RecordingGoalRepository();
      final result = await executorFor(
        RecordingTransactionsRepository(),
        createGoal: CreateGoalUseCase(goals),
      ).execute(draft, confirmed: false);

      expect(result, isA<AppFailure<AiActionExecutionResult>>());
      expect(goals.createCalls, 0);
    });
  });

  group('AI action execution safety', () {
    test('draft cannot execute without confirmation', () async {
      final repository = RecordingTransactionsRepository();
      final executor = executorFor(repository);
      final draft = await fallbackDraft();

      final result = await executor.execute(draft, confirmed: false);

      expect(result, isA<AppFailure<AiActionExecutionResult>>());
      expect(failureOf(result).code, AiActionFailureCodes.confirmationRequired);
      expect(repository.createTransactionCalls, 0);
      expect(
        executor.statusFor(draft),
        AiActionExecutionStatus.awaitingConfirmation,
      );
    });

    test(
      'confirmed draft executes once and retry after success is rejected',
      () async {
        final repository = RecordingTransactionsRepository();
        final executor = executorFor(repository);
        final draft = await fallbackDraft();

        final first = await executor.execute(draft, confirmed: true);
        final retry = await executor.execute(draft, confirmed: true);

        expect(first, isA<AppSuccess<AiActionExecutionResult>>());
        expect(
          first.expectSuccess().draft.status,
          AiActionExecutionStatus.executed,
        );
        expect(retry, isA<AppFailure<AiActionExecutionResult>>());
        expect(failureOf(retry).code, AiActionFailureCodes.alreadyExecuted);
        expect(repository.createTransactionCalls, 1);
      },
    );

    test('concurrent double confirm cannot duplicate a transaction', () async {
      final gate = Completer<void>();
      final repository = RecordingTransactionsRepository(createGate: gate);
      final executor = executorFor(repository);
      final draft = await fallbackDraft();

      final firstFuture = executor.execute(draft, confirmed: true);
      await Future<void>.delayed(Duration.zero);
      final secondFuture = executor.execute(draft, confirmed: true);
      final second = await secondFuture;
      gate.complete();
      final first = await firstFuture;

      expect(first, isA<AppSuccess<AiActionExecutionResult>>());
      expect(second, isA<AppFailure<AiActionExecutionResult>>());
      expect(failureOf(second).code, AiActionFailureCodes.alreadyExecuted);
      expect(repository.createTransactionCalls, 1);
    });

    test('cancelled draft cannot later execute', () async {
      final repository = RecordingTransactionsRepository();
      final executor = executorFor(repository);
      final draft = await fallbackDraft();

      final cancelled = executor.cancel(draft);
      final result = await executor.execute(draft, confirmed: true);

      expect(cancelled.status, AiActionExecutionStatus.cancelled);
      expect(failureOf(result).code, AiActionFailureCodes.invalidStatus);
      expect(repository.createTransactionCalls, 0);
    });

    test(
      'unexpected use-case exception records failed and returns coded failure',
      () async {
        final repository = RecordingTransactionsRepository(throwOnCreate: true);
        final executor = executorFor(repository);
        final draft = await fallbackDraft();

        final result = await executor.execute(draft, confirmed: true);

        expect(failureOf(result).code, AiActionFailureCodes.executionFailed);
        expect(executor.statusFor(draft), AiActionExecutionStatus.failed);
        expect(repository.createTransactionCalls, 1);
      },
    );

    test('unknown intent never calls a financial use case', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"unknown","requiresConfirmation":false,"description":"unknown"}',
        ),
        input: 'do something unknown',
      );
      final repository = RecordingTransactionsRepository();

      final result = await executorFor(
        repository,
      ).execute(draft, confirmed: true);

      expect(draft.action, isA<ClarificationRequiredAction>());
      expect(failureOf(result).code, AiActionFailureCodes.invalid);
      expect(repository.totalCreateCalls, 0);
    });

    test(
      'destructive structured intent is blocked and never executes',
      () async {
        final draft = await createDraft(
          aiRepository: FakeAiRepository(
            responseText:
                '{"intent":"delete_account","requiresConfirmation":true}',
          ),
          input: 'help me organize things',
        );
        final repository = RecordingTransactionsRepository();

        final result = await executorFor(
          repository,
        ).execute(draft, confirmed: true);

        expect(draft.action, isA<BlockedAiAction>());
        expect(failureOf(result).code, AiActionFailureCodes.destructiveBlocked);
        expect(repository.totalCreateCalls, 0);
      },
    );

    test(
      'destructive wording is blocked before fallback can misparse it',
      () async {
        final aiRepository = FakeAiRepository.failure();
        final draft = await createDraft(
          aiRepository: aiRepository,
          input: 'delete grocery transaction 5',
        );
        final repository = RecordingTransactionsRepository();

        final result = await executorFor(
          repository,
        ).execute(draft, confirmed: true);

        expect(aiRepository.sendMessageCalls, 0);
        expect(draft.action, isA<BlockedAiAction>());
        expect(failureOf(result).code, AiActionFailureCodes.destructiveBlocked);
        expect(repository.totalCreateCalls, 0);
      },
    );

    test('zero amount is invalid and never executes', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(responseText: expenseJson(amount: '0')),
        input: 'I bought milk for 0 LYD with cash',
      );
      final repository = RecordingTransactionsRepository();

      final result = await executorFor(
        repository,
      ).execute(draft, confirmed: true);

      expect(failureOf(result).code, AiActionFailureCodes.invalid);
      expect(repository.totalCreateCalls, 0);
    });

    test('negative structured amount is invalid and never executes', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(responseText: expenseJson(amount: '-5')),
        input: 'I bought milk for -5 LYD with cash',
      );
      final repository = RecordingTransactionsRepository();

      final result = await executorFor(
        repository,
      ).execute(draft, confirmed: true);

      expect(failureOf(result).code, AiActionFailureCodes.invalid);
      expect(repository.totalCreateCalls, 0);
    });

    test(
      'negative fallback amount is not converted to a positive expense',
      () async {
        final draft = await createDraft(
          aiRepository: FakeAiRepository.failure(),
          input: 'I bought milk for -5 LYD with cash',
        );
        final repository = RecordingTransactionsRepository();

        final result = await executorFor(
          repository,
        ).execute(draft, confirmed: true);

        expect(draft.action, isA<ClarificationRequiredAction>());
        expect(failureOf(result).code, AiActionFailureCodes.invalid);
        expect(repository.totalCreateCalls, 0);
      },
    );
  });

  group('AI income draft completeness', () {
    test('income requires an explicit source classification', () {
      final missing = CreateIncomeDraft(_incomeTransactionDraft());
      final inferred = CreateIncomeDraft(
        _incomeTransactionDraft(
          sourceType: IncomeSourceType.gift,
          source: IncomeSourceSuggestionSource.aiSemantic,
          sourceIdentity: 'Friend',
          transactionDate: DateTime.utc(2026, 8, 16),
        ),
      );
      final learned = CreateIncomeDraft(
        _incomeTransactionDraft(
          sourceType: IncomeSourceType.salary,
          source: IncomeSourceSuggestionSource.trustedLocalRule,
          transactionDate: DateTime.utc(2026, 8, 16),
        ),
      );

      expect(
        validator.validate(missing).status,
        AiActionValidationStatus.needsClarification,
      );
      expect(
        validator.validate(inferred).status,
        AiActionValidationStatus.needsClarification,
      );
      expect(
        validator.validate(learned).status,
        AiActionValidationStatus.needsClarification,
      );
    });

    test('income requires a transaction date', () {
      final action = CreateIncomeDraft(
        _incomeTransactionDraft(
          sourceType: IncomeSourceType.salary,
          source: IncomeSourceSuggestionSource.explicitUserInput,
        ),
      );

      expect(
        validator.validate(action).status,
        AiActionValidationStatus.needsClarification,
      );
    });

    test('source identity is required for person or institution inflows', () {
      for (final sourceType in <IncomeSourceType>[
        IncomeSourceType.gift,
        IncomeSourceType.debtRepayment,
        IncomeSourceType.loanProceeds,
        IncomeSourceType.reimbursement,
        IncomeSourceType.externalTransfer,
      ]) {
        final missingIdentity = CreateIncomeDraft(
          _incomeTransactionDraft(
            sourceType: sourceType,
            source: IncomeSourceSuggestionSource.explicitUserInput,
            transactionDate: DateTime.utc(2026, 8, 16),
          ),
        );
        final complete = CreateIncomeDraft(
          _incomeTransactionDraft(
            sourceType: sourceType,
            source: IncomeSourceSuggestionSource.explicitUserInput,
            sourceIdentity: 'Named source',
            transactionDate: DateTime.utc(2026, 8, 16),
          ),
        );

        expect(
          validator.validate(missingIdentity).status,
          AiActionValidationStatus.needsClarification,
          reason: sourceType.name,
        );
        expect(
          validator.validate(complete).isValid,
          isTrue,
          reason: sourceType.name,
        );
      }
    });

    test(
      'unmatched source identity is retained without creating a payee',
      () async {
        final repository = RecordingTransactionsRepository();
        final draft = AiActionDraft.create(
          action: CreateIncomeDraft(
            _incomeTransactionDraft(
              sourceType: IncomeSourceType.debtRepayment,
              source: IncomeSourceSuggestionSource.explicitUserInput,
              sourceIdentity: 'Salem',
              transactionDate: DateTime.utc(2026, 8, 16),
            ),
          ),
        );

        final result = await executorFor(
          repository,
        ).execute(draft, confirmed: true);

        expect(result, isA<AppSuccess<AiActionExecutionResult>>());
        expect(repository.lastTransaction?.payeeId, isNull);
        expect(
          repository.lastTransaction?.note,
          'Recorded income\nSource: Salem',
        );
      },
    );

    for (final status in <TransactionStatus>[
      TransactionStatus.pending,
      TransactionStatus.posted,
    ]) {
      test('confirmed income preserves ${status.name} status', () async {
        final repository = RecordingTransactionsRepository();
        final draft = AiActionDraft.create(
          action: CreateIncomeDraft(
            _incomeTransactionDraft(
              sourceType: IncomeSourceType.salary,
              source: IncomeSourceSuggestionSource.explicitUserInput,
              transactionDate: DateTime.utc(2026, 8, 16),
              status: status,
            ),
          ),
        );

        final result = await executorFor(
          repository,
        ).execute(draft, confirmed: true);

        expect(result, isA<AppSuccess<AiActionExecutionResult>>());
        expect(repository.createTransactionCalls, 1);
        expect(repository.lastTransaction?.status, status);
        expect(
          repository.lastTransaction?.transactionDate,
          DateTime.utc(2026, 8, 16),
        );
      });
    }
  });

  group('AI payee integration', () {
    test('Arabic and English expense hints resolve to payeeId', () async {
      final salem = payee(name: 'سالم', aliases: const ['Salem']);
      for (final entry in <({String input, String hint})>[
        (input: 'دفعت لسالم 50', hint: 'سالم'),
        (input: 'I paid Salem 50', hint: 'Salem'),
      ]) {
        final draft = await createDraft(
          aiRepository: FakeAiRepository(
            responseText:
                '{"intent":"create_expense","amount":"50","currency":"LYD","description":"payment","categoryHint":"Groceries","accountHint":"Cash","payeeHint":"${entry.hint}","requiresConfirmation":true}',
          ),
          input: entry.input,
          payees: <Payee>[salem],
        );
        final transactionDraft =
            (draft.action as CreateExpenseDraft).transactionDraft;
        expect(transactionDraft.payee?.id, salem.id);
      }
    });

    test('payee default category is applied when category is missing', () async {
      final categories = buildDefaultCategories();
      final groceries = categories.firstWhere(
        (category) => category.name == 'Groceries',
      );
      final merchant = payee(name: 'Al Nawar', defaultCategoryId: groceries.id);
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"12","currency":"LYD","description":"payment","accountHint":"Cash","payeeHint":"Al Nawar","requiresConfirmation":true}',
        ),
        input: 'I paid Al Nawar 12',
        categories: categories,
        payees: <Payee>[merchant],
      );

      expect(
        (draft.action as CreateExpenseDraft).transactionDraft.category?.id,
        groceries.id,
      );
    });

    test('payee default account is used when account is missing', () async {
      final merchant = payee(name: 'Shop', defaultAccountId: 'bank');
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"10","currency":"LYD","description":"payment","categoryHint":"Groceries","payeeHint":"Shop","requiresConfirmation":true}',
        ),
        input: 'Paid Shop 10',
        accounts: <Account>[
          account(id: 'cash', name: 'Cash'),
          account(id: 'bank', name: 'Bank'),
        ],
        payees: <Payee>[merchant],
      );

      expect(
        (draft.action as CreateExpenseDraft).transactionDraft.account.id,
        'bank',
      );
    });

    test('explicit account overrides payee default account', () async {
      final merchant = payee(name: 'Shop', defaultAccountId: 'bank');
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"10","currency":"LYD","description":"payment","categoryHint":"Groceries","accountHint":"Cash","payeeHint":"Shop","requiresConfirmation":true}',
        ),
        input: 'Paid Shop 10 from Cash',
        accounts: <Account>[
          account(id: 'cash', name: 'Cash'),
          account(id: 'bank', name: 'Bank'),
        ],
        payees: <Payee>[merchant],
      );

      expect(
        (draft.action as CreateExpenseDraft).transactionDraft.account.id,
        'cash',
      );
    });

    test('explicit payment method overrides the payee default account', () async {
      final merchant = payee(name: 'Shop', defaultAccountId: 'bank');
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"10","currency":"LYD","description":"paid with Edfaly","categoryHint":"Groceries","accountHint":"Edfaly","payeeHint":"Shop","requiresConfirmation":true}',
        ),
        input: 'Paid Shop 10 with Edfaly',
        accounts: <Account>[
          account(
            id: 'wallet',
            name: 'Wallet',
            paymentMethodIds: const <String>['edfaly'],
          ),
          account(id: 'bank', name: 'Bank'),
        ],
        payees: <Payee>[merchant],
      );
      final transactionDraft =
          (draft.action as CreateExpenseDraft).transactionDraft;

      expect(transactionDraft.account.id, 'wallet');
      expect(transactionDraft.paymentMethod, PaymentMethod.edfaly);
    });

    test('ambiguous payee requests clarification', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"10","currency":"LYD","description":"payment","categoryHint":"Groceries","accountHint":"Cash","payeeHint":"Salem","requiresConfirmation":true}',
        ),
        input: 'Paid Salem 10',
        payees: <Payee>[
          payee(name: 'Salem One', aliases: const ['Salem']),
          payee(name: 'Salem Two', aliases: const ['Salem']),
        ],
      );

      expect(draft.action, isA<ClarificationRequiredAction>());
    });

    test('unknown payee remains a hint and is not auto-created', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"10","currency":"LYD","description":"payment","categoryHint":"Groceries","accountHint":"Cash","payeeHint":"New Shop","requiresConfirmation":true}',
        ),
        input: 'Paid New Shop 10',
      );
      final transactionDraft =
          (draft.action as CreateExpenseDraft).transactionDraft;

      expect(transactionDraft.payee, isNull);
      expect(transactionDraft.payeeHint, 'New Shop');
    });

    test('confirmed draft creates transaction with payee link', () async {
      final merchant = payee(name: 'Linked Shop');
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"10","currency":"LYD","description":"payment","categoryHint":"Groceries","accountHint":"Cash","payeeHint":"Linked Shop","requiresConfirmation":true}',
        ),
        input: 'Paid Linked Shop 10',
        payees: <Payee>[merchant],
      );
      final repository = RecordingTransactionsRepository();
      final touch = RecordingTouchPayeeLastUsed();

      await executorFor(
        repository,
        touchPayeeLastUsed: touch,
      ).execute(draft, confirmed: true);

      expect(repository.lastTransaction?.payeeId, merchant.id);
      expect(touch.touchedPayeeId, merchant.id);
    });

    test('failed transaction creation does not touch the payee', () async {
      final merchant = payee(name: 'Uncommitted Shop');
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText:
              '{"intent":"create_expense","amount":"10","currency":"LYD","description":"payment","categoryHint":"Groceries","accountHint":"Cash","payeeHint":"Uncommitted Shop","requiresConfirmation":true}',
        ),
        input: 'Paid Uncommitted Shop 10',
        payees: <Payee>[merchant],
      );
      final repository = RecordingTransactionsRepository(failOnCreate: true);
      final touch = RecordingTouchPayeeLastUsed();

      final result = await executorFor(
        repository,
        touchPayeeLastUsed: touch,
      ).execute(draft, confirmed: true);

      expect(result, isA<AppFailure<AiActionExecutionResult>>());
      expect(touch.touchedPayeeId, isNull);
    });
  });

  group('Gemini and local parser fallback', () {
    test('Gemini invalid JSON falls back to local parser', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(responseText: '{"intent":}'),
        input: 'I bought milk for 5 LYD with cash',
      );

      expect(draft.action, isA<CreateExpenseDraft>());
    });

    test('Gemini failure falls back to local parser', () async {
      final draft = await fallbackDraft();

      expect(draft.action, isA<CreateExpenseDraft>());
    });

    test('unsupported Gemini schema falls back to local parser', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository(
          responseText: '{"intent":"future_magic","requiresConfirmation":true}',
        ),
        input: 'I bought milk for 5 LYD with cash',
      );

      expect(draft.action, isA<CreateExpenseDraft>());
    });

    test('parser failure returns clarification and cannot execute', () async {
      final draft = await createDraft(
        aiRepository: FakeAiRepository.failure(),
        input: 'nonsense without an amount',
      );
      final repository = RecordingTransactionsRepository();

      final result = await executorFor(
        repository,
      ).execute(draft, confirmed: true);

      expect(draft.action, isA<ClarificationRequiredAction>());
      expect(result, isA<AppFailure<AiActionExecutionResult>>());
      expect(repository.totalCreateCalls, 0);
    });
  });

  group('AI data minimization', () {
    test(
      'request context is allowlisted and excludes identity and balances',
      () async {
        final aiRepository = FakeAiRepository(responseText: expenseJson());
        final defaultCategories = buildDefaultCategories();
        await createDraft(
          aiRepository: aiRepository,
          input: 'I paid 5 LYD with Edfaly for office supplies',
          accounts: <Account>[
            account(
              id: 'firebase-uid-secret',
              name: 'Daily account',
              balance: '987654.32',
              paymentMethodIds: <String>['edfaly'],
            ),
            account(id: 'email-alias', name: 'secret@example.com'),
            account(id: 'phone-alias', name: 'Account 0912345678'),
            account(id: 'arabic-phone-alias', name: 'هاتف ٠٩١٢٣٤٥٦٧٨'),
            account(id: 'persian-phone-alias', name: 'حساب ۰۹۱۲۳۴۵۶۷۸'),
            account(id: 'path-alias', name: 'users/private/documents/account'),
          ],
          categories: <Category>[
            ...defaultCategories,
            defaultCategories.first.copyWith(
              id: 'private-category',
              name: 'token_abcdefghijklmnopqrstuvwxyz',
            ),
            defaultCategories.first.copyWith(
              id: 'arabic-phone-category',
              name: 'فئة ٠١٢٣٤٥٦٧',
            ),
          ],
          payees: <Payee>[
            payee(
              name: 'Sensitive Person',
              aliases: const <String>['0912345678'],
            ),
          ],
          locale: 'ar-LY',
        );

        final request = aiRepository.lastRequest!;
        final context = request.context;
        expect(
          context.keys,
          unorderedEquals(<String>[
            'locale',
            'supportedCurrencies',
            'accountAliases',
            'paymentMethodAliases',
            'categoryNames',
            'categorySemantics',
          ]),
        );
        expect(
          context['categorySemantics'],
          contains(
            predicate<String>((value) => value.startsWith('Groceries:')),
          ),
        );
        expect(context['locale'], 'ar-LY');
        expect(context['accountAliases'], contains('Daily account'));
        expect(context['paymentMethodAliases'], contains('Edfaly'));
        expect(
          context['supportedCurrencies'],
          containsAll(<String>['LYD', 'USD']),
        );
        final encoded = jsonEncode(context);
        expect(encoded, isNot(contains('firebase-uid-secret')));
        expect(encoded, isNot(contains('987654.32')));
        expect(encoded, isNot(contains('email')));
        expect(encoded, isNot(contains('"phone":')));
        expect(encoded, isNot(contains('uid')));
        expect(encoded, isNot(contains('Sensitive Person')));
        expect(encoded, isNot(contains('0912345678')));
        expect(encoded, isNot(contains('٠٩١٢٣٤٥٦٧٨')));
        expect(encoded, isNot(contains('۰۹۱۲۳۴۵۶۷۸')));
        expect(encoded, isNot(contains('٠١٢٣٤٥٦٧')));
        expect(encoded, isNot(contains('secret@example.com')));
        expect(encoded, isNot(contains('users/private')));
        expect(encoded, isNot(contains('token_abcdefghijklmnopqrstuvwxyz')));
        expect(request.messages, hasLength(1));
      },
    );
  });
}

String expenseJson({String amount = '5'}) {
  return '{"intent":"create_expense","confidence":"0.92","amount":"$amount","currency":"LYD","description":"milk","categoryHint":"Groceries","accountHint":"Cash","requiresConfirmation":true}';
}

Future<AiActionDraft> fallbackDraft() {
  return createDraft(
    aiRepository: FakeAiRepository.failure(),
    input: 'I bought milk for 5 LYD with cash',
  );
}

AiTransactionDraft _incomeTransactionDraft({
  IncomeSourceType? sourceType,
  IncomeSourceSuggestionSource source = IncomeSourceSuggestionSource.fallback,
  String? sourceIdentity,
  DateTime? transactionDate,
  TransactionStatus status = TransactionStatus.posted,
}) {
  final incomeCategory = buildDefaultCategories().firstWhere(
    (category) => category.name == 'Salary',
  );
  return AiTransactionDraft(
    type: TransactionType.income,
    amount: Money(amount: Decimal.fromInt(1000), currencyCode: 'LYD'),
    account: account(id: 'income-account'),
    category: incomeCategory,
    paymentMethod: PaymentMethod.bankTransfer,
    paymentMethodDefinition: null,
    note: 'Recorded income',
    payeeHint: sourceIdentity,
    incomeSourceSuggestion: sourceType == null
        ? null
        : IncomeSourceSuggestion(
            sourceType: sourceType,
            sourceNameHint: sourceIdentity,
            confidence: 100,
            source: source,
            requiresClarification: false,
          ),
    transactionDate: transactionDate,
    status: status,
  );
}

Future<AiActionDraft> createDraft({
  required AiRepository aiRepository,
  required String input,
  List<Account>? accounts,
  List<Category>? categories,
  List<Payee> payees = const <Payee>[],
  List<StoredExchangeRate> exchangeRates = const <StoredExchangeRate>[],
  List<BudgetProgress> budgetProgress = const <BudgetProgress>[],
  List<Goal> goals = const <Goal>[],
  List<GoalProgress> goalProgress = const <GoalProgress>[],
  ConvertMoney? convertMoney,
  String locale = 'en',
}) {
  return draftUseCase(aiRepository: aiRepository, convertMoney: convertMoney)(
    input: input,
    accounts: accounts ?? <Account>[account(id: 'cash')],
    categories: categories ?? buildDefaultCategories(),
    baseCurrencyCode: 'LYD',
    locale: locale,
    accountClarificationMessage: 'Which account?',
    payees: payees,
    exchangeRates: exchangeRates,
    budgetProgress: budgetProgress,
    goals: goals,
    goalProgress: goalProgress,
    ambiguousPayeeMessage: 'Which payee?',
    goalClarificationMessage: 'Which goal?',
  ).then((result) => result.expectSuccess());
}

CreateAiActionDraft draftUseCase({
  required AiRepository aiRepository,
  ConvertMoney? convertMoney,
}) {
  return CreateAiActionDraft(
    aiRepository: aiRepository,
    parser: const FinancialCommandParser(),
    draftFactory: const AiActionDraftFactory(),
    contextBuilder: const AiActionContextBuilder(),
    convertMoney: convertMoney,
  );
}

class _FixedConversionRepository implements ExchangeRateRepository {
  @override
  Future<AppResult<Money>> convert(Money money, String toCurrencyCode) async {
    return AppResult.success(
      Money(
        amount: money.amount * Decimal.parse('7.5'),
        currencyCode: toCurrencyCode,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MissingConversionRepository implements ExchangeRateRepository {
  @override
  Future<AppResult<Money>> convert(Money money, String toCurrencyCode) async {
    return const AppResult.failure(Failure(message: 'Missing rate.'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AiActionExecutor executorFor(
  RecordingTransactionsRepository repository, {
  TouchPayeeLastUsed? touchPayeeLastUsed,
  CreateBudget? createBudget,
  CreateGoalUseCase? createGoal,
  AddGoalContributionUseCase? addGoalContribution,
}) {
  return AiActionExecutor(
    createTransaction: CreateTransaction(repository),
    createTransfer: CreateTransfer(repository),
    validator: const AiActionValidator(),
    createBudget: createBudget,
    createGoal: createGoal,
    addGoalContribution: addGoalContribution,
    touchPayeeLastUsed: touchPayeeLastUsed,
  );
}

class _RecordingBudgetRepository implements BudgetRepository {
  int createCalls = 0;

  @override
  Future<AppResult<Budget>> createBudget(Budget budget) async {
    createCalls += 1;
    return AppResult.success(budget);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingGoalRepository implements GoalRepository {
  int createCalls = 0;

  @override
  Future<AppResult<Goal>> createGoal(Goal goal) async {
    createCalls += 1;
    return AppResult.success(goal);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingTouchPayeeLastUsed extends TouchPayeeLastUsed {
  RecordingTouchPayeeLastUsed() : super(_StubPayeesRepository());

  String? touchedPayeeId;

  @override
  Future<AppResult<Payee>> call(String id, DateTime usedAt) async {
    touchedPayeeId = id;
    return AppResult.success(
      Payee.create(id: id, name: 'Touched payee', lastUsedAt: usedAt),
    );
  }
}

class _StubPayeesRepository implements PayeesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Account account({
  required String id,
  String name = 'Cash',
  String currencyCode = 'LYD',
  String balance = '100',
  List<String> paymentMethodIds = const <String>[],
}) {
  return Account.create(
    id: id,
    name: name,
    type: AccountType.bank,
    currencyCode: currencyCode,
    balance: Decimal.parse(balance),
    icon: 'bank',
    color: 0xFF4F46E5,
    paymentMethodIds: paymentMethodIds,
  );
}

Payee payee({
  required String name,
  List<String> aliases = const <String>[],
  String? defaultCategoryId,
  String? defaultAccountId,
}) {
  return Payee.create(
    name: name,
    type: PayeeType.merchant,
    aliases: aliases,
    defaultCategoryId: defaultCategoryId,
    defaultAccountId: defaultAccountId,
  );
}

Goal goalValue({required String title, Decimal? current}) => Goal.create(
  title: title,
  targetAmount: Decimal.fromInt(3000),
  currentAmount: current,
  currency: 'LYD',
);

class FakeAiRepository implements AiRepository {
  FakeAiRepository({required this.responseText}) : fails = false;

  FakeAiRepository.failure() : responseText = null, fails = true;

  final String? responseText;
  final bool fails;
  int sendMessageCalls = 0;
  AiRequest? lastRequest;

  @override
  Future<AppResult<List<AiModel>>> getAvailableModels() async {
    return AppResult.success(<AiModel>[
      AiModel(
        id: 'fake',
        providerType: AiProviderType.mock,
        displayName: 'Fake',
        capabilities: const <AiCapability>[AiCapability.transactionParsing],
        isDefault: true,
      ),
    ]);
  }

  @override
  Future<AppResult<AiResponse>> sendMessage(AiRequest request) async {
    sendMessageCalls += 1;
    lastRequest = request;
    if (fails) {
      return const AppResult.failure(Failure(message: 'Gemini failed.'));
    }

    return AppResult.success(
      AiResponse(
        message: AiMessage.assistant(
          conversationId: request.conversationId,
          content: responseText ?? '',
        ),
        providerType: AiProviderType.mock,
        modelId: 'fake',
        finishReason: AiFinishReason.complete,
        tokenUsage: const AiTokenUsage(inputTokens: 0, outputTokens: 0),
      ),
    );
  }
}

class RecordingTransactionsRepository implements TransactionsRepository {
  RecordingTransactionsRepository({
    this.createGate,
    this.throwOnCreate = false,
    this.failOnCreate = false,
  });

  final Completer<void>? createGate;
  final bool throwOnCreate;
  final bool failOnCreate;
  int createTransactionCalls = 0;
  int createTransferCalls = 0;
  Transaction? lastTransaction;

  int get totalCreateCalls => createTransactionCalls + createTransferCalls;

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    createTransactionCalls += 1;
    lastTransaction = transaction;
    if (throwOnCreate) {
      throw StateError('create failed');
    }
    if (failOnCreate) {
      return const AppResult.failure(Failure(message: 'Create failed.'));
    }
    await createGate?.future;
    return AppResult.success(transaction);
  }

  @override
  Future<AppResult<CreatedTransfer>> createTransfer(
    CreateTransferCommand command,
  ) async {
    createTransferCalls += 1;
    return const AppResult.failure(Failure(message: 'Not needed.'));
  }

  @override
  Future<AppResult<void>> deleteTransaction(
    String id, {
    List<Transaction>? expectedCurrent,
  }) async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<Transaction?>> getTransaction(String id) async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<List<Transaction>>> getTransactions({
    String? accountId,
    String? categoryId,
    String? payeeId,
    String? transferGroupId,
    TransactionStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return const AppResult.success(<Transaction>[]);
  }

  @override
  Future<AppResult<List<Transaction>>> searchTransactions(
    String query, {
    int? limit,
    Set<TransactionType>? transactionTypes,
    TransactionStatus? status,
  }) async {
    return const AppResult.success(<Transaction>[]);
  }

  @override
  Future<AppResult<Transaction>> updateTransaction(
    Transaction transaction, {
    Transaction? expectedCurrent,
  }) async {
    return AppResult.success(transaction);
  }

  @override
  Future<AppResult<List<Transaction>>> updateTransactionStatus(
    String id,
    TransactionStatus status, {
    List<Transaction>? expectedCurrent,
  }) async {
    return const AppResult.success(<Transaction>[]);
  }
}

Failure failureOf<T>(AppResult<T> result) {
  return switch (result) {
    AppFailure<T>(:final failure) => failure,
    AppSuccess<T>() => throw TestFailure('Expected failure but got success.'),
  };
}

extension AppResultTestX<T> on AppResult<T> {
  T expectSuccess() {
    return switch (this) {
      AppSuccess<T>(:final data) => data,
      AppFailure<T>(:final failure) => throw TestFailure(
        'Expected success but got failure: ${failure.message}',
      ),
    };
  }
}
