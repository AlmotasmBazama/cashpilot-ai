'use strict';

const { execFileSync, spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const {
  androidNetworkStateCommands,
  createAndroidNetworkStateController,
} = require('./android_network_control_primitives.cjs');

const repositoryRoot = path.resolve(__dirname, '..');
const packageName = 'com.example.cashpilot_ai';
const projectNumber = '102802326815';
const androidAppId = '1:102802326815:android:6c62d29c46586279841c2a';
const debugSecretKey = 'com.google.firebase.appcheck.debug.DEBUG_SECRET';
const apiRoot = 'https://firebaseappcheck.googleapis.com/v1';
const safeMarkerPattern =
  /^ANDROID_GROQ_LIVE_[A-Z_]+[ A-Za-z0-9_=,._-]*$/;

function adbPath() {
  const localAppData = process.env.LOCALAPPDATA;
  if (!localAppData) {
    throw new Error('LOCALAPPDATA is unavailable.');
  }
  return path.join(localAppData, 'Android', 'sdk', 'platform-tools', 'adb.exe');
}

function parseGatewayConfiguration(argv) {
  let argumentValue;
  let positionalValue;
  for (let index = 2; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--gateway-url') {
      if (index + 1 >= argv.length) {
        throw new Error('The gateway URL argument has no value.');
      }
      argumentValue = argv[index + 1];
      index += 1;
      continue;
    }
    if (value.startsWith('--gateway-url=')) {
      argumentValue = value.slice('--gateway-url='.length);
      continue;
    }
    if (value.startsWith('--')) {
      throw new Error('An unsupported runner argument was supplied.');
    }
    if (positionalValue !== undefined) {
      throw new Error('More than one positional gateway URL was supplied.');
    }
    positionalValue = value;
  }

  const environmentValue =
    process.env.CASHPILOT_GROQ_GATEWAY_URL ||
    process.env.CASH_PILOT_AI_GATEWAY_BASE_URL;
  const rawValue = argumentValue || positionalValue || environmentValue;
  const source = argumentValue || positionalValue ? 'argument' : 'environment';
  if (!rawValue) {
    throw new Error('The Groq gateway URL is unavailable.');
  }

  const parsed = new URL(rawValue);
  if (
    parsed.protocol !== 'https:' ||
    parsed.username !== '' ||
    parsed.password !== '' ||
    parsed.search !== '' ||
    parsed.hash !== '' ||
    (parsed.pathname !== '' && parsed.pathname !== '/')
  ) {
    throw new Error('The Groq gateway URL must be an HTTPS origin.');
  }
  return { gatewayUrl: parsed.origin, source };
}

