import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, extname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
);
const output = execFileSync(
  "git",
  [
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "-z",
  ],
  { cwd: repositoryRoot },
).toString("utf8");
const files = output.split("\0").filter(Boolean);
const binaryExtensions = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".zip",
  ".pdf",
  ".ttf",
  ".woff",
  ".woff2",
  ".lock",
]);
const secretPatterns = [
  /\bgsk_[A-Za-z0-9_-]{20,}\b/g,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g,
  /\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/g,
];

const findings: string[] = [];
for (const relativePath of files) {
  if (binaryExtensions.has(extname(relativePath).toLowerCase())) {
    continue;
  }
  let content: string;
  try {
    content = readFileSync(resolve(repositoryRoot, relativePath), "utf8");
  } catch {
    continue;
  }
  for (const pattern of secretPatterns) {
    pattern.lastIndex = 0;
    if (pattern.test(content)) {
      findings.push(relativePath);
      break;
    }
  }
  const normalized = relativePath.replaceAll("\\", "/");
  if (
    /^(?:lib|android|ios|web)\//.test(normalized) &&
    /GROQ_API_KEY|api\.groq\.com|openai\/gpt-oss|groq\/compound|qwen\//.test(
      content,
    )
  ) {
    findings.push(`${relativePath} (provider configuration in client)`);
  }
}

assert.equal(
  files.some((path) => /(^|\/)\.dev\.vars$/.test(path.replaceAll("\\", "/"))),
  false,
  ".dev.vars must not be tracked",
);
assert.deepEqual(
  findings,
  [],
  `Potential secret or client-side provider configuration found:\n${findings.join("\n")}`,
);
