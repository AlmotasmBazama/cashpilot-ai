import { pathToFileURL } from "node:url";
import { fixedModels } from "../src/config.js";

const verificationTimeoutMs = 15_000;

export interface GroqModelVerificationOptions {
  readonly env?: NodeJS.ProcessEnv;
  readonly fetcher?: typeof fetch;
  readonly write?: (line: string) => void;
}

export async function verifyGroqModels(
  options: GroqModelVerificationOptions = {},
): Promise<boolean> {
  const env = options.env ?? process.env;
  const fetcher = options.fetcher ?? fetch;
  const write = options.write ?? console.log;
  const apiKey = env.GROQ_API_KEY?.trim() ?? "";
  const requiredModels = [
    ...new Set([
      fixedModels.generalConversation,
      fixedModels.financialExplanation,
    ]),
  ];
  if (apiKey.length === 0) {
    write("Groq model verification: server credential is not configured.");
    return false;
  }

  const baseUrl = (
    env.GROQ_BASE_URL?.trim() || "https://api.groq.com/openai/v1"
  ).replace(/\/+$/u, "");
  let response: Response;
  try {
    response = await fetcher(`${baseUrl}/models`, {
      method: "GET",
      headers: { Authorization: `Bearer ${apiKey}` },
      signal: AbortSignal.timeout(verificationTimeoutMs),
    });
  } catch {
    write("Groq model verification: request failed.");
    return false;
  }
  if (!response.ok) {
    write(`Groq model verification: upstream status ${response.status}.`);
    return false;
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    write("Groq model verification: malformed model metadata.");
    return false;
  }
  const activeIds = new Set(
    typeof body === "object" &&
      body !== null &&
      "data" in body &&
      Array.isArray(body.data)
      ? body.data.flatMap((item) =>
          typeof item === "object" &&
          item !== null &&
          "id" in item &&
          typeof item.id === "string"
            ? [item.id]
            : [],
        )
      : [],
  );
  let allActive = true;
  for (const modelId of requiredModels) {
    const active = activeIds.has(modelId);
    allActive &&= active;
    write(`${modelId}: ${active ? "active" : "missing"}`);
  }
  return allActive;
}

async function main(): Promise<void> {
  if (!(await verifyGroqModels())) {
    process.exitCode = 1;
  }
}

const invokedPath = process.argv[1];
if (
  invokedPath !== undefined &&
  import.meta.url === pathToFileURL(invokedPath).href
) {
  await main();
}
