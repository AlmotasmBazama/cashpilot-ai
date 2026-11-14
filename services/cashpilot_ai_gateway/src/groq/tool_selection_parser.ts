import {
  ToolSelectionResponseSchema,
  type ToolSelectionResponse,
} from "../contracts/tool_selection.js";
import { GatewayFailure } from "../errors.js";
import { hasUnverifiedMutationClaim } from "../security/provider_output_safety.js";

function stripJsonFence(value: string): string {
  const trimmed = value.trim();
  if (!trimmed.startsWith("```")) {
    return trimmed;
  }
  return trimmed
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
}

export function parseToolSelection(text: string): ToolSelectionResponse {
  let value: unknown;
  try {
    value = JSON.parse(stripJsonFence(text));
  } catch {
    throw new GatewayFailure(
      "toolSelectionInvalid",
      "The provider returned malformed tool-selection JSON.",
    );
  }
  const parsed = ToolSelectionResponseSchema.safeParse(value);
  if (!parsed.success) {
    throw new GatewayFailure(
      "toolSelectionInvalid",
      "The provider returned an invalid tool-selection structure.",
    );
  }
  if (
    parsed.data.clarification !== null &&
    hasUnverifiedMutationClaim(parsed.data.clarification)
  ) {
    throw new GatewayFailure(
      "toolSelectionInvalid",
      "The provider returned an unsafe tool-selection clarification.",
    );
  }
  return parsed.data;
}
