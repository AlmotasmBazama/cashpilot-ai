#!/usr/bin/env node

'use strict';

const { execFileSync } = require('node:child_process');
const path = require('node:path');

const repositoryRoot = path.resolve(__dirname, '..');
const deviceId = process.env.CASHPILOT_ANDROID_DEVICE || 'emulator-5554';
const packageName = 'com.example.cashpilot_ai';
const projectNumber = '102802326815';
const androidAppId = '1:102802326815:android:6c62d29c46586279841c2a';
const debugSecretKey = 'com.google.firebase.appcheck.debug.DEBUG_SECRET';
const debugRegistrationLabel = 'emulator-5554-development';
const apiRoot = 'https://firebaseappcheck.googleapis.com/v1';

function adbPath() {
  const localAppData = process.env.LOCALAPPDATA;
  if (!localAppData) throw new Error('local_android_sdk_unavailable');
  return path.join(localAppData, 'Android', 'sdk', 'platform-tools', 'adb.exe');
}

function readSdkManagedDebugSecret() {
  const adb = adbPath();
  const files = execFileSync(
    adb,
    ['-s', deviceId, 'shell', 'run-as', packageName, 'ls', 'shared_prefs'],
    { cwd: repositoryRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
  )
    .split(/\r?\n/)
    .map((value) => value.trim())
    .filter(Boolean);
  const file = files.find(
    (value) =>
      value.startsWith('com.google.firebase.appcheck.debug.store.') &&
      value.endsWith('.xml'),
  );
  if (!file) throw new Error('app_check_debug_store_unavailable');
  const xml = execFileSync(
    adb,
    [
      '-s',
      deviceId,
      'shell',
      'run-as',
      packageName,
      'cat',
      `shared_prefs/${file}`,
    ],
    { cwd: repositoryRoot, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] },
  );
  const match = xml.match(
    new RegExp(`<string name="${debugSecretKey}">([^<]+)</string>`),
  );
  const secret = match?.[1]?.trim();
  if (!secret || !/^[0-9a-f-]{36}$/i.test(secret)) {
    throw new Error('app_check_debug_secret_invalid');
  }
  return secret;
}

function androidClientApiKey() {
  const servicesPath = path.join(
    repositoryRoot,
    'android',
    'app',
    'google-services.json',
  );
  const services = JSON.parse(
    require('node:fs').readFileSync(servicesPath, 'utf8'),
  );
  const client = services.client?.find(
    (entry) =>
      entry.client_info?.android_client_info?.package_name === packageName,
  );
  const apiKey = client?.api_key?.[0]?.current_key;
  if (typeof apiKey !== 'string' || apiKey.length < 20) {
    throw new Error('firebase_android_client_key_unavailable');
  }
  return apiKey;
}

async function firebaseCliAccessToken() {
  const firebaseToolsRoot = path.join(
    path.dirname(process.execPath),
    'node_modules',
    'firebase-tools',
  );
  const auth = require(path.join(firebaseToolsRoot, 'lib', 'auth.js'));
  const account = auth.getGlobalDefaultAccount();
  const refreshToken = account?.tokens?.refresh_token;
  if (!refreshToken) throw new Error('firebase_cli_login_unavailable');
  const tokens = await auth.getAccessToken(refreshToken, []);
  if (!tokens?.access_token) throw new Error('firebase_access_unavailable');
  return tokens.access_token;
}

async function registerDebugSecret(secret, accessToken) {
  const response = await fetch(
    `${apiRoot}/projects/${projectNumber}/apps/${encodeURIComponent(
      androidAppId,
    )}/debugTokens`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        displayName: debugRegistrationLabel,
        token: secret,
      }),
    },
  );
  if (response.ok) return 'created';
  const body = await response.json().catch(() => null);
  if (body?.error?.status === 'ALREADY_EXISTS') return 'existing';
  throw new Error(`app_check_registration_http_${response.status}`);
}

async function listDebugTokenMetadata(accessToken, {log = true} = {}) {
  const response = await fetch(
    `${apiRoot}/projects/${projectNumber}/apps/${encodeURIComponent(
      androidAppId,
    )}/debugTokens?pageSize=100`,
    {headers: {Authorization: `Bearer ${accessToken}`}},
  );
  if (!response.ok) {
    throw new Error(`app_check_list_http_${response.status}`);
  }
  const body = await response.json().catch(() => null);
  const rows = (body?.debugTokens ?? []).map((entry) => ({
    name: entry.name,
    displayName: entry.displayName,
    createTime: entry.createTime,
    updateTime: entry.updateTime,
  }));
  if (log) console.log(JSON.stringify({count: rows.length, rows}, null, 2));
  return rows;
}

async function deleteDebugTokenRegistration(name, accessToken) {
  const expectedPrefix =
    `projects/${projectNumber}/apps/${androidAppId}/debugTokens/`;
  if (!name.startsWith(expectedPrefix)) {
    throw new Error('app_check_prune_target_invalid');
  }
  const response = await fetch(`${apiRoot}/${name}`, {
    method: 'DELETE',
    headers: {Authorization: `Bearer ${accessToken}`},
  });
  if (!response.ok) {
    throw new Error(`app_check_delete_http_${response.status}`);
  }
}

