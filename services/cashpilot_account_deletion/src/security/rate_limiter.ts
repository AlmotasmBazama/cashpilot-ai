export interface RateLimiter {
  consume(key: string): void;
}
