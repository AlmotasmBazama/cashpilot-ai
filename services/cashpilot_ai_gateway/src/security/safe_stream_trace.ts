import type { AiGatewayEvent } from "../contracts/ai_gateway_event.js";
import type {
  GroqStreamObserver,
  UpstreamStatusCategory,
} from "../groq/groq_transport.js";

export interface SafeStreamLogEntry {
  readonly kind: "cashpilot_ai_stream";
  readonly requestId: string;
  readonly route: string;
  readonly appVersion: string;
  readonly platform: string;
  readonly selectedModelAlias: string;
  readonly selectedModel: string;
  readonly upstreamHttpStatusCategory: UpstreamStatusCategory | "notStarted";
  readonly upstreamAttemptStatusCategories: readonly UpstreamStatusCategory[];
  readonly upstreamChunks: number;
  readonly normalizedSseEventTypes: readonly AiGatewayEvent["type"][];
  readonly finalCode: string;
  readonly typedErrorCode: string;
  readonly statusCode: number;
  readonly durationMs: number;
  readonly timeToFirstContentMs: number | null;
  readonly completionDurationMs: number | null;
  readonly retryCount: number;
  readonly rateLimitResult: "allowed" | "limited";
}

export type SafeStreamLogSink = (entry: SafeStreamLogEntry) => void;

export const defaultSafeStreamLogSink: SafeStreamLogSink = (entry) => {
  // This closed schema intentionally has no prompt, response, credential,
  // authorization header, UID, or financial-context field.
  console.info(JSON.stringify(entry));
};

export class SafeStreamTrace implements GroqStreamObserver {
  private selectedModelAlias = "notSelected";
  private selectedModel = "notSelected";
  private upstreamHttpStatusCategory:
    | UpstreamStatusCategory
    | "notStarted" = "notStarted";
  private readonly upstreamAttemptStatusCategories:
    UpstreamStatusCategory[] = [];
  private upstreamChunks = 0;
  private readonly eventTypes = new Set<AiGatewayEvent["type"]>();
  private finished = false;
  private retryCount = 0;
  private rateLimitResult: "allowed" | "limited" = "allowed";
  private readonly startedAt: number;
  private firstContentAt: number | undefined;

  constructor(
    private readonly requestId: string,
    private readonly route: string,
    private readonly sink: SafeStreamLogSink = defaultSafeStreamLogSink,
    private readonly metadata: {
      readonly appVersion?: string;
      readonly platform?: string;
    } = {},
    private readonly now: () => number = Date.now,
  ) {
    this.startedAt = now();
  }

  selectModel(alias: string, model = alias): void {
    this.selectedModelAlias = alias;
    this.selectedModel = model;
  }

  onHttpStatus(category: UpstreamStatusCategory): void {
    this.upstreamHttpStatusCategory = category;
    this.upstreamAttemptStatusCategories.push(category);
  }

  onChunk(): void {
    this.upstreamChunks += 1;
  }

  recordEvent(type: AiGatewayEvent["type"]): void {
    this.eventTypes.add(type);
    if (type === "textDelta" && this.firstContentAt === undefined) {
      this.firstContentAt = this.now();
    }
  }

  recordRetry(): void {
    this.retryCount += 1;
  }

  recordRateLimited(): void {
    this.rateLimitResult = "limited";
  }

  get receivedUpstreamChunks(): number {
    return this.upstreamChunks;
  }

  finish(finalCode: string, statusCode = 200): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    const finishedAt = this.now();
    const durationMs = Math.max(0, finishedAt - this.startedAt);
    this.sink({
      kind: "cashpilot_ai_stream",
      requestId: this.requestId,
      route: this.route,
      appVersion: this.metadata.appVersion ?? "unknown",
      platform: this.metadata.platform ?? "unknown",
      selectedModelAlias: this.selectedModelAlias,
      selectedModel: this.selectedModel,
      upstreamHttpStatusCategory: this.upstreamHttpStatusCategory,
      upstreamAttemptStatusCategories: [
        ...this.upstreamAttemptStatusCategories,
      ],
      upstreamChunks: this.upstreamChunks,
      normalizedSseEventTypes: [...this.eventTypes],
      finalCode,
      typedErrorCode: finalCode === "completed" ? "none" : finalCode,
      statusCode,
      durationMs,
      timeToFirstContentMs:
        this.firstContentAt === undefined
          ? null
          : Math.max(0, this.firstContentAt - this.startedAt),
      completionDurationMs:
        this.firstContentAt === undefined
          ? null
          : Math.max(0, finishedAt - this.firstContentAt),
      retryCount: this.retryCount,
      rateLimitResult: this.rateLimitResult,
    });
  }
}
