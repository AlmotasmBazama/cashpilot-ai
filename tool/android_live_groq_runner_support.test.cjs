'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  androidNetworkStateCommands,
  groqDartDefines,
  pollForSdkManagedDebugSecret,
  registerDebugSecret,
} = require('./android_live_groq_runner_support.cjs');
const {
  androidNetworkStateCommands: primitiveNetworkStateCommands,
  createAndroidNetworkStateController,
} = require('./android_network_control_primitives.cjs');

const syntheticDebugSecret = '00000000-0000-4000-8000-000000000000';

test('existing accepted App Check secret is preserved without duplicate registration', async () => {
  const calls = [];
  const result = await registerDebugSecret({
    accessToken: 'ACCESS_TOKEN_SENTINEL_DO_NOT_LOG',
    debugSecret: syntheticDebugSecret,
    suite: 'acceptance',
    fetchImpl: async (url) => {
      calls.push(url);
      return {
        ok: true,
        status: 200,
        async json() {
          return { token: 'APP_CHECK_TOKEN_SENTINEL_123456789' };
        },
      };
    },
  });
  assert.deepEqual(result, { existing: true, resourceCreated: false });
  assert.equal(calls.length, 1);
  assert.match(calls[0], /:exchangeDebugToken\?key=/);
});

test('unaccepted App Check secret is registered once after a 403 exchange', async () => {
  const calls = [];
  const result = await registerDebugSecret({
    accessToken: 'ACCESS_TOKEN_SENTINEL_DO_NOT_LOG',
    debugSecret: syntheticDebugSecret,
    suite: 'acceptance',
    fetchImpl: async (url) => {
      calls.push(url);
      if (calls.length === 1) {
        return { ok: false, status: 403 };
      }
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            name:
              'projects/102802326815/apps/' +
              '1:102802326815:android:6c62d29c46586279841c2a/' +
              'debugTokens/synthetic',
          };
        },
      };
    },
  });
  assert.equal(calls.length, 2);
  assert.match(calls[1], /\/debugTokens$/);
  assert.deepEqual(result, {
    existing: false,
    resourceCreated: true,
    resourceName:
      'projects/102802326815/apps/' +
      '1:102802326815:android:6c62d29c46586279841c2a/' +
      'debugTokens/synthetic',
  });
});

test('Android online commands disable airplane mode and enable radios', () => {
  assert.deepEqual(androidNetworkStateCommands(true), [
    ['shell', 'cmd', 'connectivity', 'airplane-mode', 'disable'],
    ['shell', 'settings', 'put', 'global', 'airplane_mode_on', '0'],
    [
      'shell',
      'am',
      'broadcast',
      '-a',
      'android.intent.action.AIRPLANE_MODE',
      '--ez',
      'state',
      'false',
    ],
    ['shell', 'svc', 'wifi', 'enable'],
    ['shell', 'svc', 'data', 'enable'],
  ]);
});

test('Android offline commands enable airplane mode and disable radios', () => {
  assert.deepEqual(androidNetworkStateCommands(false), [
    ['shell', 'cmd', 'connectivity', 'airplane-mode', 'enable'],
    ['shell', 'settings', 'put', 'global', 'airplane_mode_on', '1'],
    [
      'shell',
      'am',
      'broadcast',
      '-a',
      'android.intent.action.AIRPLANE_MODE',
      '--ez',
      'state',
      'true',
    ],
    ['shell', 'svc', 'wifi', 'disable'],
    ['shell', 'svc', 'data', 'disable'],
  ]);
});

test('injected network controller preserves ADB order, options, and safe state commit', () => {
  assert.strictEqual(androidNetworkStateCommands, primitiveNetworkStateCommands);
  const calls = [];
  const state = { current: 'unknown' };
  const controller = createAndroidNetworkStateController({
    cwd: 'C:\\repo',
    errorForInvalidRequest: () => {
      const error = new Error('safe');
      error.safeCode = 'network_control_contract_invalid';
      return error;
    },
    errorForNotApplied: () => {
      const error = new Error('safe');
      error.safeCode = 'network_state_not_applied';
      return error;
    },
    executeFileSync(executable, args, options) {
      calls.push({ executable, args, options });
      if (args.includes('connectivity')) throw new Error('unsupported');
    },
    requestIsAllowed: (deviceId, networkState) =>
      deviceId === 'emulator-5554' && networkState !== null,
    resolveAdbExecutable: () => 'adb.exe',
    timeoutMs: 15_000,
  });

  assert.equal(controller('emulator-5554', state, false), true);
  assert.equal(state.current, 'offline');
  assert.equal(calls.length, 5);
  assert.deepEqual(
    calls.map((call) => call.args),
    androidNetworkStateCommands(false).map((command) => [
      '-s',
      'emulator-5554',
      ...command,
    ]),
  );
  for (const call of calls) {
    assert.deepEqual(call, {
      executable: 'adb.exe',
      args: call.args,
      options: { cwd: 'C:\\repo', stdio: 'ignore', timeout: 15_000 },
    });
  }
  assert.equal(controller('emulator-5554', state, false), true);
  assert.equal(calls.length, 5);

  const noTimeoutOptions = [];
  const runnerPolicyController = createAndroidNetworkStateController({
    cwd: 'C:\\repo',
    errorForInvalidRequest: () => new Error('invalid'),
    errorForNotApplied: () => new Error('not applied'),
    executeFileSync(_executable, _args, options) {
      noTimeoutOptions.push(options);
    },
    requestIsAllowed: () => true,
    resolveAdbExecutable: () => 'adb.exe',
  });
  assert.equal(
    runnerPolicyController('emulator-5554', { current: 'unknown' }, true),
    true,
  );
  assert.equal(noTimeoutOptions.length, 5);
  for (const options of noTimeoutOptions) {
    assert.deepEqual(options, { cwd: 'C:\\repo', stdio: 'ignore' });
    assert.equal(Object.hasOwn(options, 'timeout'), false);
  }

  const failedState = { current: 'unknown' };
  const failedController = createAndroidNetworkStateController({
    cwd: 'C:\\repo',
    errorForInvalidRequest: () => new Error('invalid'),
    errorForNotApplied: () => {
      const error = new Error('safe');
      error.safeCode = 'network_state_not_applied';
      return error;
    },
    executeFileSync() {
      throw new Error('unsupported');
    },
    requestIsAllowed: () => true,
    resolveAdbExecutable: () => 'adb.exe',
  });
  assert.throws(
    () => failedController('emulator-5554', failedState, true),
    (error) => error.safeCode === 'network_state_not_applied',
  );
  assert.equal(failedState.current, 'unknown');
});

