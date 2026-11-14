import assert from "node:assert/strict";
import {
  existsSync,
  readFileSync,
  readdirSync,
} from "node:fs";
import {
  dirname,
  relative,
  resolve,
  sep,
} from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

interface ImportEdge {
  readonly declaration: string;
  readonly line: number;
  readonly specifier: string;
}

interface ArchitectureViolation {
  readonly key: string;
  readonly source: string;
  readonly line: number;
  readonly dependency: string;
  readonly rule: string;
  readonly expectedDirection: string;
  readonly suggestedBoundary: string;
}

const gatewayRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(gatewayRoot, "../..");
const productionRoot = resolve(gatewayRoot, "src");
const toolRoot = resolve(repositoryRoot, "tool");
const compositionModule = "src/index.ts";
const maxThinEntrypointLines = 80;

const concreteAdapterSymbols = [
  "OfficialFirebaseRequestVerifier",
  "GroqChatCompletionsClient",
  "AdminRecursiveAccountDeletionStore",
  "AdminAccountAuthDeletionStore",
] as const;

const portDeclarationPattern =
  /export\s+interface\s+(?:RequestVerifier|GroqTransport|RecursiveAccountDeletionStore|AccountAuthDeletionStore|RouteDependencies)\b/u;

/**
 * The initial 2026-08-17 audit found 20 exact debt entries. This set contains
 * only the remaining debt: fixed entries must be removed, and replacement
 * violations are rejected.
 */
const knownGatewayArchitectureDebt = new Set<string>();

const violations = scanArchitecture();

test("Gateway and tool boundaries add no debt beyond the exact baseline", () => {
  const unexpected = violations.filter(
    (violation) => !knownGatewayArchitectureDebt.has(violation.key),
  );

  assert.deepEqual(
    unexpected,
    [],
    architectureFailure(
      "New dependency debt was found. Do not expand the baseline.",
      unexpected,
    ),
  );
});

test("the Gateway architecture debt baseline contains no stale entries", () => {
  const detected = new Set(violations.map((violation) => violation.key));
  const stale = [...knownGatewayArchitectureDebt]
    .filter((entry) => !detected.has(entry))
    .sort();

  assert.deepEqual(
    stale,
    [],
    [
      "Known architecture debt no longer exists.",
      "Remove these entries so the ratchet can only move downward:",
      ...stale,
    ].join("\n"),
  );
});