async function validateDebugSecret(secret) {
  const apiKey = androidClientApiKey();
  const response = await fetch(
    `${apiRoot}/projects/${projectNumber}/apps/${encodeURIComponent(
      androidAppId,
    )}:exchangeDebugToken?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({debug_token: secret}),
    },
  );
  if (!response.ok) {
    throw new Error(`app_check_exchange_http_${response.status}`);
  }
  const body = await response.json().catch(() => null);
  if (typeof body?.token !== 'string' || body.token.length < 20) {
    throw new Error('app_check_exchange_response_invalid');
  }
  return response.status;
}

async function main() {
  let stage = 'read_sdk_debug_store';
  try {
    if (process.argv.includes('--list-safe')) {
      stage = 'firebase_cli_auth';
      const accessToken = await firebaseCliAccessToken();
      stage = 'list_debug_token_metadata';
      await listDebugTokenMetadata(accessToken);
      return;
    }
    if (process.argv.includes('--free-one-stale-slot')) {
      stage = 'firebase_cli_auth';
      const accessToken = await firebaseCliAccessToken();
      stage = 'list_debug_token_metadata';
      const rows = await listDebugTokenMetadata(accessToken, {log: false});
      const currentPresent = rows.some(
        (entry) => entry.displayName === debugRegistrationLabel,
      );
      if (!currentPresent) {
        throw new Error('app_check_current_registration_missing');
      }
      if (rows.length < 20) {
        console.log(
          `APP_CHECK_DEBUG staleSlotFreed=0 currentPreserved=true count=${rows.length}`,
        );
        return;
      }
      const [target] = rows
        .filter((entry) => /^cp-runtime-debug-/.test(entry.displayName ?? ''))
        .sort((left, right) =>
          String(left.updateTime ?? '').localeCompare(
            String(right.updateTime ?? ''),
          ),
        );
      if (!target?.name) {
        throw new Error('app_check_stale_slot_target_missing');
      }
      stage = 'delete_one_stale_debug_registration';
      await deleteDebugTokenRegistration(target.name, accessToken);
      stage = 'verify_stale_slot_cleanup';
      const after = await listDebugTokenMetadata(accessToken, {log: false});
      if (
        after.some((entry) => entry.name === target.name) ||
        !after.some((entry) => entry.displayName === debugRegistrationLabel) ||
        after.length !== rows.length - 1
      ) {
        throw new Error('app_check_stale_slot_cleanup_unverified');
      }
      console.log(
        `APP_CHECK_DEBUG staleSlotFreed=1 currentPreserved=true count=${after.length}`,
      );
      return;
    }
    if (process.argv.includes('--prune-release-stale')) {
      stage = 'firebase_cli_auth';
      const accessToken = await firebaseCliAccessToken();
      stage = 'list_debug_token_metadata';
      const rows = await listDebugTokenMetadata(accessToken, {log: false});
      const cutoff = '2026-08-13T09:30:00Z';
      const stale = rows.filter(
        (entry) =>
          /^cp-(?:runtime-debug|live-ai)-/.test(entry.displayName ?? '') &&
          (entry.updateTime ?? '') >= cutoff,
      );
      stage = 'delete_stale_release_registrations';
      for (const entry of stale) {
        await deleteDebugTokenRegistration(entry.name, accessToken);
      }
      console.log(
        `APP_CHECK_DEBUG stalePruned=${stale.length} currentDeleted=false tokenPrinted=false`,
      );
      return;
    }
    const secret = readSdkManagedDebugSecret();
    console.log('APP_CHECK_DEBUG secretRetrieved=true secretPrinted=false');
    stage = 'validate_existing_debug_secret';
    try {
      const exchangeStatus = await validateDebugSecret(secret);
      console.log(
        `APP_CHECK_DEBUG registration=existing preserved=true device=${deviceId}`,
      );
      console.log(
        `APP_CHECK_DEBUG exchange=accepted status=${exchangeStatus} tokenPrinted=false`,
      );
      return;
    } catch (error) {
      if (
        !(error instanceof Error) ||
        error.message !== 'app_check_exchange_http_403'
      ) {
        throw error;
      }
    }
    stage = 'firebase_cli_auth';
    const accessToken = await firebaseCliAccessToken();
    stage = 'register_debug_secret';
    const result = await registerDebugSecret(secret, accessToken);
    console.log(
      `APP_CHECK_DEBUG registration=${result} preserved=true device=${deviceId}`,
    );
    stage = 'validate_debug_secret';
    const exchangeStatus = await validateDebugSecret(secret);
    console.log(
      `APP_CHECK_DEBUG exchange=accepted status=${exchangeStatus} tokenPrinted=false`,
    );
  } catch (error) {
    const code =
      error instanceof Error && /^[a-z0-9_]+$/.test(error.message)
        ? error.message
        : 'unexpected_safe_failure';
    console.log(`APP_CHECK_DEBUG failureStage=${stage} code=${code}`);
    process.exitCode = 1;
  }
}

void main();
