import {
  mkdir,
  readFile,
  rename,
  writeFile,
} from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  GroqClient,
  MissingGroqApiKeyError,
  ProviderRequestError,
} from "./groq_client.ts";
import {
  activeResults,
  buildCompletionRequest,
  evaluateCompletion,
  failureResult,
  pendingEvaluations,
  reevaluateStoredResult,
  retryFailedEvaluations,
} from "./evaluators.ts";
import {
  MODEL_IDS,
  type BenchmarkCheckpoint,
  type ModelAvailability,
} from "./schemas.ts";
import {
  PROMPT_COUNTS,
  PROMPT_MATRIX,
} from "./prompt_matrix.ts";
import {
  TOOL_ROOT,
  assertNoSecret,
  writeEvaluationReports,
} from "./report_writer.ts";

const CHECKPOINT_PATH = resolve(TOOL_ROOT, "results", "checkpoint.json");

export interface RunnerOptions {
  reportOnly: boolean;
  resume: boolean;
  maxRequests: number | null;
  pauseMs: number;
  retryFailed: boolean;
}

export async function runBenchmark(
  options: RunnerOptions,
): Promise<BenchmarkCheckpoint> {
  let checkpoint =
    options.resume
      ? await loadCheckpoint(CHECKPOINT_PATH)
      : null;
  checkpoint ??= newCheckpoint();
  normalizeAttemptHistory(checkpoint);

  if (options.reportOnly) {
    if (
      checkpoint.results.length === 0 &&
      !process.env.GROQ_API_KEY
    ) {
      checkpoint.stoppedReason = "missing_api_key";
      checkpoint.updatedAt = new Date().toISOString();
    }
    await saveCheckpoint(CHECKPOINT_PATH, checkpoint);
    await writeEvaluationReports({
      checkpoint,
      matrix: PROMPT_MATRIX,
      secretGuard: process.env.GROQ_API_KEY,
    });
    return checkpoint;
  }

  let providerRetryCandidates = options.retryFailed
    ? retryFailedEvaluations(PROMPT_MATRIX, checkpoint.results)
    : [];
  if (options.retryFailed) {
    const evaluatorRepairs = providerRetryCandidates.filter(
      (candidate) => candidate.strategy === "evaluator_repair",
    );
    for (const candidate of evaluatorRepairs) {
      const repaired = reevaluateStoredResult(
        candidate.testCase,
        candidate.previousResult,
      );
      appendSupersedingAttempt(
        checkpoint,
        candidate.previousResult,
        repaired,
        "evaluator_repair",
      );
    }
    if (evaluatorRepairs.length > 0) {
      checkpoint.updatedAt = new Date().toISOString();
      await saveCheckpoint(
        CHECKPOINT_PATH,
        checkpoint,
        process.env.GROQ_API_KEY,
      );
      console.log(
        `reevaluated stored responses=${evaluatorRepairs.length}`,
      );
    }
    providerRetryCandidates = retryFailedEvaluations(
      PROMPT_MATRIX,
      checkpoint.results,
    ).filter((candidate) => candidate.strategy === "provider_retry");
    if (providerRetryCandidates.length === 0) {
      checkpoint.stoppedReason = "repair_complete";
      checkpoint.updatedAt = new Date().toISOString();
      await saveCheckpoint(
        CHECKPOINT_PATH,
        checkpoint,
        process.env.GROQ_API_KEY,
      );
      await writeEvaluationReports({
        checkpoint,
        matrix: PROMPT_MATRIX,
        secretGuard: process.env.GROQ_API_KEY,
      });
      return checkpoint;
    }
  }

  let client: GroqClient;
  try {
    client = new GroqClient();
  } catch (error) {
    if (!(error instanceof MissingGroqApiKeyError)) throw error;
    checkpoint.stoppedReason = "missing_api_key";
    checkpoint.updatedAt = new Date().toISOString();
    await saveCheckpoint(CHECKPOINT_PATH, checkpoint);
    await writeEvaluationReports({
      checkpoint,
      matrix: PROMPT_MATRIX,
    });
    console.error(
      "Benchmark not started: GROQ_API_KEY is missing from this process.",
    );
    process.exitCode = 2;
    return checkpoint;
  }

  try {
    checkpoint.availability = await client.discoverModels();
    checkpoint.updatedAt = new Date().toISOString();
    await saveCheckpoint(
      CHECKPOINT_PATH,
      checkpoint,
      process.env.GROQ_API_KEY,
    );
  } catch (error) {
    checkpoint.stoppedReason = "provider_error";
    checkpoint.updatedAt = new Date().toISOString();
    await saveCheckpoint(
      CHECKPOINT_PATH,
      checkpoint,
      process.env.GROQ_API_KEY,
    );
    await writeEvaluationReports({
      checkpoint,
      matrix: PROMPT_MATRIX,
      secretGuard: process.env.GROQ_API_KEY,
    });
    console.error(
      error instanceof ProviderRequestError
        ? `Model discovery failed (${error.statusCategory}).`
        : "Model discovery returned an invalid response.",
    );
    process.exitCode = 1;
    return checkpoint;
  }

  let interrupted = false;
  const interrupt = () => {
    interrupted = true;
  };
  process.once("SIGINT", interrupt);
  process.once("SIGTERM", interrupt);

  const available = new Set(
    checkpoint.availability
      .filter((item) => item.available === true)
      .map((item) => item.modelId),
  );
  const pending = (
    options.retryFailed
      ? providerRetryCandidates
      : pendingEvaluations(PROMPT_MATRIX, checkpoint.results)
  ).filter((item) => available.has(item.modelId));
  let executedThisRun = 0;
  checkpoint.stoppedReason = "interrupted";

  for (const item of pending) {
    if (interrupted) {
      checkpoint.stoppedReason = "interrupted";
      break;
    }
    if (
      options.maxRequests !== null &&
      executedThisRun >= options.maxRequests
    ) {
      checkpoint.stoppedReason = "max_requests";
      break;
    }
    if (!available.has(item.modelId)) {
      continue;
    }

    const request = buildCompletionRequest(
      item.testCase,
      item.modelId,
    );
    let result;
    let terminalDailyQuota = false;
    try {
      const completion = await client.complete(request);
      result = evaluateCompletion(
        item.testCase,
        item.modelId,
        completion,
      );
      console.log(
        `completed ${item.testCase.id} ${item.modelId} success=${result.success}`,
      );
    } catch (error) {
      result = failureResult(item.testCase, item.modelId, error);
      console.log(
        `completed ${item.testCase.id} ${item.modelId} status=${result.httpStatusCategory}`,
      );
      if (
        error instanceof ProviderRequestError &&
        error.providerUnavailable
      ) {
        checkpoint.availability = markUnavailable(
          checkpoint.availability,
          item.modelId,
        );
        available.delete(item.modelId);
      }
      terminalDailyQuota =
        error instanceof ProviderRequestError && error.dailyQuota;
    }

    if (options.retryFailed && "previousResult" in item) {
      appendSupersedingAttempt(
        checkpoint,
        item.previousResult,
        result,
        "provider_retry",
      );
    } else {
      initializeOriginalAttempt(result);
      checkpoint.results.push(result);
    }
    checkpoint.updatedAt = new Date().toISOString();
    executedThisRun++;
    await saveCheckpoint(
      CHECKPOINT_PATH,
      checkpoint,
      process.env.GROQ_API_KEY,
    );

    if (terminalDailyQuota) {
      checkpoint.stoppedReason = "daily_quota";
      break;
    }
    if (options.pauseMs > 0) {
      await sleep(options.pauseMs);
    }
  }

  if (
    !interrupted &&
    options.retryFailed &&
    checkpoint.stoppedReason !== "max_requests" &&
    checkpoint.stoppedReason !== "daily_quota"
  ) {
    checkpoint.stoppedReason = "repair_complete";
  } else if (
    !interrupted &&
    pendingEvaluations(
      PROMPT_MATRIX,
      activeResults(checkpoint.results),
    ).filter(
      (item) =>
        checkpoint.availability.find(
          (availability) =>
            availability.modelId === item.modelId,
        )?.available === true,
    ).length === 0
  ) {
    checkpoint.stoppedReason = "complete";
  } else if (interrupted) {
    checkpoint.stoppedReason = "interrupted";
  }
  checkpoint.updatedAt = new Date().toISOString();
  await saveCheckpoint(
    CHECKPOINT_PATH,
    checkpoint,
    process.env.GROQ_API_KEY,
  );
  await writeEvaluationReports({
    checkpoint,
    matrix: PROMPT_MATRIX,
    secretGuard: process.env.GROQ_API_KEY,
  });
  process.removeListener("SIGINT", interrupt);
  process.removeListener("SIGTERM", interrupt);
  return checkpoint;
}

