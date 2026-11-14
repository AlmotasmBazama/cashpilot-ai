import type { Request, Response } from "express";
import { z } from "zod";
import { fixedModels } from "../config.js";
import { GatewayFailure, asGatewayFailure } from "../errors.js";
import type { DiagnosticsRouteDependencies } from "./dependencies.js";
import {
  consumeAiRateLimit,
  safeRequestPlatform,
  verifyAiRequest,
} from "./ai_request_validation.js";
import { boundedAbortController } from "./request_abort.js";
import { SafeStreamTrace } from "../security/safe_stream_trace.js";

const DiagnosticRequestSchema = z
  .object({
    requestId: z.string().regex(/^[A-Za-z0-9_-]{8,80}$/),
    check: z.literal("modelAvailability"),
    synthetic: z.literal(true),
  })
  .strict();

export function diagnosticsRoute(
  dependencies: DiagnosticsRouteDependencies,
) {
  return async (request: Request, response: Response): Promise<void> => {
    const principal = await verifyAiRequest(dependencies.verifier, request);
    const parsed = DiagnosticRequestSchema.safeParse(request.body);
    if (!parsed.success) {
      throw new GatewayFailure(
        "gatewayRequestInvalid",
        "The diagnostic request is invalid.",
        { status: 400 },
      );
    }
    const trace = new SafeStreamTrace(
      parsed.data.requestId,
      "/v1/diagnostics",
      dependencies.safeStreamLog,
      {
        appVersion: dependencies.config.supportedClientVersion,
        platform: safeRequestPlatform(request),
      },
    );
    try {
      consumeAiRateLimit(dependencies.rateLimiter, principal.uid);
    } catch (error) {
      const failure = asGatewayFailure(error);
      if (failure.code === "groqRateLimited") {
        trace.recordRateLimited();
      }
      trace.finish(failure.code, failure.status);
      throw failure;
    }
    if (!dependencies.config.modelDiagnosticsEnabled) {
      const failure = new GatewayFailure(
        "gatewayUnavailable",
        "Provider diagnostics are disabled.",
      );
      trace.finish(failure.code, failure.status);
      throw failure;
    }
    const abort = boundedAbortController(
      request,
      response,
      dependencies.config.maxStreamMs,
      "groqStreamTimedOut",
    );
    try {
      const ids = await dependencies.groq.availableModelIds(
        abort.controller.signal,
      );
      if (!ids.has(fixedModels.generalConversation)) {
        throw new GatewayFailure(
          "groqModelUnavailable",
          "The configured general model is not available.",
        );
      }
      trace.selectModel(
        "general-primary",
        fixedModels.generalConversation,
      );
      let textDeltaCount = 0;
      try {
        await dependencies.groq.stream(
          {
            model: fixedModels.generalConversation,
            messages: [
              {
                role: "system",
                content:
                  "This is a synthetic provider health check. Reply with one short word.",
              },
              { role: "user", content: "Ready?" },
            ],
            maxOutputTokens: 256,
            temperature: 0,
            reasoningEffort: "low",
            reasoningFormat: "hidden",
          },
          () => {
            textDeltaCount += 1;
          },
          abort.controller.signal,
          trace,
        );
        trace.finish("completed", 200);
      } catch (error) {
        const failure = asGatewayFailure(error);
        trace.finish(failure.code, failure.status);
        throw error;
      }
      response.status(200).setHeader("Cache-Control", "no-store").json({
        requestId: parsed.data.requestId,
        gateway: "success",
        firebaseAuth: "success",
        appCheck: "success",
        generalModel: "success",
        generalStream: textDeltaCount > 0 ? "success" : "emptyResponse",
        upstreamChunks: trace.receivedUpstreamChunks,
        financialModel: ids.has(fixedModels.financialExplanation)
          ? "success"
          : "provider unavailable",
      });
    } catch (error) {
      const failure = asGatewayFailure(error);
      trace.finish(failure.code, failure.status);
      response.status(failure.status).setHeader("Cache-Control", "no-store").json({
        requestId: parsed.data.requestId,
        gateway: "success",
        firebaseAuth: "success",
        appCheck: "success",
        provider: failure.code,
      });
    } finally {
      abort.dispose();
    }
  };
}
