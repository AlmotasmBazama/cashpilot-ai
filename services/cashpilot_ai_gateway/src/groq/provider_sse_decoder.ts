import { GatewayFailure } from "../errors.js";
import type { GroqStreamObserver } from "./groq_transport.js";
import { normalizeTransportFailure } from "./groq_transport_support.js";

const maxProviderStreamBytes = 2 * 1024 * 1024;
const maxProviderSseLineCharacters = 64 * 1024;
const maxProviderSseEventCharacters = 128 * 1024;

export async function* providerSseData(
  body: ReadableStream<Uint8Array>,
  signal: AbortSignal,
  observer?: GroqStreamObserver,
): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let pending = "";
  let dataLines: string[] = [];
  let eventCharacters = 0;
  let streamBytes = 0;
  let finishedReading = false;

  const acceptLine = (lineValue: string, frames: string[]): void => {
    const line = lineValue.endsWith("\r")
      ? lineValue.slice(0, -1)
      : lineValue;
    if (line.length > maxProviderSseLineCharacters) {
      throw new GatewayFailure(
        "groqMalformedResponse",
        "A Groq SSE line exceeded the safe limit.",
      );
    }
    if (line.length === 0) {
      if (dataLines.length > 0) {
        frames.push(dataLines.join("\n"));
        dataLines = [];
        eventCharacters = 0;
      }
      return;
    }
    if (line.startsWith(":")) {
      return;
    }
    const separator = line.indexOf(":");
    const field = separator < 0 ? line : line.slice(0, separator);
    let value = separator < 0 ? "" : line.slice(separator + 1);
    if (value.startsWith(" ")) {
      value = value.slice(1);
    }
    if (field === "data") {
      eventCharacters += value.length;
      if (eventCharacters > maxProviderSseEventCharacters) {
        throw new GatewayFailure(
          "groqMalformedResponse",
          "A Groq SSE event exceeded the safe limit.",
        );
      }
      dataLines.push(value);
    }
  };

  const consumeAvailableLines = (flush: boolean): string[] => {
    const frames: string[] = [];
    for (;;) {
      const newline = pending.indexOf("\n");
      if (newline < 0) {
        break;
      }
      const line = pending.slice(0, newline);
      pending = pending.slice(newline + 1);
      acceptLine(line, frames);
    }
    if (pending.length > maxProviderSseLineCharacters) {
      throw new GatewayFailure(
        "groqMalformedResponse",
        "A Groq SSE line exceeded the safe limit.",
      );
    }
    if (flush && pending.length > 0) {
      const line = pending;
      pending = "";
      acceptLine(line, frames);
    }
    if (flush && dataLines.length > 0) {
      frames.push(dataLines.join("\n"));
      dataLines = [];
      eventCharacters = 0;
    }
    return frames;
  };

  try {
    for (;;) {
      let item: ReadableStreamReadResult<Uint8Array>;
      try {
        item = await reader.read();
      } catch (error) {
        throw normalizeTransportFailure(
          error,
          signal,
          "groqStreamTimedOut",
        );
      }
      if (item.value !== undefined && item.value.length > 0) {
        observer?.onChunk();
        streamBytes += item.value.length;
        if (streamBytes > maxProviderStreamBytes) {
          throw new GatewayFailure(
            "groqMalformedResponse",
            "The Groq stream exceeded the safe size limit.",
          );
        }
        try {
          pending += decoder.decode(item.value, { stream: true });
        } catch {
          throw new GatewayFailure(
            "groqMalformedResponse",
            "The Groq stream was not valid UTF-8 SSE.",
          );
        }
        for (const frame of consumeAvailableLines(false)) {
          yield frame;
        }
      }
      if (item.done) {
        try {
          pending += decoder.decode();
        } catch {
          throw new GatewayFailure(
            "groqMalformedResponse",
            "The Groq stream was not valid UTF-8 SSE.",
          );
        }
        for (const frame of consumeAvailableLines(true)) {
          yield frame;
        }
        finishedReading = true;
        return;
      }
    }
  } finally {
    if (!finishedReading) {
      try {
        await reader.cancel();
      } catch {
        // Cancellation is best-effort after a bounded failure/disconnect.
      }
    }
    reader.releaseLock();
  }
}
