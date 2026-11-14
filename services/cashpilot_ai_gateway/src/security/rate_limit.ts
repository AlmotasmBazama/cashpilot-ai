import { GatewayFailure } from "../errors.js";
import type { RateLimiter } from "./rate_limiter.js";

export type { RateLimiter } from "./rate_limiter.js";

interface Bucket {
  readonly timestamps: number[];
}

export class PerUserSlidingWindowRateLimiter implements RateLimiter {
  private readonly buckets = new Map<string, Bucket>();

  constructor(
    private readonly maxRequests: number,
    private readonly windowMs = 60_000,
  ) {}

  consume(uid: string, now = Date.now()): void {
    const minimum = now - this.windowMs;
    const previous = this.buckets.get(uid)?.timestamps ?? [];
    const active = previous.filter((timestamp) => timestamp > minimum);
    if (active.length >= this.maxRequests) {
      const retryAfterMs = Math.max(1, active[0]! + this.windowMs - now);
      throw new GatewayFailure(
        "rateLimited",
        "The per-user request limit was reached.",
        { retryAfterSeconds: Math.ceil(retryAfterMs / 1_000) },
      );
    }
    active.push(now);
    this.buckets.set(uid, { timestamps: active });
    if (this.buckets.size > 10_000) {
      for (const [key, bucket] of this.buckets) {
        if (bucket.timestamps.every((timestamp) => timestamp <= minimum)) {
          this.buckets.delete(key);
        }
      }
    }
  }
}
