import { z } from "zod";

const DecimalStringSchema = z
  .string()
  .trim()
  .min(1)
  .max(80)
  .regex(/^-?\d+(?:\.\d+)?$/u);
const BoundedCountSchema = z
  .number()
  .int()
  .min(0)
  .max(1_000_000_000);
const CurrencySchema = z.string().regex(/^[A-Z]{3}$/u);
const FinancialTokenSchema = z
  .string()
  .trim()
  .regex(/^[A-Za-z][A-Za-z0-9_-]{0,39}$/u);
const FinancialDateSchema = z
  .string()
  .trim()
  .max(40)
  .regex(/^\d{4}-\d{2}-\d{2}(?:[T ][0-9:.+\-Z]+)?$/u)
  .refine((value) => !Number.isNaN(Date.parse(value)));

const promptInjectionLabelPattern =
  /\b(?:assistant|developer|disregard|expose|ignore|instruction|jailbreak|prompt|reveal|system)\b|(?:ط§ط¸ظ‡ط±|ط§ظƒط´ظپ|ط§ظ„ظ†ط¸ط§ظ…|طھط¬ط§ظ‡ظ„|طھط¹ظ„ظٹظ…ط§طھ)/iu;

function sanitizeFinancialLabel(value: string): string {
  if (
    promptInjectionLabelPattern.test(value) ||
    /[\r\n{}<>]/u.test(value) ||
    value.includes("```")
  ) {
    return "[untrusted label]";
  }
  return value.replace(/\s+/gu, " ").trim();
}

const FinancialLabelSchema = z
  .string()
  .trim()
  .min(1)
  .max(80)
  .transform(sanitizeFinancialLabel);

const CategoryRecordSchema = z
  .object({
    category: FinancialLabelSchema.optional(),
    amount: DecimalStringSchema.optional(),
    currency: CurrencySchema.optional(),
  })
  .strict();
const BudgetRecordSchema = z
  .object({
    name: FinancialLabelSchema.optional(),
    spent: DecimalStringSchema.optional(),
    limit: DecimalStringSchema.optional(),
    remaining: DecimalStringSchema.optional(),
    currency: CurrencySchema.optional(),
    progressPercent: DecimalStringSchema.optional(),
    status: FinancialTokenSchema.optional(),
    partial: z.boolean().optional(),
  })
  .strict();
const SavedTotalRecordSchema = z
  .object({
    amount: DecimalStringSchema.optional(),
    currency: CurrencySchema.optional(),
  })
  .strict();
const GoalRecordSchema = z
  .object({
    title: FinancialLabelSchema.optional(),
    current: DecimalStringSchema.optional(),
    target: DecimalStringSchema.optional(),
    remaining: DecimalStringSchema.optional(),
    currency: CurrencySchema.optional(),
    progressPercent: DecimalStringSchema.optional(),
    daysRemaining: BoundedCountSchema.optional(),
    monthlyNeeded: DecimalStringSchema.optional(),
    status: FinancialTokenSchema.optional(),
  })
  .strict();
const AccountRecordSchema = z
  .object({
    name: FinancialLabelSchema.optional(),
    type: FinancialTokenSchema.optional(),
    balance: DecimalStringSchema.optional(),
    currency: CurrencySchema.optional(),
  })
  .strict();
const TransactionRecordSchema = z
  .object({
    date: FinancialDateSchema.optional(),
    type: FinancialTokenSchema.optional(),
    amount: DecimalStringSchema.optional(),
    currency: CurrencySchema.optional(),
    category: FinancialLabelSchema.optional(),
    account: FinancialLabelSchema.optional(),
    status: FinancialTokenSchema.optional(),
  })
  .strict();

const CategorySpendingValuesSchema = z
  .object({
    period: z.literal("current_month").optional(),
    categories: z.array(CategoryRecordSchema).max(20).optional(),
    partial: z.boolean().optional(),
  })
  .strict();
const GoalFeasibilityValuesSchema = z
  .object({
    monthsNeeded: BoundedCountSchema.optional(),
    feasibleWithinPeriod: z.boolean().optional(),
  })
  .strict();

function financialRecordSchema<
  const ToolId extends string,
  ValuesSchema extends z.ZodTypeAny,
>(toolId: ToolId, values: ValuesSchema) {
  return z
    .object({
      toolId: z.literal(toolId),
      partial: z.boolean(),
      values,
    })
    .strict();
}