function readSdkManagedDebugSecret(deviceId) {
  const adb = adbPath();
  const files = execFileSync(
    adb,
    ['-s', deviceId, 'shell', 'run-as', packageName, 'ls', 'shared_prefs'],
    {
      cwd: repositoryRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 15_000,
    },
  )
    .split(/\r?\n/)
    .map((value) => value.trim())
    .filter(Boolean);
  const file = files.find(
    (value) =>
      value.startsWith('com.google.firebase.appcheck.debug.store.') &&
      value.endsWith('.xml'),
  );
  if (!file) {
    throw new Error('The SDK App Check debug store is unavailable.');
  }
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
    {
      cwd: repositoryRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 15_000,
    },
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

function tryReadSdkManagedDebugSecret(deviceId) {
  try {
    return readSdkManagedDebugSecret(deviceId);
  } catch {
    // A fresh flutter test install may not have created the SDK store yet.
    return null;
  }
}

function boundedWait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function safeRunnerError(code) {
  const error = new Error('The Android live runner failed safely.');
  error.safeCode = code;
  return error;
}

async function pollForSdkManagedDebugSecret({
  deviceId,
  suiteFinishedPromise,
  timeoutMs = 90_000,
  intervalMs = 400,
  readSecret = tryReadSdkManagedDebugSecret,
  wait = boundedWait,
  now = Date.now,
}) {
  const deadline = now() + timeoutMs;
  let suiteFinished = false;
  void suiteFinishedPromise.then(
    () => {
      suiteFinished = true;
    },
    () => {
      suiteFinished = true;
    },
  );

  while (!suiteFinished && now() <= deadline) {
    const secret = readSecret(deviceId);
    if (typeof secret === 'string' && /^[0-9a-f-]{36}$/i.test(secret)) {
      return secret;
    }
    await Promise.race([wait(intervalMs), suiteFinishedPromise]);
  }

  throw safeRunnerError(
    suiteFinished
      ? 'app_check_store_missing_before_suite_exit'
      : 'app_check_store_poll_timed_out',
  );
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
  if (!refreshToken) {
    throw new Error('Firebase CLI login is unavailable.');
  }
  const tokens = await auth.getAccessToken(refreshToken, []);
  if (!tokens?.access_token) {
    throw new Error('Firebase access is unavailable.');
  }
  return tokens.access_token;
}

function debugTokensUrl() {
  return `${apiRoot}/projects/${projectNumber}/apps/${encodeURIComponent(
    androidAppId,
  )}/debugTokens`;
}

function androidClientApiKey() {
  const services = JSON.parse(
    fs.readFileSync(
      path.join(repositoryRoot, 'android', 'app', 'google-services.json'),
      'utf8',
    ),
  );
  const client = services.client?.find(
    (entry) =>
      entry.client_info?.android_client_info?.package_name === packageName,
  );
  const apiKey = client?.api_key?.[0]?.current_key;
  if (typeof apiKey !== 'string' || apiKey.length < 20) {
    throw safeRunnerError('firebase_android_client_key_unavailable');
  }
  return apiKey;
}

async function validateDebugSecret(debugSecret, fetchImpl = fetch) {
  const response = await fetchImpl(
    `${apiRoot}/projects/${projectNumber}/apps/${encodeURIComponent(
      androidAppId,
    )}:exchangeDebugToken?key=${encodeURIComponent(androidClientApiKey())}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ debug_token: debugSecret }),
      signal: AbortSignal.timeout(10_000),
    },
  );
  if (response.status === 403) return false;
  if (!response.ok) {
    throw safeRunnerError(`app_check_exchange_http_${response.status}`);
  }
  let body;
  try {
    body = await response.json().catch(() => null);
    if (typeof body?.token !== 'string' || body.token.length < 20) {
      throw safeRunnerError('app_check_exchange_response_invalid');
    }
    return true;
  } finally {
    body = undefined;
  }
}

async function registerDebugSecret({
  accessToken,
  debugSecret,
  suite,
  fetchImpl = fetch,
}) {
  if (await validateDebugSecret(debugSecret, fetchImpl)) {
    return { existing: true, resourceCreated: false };
  }
  const response = await fetchImpl(debugTokensUrl(), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      displayName: `cp-groq-${suite}-${Date.now()}`,
      token: debugSecret,
    }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) {
    const errorBody = await response.json().catch(() => null);
    if (errorBody?.error?.status === 'ALREADY_EXISTS') {
      return { existing: true, resourceCreated: false };
    }
    const failure = new Error('App Check registration was rejected.');
    failure.safeCode = `app_check_http_${response.status}`;
    throw failure;
  }
  const body = await response.json().catch(() => null);
  if (
    typeof body?.name !== 'string' ||
    !body.name.startsWith(
      `projects/${projectNumber}/apps/${androidAppId}/debugTokens/`,
    )
  ) {
    throw new Error('App Check registration returned no resource name.');
  }
  return {
    existing: false,
    resourceCreated: true,
    resourceName: body.name,
  };
}

const applyDeviceNetworkState = createAndroidNetworkStateController({
  commandsForState: androidNetworkStateCommands,
  cwd: repositoryRoot,
  errorForInvalidRequest: () =>
    new Error(
      'Network recovery requires an emulator or USB-connected device.',
    ),
  errorForNotApplied: (desired) =>
    new Error(`Android network state ${desired} was not applied.`),
  executeFileSync: execFileSync,
  requestIsAllowed: (deviceId) => !deviceId.includes(':'),
  resolveAdbExecutable: adbPath,
});

function setDeviceNetworkOnline(deviceId, state, online) {
  applyDeviceNetworkState(deviceId, state, online);
}

const sensitiveFlutterDefineNamePattern =
  /(?:^|_)(?:GROQ_API_KEY|API_KEY|SECRET(?:_KEY)?|PASSWORD|CREDENTIALS?|PRIVATE_KEY|SIGNING_KEY|TOKEN)$/u;

function groqDartDefines(gatewayUrl, extraDefines = []) {
  const safeExtraDefines = extraDefines.map((value) => {
    if (typeof value !== 'string') {
      throw new Error('Android live Dart defines must be strings.');
    }
    const separatorAt = value.indexOf('=');
    const name = separatorAt < 0 ? '' : value.slice(0, separatorAt);
    if (!/^[A-Z][A-Z0-9_]*$/u.test(name)) {
      throw new Error('Android live Dart define names are invalid.');
    }
    if (sensitiveFlutterDefineNamePattern.test(name)) {
      throw new Error('Sensitive values must never be forwarded to Flutter.');
    }
    return value;
  });

  return [
    '--dart-define-from-file=config/groq_staging.json',
    // Flutter applies these later tool-owned values over the canonical file.
    `--dart-define=CASH_PILOT_AI_GATEWAY_BASE_URL=${gatewayUrl}`,
    ...safeExtraDefines.map((value) => `--dart-define=${value}`),
  ];
}

function runFlutterSuite({
  deviceId,
  gatewayUrl,
  testFile,
  controlsNetwork,
  networkState,
  extraDefines,
  onSafeMarker = () => {},
}) {
  return new Promise((resolve, reject) => {
    const args = [
      'test',
      '--no-pub',
      '-r',
      'compact',
      '--concurrency=1',
      '-d',
      deviceId,
      testFile,
      ...groqDartDefines(gatewayUrl, extraDefines),
    ];
    const child = spawn('flutter.bat', args, {
      cwd: repositoryRoot,
      shell: true,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let pending = '';
    const safeMarkers = [];
    const failureLocations = new Set();
    let networkControlFailed = false;

    const inspectFailureLocation = (chunk) => {
      const text = chunk.toString('utf8');
      const pattern = /android_live_groq_[a-z_]+_test\.dart:(\d+):\d+/g;
      for (const match of text.matchAll(pattern)) {
        failureLocations.add(match[1]);
      }
    };

    const applyNetworkMarker = (marker) => {
      if (!controlsNetwork) {
        return;
      }
      const offline =
        marker === 'ANDROID_GROQ_LIVE_NETWORK_REQUEST state=offline';
      const online = marker === 'ANDROID_GROQ_LIVE_NETWORK_REQUEST state=online';
      if (!offline && !online) {
        return;
      }
      const desired = offline ? 'offline' : 'online';
      try {
        setDeviceNetworkOnline(deviceId, networkState, online);
        safeMarkers.push(
          `ANDROID_GROQ_LIVE_NETWORK_CONTROL state=${desired} applied=true`,
        );
      } catch {
        networkControlFailed = true;
        safeMarkers.push(
          `ANDROID_GROQ_LIVE_NETWORK_CONTROL state=${desired} applied=false`,
        );
      }
    };

    const inspect = (chunk) => {
      inspectFailureLocation(chunk);
      pending += chunk.toString('utf8');
      const lines = pending.split(/\r?\n/);
      pending = lines.pop() ?? '';
      for (const line of lines) {
        const markerAt = line.indexOf('ANDROID_GROQ_LIVE_');
        if (markerAt < 0) {
          continue;
        }
        const marker = line.slice(markerAt).trim();
        if (safeMarkerPattern.test(marker)) {
          safeMarkers.push(marker);
          applyNetworkMarker(marker);
          try {
            onSafeMarker(marker);
          } catch {
            // Marker observers must never interfere with the Flutter process.
          }
        }
      }
    };

    child.stdout.on('data', inspect);
    // Android's App Check debug provider can write its debug secret to stderr.
    // Inspect only source line numbers, then discard stderr without logging,
    // persisting, or reflecting its potentially sensitive text.
    child.stderr.on('data', inspectFailureLocation);
    child.on('error', reject);
    child.on('close', (code) => {
      inspect(Buffer.from('\n'));
      for (const marker of safeMarkers) {
        console.log(marker);
      }
      for (const line of [...failureLocations].sort((a, b) => a - b)) {
        console.log(`ANDROID_GROQ_LIVE_FLUTTER_FAILURE testLine=${line}`);
      }
      resolve({ exitCode: code ?? 1, networkControlFailed });
    });
  });
}

async function registerAppCheckAfterFlutterBootstrap({
  deviceId,
  suite,
  accessToken,
  bootstrapMarkerPromise,
  suiteFinishedPromise,
}) {
  const markerObserved = await Promise.race([
    bootstrapMarkerPromise.then(() => true),
    suiteFinishedPromise.then(() => false),
  ]);
  if (!markerObserved) {
    throw safeRunnerError('app_check_bootstrap_marker_missing');
  }

  let debugSecret;
  try {
    debugSecret = await pollForSdkManagedDebugSecret({
      deviceId,
      suiteFinishedPromise,
    });
    return await registerDebugSecret({ accessToken, debugSecret, suite });
  } finally {
    debugSecret = undefined;
  }
}

async function clearDeviceLogs(deviceId) {
  try {
    execFileSync(adbPath(), ['-s', deviceId, 'logcat', '-c'], {
      cwd: repositoryRoot,
      stdio: 'ignore',
      timeout: 15_000,
    });
    return true;
  } catch {
    return false;
  }
}

async function runGroqAndroidLiveSuite({
  suite,
  testFile,
  controlsNetwork = false,
  extraDefines = [],
}) {
  const deviceId = process.env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554';
  const networkState = { current: 'unknown' };
  let stage = 'gateway_configuration';
  let safeFailureCode = 'none';
  let flutterExitCode = 1;
  let registrationPreserved = false;
  let networkRestored = !controlsNetwork;
  let networkControlFailed = false;
  let accessToken;

  try {
    const gateway = parseGatewayConfiguration(process.argv);
    console.log(
      `ANDROID_GROQ_LIVE_RUNNER_CONFIG suite=${suite} ` +
        `gatewayConfigured=true source=${gateway.source} scheme=https`,
    );
    if (controlsNetwork) {
      stage = 'ensuring_device_network';
      setDeviceNetworkOnline(deviceId, networkState, true);
    }
    stage = 'firebase_cli_auth';
    accessToken = await firebaseCliAccessToken();
    stage = 'flutter_suite_bootstrap';
    let resolveBootstrapMarker;
    const bootstrapMarkerPromise = new Promise((resolve) => {
      resolveBootstrapMarker = resolve;
    });
    let resolveSuiteFinished;
    const suiteFinishedPromise = new Promise((resolve) => {
      resolveSuiteFinished = resolve;
    });
    const flutterSuitePromise = runFlutterSuite({
      deviceId,
      gatewayUrl: gateway.gatewayUrl,
      testFile,
      controlsNetwork,
      networkState,
      extraDefines,
      onSafeMarker: (marker) => {
        if (
          marker.startsWith(
            'ANDROID_GROQ_LIVE_APPCHECK_BOOTSTRAP activationAvailable=true ',
          )
        ) {
          resolveBootstrapMarker();
        }
      },
    }).finally(() => resolveSuiteFinished());
    const registrationPromise = registerAppCheckAfterFlutterBootstrap({
      deviceId,
      suite,
      accessToken,
      bootstrapMarkerPromise,
      suiteFinishedPromise,
    });
    const [flutterSettlement, registrationSettlement] =
      await Promise.allSettled([flutterSuitePromise, registrationPromise]);
    if (registrationSettlement.status === 'rejected') {
      throw registrationSettlement.reason;
    }
    const registration = registrationSettlement.value;
    registrationPreserved =
      registration.existing || registration.resourceCreated;
    console.log(
      'ANDROID_GROQ_LIVE_DEBUG_REGISTRATION ' +
        `created=${registration.resourceCreated} ` +
        `existing=${registration.existing} preserved=true`,
    );
    if (flutterSettlement.status === 'rejected') {
      throw flutterSettlement.reason;
    }
    const result = flutterSettlement.value;
    flutterExitCode = result.exitCode;
    networkControlFailed = result.networkControlFailed;
  } catch (error) {
    safeFailureCode =
      typeof error?.safeCode === 'string' ? error.safeCode : 'runner_failure';
    console.log(
      `ANDROID_GROQ_LIVE_RUNNER_FAILURE stage=${stage} ` +
        `code=${safeFailureCode}`,
    );
    flutterExitCode = 1;
  } finally {
    accessToken = undefined;
    if (controlsNetwork) {
      stage = 'restoring_device_network';
      try {
        setDeviceNetworkOnline(deviceId, networkState, true);
        networkRestored = true;
      } catch {
        networkRestored = false;
      }
    }
    const logsCleared = await clearDeviceLogs(deviceId);
    console.log(
      'ANDROID_GROQ_LIVE_DEBUG_REGISTRATION revoked=false ' +
        `preserved=${registrationPreserved}`,
    );
    if (controlsNetwork) {
      console.log(
        `ANDROID_GROQ_LIVE_NETWORK_RESTORED restored=${networkRestored}`,
      );
    }
    console.log(`ANDROID_GROQ_LIVE_DEVICE_LOGS cleared=${logsCleared}`);
    console.log(`ANDROID_GROQ_LIVE_FLUTTER exitCode=${flutterExitCode}`);
  }

  process.exitCode =
    flutterExitCode === 0 &&
    registrationPreserved &&
    networkRestored &&
    !networkControlFailed
      ? 0
      : 1;
}

module.exports = {
  adbPath,
  androidClientApiKey,
  androidNetworkStateCommands,
  clearDeviceLogs,
  firebaseCliAccessToken,
  groqDartDefines,
  parseGatewayConfiguration,
  pollForSdkManagedDebugSecret,
  readSdkManagedDebugSecret,
  registerDebugSecret,
  runGroqAndroidLiveSuite,
  validateDebugSecret,
};
