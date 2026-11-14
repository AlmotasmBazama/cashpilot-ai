import type { SanitizedFinancialContext } from "../contracts/financial_context.js";
import { GatewayFailure } from "../errors.js";
import { hasUnverifiedMutationClaim } from "../security/provider_output_safety.js";
import type {
  FinancialFigureDimension,
  GroundedFinancialFigure,
} from "./financial_figure_contracts.js";
import {
  financialFigurePattern,
  normalizeDate,
  normalizeDecimal,
} from "./financial_figure_normalization.js";
import { financialFieldDimensions } from "./financial_grounding_catalog.js";

function groundedFiguresForValue(
  value: unknown,
  toolId: string,
  field: string,
  dimensions: Readonly<Record<string, FinancialFigureDimension>>,
  target: GroundedFinancialFigure[],
): void {
  if (typeof value === "number") {
    const dimension = dimensions[field];
    if (
      dimension !== "count" ||
      !Number.isSafeInteger(value) ||
      value < 0 ||
      value > 1_000_000_000
    ) {
      return;
    }
    target.push({
      canonical: value.toString(),
      dimension,
      provenance: { toolId, field },
    });
    return;
  }
  if (typeof value === "string") {
    const dimension = dimensions[field];
    if (dimension === undefined) {
      return;
    }
    const provenance = { toolId, field };
    if (dimension === "date") {
      const date = normalizeDate(value);
      if (date !== null) {
        target.push({
          canonical: date.canonical,
          dimension,
          provenance,
        });
        for (const component of date.components) {
          target.push({ canonical: component, dimension, provenance });
        }
      }
      return;
    }
    const decimal = normalizeDecimal(value);
    if (
      decimal === null ||
      (dimension !== "percent" && decimal.percent) ||
      (dimension === "count" &&
        (decimal.canonical.startsWith("-") ||
          decimal.canonical.includes(".")))
    ) {
      return;
    }
    target.push({
      canonical: decimal.canonical,
      dimension,
      provenance,
    });
    return;
  }
  if (!Array.isArray(value)) {
    return;
  }
  for (const item of value) {
    if (item === null || typeof item !== "object" || Array.isArray(item)) {
      continue;
    }
    for (const [nestedField, nestedValue] of Object.entries(item)) {
      groundedFiguresForValue(
        nestedValue,
        toolId,
        `${field}[].${nestedField}`,
        dimensions,
        target,
      );
    }
  }
}

function collectGroundedFinancialFigures(
  context: SanitizedFinancialContext,
): GroundedFinancialFigure[] {
  const result: GroundedFinancialFigure[] = [];
  for (const record of context.records) {
    const dimensions = financialFieldDimensions[record.toolId];
    if (dimensions === undefined) {
      continue;
    }
    for (const [field, value] of Object.entries(record.values)) {
      groundedFiguresForValue(
        value,
        record.toolId,
        field,
        dimensions,
        result,
      );
    }
  }
  return result;
}

const percentPrefix =
  /(?:percentage|percent|(?:savings|change)\s+rate|\u0646\u0633\u0628\u0629)\s*(?:(?:is|was)|\u0647\u064a|\u0647\u0648|:)?\s*$/iu;
const percentSuffix =
  /^\s*(?:percent(?:age)?|percentage\s+points?|\u0628\u0627\u0644\u0645\u0626\u0629|\u0628\u0627\u0644\u0645\u0627\u0626\u0629|\u0641\u064a\s+\u0627\u0644\u0645\u0626\u0629)(?!\p{L})/iu;
const countSuffix =
  /^\s*(?:(?:active|completed|matching|recurring|open|closed|total)\s+){0,3}(?:transactions?|accounts?|budgets?|goals?|categories|records?|patterns?|months?|days?|weeks?|years?|items?|entries|\u0645\u0639\u0627\u0645\u0644\u0629|\u0645\u0639\u0627\u0645\u0644\u0627\u062a|\u062d\u0633\u0627\u0628|\u062d\u0633\u0627\u0628\u0627\u062a|\u0645\u064a\u0632\u0627\u0646\u064a\u0629|\u0645\u064a\u0632\u0627\u0646\u064a\u0627\u062a|\u0647\u062f\u0641|\u0623\u0647\u062f\u0627\u0641|\u0641\u0626\u0629|\u0641\u0626\u0627\u062a|\u0646\u0645\u0637|\u0623\u0646\u0645\u0627\u0637|\u0634\u0647\u0631|\u0623\u0634\u0647\u0631|\u064a\u0648\u0645|\u0623\u064a\u0627\u0645|\u0633\u062c\u0644|\u0633\u062c\u0644\u0627\u062a|\u0639\u0646\u0635\u0631|\u0639\u0646\u0627\u0635\u0631|\u0645\u0631\u0629|\u0645\u0631\u0627\u062a)(?!\p{L})/iu;
