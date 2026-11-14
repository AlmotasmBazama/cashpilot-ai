import {
  MODEL_IDS,
  type ModelAvailability,
  type ModelId,
  type ProviderCompletion,
  type ToolCall,
  isRecord,
} from "./schemas.ts";

const GROQ_BASE_URL = "https://api.groq.com/openai/v1";

type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

type Sleep = (milliseconds: number) => Promise<void>;

export interface GroqClientOptions {
  apiKey?: string;
  fetchImpl?: FetchLike;
  sleep?: Sleep;
  maxRetries?: number;
  timeoutMs?: number;
  maxRetryDelayMs?: number;
}

export interface CompletionRequest {
  model: ModelId;
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>;
  tools?: unknown[];
  toolChoice?: "auto" | "none";
  responseFormat?:
    | { type: "json_object" }
    | {
        type: "json_schema";
        json_schema: {
          name: string;
          strict: boolean;
          schema: Record<string, unknown>;
        };
      };
  compoundWebSearchOnly?: boolean;
  maxCompletionTokens?: number;
  temperature?: number;
  reasoningEffort?: "none" | "default" | "low" | "medium" | "high";
}

export class MissingGroqApiKeyError extends Error {
  constructor() {
    super("GROQ_API_KEY is required for live model evaluation.");
    this.name = "MissingGroqApiKeyError";
  }
}

export class InvalidProviderResponseError extends Error {
  constructor() {
    super("Groq returned an invalid response shape.");
    this.name = "InvalidProviderResponseError";
  }
}

export class ProviderRequestError extends Error {
  readonly status: number | null;
  readonly statusCategory: string;
  readonly rateLimited: boolean;
  readonly dailyQuota: boolean;
  readonly providerUnavailable: boolean;
  readonly timeout: boolean;
  readonly diagnostic: import("./schemas.ts").SafeProviderDiagnostic;

  constructor(input: {
    status?: number | null;
    statusCategory: string;
    rateLimited?: boolean;
    dailyQuota?: boolean;
    providerUnavailable?: boolean;
    timeout?: boolean;
    diagnostic?: import("./schemas.ts").SafeProviderDiagnostic;
  }) {
    super(`Groq request failed (${input.statusCategory}).`);
    this.name = "ProviderRequestError";
    this.status = input.status ?? null;
    this.statusCategory = input.statusCategory;
    this.rateLimited = input.rateLimited ?? false;
    this.dailyQuota = input.dailyQuota ?? false;
    this.providerUnavailable = input.providerUnavailable ?? false;
    this.timeout = input.timeout ?? false;
    this.diagnostic = input.diagnostic ?? {
      code: null,
      message: null,
      parameter: null,
      failedGenerationPresent: false,
    };
  }
}

export class GroqClient {
  readonly #apiKey: string;
  readonly #fetch: FetchLike;
  readonly #sleep: Sleep;
  readonly #maxRetries: number;
  readonly #timeoutMs: number;
  readonly #maxRetryDelayMs: number;

  constructor(options: GroqClientOptions = {}) {
    const key = options.apiKey ?? process.env.GROQ_API_KEY;
    if (!key || key.trim().length === 0) {
      throw new MissingGroqApiKeyError();
    }
    this.#apiKey = key;
    this.#fetch = options.fetchImpl ?? fetch;
    this.#sleep =
      options.sleep ??
      ((milliseconds) =>
        new Promise((resolve) => setTimeout(resolve, milliseconds)));
    this.#maxRetries = options.maxRetries ?? 2;
    this.#timeoutMs = options.timeoutMs ?? 60_000;
    this.#maxRetryDelayMs = options.maxRetryDelayMs ?? 60_000;
  }

  async discoverModels(): Promise<ModelAvailability[]> {
    const response = await this.#requestJson("models", { method: "GET" });
    if (!isRecord(response.body) || !Array.isArray(response.body.data)) {
      throw new InvalidProviderResponseError();
    }
    const available = new Map<string, { active: boolean | null }>();
    for (const rawModel of response.body.data) {
      if (!isRecord(rawModel) || typeof rawModel.id !== "string") continue;
      available.set(rawModel.id, {
        active:
          typeof rawModel.active === "boolean" ? rawModel.active : null,
      });
    }
    return MODEL_IDS.map((modelId) => {
      const model = available.get(modelId);
      if (!model) {
        return {
          modelId,
          available: false,
          active: null,
          reason: "not_listed",
        };
      }
      if (model.active === false) {
        return {
          modelId,
          available: false,
          active: false,
          reason: "inactive",
        };
      }
      return {
        modelId,
        available: true,
        active: model.active,
        reason: "available",
      };
    });
  }

