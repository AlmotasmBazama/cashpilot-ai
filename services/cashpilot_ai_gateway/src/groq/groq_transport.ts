export interface UpstreamMessage {
  readonly role: "system" | "user" | "assistant";
  readonly content: string;
}

export interface GroqCompletionRequest {
  readonly model: string;
  readonly messages: readonly UpstreamMessage[];
  readonly maxOutputTokens: number;
  readonly temperature: number;
  readonly responseFormat?: Record<string, unknown>;
  readonly reasoningEffort?: "low" | "medium" | "high";
  readonly reasoningFormat?: "hidden";
}

export type UpstreamStatusCategory =
  | "success"
  | "clientError"
  | "authenticationRejected"
  | "rateLimited"
  | "capacityUnavailable"
  | "serverError"
  | "timeout"
  | "networkFailure";

export interface GroqStreamObserver {
  onHttpStatus(category: UpstreamStatusCategory): void;
  onChunk(): void;
}

export interface GroqTransport {
  complete(
    request: GroqCompletionRequest,
    signal?: AbortSignal,
    observer?: GroqStreamObserver,
  ): Promise<string>;

  stream(
    request: GroqCompletionRequest,
    onDelta: (delta: string) => void,
    signal?: AbortSignal,
    observer?: GroqStreamObserver,
  ): Promise<void>;

  availableModelIds(signal?: AbortSignal): Promise<ReadonlySet<string>>;
}
