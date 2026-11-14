import test from "node:test";
import assert from "node:assert/strict";
import {
  PROMPT_COUNTS,
  PROMPT_MATRIX,
} from "../src/prompt_matrix.ts";
import {
  assertSyntheticCase,
  type PromptCase,
} from "../src/schemas.ts";

test("prepares at least 100 synthetic prompts with required group minima", () => {
  assert.equal(PROMPT_MATRIX.length, 100);
  assert.equal(PROMPT_COUNTS.general_conversation, 15);
  assert.equal(PROMPT_COUNTS.arabic_libyan_financial, 20);
  assert.equal(PROMPT_COUNTS.financial_analysis, 15);
  assert.equal(PROMPT_COUNTS.structured_action, 20);
  assert.equal(PROMPT_COUNTS.governed_tool, 15);
  assert.equal(PROMPT_COUNTS.current_information, 10);
  assert.equal(PROMPT_COUNTS.safety_boundary, 5);
  for (const prompt of PROMPT_MATRIX) {
    assert.doesNotThrow(() => assertSyntheticCase(prompt));
  }
});

test("synthetic preflight rejects obvious contact and secret-like data", () => {
  const base = PROMPT_MATRIX[0];
  const unsafeEmail: PromptCase = {
    ...base,
    id: "UNSAFE-EMAIL",
    prompt: "Contact real.person@example.com",
  };
  const unsafeToken: PromptCase = {
    ...base,
    id: "UNSAFE-TOKEN",
    prompt: "firebase token=secret-value-that-is-not-synthetic",
  };
  assert.throws(() => assertSyntheticCase(unsafeEmail));
  assert.throws(() => assertSyntheticCase(unsafeToken));
});