const countPrefix =
  /(?:there\s+(?:are|were|is)|number\s+of|count\s*(?:(?:is|was)|:)|\u0647\u0646\u0627\u0643|\u064a\u0648\u062c\u062f|\u062a\u0648\u062c\u062f|\u0639\u062f\u062f(?:\u0647\u0627|\u0647\u0645)?)\s*$/iu;
const datePrefix =
  /(?:date|year|month|day|as\s+of|target\s+year|\u062a\u0627\u0631\u064a\u062e|\u0633\u0646\u0629|\u0634\u0647\u0631|\u064a\u0648\u0645)\s*(?:(?:is|was)|:)?\s*$/iu;
const dateSuffix =
  /^\s*(?:year|month|day|\u0633\u0646\u0629|\u0634\u0647\u0631|\u064a\u0648\u0645)(?!\p{L})/iu;
const ratePrefix =
  /(?:(?:(?:exchange|conversion|stored)\s+)?rate|ratio|\u0633\u0639\u0631\s+\u0627\u0644\u0635\u0631\u0641|\u0645\u0639\u0627\u0645\u0644\s+\u0627\u0644\u062a\u062d\u0648\u064a\u0644)\s*(?:(?:is|was)|:)?\s*$/iu;
const amountPrefix =
  /(?:income|expenses?|savings?|balance|net\s+worth|cash\s+flow|spent|spending|remaining|allowance|contribution|target|amount|budget\s+limit|difference|\u062f\u062e\u0644|\u0645\u0635\u0631\u0648\u0641|\u0646\u0641\u0642\u0627\u062a|\u0631\u0635\u064a\u062f|\u0627\u062f\u062e\u0627\u0631|\u0645\u0628\u0644\u063a)\s*(?:(?:is|are|was|were|of)|:)?\s*$/iu;
const amountSuffix =
  /^\s*(?:[A-Z]{3}|[$أ¢â€ڑآ¬ط¢آ£]|\u062f\.?\s*\u0644|\u062f\u064a\u0646\u0627\u0631|\u062f\u0648\u0644\u0627\u0631|\u064a\u0648\u0631\u0648)(?!\p{L})/iu;

function inferredDimension(
  text: string,
  start: number,
  end: number,
): FinancialFigureDimension | undefined {
  const prefix = text.slice(Math.max(0, start - 64), start);
  const suffix = text.slice(end, Math.min(text.length, end + 64));
  if (percentPrefix.test(prefix) || percentSuffix.test(suffix)) {
    return "percent";
  }
  if (datePrefix.test(prefix) || dateSuffix.test(suffix)) {
    return "date";
  }
  if (countPrefix.test(prefix) || countSuffix.test(suffix)) {
    return "count";
  }
  if (ratePrefix.test(prefix)) {
    return "rate";
  }
  if (amountPrefix.test(prefix) || amountSuffix.test(suffix)) {
    return "amount";
  }
  return undefined;
}

export function unsupportedFinancialFigures(
  text: string,
  context: SanitizedFinancialContext,
): string[] {
  const grounded = collectGroundedFinancialFigures(context);
  const unsupported = new Set<string>();
  for (const match of text.matchAll(financialFigurePattern)) {
    const raw = match[0];
    const start = match.index;
    const date = normalizeDate(raw);
    if (date !== null) {
      if (
        !grounded.some(
          (figure) =>
            figure.dimension === "date" &&
            figure.canonical === date.canonical,
        )
      ) {
        unsupported.add(raw);
      }
      continue;
    }

    const decimal = normalizeDecimal(raw);
    if (decimal === null) {
      unsupported.add(raw);
      continue;
    }
    const dimension = decimal.percent
      ? "percent"
      : inferredDimension(text, start, start + raw.length);
    if (
      !grounded.some(
        (figure) =>
          figure.canonical === decimal.canonical &&
          (dimension === undefined || figure.dimension === dimension),
      )
    ) {
      unsupported.add(raw);
    }
  }
  return [...unsupported];
}

export function assertFinancialAnswerIsGrounded(
  text: string,
  context: SanitizedFinancialContext,
): void {
  if (text.trim().length === 0 || text.length > 8_000) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The financial explanation was empty or oversized.",
    );
  }
  const unsupported = unsupportedFinancialFigures(text, context);
  if (unsupported.length > 0) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The financial explanation introduced unsupported figures.",
    );
  }
  if (hasUnverifiedMutationClaim(text)) {
    throw new GatewayFailure(
      "groqMalformedResponse",
      "The financial explanation falsely claimed a financial mutation.",
    );
  }
}
