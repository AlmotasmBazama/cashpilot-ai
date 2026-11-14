import {
  mkdir,
  rename,
  writeFile,
} from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  MODEL_IDS,
  type BenchmarkCheckpoint,
  type BenchmarkResult,
  type ModelId,
  type PromptCase,
} from "./schemas.ts";
import {
  activeResults,
  pendingEvaluations,
} from "./evaluators.ts";

const MODULE_DIR = dirname(fileURLToPath(import.meta.url));
export const TOOL_ROOT = resolve(MODULE_DIR, "..");
export const REPO_ROOT = resolve(TOOL_ROOT, "..", "..");

export interface ScoreRow {
  modelId: ModelId;
  category: string;
  score: number;
  completed: number;
  successRate: number;
  medianLatencyMs: number | null;
}

export interface EvaluationSummary {
  generatedAt: string;
  preparedPromptCount: number;
  plannedRequestCount: number;
  completedRequestCount: number;
  totalAttemptCount: number;
  supersededAttemptCount: number;
  providerRetryAttemptCount: number;
  evaluatorRepairAttemptCount: number;
  successfulRequestCount: number;
  remainingRequestCount: number;
  stoppedReason: BenchmarkCheckpoint["stoppedReason"];
  availability: BenchmarkCheckpoint["availability"];
  rateLimitedRequestCount: number;
  timeoutRequestCount: number;
  providerUnavailableRequestCount: number;
  safeProviderDiagnostics: Array<{
    code: string | null;
    parameter: string | null;
    message: string | null;
    failedGenerationPresent: boolean;
    count: number;
  }>;
  scoreRows: ScoreRow[];
  winners: Record<string, string>;
  proposedRouting: Record<string, string>;
  scoringNote: string;
}

export async function writeEvaluationReports(input: {
  checkpoint: BenchmarkCheckpoint;
  matrix: PromptCase[];
  secretGuard?: string;
  outputRoot?: string;
}): Promise<EvaluationSummary> {
  const outputRoot = input.outputRoot ?? TOOL_ROOT;
  const repoRoot =
    input.outputRoot === undefined
      ? REPO_ROOT
      : resolve(outputRoot, "repository");
  const resultsDir = resolve(outputRoot, "results");
  const docsDir = resolve(repoRoot, "docs");
  await Promise.all([
    mkdir(resultsDir, { recursive: true }),
    mkdir(docsDir, { recursive: true }),
  ]);

  const summary = buildSummary(input.checkpoint, input.matrix);
  const objective = {
    schemaVersion: 1,
    generatedAt: summary.generatedAt,
    syntheticOnly: true,
    results: input.checkpoint.results,
  };
  const manualReview = renderManualReview(
    input.matrix,
    activeResults(input.checkpoint.results),
    summary,
  );
  const mainReport = renderMainReport(
    input.checkpoint,
    input.matrix,
    summary,
  );

  const outputs: Array<[string, string]> = [
    [
      resolve(resultsDir, "summary.json"),
      `${JSON.stringify(summary, null, 2)}\n`,
    ],
    [
      resolve(resultsDir, "objective_results.json"),
      `${JSON.stringify(objective, null, 2)}\n`,
    ],
    [resolve(resultsDir, "manual_review.md"), manualReview],
    [resolve(docsDir, "groq_model_evaluation.md"), mainReport],
  ];
  for (const [path, content] of outputs) {
    assertNoSecret(content, input.secretGuard);
    await atomicWrite(path, content);
  }
  return summary;
}

