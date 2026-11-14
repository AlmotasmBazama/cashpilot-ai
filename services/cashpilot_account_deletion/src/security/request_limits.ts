import type { NextFunction, Request, Response } from "express";
import { GatewayFailure } from "../errors.js";

export function requireJsonPost(
  request: Request,
  _response: Response,
  next: NextFunction,
): void {
  if (request.method !== "POST") {
    next(
      new GatewayFailure(
        "gatewayRequestInvalid",
        "Only POST is supported for this endpoint.",
        { status: 405 },
      ),
    );
    return;
  }
  if (!request.is("application/json")) {
    next(
      new GatewayFailure(
        "gatewayRequestInvalid",
        "Content-Type must be application/json.",
        { status: 415 },
      ),
    );
    return;
  }
  next();
}

export function rejectOversizedBody(error: unknown): GatewayFailure | null {
  if (
    typeof error === "object" &&
    error !== null &&
    "type" in error &&
    error.type === "entity.too.large"
  ) {
    return new GatewayFailure(
      "requestTooLarge",
      "The request body is too large.",
    );
  }
  return null;
}

export function rejectMalformedJson(error: unknown): GatewayFailure | null {
  if (
    error instanceof SyntaxError &&
    typeof error === "object" &&
    error !== null &&
    "status" in error &&
    error.status === 400
  ) {
    return new GatewayFailure(
      "gatewayRequestInvalid",
      "The request body was not valid JSON.",
    );
  }
  return null;
}
