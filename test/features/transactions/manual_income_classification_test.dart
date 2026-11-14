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
import 'package:cashpilot_ai/features/income_sources/domain/enums/income_source_type.dart';
import 'package:cashpilot_ai/features/payees/application/providers/payees_providers.dart';
import 'package:cashpilot_ai/features/payees/domain/entities/payee.dart';
import 'package:cashpilot_ai/features/payees/domain/repositories/payees_repository.dart';
import 'package:cashpilot_ai/features/payees/domain/usecases/touch_payee_last_used.dart';
import 'package:cashpilot_ai/features/transactions/application/providers/transactions_providers.dart';
import 'package:cashpilot_ai/features/transactions/application/services/create_transaction_with_payee_usage.dart';
import 'package:cashpilot_ai/features/transactions/domain/entities/transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:cashpilot_ai/features/transactions/domain/usecases/create_transaction.dart';
import 'package:cashpilot_ai/features/transactions/domain/enums/transaction_type.dart';
import 'package:cashpilot_ai/features/transactions/presentation/widgets/transaction_form_sheet.dart';
import 'package:cashpilot_ai/l10n/app_localizations.dart';
import 'package:cashpilot_ai/shared/design_system/design_system.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OF-024 manual income classification', () {
    for (final sourceType in IncomeSourceType.values) {
      testWidgets('persists explicit ${sourceType.name} classification', (
        tester,
      ) async {
        final repository = _RecordingTransactionsRepository();
        await _pumpIncomeForm(tester, repository);

        await tester.enterText(find.byType(TextFormField).first, '10');
        await tester.tap(
          find.byKey(const Key('manual_income_source_type_selector')),
        );
        await tester.pumpAndSettle();
        final label = _incomeSourceLabel(sourceType);
        final choice = find.text(label).last;
        await tester.scrollUntilVisible(
          choice,
          120,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(choice);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(CPButton, 'Save');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(repository.created, hasLength(1));
        expect(repository.created.single.incomeSourceType, sourceType);
      });
    }

    testWidgets('null classification cannot submit manual income', (
      tester,
    ) async {
      final repository = _RecordingTransactionsRepository();
      await _pumpIncomeForm(tester, repository);

      await tester.enterText(find.byType(TextFormField).first, '10');
      final save = find.widgetWithText(CPButton, 'Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();

      expect(repository.created, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Income source type'), findsWidgets);
    });
  });
}

Future<void> _pumpIncomeForm(
  WidgetTester tester,
  _RecordingTransactionsRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final account = Account.create(
    id: 'income-account',
    name: 'Income account',
    type: AccountType.bank,
    currencyCode: 'LYD',
    balance: Decimal.zero,
    icon: 'bank',
    color: 0xFF006C67,
  );
  final category = Category.create(
    id: 'income-category',
    name: 'Income',
    type: CategoryType.income,
    icon: const CategoryIcon(key: 'income'),
    color: const CategoryColor(argb: 0xFF006C67),
  );
  final create = CreateTransactionWithPayeeUsage(
    createTransaction: CreateTransaction(repository),
    touchPayeeLastUsed: TouchPayeeLastUsed(_UnusedPayeesRepository()),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountsProvider.overrideWith(
          (_) async => AppResult<List<Account>>.success(<Account>[account]),
        ),
        categoriesByTypeProvider.overrideWith(
          (_, _) async =>
              AppResult<List<Category>>.success(<Category>[category]),
        ),
        payeesProvider.overrideWith(
          (_) => Stream.value(const AppResult<List<Payee>>.success(<Payee>[])),
        ),
        createTransactionWithPayeeUsageProvider.overrideWithValue(create),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CPTheme.dark(),
        home: const Scaffold(
          body: TransactionFormSheet(type: TransactionType.income),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _incomeSourceLabel(IncomeSourceType sourceType) {
  return switch (sourceType) {
    IncomeSourceType.salary => 'Salary',
    IncomeSourceType.freelance => 'Freelance',
    IncomeSourceType.businessRevenue => 'Business revenue',
    IncomeSourceType.gift => 'Gift',
    IncomeSourceType.allowance => 'Allowance',
    IncomeSourceType.refund => 'Refund',
    IncomeSourceType.sale => 'Sale proceeds',
    IncomeSourceType.rentalIncome => 'Rental income',
    IncomeSourceType.governmentSupport => 'Government support',
    IncomeSourceType.scholarship => 'Scholarship',
    IncomeSourceType.investmentReturn => 'Investment return',
    IncomeSourceType.reimbursement => 'Reimbursement',
    IncomeSourceType.debtRepayment => 'Debt repayment',
    IncomeSourceType.prize => 'Prize',
    IncomeSourceType.loanProceeds => 'Loan proceeds',
    IncomeSourceType.externalTransfer => 'External transfer',
    IncomeSourceType.other => 'Other',
  };
}

final class _RecordingTransactionsRepository implements TransactionsRepository {
  final List<Transaction> created = <Transaction>[];

  @override
  Future<AppResult<Transaction>> createTransaction(
    Transaction transaction,
  ) async {
    created.add(transaction);
    return const AppResult<Transaction>.failure(
      Failure(message: 'Expected UI test stop.'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedPayeesRepository implements PayeesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
