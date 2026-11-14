'use strict';

const fs = require('node:fs');
const path = require('node:path');

const apiRoot = 'https://firebaseappcheck.googleapis.com/v1';
const managedRegistrationLabel = 'cashpilot-web-local-development-v1';
const debugTokenPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/iu;

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/u, ''));
  } catch {
    throw new Error('local_config_unreadable');
  }
}

function readDebugToken(secretFilePath) {
  const value = readJson(secretFilePath).FIREBASE_APP_CHECK_DEBUG_TOKEN;
  if (typeof value !== 'string' || !debugTokenPattern.test(value.trim())) {
    throw new Error('web_debug_token_missing_or_invalid');
  }
  return value.trim();
}

function readWebFirebaseOptions(firebaseOptionsPath) {
  let source;
  try {
    source = fs.readFileSync(firebaseOptionsPath, 'utf8');
  } catch {
    throw new Error('firebase_web_options_unreadable');
  }
  const block = source.match(
    /static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\n\s*\);/u,
  )?.[1];
  const field = (name) =>
    block?.match(new RegExp(`${name}:\\s*'([^']+)'`, 'u'))?.[1];
  const apiKey = field('apiKey');
  const appId = field('appId');
  const projectId = field('projectId');
  const projectNumber = appId?.match(/^1:(\d+):web:/u)?.[1];
  if (!apiKey || !appId || !projectId || !projectNumber) {
    throw new Error('firebase_web_options_invalid');
  }
  return {apiKey, appId, projectId, projectNumber};
}

function buildWebDefines(stagingConfig, debugToken) {
  if (
    stagingConfig == null ||
    typeof stagingConfig !== 'object' ||
    Array.isArray(stagingConfig)
  ) {
    throw new Error('staging_config_invalid');
  }
  return {
    ...stagingConfig,
    FIREBASE_APP_CHECK_DEBUG_TOKEN: debugToken,
  };
}

function writePrivateJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, {
    encoding: 'utf8',
    mode: 0o600,
  });
  try {
    fs.chmodSync(filePath, 0o600);
  } catch {
    // Windows does not implement POSIX file modes. The file remains ignored.
  }
}

async function exchangeDebugToken({debugToken, firebase, fetchImpl = fetch}) {
  const response = await fetchImpl(
    `${apiRoot}/projects/${firebase.projectNumber}/apps/${encodeURIComponent(
      firebase.appId,
    )}:exchangeDebugToken?key=${encodeURIComponent(firebase.apiKey)}`,
    {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({debug_token: debugToken}),
    },
  );
  if (response.ok) {
    const body = await response.json().catch(() => null);
    if (typeof body?.token !== 'string' || body.token.length < 20) {
      throw new Error('web_debug_exchange_response_invalid');
    }
    return true;
  }
  if (response.status === 403) {
    return false;
  }
  throw new Error(`web_debug_exchange_http_${response.status}`);
}

async function firebaseCliAccessToken() {
  let auth;
  try {
    const firebaseToolsRoot = path.join(
      path.dirname(process.execPath),
      'node_modules',
      'firebase-tools',
    );
    auth = require(path.join(firebaseToolsRoot, 'lib', 'auth.js'));
  } catch {
    throw new Error('firebase_cli_unavailable');
  }
  const account = auth.getGlobalDefaultAccount();
  const refreshToken = account?.tokens?.refresh_token;
  if (!refreshToken) {
    throw new Error('firebase_cli_login_unavailable');
  }
  const tokens = await auth.getAccessToken(refreshToken, []);
  if (!tokens?.access_token) {
    throw new Error('firebase_access_unavailable');
  }
  return tokens.access_token;
}

function debugTokensCollection(firebase) {
  return `${apiRoot}/projects/${firebase.projectNumber}/apps/${encodeURIComponent(
    firebase.appId,
  )}/debugTokens`;
}

async function listDebugTokenMetadata({firebase, accessToken, fetchImpl = fetch}) {
  const response = await fetchImpl(
    `${debugTokensCollection(firebase)}?pageSize=100`,
    {headers: {Authorization: `Bearer ${accessToken}`}},
  );
  if (!response.ok) {
    throw new Error(`web_debug_list_http_${response.status}`);
  }
  const body = await response.json().catch(() => null);
  return (body?.debugTokens ?? []).map((entry) => ({
    name: entry.name,
    displayName: entry.displayName,
    createTime: entry.createTime,
    updateTime: entry.updateTime,
  }));
}

async function deleteManagedRegistration({
  name,
  firebase,
  accessToken,
  fetchImpl = fetch,
}) {
  const expectedPrefix =
    `projects/${firebase.projectNumber}/apps/${firebase.appId}/debugTokens/`;
  if (typeof name !== 'string' || !name.startsWith(expectedPrefix)) {
    throw new Error('web_debug_prune_target_invalid');
  }
  const response = await fetchImpl(`${apiRoot}/${name}`, {
    method: 'DELETE',
    headers: {Authorization: `Bearer ${accessToken}`},
  });
  if (!response.ok) {
    throw new Error(`web_debug_delete_http_${response.status}`);
  }
}

async function registerDebugToken({
  debugToken,
  firebase,
  accessToken,
  fetchImpl = fetch,
}) {
  const response = await fetchImpl(debugTokensCollection(firebase), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      displayName: managedRegistrationLabel,
      token: debugToken,
    }),
  });
  if (response.ok) {
    return;
  }
  const body = await response.json().catch(() => null);
  if (body?.error?.status === 'ALREADY_EXISTS') {
    return;
  }
  throw new Error(`web_debug_registration_http_${response.status}`);
}

async function ensureWebDebugRegistration({
  debugToken,
  firebase,
  fetchImpl = fetch,
  accessTokenLoader = firebaseCliAccessToken,
}) {
  if (await exchangeDebugToken({debugToken, firebase, fetchImpl})) {
    return {registration: 'existing', removedManagedRegistrations: 0};
  }

  const accessToken = await accessTokenLoader();
  const rows = await listDebugTokenMetadata({
    firebase,
    accessToken,
    fetchImpl,
  });
  const staleManagedRows = rows.filter(
    (entry) => entry.displayName === managedRegistrationLabel,
  );
  for (const entry of staleManagedRows) {
    await deleteManagedRegistration({
      name: entry.name,
      firebase,
      accessToken,
      fetchImpl,
    });
  }
  await registerDebugToken({
    debugToken,
    firebase,
    accessToken,
    fetchImpl,
  });
  if (!(await exchangeDebugToken({debugToken, firebase, fetchImpl}))) {
    throw new Error('web_debug_registration_not_accepted');
  }
  return {
    registration: 'created',
    removedManagedRegistrations: staleManagedRows.length,
  };
}

function safeErrorCode(error) {
  return error instanceof Error && /^[a-z0-9_]+$/u.test(error.message)
    ? error.message
    : 'unexpected_safe_failure';
}

module.exports = {
  buildWebDefines,
  ensureWebDebugRegistration,
  exchangeDebugToken,
  managedRegistrationLabel,
  readDebugToken,
  readJson,
  readWebFirebaseOptions,
  safeErrorCode,
  writePrivateJson,
};
