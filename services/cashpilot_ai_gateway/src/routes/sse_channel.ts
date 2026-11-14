import type { Response } from "express";
import type { AiGatewayEvent } from "../contracts/ai_gateway_event.js";
import { type GatewayFailure, asGatewayFailure } from "../errors.js";

export class SseChannel {
  private sequence = 0;
  private ended = false;
  private emittedText = false;

  constructor(
    private readonly response: Response,
    readonly requestId: string,
    private readonly onEvent?: (type: AiGatewayEvent["type"]) => void,
  ) {
    response.status(200);
    response.setHeader("Content-Type", "text/event-stream; charset=utf-8");
    response.setHeader("Cache-Control", "no-store, no-cache, must-revalidate");
    response.setHeader("Connection", "keep-alive");
    response.setHeader("X-Accel-Buffering", "no");
    response.setHeader("X-Request-ID", requestId);
    response.flushHeaders();
  }

  send(event: AiGatewayEvent): void {
    if (
      this.ended ||
      this.response.writableEnded ||
      this.response.destroyed
    ) {
      return;
    }
    this.sequence += 1;
    this.onEvent?.(event.type);
    if (event.type === "textDelta" && event.delta.length > 0) {
      this.emittedText = true;
    }
    this.response.write(
      `id: ${this.sequence}\nevent: cashpilot\ndata: ${JSON.stringify(event)}\n\n`,
    );
  }

  get hasEmittedText(): boolean {
    return this.emittedText;
  }

  complete(): void {
    if (this.ended) {
      return;
    }
    this.send({ type: "completed", requestId: this.requestId });
    this.ended = true;
    this.response.end();
  }

  fail(error: unknown): GatewayFailure["code"] {
    if (this.ended) {
      return "invalidResponse";
    }
    const failure = asGatewayFailure(error);
    this.response.locals.failureCode = failure.code;
    this.send({
      type: "failure",
      requestId: this.requestId,
      code: failure.code,
      ...(failure.retryAfterSeconds === undefined
        ? {}
        : { retryAfterSeconds: failure.retryAfterSeconds }),
    });
    this.ended = true;
    this.response.end();
    return failure.code;
  }
}
