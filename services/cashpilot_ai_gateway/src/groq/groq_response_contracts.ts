import { z } from "zod";
import { GatewayFailure } from "../errors.js";

const maxProviderOutputCharacters = 16 * 1024;

const CompletionEnvelopeSchema = z
  .object({ choices: z.array(z.unknown()) })
  .passthrough();

const ModelListEnvelopeSchema = z
  .object({ data: z.array(z.unknown()) })
  .passthrough();

const StreamEnvelopeSchema = z.object({}).passthrough();

export interface ParsedProviderStreamEvent {
  readonly done: boolean;
  readonly delta: string;
}

export function parseCompletionContent(text: string): string {
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "Groq returned malformed JSON.",
    );
  }
  const envelope = CompletionEnvelopeSchema.safeParse(body);
  const firstChoice = envelope.success ? envelope.data.choices[0] : null;
  const content =
    typeof firstChoice === "object" &&
    firstChoice !== null &&
    "message" in firstChoice &&
    typeof firstChoice.message === "object" &&
    firstChoice.message !== null &&
    "content" in firstChoice.message &&
    typeof firstChoice.message.content === "string"
      ? firstChoice.message.content
      : "";
  if (
    content.trim().length === 0 ||
    content.length > maxProviderOutputCharacters
  ) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "Groq returned an empty or oversized completion.",
    );
  }
  return content;
}

export function parseProviderStreamEvent(
  data: string,
): ParsedProviderStreamEvent {
  if (data.trim() === "[DONE]") {
    return { done: true, delta: "" };
  }

  let event: unknown;
  try {
    event = JSON.parse(data);
  } catch {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The Groq stream contained malformed JSON.",
    );
  }

  const streamedFailure = failureFromStreamPayload(event);
  if (streamedFailure !== null) {
    throw streamedFailure;
  }

  const envelope = StreamEnvelopeSchema.safeParse(event);
  if (!envelope.success || !("choices" in envelope.data)) {
    return { done: false, delta: "" };
  }
  if (!Array.isArray(envelope.data.choices)) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The Groq stream contained malformed choices.",
    );
  }
  const firstChoice = envelope.data.choices[0];
  if (
    typeof firstChoice !== "object" ||
    firstChoice === null ||
    !("delta" in firstChoice) ||
    typeof firstChoice.delta !== "object" ||
    firstChoice.delta === null ||
    !("content" in firstChoice.delta)
  ) {
    return { done: false, delta: "" };
  }
  const content = firstChoice.delta.content;
  if (content !== null && typeof content !== "string") {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The Groq stream contained malformed text content.",
    );
  }
  return {
    done: false,
    delta: typeof content === "string" ? content : "",
  };
}

export function assertProviderStreamOutputSize(
  emittedCharacters: number,
): void {
  if (emittedCharacters > maxProviderOutputCharacters) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The Groq stream output exceeded the safe limit.",
    );
  }
}

export function parseAvailableModelIds(text: string): ReadonlySet<string> {
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "Groq returned malformed model metadata.",
    );
  }
  const envelope = ModelListEnvelopeSchema.safeParse(body);
  if (!envelope.success) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "Groq returned invalid model metadata.",
    );
  }
  return new Set(
    envelope.data.data.flatMap((item) =>
      typeof item === "object" &&
      item !== null &&
      "id" in item &&
      typeof item.id === "string"
        ? [item.id]
        : [],
    ),
  );
}

function failureFromStreamPayload(value: unknown): GatewayFailure | null {
  if (
    typeof value !== "object" ||
    value === null ||
    !("error" in value)
  ) {
    return null;
  }
  if (typeof value.error !== "object" || value.error === null) {
    return new GatewayFailure(
      "groqMalformedResponse",
      "The Groq stream contained a malformed failure event.",
    );
  }
  const error = value.error as {
    code?: unknown;
    type?: unknown;
    message?: unknown;
  };
  const code = String(error.code ?? "").toLowerCase();
  const type = String(error.type ?? "").toLowerCase();
  const message = String(error.message ?? "").toLowerCase();
  if (
    code.includes("quota") ||
    type.includes("quota") ||
    code.includes("rate") ||
    type.includes("rate")
  ) {
    return new GatewayFailure(
      "groqRateLimited",
      "Groq is temporarily rate limited.",
    );
  }
  if (
    code.includes("auth") ||
    code.includes("key") ||
    type.includes("auth")
  ) {
    return new GatewayFailure(
      "groqAuthenticationFailed",
      "Groq rejected the server-held credential.",
    );
  }
  if (
    code.includes("model") ||
    type.includes("model") ||
    message.includes("model")
  ) {
    return new GatewayFailure(
      "groqModelUnavailable",
      "The configured Groq model is unavailable.",
    );
  }
  return new GatewayFailure(
    "groqUpstreamUnavailable",
    "The Groq stream failed before completion.",
  );
}
