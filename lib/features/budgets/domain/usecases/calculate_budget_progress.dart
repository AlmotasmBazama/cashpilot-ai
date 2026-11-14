import '../../../transactions/domain/entities/transaction.dart';
import '../entities/budget.dart';
import '../entities/budget_progress.dart';
import '../services/budget_progress_calculator.dart';

class CalculateBudgetProgress {
  const CalculateBudgetProgress({
    required BudgetProgressCalculator calculator,
    required BudgetMoneyConverter convertMoney,
  }) : _calculator = calculator,
       _convertMoney = convertMoney;

  final BudgetProgressCalculator _calculator;
  final BudgetMoneyConverter _convertMoney;

  Future<BudgetProgress> call({
    required Budget budget,
    required List<Transaction> transactions,
    required DateTime now,
  }) => _calculator.calculate(
    budget: budget,
    transactions: transactions,
    now: now,
    convertMoney: _convertMoney,
  );
}
