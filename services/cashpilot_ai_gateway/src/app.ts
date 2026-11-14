import { randomUUID } from "node:crypto";
import express, {
  type ErrorRequestHandler,
  type Express,
  type RequestHandler,
} from "express";
import { asGatewayFailure } from "./errors.js";
import { accountAuthDeletionRoute, accountDeletionRoute } from "./routes/account_deletion.js";
import type { RouteDependencies } from "./routes/dependencies.js";
import { diagnosticsRoute } from "./routes/diagnostics.js";
import { financialExplanationRoute } from "./routes/financial_explanation.js";
import { generalChatRoute } from "./routes/general_chat.js";
import { healthRoute } from "./routes/health.js";
import { toolSelectionRoute } from "./routes/tool_selection.js";
import { exactCorsPolicy } from "./security/cors_policy.js";
import {
  rejectMalformedJson,
  rejectOversizedBody,
  requireJsonPost,
} from "./security/request_limits.js";

/// Public compatibility name for the complete application dependency set.
/// Route factories may narrow this type independently without duplicating the
/// production composition contract.
export type GatewayDependencies = RouteDependencies;

function requestIdMiddleware(): RequestHandler {
  return (request, response, next) => {
    const supplied = request.header("X-Request-ID")?.trim() ?? "";
    const requestId = /^[A-Za-z0-9_-]{8,80}$/.test(supplied)
      ? supplied
      : randomUUID();
    response.locals.requestId = requestId;
    response.setHeader("X-Request-ID", requestId);
    next();
  };
}

export function createGatewayApp(
  dependencies: GatewayDependencies,
): Express {
  const app = express();
  app.disable("x-powered-by");
  app.use(requestIdMiddleware());
  app.use(exactCorsPolicy(dependencies.config.allowedOrigins));
  app.use((_request, response, next) => {
    response.setHeader("Cache-Control", "no-store");
    response.setHeader("Pragma", "no-cache");
    response.setHeader("X-Content-Type-Options", "nosniff");
    response.setHeader("Referrer-Policy", "no-referrer");
    next();
  });
  app.get("/health", healthRoute(dependencies.config));
  app.use(
    express.json({
      limit: dependencies.config.maxBodyBytes,
      strict: true,
      type: "application/json",
    }),
  );

  const postPaths: string[] = [];
  const post = (path: string, handler: RequestHandler) => {
    postPaths.push(path);
    app.post(path, requireJsonPost, (request, response, next) => {
      Promise.resolve(handler(request, response, next)).catch(next);
    });
  };
  post("/v1/ai/general-chat", generalChatRoute(dependencies));
  post(
    "/v1/ai/financial-explanation",
    financialExplanationRoute(dependencies),
  );
  post("/v1/ai/tool-selection", toolSelectionRoute(dependencies));
  post("/v1/diagnostics", diagnosticsRoute(dependencies));
  post(
    "/v1/account-deletion/recursive",
    accountDeletionRoute(dependencies),
  );
  post(
    "/v1/account-deletion/auth",
    accountAuthDeletionRoute(dependencies),
  );
  for (const path of postPaths) {
    app.all(path, requireJsonPost);
  }

  app.use((_request, response) => {
    response.status(404).json({
      failure: {
        code: "gatewayRequestInvalid",
        message: "The requested gateway route does not exist.",
      },
    });
  });

  const errorHandler: ErrorRequestHandler = (
    error,
    _request,
    response,
    _next,
  ) => {
    const oversized = rejectOversizedBody(error);
    const malformedJson = rejectMalformedJson(error);
    const failure = oversized ?? malformedJson ?? asGatewayFailure(error);
    if (response.headersSent) {
      response.end();
      return;
    }
    if (failure.retryAfterSeconds !== undefined) {
      response.setHeader(
        "Retry-After",
        failure.retryAfterSeconds.toString(),
      );
    }
    response.locals.failureCode = failure.code;
    response.setHeader("Cache-Control", "no-store");
    response.setHeader("Pragma", "no-cache");
    response.status(failure.status).json({
      failure: {
        code: failure.code,
        message: failure.message,
      },
      requestId: response.locals.requestId,
    });
  };
  app.use(errorHandler);
  return app;
}