export function buildSummary(
  checkpoint: BenchmarkCheckpoint,
  matrix: PromptCase[],
): EvaluationSummary {
  const currentResults = activeResults(checkpoint.results);
  const scoreRows = calculateScoreRows(currentResults);
  const winner = (category: string): string => {
    const eligible = scoreRows
      .filter(
        (row) =>
          row.category === category &&
          row.completed > 0 &&
          row.successRate > 0,
      )
      .sort(
        (left, right) =>
          right.score - left.score ||
          right.successRate - left.successRate ||
          (left.medianLatencyMs ?? Number.MAX_SAFE_INTEGER) -
            (right.medianLatencyMs ?? Number.MAX_SAFE_INTEGER),
      );
    return eligible[0]?.modelId ?? "Not determined";
  };
  const primary = choosePrimary(scoreRows);
  const currentWinner = winner("current_information");
  const structuredWinner = winner("structured_action");
  const availability = new Map(
    checkpoint.availability.map((item) => [
      item.modelId,
      item.available,
    ]),
  );
  const fastFallback =
    availability.get("openai/gpt-oss-20b") === false
      ? "Not determined"
      : hasCompleted(
            currentResults,
            "openai/gpt-oss-20b",
            "structured_action",
          )
        ? "openai/gpt-oss-20b"
        : "Not determined";

  return {
    generatedAt: new Date().toISOString(),
    preparedPromptCount: matrix.length,
    plannedRequestCount: matrix.reduce(
      (sum, testCase) => sum + testCase.models.length,
      0,
    ),
    completedRequestCount: currentResults.length,
    totalAttemptCount: checkpoint.results.length,
    supersededAttemptCount: checkpoint.results.filter(
      (result) => result.isSuperseded === true,
    ).length,
    providerRetryAttemptCount: checkpoint.results.filter(
      (result) => result.attemptKind === "provider_retry",
    ).length,
    evaluatorRepairAttemptCount: checkpoint.results.filter(
      (result) => result.attemptKind === "evaluator_repair",
    ).length,
    successfulRequestCount: currentResults.filter(
      (result) => result.success,
    ).length,
    remainingRequestCount: pendingEvaluations(
      matrix,
      currentResults,
    ).length,
    stoppedReason: checkpoint.stoppedReason,
    availability: checkpoint.availability,
    rateLimitedRequestCount: currentResults.filter(
      (result) => result.flags.rateLimited,
    ).length,
    timeoutRequestCount: currentResults.filter(
      (result) => result.flags.timeout,
    ).length,
    providerUnavailableRequestCount: currentResults.filter(
      (result) => result.flags.providerUnavailable,
    ).length,
    safeProviderDiagnostics: aggregateProviderDiagnostics(
      checkpoint.results,
    ),
    scoreRows,
    winners: {
      generalConversation: winner("general_conversation"),
      arabicLibyan: winner("arabic_libyan_financial"),
      financialAnalysis: winner("financial_analysis"),
      structuredAction: structuredWinner,
      governedTool: winner("governed_tool"),
      currentInformation: currentWinner,
      recommendedPrimary: primary,
    },
    proposedRouting: {
      generalConversation: winner("general_conversation"),
      arabicLibyanConversation: winner(
        "arabic_libyan_financial",
      ),
      personalFinancialAnalysis: winner("financial_analysis"),
      structuredActionExtraction: structuredWinner,
      currentWebInformation: currentWinner,
      fastFallback,
      receiptVision:
        "Existing Firebase Gemini receipt path (not evaluated; no production change)",
      finalLocalFallback:
        "Existing deterministic CashPilot parser and governed local tools",
    },
    scoringNote:
      "Scores are provisional deterministic heuristics over objective flags and are not scientific or a substitute for the manual-review notes.",
  };
}

export function calculateScoreRows(
  results: BenchmarkResult[],
): ScoreRow[] {
  const groups = new Map<string, BenchmarkResult[]>();
  for (const result of results) {
    const key = `${result.modelId}\u0000${result.category}`;
    groups.set(key, [...(groups.get(key) ?? []), result]);
  }
  return [...groups.entries()]
    .map(([key, rows]) => {
      const [modelId, category] = key.split("\u0000") as [
        ModelId,
        string,
      ];
      const latencies = rows
        .map((row) => row.latencyTotalMs)
        .filter((value): value is number => value !== null)
        .sort((left, right) => left - right);
      return {
        modelId,
        category,
        score: round(
          rows.reduce((sum, row) => sum + row.categoryScore, 0) /
            rows.length,
        ),
        completed: rows.length,
        successRate: round(
          (rows.filter((row) => row.success).length / rows.length) *
            100,
        ),
        medianLatencyMs:
          latencies.length === 0
            ? null
            : latencies[Math.floor(latencies.length / 2)],
      };
    })
    .sort(
      (left, right) =>
        left.category.localeCompare(right.category) ||
        left.modelId.localeCompare(right.modelId),
    );
}

