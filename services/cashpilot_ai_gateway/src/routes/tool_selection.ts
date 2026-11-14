import type { Request, Response } from "express";
import { GatewayFailure } from "../errors.js";
import { withSingleTransientRetry } from "../groq/model_router.js";
import { toolSelectionMessages } from "../groq/prompts.js";
import { parseToolSelection } from "../groq/tool_selection_parser.js";
import {
  intersectAllowedTools,
  toolSelectionJsonSchema,
  validateToolSelection,
} from "../tools/allowlist.js";
import type { ToolSelectionRouteDependencies } from "./dependencies.js";
import { runAiRequestLifecycle } from "./ai_request_lifecycle.js";

export function toolSelectionRoute(
  dependencies: ToolSelectionRouteDependencies,
) {
  return async (request: Request, response: Response): Promise<void> => {
    await runAiRequestLifecycle(
      {
        request,
        response,
        dependencies,
        expectedMode: "governedToolSelection",
        route: "/v1/ai/tool-selection",
        prepare: (body) => body,
      },
      async (body, active) => {
        if (!dependencies.config.toolSelectionEnabled) {
          throw new GatewayFailure(
            "gatewayUnavailable",
            "Groq tool selection is disabled.",
          );
        }
        const allowedIds = intersectAllowedTools(
          body.allowedToolIds ?? [],
        );
        const channel = active.startSse();
        const signal = active.startAbort(
          dependencies.config.maxStreamMs,
          "groqRequestTimedOut",
        );
        const routed = await withSingleTransientRetry(
          body.mode,
          async (model) => {
            active.trace.selectModel("tool-selection-primary", model);
            return dependencies.groq.complete(
              {
                model,
                messages: toolSelectionMessages({
                  locale: body.locale,
                  messages: body.sanitizedMessages,
                  allowedToolIds: allowedIds,
                }),
                maxOutputTokens: 450,
                temperature: 0,
                responseFormat: {
                  type: "json_schema",
                  json_schema: toolSelectionJsonSchema(allowedIds),
                },
              },
              signal,
              active.trace,
            );
          },
          active.transientRetryOptions(signal),
        );
        const selection = validateToolSelection(
          parseToolSelection(routed.value),
          allowedIds,
        );
        channel.send({
          type: "toolSelection",
          requestId: body.requestId,
          selection,
        });
        active.completeSse();
      },
    );
  };
}
