import type { NextFunction, Request, Response } from "express";
import { GatewayFailure } from "../errors.js";

export function exactCorsPolicy(allowedOrigins: ReadonlySet<string>) {
  return (request: Request, response: Response, next: NextFunction): void => {
    const origin = request.header("Origin");
    if (origin !== undefined) {
      if (!allowedOrigins.has(origin)) {
        next(
          new GatewayFailure(
            "gatewayRequestInvalid",
            "This web origin is not allowed.",
            { status: 403, retryable: false },
          ),
        );
        return;
      }
      response.setHeader("Access-Control-Allow-Origin", origin);
      response.setHeader("Vary", "Origin");
      response.setHeader(
        "Access-Control-Allow-Headers",
        "Authorization, Content-Type, X-Firebase-AppCheck, " +
          "X-Cashpilot-Deletion-Session, X-Request-ID",
      );
      response.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
      response.setHeader("Access-Control-Max-Age", "600");
    }
    if (request.method === "OPTIONS") {
      response.status(204).end();
      return;
    }
    next();
  };
}
