import type { Request } from "express";
import { ZodError } from "zod";
import type {
  RequestVerifier,
  VerifiedPrincipal,
} from "../auth/request_verifier_port.js";
import type { GatewayConfig } from "../config.js";
import {
  AiGatewayRequestSchema,
  type AiGatewayMode,
  type AiGatewayRequest,
} from "../contracts/ai_gateway_request.js";
import { GatewayFailure, asGatewayFailure } from "../errors.js";
import { assertRequestIsMinimized } from "../security/redaction.js";
import type { RateLimiter } from "../security/rate_limiter.js";

export function parseModeRequest(
  request: Request,
  expectedMode: AiGatewayMode,
  config: Pick<GatewayConfig, "supportedClientVersion">,
): AiGatewayRequest {
  try {
    const parsed = AiGatewayRequestSchema.parse(request.body);
    if (parsed.mode !== expectedMode) {
      throw new GatewayFailure(
        "gatewayRequestInvalid",
        "The request mode does not match this endpoint.",
        { status: 400 },
      );
    }
    if (parsed.clientVersion !== config.supportedClientVersion) {
      throw new GatewayFailure(
        "gatewayRequestInvalid",
        "The client version is not supported by this gateway.",
      );
    }
    assertRequestIsMinimized(parsed);
    return parsed;
  } catch (error) {
    if (error instanceof GatewayFailure) {
      throw error;
    }
    if (error instanceof ZodError) {
      throw new GatewayFailure(
        "gatewayRequestInvalid",
        "The request did not match the exact gateway schema.",
        { status: 400 },
      );
    }
    throw error;
  }
}

export async function verifyAiRequest(
  verifier: RequestVerifier,
  request: Request,
): Promise<VerifiedPrincipal> {
  try {
    return await verifier.verify(request);
  } catch (error) {
    const failure = asGatewayFailure(error);
    if (failure.code === "unauthenticated") {
      throw new GatewayFailure(
        "gatewayAuthenticationRequired",
        "A valid Firebase authentication token is required.",
      );
    }
    if (failure.code === "appCheckRejected") {
      throw new GatewayFailure(
        "gatewayAppCheckRequired",
        "A valid Firebase App Check token is required.",
      );
    }
    throw failure;
  }
}

export function safeRequestPlatform(request: Request): string {
  const value = request.header("X-CashPilot-Platform")?.trim().toLowerCase() ?? "";
  return /^[a-z][a-z0-9_-]{0,31}$/u.test(value) ? value : "unknown";
}

export function consumeAiRateLimit(
  rateLimiter: RateLimiter,
  uid: string,
): void {
  try {
    rateLimiter.consume(uid);
  } catch (error) {
    const failure = asGatewayFailure(error);
    if (failure.code === "rateLimited") {
      throw new GatewayFailure(
        "groqRateLimited",
        "The AI request rate limit was reached.",
        failure.retryAfterSeconds === undefined
          ? {}
          : { retryAfterSeconds: failure.retryAfterSeconds },
      );
    }
    throw failure;
  }
}