export function assertNoSecret(
  content: string,
  secret?: string,
): void {
  if (secret && secret.length > 0 && content.includes(secret)) {
    throw new Error("Refusing to write a report containing the API key.");
  }
}

function choosePrimary(scoreRows: ScoreRow[]): string {
  const relevantCategories = new Set([
    "general_conversation",
    "financial_analysis",
    "governed_tool",
  ]);
  const byModel = new Map<ModelId, ScoreRow[]>();
  for (const row of scoreRows) {
    if (!relevantCategories.has(row.category)) continue;
    byModel.set(row.modelId, [...(byModel.get(row.modelId) ?? []), row]);
  }
  const ranked = [...byModel.entries()]
    .filter(([, rows]) => rows.length === relevantCategories.size)
    .map(([modelId, rows]) => ({
      modelId,
      score:
        rows.reduce((sum, row) => sum + row.score, 0) / rows.length,
    }))
    .sort((left, right) => right.score - left.score);
  return ranked[0]?.modelId ?? "Not determined";
}

function aggregateProviderDiagnostics(
  results: BenchmarkResult[],
): EvaluationSummary["safeProviderDiagnostics"] {
  const groups = new Map<
    string,
    EvaluationSummary["safeProviderDiagnostics"][number]
  >();
  for (const result of results) {
    const diagnostic = result.providerDiagnostic;
    if (!diagnostic) continue;
    const key = JSON.stringify(diagnostic);
    const existing = groups.get(key);
    if (existing) {
      existing.count++;
    } else {
      groups.set(key, { ...diagnostic, count: 1 });
    }
  }
  return [...groups.values()].sort(
    (left, right) => right.count - left.count,
  );
}

function renderManualReview(
  matrix: PromptCase[],
  results: BenchmarkResult[],
  summary: EvaluationSummary,
): string {
  const byEvaluation = new Map(
    results.map((result) => [
      `${result.testCaseId}\u0000${result.modelId}`,
      result,
    ]),
  );
  const sections = matrix
    .filter((testCase) => testCase.important)
    .map((testCase) => {
      const rows = testCase.models
        .map((modelId) => {
          const result = byEvaluation.get(
            `${testCase.id}\u0000${modelId}`,
          );
          if (!result) {
            return `| ${escapeCell(modelId)} | Not run | — | — |  |`;
          }
          const objectiveFlags = [
            `success=${result.success}`,
            `language=${result.flags.languageMatch}`,
            `schema=${result.flags.schemaValid ?? "n/a"}`,
            `tool=${result.flags.toolNameCorrect ?? "n/a"}`,
            `sources=${result.flags.sourceSearchMetadataPresent}`,
          ].join("; ");
          return `| ${escapeCell(modelId)} | ${escapeCell(result.answer || "(tool call only)")} | ${escapeCell(objectiveFlags)} | ${result.latencyTotalMs ?? "—"} |  |`;
        })
        .join("\n");
      const context = testCase.syntheticContext
        ? `\n\nSynthetic context: ${testCase.syntheticContext}`
        : "";
      return `## ${testCase.id} — ${testCase.category}

Prompt: ${testCase.prompt}${context}

| Model | Answer | Objective flags | Total latency (ms) | Manual notes |
|---|---|---|---:|---|
${rows}`;
    })
    .join("\n\n");

  return `# Groq Model Evaluation — Human Review

All prompts and contexts in this document are synthetic. Blank notes are intentionally left for human review. Objective scores are provisional heuristics.

- Prepared prompts: ${summary.preparedPromptCount}
- Completed model requests: ${summary.completedRequestCount}
- Total auditable attempts: ${summary.totalAttemptCount}
- Superseded attempts retained: ${summary.supersededAttemptCount}
- Remaining model requests: ${summary.remainingRequestCount}

${sections}
`;
}

