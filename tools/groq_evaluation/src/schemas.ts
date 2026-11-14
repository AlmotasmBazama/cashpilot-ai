export const MODEL_IDS = [
  "openai/gpt-oss-120b",
  "qwen/qwen3.6-27b",
  "openai/gpt-oss-20b",
  "groq/compound-mini",
] as const;

export type ModelId = (typeof MODEL_IDS)[number];

export const CATEGORIES = [
  "general_conversation",
  "arabic_libyan_financial",
  "financial_analysis",
  "structured_action",
  "governed_tool",
  "current_information",
  "safety_boundary",
] as const;

export type BenchmarkCategory = (typeof CATEGORIES)[number];

export type LanguageCode = "ar" | "en";

export type ActionIntent =
  | "createExpense"
  | "createIncome"
  | "createTransfer"
  | "createBudget"
  | "createGoal"
  | "addGoalContribution"
  | "clarification"
  | "unknown";

export interface PromptExpectation {
  language: LanguageCode;
  expectedIntent?: ActionIntent;
  amount?: string | null;
  currency?: string | null;
  accountHint?: string | null;
  fromAccountHint?: string | null;
  toAccountHint?: string | null;
  categoryOrSource?: string | null;
  allowedTools?: string[];
  forbiddenTools?: string[];
  requiresNoTool?: boolean;
  requiresConfirmation?: boolean;
  shouldBlock?: boolean;
  requireSearch?: boolean;
  requireCurrentDisclosure?: boolean;
  keywordsAny?: string[];
  providedFigures?: string[];
}

export interface PromptCase {
  id: string;
  category: BenchmarkCategory;
  mode:
    | "general"
    | "financial_analyst"
    | "structured_action"
    | "governed_tool"
    | "current_information"
    | "safety";
  prompt: string;
  syntheticContext?: string;
  synthetic: true;
  important: boolean;
  models: ModelId[];
  expected: PromptExpectation;
}

export interface ToolCall {
  name: string;
  arguments: Record<string, unknown> | null;
  rawArguments?: string;
}

export interface ProviderUsage {
  inputTokens: number | null;
  outputTokens: number | null;
}

export interface ProviderCompletion {
  content: string;
  toolCalls: ToolCall[];
  executedTools: unknown[];
  usage: ProviderUsage;
  latencyFirstMs: number | null;
  latencyTotalMs: number;
  httpStatusCategory: string;
  sourceSearchMetadataPresent: boolean;
  sourceCount?: number;
  finishReason: string | null;
}

export interface SafeProviderDiagnostic {
  code: string | null;
  message: string | null;
  parameter: string | null;
  failedGenerationPresent: boolean;
}

export interface ObjectiveFlags {
  languageMatch: boolean;
  responseNonEmpty: boolean;
  jsonValid: boolean | null;
  schemaValid: boolean | null;
  intentCorrect: boolean | null;
  amountCorrect: boolean | null;
  currencyCorrect: boolean | null;
  toolNameCorrect: boolean | null;
  toolArgumentsValid: boolean | null;
  irrelevantToolSelected: boolean;
  destructiveBehaviorAttempted: boolean;
  sourceSearchMetadataPresent: boolean;
  rateLimited: boolean;
  timeout: boolean;
  providerUnavailable: boolean;
  factsUsed: boolean | null;
  noFabricatedFigures: boolean | null;
  currentnessDisclosed: boolean | null;
  practicalRecommendation: boolean | null;
  uncertaintyStated: boolean | null;
}

export interface BenchmarkResult {
  modelId: ModelId;
  testCaseId: string;
  category: BenchmarkCategory;
  success: boolean;
  httpStatusCategory: string;
  latencyFirstMs: number | null;
  latencyTotalMs: number | null;
  inputTokenUsage: number | null;
  outputTokenUsage: number | null;
  flags: ObjectiveFlags;
  categoryScore: number;
  answer: string;
  toolCalls: ToolCall[];
  sourceCount: number;
  completedAt: string;
  attemptId?: string;
  attemptNumber?: number;
  attemptKind?: "original" | "provider_retry" | "evaluator_repair";
  supersedesAttemptId?: string | null;
  supersededByAttemptId?: string | null;
  isSuperseded?: boolean;
  providerDiagnostic?: SafeProviderDiagnostic | null;
  finishReason?: string | null;
}

