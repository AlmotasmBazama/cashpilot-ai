import type { Request, Response } from "express";
import { GatewayFailure } from "../errors.js";
import {
  assertFinancialAnswerIsGrounded,
  unsupportedFinancialFigures,
} from "../groq/financial_response_grounding.js";
import { withSingleTransientRetry } from "../groq/model_router.js";
import { financialExplanationMessages } from "../groq/prompts.js";
import { textDeltas } from "../groq/text_chunking.js";
import type { FinancialExplanationRouteDependencies } from "./dependencies.js";
import { runAiRequestLifecycle } from "./ai_request_lifecycle.js";

export function financialExplanationRoute(
  dependencies: FinancialExplanationRouteDependencies,
) {
  return async (request: Request, response: Response): Promise<void> => {
    await runAiRequestLifecycle(
      {
        request,
        response,
        dependencies,
        expectedMode: "financialExplanation",
        route: "/v1/ai/financial-explanation",
        prepare: (body) => {
          const context = body.sanitizedFinancialContext;
          if (context === undefined) {
            throw new GatewayFailure(
              "gatewayRequestInvalid",
              "Bounded financial context is required.",
              { status: 400 },
            );
          }
          return { body, context };
        },
      },
      async ({ body, context }, active) => {
        const channel = active.startSse();
        const signal = active.startAbort(
          dependencies.config.maxStreamMs,
          "groqRequestTimedOut",
        );
        const initialMessages = financialExplanationMessages({
          locale: body.locale,
          messages: body.sanitizedMessages,
          financialContext: context,
        });
        const routed = await withSingleTransientRetry(
          body.mode,
          async (model) => {
            active.trace.selectModel("financial-primary", model);
            return dependencies.groq.complete(
              {
                model,
                messages: initialMessages,
                maxOutputTokens: 900,
                temperature: 0.1,
              },
              signal,
              active.trace,
            );
          },
          active.transientRetryOptions(signal),
        );

        let answer = routed.value;
        const unsupported = unsupportedFinancialFigures(answer, context);
        if (unsupported.length > 0) {
          const correctedMessages = financialExplanationMessages({
            locale: body.locale,
            messages: body.sanitizedMessages,
            financialContext: context,
            correction:
              "The previous draft introduced unsupported figures. Rewrite once using only numbers present in the bounded context.",
          });
          answer = await dependencies.groq.complete(
            {
              model: routed.model,
              messages: correctedMessages,
              maxOutputTokens: 900,
              temperature: 0,
            },
            signal,
            active.trace,
          );
        }
        assertFinancialAnswerIsGrounded(answer, context);
        for (const delta of textDeltas(answer)) {
          channel.send({
            type: "textDelta",
            requestId: body.requestId,
            delta,
          });
        }
        active.completeSse();
      },
    );
  };
}
