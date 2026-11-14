#!/usr/bin/env node

'use strict';

const { execFileSync, spawn } = require('node:child_process');
const path = require('node:path');

const repositoryRoot = path.resolve(__dirname, '..');
const deviceId = process.env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554';
const packageName = 'com.example.cashpilot_ai';
const projectNumber = '102802326815';
const androidAppId = '1:102802326815:android:6c62d29c46586279841c2a';
const debugSecretKey = 'com.google.firebase.appcheck.debug.DEBUG_SECRET';
const apiRoot = 'https://firebaseappcheck.googleapis.com/v1';

let registeredResourceName;
let usingExistingRegistration = false;
let accessToken;
let stage = 'initializing';
let safeFailureCode = 'none';
let deviceNetworkState = 'unknown';
let networkControlFailed = false;

function adbPath() {
  const localAppData = process.env.LOCALAPPDATA;
  if (!localAppData) throw new Error('LOCALAPPDATA is unavailable.');
  return path.join(localAppData, 'Android', 'sdk', 'platform-tools', 'adb.exe');
}

function setDeviceNetworkOnline(online) {
  if (deviceId.includes(':')) {
    throw new Error(
      'Network recovery acceptance requires an emulator or USB-connected device.',
    );
  }
  const desired = online ? 'online' : 'offline';
  if (deviceNetworkState === desired) return;
  const enabled = online ? 'enable' : 'disable';
  const setting = online ? '0' : '1';
  const broadcastState = online ? 'false' : 'true';
  const commands = [
    ['shell', 'cmd', 'connectivity', 'airplane-mode', enabled],
    ['shell', 'settings', 'put', 'global', 'airplane_mode_on', setting],
    [
      'shell',
      'am',
      'broadcast',
      '-a',
      'android.intent.action.AIRPLANE_MODE',
      '--ez',
      'state',
      broadcastState,
    ],
    ['shell', 'svc', 'wifi', enabled],
    ['shell', 'svc', 'data', enabled],
  ];
  let appliedCommands = 0;
  for (const command of commands) {
    try {
      execFileSync(adbPath(), ['-s', deviceId, ...command], {
        cwd: repositoryRoot,
        stdio: 'ignore',
      });
      appliedCommands += 1;
    } catch {
      // Android versions expose different subsets of these shell controls.
    }
  }
  if (appliedCommands === 0) {
    throw new Error(`Android network state ${desired} could not be requested.`);
  }
  deviceNetworkState = desired;
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
  if (!file) throw new Error('The SDK App Check debug store is unavailable.');
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
    throw new Error('The SDK App Check debug secret has an invalid shape.');
  }
  return secret;
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
  if (!refreshToken) throw new Error('Firebase CLI login is unavailable.');
  const tokens = await auth.getAccessToken(refreshToken, []);
  if (!tokens?.access_token) throw new Error('Firebase access is unavailable.');
  return tokens.access_token;
}

function debugTokensUrl() {
  return `${apiRoot}/projects/${projectNumber}/apps/${encodeURIComponent(
    androidAppId,
  )}/debugTokens`;
}

async function registerDebugSecret(secret) {
  const response = await fetch(debugTokensUrl(), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      displayName: `cp-live-recovery-${Date.now()}`,
      token: secret,
    }),
  });
  if (!response.ok) {
    const errorBody = await response.json().catch(() => null);
    if (errorBody?.error?.status === 'ALREADY_EXISTS') {
      // Preserve an environment-owned registration instead of deleting it.
      usingExistingRegistration = true;
      return;
    }
    safeFailureCode = `app_check_http_${response.status}`;
    throw new Error(`App Check registration failed with HTTP ${response.status}.`);
  }
  const body = await response.json();
  if (
    typeof body.name !== 'string' ||
    !body.name.endsWith('/debugTokens/' + body.name.split('/').pop())
  ) {
    throw new Error('App Check registration returned no resource name.');
  }
  registeredResourceName = body.name;
}

function preserveDebugRegistration() {
  // Preserve a registration created for a fresh integration-test install.
  // Removing it in teardown makes the next launcher run fail App Check. Token
  // cleanup must be an explicit environment-management action, not a test side
  // effect.
  return usingExistingRegistration || Boolean(registeredResourceName);
}