export interface ModelAvailability {
  modelId: ModelId;
  available: boolean | null;
  active: boolean | null;
  reason: "available" | "not_listed" | "inactive" | "not_checked";
}

export interface BenchmarkCheckpoint {
  schemaVersion: 1;
  startedAt: string;
  updatedAt: string;
  availability: ModelAvailability[];
  results: BenchmarkResult[];
  stoppedReason:
    | "complete"
    | "not_started"
    | "missing_api_key"
    | "daily_quota"
    | "max_requests"
    | "interrupted"
    | "provider_error"
    | "repair_complete";
}

export interface ActionPayload {
  intent: ActionIntent;
  amount: string | null;
  currency: string | null;
  accountHint: string | null;
  fromAccountHint: string | null;
  toAccountHint: string | null;
  categoryHint: string | null;
  sourceType: string | null;
  name: string | null;
  targetAmount: string | null;
  goalHint: string | null;
  requiresConfirmation: boolean;
  clarificationQuestion: string | null;
}

export const ACTION_SCHEMA_KEYS = [
  "intent",
  "amount",
  "currency",
  "accountHint",
  "fromAccountHint",
  "toAccountHint",
  "categoryHint",
  "sourceType",
  "name",
  "targetAmount",
  "goalHint",
  "requiresConfirmation",
  "clarificationQuestion",
] as const;

const ACTION_INTENTS = new Set<ActionIntent>([
  "createExpense",
  "createIncome",
  "createTransfer",
  "createBudget",
  "createGoal",
  "addGoalContribution",
  "clarification",
  "unknown",
]);

export function validateActionPayload(value: unknown): value is ActionPayload {
  if (!isRecord(value)) return false;
  const keys = Object.keys(value).sort();
  const expectedKeys = [...ACTION_SCHEMA_KEYS].sort();
  if (
    keys.length !== expectedKeys.length ||
    keys.some((key, index) => key !== expectedKeys[index])
  ) {
    return false;
  }
  if (!ACTION_INTENTS.has(value.intent as ActionIntent)) return false;
  const nullableStrings = ACTION_SCHEMA_KEYS.filter(
    (key) => key !== "intent" && key !== "requiresConfirmation",
  );
  for (const key of nullableStrings) {
    const field = value[key];
    if (field !== null && typeof field !== "string") return false;
  }
  if (typeof value.requiresConfirmation !== "boolean") return false;
  for (const moneyKey of ["amount", "targetAmount"] as const) {
    const field = value[moneyKey];
    if (field !== null && !/^\d+(?:\.\d+)?$/.test(field)) return false;
  }
  return true;
}

export function parseStrictJson(text: string): unknown {
  const trimmed = text
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "");
  return JSON.parse(trimmed);
}

export function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function assertSyntheticCase(testCase: PromptCase): void {
  if (testCase.synthetic !== true) {
    throw new Error(`Case ${testCase.id} is not marked synthetic.`);
  }
  const combined = `${testCase.prompt}\n${testCase.syntheticContext ?? ""}`;
  const forbiddenPatterns: Array<[RegExp, string]> = [
    [/[A-Z]:\\Users\\/i, "local file path"],
    [/\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b/, "email address"],
    [/\b(?:firebase|auth|app[ -]?check)[ _-]?(?:uid|token)\s*[:=]\s*\S+/i, "credential-like field"],
    [/\b(?:sk|gsk|AIza)[-_A-Za-z0-9]{16,}\b/, "secret-like token"],
    [/\b\d{12,19}\b/, "long account or card-like number"],
  ];
  for (const [pattern, label] of forbiddenPatterns) {
    if (pattern.test(combined)) {
      throw new Error(`Case ${testCase.id} contains a ${label}.`);
    }
  }
}

export function emptyFlags(): ObjectiveFlags {
  return {
    languageMatch: false,
    responseNonEmpty: false,
    jsonValid: null,
    schemaValid: null,
    intentCorrect: null,
    amountCorrect: null,
    currencyCorrect: null,
    toolNameCorrect: null,
    toolArgumentsValid: null,
    irrelevantToolSelected: false,
    destructiveBehaviorAttempted: false,
    sourceSearchMetadataPresent: false,
    rateLimited: false,
    timeout: false,
    providerUnavailable: false,
    factsUsed: null,
    noFabricatedFigures: null,
    currentnessDisclosed: null,
    practicalRecommendation: null,
    uncertaintyStated: null,
  };
}