test('Groq Android arguments load the canonical file before tool overrides', () => {
  const defines = groqDartDefines('https://gateway.example', [
    'CASH_PILOT_AI_RATE_LIMIT_PER_MINUTE=20',
  ]);
  const config = JSON.parse(
    fs.readFileSync(
      path.resolve(__dirname, '..', 'config', 'groq_staging.json'),
      'utf8',
    ),
  );

  assert.deepEqual(defines, [
    '--dart-define-from-file=config/groq_staging.json',
    '--dart-define=CASH_PILOT_AI_GATEWAY_BASE_URL=https://gateway.example',
    '--dart-define=CASH_PILOT_AI_RATE_LIMIT_PER_MINUTE=20',
  ]);
  assert.notEqual(
    config.CASH_PILOT_AI_GATEWAY_BASE_URL,
    'https://gateway.example',
  );
  assert.equal(config.CASH_PILOT_ENVIRONMENT, 'staging');
  assert.equal(config.CASH_PILOT_AI_PROVIDER, 'groq');
  assert.equal(config.CASH_PILOT_AI_DIAGNOSTICS, 'false');
  assert.equal(config.CASH_PILOT_AI_GROQ_GATEWAY_ENABLED, 'true');
  assert.equal(config.CASH_PILOT_AI_GROQ_GENERAL_CHAT_ENABLED, 'true');
  assert.equal(
    config.CASH_PILOT_AI_GROQ_FINANCIAL_EXPLANATION_ENABLED,
    'true',
  );
  assert.equal(config.CASH_PILOT_AI_FIREBASE_TEXT_FALLBACK_ENABLED, 'false');
  assert.equal(config.CASH_PILOT_AI_FIREBASE_RECEIPT_VISION_ENABLED, 'true');
  assert.equal(config.CASH_PILOT_CLIENT_VERSION, '1.0.0');
  assert.ok(
    Object.keys(config).every(
      (key) => !/api[_-]?key|secret|password|credential|token/iu.test(key),
    ),
  );
  assert.ok(!defines.some((value) => /api[_-]?key|token=/iu.test(value)));
});

test('Groq Android arguments reject secret-shaped Flutter overrides', () => {
  for (const define of [
    'GROQ_API_KEY=redacted',
    'CASH_PILOT_GROQ_API_KEY=redacted',
    'CASH_PILOT_GROQ_SECRET_KEY=redacted',
    'FIREBASE_APP_CHECK_DEBUG_TOKEN=redacted',
    'CASH_PILOT_SERVICE_ACCOUNT_PRIVATE_KEY=redacted',
  ]) {
    assert.throws(
      () => groqDartDefines('https://gateway.example', [define]),
      /Sensitive values must never be forwarded to Flutter/u,
    );
  }
});

test('debug-store polling tolerates an initially missing package', async () => {
  let reads = 0;
  let clock = 0;
  const suiteFinishedPromise = new Promise(() => {});

  const secret = await pollForSdkManagedDebugSecret({
    deviceId: 'synthetic-device',
    suiteFinishedPromise,
    timeoutMs: 100,
    intervalMs: 10,
    readSecret: () => {
      reads += 1;
      return reads < 3 ? null : syntheticDebugSecret;
    },
    wait: async (milliseconds) => {
      clock += milliseconds;
    },
    now: () => clock,
  });

  assert.equal(secret, syntheticDebugSecret);
  assert.equal(reads, 3);
});

test('debug-store polling is bounded and reports only a safe code', async () => {
  let clock = 0;
  const suiteFinishedPromise = new Promise(() => {});

  await assert.rejects(
    pollForSdkManagedDebugSecret({
      deviceId: 'synthetic-device',
      suiteFinishedPromise,
      timeoutMs: 20,
      intervalMs: 10,
      readSecret: () => null,
      wait: async (milliseconds) => {
        clock += milliseconds;
      },
      now: () => clock,
    }),
    (error) => {
      assert.equal(error.safeCode, 'app_check_store_poll_timed_out');
      assert.ok(!String(error.message).includes(syntheticDebugSecret));
      return true;
    },
  );
});

test('debug-store polling stops when the Flutter suite exits', async () => {
  let finishSuite;
  const suiteFinishedPromise = new Promise((resolve) => {
    finishSuite = resolve;
  });

  await assert.rejects(
    pollForSdkManagedDebugSecret({
      deviceId: 'synthetic-device',
      suiteFinishedPromise,
      timeoutMs: 100,
      intervalMs: 10,
      readSecret: () => {
        finishSuite();
        return null;
      },
      wait: async () => {},
      now: () => 0,
    }),
    (error) => {
      assert.equal(
        error.safeCode,
        'app_check_store_missing_before_suite_exit',
      );
      return true;
    },
  );
});
