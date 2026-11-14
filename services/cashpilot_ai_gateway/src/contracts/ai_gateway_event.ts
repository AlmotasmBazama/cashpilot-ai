import type { GatewayFailureCode } from "../errors.js";
import type { ToolSelectionResponse } from "./tool_selection.js";

export type AiGatewayEvent =
  | { type: "started"; requestId: string }
  | { type: "textDelta"; requestId: string; delta: string }
  | {
      type: "toolSelection";
      requestId: string;
      selection: ToolSelectionResponse;
    }
  | { type: "warning"; requestId: string; code: string }
  | { type: "completed"; requestId: string }
  | {
      type: "failure";
      requestId: string;
      code: GatewayFailureCode;
      retryAfterSeconds?: number;
    };
