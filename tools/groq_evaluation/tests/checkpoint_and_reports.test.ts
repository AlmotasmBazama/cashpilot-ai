import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtemp,
  readFile,
  readdir,
} from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  newCheckpoint,
  loadCheckpoint,
  saveCheckpoint,
} from "../src/benchmark_runner.ts";
import {
  failureResult,
  pendingEvaluations,
} from "../src/evaluators.ts";
import { PROMPT_MATRIX } from "../src/prompt_matrix.ts";
import { writeEvaluationReports } from "../src/report_writer.ts";

test("checkpoint save/load resumes after completed model-case pairs", async () => {
  const directory = await mkdtemp(
    join(tmpdir(), "cashpilot-groq-checkpoint-"),
  );
  const path = join(directory, "checkpoint.json");
  const checkpoint = newCheckpoint();
  const testCase = PROMPT_MATRIX[0];
  checkpoint.results.push(
    failureResult(
      testCase,
      testCase.models[0],
      new Error("synthetic failure"),
    ),
  );
  const before = pendingEvaluations(
    PROMPT_MATRIX,
    checkpoint.results,
  ).length;
  await saveCheckpoint(path, checkpoint, "guard-secret");
  const loaded = await loadCheckpoint(path);
  assert.ok(loaded);
  const after = pendingEvaluations(
    PROMPT_MATRIX,
    loaded.results,
  ).length;
  assert.equal(after, before);
  assert.equal(
    after,
    PROMPT_MATRIX.reduce(
      (sum, item) => sum + item.models.length,
      0,
    ) - 1,
  );
});

test("API key content is rejected and never appears in generated reports", async () => {
  const directory = await mkdtemp(
    join(tmpdir(), "cashpilot-groq-reports-"),
  );
  const secret = "synthetic-report-guard-secret";
  const checkpoint = newCheckpoint();
  checkpoint.results.push({
    ...failureResult(
      PROMPT_MATRIX[0],
      PROMPT_MATRIX[0].models[0],
      new Error("synthetic failure"),
    ),
    answer: `unsafe echo ${secret}`,
  });
  await assert.rejects(() =>
    writeEvaluationReports({
      checkpoint,
      matrix: PROMPT_MATRIX,
      secretGuard: secret,
      outputRoot: directory,
    }),
  );
  const combined = await readFilesRecursively(directory);
  assert.equal(combined.includes(secret), false);
});

async function readFilesRecursively(path: string): Promise<string> {
  const entries = await readdir(path, { withFileTypes: true });
  const contents: string[] = [];
  for (const entry of entries) {
    const child = join(path, entry.name);
    if (entry.isDirectory()) {
      contents.push(await readFilesRecursively(child));
    } else {
      contents.push(await readFile(child, "utf8"));
    }
  }
  return contents.join("\n");
}
