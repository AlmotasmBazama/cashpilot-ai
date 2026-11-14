import type { Request, Response } from "express";
import type { RequestVerifier } from "../auth/request_verifier_port.js";
import type { GatewayConfig } from "../config.js";
import type {
  AiGatewayMode,
  AiGatewayRequest,
} from "../contracts/ai_gateway_request.js";
import { asGatewayFailure } from "../errors.js";
import type { SameModelRetryOptions } from "../groq/model_router.js";
import type { RateLimiter } from "../security/rate_limiter.js";
import {
  SafeStreamTrace,
  type SafeStreamLogSink,
} from "../security/safe_stream_trace.js";
import {
  consumeAiRateLimit,
  parseModeRequest,
  safeRequestPlatform,
  verifyAiRequest,
} from "./ai_request_validation.js";
import { boundedAbortController } from "./request_abort.js";
import { SseChannel } from "./sse_channel.js";

interface AiRequestLifecycleDependencies {
  readonly config: Pick<
    GatewayConfig,
    "maxStreamMs" | "supportedClientVersion"
  >;
  readonly verifier: RequestVerifier;
  readonly rateLimiter: RateLimiter;
  readonly safeStreamLog?: SafeStreamLogSink;
}

interface AiRequestLifecycleDefinition<TPrepared> {
  readonly request: Request;
  readonly response: Response;
  readonly dependencies: AiRequestLifecycleDependencies;
  readonly expectedMode: AiGatewayMode;
  readonly route: string;
  /** Runs after parsing but before tracing and rate-limit consumption. */
  readonly prepare: (body: AiGatewayRequest) => TPrepared;
}

export class ActiveAiRequest {
  readonly trace: SafeStreamTrace;

  private channel: SseChannel | undefined;
  private abort: ReturnType<typeof boundedAbortController> | undefined;

  constructor(
    private readonly request: Request,
    private readonly response: Response,
    private readonly requestId: string,
    route: string,
    dependencies: AiRequestLifecycleDependencies,
  ) {
    this.trace = new SafeStreamTrace(
      requestId,
      route,
      dependencies.safeStreamLog,
      {
        appVersion: dependencies.config.supportedClientVersion,
        platform: safeRequestPlatform(request),
      },
    );
  }

  startAbort(
    durationMs: number,
    timeoutCode: "groqRequestTimedOut" | "groqStreamTimedOut",
  ): AbortSignal {
    this.abort = boundedAbortController(
      this.request,
      this.response,
      durationMs,
      timeoutCode,
    );
    return this.abort.controller.signal;
  }

  startSse(): SseChannel {
    const channel = new SseChannel(
      this.response,
      this.requestId,
      (type) => this.trace.recordEvent(type),
    );
    this.channel = channel;
    channel.send({ type: "started", requestId: this.requestId });
    return channel;
  }

  transientRetryOptions(signal: AbortSignal): SameModelRetryOptions {
    return {
      signal,
      ...(this.channel === undefined
        ? {}
        : {
            hasEmittedContent: () =>
              this.channel?.hasEmittedText === true,
          }),
      onRetry: () => {
        this.trace.recordRetry();
        this.channel?.send({
          type: "warning",
          requestId: this.requestId,
          code: "transientUpstreamRetry",
        });
      },
    };
  }

  finishHttp(status = 200): void {
    this.trace.finish("completed", status);
  }

  completeSse(): void {
    this.channel?.complete();
    this.trace.finish("completed", 200);
  }

  handleFailure(error: unknown): void {
    const failure = asGatewayFailure(error);
    if (failure.code === "groqRateLimited") {
      this.trace.recordRateLimited();
    }
    if (this.channel === undefined) {
      this.trace.finish(failure.code, failure.status);
      throw failure;
    }
    this.channel.fail(failure);
    this.trace.finish(failure.code, failure.status);
  }

  dispose(): void {
    this.abort?.dispose();
  }
}

export async function runAiRequestLifecycle<TPrepared>(
  definition: AiRequestLifecycleDefinition<TPrepared>,
  execute: (
    prepared: TPrepared,
    request: ActiveAiRequest,
  ) => Promise<void>,
): Promise<void> {
  let active: ActiveAiRequest | undefined;
  try {
    const principal = await verifyAiRequest(
      definition.dependencies.verifier,
      definition.request,
    );
    const body = parseModeRequest(
      definition.request,
      definition.expectedMode,
      definition.dependencies.config,
    );
    const prepared = definition.prepare(body);
    active = new ActiveAiRequest(
      definition.request,
      definition.response,
      body.requestId,
      definition.route,
      definition.dependencies,
    );
    consumeAiRateLimit(
      definition.dependencies.rateLimiter,
      principal.uid,
    );
    await execute(prepared, active);
  } catch (error) {
    const failure = asGatewayFailure(error);
    if (active === undefined) {
      throw failure;
    }
    active.handleFailure(failure);
  } finally {
    active?.dispose();
  }
}
