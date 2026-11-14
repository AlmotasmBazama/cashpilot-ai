import type { Request, Response } from "express";
import { gatewayServiceVersion, type GatewayConfig } from "../config.js";

export function healthRoute(config: GatewayConfig) {
  return (_request: Request, response: Response): void => {
    const firebaseConfigured = config.firebaseProjectId.trim().length > 0;
    const groqConfigured = config.groqApiKey.trim().length > 0;
    response
      .status(200)
      .setHeader("Cache-Control", "no-store")
      .json({
        status: "success",
        serviceVersion: gatewayServiceVersion,
        environment: config.environment,
        supportedClientVersion: config.supportedClientVersion,
        readiness: {
          ready: firebaseConfigured && groqConfigured,
          firebase: firebaseConfigured ? "configured" : "notConfigured",
          groq: groqConfigured ? "configured" : "notConfigured",
        },
      });
  };
}
