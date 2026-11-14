import 'dart:async';

import 'package:cashpilot_ai/core/error/failure.dart';
import 'package:cashpilot_ai/core/error/result.dart';
import 'package:cashpilot_ai/features/accounts/application/providers/accounts_providers.dart';
import 'package:cashpilot_ai/features/accounts/domain/entities/account.dart';
import 'package:cashpilot_ai/features/accounts/domain/enums/account_type.dart';
import 'package:cashpilot_ai/features/categories/application/providers/categories_providers.dart';
import 'package:cashpilot_ai/features/categories/domain/entities/category.dart';
import 'package:cashpilot_ai/features/categories/domain/enums/category_type.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_color.dart';
import 'package:cashpilot_ai/features/categories/domain/value_objects/category_icon.dart';
import 'package:cashpilot_ai/features/exchange_rates/application/providers/exchange_rates_providers.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/repositories/exchange_rate_repository.dart';
import 'package:cashpilot_ai/features/exchange_rates/domain/usecases/get_latest_exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/exchange_rate.dart';
import 'package:cashpilot_ai/features/finance_engine/domain/value_objects/money.dart';
import 'package:cashpilot_ai/features/payees/application/providers/payees_providers.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/payees/domain/enums/payee_type.dart';
import 'package:cashpilot_ai/features/transactions/application/providers/transactions_providers.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/create_transfer_command.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/created_transfer.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction_history_page.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transfer.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/update_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_status.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/presentation/pages/transaction_details_screen.dart';
import 'package:cashpilot_ai/features/transactions/presentation/pages/transactions_screen.dart';
import 'package:cashpilot_ai/features/transactions/presentation/pages/transfer_screen.dart';
import 'package:cashpilot_ai/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:cashpilot_ai/features/transactions/presentation/widgets/transaction_form_sheet.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transfer preview renders on a narrow RTL phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final accounts = [
      _account(id: 'cash', name: 'الحساب اليومي', currencyCode: 'LYD'),
      _account(id: 'usd', name: 'حساب الدولار', currencyCode: 'USD'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success(accounts),
          ),
          latestExchangeRateProvider.overrideWith(
            (_, _) async => AppResult<ExchangeRate?>.success(
              ExchangeRate(
                fromCurrencyCode: 'LYD',
                toCurrencyCode: 'USD',
                rate: Decimal.parse('0.2'),
                asOf: DateTime.utc(2026, 1, 1),
              ),
            ),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('ar'),
          child: const TransferScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('معاينة التحويل'), findsOneWidget);
    expect(find.text('سعر يدوي محفوظ مقترح'), findsWidgets);
    expect(find.text('إنشاء تحويل'), findsOneWidget);
    expect(find.textContaining('1 LYD = 0.2 USD'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'OF-005 delayed FX lookup ignores a second transfer confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final accounts = <Account>[
        _account(id: 'cash', name: 'Cash', currencyCode: 'LYD'),
        _account(id: 'usd', name: 'USD', currencyCode: 'USD'),
      ];
      final rates = _DelayedExchangeRateRepository();
      final transactions = _RecordingTransactionsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith(
              (_) async => AppResult<List<Account>>.success(accounts),
            ),
            latestExchangeRateProvider.overrideWith(
              (_, _) async => const AppResult<ExchangeRate?>.success(null),
            ),
            getLatestExchangeRateUseCaseProvider.overrideWithValue(
              GetLatestExchangeRate(rates),
            ),
            createTransferUseCaseProvider.overrideWithValue(
              CreateTransfer(transactions),
            ),
          ],
          child: _localizedApp(
            locale: const Locale('en'),
            child: const TransferScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '10');
      final submit = find.ancestor(
        of: find.text('Create transfer'),
        matching: find.byType(CPButton),
      );
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();

      await tester.tap(submit);
      await tester.tap(submit);

      expect(rates.calls, 1);
      expect(transactions.commands, isEmpty);
      rates.result.complete(
        AppResult<ExchangeRate?>.success(
          ExchangeRate(
            fromCurrencyCode: 'LYD',
            toCurrencyCode: 'USD',
            rate: Decimal.parse('0.2'),
            asOf: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(transactions.commands, hasLength(1));
      final command = transactions.commands.single;
      expect(command.transferGroupId, isNotEmpty);
      expect(command.outgoingTransactionId, isNotEmpty);
      expect(command.incomingTransactionId, isNotEmpty);
      expect(
        command.outgoingTransactionId,
        isNot(command.incomingTransactionId),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transaction list remains scannable on a small phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final account = _account(
      id: 'cash',
      name: 'Daily cash account',
      currencyCode: 'LYD',
    );
    final category = Category.create(
      id: 'coffee',
      name: 'Coffee',
      type: CategoryType.expense,
      icon: const CategoryIcon(key: 'coffee'),
      color: const CategoryColor(argb: 0xFFEF4444),
    );
    final transaction = Transaction.create(
      id: 'transaction',
      accountId: account.id,
      categoryId: category.id,
      amount: Money(amount: Decimal.parse('1234567.89'), currencyCode: 'LYD'),
      type: TransactionType.expense,
      note: 'Morning coffee',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success([account]),
          ),
          categoriesProvider.overrideWith(
            (_) async => AppResult<List<Category>>.success([category]),
          ),
          transactionHistoryProvider.overrideWith(
            (_, _) => Stream.value(
              AppResult<TransactionHistoryPage>.success(
                TransactionHistoryPage(
                  transactions: <Transaction>[transaction],
                  totalCount: 1,
                ),
              ),
            ),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('en'),
          child: const TransactionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Results'), findsOneWidget);
    expect(find.text('Morning coffee'), findsOneWidget);
    expect(find.textContaining('1234567.89'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final localeCase
      in <
        ({
          Locale locale,
          String loadMoreLabel,
          String retryLabel,
          String errorMessage,
          String loadedCount,
        })
      >[
        (
          locale: Locale('en'),
          loadMoreLabel: 'Load more transactions',
          retryLabel: 'Retry',
          errorMessage: 'Refresh the page or try again later.',
          loadedCount: '55 of 55',
        ),
        (
          locale: Locale('ar'),
          loadMoreLabel: 'تحميل معاملات إضافية',
          retryLabel: 'إعادة المحاولة',
          errorMessage: 'قم بتحديث الصفحة أو حاول لاحقا.',
          loadedCount: '55 من 55',
        ),
      ]) {
    testWidgets(
      'transaction history loads the next page in ${localeCase.locale.languageCode}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final account = _account(id: 'cash', name: 'Cash', currencyCode: 'LYD');
        final category = Category.create(
          id: 'general',
          name: 'General',
          type: CategoryType.expense,
          icon: const CategoryIcon(key: 'receipt'),
          color: const CategoryColor(argb: 0xFFEF4444),
        );
        final transactions = <Transaction>[
          for (var index = 0; index < 55; index++)
            Transaction.create(
              id: 'transaction-$index',
              accountId: account.id,
              categoryId: category.id,
              amount: Money(amount: Decimal.one, currencyCode: 'LYD'),
              type: TransactionType.expense,
              note: 'Item $index',
              transactionDate: DateTime.utc(
                2026,
                1,
                1,
              ).add(Duration(minutes: index)),
            ),
        ];
        final requests = <TransactionHistoryRequest>[];
        final loadMoreControllers =
            <StreamController<AppResult<TransactionHistoryPage>>>[];
        addTearDown(() async {
          for (final controller in loadMoreControllers) {
            await controller.close();
          }
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountsProvider.overrideWith(
                (_) async => AppResult<List<Account>>.success([account]),
              ),
              categoriesProvider.overrideWith(
                (_) async => AppResult<List<Category>>.success([category]),
              ),
              transactionHistoryProvider.overrideWith((_, request) {
                requests.add(request);
                if (request.limit == 50) {
                  return Stream.value(
                    AppResult<TransactionHistoryPage>.success(
                      TransactionHistoryPage(
                        transactions: transactions.take(request.limit),
                        totalCount: transactions.length,
                      ),
                    ),
                  );
                }
                final controller =
                    StreamController<AppResult<TransactionHistoryPage>>();
                loadMoreControllers.add(controller);
                return controller.stream;
              }),
            ],
            child: _localizedApp(
              locale: localeCase.locale,
              child: const TransactionsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests.single.limit, 50);

        await tester.scrollUntilVisible(
          find.byKey(const Key('transactions_load_more_button')),
          600,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('transactions_lazy_list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text(localeCase.loadMoreLabel), findsOneWidget);
        final retainedPageOneKey = tester
            .widgetList<TransactionCard>(find.byType(TransactionCard))
            .first
            .key!;
        await tester.tap(
          find.byKey(const Key('transactions_load_more_button')),
        );
        await tester.pump();

        expect(requests.last.limit, 100);
        expect(loadMoreControllers, hasLength(1));
        expect(find.byKey(retainedPageOneKey), findsOneWidget);
        expect(
          find.byKey(const Key('transactions_load_more_button')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('transactions_load_more_button')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        loadMoreControllers.single.add(
          const AppResult<TransactionHistoryPage>.failure(
            Failure(message: 'Expected page-two test failure.'),
          ),
        );
        await tester.pump();

        expect(find.byKey(retainedPageOneKey), findsOneWidget);
        expect(
          find.byKey(const Key('transactions_load_more_error')),
          findsOneWidget,
        );
        expect(find.text(localeCase.errorMessage), findsOneWidget);
        expect(find.text(localeCase.retryLabel), findsOneWidget);

        final retryButton = find.byKey(
          const Key('transactions_load_more_retry_button'),
        );
        await tester.ensureVisible(retryButton);
        await tester.pumpAndSettle();
        await tester.tap(retryButton);
        await tester.pump();

        expect(loadMoreControllers, hasLength(2));
        expect(requests.last.limit, 100);
        expect(find.byType(TransactionCard), findsWidgets);
        loadMoreControllers.last.add(
          AppResult<TransactionHistoryPage>.success(
            TransactionHistoryPage(
              transactions: transactions,
              totalCount: transactions.length,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('transactions_load_more_error')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('transactions_load_more_button')),
          findsNothing,
        );
        expect(find.byType(TransactionCard), findsWidgets);
        final visibleKeys = tester
            .widgetList<TransactionCard>(find.byType(TransactionCard))
            .map((card) => card.key)
            .toList();
        expect(visibleKeys.toSet(), hasLength(visibleKeys.length));
        final listFinder = find.byKey(const Key('transactions_lazy_list'));
        final listView = tester.widget<ListView>(listFinder);
        final delegate =
            listView.childrenDelegate as SliverChildBuilderDelegate;
        expect(delegate.estimatedChildCount, 57);
        final listContext = tester.element(listFinder);
        final pageTwoItem = delegate.builder(listContext, 56)! as Padding;
        expect(pageTwoItem.child, isA<TransactionCard>());
        expect(
          pageTwoItem.child!.key,
          const ValueKey('transaction-transaction-54'),
        );
        final header = delegate.builder(listContext, 0)!;
        expect(requests.where((request) => request.limit == 100), hasLength(2));

        await tester.pumpWidget(
          _localizedApp(
            locale: localeCase.locale,
            child: Scaffold(body: SingleChildScrollView(child: header)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(localeCase.loadedCount), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'transaction history lazily debounces search and preserves payee hits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final account = _account(id: 'cash', name: 'Cash', currencyCode: 'LYD');
      final category = Category.create(
        id: 'general',
        name: 'General',
        type: CategoryType.expense,
        icon: const CategoryIcon(key: 'receipt'),
        color: const CategoryColor(argb: 0xFFEF4444),
      );
      final transactions = <Transaction>[
        for (final note in <String>['Keep this', 'Hide this'])
          Transaction.create(
            id: note,
            accountId: account.id,
            categoryId: category.id,
            amount: Money(amount: Decimal.one, currencyCode: 'LYD'),
            type: TransactionType.expense,
            note: note,
            transactionDate: DateTime.utc(2026, 1, 1),
          ),
        Transaction.create(
          id: 'Payee only',
          accountId: account.id,
          categoryId: category.id,
          payeeId: 'merchant-42',
          amount: Money(amount: Decimal.one, currencyCode: 'LYD'),
          type: TransactionType.income,
          status: TransactionStatus.pending,
          transactionDate: DateTime.utc(2026, 1, 1),
        ),
      ];
      final historyRequests = <TransactionHistoryRequest>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith(
              (_) async => AppResult<List<Account>>.success([account]),
            ),
            categoriesProvider.overrideWith(
              (_) async => AppResult<List<Category>>.success([category]),
            ),
            transactionHistoryProvider.overrideWith((_, request) {
              historyRequests.add(request);
              final filtered = transactions
                  .where((transaction) {
                    final query = request.query.toLowerCase();
                    final matchesText =
                        query.isEmpty ||
                        (transaction.note?.toLowerCase().contains(query) ??
                            false) ||
                        (transaction.payeeId?.toLowerCase().contains(query) ??
                            false);
                    final matchesFilter = switch (request.filter) {
                      TransactionHistoryFilter.all => true,
                      TransactionHistoryFilter.income =>
                        transaction.type == TransactionType.income,
                      TransactionHistoryFilter.expense =>
                        transaction.type == TransactionType.expense,
                      TransactionHistoryFilter.transfer =>
                        transaction.type == TransactionType.transferIn ||
                            transaction.type == TransactionType.transferOut,
                      TransactionHistoryFilter.pending =>
                        transaction.status == TransactionStatus.pending,
                    };
                    return matchesText && matchesFilter;
                  })
                  .toList(growable: false);
              return Stream.value(
                AppResult<TransactionHistoryPage>.success(
                  TransactionHistoryPage(
                    transactions: filtered.take(request.limit),
                    totalCount: filtered.length,
                  ),
                ),
              );
            }),
          ],
          child: _localizedApp(
            locale: const Locale('en'),
            child: const TransactionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(
        find.byKey(const Key('transactions_lazy_list')),
      );
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
      expect(find.text('Keep this'), findsOneWidget);
      expect(find.text('Hide this'), findsOneWidget);
      historyRequests.clear();

      await tester.enterText(find.byType(TextFormField).first, 'merchant-42');
      await tester.pump(const Duration(milliseconds: 299));
      expect(historyRequests, isEmpty);
      expect(find.text('Hide this'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(historyRequests, <TransactionHistoryRequest>[
        (
          query: 'merchant-42',
          filter: TransactionHistoryFilter.all,
          sort: TransactionHistorySort.newest,
          limit: 50,
        ),
      ]);
      const payeeOnlyCardKey = ValueKey('transaction-Payee only');
      expect(find.byKey(payeeOnlyCardKey), findsOneWidget);
      expect(find.text('Keep this'), findsNothing);
      expect(find.text('Hide this'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
      await tester.pumpAndSettle();
      expect(historyRequests.last.filter, TransactionHistoryFilter.income);
      expect(find.byKey(payeeOnlyCardKey), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Pending'));
      await tester.pumpAndSettle();
      expect(historyRequests.last.filter, TransactionHistoryFilter.pending);
      expect(find.byKey(payeeOnlyCardKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RTL transfer accepts Arabic-Indic decimal input', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final transactions = _RecordingTransactionsRepository();
    final accounts = <Account>[
      _account(id: 'cash', name: 'نقدي', currencyCode: 'LYD'),
      _account(id: 'savings', name: 'توفير', currencyCode: 'LYD'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success(accounts),
          ),
          createTransferUseCaseProvider.overrideWithValue(
            CreateTransfer(transactions),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('ar'),
          child: const TransferScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '١٢٫٥');
    final submit = find.ancestor(
      of: find.text('إنشاء تحويل'),
      matching: find.byType(CPButton),
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(transactions.commands, hasLength(1));
    expect(
      transactions.commands.single.sourceAmount.amount,
      Decimal.parse('12.5'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending details edit prepopulates identity and ignores duplicate save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cash = _account(id: 'cash', name: 'Cash', currencyCode: 'LYD');
      final category = Category.create(
        id: 'food',
        name: 'Food',
        type: CategoryType.expense,
        icon: const CategoryIcon(key: 'groceries'),
        color: const CategoryColor(argb: 0xFFEF4444),
      );
      final createdAt = DateTime.utc(2026, 1, 1);
      final pending = Transaction.create(
        id: 'pending-edit-ui',
        accountId: cash.id,
        categoryId: category.id,
        amount: Money(amount: Decimal.parse('12.5'), currencyCode: 'LYD'),
        type: TransactionType.expense,
        status: TransactionStatus.pending,
        note: 'Original note',
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final repository = _RecordingUpdateTransactionsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionByIdProvider.overrideWith(
              (_, _) async => AppResult<Transaction?>.success(pending),
            ),
            accountsProvider.overrideWith(
              (_) async => AppResult<List<Account>>.success(<Account>[cash]),
            ),
            categoriesProvider.overrideWith(
              (_) async =>
                  AppResult<List<Category>>.success(<Category>[category]),
            ),
            categoriesByTypeProvider.overrideWith(
              (_, _) async =>
                  AppResult<List<Category>>.success(<Category>[category]),
            ),
            payeesProvider.overrideWith(
              (_) =>
                  Stream.value(const AppResult<List<Payee>>.success(<Payee>[])),
            ),
            updateTransactionUseCaseProvider.overrideWithValue(
              UpdateTransaction(repository),
            ),
          ],
          child: _localizedApp(
            locale: const Locale('en'),
            child: const TransactionDetailsScreen(
              transactionId: 'pending-edit-ui',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Edit transaction'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit transaction'));
      await tester.pumpAndSettle();
      expect(find.text('Edit transaction'), findsWidgets);
      expect(
        find.text(
          'Pending transactions do not affect account balances until they are posted.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        '12.5',
      );

      await tester.enterText(find.byType(TextFormField).first, '25');
      final save = find.ancestor(
        of: find.text('Save'),
        matching: find.byType(CPButton),
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();

      expect(repository.calls, hasLength(1));
      final edited = repository.calls.single;
      expect(edited.id, pending.id);
      expect(edited.createdAt, pending.createdAt);
      expect(edited.amount.amount, Decimal.parse('25'));
      expect(edited.status, TransactionStatus.pending);
      repository.result.complete(AppResult<Transaction>.success(edited));
      await tester.pumpAndSettle();
      expect(find.text('Transaction updated.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelling a pending edit performs no repository mutation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cash = _account(id: 'cash', name: 'Cash', currencyCode: 'LYD');
    final category = Category.create(
      id: 'food',
      name: 'Food',
      type: CategoryType.expense,
      icon: const CategoryIcon(key: 'groceries'),
      color: const CategoryColor(argb: 0xFFEF4444),
    );
    final pending = Transaction.create(
      id: 'cancel-edit-ui',
      accountId: cash.id,
      categoryId: category.id,
      amount: Money(amount: Decimal.parse('8'), currencyCode: 'LYD'),
      type: TransactionType.expense,
      status: TransactionStatus.pending,
    );
    final repository = _RecordingUpdateTransactionsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success(<Account>[cash]),
          ),
          categoriesByTypeProvider.overrideWith(
            (_, _) async =>
                AppResult<List<Category>>.success(<Category>[category]),
          ),
          payeesProvider.overrideWith(
            (_) =>
                Stream.value(const AppResult<List<Payee>>.success(<Payee>[])),
          ),
          updateTransactionUseCaseProvider.overrideWithValue(
            UpdateTransaction(repository),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: TransactionFormSheet(
              type: TransactionType.expense,
              existingTransaction: pending,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CPButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual transaction payee selector works at 320px in RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cash = _account(id: 'cash', name: 'نقدي', currencyCode: 'LYD');
    final groceries = Category.create(
      id: 'groceries',
      name: 'Groceries',
      type: CategoryType.expense,
      icon: const CategoryIcon(key: 'groceries'),
      color: const CategoryColor(argb: 0xFF16A34A),
    );
    final merchant = Payee.create(
      id: 'merchant',
      name: 'النوار',
      type: PayeeType.merchant,
      defaultAccountId: cash.id,
      defaultCategoryId: groceries.id,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (_) async => AppResult<List<Account>>.success(<Account>[cash]),
          ),
          categoriesByTypeProvider.overrideWith(
            (_, type) async =>
                AppResult<List<Category>>.success(<Category>[groceries]),
          ),
          payeesProvider.overrideWith(
            (_) =>
                Stream.value(AppResult<List<Payee>>.success(<Payee>[merchant])),
          ),
        ],
        child: _localizedApp(
          locale: const Locale('ar'),
          child: const Scaffold(
            body: TransactionFormSheet(type: TransactionType.expense),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بلا مستفيد'), findsOneWidget);
    await tester.tap(find.text('بلا مستفيد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النوار'));
    await tester.pumpAndSettle();

    expect(find.text('النوار'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _localizedApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: CPTheme.dark(),
    home: child,
  );
}

Account _account({
  required String id,
  required String name,
  required String currencyCode,
}) {
  return Account.create(
    id: id,
    name: name,
    type: AccountType.bank,
    currencyCode: currencyCode,
    balance: Decimal.parse('5000'),
    icon: 'bank',
    color: 0xFF4F46E5,
  );
}

final class _DelayedExchangeRateRepository implements ExchangeRateRepository {
  final Completer<AppResult<ExchangeRate?>> result =
      Completer<AppResult<ExchangeRate?>>();
  int calls = 0;

  @override
  Future<AppResult<ExchangeRate?>> getLatestRate(
    String fromCurrency,
    String toCurrency,
  ) {
    calls += 1;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingTransactionsRepository implements TransactionsRepository {
  final List<CreateTransferCommand> commands = <CreateTransferCommand>[];

  @override
  Future<AppResult<CreatedTransfer>> createTransfer(
    CreateTransferCommand command,
  ) async {
    commands.add(command);
    return const AppResult<CreatedTransfer>.failure(
      Failure(message: 'Expected UI test stop.'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingUpdateTransactionsRepository
    implements TransactionsRepository {
  final List<Transaction> calls = <Transaction>[];
  final Completer<AppResult<Transaction>> result =
      Completer<AppResult<Transaction>>();

  @override
  Future<AppResult<Transaction>> updateTransaction(
    Transaction transaction, {
    Transaction? expectedCurrent,
  }) {
    calls.add(transaction);
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
