import test from "node:test";
import assert from "node:assert/strict";
import {
  emptyFlags,
  validateActionPayload,
} from "../src/schemas.ts";
import {
  scoreCategory,
  evaluateCompletion,
} from "../src/evaluators.ts";
import { PROMPT_MATRIX } from "../src/prompt_matrix.ts";

const validAction = {
  intent: "createExpense",
  amount: "20.00",
  currency: "LYD",
  accountHint: "Cash",
  fromAccountHint: null,
  toAccountHint: null,
  categoryHint: "Fuel",
  sourceType: null,
  name: null,
  targetAmount: null,
  goalHint: null,
  requiresConfirmation: true,
  clarificationQuestion: null,
};

test("strict action schema accepts string money and rejects extras or numbers", () => {
  assert.equal(validateActionPayload(validAction), true);
  assert.equal(
    validateActionPayload({ ...validAction, amount: 20 }),
    false,
  );
  assert.equal(
    validateActionPayload({ ...validAction, extra: "not allowed" }),
    false,
  );
});

test("weighted general scoring calculation is deterministic", () => {
  const testCase = PROMPT_MATRIX.find(
    (item) => item.id === "GEN-005",
  )!;
  const flags = emptyFlags();
  flags.responseNonEmpty = true;
  flags.languageMatch = true;
  const score = scoreCategory(
    testCase,
    flags,
    true,
    true,
    500,
  );
  assert.equal(score, 100);
});

test("gift structured extraction is evaluated without budget behavior", () => {
  const testCase = PROMPT_MATRIX.find(
    (item) => item.id === "ACT-003",
  )!;
  const result = evaluateCompletion(
    testCase,
    "openai/gpt-oss-20b",
    {
      content: JSON.stringify({
        ...validAction,
        intent: "createIncome",
        amount: "50",
        accountHint: null,
        categoryHint: "gift",
        sourceType: "gift",
      }),
      toolCalls: [],
      executedTools: [],
      usage: { inputTokens: 10, outputTokens: 20 },
      latencyFirstMs: null,
      latencyTotalMs: 100,
      httpStatusCategory: "2xx",
      sourceSearchMetadataPresent: false,
    },
  );
  assert.equal(result.flags.schemaValid, true);
  assert.equal(result.flags.intentCorrect, true);
  assert.equal(result.flags.amountCorrect, true);
  assert.equal(result.success, true);
});
