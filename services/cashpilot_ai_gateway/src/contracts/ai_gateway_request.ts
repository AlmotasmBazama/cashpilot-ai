import { z } from "zod";
import { SanitizedFinancialContextSchema } from "./financial_context.js";

export const AiGatewayModeSchema = z.enum([
  "generalConversation",
  "financialExplanation",
  "governedToolSelection",
]);
export type AiGatewayMode = z.infer<typeof AiGatewayModeSchema>;

export const AiGatewayMessageSchema = z
  .object({
    role: z.enum(["user", "assistant"]),
    content: z.string().trim().min(1).max(2_000),
  })
  .strict();
export type AiGatewayMessage = z.infer<typeof AiGatewayMessageSchema>;

export const AiGatewayRequestSchema = z
  .object({
    requestId: z.string().regex(/^[A-Za-z0-9_-]{8,80}$/),
    mode: AiGatewayModeSchema,
    locale: z
      .string()
      .regex(/^[a-z]{2}(?:[-_][A-Za-z0-9]{2,8})?$/i)
      .max(16),
    sanitizedMessages: z.array(AiGatewayMessageSchema).min(1).max(8),
    compactMemorySummary: z.string().trim().max(2_000).optional(),
    sanitizedFinancialContext: SanitizedFinancialContextSchema.optional(),
    allowedToolIds: z
      .array(z.string().regex(/^[a-z][a-z0-9_]{1,63}$/))
      .max(20)
      .optional(),
    timeoutClass: z.enum(["interactive", "analysis"]),
    clientVersion: z.string().trim().min(1).max(64),
    responseMode: z.enum(["stream", "json"]).optional(),
  })
  .strict()
  .superRefine((value, context) => {
    if (
      value.mode === "financialExplanation" &&
      value.sanitizedFinancialContext === undefined
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["sanitizedFinancialContext"],
        message: "Financial context is required for financial explanation.",
      });
    }
    if (
      value.mode !== "financialExplanation" &&
      value.sanitizedFinancialContext !== undefined
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["sanitizedFinancialContext"],
        message: "Financial context is not accepted for this mode.",
      });
    }
    if (
      value.mode === "governedToolSelection" &&
      (value.allowedToolIds === undefined ||
        value.allowedToolIds.length === 0)
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["allowedToolIds"],
        message: "At least one allowed tool is required.",
      });
    }
    if (
      value.mode !== "governedToolSelection" &&
      value.allowedToolIds !== undefined
    ) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["allowedToolIds"],
        message: "Tool IDs are not accepted for this mode.",
      });
    }
  });

export type AiGatewayRequest = z.infer<typeof AiGatewayRequestSchema>;
