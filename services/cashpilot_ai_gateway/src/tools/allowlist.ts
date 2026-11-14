import type { ToolSelectionResponse } from "../contracts/tool_selection.js";
import { GatewayFailure } from "../errors.js";
import {
  serverToolAllowlist,
  toolArgumentJsonSchema,
  type ServerToolId,
} from "./tool_definitions.js";

export { serverToolAllowlist };
export type { ServerToolId };

export function intersectAllowedTools(
  requestedIds: readonly string[],
): ServerToolId[] {
  const unique = [...new Set(requestedIds)];
  const unknown = unique.filter((id) => !(id in serverToolAllowlist));
  if (unknown.length > 0) {
    throw new GatewayFailure(
      "toolSelectionInvalid",
      "One or more requested tools are not server-approved.",
      { status: 422 },
    );
  }
  return unique as ServerToolId[];
}

export function validateToolSelection(
  response: ToolSelectionResponse,
  allowedIds: readonly ServerToolId[],
): ToolSelectionResponse {
  const allowed = new Set<string>(allowedIds);
  const fingerprints = new Set<string>();
  for (const selection of response.toolSelections) {
    if (!allowed.has(selection.name)) {
      throw new GatewayFailure(
        "toolSelectionInvalid",
        "The provider selected a tool outside the effective allowlist.",
      );
    }
    const schema = serverToolAllowlist[selection.name as ServerToolId];
    const normalizedArguments = Object.fromEntries(
      Object.entries(selection.arguments).filter(([, value]) => value !== null),
    );
    const parsed = schema.safeParse(normalizedArguments);
    if (!parsed.success) {
      throw new GatewayFailure(
        "toolSelectionInvalid",
        "The provider returned invalid tool arguments.",
      );
    }
    const fingerprint = `${selection.name}:${JSON.stringify(parsed.data)}`;
    if (!fingerprints.add(fingerprint)) {
      throw new GatewayFailure(
        "toolSelectionInvalid",
        "The provider returned a duplicate tool selection.",
      );
    }
    selection.arguments = parsed.data as Record<string, unknown>;
  }
  return response;
}

export function toolSelectionJsonSchema(
  allowedIds: readonly ServerToolId[],
): Record<string, unknown> {
  return {
    name: "cashpilot_governed_tool_selection",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["toolSelections", "clarification"],
      properties: {
        toolSelections: {
          type: "array",
          maxItems: 3,
          items: {
            anyOf: allowedIds.map((id) => ({
              type: "object",
              additionalProperties: false,
              required: ["name", "arguments"],
              properties: {
                name: { type: "string", enum: [id] },
                arguments: toolArgumentJsonSchema(id),
              },
            })),
          },
        },
        clarification: {
          anyOf: [{ type: "string", maxLength: 300 }, { type: "null" }],
        },
      },
    },
  };
}
