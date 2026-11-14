import type { GatewayConfig } from "../config.js";
import { GatewayFailure } from "../errors.js";
import type {
  GroqCompletionRequest,
  GroqStreamObserver,
  GroqTransport,
} from "./groq_transport.js";
import {
  boundedProviderSignal,
  maxCompletionBodyBytes,
  maxModelsBodyBytes,
  normalizeTransportFailure,
  readBoundedText,
  statusCategoryForFailure,
  upstreamFailure,
  upstreamStatusCategory,
} from "./groq_transport_support.js";
import { providerSseData } from "./provider_sse_decoder.js";
import {
  assertProviderStreamOutputSize,
  parseAvailableModelIds,
  parseCompletionContent,
  parseProviderStreamEvent,
} from "./groq_response_contracts.js";

export type {
  GroqCompletionRequest,
  GroqStreamObserver,
  GroqTransport,
  UpstreamStatusCategory,
} from "./groq_transport.js";

function requestBody(
  request: GroqCompletionRequest,
  stream: boolean,
): Record<string, unknown> {
  return {
    model: request.model,
    messages: request.messages,
    temperature: request.temperature,
    max_completion_tokens: request.maxOutputTokens,
    stream,
    ...(request.responseFormat === undefined
      ? {}
      : { response_format: request.responseFormat }),
    ...(request.reasoningEffort === undefined
      ? {}
      : { reasoning_effort: request.reasoningEffort }),
    ...(request.reasoningFormat === undefined
      ? {}
      : { reasoning_format: request.reasoningFormat }),
  };
}

export class GroqChatCompletionsClient implements GroqTransport {
  constructor(
    private readonly config: GatewayConfig,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  async complete(
    request: GroqCompletionRequest,
    signal?: AbortSignal,
    observer?: GroqStreamObserver,
  ): Promise<string> {
    this.assertConfigured();
    const bounded = boundedProviderSignal(
      signal,
      this.config.providerTimeoutMs,
      "groqRequestTimedOut",
    );
    try {
      let response: Response;
      try {
        response = await this.post(
          "/chat/completions",
          requestBody(request, false),
          bounded.signal,
        );
      } catch (error) {
        const failure = normalizeTransportFailure(
          error,
          bounded.signal,
          "groqRequestTimedOut",
        );
        observer?.onHttpStatus(statusCategoryForFailure(failure));
        throw failure;
      }
      observer?.onHttpStatus(upstreamStatusCategory(response.status));
      if (!response.ok) {
        throw await upstreamFailure(
          response,
          bounded.signal,
          "groqRequestTimedOut",
        );
      }
      const text = await readBoundedText(
        response,
        maxCompletionBodyBytes,
        bounded.signal,
        "groqRequestTimedOut",
        observer,
      );
      return parseCompletionContent(text);
    } finally {
      bounded.dispose();
    }
  }

  async stream(
    request: GroqCompletionRequest,
    onDelta: (delta: string) => void,
    signal?: AbortSignal,
    observer?: GroqStreamObserver,
  ): Promise<void> {
    this.assertConfigured();
    const bounded = boundedProviderSignal(
      signal,
      this.config.providerTimeoutMs,
      "groqStreamTimedOut",
    );
    try {
      let response: Response;
      try {
        response = await this.post(
          "/chat/completions",
          requestBody(request, true),
          bounded.signal,
        );
      } catch (error) {
        const failure = normalizeTransportFailure(
          error,
          bounded.signal,
          "groqStreamTimedOut",
        );
        observer?.onHttpStatus(statusCategoryForFailure(failure));
        throw failure;
      }
      observer?.onHttpStatus(upstreamStatusCategory(response.status));
      if (!response.ok) {
        throw await upstreamFailure(
          response,
          bounded.signal,
          "groqStreamTimedOut",
        );
      }
      if (response.body === null) {
        throw new GatewayFailure(
          "groqMalformedResponse",
          "Groq did not return a response stream.",
        );
      }
      let emittedCharacters = 0;
      let emittedNonWhitespace = false;
      let completed = false;
      for await (const data of providerSseData(
        response.body,
        bounded.signal,
        observer,
      )) {
        const event = parseProviderStreamEvent(data);
        if (event.done) {
          completed = true;
          break;
        }
        const { delta } = event;
        if (delta.length > 0) {
          emittedCharacters += delta.length;
          assertProviderStreamOutputSize(emittedCharacters);
          emittedNonWhitespace ||= delta.trim().length > 0;
          onDelta(delta);
        }
      }
      if (!completed) {
        throw new GatewayFailure(
          "groqUpstreamUnavailable",
          "The Groq stream disconnected before completion.",
        );
      }
      if (!emittedNonWhitespace) {
        throw new GatewayFailure(
          "groqMalformedResponse",
          "The Groq stream contained no answer text.",
        );
      }
    } finally {
      bounded.dispose();
    }
  }

  async availableModelIds(
    signal?: AbortSignal,
  ): Promise<ReadonlySet<string>> {
    this.assertConfigured();
    const bounded = boundedProviderSignal(
      signal,
      this.config.providerTimeoutMs,
      "groqRequestTimedOut",
    );
    try {
      let response: Response;
      try {
        response = await this.get("/models", bounded.signal);
      } catch (error) {
        throw normalizeTransportFailure(
          error,
          bounded.signal,
          "groqRequestTimedOut",
        );
      }
      if (!response.ok) {
        throw await upstreamFailure(
          response,
          bounded.signal,
          "groqRequestTimedOut",
        );
      }
      const text = await readBoundedText(
        response,
        maxModelsBodyBytes,
        bounded.signal,
        "groqRequestTimedOut",
      );
      return parseAvailableModelIds(text);
    } finally {
      bounded.dispose();
    }
  }

  private assertConfigured(): void {
    if (this.config.groqApiKey.trim().length === 0) {
      throw new GatewayFailure(
        "groqNotConfigured",
        "Groq is not configured for this gateway.",
      );
    }
  }

  private async post(
    path: string,
    body: Record<string, unknown>,
    signal: AbortSignal,
  ): Promise<Response> {
    return this.fetcher(`${this.baseUrl()}${path}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.config.groqApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal,
    });
  }

  private async get(path: string, signal: AbortSignal): Promise<Response> {
    return this.fetcher(`${this.baseUrl()}${path}`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${this.config.groqApiKey}`,
      },
      signal,
    });
  }

  private baseUrl(): string {
    return this.config.groqBaseUrl.replace(/\/+$/u, "");
  }
}