function scanArchitecture(): ArchitectureViolation[] {
  const byKey = new Map<string, ArchitectureViolation>();
  const sourceFiles = filesBelow(productionRoot).filter((file) =>
    file.endsWith(".ts"),
  );
  const sources = new Map(
    sourceFiles.map((file) => [file, readFileSync(file, "utf8")]),
  );
  const imports = new Map(
    [...sources].map(([file, source]) => [file, importEdges(source)]),
  );
  const firebaseAdapterModules = new Set(
    [...imports]
      .filter(([, edges]) =>
        edges.some((edge) => edge.specifier.startsWith("firebase-admin/")),
      )
      .map(([file]) => normalizedRelative(gatewayRoot, file)),
  );

  for (const [file, source] of sources) {
    const sourcePath = normalizedRelative(gatewayRoot, file);
    const edges = imports.get(file) ?? [];

    if (portDeclarationPattern.test(source)) {
      for (const edge of edges) {
        if (
          edge.specifier === "express" ||
          edge.specifier.startsWith("firebase-admin/")
        ) {
          register(byKey, {
            key: `${sourcePath}|port-framework-import|${edge.specifier}`,
            source: sourcePath,
            line: edge.line,
            dependency: edge.specifier,
            rule: "Gateway ports cannot import Express or Firebase Admin.",
            expectedDirection:
              "route/composition or Firebase adapter -> framework-free port",
            suggestedBoundary:
              "Move the interface and its plain request/value types into a dedicated ports/contracts module.",
          });
        }
      }
    }

    if (sourcePath.startsWith("src/routes/")) {
      for (const edge of edges) {
        const target = resolvedProjectModule(file, edge.specifier);
        if (target !== null && firebaseAdapterModules.has(target)) {
          register(byKey, {
            key: `${sourcePath}|route-firebase-adapter-import|${edge.specifier}`,
            source: sourcePath,
            line: edge.line,
            dependency: edge.specifier,
            rule: "Routes cannot import a Firebase-backed adapter module.",
            expectedDirection:
              "route -> framework-free port <- Firebase adapter, wired by composition",
            suggestedBoundary:
              "Import a port or typed route failure from contracts and inject its adapter from src/index.ts.",
          });
        }
      }
    }

    if (sourcePath !== compositionModule) {
      for (const edge of edges) {
        for (const symbol of concreteAdapterSymbols) {
          if (identifierPattern(symbol).test(edge.declaration)) {
            register(byKey, {
              key: `${sourcePath}|concrete-adapter-import|${symbol}`,
              source: sourcePath,
              line: edge.line,
              dependency: symbol,
              rule:
                "Production modules outside composition cannot import concrete adapters.",
              expectedDirection:
                "src/index.ts composition -> concrete adapter -> port",
              suggestedBoundary:
                "Depend on the adapter's port and construct the concrete class only in src/index.ts.",
            });
          }
        }
      }

      for (const symbol of concreteAdapterSymbols) {
        const construction = new RegExp(`\\bnew\\s+${symbol}\\s*\\(`, "u").exec(
          source,
        );
        if (construction !== null) {
          register(byKey, {
            key: `${sourcePath}|concrete-adapter-construction|${symbol}`,
            source: sourcePath,
            line: lineNumber(source, construction.index),
            dependency: `new ${symbol}(...)`,
            rule:
              "Production modules outside composition cannot construct concrete adapters.",
            expectedDirection:
              "src/index.ts composition -> concrete adapter -> port",
            suggestedBoundary:
              "Move construction to productionDependencies() and inject the port.",
          });
        }
      }
    }
  }

  for (const file of filesBelow(toolRoot)) {
    const name = file.slice(file.lastIndexOf(sep) + 1);
    if (
      !name.startsWith("run_") ||
      name.includes(".test.") ||
      !/\.(?:cjs|mjs|js|ps1)$/u.test(name)
    ) {
      continue;
    }
    const source = readFileSync(file, "utf8");
    const lines = physicalLineCount(source);
    if (lines <= maxThinEntrypointLines) continue;
    const sourcePath = normalizedRelative(repositoryRoot, file);
    register(byKey, {
      key: `${sourcePath}|thick-tool-entrypoint`,
      source: sourcePath,
      line: 1,
      dependency: `${lines} physical lines`,
      rule: `Tool entrypoints must stay at or below ${maxThinEntrypointLines} lines.`,
      expectedDirection: "thin run_* entrypoint -> independently tested support module",
      suggestedBoundary:
        "Move orchestration and parsing into a *_support module; retain only argument forwarding and exit handling here.",
    });
  }

  return [...byKey.values()].sort((left, right) =>
    left.key.localeCompare(right.key),
  );
}

function importEdges(source: string): ImportEdge[] {
  const edges: ImportEdge[] = [];
  const pattern =
    /(?:^|\n)\s*(?:import|export)\s+(?:(?:type\s+)?[\s\S]*?\s+from\s+)?["']([^"']+)["'];/gu;
  for (const match of source.matchAll(pattern)) {
    const specifier = match[1];
    if (specifier === undefined || match.index === undefined) continue;
    edges.push({
      declaration: match[0],
      line: lineNumber(source, match.index),
      specifier,
    });
  }
  return edges;
}

function resolvedProjectModule(
  sourceFile: string,
  specifier: string,
): string | null {
  if (!specifier.startsWith(".")) return null;
  const target = resolve(
    dirname(sourceFile),
    specifier.replace(/\.js$/u, ".ts"),
  );
  if (!existsSync(target)) return null;
  return normalizedRelative(gatewayRoot, target);
}

function filesBelow(directory: string): string[] {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = resolve(directory, entry.name);
    return entry.isDirectory() ? filesBelow(path) : [path];
  });
}

function normalizedRelative(root: string, file: string): string {
  return relative(root, file).split(sep).join("/");
}

function identifierPattern(identifier: string): RegExp {
  return new RegExp(`\\b${identifier}\\b`, "u");
}

function lineNumber(source: string, offset: number): number {
  return source.slice(0, offset).split(/\r?\n/u).length;
}

function physicalLineCount(source: string): number {
  return source.length === 0 ? 0 : source.replace(/\r\n/gu, "\n").split("\n").length;
}

function register(
  violations: Map<string, ArchitectureViolation>,
  violation: ArchitectureViolation,
): void {
  violations.set(violation.key, violation);
}

function architectureFailure(
  heading: string,
  items: readonly ArchitectureViolation[],
): string {
  return [
    heading,
    ...items.flatMap((item) => [
      `source: ${item.source}:${item.line}`,
      `forbidden dependency: ${item.dependency}`,
      `rule: ${item.rule}`,
      `expected direction: ${item.expectedDirection}`,
      `suggested boundary: ${item.suggestedBoundary}`,
    ]),
  ].join("\n");
}
