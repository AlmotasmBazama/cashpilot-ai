export type FinancialFigureDimension =
  | "amount"
  | "percent"
  | "count"
  | "date"
  | "rate";

export interface FinancialFigureProvenance {
  readonly toolId: string;
  readonly field: string;
}

export interface GroundedFinancialFigure {
  readonly canonical: string;
  readonly dimension: FinancialFigureDimension;
  readonly provenance: FinancialFigureProvenance;
}

export interface NormalizedDecimal {
  readonly canonical: string;
  readonly percent: boolean;
}

export interface NormalizedDate {
  readonly canonical: string;
  readonly components: readonly string[];
}
