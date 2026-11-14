import type { Request, Response } from "express";
import { GatewayFailure } from "../errors.js";

export function boundedAbortController(
  request: Request,
  response: Response,
  durationMs: number,
  timeoutCode: "groqRequestTimedOut" | "groqStreamTimedOut",
): { readonly controller: AbortController; readonly dispose: () => void } {
  const controller = new AbortController();
  const timer = setTimeout(
    () =>
      controller.abort(
        new GatewayFailure(
          timeoutCode,
          timeoutCode === "groqStreamTimedOut"
            ? "The gateway stream timed out."
            : "The gateway request timed out.",
        ),
      ),
    durationMs,
  );
  const disconnected = () =>
    controller.abort(
      new GatewayFailure(
        "gatewayUnavailable",
        "The client disconnected from the gateway.",
      ),
    );
  const responseClosed = () => {
    if (!response.writableEnded) {
      disconnected();
    }
  };
  request.once("aborted", disconnected);
  response.once("close", responseClosed);
  // Authentication can await network verification before listeners attach.
  // A disconnect during that wait must not start a new provider request.
  if (request.aborted || (response.destroyed && !response.writableEnded)) {
    disconnected();
  }
  return {
    controller,
    dispose: () => {
      clearTimeout(timer);
      request.off("aborted", disconnected);
      response.off("close", responseClosed);
    },
  };
}