  async complete(request: CompletionRequest): Promise<ProviderCompletion> {
    const body: Record<string, unknown> = request.compoundWebSearchOnly
      ? {
          model: request.model,
          messages: request.messages,
          compound_custom: {
            tools: { enabled_tools: ["web_search"] },
          },
        }
      : {
          model: request.model,
          messages: request.messages,
          temperature: request.temperature ?? 0.2,
          max_completion_tokens: request.maxCompletionTokens ?? 600,
          reasoning_format: "hidden",
          parallel_tool_calls: false,
          stream: false,
        };
    if (request.reasoningEffort && !request.compoundWebSearchOnly) {
      body.reasoning_effort = request.reasoningEffort;
    }
    if (request.tools) {
      body.tools = request.tools;
      body.tool_choice = request.toolChoice ?? "auto";
      body.disable_tool_validation = false;
    }
    if (request.responseFormat) {
      body.response_format = request.responseFormat;
      // JSON modes already separate reasoning from the final JSON. Omitting
      // reasoning_format avoids unsupported JSON-mode combinations while the
      // parser intentionally discards any provider reasoning field.
      delete body.reasoning_format;
    }
    if (request.compoundWebSearchOnly) {
      // Keep Compound requests intentionally minimal. Built-in search and
      // citations are enabled by the Compound system; model-specific
      // reasoning/sampling/response-format options can produce HTTP 400.
    }

    const started = performance.now();
    const response = await this.#requestJson("chat/completions", {
      method: "POST",
      body: JSON.stringify(body),
      headers: { "Groq-Model-Version": "latest" },
    });
    const latencyTotalMs = Math.round(performance.now() - started);
    const parsed = parseCompletion(response.body);
    return {
      ...parsed,
      latencyFirstMs: null,
      latencyTotalMs,
      httpStatusCategory: response.statusCategory,
    };
  }

  async #requestJson(
    path: string,
    init: RequestInit,
  ): Promise<{
    body: unknown;
    statusCategory: string;
  }> {
    for (let attempt = 0; attempt <= this.#maxRetries; attempt++) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), this.#timeoutMs);
      let response: Response;
      try {
        response = await this.#fetch(`${GROQ_BASE_URL}/${path}`, {
          ...init,
          signal: controller.signal,
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${this.#apiKey}`,
            ...(init.headers ?? {}),
          },
        });
      } catch (error) {
        clearTimeout(timeout);
        const timedOut =
          error instanceof Error &&
          (error.name === "AbortError" || error.name === "TimeoutError");
        if (timedOut && attempt < this.#maxRetries) continue;
        throw new ProviderRequestError({
          statusCategory: timedOut ? "timeout" : "network_error",
          timeout: timedOut,
        });
      }
      clearTimeout(timeout);

      const rawText = await response.text();
      const parsedBody = safeJson(rawText);
      if (response.ok) {
        if (parsedBody === null) throw new InvalidProviderResponseError();
        return {
          body: parsedBody,
          statusCategory: statusCategory(response.status),
        };
      }

      const errorText = extractProviderErrorText(parsedBody);
      const diagnostic = safeProviderDiagnostic(
        parsedBody,
        this.#apiKey,
      );
      const rateLimited = response.status === 429;
      const dailyQuota =
        rateLimited &&
        /\b(?:daily|per day|tokens per day|requests per day|tpd|rpd)\b/i.test(
          errorText,
        );
      const retryable = rateLimited || response.status >= 500;
      if (retryable && !dailyQuota && attempt < this.#maxRetries) {
        const delay = Math.min(
          retryAfterMilliseconds(response.headers.get("Retry-After")) ??
            1000 * 2 ** attempt,
          this.#maxRetryDelayMs,
        );
        await this.#sleep(delay);
        continue;
      }
      throw new ProviderRequestError({
        status: response.status,
        statusCategory: statusCategory(response.status),
        rateLimited,
        dailyQuota,
        providerUnavailable:
          response.status === 404 ||
          diagnostic.code === "model_not_found" ||
          diagnostic.code === "model_decommissioned",
        diagnostic,
      });
    }
    throw new ProviderRequestError({ statusCategory: "retry_exhausted" });
  }
}

function parseCompletion(body: unknown): Omit<
  ProviderCompletion,
  "latencyFirstMs" | "latencyTotalMs" | "httpStatusCategory"
> {
  if (!isRecord(body) || !Array.isArray(body.choices)) {
    throw new InvalidProviderResponseError();
  }
  const firstChoice = body.choices[0];
  if (!isRecord(firstChoice) || !isRecord(firstChoice.message)) {
    throw new InvalidProviderResponseError();
  }
  const message = firstChoice.message;
  const content = typeof message.content === "string" ? message.content : "";
  const toolCalls = parseToolCalls(message.tool_calls);
  const executedTools = Array.isArray(message.executed_tools)
    ? message.executed_tools
    : [];
  const sourceCount =
    countSearchSources(executedTools) +
    countCitationSources(message.citations);
  const usage = isRecord(body.usage) ? body.usage : {};
  return {
    content,
    toolCalls,
    executedTools,
    usage: {
      inputTokens: numberOrNull(
        usage.prompt_tokens ?? usage.input_tokens,
      ),
      outputTokens: numberOrNull(
        usage.completion_tokens ?? usage.output_tokens,
      ),
    },
    sourceSearchMetadataPresent:
      sourceCount > 0 ||
      hasSearchExecution(executedTools) ||
      /\[[^\]]+\]\(https?:\/\/[^)]+\)/.test(content),
    sourceCount,
    finishReason:
      typeof firstChoice.finish_reason === "string"
        ? firstChoice.finish_reason
        : null,
  };
}

