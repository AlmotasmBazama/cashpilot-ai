import 'package:flutter/material.dart';

import '../tokens/cp_colors.dart';

@immutable
class CPSemanticColors extends ThemeExtension<CPSemanticColors> {
  const CPSemanticColors({
    required this.income,
    required this.onIncome,
    required this.incomeContainer,
    required this.onIncomeContainer,
    required this.expense,
    required this.onExpense,
    required this.expenseContainer,
    required this.onExpenseContainer,
    required this.transfer,
    required this.onTransfer,
    required this.transferContainer,
    required this.onTransferContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.savings,
    required this.onSavings,
    required this.savingsContainer,
    required this.onSavingsContainer,
    required this.goals,
    required this.onGoals,
    required this.goalsContainer,
    required this.onGoalsContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.ai,
    required this.onAi,
    required this.aiContainer,
    required this.onAiContainer,
    required this.insight,
    required this.onInsight,
    required this.insightContainer,
    required this.onInsightContainer,
  });

  final Color income;
  final Color onIncome;
  final Color incomeContainer;
  final Color onIncomeContainer;
  final Color expense;
  final Color onExpense;
  final Color expenseContainer;
  final Color onExpenseContainer;
  final Color transfer;
  final Color onTransfer;
  final Color transferContainer;
  final Color onTransferContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color savings;
  final Color onSavings;
  final Color savingsContainer;
  final Color onSavingsContainer;
  final Color goals;
  final Color onGoals;
  final Color goalsContainer;
  final Color onGoalsContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color ai;
  final Color onAi;
  final Color aiContainer;
  final Color onAiContainer;
  final Color insight;
  final Color onInsight;
  final Color insightContainer;
  final Color onInsightContainer;

  static CPSemanticColors light() {
    return const CPSemanticColors(
      income: CPColors.income,
      onIncome: Colors.white,
      incomeContainer: Color(0xFFDCFCE7),
      onIncomeContainer: Color(0xFF14532D),
      expense: CPColors.expense,
      onExpense: Colors.white,
      expenseContainer: Color(0xFFFEE2E2),
      onExpenseContainer: Color(0xFF7F1D1D),
      transfer: CPColors.transfer,
      onTransfer: Colors.white,
      transferContainer: Color(0xFFDBEAFE),
      onTransferContainer: Color(0xFF1E3A8A),
      warning: CPColors.warning,
      onWarning: Color(0xFF451A03),
      warningContainer: Color(0xFFFEF3C7),
      onWarningContainer: Color(0xFF78350F),
      success: CPColors.success,
      onSuccess: Colors.white,
      successContainer: Color(0xFFDCFCE7),
      onSuccessContainer: Color(0xFF14532D),
      savings: CPColors.savings,
      onSavings: Colors.white,
      savingsContainer: Color(0xFFE0E7FF),
      onSavingsContainer: Color(0xFF312E81),
      goals: CPColors.goals,
      onGoals: Colors.white,
      goalsContainer: Color(0xFFFCE7F3),
      onGoalsContainer: Color(0xFF831843),
      info: CPColors.info,
      onInfo: Colors.white,
      infoContainer: Color(0xFFDBEAFE),
      onInfoContainer: Color(0xFF1E3A8A),
      ai: CPColors.ai,
      onAi: Colors.white,
      aiContainer: Color(0xFFEDE9FE),
      onAiContainer: Color(0xFF4C1D95),
      insight: CPColors.ai,
      onInsight: Colors.white,
      insightContainer: Color(0xFFEDE9FE),
      onInsightContainer: Color(0xFF4C1D95),
    );
  }

  static CPSemanticColors dark() {
    return const CPSemanticColors(
      income: CPColors.income,
      onIncome: Color(0xFF052E16),
      incomeContainer: Color(0xFF123C24),
      onIncomeContainer: Color(0xFFBBF7D0),
      expense: CPColors.expense,
      onExpense: Color(0xFF450A0A),
      expenseContainer: Color(0xFF4B1D25),
      onExpenseContainer: Color(0xFFFECACA),
      transfer: CPColors.transfer,
      onTransfer: Color(0xFF0B1F45),
      transferContainer: Color(0xFF152A4F),
      onTransferContainer: Color(0xFFBFDBFE),
      warning: CPColors.warning,
      onWarning: Color(0xFF451A03),
      warningContainer: Color(0xFF3B2B15),
      onWarningContainer: Color(0xFFFDE68A),
      success: CPColors.success,
      onSuccess: Color(0xFF052E16),
      successContainer: Color(0xFF123C24),
      onSuccessContainer: Color(0xFFBBF7D0),
      savings: CPColors.savings,
      onSavings: Colors.white,
      savingsContainer: Color(0xFF242454),
      onSavingsContainer: Color(0xFFC7D2FE),
      goals: CPColors.goals,
      onGoals: Color(0xFF500724),
      goalsContainer: Color(0xFF3A1E33),
      onGoalsContainer: Color(0xFFFBCFE8),
      info: CPColors.info,
      onInfo: Color(0xFF0B1F45),
      infoContainer: Color(0xFF152A4F),
      onInfoContainer: Color(0xFFBFDBFE),
      ai: CPColors.ai,
      onAi: Colors.white,
      aiContainer: Color(0xFF2A1B4A),
      onAiContainer: Color(0xFFDDD6FE),
      insight: CPColors.ai,
      onInsight: Colors.white,
      insightContainer: Color(0xFF2A1B4A),
      onInsightContainer: Color(0xFFDDD6FE),
    );
  }

