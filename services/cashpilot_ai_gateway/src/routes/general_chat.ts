import type { Request, Response } from "express";
import { GatewayFailure } from "../errors.js";
import { withSingleTransientRetry } from "../groq/model_router.js";
import { generalConversationMessages } from "../groq/prompts.js";
import { hasUnverifiedMutationClaim } from "../security/provider_output_safety.js";
import type { GeneralChatRouteDependencies } from "./dependencies.js";
import { runAiRequestLifecycle } from "./ai_request_lifecycle.js";
import type { SseChannel } from "./sse_channel.js";

const progressiveSafetyHoldbackCharacters = 192;
const maxGeneralOutputCharacters = 16 * 1024;

class SafeProgressiveEmitter {
  private fullText = "";
  private pendingText = "";

  constructor(
    private readonly channel: SseChannel,
    private readonly requestId: string,
  ) {}

  accept(delta: string): void {
    if (delta.length === 0) {
      return;
    }
    this.fullText += delta;
    this.pendingText += delta;
    this.assertSafeAndBounded();
    let emitLength =
      this.pendingText.length - progressiveSafetyHoldbackCharacters;
    if (emitLength <= 0) {
      return;
    }
    if (/^[\uDC00-\uDFFF]$/u.test(this.pendingText[emitLength] ?? "")) {
      emitLength -= 1;
    }
    if (emitLength > 0) {
      this.emit(this.pendingText.slice(0, emitLength));
      this.pendingText = this.pendingText.slice(emitLength);
    }
  }

  finish(): void {
    this.assertSafeAndBounded();
    if (this.fullText.trim().length === 0) {
      throw new GatewayFailure(
        "groqMalformedResponse",
        "Groq returned an empty response.",
      );
    }
    if (this.pendingText.length > 0) {
      this.emit(this.pendingText);
      this.pendingText = "";
    }
  }

  private assertSafeAndBounded(): void {
    if (this.fullText.length > maxGeneralOutputCharacters) {
      throw new GatewayFailure(
        "groqMalformedResponse",
        "The Groq response exceeded the safe output limit.",
      );
    }
    if (hasUnverifiedMutationClaim(this.fullText)) {
      throw new GatewayFailure(
        "groqMalformedResponse",
        "The Groq response contained an unverified action claim.",
      );
    }
  }

  private emit(delta: string): void {
    this.channel.send({
      type: "textDelta",
      requestId: this.requestId,
      delta,
    });
  }
}

function assertSafeCompleteAnswer(answer: string): void {
  if (
    answer.trim().length === 0 ||
    answer.length > maxGeneralOutputCharacters
  ) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "Groq returned an empty or oversized response.",
    );
  }
  if (hasUnverifiedMutationClaim(answer)) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The Groq response contained an unverified action claim.",
    );
  }
}

export function generalChatRoute(
  dependencies: GeneralChatRouteDependencies,
) {
  return async (request: Request, response: Response): Promise<void> => {
    await runAiRequestLifecycle(
      {
        request,
        response,
        dependencies,
        expectedMode: "generalConversation",
        route: "/v1/ai/general-chat",
        prepare: (body) => body,
      },
      async (body, active) => {
        const signal = active.startAbort(
          dependencies.config.maxStreamMs,
          body.responseMode === "json"
            ? "groqRequestTimedOut"
            : "groqStreamTimedOut",
        );
        const messages = generalConversationMessages({
          locale: body.locale,
          messages: body.sanitizedMessages,
          ...(body.compactMemorySummary === undefined
            ? {}
            : { compactMemorySummary: body.compactMemorySummary }),
        });

        if (body.responseMode === "json") {
          const routed = await withSingleTransientRetry(
            body.mode,
            async (model) => {
              active.trace.selectModel("general-primary", model);
              return dependencies.groq.complete(
                {
                  model,
                  messages,
                  maxOutputTokens: 700,
                  temperature: 0.2,
                  reasoningEffort: "low",
                  reasoningFormat: "hidden",
                },
                signal,
                active.trace,
              );
            },
            active.transientRetryOptions(signal),
          );
          assertSafeCompleteAnswer(routed.value);
          response.status(200).json({
            requestId: body.requestId,
            text: routed.value,
          });
          active.finishHttp();
          return;
        }

        const channel = active.startSse();
        await withSingleTransientRetry(
          body.mode,
          async (model) => {
            active.trace.selectModel("general-primary", model);
            const emitter = new SafeProgressiveEmitter(
              channel,
              body.requestId,
            );
            await dependencies.groq.stream(
              {
                model,
                messages,
                maxOutputTokens: 700,
                temperature: 0.2,
                reasoningEffort: "low",
                reasoningFormat: "hidden",
              },
              (delta) => emitter.accept(delta),
              signal,
              active.trace,
            );
            emitter.finish();
          },
          active.transientRetryOptions(signal),
        );
        active.completeSse();
      },
    );
  };
}
