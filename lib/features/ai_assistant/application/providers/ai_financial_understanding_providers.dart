import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/application/providers/accounts_providers.dart';
import '../../../budgets/application/providers/budgets_providers.dart';
import '../../../categories/application/providers/categories_providers.dart';
import '../../../exchange_rates/application/providers/exchange_rates_providers.dart';
import '../../../goals/application/providers/goals_providers.dart';
import '../../../payees/application/providers/payees_providers.dart';
import '../../../exchange_rates/application/base_currency_provider.dart';
import '../services/ai_financial_understanding_coordinator.dart';

final aiFinancialUnderstandingCoordinatorProvider =
    Provider<AiFinancialUnderstandingCoordinator>(
      (ref) => AiFinancialUnderstandingCoordinator(
        readBaseCurrencyCode: () => ref.read(effectiveBaseCurrencyCodeProvider),
        loadAccounts: () => ref.read(accountsProvider.future),
        loadCategories: () => ref.read(categoriesProvider.future),
        loadPayees: () => ref.read(payeesProvider.future),
        loadExchangeRates: () => ref.read(exchangeRatesProvider.future),
        loadBudgetProgress: () => ref.read(budgetProgressProvider.future),
        loadGoals: () => ref.read(allGoalsProvider.future),
        loadGoalProgress: () => ref.read(allGoalProgressProvider.future),
      ),
      name: 'aiFinancialUnderstandingCoordinatorProvider',
    );