function renderMainReport(
  checkpoint: BenchmarkCheckpoint,
  matrix: PromptCase[],
  summary: EvaluationSummary,
): string {
  const available = checkpoint.availability
    .filter((item) => item.available === true)
    .map((item) => `- ${item.modelId}`)
    .join("\n");
  const unavailable = checkpoint.availability
    .filter((item) => item.available === false)
    .map((item) => `- ${item.modelId}: ${item.reason}`)
    .join("\n");
  const notChecked = checkpoint.availability.every(
    (item) => item.available === null,
  );
  const scoreTable =
    summary.scoreRows.length === 0
      ? "No live objective results yet."
      : [
          "| Model | Category | Score / 100 | Success rate | Median latency (ms) |",
          "|---|---|---:|---:|---:|",
          ...summary.scoreRows.map(
            (row) =>
              `| ${row.modelId} | ${row.category} | ${row.score.toFixed(2)} | ${row.successRate.toFixed(2)}% | ${row.medianLatencyMs ?? "—"} |`,
          ),
        ].join("\n");
  const latencyRows =
    summary.scoreRows.length === 0
      ? "No latency samples."
      : summary.scoreRows
          .map(
            (row) =>
              `- ${row.modelId} / ${row.category}: ${row.medianLatencyMs ?? "no sample"} ms median`,
          )
          .join("\n");
  const reliabilityRows =
    summary.scoreRows.length === 0
      ? "No reliability samples."
      : summary.scoreRows
          .map(
            (row) =>
              `- ${row.modelId} / ${row.category}: ${row.successRate.toFixed(2)}% (${row.completed} requests)`,
          )
          .join("\n");
  const modelsNotRecommended =
    summary.completedRequestCount === 0
      ? "Not determined without live results."
      : MODEL_IDS.filter(
          (modelId) =>
            !Object.values(summary.proposedRouting).includes(modelId),
        )
          .map((modelId) => `- ${modelId}`)
          .join("\n") || "None based on the completed sample.";
  const diagnosticRows =
    summary.safeProviderDiagnostics.length === 0
      ? "No sanitized provider diagnostics were retained by the original run. Failed-only retries will populate this section."
      : summary.safeProviderDiagnostics
          .map(
            (item) =>
              `- count=${item.count}; code=${item.code ?? "none"}; parameter=${item.parameter ?? "none"}; failed_generation=${item.failedGenerationPresent}; message=${item.message ?? "none"}`,
          )
          .join("\n");

  return `# CashPilot AI — Controlled Groq Model Evaluation

Status: ${checkpoint.stoppedReason}. This evaluation is isolated from the Flutter production runtime. Scores are deterministic heuristics, not scientific certainty.

Methodology uses Groq's official OpenAI-compatible endpoint and exact requested model IDs. Compound Mini is restricted to public web search. All financial prompts and context are fictional.

## Benchmark repair diagnostics

- FIN: the original requests returned HTTP 2xx. False negatives came from literal number matching that missed grouped digits and from treating derived arithmetic as fabricated. Qwen also produced empty 2xx content under the original reasoning/token budget.
- ACT: the original run used best-effort JSON Object mode for every model. Intermittent GPT 400s and universal Qwen 400s were generated-output/request-mode failures, not local schema-keyword rejection. GPT retries now use strict JSON Schema; Qwen uses JSON Object mode with reasoning disabled.
- CUR: the original Compound requests were over-specified with base-model sampling/output options. Retries now use the documented minimal Compound payload and web_search only.
- Failed cases repaired or retried so far: ${summary.providerRetryAttemptCount + summary.evaluatorRepairAttemptCount}

Sanitized provider diagnostics:

${diagnosticRows}

## 1. Models tested

${available || (notChecked ? "Model discovery was not run because the environment key was unavailable." : "No requested model completed a live request.")}

## 2. Models unavailable

${unavailable || (notChecked ? "Not checked." : "None of the requested models were marked unavailable by discovery.")}

## 3. Number of prompts completed

- Synthetic prompts prepared: ${matrix.length}
- Planned model requests: ${summary.plannedRequestCount}
- Completed model requests: ${summary.completedRequestCount}
- Total auditable attempts: ${summary.totalAttemptCount}
- Provider retry attempts: ${summary.providerRetryAttemptCount}
- Evaluator-only repair attempts: ${summary.evaluatorRepairAttemptCount}
- Superseded attempts retained: ${summary.supersededAttemptCount}
- Remaining model requests: ${summary.remainingRequestCount}

## 4. Rate limits encountered

- Rate-limited requests: ${summary.rateLimitedRequestCount}
- Timeouts: ${summary.timeoutRequestCount}
- Stop reason: ${summary.stoppedReason}

## 5. General conversation winner

${summary.winners.generalConversation}

## 6. Arabic/Libyan winner

${summary.winners.arabicLibyan}

## 7. Financial-analysis winner

${summary.winners.financialAnalysis}

## 8. Structured-action winner

${summary.winners.structuredAction}

## 9. Tool-calling winner

${summary.winners.governedTool}

## 10. Current-information result

${summary.winners.currentInformation}

## 11. Latency comparison

${latencyRows}

## 12. Reliability comparison

${reliabilityRows}

## 13. Privacy/security observations

- The API key is read only from the process environment.
- Authorization and response headers are never logged or persisted.
- Reports are rejected if they contain the exact in-memory key.
- Only prompts marked synthetic pass preflight validation.
- No Firebase UID, authentication token, App Check token, contact detail, real balance, transaction, receipt, or local file path is included in provider requests.
- Compound Mini receives public current-information prompts only and no CashPilot financial context.

## 14. Recommended primary model

${summary.winners.recommendedPrimary}

## 15. Recommended Arabic fallback

${summary.winners.arabicLibyan}

## 16. Recommended extraction model

${summary.winners.structuredAction}

## 17. Recommended current-information model

${summary.winners.currentInformation}

## 18. Models not recommended

${modelsNotRecommended}

## 19. Production risks

- Live quality, quota, preview-model stability, latency, and structured-output consistency must be reviewed before integration.
- Model availability is account-specific and may change.
- Compound search must never receive private CashPilot context.
- Tool calls must remain locally validated and writes must remain review-only drafts with explicit confirmation.
- Receipt vision was intentionally not evaluated in this text-only sprint.

## 20. Proposed CashPilot routing table

- General conversation: ${summary.proposedRouting.generalConversation}
- Arabic/Libyan conversation: ${summary.proposedRouting.arabicLibyanConversation}
- Personal financial analysis: ${summary.proposedRouting.personalFinancialAnalysis}
- Structured action extraction: ${summary.proposedRouting.structuredActionExtraction}
- Current web information: ${summary.proposedRouting.currentWebInformation}
- Fast fallback: ${summary.proposedRouting.fastFallback}
- Receipt vision: ${summary.proposedRouting.receiptVision}
- Final local fallback: ${summary.proposedRouting.finalLocalFallback}

## Objective score summary

${scoreTable}

${summary.scoringNote}

## Resume command

\`npm.cmd --prefix tools/groq_evaluation run benchmark -- --resume\`
`;
}

async function atomicWrite(path: string, content: string): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.tmp`;
  await writeFile(temporary, content, "utf8");
  await rename(temporary, path);
}

function hasCompleted(
  results: BenchmarkResult[],
  modelId: ModelId,
  category: string,
): boolean {
  return results.some(
    (result) =>
      result.modelId === modelId && result.category === category,
  );
}

function escapeCell(value: string): string {
  return value
    .replace(/\|/g, "\\|")
    .replace(/\r?\n/g, "<br>")
    .trim();
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}
