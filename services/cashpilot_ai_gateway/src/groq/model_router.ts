import { fixedModels } from "../config.js";
import {
  GatewayFailure,
  asGatewayFailure,
  isRetryableGroqFailure,
} from "../errors.js";
import type { AiGatewayMode } from "../contracts/ai_gateway_request.js";

const baseRetryDelayMs = 150;
const retryJitterMs = 100;
const maxAutomaticRetryDelayMs = 2_000;

export interface RoutedResult<T> {
  readonly value: T;
  readonly model: string;
  readonly retryCount: number;
}

export interface SameModelRetryOptions {
  readonly signal?: AbortSignal;
  readonly hasEmittedContent?: () => boolean;
  readonly onRetry?: (delayMs: number) => void;
  readonly sleep?: (delayMs: number, signal?: AbortSignal) => Promise<void>;
  readonly random?: () => number;
}

export function fixedModelForMode(mode: AiGatewayMode): string {
  switch (mode) {
    case "generalConversation":
      return fixedModels.generalConversation;
    case "financialExplanation":
      return fixedModels.financialExplanation;
    case "governedToolSelection":
      return fixedModels.governedToolSelection;
  }
}

function abortFailure(signal: AbortSignal | undefined): GatewayFailure {
  if (signal?.reason instanceof GatewayFailure) {
    return signal.reason;
  }
  return new GatewayFailure(
    "gatewayUnavailable",
    "The gateway request was interrupted.",
  );
}

async function defaultSleep(
  delayMs: number,
  signal?: AbortSignal,
): Promise<void> {
  if (signal?.aborted === true) {
    throw abortFailure(signal);
  }
  await new Promise<void>((resolve, reject) => {
    const complete = () => {
      signal?.removeEventListener("abort", aborted);
      resolve();
    };
    const timer = setTimeout(complete, delayMs);
    const aborted = () => {
      clearTimeout(timer);
      signal?.removeEventListener("abort", aborted);
      reject(abortFailure(signal));
    };
    signal?.addEventListener("abort", aborted, { once: true });
    if (signal?.aborted === true) {
      aborted();
    }
  });
}

function boundedRetryDelay(
  failure: GatewayFailure,
  random: () => number,
): number | null {
  if (failure.retryAfterSeconds !== undefined) {
    const requestedMs = Math.max(0, failure.retryAfterSeconds * 1_000);
    return requestedMs <= maxAutomaticRetryDelayMs ? requestedMs : null;
  }
  const jitter = Math.floor(Math.max(0, Math.min(1, random())) * retryJitterMs);
  return baseRetryDelayMs + jitter;
}

/**
 * Executes a fixed-model operation with at most one transient retry. The model
 * never changes, Retry-After is honored when it fits the bounded automatic
 * retry window, and streamed content permanently closes the retry window.
 */
export async function withSingleTransientRetry<T>(
  mode: AiGatewayMode,
  operation: (model: string, attempt: 0 | 1) => Promise<T>,
  options: SameModelRetryOptions = {},
): Promise<RoutedResult<T>> {
  const model = fixedModelForMode(mode);
  try {
    return {
      value: await operation(model, 0),
      model,
      retryCount: 0,
    };
  } catch (error) {
    const failure = asGatewayFailure(error);
    if (
      !isRetryableGroqFailure(failure) ||
      options.hasEmittedContent?.() === true ||
      options.signal?.aborted === true
    ) {
      throw failure;
    }
    const delayMs = boundedRetryDelay(failure, options.random ?? Math.random);
    if (delayMs === null) {
      throw failure;
    }
    options.onRetry?.(delayMs);
    await (options.sleep ?? defaultSleep)(delayMs, options.signal);
    return {
      value: await operation(model, 1),
      model,
      retryCount: 1,
    };
  }
}
