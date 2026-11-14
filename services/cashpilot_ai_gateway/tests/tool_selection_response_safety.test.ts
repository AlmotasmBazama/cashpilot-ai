import assert from "node:assert/strict";
import { test } from "node:test";
import { GatewayFailure } from "../src/errors.js";
import { parseToolSelection } from "../src/groq/response_parser.js";

function providerSelection(clarification: string): string {
  return JSON.stringify({ toolSelections: [], clarification });
}

test("tool-selection clarification rejects passive false-mutation claims", () => {
  for (const clarification of [
    "Your transaction has been recorded.",
    "تم تسجيل الدخل",
    "خلاص، تم حفظ المصروف.",
  ]) {
    assert.throws(
      () => parseToolSelection(providerSelection(clarification)),
      (error: unknown) =>
        error instanceof GatewayFailure &&
        error.code === "toolSelectionInvalid",
      clarification,
    );
  }
});

test("tool-selection clarification accepts an ordinary question", () => {
  const clarification = "Which account should I use for this expense?";

  assert.deepEqual(parseToolSelection(providerSelection(clarification)), {
    toolSelections: [],
    clarification,
  });
});