export const SanitizedFinancialRecordSchema = z.discriminatedUnion("toolId", [
  financialRecordSchema(
    "get_dashboard_summary",
    z
      .object({
        currency: CurrencySchema.optional(),
        monthlyIncome: DecimalStringSchema.optional(),
        monthlyExpense: DecimalStringSchema.optional(),
        monthlySavings: DecimalStringSchema.optional(),
        netWorth: DecimalStringSchema.optional(),
        accountCount: BoundedCountSchema.optional(),
        partial: z.boolean().optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "get_monthly_comparison",
    z
      .object({
        currency: CurrencySchema.optional(),
        currentExpense: DecimalStringSchema.optional(),
        previousExpense: DecimalStringSchema.optional(),
        expenseChangePercent: DecimalStringSchema.optional(),
        partial: z.boolean().optional(),
      })
      .strict(),
  ),
  financialRecordSchema("get_category_spending", CategorySpendingValuesSchema),
  financialRecordSchema(
    "get_top_spending_categories",
    CategorySpendingValuesSchema,
  ),
  financialRecordSchema(
    "get_budget_summary",
    z
      .object({
        activeCount: BoundedCountSchema.optional(),
        warningCount: BoundedCountSchema.optional(),
        exceededCount: BoundedCountSchema.optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "get_budget_progress",
    z.object({ budgets: z.array(BudgetRecordSchema).max(20).optional() }).strict(),
  ),
  financialRecordSchema(
    "get_goal_summary",
    z
      .object({
        activeCount: BoundedCountSchema.optional(),
        completedCount: BoundedCountSchema.optional(),
        savedTotals: z.array(SavedTotalRecordSchema).max(20).optional(),
        nearestTargetDate: FinancialDateSchema.optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "get_goal_progress",
    z.object({ goals: z.array(GoalRecordSchema).max(20).optional() }).strict(),
  ),
  financialRecordSchema(
    "get_cash_flow_trend",
    z
      .object({
        hasData: z.boolean().optional(),
        currentNet: DecimalStringSchema.optional(),
        previousNet: DecimalStringSchema.optional(),
        currency: CurrencySchema.optional(),
        partial: z.boolean().optional(),
        sixMonthExpenseTrend: z
          .array(DecimalStringSchema)
          .max(20)
          .optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "get_recurring_transactions",
    z
      .object({
        detectedPatternCount: BoundedCountSchema.optional(),
        periodStart: FinancialDateSchema.optional(),
        periodEnd: FinancialDateSchema.optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "get_income_expense_breakdown",
    z
      .object({
        period: z.enum(["current_month", "year"]).optional(),
        income: DecimalStringSchema.optional(),
        expense: DecimalStringSchema.optional(),
        currency: CurrencySchema.optional(),
        partial: z.boolean().optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "get_net_worth",
    z
      .object({
        amount: DecimalStringSchema.optional(),
        currency: CurrencySchema.optional(),
        partial: z.boolean().optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "get_accounts_summary",
    z
      .object({ accounts: z.array(AccountRecordSchema).max(20).optional() })
      .strict(),
  ),
  financialRecordSchema(
    "get_exchange_rate",
    z
      .object({
        from: CurrencySchema.optional(),
        to: CurrencySchema.optional(),
        rate: DecimalStringSchema.optional(),
        asOf: FinancialDateSchema.optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "search_transactions",
    z
      .object({
        transactions: z.array(TransactionRecordSchema).max(20).optional(),
        resultCount: BoundedCountSchema.optional(),
        bounded: z.boolean().optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "calculate_savings_rate",
    z
      .object({
        savings: DecimalStringSchema.optional(),
        savingsRatePercent: DecimalStringSchema.optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "project_month_end",
    z.object({ projectedAmount: DecimalStringSchema.optional() }).strict(),
  ),
  financialRecordSchema(
    "simulate_budget_change",
    z.object({ remaining: DecimalStringSchema.optional() }).strict(),
  ),
  financialRecordSchema(
    "calculate_goal_feasibility",
    GoalFeasibilityValuesSchema,
  ),
  financialRecordSchema("forecast_goal_completion", GoalFeasibilityValuesSchema),
  financialRecordSchema(
    "calculate_safe_allowance",
    z.object({ safeAllowance: DecimalStringSchema.optional() }).strict(),
  ),
  financialRecordSchema(
    "simulate_income_change",
    z.object({ projectedCashFlow: DecimalStringSchema.optional() }).strict(),
  ),
  financialRecordSchema(
    "compare_scenarios",
    z
      .object({
        difference: DecimalStringSchema.optional(),
        betterScenario: z.enum(["A", "B", "equal"]).optional(),
      })
      .strict(),
  ),
  financialRecordSchema(
    "convert_currency_amount",
    z
      .object({
        amount: DecimalStringSchema.optional(),
        from: CurrencySchema.optional(),
        to: CurrencySchema.optional(),
      })
      .strict(),
  ),
]);

const partialFinancialAssumption =
  "Some deterministic CashPilot values are partial because local conversion data is incomplete.";

export const SanitizedFinancialContextSchema = z
  .object({
    currency: CurrencySchema,
    records: z.array(SanitizedFinancialRecordSchema).min(1).max(12),
    assumptions: z.array(z.literal(partialFinancialAssumption)).max(1),
  })
  .strict();
export type SanitizedFinancialContext = z.infer<
  typeof SanitizedFinancialContextSchema
>;
