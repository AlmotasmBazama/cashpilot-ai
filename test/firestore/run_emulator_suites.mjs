import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const repositoryRoot = fileURLToPath(new URL('../..', import.meta.url));
const deletionProviderRoot = path.join(
  repositoryRoot,
  'services',
  'cashpilot_account_deletion',
);

function run(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    env: process.env,
    stdio: 'inherit',
  });
  if (result.error !== undefined) {
    throw result.error;
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

run(
  process.execPath,
  ['--test', 'test/firestore/firestore.rules.test.mjs'],
  repositoryRoot,
);

const tsxCli = path.join(
  deletionProviderRoot,
  'node_modules',
  'tsx',
  'dist',
  'cli.mjs',
);
run(
  process.execPath,
  [tsxCli, '--test', 'tests/account_deletion_emulator.test.ts'],
  deletionProviderRoot,
);
