import { z } from "zod";

type ProviderJsonSchema = Record<string, unknown>;

interface ToolArgumentField {
  readonly validation: z.ZodTypeAny;
  readonly providerSchema: ProviderJsonSchema;
}

interface ToolDefinition {
  readonly arguments: z.ZodObject<z.ZodRawShape>;
  readonly providerSchema: ProviderJsonSchema;
}

function nullable(schema: ProviderJsonSchema): ProviderJsonSchema {
  return { anyOf: [schema, { type: "null" }] };
}

function objectSchema(
  properties: Record<string, unknown>,
): ProviderJsonSchema {
  return {
    type: "object",
    properties,
    required: Object.keys(properties),
    additionalProperties: false,
  };
}

function requiredField(
  validation: z.ZodTypeAny,
  providerSchema: ProviderJsonSchema,
): ToolArgumentField {
  return { validation, providerSchema };
}

function optionalField(field: ToolArgumentField): ToolArgumentField {
  return {
    validation: field.validation.optional(),
    providerSchema: nullable(field.providerSchema),
  };
}

function integerField(minimum: number, maximum: number): ToolArgumentField {
  return requiredField(
    z.number().int().min(minimum).max(maximum),
    { type: "integer", minimum, maximum },
  );
}

function trimmedStringField(
  minLength: number,
  maxLength: number,
): ToolArgumentField {
  return requiredField(
    z.string().trim().min(minLength).max(maxLength),
    { type: "string", minLength, maxLength },
  );
}

function patternStringField(
  pattern: string,
  maxLength?: number,
): ToolArgumentField {
  const validation = z.string().regex(new RegExp(pattern));
  return requiredField(
    maxLength === undefined ? validation : validation.max(maxLength),
    {
      type: "string",
      pattern,
      ...(maxLength === undefined ? {} : { maxLength }),
    },
  );
}

function enumField<const Values extends readonly [string, ...string[]]>(
  values: Values,
): ToolArgumentField {
  return requiredField(z.enum(values), { type: "string", enum: [...values] });
}

function defineTool(
  fields: Readonly<Record<string, ToolArgumentField>>,
): ToolDefinition {
  const validationShape = Object.fromEntries(
    Object.entries(fields).map(([name, field]) => [name, field.validation]),
  ) as z.ZodRawShape;
  const providerProperties = Object.fromEntries(
    Object.entries(fields).map(([name, field]) => [
      name,
      field.providerSchema,
    ]),
  );
  return {
    arguments: z.object(validationShape).strict(),
    providerSchema: objectSchema(providerProperties),
  };
}

const noArguments = defineTool({});
const limit = integerField(1, 20);
const period = enumField([
  "current_month",
  "previous_month",
  "year",
]);
const decimalString = patternStringField(
  "^-?(?:0|[1-9]\\d*)(?:\\.\\d{1,8})?$",
  40,
);
const currency = patternStringField("^[A-Z]{3}$");

export const serverToolDefinitions = {
  get_dashboard_summary: noArguments,
  get_monthly_comparison: noArguments,
  get_category_spending: defineTool({
    category: trimmedStringField(1, 80),
    period: optionalField(period),
    limit: optionalField(limit),
  }),
  get_top_spending_categories: defineTool({
    period: optionalField(period),
    limit: optionalField(limit),
  }),
  get_budget_summary: noArguments,
  get_budget_progress: defineTool({ limit: optionalField(limit) }),
  get_goal_summary: noArguments,
  get_goal_progress: defineTool({ limit: optionalField(limit) }),
  get_cash_flow_trend: noArguments,
  get_recurring_transactions: defineTool({ limit: optionalField(limit) }),
  get_income_expense_breakdown: defineTool({
    period: optionalField(period),
  }),
  get_net_worth: noArguments,
  get_accounts_summary: defineTool({ limit: optionalField(limit) }),
  get_exchange_rate: defineTool({ from: currency, to: currency }),
  search_transactions: defineTool({
    query: trimmedStringField(1, 120),
    limit: optionalField(limit),
  }),
  get_base_currency: noArguments,
  get_agent_capabilities: noArguments,
  calculate_savings_rate: defineTool({
    income: decimalString,
    expense: decimalString,
  }),
  project_month_end: defineTool({
    spentToDate: decimalString,
    elapsedDays: integerField(1, 31),
    daysInMonth: integerField(28, 31),
  }),
  simulate_budget_change: defineTool({
    currentSpending: decimalString,
    proposedBudget: decimalString,
  }),
  calculate_goal_feasibility: defineTool({
    remaining: decimalString,
    monthlyContribution: decimalString,
    monthsAvailable: optionalField(integerField(1, 600)),
  }),
  forecast_goal_completion: defineTool({
    remaining: decimalString,
    monthlyContribution: decimalString,
  }),
  calculate_safe_allowance: defineTool({
    income: decimalString,
    fixedCosts: decimalString,
    plannedSavings: optionalField(decimalString),
  }),
  simulate_income_change: defineTool({
    income: decimalString,
    expense: decimalString,
    incomeChange: decimalString,
  }),
  compare_scenarios: defineTool({
    scenarioA: decimalString,
    scenarioB: decimalString,
  }),
  convert_currency_amount: defineTool({
    amount: decimalString,
    rate: decimalString,
    from: currency,
    to: currency,
  }),
} as const satisfies Record<string, ToolDefinition>;

export type ServerToolId = keyof typeof serverToolDefinitions;

export const serverToolAllowlist = Object.fromEntries(
  Object.entries(serverToolDefinitions).map(([id, definition]) => [
    id,
    definition.arguments,
  ]),
) as {
  readonly [Id in ServerToolId]:
    (typeof serverToolDefinitions)[Id]["arguments"];
};

export function toolArgumentJsonSchema(
  id: ServerToolId,
): ProviderJsonSchema {
  return serverToolDefinitions[id].providerSchema;
}
