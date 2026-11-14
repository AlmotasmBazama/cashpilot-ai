import type { Request, Response } from "express";
import {
  accountDeletionServiceVersion,
  type AccountDeletionConfig,
} from "../config.js";

export function healthRoute(config: AccountDeletionConfig) {
  return (_request: Request, response: Response): void => {
    response.status(200).json({
      status: "ok",
      service: "cashpilot-account-deletion",
      version: accountDeletionServiceVersion,
      environment: config.environment,
    });
  };
}
