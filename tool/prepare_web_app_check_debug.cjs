#!/usr/bin/env node

'use strict';

const path = require('node:path');

const {
  buildWebDefines,
  ensureWebDebugRegistration,
  readDebugToken,
  readJson,
  readWebFirebaseOptions,
  safeErrorCode,
  writePrivateJson,
} = require('./web_app_check_debug_support.cjs');

const repositoryRoot = path.resolve(__dirname, '..');
const stagingConfigPath = path.join(
  repositoryRoot,
  'config',
  'groq_staging.json',
);
const secretConfigPath = path.join(
  repositoryRoot,
  '.dart-define.appcheck.json',
);
const generatedConfigPath = path.join(
  repositoryRoot,
  '.dart-define.groq-staging.local.json',
);
const firebaseOptionsPath = path.join(
  repositoryRoot,
  'lib',
  'firebase_options.dart',
);

async function main() {
  let stage = 'read_local_configuration';
  try {
    const stagingConfig = readJson(stagingConfigPath);
    const debugToken = readDebugToken(secretConfigPath);
    const firebase = readWebFirebaseOptions(firebaseOptionsPath);

    stage = 'write_private_web_configuration';
    writePrivateJson(
      generatedConfigPath,
      buildWebDefines(stagingConfig, debugToken),
    );

    stage = 'ensure_firebase_registration';
    const result = await ensureWebDebugRegistration({debugToken, firebase});
    console.log(
      'WEB_APP_CHECK_READY ' +
        `registration=${result.registration} ` +
        `staleManagedRemoved=${result.removedManagedRegistrations} ` +
        'tokenPrinted=false configGenerated=true',
    );
  } catch (error) {
    console.log(
      `WEB_APP_CHECK_FAILURE stage=${stage} code=${safeErrorCode(error)} ` +
        'tokenPrinted=false',
    );
    process.exitCode = 1;
  }
}

void main();