  @override
  CPSemanticColors copyWith({
    Color? income,
    Color? onIncome,
    Color? incomeContainer,
    Color? onIncomeContainer,
    Color? expense,
    Color? onExpense,
    Color? expenseContainer,
    Color? onExpenseContainer,
    Color? transfer,
    Color? onTransfer,
    Color? transferContainer,
    Color? onTransferContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? savings,
    Color? onSavings,
    Color? savingsContainer,
    Color? onSavingsContainer,
    Color? goals,
    Color? onGoals,
    Color? goalsContainer,
    Color? onGoalsContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? ai,
    Color? onAi,
    Color? aiContainer,
    Color? onAiContainer,
    Color? insight,
    Color? onInsight,
    Color? insightContainer,
    Color? onInsightContainer,
  }) {
    return CPSemanticColors(
      income: income ?? this.income,
      onIncome: onIncome ?? this.onIncome,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      onIncomeContainer: onIncomeContainer ?? this.onIncomeContainer,
      expense: expense ?? this.expense,
      onExpense: onExpense ?? this.onExpense,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      onExpenseContainer: onExpenseContainer ?? this.onExpenseContainer,
      transfer: transfer ?? this.transfer,
      onTransfer: onTransfer ?? this.onTransfer,
      transferContainer: transferContainer ?? this.transferContainer,
      onTransferContainer: onTransferContainer ?? this.onTransferContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      savings: savings ?? this.savings,
      onSavings: onSavings ?? this.onSavings,
      savingsContainer: savingsContainer ?? this.savingsContainer,
      onSavingsContainer: onSavingsContainer ?? this.onSavingsContainer,
      goals: goals ?? this.goals,
      onGoals: onGoals ?? this.onGoals,
      goalsContainer: goalsContainer ?? this.goalsContainer,
      onGoalsContainer: onGoalsContainer ?? this.onGoalsContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      ai: ai ?? this.ai,
      onAi: onAi ?? this.onAi,
      aiContainer: aiContainer ?? this.aiContainer,
      onAiContainer: onAiContainer ?? this.onAiContainer,
      insight: insight ?? this.insight,
      onInsight: onInsight ?? this.onInsight,
      insightContainer: insightContainer ?? this.insightContainer,
      onInsightContainer: onInsightContainer ?? this.onInsightContainer,
    );
  }

  @override
  CPSemanticColors lerp(ThemeExtension<CPSemanticColors>? other, double t) {
    if (other is! CPSemanticColors) {
      return this;
    }

    return CPSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      onIncome: Color.lerp(onIncome, other.onIncome, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      onIncomeContainer: Color.lerp(
        onIncomeContainer,
        other.onIncomeContainer,
        t,
      )!,
      expense: Color.lerp(expense, other.expense, t)!,
      onExpense: Color.lerp(onExpense, other.onExpense, t)!,
      expenseContainer: Color.lerp(
        expenseContainer,
        other.expenseContainer,
        t,
      )!,
      onExpenseContainer: Color.lerp(
        onExpenseContainer,
        other.onExpenseContainer,
        t,
      )!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      onTransfer: Color.lerp(onTransfer, other.onTransfer, t)!,
      transferContainer: Color.lerp(
        transferContainer,
        other.transferContainer,
        t,
      )!,
      onTransferContainer: Color.lerp(
        onTransferContainer,
        other.onTransferContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      savings: Color.lerp(savings, other.savings, t)!,
      onSavings: Color.lerp(onSavings, other.onSavings, t)!,
      savingsContainer: Color.lerp(
        savingsContainer,
        other.savingsContainer,
        t,
      )!,
      onSavingsContainer: Color.lerp(
        onSavingsContainer,
        other.onSavingsContainer,
        t,
      )!,
      goals: Color.lerp(goals, other.goals, t)!,
      onGoals: Color.lerp(onGoals, other.onGoals, t)!,
      goalsContainer: Color.lerp(goalsContainer, other.goalsContainer, t)!,
      onGoalsContainer: Color.lerp(
        onGoalsContainer,
        other.onGoalsContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      ai: Color.lerp(ai, other.ai, t)!,
      onAi: Color.lerp(onAi, other.onAi, t)!,
      aiContainer: Color.lerp(aiContainer, other.aiContainer, t)!,
      onAiContainer: Color.lerp(onAiContainer, other.onAiContainer, t)!,
      insight: Color.lerp(insight, other.insight, t)!,
      onInsight: Color.lerp(onInsight, other.onInsight, t)!,
      insightContainer: Color.lerp(
        insightContainer,
        other.insightContainer,
        t,
      )!,
      onInsightContainer: Color.lerp(
        onInsightContainer,
        other.onInsightContainer,
        t,
      )!,
    );
  }
}

extension CPSemanticColorsBuildContext on BuildContext {
  CPSemanticColors get cpColors {
    return Theme.of(this).extension<CPSemanticColors>()!;
  }
}
