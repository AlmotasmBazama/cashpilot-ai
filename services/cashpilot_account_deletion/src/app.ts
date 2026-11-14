import { randomUUID } from "node:crypto";
import express, {
  type ErrorRequestHandler,
  type Express,
  type RequestHandler,
} from "express";
import type { AccountDeletionConfig } from "./config.js";
import { asGatewayFailure } from "./errors.js";
import type { SafeAccountDeletionLogEvent } from "./observability.js";
import {
  accountAuthDeletionRoute,
  accountDeletionRoute,
} from "./routes/account_deletion.js";
import type { AccountDeletionDependencies } from "./routes/dependencies.js";
import { healthRoute } from "./routes/health.js";
import { exactCorsPolicy } from "./security/cors_policy.js";
import {
  rejectMalformedJson,
  rejectOversizedBody,
  requireJsonPost,
} from "./security/request_limits.js";

export type AccountDeletionAppDependencies = AccountDeletionDependencies & {
  readonly config: AccountDeletionConfig;
};

function requestContextMiddleware(): RequestHandler {
  return (request, response, next) => {
    const supplied = request.header("X-Request-ID")?.trim() ?? "";
    const correlationId = /^[A-Za-z0-9_-]{8,80}$/u.test(supplied)
      ? supplied
      : randomUUID();
    response.locals.correlationId = correlationId;
    response.locals.startedAtMs = Date.now();
    response.setHeader("X-Request-ID", correlationId);
    next();
  };
}

export function createAccountDeletionApp(
  dependencies: AccountDeletionAppDependencies,
): Express {
  const app = express();
  app.disable("x-powered-by");
  app.use(requestContextMiddleware());
  app.use((_request, response, next) => {
    response.setHeader("Cache-Control", "no-store");
    response.setHeader("Pragma", "no-cache");
    response.setHeader("X-Content-Type-Options", "nosniff");
    response.setHeader("Referrer-Policy", "no-referrer");
    response.on("finish", () => {
      const event: SafeAccountDeletionLogEvent = {
        correlationId: response.locals.correlationId as string,
        serviceRevision: dependencies.serviceRevision,
        stage: "responseSent",
        durationMs: Date.now() - (response.locals.startedAtMs as number),
        attempt: 1,
        resultCode:
          (response.locals.failureCode as string | undefined) ?? "completed",
        httpStatus: response.statusCode,
        retryable:
          (response.locals.retryable as boolean | undefined) ?? false,
        ...(typeof response.locals.operationId === "string"
          ? { operationId: response.locals.operationId as string }
          : {}),
        ...(typeof response.locals.safeErrorClass === "string"
          ? { safeErrorClass: response.locals.safeErrorClass as string }
          : {}),
      };
      dependencies.logSink.write(event);
    });
    next();
  });
  app.use(exactCorsPolicy(dependencies.config.allowedOrigins));
  app.get("/health", healthRoute(dependencies.config));
  app.use(
    express.json({
      limit: dependencies.config.maxBodyBytes,
      strict: true,
      type: "application/json",
    }),
  );

  const post = (path: string, handler: RequestHandler) => {
    app.post(path, requireJsonPost, (request, response, next) => {
      Promise.resolve(handler(request, response, next)).catch(next);
    });
    app.all(path, requireJsonPost);
  };
  post("/v1/account-deletion/recursive", accountDeletionRoute(dependencies));
  post("/v1/account-deletion/auth", accountAuthDeletionRoute(dependencies));

  app.use((_request, response) => {
    response.status(404).json({
      failure: {
        code: "gatewayRequestInvalid",
        message: "The requested account deletion route does not exist.",
      },
    });
  });

  const errorHandler: ErrorRequestHandler = (
    error,
    _request,
    response,
    _next,
  ) => {
    const failure =
      rejectOversizedBody(error) ??
      rejectMalformedJson(error) ??
      asGatewayFailure(error);
    if (response.headersSent) {
      response.end();
      return;
    }
    if (failure.retryAfterSeconds !== undefined) {
      response.setHeader("Retry-After", failure.retryAfterSeconds.toString());
    }
    response.locals.failureCode = failure.code;
    response.locals.retryable = failure.retryable;
    response.locals.safeErrorClass = failure.safeErrorClass;
    response.status(failure.status).json({
      failure: {
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable,
      },
    });
  };
  app.use(errorHandler);
  return app;
}