function applyNetworkMarker(marker, safeMarkers) {
  const offline = marker === 'ANDROID_LIVE_NETWORK_REQUEST state=offline';
  const online = marker === 'ANDROID_LIVE_NETWORK_REQUEST state=online';
  if (!offline && !online) return;
  const state = offline ? 'offline' : 'online';
  try {
    setDeviceNetworkOnline(online);
    safeMarkers.push(
      `ANDROID_LIVE_NETWORK_CONTROL state=${state} applied=true`,
    );
  } catch {
    networkControlFailed = true;
    safeMarkers.push(
      `ANDROID_LIVE_NETWORK_CONTROL state=${state} applied=false`,
    );
  }
}

function runFlutterAcceptance() {
  return new Promise((resolve, reject) => {
    const args = [
      'test',
      '--no-pub',
      '-r',
      'compact',
      '--concurrency=1',
      '-d',
      deviceId,
      'integration_test/android_live_ai_failure_recovery_test.dart',
      '--dart-define=CASH_PILOT_AI_PROVIDER=firebaseGemini',
      '--dart-define=CASH_PILOT_FIREBASE_AI_BACKEND=vertex',
    ];
    const child = spawn('flutter.bat', args, {
      cwd: repositoryRoot,
      shell: true,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let pending = '';
    const safeMarkers = [];
    const inspect = (chunk) => {
      pending += chunk.toString('utf8');
      const lines = pending.split(/\r?\n/);
      pending = lines.pop() ?? '';
      for (const line of lines) {
        const markerAt = line.indexOf('ANDROID_LIVE_');
        if (markerAt < 0) continue;
        const marker = line.slice(markerAt).trim();
        if (/^ANDROID_LIVE_[A-Z_]+[ A-Za-z0-9_=,._-]*$/.test(marker)) {
          safeMarkers.push(marker);
          applyNetworkMarker(marker, safeMarkers);
        }
      }
    };
    child.stdout.on('data', inspect);
    // Native debug-provider output can contain its secret. Consume and discard
    // stderr without logging, persisting, or reflecting any line.
    child.stderr.on('data', () => {});
    child.on('error', reject);
    child.on('close', (code) => {
      inspect(Buffer.from('\n'));
      for (const marker of safeMarkers) console.log(marker);
      resolve(code ?? 1);
    });
  });
}

async function clearDeviceLogs() {
  try {
    execFileSync(adbPath(), ['-s', deviceId, 'logcat', '-c'], {
      stdio: 'ignore',
    });
    return true;
  } catch {
    return false;
  }
}

async function main() {
  let flutterExitCode = 1;
  let registrationPreserved = false;
  let networkRestored = false;
  try {
    stage = 'ensuring_device_network';
    setDeviceNetworkOnline(true);
    stage = 'reading_sdk_store';
    const debugSecret = readSdkManagedDebugSecret();
    stage = 'firebase_auth';
    accessToken = await firebaseCliAccessToken();
    stage = 'registering_debug_token';
    await registerDebugSecret(debugSecret);
    console.log(
      `ANDROID_LIVE_DEBUG_REGISTRATION temporary=${!usingExistingRegistration} ` +
        `existing=${usingExistingRegistration}`,
    );
    stage = 'flutter_failure_recovery';
    flutterExitCode = await runFlutterAcceptance();
  } catch {
    console.log(
      `ANDROID_LIVE_RUNNER_FAILURE stage=${stage} code=${safeFailureCode}`,
    );
    flutterExitCode = 1;
  } finally {
    stage = 'restoring_device_network';
    try {
      setDeviceNetworkOnline(true);
      networkRestored = true;
    } catch {
      networkRestored = false;
    }
    stage = 'preserving_debug_token';
    registrationPreserved = preserveDebugRegistration();
    const logsCleared = await clearDeviceLogs();
    console.log(
      `ANDROID_LIVE_DEBUG_REGISTRATION revoked=false ` +
        `preserved=${registrationPreserved}`,
    );
    console.log(`ANDROID_LIVE_NETWORK_RESTORED restored=${networkRestored}`);
    console.log(`ANDROID_LIVE_DEVICE_LOGS cleared=${logsCleared}`);
    console.log(`ANDROID_LIVE_FLUTTER exitCode=${flutterExitCode}`);
  }
  process.exitCode =
    flutterExitCode === 0 &&
    registrationPreserved &&
    networkRestored &&
    !networkControlFailed
      ? 0
      : 1;
}

module.exports = Object.freeze({ main });
