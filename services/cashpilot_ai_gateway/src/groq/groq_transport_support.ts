import { GatewayFailure } from "../errors.js";
import type {
  GroqStreamObserver,
  UpstreamStatusCategory,
} from "./groq_transport.js";

export const maxCompletionBodyBytes = 512 * 1024;
export const maxModelsBodyBytes = 2 * 1024 * 1024;

const maxErrorBodyBytes = 64 * 1024;

export type ProviderTimeoutCode =
  | "groqRequestTimedOut"
  | "groqStreamTimedOut";

interface UpstreamError {
  readonly error?: {
    readonly code?: string;
    readonly type?: string;
    readonly message?: string;
  };
}

export function upstreamStatusCategory(
  status: number,
): UpstreamStatusCategory {
  if (status >= 200 && status < 300) {
    return "success";
  }
  if (status === 401 || status === 403) {
    return "authenticationRejected";
  }
  if (status === 429) {
    return "rateLimited";
  }
  if (status === 408) {
    return "timeout";
  }
  if (status === 498 || status >= 500) {
    return status === 498 ? "capacityUnavailable" : "serverError";
  }
  return "clientError";
}

export function statusCategoryForFailure(
  failure: GatewayFailure,
): UpstreamStatusCategory {
  switch (failure.code) {
    case "groqAuthenticationFailed":
      return "authenticationRejected";
    case "groqRateLimited":
      return "rateLimited";
    case "groqRequestTimedOut":
    case "groqStreamTimedOut":
      return "timeout";
    case "groqUpstreamUnavailable":
    case "gatewayUnavailable":
      return "networkFailure";
    default:
      return "clientError";
  }
}

function retryAfterSeconds(response: Response): number | undefined {
  const value = response.headers.get("Retry-After");
  if (value === null) {
    return undefined;
  }
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.ceil(seconds);
  }
  const date = Date.parse(value);
  if (Number.isFinite(date)) {
    return Math.max(0, Math.ceil((date - Date.now()) / 1_000));
  }
  return undefined;
}

function abortReason(
  signal: AbortSignal | undefined,
  timeoutCode: ProviderTimeoutCode,
): GatewayFailure {
  if (signal?.reason instanceof GatewayFailure) {
    return signal.reason;
  }
  return new GatewayFailure(
    timeoutCode,
    timeoutCode === "groqStreamTimedOut"
      ? "The Groq response stream timed out."
      : "The Groq request timed out.",
  );
}

export function normalizeTransportFailure(
  error: unknown,
  signal: AbortSignal | undefined,
  timeoutCode: ProviderTimeoutCode,
): GatewayFailure {
  if (error instanceof GatewayFailure) {
    return error;
  }
  if (
    signal?.aborted === true ||
    (error instanceof DOMException && error.name === "AbortError")
  ) {
    return abortReason(signal, timeoutCode);
  }
  return new GatewayFailure(
    "groqUpstreamUnavailable",
    "The Groq upstream request is temporarily unavailable.",
  );
}

export function boundedProviderSignal(
  externalSignal: AbortSignal | undefined,
  timeoutMs: number,
  timeoutCode: ProviderTimeoutCode,
): { readonly signal: AbortSignal; readonly dispose: () => void } {
  const controller = new AbortController();
  const timer = setTimeout(() => {
    controller.abort(abortReason(undefined, timeoutCode));
  }, timeoutMs);
  const externalAbort = () => {
    controller.abort(
      externalSignal?.reason instanceof GatewayFailure
        ? externalSignal.reason
        : new GatewayFailure(
            "gatewayUnavailable",
            "The gateway request was interrupted.",
          ),
    );
  };
  externalSignal?.addEventListener("abort", externalAbort, { once: true });
  if (externalSignal?.aborted === true) {
    externalAbort();
  }
  return {
    signal: controller.signal,
    dispose: () => {
      clearTimeout(timer);
      externalSignal?.removeEventListener("abort", externalAbort);
    },
  };
}

export async function readBoundedText(
  response: Response,
  maxBytes: number,
  signal: AbortSignal,
  timeoutCode: ProviderTimeoutCode,
  observer?: GroqStreamObserver,
): Promise<string> {
  if (response.body === null) {
    return "";
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let byteCount = 0;
  let text = "";
  let finishedReading = false;
  try {
    for (;;) {
      let item: ReadableStreamReadResult<Uint8Array>;
      try {
        item = await reader.read();
      } catch (error) {
        throw normalizeTransportFailure(error, signal, timeoutCode);
      }
      if (item.value !== undefined && item.value.length > 0) {
        observer?.onChunk();
        byteCount += item.value.length;
        if (byteCount > maxBytes) {
          throw new GatewayFailure(
            "groqMalformedResponse",
            "The Groq response exceeded the safe size limit.",
          );
        }
        try {
          text += decoder.decode(item.value, { stream: true });
        } catch {
          throw new GatewayFailure(
            "groqMalformedResponse",
            "The Groq response was not valid UTF-8.",
          );
        }
      }
      if (item.done) {
        finishedReading = true;
        try {
          text += decoder.decode();
        } catch {
          throw new GatewayFailure(
            "groqMalformedResponse",
            "The Groq response was not valid UTF-8.",
          );
        }
        return text;
      }
    }
  } finally {
    if (!finishedReading) {
      try {
        await reader.cancel();
      } catch {
        // Preserve the original failure if the upstream is already broken.
      }
    }
    reader.releaseLock();
  }
}

export async function upstreamFailure(
  response: Response,
  signal: AbortSignal,
  timeoutCode: ProviderTimeoutCode,
): Promise<GatewayFailure> {
  let code = "";
  let type = "";
  let message = "";
  try {
    const text = await readBoundedText(
      response,
      maxErrorBodyBytes,
      signal,
      timeoutCode,
    );
    const body = JSON.parse(text) as UpstreamError;
    code = body.error?.code?.toLowerCase() ?? "";
    type = body.error?.type?.toLowerCase() ?? "";
    message = body.error?.message?.toLowerCase() ?? "";
  } catch {
    // Provider error bodies are optional and are never logged or returned.
  }
  if (response.status === 413 || code === "request_too_large") {
    return new GatewayFailure(
      "gatewayRequestInvalid",
      "The fixed Groq request exceeded the provider size limit.",
      { status: 413 },
    );
  }
  if (response.status === 429) {
    const retryAfter = retryAfterSeconds(response);
    return new GatewayFailure(
      "groqRateLimited",
      "Groq is temporarily rate limited.",
      retryAfter === undefined ? {} : { retryAfterSeconds: retryAfter },
    );
  }
  if (response.status === 401 || response.status === 403) {
    return new GatewayFailure(
      "groqAuthenticationFailed",
      "Groq rejected the server-held credential.",
    );
  }
  if (
    response.status === 404 ||
    code.includes("model") ||
    type.includes("model") ||
    (message.includes("model") &&
      (message.includes("unavailable") ||
        message.includes("not found") ||
        message.includes("does not exist") ||
        message.includes("decommission")))
  ) {
    return new GatewayFailure(
      "groqModelUnavailable",
      "The configured Groq model is unavailable.",
    );
  }
  if (response.status === 408) {
    return abortReason(undefined, timeoutCode);
  }
  if (response.status === 498 || response.status >= 500) {
    return new GatewayFailure(
      "groqUpstreamUnavailable",
      "Groq is temporarily unavailable.",
    );
  }
  return new GatewayFailure(
    "gatewayRequestInvalid",
    "Groq rejected the fixed gateway request.",
  );
}