function parseToolCalls(value: unknown): ToolCall[] {
  if (!Array.isArray(value)) return [];
  const calls: ToolCall[] = [];
  for (const entry of value) {
    if (!isRecord(entry) || !isRecord(entry.function)) continue;
    const name = entry.function.name;
    if (typeof name !== "string") continue;
    const rawArguments =
      typeof entry.function.arguments === "string"
        ? entry.function.arguments
        : "";
    const parsed = safeJson(rawArguments);
    calls.push({
      name,
      arguments: isRecord(parsed) ? parsed : null,
      rawArguments,
    });
  }
  return calls;
}

export function countSearchSources(executedTools: unknown[]): number {
  let count = 0;
  for (const tool of executedTools) {
    if (!isRecord(tool)) continue;
    let toolCount = 0;
    if (Array.isArray(tool.search_results)) {
      toolCount += tool.search_results.filter(
        (item) =>
          isRecord(item) &&
          typeof item.url === "string" &&
          /^https?:\/\//.test(item.url),
      ).length;
    }
    if (typeof tool.output === "string") {
      toolCount += new Set(
        tool.output.match(/https?:\/\/[^\s)\]}"']+/g) ?? [],
      ).size;
    }
    if (
      toolCount === 0 &&
      (tool.type === "search" ||
        tool.type === "web_search" ||
        tool.name === "web_search") &&
      (typeof tool.output === "string" || tool.search_results)
    ) {
      toolCount = 1;
    }
    count += toolCount;
  }
  return count;
}

function countCitationSources(value: unknown): number {
  if (!Array.isArray(value)) return 0;
  return value.filter(
    (citation) =>
      (typeof citation === "string" &&
        /^https?:\/\//.test(citation)) ||
      (isRecord(citation) &&
        typeof citation.url === "string" &&
        /^https?:\/\//.test(citation.url)),
  ).length;
}

function hasSearchExecution(executedTools: unknown[]): boolean {
  return executedTools.some(
    (tool) =>
      isRecord(tool) &&
      (tool.type === "search" ||
        tool.type === "web_search" ||
        tool.name === "web_search"),
  );
}

function safeJson(text: string): unknown | null {
  if (text.trim().length === 0) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function extractProviderErrorText(body: unknown): string {
  if (!isRecord(body)) return "";
  if (isRecord(body.error) && typeof body.error.message === "string") {
    return body.error.message;
  }
  return typeof body.message === "string" ? body.message : "";
}

function safeProviderDiagnostic(
  body: unknown,
  apiKey: string,
): import("./schemas.ts").SafeProviderDiagnostic {
  const error = isRecord(body) && isRecord(body.error)
    ? body.error
    : isRecord(body)
      ? body
      : {};
  const code =
    typeof error.code === "string"
      ? safeToken(error.code)
      : typeof error.type === "string"
        ? safeToken(error.type)
        : null;
  const rawMessage =
    typeof error.message === "string" ? error.message : "";
  const rawParameter =
    typeof error.param === "string" ? error.param : "";
  return {
    code,
    message:
      rawMessage.length === 0
        ? null
        : redactDiagnostic(rawMessage, apiKey).slice(0, 400),
    parameter:
      rawParameter.length === 0 ? null : safeToken(rawParameter),
    failedGenerationPresent:
      isRecord(body) &&
      (Object.hasOwn(body, "failed_generation") ||
        (isRecord(body.error) &&
          Object.hasOwn(body.error, "failed_generation"))),
  };
}

function safeToken(value: string): string | null {
  const sanitized = value.replace(/[^A-Za-z0-9_.-]/g, "").slice(0, 80);
  return sanitized.length > 0 ? sanitized : null;
}

function redactDiagnostic(value: string, apiKey: string): string {
  return value
    .replaceAll(apiKey, "[REDACTED]")
    .replace(/Bearer\s+\S+/gi, "Bearer [REDACTED]")
    .replace(/\b(?:gsk|sk|AIza)[-_A-Za-z0-9]{12,}\b/g, "[REDACTED]")
    .replace(/[\r\n\t]+/g, " ")
    .trim();
}

function statusCategory(status: number): string {
  if (status >= 200 && status < 300) return "2xx";
  if (status === 400) return "bad_request";
  if (status === 401 || status === 403) return "auth_error";
  if (status === 404) return "not_found";
  if (status === 408) return "timeout";
  if (status === 429) return "rate_limited";
  if (status >= 500) return "provider_5xx";
  return `${Math.floor(status / 100)}xx`;
}

function retryAfterMilliseconds(value: string | null): number | null {
  if (!value) return null;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) {
    return Math.ceil(seconds * 1000);
  }
  const date = Date.parse(value);
  if (Number.isNaN(date)) return null;
  return Math.max(0, date - Date.now());
}