export async function loadCheckpoint(
  path: string,
): Promise<BenchmarkCheckpoint | null> {
  try {
    const value = JSON.parse(await readFile(path, "utf8"));
    if (
      value?.schemaVersion !== 1 ||
      !Array.isArray(value.results) ||
      !Array.isArray(value.availability)
    ) {
      throw new Error("Checkpoint schema is invalid.");
    }
    return value as BenchmarkCheckpoint;
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      error.code === "ENOENT"
    ) {
      return null;
    }
    throw error;
  }
}

export async function saveCheckpoint(
  path: string,
  checkpoint: BenchmarkCheckpoint,
  secretGuard?: string,
): Promise<void> {
  const content = `${JSON.stringify(checkpoint, null, 2)}\n`;
  assertNoSecret(content, secretGuard);
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.tmp`;
  await writeFile(temporary, content, "utf8");
  await rename(temporary, path);
}

export function newCheckpoint(): BenchmarkCheckpoint {
  const now = new Date().toISOString();
  return {
    schemaVersion: 1,
    startedAt: now,
    updatedAt: now,
    availability: MODEL_IDS.map((modelId) => ({
      modelId,
      available: null,
      active: null,
      reason: "not_checked",
    })),
    results: [],
    stoppedReason: "not_started",
  };
}

function markUnavailable(
  availability: ModelAvailability[],
  modelId: ModelAvailability["modelId"],
): ModelAvailability[] {
  return availability.map((item) =>
    item.modelId === modelId
      ? {
          ...item,
          available: false,
          active: false,
          reason: "inactive",
        }
      : item,
  );
}

function parseOptions(argv: string[]): RunnerOptions {
  const maxArgument = argv.find((argument) =>
    argument.startsWith("--max-requests="),
  );
  const environmentMax = process.env.GROQ_EVAL_MAX_REQUESTS;
  const rawMax =
    maxArgument?.slice("--max-requests=".length) ?? environmentMax;
  const maxRequests =
    rawMax && Number.isInteger(Number(rawMax)) && Number(rawMax) >= 0
      ? Number(rawMax)
      : null;
  const environmentPause = process.env.GROQ_EVAL_PAUSE_MS;
  const pauseMs =
    environmentPause &&
    Number.isFinite(Number(environmentPause)) &&
    Number(environmentPause) >= 0
      ? Number(environmentPause)
      : 1_100;
  return {
    reportOnly: argv.includes("--report-only"),
    resume: argv.includes("--resume") || !argv.includes("--fresh"),
    maxRequests,
    pauseMs,
    retryFailed: argv.includes("--retry-failed"),
  };
}

function sleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function normalizeAttemptHistory(
  checkpoint: BenchmarkCheckpoint,
): void {
  for (const result of checkpoint.results) {
    result.attemptId ??=
      `original:${result.testCaseId}:${result.modelId}`;
    result.attemptNumber ??= 1;
    result.attemptKind ??= "original";
    result.supersedesAttemptId ??= null;
    result.supersededByAttemptId ??= null;
    result.isSuperseded ??= false;
    result.providerDiagnostic ??= null;
    result.finishReason ??= null;
  }
}

function initializeOriginalAttempt(
  result: import("./schemas.ts").BenchmarkResult,
): void {
  result.attemptId =
    `original:${result.testCaseId}:${result.modelId}`;
  result.attemptNumber = 1;
  result.attemptKind = "original";
  result.supersedesAttemptId = null;
  result.supersededByAttemptId = null;
  result.isSuperseded = false;
}

function appendSupersedingAttempt(
  checkpoint: BenchmarkCheckpoint,
  previous: import("./schemas.ts").BenchmarkResult,
  result: import("./schemas.ts").BenchmarkResult,
  kind: "provider_retry" | "evaluator_repair",
): void {
  const attemptNumber = (previous.attemptNumber ?? 1) + 1;
  const attemptId =
    `${kind}:${result.testCaseId}:${result.modelId}:${attemptNumber}:${Date.now()}`;
  previous.isSuperseded = true;
  previous.supersededByAttemptId = attemptId;
  result.attemptId = attemptId;
  result.attemptNumber = attemptNumber;
  result.attemptKind = kind;
  result.supersedesAttemptId = previous.attemptId ?? null;
  result.supersededByAttemptId = null;
  result.isSuperseded = false;
  checkpoint.results.push(result);
}

async function main(): Promise<void> {
  console.log(
    `prepared synthetic prompts=${PROMPT_MATRIX.length} groups=${Object.keys(PROMPT_COUNTS).length}`,
  );
  const checkpoint = await runBenchmark(parseOptions(process.argv.slice(2)));
  console.log(
    `benchmark stop=${checkpoint.stoppedReason} completed=${checkpoint.results.length}`,
  );
}

const invokedPath = process.argv[1]
  ? resolve(process.argv[1])
  : "";
if (invokedPath === fileURLToPath(import.meta.url)) {
  await main();
}
