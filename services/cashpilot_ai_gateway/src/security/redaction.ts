import type { AiGatewayRequest } from "../contracts/ai_gateway_request.js";
import { GatewayFailure } from "../errors.js";

const forbiddenKeys = new Set([
  "uid",
  "userid",
  "firebaseuid",
  "email",
  "phone",
  "phonenumber",
  "token",
  "authorization",
  "appcheck",
  "receiptimage",
  "imagebytes",
  "filepath",
  "firestorepath",
  "privateNote",
  "rawtransactions",
  "transactionhistory",
  "model",
  "modelid",
].map((value) => value.toLowerCase()));

const forbiddenStringPatterns = [
  /\bBearer\s+\S+/i,
  /\beyJ[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{8,}\./,
  /\b[A-Z]:\\(?:Users|Documents|Windows)\\/i,
  /\/(?:Users|home)\/[^/\s]+/i,
  /\bgs:\/\//i,
  /\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b/,
  // Seven or more ASCII/Arabic digits in one phone-shaped run. Words and
  // normal small monetary values split the run, avoiding a total-digit-count
  // rule that would reject ordinary financial sentences.
  /(?:\+|00)?[0-9\u0660-\u0669\u06F0-\u06F9](?:[ \t\u00A0()./-]{0,3}[0-9\u0660-\u0669\u06F0-\u06F9]){6,}/u,
];

const financialLabelKeys = new Set([
  "account",
  "category",
  "name",
  "title",
]);

function inspectPrivateText(value: string, path: string): void {
  if (forbiddenStringPatterns.some((pattern) => pattern.test(value))) {
    throw new GatewayFailure(
      "gatewayRequestInvalid",
      `Private or credential-like data was rejected at ${path}.`,
      { status: 422 },
    );
  }
}

function inspectForbiddenKeys(value: unknown, path: string): void {
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      inspectForbiddenKeys(item, `${path}[${index}]`),
    );
    return;
  }
  if (value !== null && typeof value === "object") {
    for (const [key, nested] of Object.entries(value)) {
      if (forbiddenKeys.has(key.toLowerCase())) {
        throw new GatewayFailure(
          "gatewayRequestInvalid",
          `Private field ${path}.${key} is not accepted.`,
          { status: 422 },
        );
      }
      inspectForbiddenKeys(nested, `${path}.${key}`);
    }
  }
}

function inspectFinancialLabels(value: unknown, path: string): void {
  if (Array.isArray(value)) {
    value.forEach((item, index) =>
      inspectFinancialLabels(item, `${path}[${index}]`),
    );
    return;
  }
  if (value !== null && typeof value === "object") {
    for (const [key, nested] of Object.entries(value)) {
      const nestedPath = `${path}.${key}`;
      if (financialLabelKeys.has(key) && typeof nested === "string") {
        inspectPrivateText(nested, nestedPath);
      } else if (typeof nested !== "string") {
        inspectFinancialLabels(nested, nestedPath);
      }
    }
  }
}

export function assertRequestIsMinimized(request: AiGatewayRequest): void {
  // The strict request schema already validates identifiers, enums, decimal
  // strings, dates, currencies, and tool IDs. Scanning those structural values
  // as prose creates phone-number false positives (notably for UUIDs and ISO
  // dates), so private-text patterns apply only to user-authored text surfaces.
  // Forbidden keys remain a recursive whole-request defense in depth.
  inspectForbiddenKeys(request, "request");
  request.sanitizedMessages.forEach((message, index) =>
    inspectPrivateText(
      message.content,
      `request.sanitizedMessages[${index}].content`,
    ),
  );
  if (request.compactMemorySummary !== undefined) {
    inspectPrivateText(
      request.compactMemorySummary,
      "request.compactMemorySummary",
    );
  }
  if (request.sanitizedFinancialContext !== undefined) {
    inspectFinancialLabels(
      request.sanitizedFinancialContext,
      "request.sanitizedFinancialContext",
    );
  }
}
