'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const {
  acceptanceBuildExtraDefines,
  acceptanceStateFromUiXml,
  approvedGatewayHost,
  authSurfaceFromUiXml,
  collectRequiredSettingsRows,
  collectSettingsRowsAcrossRefreshes,
  composerInputStateFromUiXml,
  credentialClearCommands,
  createProductionAdapter,
  createSyntheticProfile,
  deleteSyntheticProfile,
  emailInputCommands,
  executeForceStopAcceptance,
  fillAndSubmitLogin,
  findAndTapLoginSubmit,
  findUiTarget,
  firestoreProfileUrl,
  loginStateFromUiXml,
  normalizeSignedOutSession,
  observeLoginAuthentication,
  observeQuestionCompletion,
  observeSettingsTestTransition,
  parseForceStopArguments,
  pidFromCommandResult,
  performResourceIdLogout,
  prepareAndSubmitQuestion,
  proveProcessRestart,
  questionInputMode,
  settingsRequiredResourceIds,
  settingsStateFromUiXml,
  syntheticPassword,
  triggerSettingsLiveTest,
  verifySyntheticCredentials,
} = require('./android_live_groq_force_stop_support.cjs');
const {
  assertBoundedUiXml,
  decodeXmlAttribute,
  maxUiXmlBytes,
  nodeAttributes,
  pointFromBounds,
  rectFromBounds,
  resourceIdMatches,
} = require('./android_uiautomator_xml_primitives.cjs');
const {
  safeCodeFor: sharedSafeCodeFor,
  serializeSafeMarkerFields,
} = require('./android_safe_output_primitives.cjs');
const {
  createAdbExecutor,
  createUiDumpLifecycle,
  longPressPoint: executeLongPress,
  tapPoint: executeTap,
} = require('./android_adb_ui_primitives.cjs');
const {
  createFirebaseAcceptanceFixtures,
} = require('./android_firebase_acceptance_fixtures.cjs');
const {
  createAndroidSettingsAcceptanceSupport,
} = require('./android_settings_acceptance_support.cjs');
const {
  createAndroidAuthAcceptanceSupport,
} = require('./android_auth_acceptance_support.cjs');
const {
  createAndroidAiQuestionAcceptanceSupport,
} = require('./android_ai_question_acceptance_support.cjs');
const {
  createAndroidDeviceLifecycleSupport,
} = require('./android_device_lifecycle_support.cjs');

function fixtureSafeError(code) {
  const error = new Error('safe');
  error.safeCode = code;
  return error;
}

function createInjectedFirebaseFixtures(overrides = {}) {
  return createFirebaseAcceptanceFixtures({
    repositoryRoot: 'C:\\repo',
    packageName: 'com.example.cashpilot_ai',
    firebaseProjectId: 'cashpilot-ai-a6b49',
    readFileSync: () =>
      JSON.stringify({
        project_info: { project_id: 'cashpilot-ai-a6b49' },
        client: [
          {
            client_info: {
              android_client_info: {
                package_name: 'com.example.cashpilot_ai',
              },
            },
            api_key: [{ current_key: 'API_KEY_SENTINEL_123456789' }],
          },
        ],
      }),
    randomBytes: (size) => ({
      toString: () => (size === 8 ? '0123456789abcdef' : 'f'.repeat(32)),
    }),
    fetchImplementation: async () => {
      throw new Error('unexpected fetch');
    },
    timeoutSignal: (milliseconds) => ({ milliseconds }),
    waitImpl: async () => {},
    readSdkManagedDebugSecret: () => 'debug-secret',
    registerDebugSecret: async () => ({ resourceCreated: false }),
    firebaseCliAccessToken: async () => 'ACCESS_TOKEN_SENTINEL',
    safeRunnerError: fixtureSafeError,
    ...overrides,
  });
}

function createInjectedSettingsSupport(overrides = {}) {
  const packageName = 'com.example.cashpilot_ai';
  return createAndroidSettingsAcceptanceSupport({
    adbExec() {
      throw new Error('unexpected adb');
    },
    assertBoundedUiXml: (xml) =>
      assertBoundedUiXml(xml, () => fixtureSafeError('ui_snapshot_invalid')),
    deviceViewport: () => Object.freeze({ width: 1_000, height: 2_000 }),
    findUiTarget: () => null,
    isTransientUiSnapshotError: (error) =>
      ['ui_dump_failed', 'ui_dump_read_failed'].includes(
        sharedSafeCodeFor(error),
      ),
    nodeAttributes,
    nowImpl: () => 0,
    safeCodeFor: sharedSafeCodeFor,
    safeRunnerError: fixtureSafeError,
    settingsScreenSize: () =>
      Object.freeze({ width: 1_000, height: 2_000 }),
    snapshotUi: () => '<hierarchy />',
    strictSettingsResourceId(resourceId) {
      if (/^[A-Za-z0-9_]+$/.test(resourceId)) return resourceId;
      const prefix = `${packageName}:id/`;
      if (!resourceId.startsWith(prefix)) return null;
      const identifier = resourceId.slice(prefix.length);
      return /^[A-Za-z0-9_]+$/.test(identifier) ? identifier : null;
    },
    tapPoint() {
      throw new Error('unexpected tap');
    },
    validViewport: (viewport) =>
      viewport !== null &&
      typeof viewport === 'object' &&
      Number.isSafeInteger(viewport.width) &&
      viewport.width > 0 &&
      Number.isSafeInteger(viewport.height) &&
      viewport.height > 0,
    waitForTarget() {
      throw new Error('unexpected target wait');
    },
    waitImpl: async () => {},
    ...overrides,
  });
}

function createInjectedAuthSupport(overrides = {}) {
  return createAndroidAuthAcceptanceSupport({
    adbExec() {
      throw new Error('unexpected adb');
    },
    assertBoundedUiXml: (xml) =>
      assertBoundedUiXml(xml, () => fixtureSafeError('ui_snapshot_invalid')),
    deviceViewport: () => Object.freeze({ width: 1_000, height: 2_000 }),
    findUiTarget: () => null,
    inputText() {
      throw new Error('unexpected input');
    },
    isTransientUiSnapshotError: () => false,
    nowImpl: () => 0,
    async openSettingsPage() {
      throw new Error('unexpected Settings navigation');
    },
    async resetSettingsScroll() {
      throw new Error('unexpected Settings reset');
    },
    safeRunnerError: fixtureSafeError,
    settingsScreenSize: () =>
      Object.freeze({ width: 1_000, height: 2_000 }),
    snapshotUi: () => '<hierarchy />',
    strictSettingsResourceId(resourceId) {
      const marker = ':id/';
      const identifier = resourceId.includes(marker)
        ? resourceId.slice(resourceId.indexOf(marker) + marker.length)
        : resourceId;
      return /^[A-Za-z0-9_]+$/.test(identifier) ? identifier : null;
    },
    tapPoint() {
      throw new Error('unexpected tap');
    },
    async tapTarget() {
      throw new Error('unexpected target tap');
    },
    uiNodesWithParents: (xml) =>
      [...xml.matchAll(/<node\s+([^>]+)>?/g)].map((match) => ({
        attributes: nodeAttributes(match[1]),
      })),
    async waitForTarget() {
      throw new Error('unexpected target wait');
    },
    waitImpl: async () => {},
    ...overrides,
  });
}

function createInjectedAiQuestionSupport(overrides = {}) {
  return createAndroidAiQuestionAcceptanceSupport({
    adbExec() {
      throw new Error('unexpected adb');
    },
    assertBoundedUiXml: (xml) =>
      assertBoundedUiXml(xml, () => fixtureSafeError('ui_snapshot_invalid')),
    composerResourceIdentifiers: ['cashpilot_acceptance_ai_composer'],
    executeLongPress() {
      throw new Error('unexpected long press');
    },
    findUiTarget: () => null,
    inputText() {
      throw new Error('unexpected input');
    },
    isTransientUiSnapshotError: () => false,
    nodeAttributes,
    nowImpl: () => 0,
    resourceIdMatches,
    safeRunnerError: fixtureSafeError,
    snapshotUi: () => '<hierarchy />',
    tapPoint() {
      throw new Error('unexpected tap');
    },
    uiNodesWithParents: (xml) =>
      [...xml.matchAll(/<node\s+([^>]+)>?/g)].map((match) => ({
        attributes: nodeAttributes(match[1]),
      })),
    async waitForTarget() {
      throw new Error('unexpected target wait');
    },
    waitImpl: async () => {},
    ...overrides,
  });
}

function createInjectedDeviceLifecycleSupport(overrides = {}) {
  return createAndroidDeviceLifecycleSupport({
    adbExec() {
      throw new Error('unexpected adb');
    },
    clearDeviceLogs() {},
    existsSync: () => false,
    fetchImplementation: async () => {
      throw new Error('unexpected fetch');
    },
    groqDartDefines: () => [
      '--dart-define=CASH_PILOT_AI_GATEWAY_BASE_URL=https://example.test',
    ],
    joinPath: (...parts) => parts.join('\\'),
    launcherComponent: 'com.example.cashpilot_ai/.MainActivity',
    nowImpl: () => 0,
    packageName: 'com.example.cashpilot_ai',
    repositoryRoot: 'C:\\repo',
    resolveAdbPath: () => 'C:\\sdk\\adb.exe',
    safeRunnerError: fixtureSafeError,
    spawnSyncImplementation() {
      throw new Error('unexpected spawn');
    },
    timeoutSignal: (milliseconds) => ({ milliseconds }),
    waitImpl: async () => {},
    ...overrides,
  });
}

test('shared UIAutomator XML primitives preserve exact decoding and attributes', () => {
  assert.equal(
    decodeXmlAttribute('&quot;&apos;&lt;&gt;&amp;&amp;lt;'),
    '"\'<>&&lt;',
  );

  const attributes = nodeAttributes(
    'resource-id="com.example:id/trusted" enabled="true" text="A&amp;B" ignored=unquoted',
  );
  assert.equal(Object.getPrototypeOf(attributes), null);
  assert.deepEqual({ ...attributes }, {
    'resource-id': 'com.example:id/trusted',
    enabled: 'true',
    text: 'A&B',
  });
});

test('shared UIAutomator bounds, resource IDs, and byte cap stay fail-closed', () => {
  const rect = rectFromBounds('[1,2][10,13]');
  assert.deepEqual(rect, { left: 1, top: 2, right: 10, bottom: 13 });
  assert.equal(Object.isFrozen(rect), true);
  assert.deepEqual(pointFromBounds('[1,2][10,13]'), { x: 5, y: 7 });
  assert.equal(pointFromBounds('[1,2][1,13]'), null);
  assert.equal(pointFromBounds('[-1,2][10,13]'), null);

  assert.equal(resourceIdMatches('trusted', 'trusted'), true);
  assert.equal(resourceIdMatches('com.example:id/trusted', 'trusted'), true);
  assert.equal(resourceIdMatches('com.example:trusted', 'trusted'), true);
  assert.equal(resourceIdMatches('com.example:id/trusted_extra', 'trusted'), false);

  const invalidSnapshot = new Error('safe');
  invalidSnapshot.safeCode = 'ui_snapshot_invalid';
  const invalidSnapshotError = () => invalidSnapshot;
  assert.doesNotThrow(() => assertBoundedUiXml('x', invalidSnapshotError));
  assert.throws(
    () => assertBoundedUiXml(null, invalidSnapshotError),
    (error) => error === invalidSnapshot,
  );
  assert.throws(
    () =>
      assertBoundedUiXml('x'.repeat(maxUiXmlBytes + 1), invalidSnapshotError),
    (error) => error === invalidSnapshot,
  );
});

test('shared safe-output primitives keep codes and marker fields content-blind', () => {
  assert.equal(sharedSafeCodeFor({ safeCode: 'known_safe_code' }), 'known_safe_code');
  assert.equal(sharedSafeCodeFor({ safeCode: 'UNSAFE' }), 'runner_failure');
  assert.equal(sharedSafeCodeFor(new Error('SENSITIVE')), 'runner_failure');
  assert.deepEqual(
    serializeSafeMarkerFields(
      { stage: 'ui_parse', attempt: 2, complete: false },
      () => new Error('unsafe_marker_value'),
    ),
    ['stage=ui_parse', 'attempt=2', 'complete=false'],
  );
  assert.throws(
    () =>
      serializeSafeMarkerFields({ unsafe_key: 'contains spaces' }, () => {
        const error = new Error('safe');
        error.safeCode = 'unsafe_marker_value';
        return error;
      }),
    (error) => error.safeCode === 'unsafe_marker_value',
  );
});

test('shared ADB executor preserves exact invocation options and safe failures', () => {
  const calls = [];
  const executeAdb = createAdbExecutor({
    resolveExecutable: () => 'C:\\sdk\\adb.exe',
    cwd: 'C:\\repo',
    defaultMaxBuffer: 2_097_152,
    errorForCode(code) {
      const error = new Error('safe');
      error.safeCode = code;
      return error;
    },
    execFileSyncImpl(executable, args, options) {
      calls.push({ executable, args, options });
      if (args.includes('fail')) throw new Error('SENSITIVE');
      return 'RESULT';
    },
  });

  assert.equal(
    executeAdb('emulator-5554', ['exec-out', 'cat', '/fixed.xml'], {
      capture: true,
      encoding: 'utf8',
      maxBuffer: 1024,
      timeoutMs: 5000,
      safeCode: 'read_failed',
    }),
    'RESULT',
  );
  assert.deepEqual(calls[0], {
    executable: 'C:\\sdk\\adb.exe',
    args: ['-s', 'emulator-5554', 'exec-out', 'cat', '/fixed.xml'],
    options: {
      cwd: 'C:\\repo',
      encoding: 'utf8',
      maxBuffer: 1024,
      timeout: 5000,
      stdio: ['ignore', 'pipe', 'ignore'],
    },
  });
  assert.throws(
    () =>
      executeAdb('emulator-5554', ['fail'], {
        safeCode: 'fixed_safe_failure',
      }),
    (error) =>
      error.safeCode === 'fixed_safe_failure' &&
      !error.message.includes('SENSITIVE'),
  );
});

test('shared UI dump lifecycle always verifies bounded cleanup and input commands', () => {
  const calls = [];
  const xml = '<hierarchy />';
  const executeAdb = (deviceId, args, options) => {
    calls.push({ deviceId, args, options });
    return args[0] === 'exec-out' ? xml : undefined;
  };
  const lifecycle = createUiDumpLifecycle({
    executeAdb,
    remoteUiDumpPath: '/data/local/tmp/fixed.xml',
    maxUiXmlBytes: 2_097_152,
    assertBoundedUiXml(value) {
      assert.equal(value, xml);
    },
    errorForCode(code) {
      const error = new Error('safe');
      error.safeCode = code;
      return error;
    },
  });

  assert.equal(lifecycle.snapshotUi('emulator-5554'), xml);
  assert.deepEqual(
    calls.map((call) => call.args),
    [
      [
        'shell',
        'uiautomator',
        'dump',
        '--compressed',
        '/data/local/tmp/fixed.xml',
      ],
      ['exec-out', 'cat', '/data/local/tmp/fixed.xml'],
      ['shell', 'rm', '-f', '/data/local/tmp/fixed.xml'],
      ['shell', 'test', '!', '-e', '/data/local/tmp/fixed.xml'],
    ],
  );
  executeTap(executeAdb, 'emulator-5554', { x: 10, y: 20 });
  executeLongPress(executeAdb, 'emulator-5554', { x: 30, y: 40 }, 800);
  assert.deepEqual(calls.at(-2).args, ['shell', 'input', 'tap', '10', '20']);
  assert.deepEqual(calls.at(-1).args, [
    'shell',
    'input',
    'swipe',
    '30',
    '40',
    '30',
    '40',
    '800',
  ]);

  let cleanupAttempts = 0;
  const failingCleanup = createUiDumpLifecycle({
    executeAdb(_deviceId, args) {
      if (args[1] === 'rm') {
        cleanupAttempts += 1;
        throw new Error('SENSITIVE');
      }
      return args[0] === 'exec-out' ? xml : undefined;
    },
    remoteUiDumpPath: '/data/local/tmp/fixed.xml',
    maxUiXmlBytes: 2_097_152,
    assertBoundedUiXml() {},
    errorForCode(code) {
      const error = new Error('safe');
      error.safeCode = code;
      return error;
    },
  });
  assert.throws(
    () => failingCleanup.snapshotUi('emulator-5554'),
    (error) =>
      error.safeCode === 'ui_dump_cleanup_failed' &&
      !error.message.includes('SENSITIVE'),
  );
  assert.equal(cleanupAttempts, 3);
});

test('Android acceptance support compatibility exports stay exact', () => {
  const forceStopSupport = require('./android_live_groq_force_stop_support.cjs');
  const smallTalkSupport = require('./android_appcheck_smalltalk_acceptance_support.cjs');
  const plainRunSupport = require('./android_plain_flutter_run_acceptance_support.cjs');

  assert.deepEqual(Object.keys(forceStopSupport).sort(), [
    'acceptanceBuildExtraDefines',
    'acceptanceStateFromUiXml',
    'approvedGatewayHost',
    'authSurfaceFromUiXml',
    'collectRequiredSettingsRows',
    'collectSettingsRowsAcrossRefreshes',
    'composerInputStateFromUiXml',
    'createProductionAdapter',
    'createSyntheticProfile',
    'credentialClearCommands',
    'deleteSyntheticProfile',
    'emailInputCommands',
    'emitSafeMarker',
    'executeForceStopAcceptance',
    'fillAndSubmitLogin',
    'findAndTapLoginSubmit',
    'findUiTarget',
    'firestoreProfileUrl',
    'loginStateFromUiXml',
    'main',
    'normalizeSignedOutSession',
    'observeLoginAuthentication',
    'observeQuestionCompletion',
    'observeSettingsTestTransition',
    'parseForceStopArguments',
    'performResourceIdLogout',
    'pidFromCommandResult',
    'prepareAndSubmitQuestion',
    'proveProcessRestart',
    'questionInputMode',
    'settingsRequiredResourceIds',
    'settingsStateFromUiXml',
    'syntheticPassword',
    'triggerSettingsLiveTest',
    'verifySyntheticCredentials',
  ]);
  assert.deepEqual(Object.keys(smallTalkSupport).sort(), [
    'acceptanceUiStateFromXml',
    'closeGatewayWindow',
    'createGatewayWindow',
    'createProductionAcceptanceAdapter',
    'createProductionCoordinator',
    'emitSafeMarker',
    'executeAcceptance',
    'listSafeGatewayTraces',
    'longPressPoint',
    'main',
    'observeOfflineRetryCompletion',
    'offlineQuestionInputCommands',
    'parseAcceptanceArguments',
    'parseSafeTraceEntry',
    'resourcePointFromUiXml',
    'validateTraceExpectation',
    'verifyGatewayTraceWindow',
    'waitForDeviceNetworkState',
    'waitForExternalAppStart',
    'waitForExternalAppState',
  ]);
  assert.deepEqual(Object.keys(plainRunSupport).sort(), [
    'createProductionCoordinator',
    'emitPlainMarker',
    'executePlainFlutterAcceptance',
    'main',
    'parsePlainRunArguments',
    'requireQuestionProof',
    'requireSettingsLiveProof',
    'requireSettingsProof',
    'waitForExternalProcessState',
  ]);
});

test('production adapter lifecycle surface is inert until explicitly invoked', () => {
  const adapter = createProductionAdapter();

  assert.deepEqual(Object.keys(adapter), [
    'askQuestion',
    'buildAndInstall',
    'clearLogs',
    'clearUiDump',
    'createSyntheticUser',
    'deleteAppCheckRegistration',
    'deleteSyntheticProfile',
    'deleteSyntheticUser',
    'forceStop',
    'getPid',
    'inspectFeasibility',
    'loadCloudCredentials',
    'login',
    'logout',
    'launchFromLauncher',
    'navigateToDashboard',
    'normalizeSignedOut',
    'openAi',
    'reachLoginScreen',
    'registerAppCheck',
    'runSettingsLiveTest',
    'uninstall',
    'verifyRestoredSettings',
    'verifyGatewayHealth',
    'verifySettings',
    'waitForNewPid',
    'waitForStopped',
  ]);
  assert.equal(
    Object.values(adapter).every((operation) => typeof operation === 'function'),
    true,
  );
});

test('shared acceptance composition owns implementations without reverse imports', () => {
  const sharedSupport = require('./android_cashpilot_acceptance_support.cjs');
  const forceStopSupport = require('./android_live_groq_force_stop_support.cjs');
  const settingsSource = fs.readFileSync(
    `${__dirname}/android_settings_acceptance_support.cjs`,
    'utf8',
  );
  const authSource = fs.readFileSync(
    `${__dirname}/android_auth_acceptance_support.cjs`,
    'utf8',
  );
  const aiQuestionSource = fs.readFileSync(
    `${__dirname}/android_ai_question_acceptance_support.cjs`,
    'utf8',
  );
  const deviceLifecycleSource = fs.readFileSync(
    `${__dirname}/android_device_lifecycle_support.cjs`,
    'utf8',
  );
  const sources = [
    'android_cashpilot_acceptance_support.cjs',
    'android_ai_question_acceptance_support.cjs',
    'android_auth_acceptance_support.cjs',
    'android_device_lifecycle_support.cjs',
    'android_firebase_acceptance_fixtures.cjs',
    'android_settings_acceptance_support.cjs',
    'android_appcheck_smalltalk_acceptance_support.cjs',
    'android_plain_flutter_run_acceptance_support.cjs',
  ].map((file) => fs.readFileSync(`${__dirname}/${file}`, 'utf8'));

  for (const source of sources) {
    assert.doesNotMatch(
      source,
      /require\(['"]\.\/android_live_groq_force_stop_support\.cjs['"]\)/,
    );
  }
  assert.doesNotMatch(
    `${settingsSource}\n${authSource}\n${aiQuestionSource}\n${deviceLifecycleSource}`,
    /require\(['"]\.\/android_(?:cashpilot_acceptance|appcheck_smalltalk_acceptance|plain_flutter_run_acceptance|live_groq_force_stop)_support\.cjs['"]\)/,
  );
  const sharedSource = sources[0];
  assert.doesNotMatch(
    sharedSource,
    /function (?:authSurfaceFromUiXml|loginStateFromUiXml|credentialClearCommands|emailInputCommands|reachLoginScreen|normalizeSignedOutSession|findAndTapLoginSubmit|fillAndSubmitLogin|performResourceIdLogout|composerInputStateFromUiXml|acceptanceStateFromUiXml|waitForComposerInputState|openAiAssistant|readAcceptanceState|questionInputMode|selectAllQuestionComposer|deleteSelectedQuestionComposer|prepareAndSubmitQuestion|observeQuestionCompletion|askGroqQuestion|proveProcessRestart|pidFromCommandResult|currentPid|launchFromLauncher|waitForPid|verifyGatewayHealth|inspectFeasibility|buildAndInstall|bestEffortUninstall|packageIsInstalled)\(/,
  );
  for (const [name, implementation] of Object.entries(sharedSupport)) {
    if (name === 'safeRunnerError') continue;
    assert.strictEqual(forceStopSupport[name], implementation, name);
  }
  assert.strictEqual(
    forceStopSupport.createProductionAdapter,
    sharedSupport.createProductionAdapter,
  );
});

test('injected Firebase fixtures compose config and synthetic account/profile exactly', async () => {
  const calls = [];
  let configRead;
  const fixtures = createInjectedFirebaseFixtures({
    readFileSync: (file, encoding) => {
      configRead = { file, encoding };
      return JSON.stringify({
        project_info: { project_id: 'cashpilot-ai-a6b49' },
        client: [
          {
            client_info: {
              android_client_info: {
                package_name: 'com.example.cashpilot_ai',
              },
            },
            api_key: [{ current_key: 'API_KEY_SENTINEL_123456789' }],
          },
        ],
      });
    },
    fetchImplementation: async (url, options) => {
      calls.push({ url, options });
      if (url.endsWith('/accounts:signUp')) {
        const body = JSON.parse(options.body);
        assert.equal(body.localId, 'cp-restart-0123456789abcdef');
        assert.equal(body.targetProjectId, 'cashpilot-ai-a6b49');
        return {
          ok: true,
          status: 200,
          json: async () => ({ localId: body.localId }),
        };
      }
      if (url.endsWith('/accounts:query')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            userInfo: [
              {
                localId: 'cp-restart-0123456789abcdef',
                emailVerified: true,
                displayName: 'CashPilot Restart Acceptance',
              },
            ],
          }),
        };
      }
      if (url.includes('accounts:signInWithPassword')) {
        return {
          ok: true,
          status: 200,
          json: async () => ({
            localId: 'cp-restart-0123456789abcdef',
            idToken: 'ID_TOKEN_SENTINEL_123456789',
          }),
        };
      }
      if (options.method === 'PATCH') {
        const body = JSON.parse(options.body);
        return {
          ok: true,
          status: 200,
          json: async () => ({
            name:
              'projects/cashpilot-ai-a6b49/databases/(default)/documents/' +
              'users/cp-restart-0123456789abcdef',
            fields: body.fields,
          }),
        };
      }
      throw new Error('unexpected fixture request');
    },
  });

  assert.deepEqual(await fixtures.loadCloudCredentials(), {
    accessToken: 'ACCESS_TOKEN_SENTINEL',
    apiKey: 'API_KEY_SENTINEL_123456789',
  });
  assert.match(configRead.file, /android[\\/]app[\\/]google-services\.json$/);
  assert.equal(configRead.encoding, 'utf8');
  assert.deepEqual(
    await fixtures.createSyntheticUser({
      accessToken: 'ACCESS_TOKEN_SENTINEL',
      apiKey: 'API_KEY_SENTINEL_123456789',
    }),
    {
      email: 'cp-0123456789abcdef@example.com',
      password: 'cp9ffffffffffffffff',
      localId: 'cp-restart-0123456789abcdef',
    },
  );
  assert.deepEqual(
    calls.map(({ options }) => options.method),
    ['POST', 'POST', 'POST', 'PATCH'],
  );
});

test('injected App Check fixture preserves bounded retry and validated cleanup', async () => {
  const waits = [];
  const registrations = [];
  const deletes = [];
  let debugReads = 0;
  const fixtures = createInjectedFirebaseFixtures({
    waitImpl: async (milliseconds) => waits.push(milliseconds),
    readSdkManagedDebugSecret: () => {
      debugReads += 1;
      if (debugReads === 1) throw new Error('not ready');
      return 'DEBUG_SECRET_SENTINEL';
    },
    registerDebugSecret: async (request) => {
      registrations.push(request);
      return {
        resourceCreated: true,
        resourceName:
          'projects/102802326815/apps/android:app/debugTokens/token_1',
      };
    },
    fetchImplementation: async (url, options) => {
      deletes.push({ url, options });
      return { ok: true, status: 200, json: async () => ({}) };
    },
  });

  const registration = await fixtures.registerAcceptanceAppCheck(
    'emulator-5554',
    { accessToken: 'ACCESS_TOKEN_SENTINEL' },
  );
  assert.deepEqual(waits, [300]);
  assert.deepEqual(registrations, [
    {
      accessToken: 'ACCESS_TOKEN_SENTINEL',
      debugSecret: 'DEBUG_SECRET_SENTINEL',
      suite: 'force-stop-reopen',
    },
  ]);
  assert.equal(
    await fixtures.deleteAppCheckRegistration(
      { accessToken: 'ACCESS_TOKEN_SENTINEL' },
      registration,
    ),
    true,
  );
  assert.equal(deletes.length, 1);
  assert.match(deletes[0].url, /firebaseappcheck\.googleapis\.com/);
  assert.equal(deletes[0].options.method, 'DELETE');
  assert.equal(
    await fixtures.deleteAppCheckRegistration(
      { accessToken: 'ACCESS_TOKEN_SENTINEL' },
      { resourceCreated: true, resourceName: '../unsafe' },
    ),
    false,
  );
  assert.equal(deletes.length, 1);
});

test('injected Settings owner composes exact navigation, reset, and row scan', async () => {
  const events = [];
  const waits = [];
  const shellXml = '<hierarchy><!-- shell --></hierarchy>';
  const settingsXml = `<hierarchy>${settingsRequiredResourceIds
    .map(
      (identifier) =>
        `<node resource-id="com.example.cashpilot_ai:id/${identifier}" />`,
    )
    .join('')}<node resource-id="com.example.cashpilot_ai:id/ai_settings_test_idle" /></hierarchy>`;
  const snapshots = [shellXml, settingsXml];
  const settings = createInjectedSettingsSupport({
    adbExec(deviceId, args, options) {
      events.push({ type: 'adb', deviceId, args, options });
    },
    findUiTarget(xml, target, viewport = null) {
      events.push({ type: 'target', target, viewport });
      if (target === 'settings' && xml === shellXml) {
        return Object.freeze({ x: 50, y: 60 });
      }
      if (target === 'settingsLiveTest' && xml === settingsXml) {
        return Object.freeze({ x: 500, y: 1_500 });
      }
      return null;
    },
    snapshotUi(deviceId) {
      events.push({ type: 'snapshot', deviceId });
      return snapshots.shift() || settingsXml;
    },
    tapPoint(deviceId, point) {
      events.push({ type: 'tap', deviceId, point });
    },
    async waitForTarget(deviceId, target, timeoutMs) {
      events.push({ type: 'waitTarget', deviceId, target, timeoutMs });
      return Object.freeze({ x: 1, y: 1 });
    },
    async waitImpl(milliseconds) {
      waits.push(milliseconds);
    },
  });

  const result = await settings.verifySettingsPage('emulator-5554');

  assert.equal(result.rowsVerified, true);
  assert.equal(result.rowCount, settingsRequiredResourceIds.length);
  assert.deepEqual(result.rowIds, settingsRequiredResourceIds);
  assert.equal(result.testStatus, 'idle');
  assert.deepEqual(result.liveTestPoint, { x: 500, y: 1_500 });
  assert.deepEqual(
    events.find((event) => event.type === 'tap'),
    {
      type: 'tap',
      deviceId: 'emulator-5554',
      point: { x: 50, y: 60 },
    },
  );
  assert.deepEqual(
    events.find((event) => event.type === 'waitTarget'),
    {
      type: 'waitTarget',
      deviceId: 'emulator-5554',
      target: 'settingsCard',
      timeoutMs: 30_000,
    },
  );
  const adbEvents = events.filter((event) => event.type === 'adb');
  assert.equal(adbEvents.length, 14);
  for (const event of adbEvents) {
    assert.deepEqual(event, {
      type: 'adb',
      deviceId: 'emulator-5554',
      args: [
        'shell',
        'input',
        'swipe',
        '500',
        '560',
        '500',
        '1560',
        '250',
      ],
      options: { safeCode: 'settings_scroll_failed' },
    });
  }
  assert.deepEqual(waits, Array.from({ length: 14 }, () => 120));
});

test('injected Settings owner keeps restored-route and state parsing fail-closed', async () => {
  let taps = 0;
  const shellXml = '<hierarchy><!-- shell --></hierarchy>';
  const settings = createInjectedSettingsSupport({
    findUiTarget(xml, target) {
      return target === 'settings' && xml === shellXml
        ? Object.freeze({ x: 50, y: 60 })
        : null;
    },
    snapshotUi: () => shellXml,
    tapPoint: () => {
      taps += 1;
    },
  });

  await assert.rejects(
    () =>
      settings.openSettingsPage('emulator-5554', {
        requireRestoredRoute: true,
      }),
    (error) => error.safeCode === 'settings_route_not_restored',
  );
  assert.equal(taps, 0);
  assert.throws(
    () =>
      settings.settingsStateFromUiXml(
        '<hierarchy>' +
          '<node resource-id="com.example.cashpilot_ai:id/ai_settings_test_idle" />' +
          '<node resource-id="com.example.cashpilot_ai:id/ai_settings_test_testing" />' +
          '</hierarchy>',
      ),
    (error) => error.safeCode === 'settings_test_state_ambiguous',
  );
});

test('injected Auth owner preserves exact credential and login proof order', async () => {
  const events = [];
  const readyXml =
    '<hierarchy><node resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_state_ready" /></hierarchy>';
  const submitXml = '<hierarchy><!-- submit --></hierarchy>';
  const authenticatedXml = '<hierarchy><!-- authenticated --></hierarchy>';
  const snapshots = [
    ['ready', readyXml],
    ['submit', submitXml],
    ['authenticated', authenticatedXml],
  ];
  const auth = createInjectedAuthSupport({
    findUiTarget(xml, target) {
      events.push(['target', target]);
      if (xml === submitXml && target === 'loginSubmit') {
        return Object.freeze({ x: 50, y: 60 });
      }
      if (xml === authenticatedXml && target === 'authenticatedShell') {
        return Object.freeze({ x: 70, y: 80 });
      }
      return null;
    },
    inputText(deviceId, value, kind) {
      events.push(['input', deviceId, kind, value]);
    },
    snapshotUi(deviceId) {
      const [name, xml] = snapshots.shift();
      events.push(['snapshot', deviceId, name]);
      return xml;
    },
    tapPoint(deviceId, point) {
      events.push(['tap', deviceId, point]);
    },
    async waitForTarget(deviceId, target) {
      events.push(['waitTarget', deviceId, target]);
      return target === 'email'
        ? Object.freeze({ x: 10, y: 20 })
        : Object.freeze({ x: 30, y: 40 });
    },
  });

  assert.equal(
    await auth.loginSyntheticUser('emulator-5554', {
      email: 'synthetic@example.com',
      password: 'Password123',
    }),
    true,
  );
  assert.deepEqual(events, [
    ['waitTarget', 'emulator-5554', 'email'],
    ['tap', 'emulator-5554', { x: 10, y: 20 }],
    ['input', 'emulator-5554', 'email', 'synthetic@example.com'],
    ['waitTarget', 'emulator-5554', 'password'],
    ['tap', 'emulator-5554', { x: 30, y: 40 }],
    ['input', 'emulator-5554', 'password', 'Password123'],
    ['snapshot', 'emulator-5554', 'ready'],
    ['snapshot', 'emulator-5554', 'submit'],
    ['target', 'loginSubmit'],
    ['tap', 'emulator-5554', { x: 50, y: 60 }],
    ['snapshot', 'emulator-5554', 'authenticated'],
    ['target', 'authenticatedShell'],
  ]);
});

test('injected Auth owner keeps session normalization and logout fail-closed', async () => {
  let settingsAttempts = 0;
  let taps = 0;
  const signedInXml = '<hierarchy><!-- signed-in --></hierarchy>';
  const auth = createInjectedAuthSupport({
    findUiTarget(xml, target) {
      return xml === signedInXml && target === 'authenticatedShell'
        ? Object.freeze({ x: 10, y: 20 })
        : null;
    },
    async openSettingsPage() {
      settingsAttempts += 1;
      throw new Error('SENSITIVE');
    },
    snapshotUi: () => signedInXml,
    tapPoint: () => {
      taps += 1;
    },
  });

  await assert.rejects(
    () => auth.normalizeSignedOutSession('emulator-5554'),
    (error) =>
      error.safeCode === 'prior_auth_logout_failed' &&
      !error.message.includes('SENSITIVE'),
  );
  assert.equal(settingsAttempts, 1);
  assert.equal(taps, 0);
  assert.throws(
    () =>
      auth.loginStateFromUiXml(
        '<hierarchy><node resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_state_not_allowed" /></hierarchy>',
      ),
    (error) => error.safeCode === 'login_state_invalid',
  );
});

test('injected AI-question owner preserves fixed hook and bounded answer proof', async () => {
  const events = [];
  const stateXml = (phase, count) =>
    `<hierarchy><node resource-id="com.example.cashpilot_ai:id/cashpilot_ai_acceptance_${phase}_${count}" /></hierarchy>`;
  const composerXml = (text) =>
    `<hierarchy><node text="${text}" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_ai_composer" /></hierarchy>`;
  const snapshots = [
    ['baseline', stateXml('idle', 0)],
    ['empty', composerXml('')],
    ['fixed', composerXml(fixedArabicPrompt)],
    ['sending', stateXml('sending', 1)],
    ...Array.from({ length: 5 }, (_, index) => [
      `complete-${index + 1}`,
      stateXml('answer_complete', 2),
    ]),
  ];
  const question = createInjectedAiQuestionSupport({
    executeLongPress(_adbExec, deviceId, point, durationMs) {
      events.push(['longPress', deviceId, point, durationMs]);
    },
    snapshotUi(deviceId) {
      const [name, xml] = snapshots.shift();
      events.push(['snapshot', deviceId, name]);
      return xml;
    },
    tapPoint(deviceId, point) {
      events.push(['tap', deviceId, point]);
    },
    async waitForTarget(deviceId, target) {
      events.push(['waitTarget', deviceId, target]);
      return target === 'composer'
        ? Object.freeze({ x: 10, y: 20 })
        : Object.freeze({ x: 30, y: 40 });
    },
    waitImpl: async (milliseconds) => {
      events.push(['wait', milliseconds]);
    },
  });

  assert.deepEqual(await question.askGroqQuestion('emulator-5554', 0), {
    sendingObserved: true,
    answerCompleted: true,
    messageDelta: 2,
    duplicateResponse: false,
  });
  assert.equal(snapshots.length, 0);
  assert.deepEqual(events.slice(0, 8), [
    ['snapshot', 'emulator-5554', 'baseline'],
    ['waitTarget', 'emulator-5554', 'composer'],
    ['tap', 'emulator-5554', { x: 10, y: 20 }],
    ['snapshot', 'emulator-5554', 'empty'],
    ['waitTarget', 'emulator-5554', 'send'],
    ['longPress', 'emulator-5554', { x: 30, y: 40 }, 800],
    ['snapshot', 'emulator-5554', 'fixed'],
    ['waitTarget', 'emulator-5554', 'send'],
  ]);
  assert.deepEqual(
    events.filter(([name]) => name === 'wait'),
    Array.from({ length: 5 }, () => ['wait', 200]),
  );
});

test('injected AI-question owner preserves replacement ADB and input order', async () => {
  const adbCalls = [];
  const events = [];
  const stateXml = (phase, count) =>
    `<hierarchy><node resource-id="com.example.cashpilot_ai:id/cashpilot_ai_acceptance_${phase}_${count}" /></hierarchy>`;
  const snapshots = [
    stateXml('idle', 0),
    ...Array.from({ length: 5 }, () => stateXml('answer_complete', 2)),
  ];
  const question = createInjectedAiQuestionSupport({
    adbExec(deviceId, args, options) {
      adbCalls.push({ deviceId, args, options });
    },
    inputText(deviceId, value, kind) {
      events.push(['input', deviceId, value, kind]);
    },
    snapshotUi: () => snapshots.shift(),
    tapPoint(deviceId, point) {
      events.push(['tap', deviceId, point]);
    },
    async waitForTarget(deviceId, target) {
      events.push(['waitTarget', deviceId, target]);
      return target === 'composer'
        ? Object.freeze({ x: 10, y: 20 })
        : Object.freeze({ x: 30, y: 40 });
    },
    waitImpl: async (milliseconds) => {
      events.push(['wait', milliseconds]);
    },
  });

  assert.deepEqual(await question.askGroqQuestion('emulator-5554', 1), {
    sendingObserved: false,
    answerCompleted: true,
    messageDelta: 2,
    duplicateResponse: false,
  });
  assert.deepEqual(adbCalls, [
    {
      deviceId: 'emulator-5554',
      args: [
        'shell',
        'input',
        'keycombination',
        'KEYCODE_CTRL_LEFT',
        'KEYCODE_A',
      ],
      options: { safeCode: 'composer_select_all_failed' },
    },
    {
      deviceId: 'emulator-5554',
      args: ['shell', 'input', 'keyevent', 'KEYCODE_DEL'],
      options: { safeCode: 'composer_clear_failed' },
    },
  ]);
  assert.deepEqual(events.slice(0, 7), [
    ['waitTarget', 'emulator-5554', 'composer'],
    ['tap', 'emulator-5554', { x: 10, y: 20 }],
    ['wait', 120],
    [
      'input',
      'emulator-5554',
      'Explain compound interest simply.',
      'question',
    ],
    ['waitTarget', 'emulator-5554', 'send'],
    ['tap', 'emulator-5554', { x: 30, y: 40 }],
    ['wait', 200],
  ]);
  assert.equal(snapshots.length, 0);
});

test('injected device lifecycle preserves PID and launcher commands exactly', () => {
  const adbCalls = [];
  const spawnCalls = [];
  const lifecycle = createInjectedDeviceLifecycleSupport({
    adbExec(deviceId, args, options) {
      adbCalls.push({ deviceId, args, options });
      if (args[1] === 'wm') {
        throw new Error('dismiss-keyguard unsupported');
      }
      if (args[1] === 'cmd') {
        return 'com.example.cashpilot_ai/.MainActivity\n';
      }
      return '';
    },
    spawnSyncImplementation(...args) {
      spawnCalls.push(args);
      return { status: 0, stdout: '4321\n', stderr: '' };
    },
  });

  assert.equal(lifecycle.currentPid('emulator-5554'), '4321');
  lifecycle.launchFromLauncher('emulator-5554');

  assert.deepEqual(spawnCalls, [
    [
      'C:\\sdk\\adb.exe',
      [
        '-s',
        'emulator-5554',
        'shell',
        'pidof',
        'com.example.cashpilot_ai',
      ],
      {
        cwd: 'C:\\repo',
        encoding: 'utf8',
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'pipe'],
        timeout: 5_000,
      },
    ],
  ]);
  assert.deepEqual(adbCalls, [
    {
      deviceId: 'emulator-5554',
      args: ['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'],
      options: undefined,
    },
    {
      deviceId: 'emulator-5554',
      args: ['shell', 'wm', 'dismiss-keyguard'],
      options: undefined,
    },
    {
      deviceId: 'emulator-5554',
      args: [
        'shell',
        'cmd',
        'package',
        'resolve-activity',
        '--brief',
        '-a',
        'android.intent.action.MAIN',
        '-c',
        'android.intent.category.LAUNCHER',
        'com.example.cashpilot_ai',
      ],
      options: {
        capture: true,
        encoding: 'utf8',
        safeCode: 'launcher_resolution_failed',
      },
    },
    {
      deviceId: 'emulator-5554',
      args: [
        'shell',
        'am',
        'start',
        '-W',
        '-a',
        'android.intent.action.MAIN',
        '-c',
        'android.intent.category.LAUNCHER',
        '-n',
        'com.example.cashpilot_ai/.MainActivity',
      ],
      options: {
        safeCode: 'launcher_reopen_failed',
        timeoutMs: 45_000,
      },
    },
  ]);

  const mismatchedLauncher = createInjectedDeviceLifecycleSupport({
    adbExec(_deviceId, args) {
      return args[1] === 'cmd' ? 'com.example.other/.MainActivity\n' : '';
    },
  });
  assert.throws(
    () => mismatchedLauncher.launchFromLauncher('emulator-5554'),
    (error) => error.safeCode === 'launcher_component_mismatch',
  );
});

test('injected device lifecycle keeps process waits bounded at exact limits', async () => {
  let clock = 0;
  let reads = 0;
  let waits = 0;
  const lifecycle = createInjectedDeviceLifecycleSupport({
    nowImpl: () => clock,
    spawnSyncImplementation: () => {
      reads += 1;
      return { status: 0, stdout: '111\n', stderr: '' };
    },
    waitImpl: async (milliseconds) => {
      assert.equal(milliseconds, 200);
      waits += 1;
      clock += milliseconds;
    },
  });

  await assert.rejects(
    lifecycle.waitForNewPid('emulator-5554', '111'),
    (error) => error.safeCode === 'new_process_not_observed',
  );
  assert.equal(reads, 101);
  assert.equal(waits, 101);

  clock = 0;
  reads = 0;
  waits = 0;
  await assert.rejects(
    lifecycle.waitForStopped('emulator-5554'),
    (error) => error.safeCode === 'old_process_still_running',
  );
  assert.equal(reads, 51);
  assert.equal(waits, 51);
});

test('injected device lifecycle preserves feasibility and build-install options', () => {
  const adbCalls = [];
  const spawnCalls = [];
  const defineCalls = [];
  const lifecycle = createInjectedDeviceLifecycleSupport({
    adbExec(deviceId, args, options) {
      adbCalls.push({ deviceId, args, options });
      if (args[0] === 'get-state') return 'device\n';
      if (args[1] === 'pm') return 'package:com.example.cashpilot_ai\n';
      return '';
    },
    existsSync: () => true,
    groqDartDefines(gatewayUrl, extraDefines) {
      defineCalls.push({ gatewayUrl, extraDefines });
      return [
        '--dart-define=CASH_PILOT_AI_GATEWAY_BASE_URL=https://gateway.test',
      ];
    },
    spawnSyncImplementation(...args) {
      spawnCalls.push(args);
      return { status: 0, stdout: '', stderr: '' };
    },
  });

  assert.deepEqual(lifecycle.inspectFeasibility('emulator-5554'), {
    adbAvailable: true,
    flutterAvailable: true,
    deviceAvailable: true,
    packageInstalled: true,
    uiDriverAvailable: true,
  });
  lifecycle.buildAndInstall('emulator-5554', 'https://gateway.test');

  assert.deepEqual(spawnCalls, [
    [
      'where.exe',
      ['flutter.bat'],
      {
        cwd: 'C:\\repo',
        encoding: 'utf8',
        windowsHide: true,
        stdio: ['ignore', 'pipe', 'ignore'],
        timeout: 5_000,
      },
    ],
    [
      'flutter.bat build apk --debug --no-pub --dart-define=CASH_PILOT_AI_GATEWAY_BASE_URL=https://gateway.test',
      {
        cwd: 'C:\\repo',
        shell: true,
        windowsHide: true,
        stdio: 'ignore',
        timeout: 10 * 60_000,
      },
    ],
  ]);
  assert.equal(defineCalls[0].gatewayUrl, 'https://gateway.test');
  assert.strictEqual(
    defineCalls[0].extraDefines,
    lifecycle.acceptanceBuildExtraDefines,
  );
  assert.equal(Object.isFrozen(lifecycle.acceptanceBuildExtraDefines), true);
  assert.deepEqual(adbCalls.at(-1), {
    deviceId: 'emulator-5554',
    args: [
      'install',
      'C:\\repo\\build\\app\\outputs\\flutter-apk\\app-debug.apk',
    ],
    options: {
      safeCode: 'acceptance_apk_install_failed',
      timeoutMs: 2 * 60_000,
    },
  });

  let unsafeSpawned = false;
  const unsafeLifecycle = createInjectedDeviceLifecycleSupport({
    groqDartDefines: () => ['unsafe argument'],
    spawnSyncImplementation: () => {
      unsafeSpawned = true;
      return { status: 0 };
    },
  });
  assert.throws(
    () => unsafeLifecycle.buildAndInstall('emulator-5554', 'https://gateway.test'),
    (error) => error.safeCode === 'flutter_build_argument_invalid',
  );
  assert.equal(unsafeSpawned, false);

  const failedBuild = createInjectedDeviceLifecycleSupport({
    spawnSyncImplementation: () => ({ status: 7 }),
  });
  assert.throws(
    () => failedBuild.buildAndInstall('emulator-5554', 'https://gateway.test'),
    (error) => error.safeCode === 'flutter_build_failed',
  );

  const missingApk = createInjectedDeviceLifecycleSupport({
    existsSync: () => false,
    spawnSyncImplementation: () => ({ status: 0 }),
  });
  assert.throws(
    () => missingApk.buildAndInstall('emulator-5554', 'https://gateway.test'),
    (error) => error.safeCode === 'acceptance_apk_missing',
  );
});

test('injected device lifecycle preserves Gateway and uninstall cleanup contracts', async () => {
  const adbCalls = [];
  const packageStates = [
    'package:com.example.cashpilot_ai\n',
    'package:com.example.other\n',
  ];
  const fetchCalls = [];
  const lifecycle = createInjectedDeviceLifecycleSupport({
    adbExec(deviceId, args, options) {
      adbCalls.push({ deviceId, args, options });
      if (args[1] === 'pm') return packageStates.shift();
      return '';
    },
    fetchImplementation: async (url, options) => {
      fetchCalls.push({ url, options });
      return {
        ok: true,
        status: 200,
        json: async () => ({
          status: 'success',
          environment: 'staging',
          supportedClientVersion: '1.0.0',
          readiness: { ready: true },
        }),
      };
    },
  });

  await lifecycle.verifyGatewayHealth('https://gateway.test');
  assert.deepEqual(fetchCalls, [
    {
      url: 'https://gateway.test/health',
      options: {
        headers: { Accept: 'application/json' },
        signal: { milliseconds: 10_000 },
      },
    },
  ]);
  assert.equal(lifecycle.bestEffortUninstall('emulator-5554'), true);
  assert.deepEqual(
    adbCalls.map(({ args }) => args),
    [
      [
        'shell',
        'pm',
        'list',
        'packages',
        '-u',
        '--user',
        '0',
        'com.example.cashpilot_ai',
      ],
      ['uninstall', 'com.example.cashpilot_ai'],
      [
        'shell',
        'pm',
        'list',
        'packages',
        '-u',
        '--user',
        '0',
        'com.example.cashpilot_ai',
      ],
    ],
  );

  const unreachable = createInjectedDeviceLifecycleSupport({
    fetchImplementation: async () => {
      throw new Error('SENSITIVE');
    },
  });
  await assert.rejects(
    unreachable.verifyGatewayHealth('https://gateway.test'),
    (error) =>
      error.safeCode === 'gateway_health_unreachable' &&
      !error.message.includes('SENSITIVE'),
  );

  const httpFailure = createInjectedDeviceLifecycleSupport({
    fetchImplementation: async () => ({
      ok: false,
      status: 503,
      json: async () => ({}),
    }),
  });
  await assert.rejects(
    httpFailure.verifyGatewayHealth('https://gateway.test'),
    (error) => error.safeCode === 'gateway_health_http_503',
  );

  const contractFailure = createInjectedDeviceLifecycleSupport({
    fetchImplementation: async () => ({
      ok: true,
      status: 200,
      json: async () => ({ status: 'success', environment: 'production' }),
    }),
  });
  await assert.rejects(
    contractFailure.verifyGatewayHealth('https://gateway.test'),
    (error) => error.safeCode === 'gateway_health_contract_mismatch',
  );

  const uninstallFailure = createInjectedDeviceLifecycleSupport({
    adbExec() {
      throw new Error('SENSITIVE');
    },
  });
  assert.equal(uninstallFailure.bestEffortUninstall('emulator-5554'), false);
});

test('email input isolates special characters as Android key events', () => {
  assert.deepEqual(emailInputCommands('cashpilot-test@example.com'), [
    ['shell', 'input', 'text', 'cashpilot-test'],
    ['shell', 'input', 'keyevent', 'KEYCODE_AT'],
    ['shell', 'input', 'text', 'example'],
    ['shell', 'input', 'keyevent', 'KEYCODE_PERIOD'],
    ['shell', 'input', 'text', 'com'],
  ]);
  assert.throws(
    () => emailInputCommands('unsafe+alias@example.com'),
    (error) => error.safeCode === 'ui_input_shape_invalid',
  );
});

test('credential input clears the active field before writing', () => {
  assert.deepEqual(credentialClearCommands(), [
    [
      'shell',
      'input',
      'keycombination',
      'KEYCODE_CTRL_LEFT',
      'KEYCODE_A',
    ],
    ['shell', 'input', 'keyevent', 'KEYCODE_DEL'],
  ]);
});

test('synthetic password is randomized but shell-input stable', () => {
  const password = syntheticPassword('0123456789abcdef0123456789abcdef');
  assert.equal(password, 'cp90123456789abcdef');
  assert.match(password, /^[a-z0-9]+$/);
  assert.throws(
    () => syntheticPassword('not-hex'),
    (error) => error.safeCode === 'synthetic_password_source_invalid',
  );
});

test('synthetic credentials are client-valid without exposing returned tokens', async () => {
  const synthetic = Object.freeze({
    email: 'cp-0123456789abcdef@example.com',
    password: 'cp90123456789abcdef',
    localId: 'cp-restart-0123456789abcdef',
  });
  let requestBody;
  const result = await verifySyntheticCredentials(
    { apiKey: 'API_KEY_SENTINEL_123456789' },
    synthetic,
    async (url, init) => {
      assert.match(url, /accounts:signInWithPassword\?key=/);
      requestBody = JSON.parse(init.body);
      return {
        ok: true,
        status: 200,
        async json() {
          return {
            localId: synthetic.localId,
            idToken: 'ID_TOKEN_SENTINEL_123456789',
          };
        },
      };
    },
  );

  assert.equal(result, true);
  assert.deepEqual(requestBody, {
    email: synthetic.email,
    password: synthetic.password,
    returnSecureToken: true,
  });
});

const primaryGatewayUrl = `https://${approvedGatewayHost}`;
const syntheticProfile = Object.freeze({
  localId: 'cp-restart-synthetic',
  email: 'synthetic-profile@example.com',
});
const fixedArabicPrompt = 'اشرح لي مفهوم التضخم بطريقة بسيطة';

function settingsXml(resourceIds, { packagePrefix = true } = {}) {
  const nodes = resourceIds.map((identifier, index) => {
    const resourceId = packagePrefix
      ? `com.example.cashpilot_ai:id/${identifier}`
      : identifier;
    const top = index * 20;
    const clickable = identifier === 'ai_settings_live_test';
    return `<node text="TEXT_SENTINEL_DO_NOT_READ" content-desc="CONTENT_SENTINEL_DO_NOT_READ" enabled="true" visible-to-user="true" clickable="${clickable}" resource-id="${resourceId}" bounds="[0,${top}][100,${top + 15}]" />`;
  });
  return `<hierarchy>${nodes.join('')}</hierarchy>`;
}

function matchingProfileDocument() {
  return {
    name:
      'projects/cashpilot-ai-a6b49/databases/(default)/documents/users/' +
      syntheticProfile.localId,
    fields: {
      uid: { stringValue: syntheticProfile.localId },
      name: { stringValue: 'CashPilot Restart Acceptance' },
      email: { stringValue: syntheticProfile.email },
      currency: { stringValue: 'LYD' },
      language: { stringValue: 'en' },
      country: { stringValue: 'LY' },
      timezone: { stringValue: 'UTC' },
    },
  };
}

function liveOptions() {
  return parseForceStopArguments([
    '--execute-live',
    '--promotion-confirmed',
    '--dedicated-device',
    '--gateway-url',
    primaryGatewayUrl,
  ]);
}

test('runner defaults to a non-mutating dry run', () => {
  const options = parseForceStopArguments([]);

  assert.equal(options.executeLive, false);
  assert.equal(options.gatewayUrl, null);
  assert.equal(options.deviceId, 'emulator-5554');
});

test('live mode requires promotion, dedicated-device, and primary URL gates', () => {
  assert.throws(
    () => parseForceStopArguments(['--execute-live']),
    (error) => error.safeCode === 'live_confirmation_incomplete',
  );
  assert.throws(
    () =>
      parseForceStopArguments([
        '--execute-live',
        '--promotion-confirmed',
        '--dedicated-device',
        '--gateway-url',
        'https://groq-candidate---cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app',
      ]),
    (error) => error.safeCode === 'candidate_tag_forbidden',
  );
  assert.throws(
    () =>
      parseForceStopArguments([
        '--execute-live',
        '--promotion-confirmed',
        '--dedicated-device',
        '--gateway-url',
        'https://example.test',
      ]),
    (error) => error.safeCode === 'primary_gateway_host_required',
  );

  const options = liveOptions();
  assert.equal(options.executeLive, true);
  assert.equal(options.promotionConfirmed, true);
  assert.equal(options.dedicatedDevice, true);
  assert.equal(options.gatewayUrl, primaryGatewayUrl);
});

test('only emulator device IDs and HTTPS origins are accepted', () => {
  assert.throws(
    () => parseForceStopArguments(['--device', 'physical-device']),
    (error) => error.safeCode === 'dedicated_emulator_required',
  );
  assert.throws(
    () =>
      parseForceStopArguments([
        '--gateway-url',
        `https://${approvedGatewayHost}/unexpected`,
      ]),
    (error) => error.safeCode === 'gateway_origin_invalid',
  );
});

test('UI parsing returns only safe coordinates and acceptance state', () => {
  const sensitiveUiText = 'SENSITIVE_RESPONSE_MUST_NOT_ESCAPE';
  const xml = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<hierarchy>',
    '<node text="Email" content-desc="" class="android.widget.EditText" enabled="true" resource-id="cashpilot_acceptance_login_email" bounds="[10,20][110,80]" />',
    `<node text="${sensitiveUiText}" content-desc="" class="android.view.View" enabled="true" resource-id="cashpilot_ai_acceptance_answer_complete_2" bounds="[0,0][100,100]" />`,
    '</hierarchy>',
  ].join('');

  const target = findUiTarget(xml, 'email');
  const state = acceptanceStateFromUiXml(xml);

  assert.deepEqual(target, { x: 60, y: 50 });
  assert.deepEqual(state, { phase: 'answer_complete', messageCount: 2 });
  assert.ok(!JSON.stringify({ target, state }).includes(sensitiveUiText));
});

test('auth preflight classifies only trusted resource IDs', () => {
  const node = (resourceId) =>
    `<node text="SENSITIVE_AUTH_TEXT" content-desc="SENSITIVE_AUTH_DESC" enabled="true" resource-id="com.example.cashpilot_ai:id/${resourceId}" bounds="[0,0][100,100]" />`;

  assert.equal(
    authSurfaceFromUiXml(
      `<hierarchy>${node('cashpilot_acceptance_login_email')}${node(
        'cashpilot_acceptance_login_password',
      )}</hierarchy>`,
    ),
    'signedOut',
  );
  assert.equal(
    authSurfaceFromUiXml(
      `<hierarchy>${node(
        'cashpilot_acceptance_authenticated_shell',
      )}</hierarchy>`,
    ),
    'signedIn',
  );
  assert.equal(
    authSurfaceFromUiXml(
      `<hierarchy>${node('cashpilot_acceptance_welcome_login')}</hierarchy>`,
    ),
    'entry',
  );
  assert.equal(
    authSurfaceFromUiXml(
      `<hierarchy>${node('cashpilot_acceptance_onboarding_skip')}</hierarchy>`,
    ),
    'entry',
  );
  assert.equal(
    authSurfaceFromUiXml(
      '<hierarchy><node text="cashpilot_acceptance_authenticated_shell" content-desc="" enabled="true" resource-id="" bounds="[0,0][100,100]" /></hierarchy>',
    ),
    'unknown',
  );
});

test('auth normalization never taps an unrelated system dialog', async () => {
  const foreignDialog = [
    '<hierarchy>',
    '<node text="Unrelated app is not responding" package="android" enabled="true" resource-id="android:id/alertTitle" bounds="[0,0][100,100]" />',
    '<node text="Close app" package="android" clickable="true" enabled="true" resource-id="android:id/aerr_close" bounds="[0,100][100,200]" />',
    '</hierarchy>',
  ].join('');
  const login = [
    '<hierarchy>',
    '<node text="" package="com.example.cashpilot_ai" enabled="true" resource-id="cashpilot_acceptance_login_email" bounds="[0,0][100,100]" />',
    '<node text="" package="com.example.cashpilot_ai" enabled="true" resource-id="cashpilot_acceptance_login_password" bounds="[0,100][100,200]" />',
    '</hierarchy>',
  ].join('');
  const snapshots = [foreignDialog, login];
  const operations = [];

  const result = await normalizeSignedOutSession('emulator-5554', {
    snapshotImpl: () => snapshots.shift(),
    tapPointImpl: async () => operations.push('tap'),
    logoutImpl: async () => {
      operations.push('logout');
      return true;
    },
    waitImpl: async (milliseconds) =>
      operations.push(`wait-${milliseconds}`),
    now: () => 0,
    timeoutMs: 1_000,
  });

  assert.deepEqual(result, { signedOut: true, priorSession: false });
  assert.deepEqual(operations, ['wait-300']);
  assert.equal(snapshots.length, 0);
});

test('auth normalization reclassifies entry hydration before logging out', async () => {
  const node = (resourceId) =>
    `<node text="SENSITIVE_AUTH_TEXT" content-desc="SENSITIVE_AUTH_DESC" enabled="true" resource-id="com.example.cashpilot_ai:id/${resourceId}" bounds="[0,0][100,100]" />`;
  const snapshots = [
    `<hierarchy>${node('cashpilot_acceptance_welcome_login')}</hierarchy>`,
    `<hierarchy>${node(
      'cashpilot_acceptance_authenticated_shell',
    )}</hierarchy>`,
    `<hierarchy>${node('cashpilot_acceptance_login_email')}${node(
      'cashpilot_acceptance_login_password',
    )}</hierarchy>`,
  ];
  const operations = [];

  const result = await normalizeSignedOutSession('emulator-5554', {
    snapshotImpl: () => snapshots.shift(),
    tapPointImpl: async (_deviceId, point) =>
      operations.push(`tap-${point.x}-${point.y}`),
    logoutImpl: async () => {
      operations.push('logout');
      return true;
    },
    waitImpl: async (milliseconds) =>
      operations.push(`wait-${milliseconds}`),
    now: () => 0,
    timeoutMs: 1_000,
  });

  assert.deepEqual(result, { signedOut: true, priorSession: true });
  assert.deepEqual(operations, [
    'tap-50-50',
    'wait-400',
    'logout',
    'wait-300',
  ]);
  assert.equal(snapshots.length, 0);
});

test('resource-ID logout resets Settings scroll before tapping logout', async () => {
  const operations = [];

  const result = await performResourceIdLogout({
    openSettings: async () => operations.push('open-settings'),
    waitForSettingsCard: async () => operations.push('wait-settings-card'),
    resetScroll: async () => operations.push('reset-settings-scroll'),
    tapLogout: async () => operations.push('tap-logout-id'),
    waitForEmail: async () => operations.push('wait-email-id'),
    waitForPassword: async () => operations.push('wait-password-id'),
  });

  assert.equal(result, true);
  assert.deepEqual(operations, [
    'open-settings',
    'wait-settings-card',
    'reset-settings-scroll',
    'tap-logout-id',
    'wait-email-id',
    'wait-password-id',
  ]);
});

test('welcome login and form submit use distinct exact resource IDs', () => {
  const xml = [
    '<hierarchy>',
    '<node text="SENSITIVE_WELCOME" content-desc="" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_welcome_login" bounds="[0,0][100,100]" />',
    '<node text="SENSITIVE_SUBMIT" content-desc="" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_submit" bounds="[0,200][100,300]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(findUiTarget(xml, 'login'), { x: 50, y: 50 });
  assert.deepEqual(findUiTarget(xml, 'loginSubmit'), { x: 50, y: 250 });
});

test('login submit rejects hidden and offscreen XML nodes before tapping', async () => {
  const viewport = { width: 1080, height: 1920 };
  const snapshots = [
    '<hierarchy><node enabled="true" visible-to-user="false" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_submit" bounds="[100,800][900,920]" /></hierarchy>',
    '<hierarchy><node enabled="true" visible-to-user="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_submit" bounds="[100,2000][900,2120]" /></hierarchy>',
    '<hierarchy><node enabled="true" visible-to-user="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_submit" bounds="[100,800][900,920]" /></hierarchy>',
  ];
  const operations = [];

  const result = await findAndTapLoginSubmit({
    readTarget: async () => {
      operations.push('read-id');
      return findUiTarget(snapshots.shift(), 'loginSubmit', viewport);
    },
    scrollForward: async () => operations.push('scroll-forward'),
    tap: async () => operations.push('tap-submit-id'),
    waitImpl: async () => operations.push('wait'),
    maxScrollSteps: 3,
  });

  assert.deepEqual(result, { scrollSteps: 2 });
  assert.deepEqual(operations, [
    'read-id',
    'scroll-forward',
    'wait',
    'read-id',
    'scroll-forward',
    'wait',
    'read-id',
    'tap-submit-id',
  ]);
});

test('login submit search fails closed at the forward-scroll bound', async () => {
  const operations = [];

  await assert.rejects(
    findAndTapLoginSubmit({
      readTarget: async () => {
        operations.push('read-id');
        return null;
      },
      scrollForward: async () => operations.push('scroll-forward'),
      tap: async () => operations.push('tap-submit-id'),
      waitImpl: async () => operations.push('wait'),
      maxScrollSteps: 2,
    }),
    (error) => error.safeCode === 'ui_login_submit_timed_out',
  );

  assert.deepEqual(operations, [
    'read-id',
    'scroll-forward',
    'wait',
    'read-id',
    'scroll-forward',
    'wait',
    'read-id',
  ]);
});

test('login proves locally ready before submit without keyboard dismissal', async () => {
  const operations = [];

  const result = await fillAndSubmitLogin({
    waitForEmail: async () => {
      operations.push('wait-email-id');
      return { x: 10, y: 20 };
    },
    tapEmail: async () => operations.push('tap-email-id'),
    inputEmail: async () => operations.push('input-email'),
    waitForPassword: async () => {
      operations.push('wait-password-id');
      return { x: 30, y: 40 };
    },
    tapPassword: async () => operations.push('tap-password-id'),
    inputPassword: async () => operations.push('input-password'),
    waitForReady: async () => operations.push('wait-ready-id'),
    tapSubmit: async () => operations.push('tap-submit-id'),
    waitForAuthenticated: async () =>
      operations.push('wait-authenticated-id'),
  });

  assert.equal(result, true);
  assert.deepEqual(operations, [
    'wait-email-id',
    'tap-email-id',
    'input-email',
    'wait-password-id',
    'tap-password-id',
    'input-password',
    'wait-ready-id',
    'tap-submit-id',
    'wait-authenticated-id',
  ]);
  assert.ok(!operations.some((operation) => /back|keyboard/i.test(operation)));
  assert.equal(
    operations.indexOf('tap-submit-id'),
    operations.indexOf('wait-ready-id') + 1,
  );
});

test('typed login state parser accepts one allowlisted resource ID only', () => {
  const xml = (state) =>
    `<hierarchy><node enabled="true" visible-to-user="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_state_${state}" bounds="[0,0][100,100]" /></hierarchy>`;

  assert.equal(loginStateFromUiXml(xml('idle')), 'idle');
  assert.equal(loginStateFromUiXml(xml('ready')), 'ready');
  assert.equal(
    loginStateFromUiXml(xml('failure_permission_denied')),
    'failure_permission_denied',
  );
  assert.throws(
    () => loginStateFromUiXml(xml('failure_secret_leak')),
    (error) => error.safeCode === 'login_state_invalid',
  );
  assert.throws(
    () =>
      loginStateFromUiXml(
        `<hierarchy>${xml('idle')}${xml('ready')}</hierarchy>`,
      ),
    (error) => error.safeCode === 'login_state_ambiguous',
  );
});

test('login observer proves submitting then authenticated shell', async () => {
  const snapshots = [
    '<hierarchy><node enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_state_submitting" bounds="[0,0][100,100]" /></hierarchy>',
    '<hierarchy><node enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_authenticated_shell" bounds="[0,0][100,100]" /></hierarchy>',
  ];
  let clock = 0;

  const result = await observeLoginAuthentication({
    readSnapshot: async () => snapshots.shift() || snapshots.at(-1),
    waitImpl: async (milliseconds) => {
      clock += milliseconds;
    },
    now: () => clock,
    timeoutMs: 1_000,
  });

  assert.deepEqual(result, {
    authenticated: true,
    submittingObserved: true,
  });
});

test('login observer fails immediately with the typed safe auth state', async () => {
  const xml =
    '<hierarchy><node enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_state_failure_permission_denied" bounds="[0,0][100,100]" /></hierarchy>';

  await assert.rejects(
    observeLoginAuthentication({
      readSnapshot: async () => xml,
      waitImpl: async () => {},
      timeoutMs: 1_000,
    }),
    (error) => error.safeCode === 'ui_login_failure_permission_denied',
  );
});

test('composer proof classifies only empty, fixed, or unrelated text', () => {
  const composerXml = (text) =>
    '<hierarchy>' +
    `<node text="${text}" content-desc="" class="android.widget.EditText" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_ai_composer" bounds="[10,20][410,90]" />` +
    '</hierarchy>';

  assert.equal(composerInputStateFromUiXml(composerXml('')), 'empty');
  assert.equal(
    composerInputStateFromUiXml(composerXml(fixedArabicPrompt)),
    'fixedPrompt',
  );
  assert.equal(
    composerInputStateFromUiXml(composerXml('unrelated user text')),
    'other',
  );
  assert.equal(
    composerInputStateFromUiXml('<hierarchy></hierarchy>'),
    'missing',
  );
});

test('assistant text cannot spoof the resource-id completion marker', () => {
  const xml = [
    '<hierarchy>',
    '<node text="cashpilot_ai_acceptance_answer_complete_999" content-desc="" class="android.view.View" enabled="true" resource-id="" bounds="[0,0][10,10]" />',
    '<node text="" content-desc="" class="android.view.View" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_ai_acceptance_idle_0" bounds="[0,0][10,10]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(acceptanceStateFromUiXml(xml), {
    phase: 'idle',
    messageCount: 0,
  });
});

test('spoofing text before the trusted UI identifier cannot win selection', () => {
  const xml = [
    '<hierarchy>',
    '<node text="" content-desc="AI" class="android.view.View" enabled="true" resource-id="" bounds="[1,1][11,11]" />',
    '<node text="" content-desc="" class="android.view.View" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_dashboard_ai" bounds="[20,30][40,50]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(findUiTarget(xml, 'aiAssistant'), { x: 30, y: 40 });
});

test('acceptance UI selection fails closed when the identifier is absent', () => {
  const xml =
    '<hierarchy><node text="Email" content-desc="Email" class="android.widget.EditText" enabled="true" resource-id="" bounds="[1,1][11,11]" /></hierarchy>';

  assert.equal(findUiTarget(xml, 'email'), null);
});

test('settings live test taps the smallest clickable container around its trusted ID', () => {
  const xml = [
    '<hierarchy>',
    '<node text="ai_settings_live_test" content-desc="" enabled="true" visible-to-user="true" clickable="true" resource-id="" bounds="[0,0][500,500]">',
    '<node text="" content-desc="" enabled="true" visible-to-user="true" clickable="true" resource-id="" bounds="[10,20][310,120]">',
    '<node text="" content-desc="" enabled="true" visible-to-user="true" clickable="false" resource-id="com.example.cashpilot_ai:id/ai_settings_live_test" bounds="[30,40][130,70]" />',
    '</node>',
    '</node>',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(findUiTarget(xml, 'settingsLiveTest'), {
    x: 160,
    y: 70,
  });
});

test('settings live test falls back to the visible trusted ID bounds', () => {
  const xml = [
    '<hierarchy>',
    '<node text="ai_settings_live_test" content-desc="" enabled="true" visible-to-user="true" clickable="true" resource-id="" bounds="[0,0][500,500]" />',
    '<node text="" content-desc="" enabled="true" visible-to-user="true" clickable="false" resource-id="com.example.cashpilot_ai:id/ai_settings_live_test" bounds="[30,40][130,70]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(findUiTarget(xml, 'settingsLiveTest'), { x: 80, y: 55 });
});

test('settings live test ignores an offscreen ID before the visible action', () => {
  const xml = [
    '<hierarchy>',
    '<node text="" content-desc="" enabled="true" visible-to-user="false" clickable="true" resource-id="com.example.cashpilot_ai:id/ai_settings_live_test" bounds="[0,900][300,1000]" />',
    '<node text="" content-desc="" enabled="true" visible-to-user="true" clickable="true" resource-id="com.example.cashpilot_ai:id/ai_settings_live_test" bounds="[10,20][310,120]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(findUiTarget(xml, 'settingsLiveTest'), { x: 160, y: 70 });
});

test('settings live test uses physical viewport when Android visibility is false', () => {
  const xml = [
    '<hierarchy>',
    '<node text="" content-desc="" enabled="true" visible-to-user="false" clickable="true" resource-id="com.example.cashpilot_ai:id/ai_settings_live_test" bounds="[0,2500][300,2600]" />',
    '<node text="" content-desc="" enabled="true" visible-to-user="false" clickable="true" resource-id="com.example.cashpilot_ai:id/ai_settings_live_test" bounds="[10,1200][310,1300]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(
    findUiTarget(xml, 'settingsLiveTest', { width: 1080, height: 2400 }),
    { x: 160, y: 1250 },
  );
});

test('settings tap retries once only while the trusted status remains idle', async () => {
  const waits = [];
  let taps = 0;
  const statuses = ['idle', 'testing'];
  const result = await triggerSettingsLiveTest({
    readTarget: async () => ({ x: 50, y: 75 }),
    tap: async () => {
      taps += 1;
    },
    readStatus: async () => statuses.shift(),
    waitImpl: async (milliseconds) => {
      waits.push(milliseconds);
    },
  });

  assert.deepEqual(result, { initialStatus: 'testing', tapAttempts: 2 });
  assert.equal(taps, 2);
  assert.deepEqual(waits, [750, 400, 750, 400]);
});

test('settings tap never retries after checking is observable', async () => {
  let taps = 0;
  const result = await triggerSettingsLiveTest({
    readTarget: async () => ({ x: 50, y: 75 }),
    tap: async () => {
      taps += 1;
    },
    readStatus: async () => 'testing',
    waitImpl: async () => {},
  });

  assert.deepEqual(result, { initialStatus: 'testing', tapAttempts: 1 });
  assert.equal(taps, 1);
});

test('dashboard return target is selected by resource ID only', () => {
  const xml = [
    '<hierarchy>',
    '<node text="cashpilot_acceptance_nav_dashboard" content-desc="cashpilot_acceptance_nav_dashboard" enabled="true" resource-id="" bounds="[0,0][10,10]" />',
    '<node text="" content-desc="" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_nav_dashboard" bounds="[20,30][60,70]" />',
    '</hierarchy>',
  ].join('');
  assert.deepEqual(findUiTarget(xml, 'dashboard'), { x: 40, y: 50 });
});

test('authenticated shell target is selected by resource ID only', () => {
  const xml = [
    '<hierarchy>',
    '<node text="cashpilot_acceptance_authenticated_shell" content-desc="cashpilot_acceptance_authenticated_shell" enabled="true" resource-id="" bounds="[0,0][10,10]" />',
    '<node text="" content-desc="" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_authenticated_shell" bounds="[10,20][210,420]" />',
    '</hierarchy>',
  ].join('');
  assert.deepEqual(findUiTarget(xml, 'authenticatedShell'), {
    x: 110,
    y: 220,
  });
});

test('acceptance build needs no semantics or prompt-prefill defines', () => {
  assert.deepEqual(acceptanceBuildExtraDefines, []);
});

test('settings evidence uses only exact trusted resource IDs', () => {
  const trusted = settingsStateFromUiXml(
    settingsXml([
      'ai_settings_card',
      'ai_settings_remote_groq',
      'ai_settings_test_testing',
    ]),
  );
  assert.deepEqual(trusted, {
    rowIds: ['ai_settings_card', 'ai_settings_remote_groq'],
    testStatus: 'testing',
  });

  const spoofed = [
    '<hierarchy>',
    '<node text="ai_settings_card" content-desc="ai_settings_test_available" enabled="true" resource-id="" bounds="[0,0][10,10]" />',
    '<node text="" content-desc="" enabled="true" resource-id="other.package:id/ai_settings_remote_groq" bounds="[0,0][10,10]" />',
    '</hierarchy>',
  ].join('');
  assert.deepEqual(settingsStateFromUiXml(spoofed), {
    rowIds: [],
    testStatus: null,
  });
});

test('settings dynamic state fails closed when two statuses coexist', () => {
  assert.throws(
    () =>
      settingsStateFromUiXml(
        settingsXml([
          'ai_settings_test_testing',
          'ai_settings_test_available',
        ]),
      ),
    (error) => error.safeCode === 'settings_test_state_ambiguous',
  );
});

test('bounded settings scan accumulates all fixed rows and dynamic status', async () => {
  const snapshots = [
    settingsXml(settingsRequiredResourceIds.slice(0, 4)),
    settingsXml(settingsRequiredResourceIds.slice(4, 8)),
    settingsXml([
      ...settingsRequiredResourceIds.slice(8),
      'ai_settings_test_idle',
    ]),
  ];
  let snapshotIndex = 0;
  let scrollCount = 0;
  const result = await collectRequiredSettingsRows({
    snapshot: async () => snapshots[Math.min(snapshotIndex, 2)],
    scroll: async () => {
      scrollCount += 1;
      snapshotIndex += 1;
    },
    waitImpl: async () => {},
  });

  assert.equal(result.rowsVerified, true);
  assert.equal(result.rowCount, settingsRequiredResourceIds.length);
  assert.equal(result.testStatus, 'idle');
  assert.equal(scrollCount, 2);
  assert.deepEqual(new Set(result.rowIds), new Set(settingsRequiredResourceIds));
  assert.deepEqual(result.liveTestPoint, { x: 50, y: 47 });
});

test('settings scan stops at its explicit scroll bound', async () => {
  let scrollCount = 0;
  let presence;
  await assert.rejects(
    collectRequiredSettingsRows({
      snapshot: async () => settingsXml(['ai_settings_card']),
      scroll: async () => {
        scrollCount += 1;
      },
      waitImpl: async () => {},
      maxScrollSteps: 3,
    }),
    (error) => {
      presence = error.safeSettingsPresence;
      return error.safeCode === 'settings_rows_incomplete';
    },
  );
  assert.equal(scrollCount, 3);
  assert.deepEqual(presence, {
    card: true,
    remoteGroq: false,
    general20b: false,
    financial120b: false,
    localParser: false,
    receiptFirebase: false,
    fallbackDisabled: false,
    gatewayAvailable: false,
    authReady: false,
    appCheckVerified: false,
    liveTest: false,
    dynamicStatus: false,
  });
});

test('settings scan can reach the trailing live action after nine swipes', async () => {
  const rowsBeforeAction = settingsRequiredResourceIds.filter(
    (identifier) => identifier !== 'ai_settings_live_test',
  );
  let scrollCount = 0;
  const result = await collectRequiredSettingsRows({
    snapshot: async () =>
      settingsXml([
        ...rowsBeforeAction,
        'ai_settings_test_idle',
        ...(scrollCount >= 9 ? ['ai_settings_live_test'] : []),
      ]),
    scroll: async () => {
      scrollCount += 1;
    },
    waitImpl: async () => {},
  });

  assert.equal(result.rowsVerified, true);
  assert.equal(scrollCount, 9);
});

test('settings scan returns only with a current live-test coordinate', async () => {
  const gatewayId = 'ai_settings_gateway_available';
  const liveId = 'ai_settings_live_test';
  const snapshots = [
    settingsXml([
      ...settingsRequiredResourceIds.filter(
        (identifier) => identifier !== gatewayId,
      ),
      'ai_settings_test_idle',
    ]),
    settingsXml([gatewayId, 'ai_settings_test_idle']),
    settingsXml([liveId, 'ai_settings_test_idle']),
  ];
  let index = 0;
  let scrollCount = 0;
  const result = await collectRequiredSettingsRows({
    snapshot: async () => snapshots[Math.min(index, 2)],
    scroll: async () => {
      index += 1;
      scrollCount += 1;
    },
    waitImpl: async () => {},
    maxScrollSteps: 2,
  });

  assert.equal(result.rowsVerified, true);
  assert.equal(scrollCount, 2);
  assert.deepEqual(result.liveTestPoint, { x: 50, y: 7 });
});

test('settings scan refreshes from the top for delayed gateway health', async () => {
  let scans = 0;
  let resets = 0;
  let waits = 0;
  const expected = Object.freeze({ rowsVerified: true, rowCount: 11 });
  const result = await collectSettingsRowsAcrossRefreshes({
    reset: async () => {
      resets += 1;
    },
    scan: async () => {
      scans += 1;
      if (scans === 1) {
        const error = new Error('safe');
        error.safeCode = 'settings_rows_incomplete';
        throw error;
      }
      return expected;
    },
    waitImpl: async () => {
      waits += 1;
    },
  });

  assert.equal(result, expected);
  assert.equal(scans, 2);
  assert.equal(resets, 2);
  assert.equal(waits, 1);
});

test('settings scan retries a transient first dump failure then succeeds', async () => {
  let scans = 0;
  let resets = 0;
  let waits = 0;
  const expected = Object.freeze({ rowsVerified: true, rowCount: 11 });

  const result = await collectSettingsRowsAcrossRefreshes({
    reset: async () => {
      resets += 1;
    },
    scan: async () => {
      scans += 1;
      if (scans === 1) {
        const error = new Error('TRANSIENT_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'ui_dump_failed';
        throw error;
      }
      return expected;
    },
    waitImpl: async () => {
      waits += 1;
    },
  });

  assert.equal(result, expected);
  assert.equal(scans, 2);
  assert.equal(resets, 2);
  assert.equal(waits, 1);
});

test('settings scan fails closed after the transient dump retry bound', async () => {
  let scans = 0;
  let resets = 0;
  let waits = 0;

  await assert.rejects(
    collectSettingsRowsAcrossRefreshes({
      reset: async () => {
        resets += 1;
      },
      scan: async () => {
        scans += 1;
        const error = new Error('TRANSIENT_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'ui_dump_read_failed';
        throw error;
      },
      waitImpl: async () => {
        waits += 1;
      },
    }),
    (error) => error.safeCode === 'ui_dump_read_failed',
  );

  assert.equal(scans, 3);
  assert.equal(resets, 3);
  assert.equal(waits, 2);
});

test('settings refresh does not retry a non-row non-transient failure', async () => {
  let scans = 0;
  await assert.rejects(
    collectSettingsRowsAcrossRefreshes({
      reset: async () => {},
      scan: async () => {
        scans += 1;
        const error = new Error('SENSITIVE_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'settings_state_ambiguous';
        throw error;
      },
      waitImpl: async () => {},
    }),
    (error) => error.safeCode === 'settings_state_ambiguous',
  );
  assert.equal(scans, 1);
});

test('settings live test proves testing then available around one quiet window', async () => {
  let initialReads = 0;
  let settledReads = 0;
  let waits = 0;
  let waitedMs = 0;
  const result = await observeSettingsTestTransition({
    baselineStatus: 'idle',
    readInitialStatus: async () => {
      initialReads += 1;
      return 'testing';
    },
    readSettledStatus: async () => {
      settledReads += 1;
      return 'available';
    },
    waitImpl: async (milliseconds) => {
      waits += 1;
      waitedMs = milliseconds;
    },
    settleDelayMs: 123,
  });
  assert.deepEqual(result, {
    baselineIdle: true,
    testingUiObserved: true,
    stateMachineOrdered: true,
    available: true,
  });
  assert.equal(initialReads, 1);
  assert.equal(settledReads, 1);
  assert.equal(waits, 1);
  assert.equal(waitedMs, 123);
});

test('settings live test accepts an immediate available state without waiting', async () => {
  let waits = 0;
  const result = await observeSettingsTestTransition({
    baselineStatus: 'idle',
    readInitialStatus: async () => 'available',
    readSettledStatus: async () => {
      throw new Error('settled status must not be read');
    },
    waitImpl: async () => {
      waits += 1;
    },
    settleDelayMs: 0,
  });
  assert.deepEqual(result, {
    baselineIdle: true,
    testingUiObserved: false,
    stateMachineOrdered: true,
    available: true,
  });
  assert.equal(waits, 0);
});

test('settings live test surfaces a typed final failure after testing', async () => {
  await assert.rejects(
    observeSettingsTestTransition({
      baselineStatus: 'idle',
      readInitialStatus: async () => 'testing',
      readSettledStatus: async () => 'gateway_unavailable',
      waitImpl: async () => {},
      settleDelayMs: 0,
    }),
    (error) => error.safeCode === 'settings_live_test_failed',
  );
});

test('settings live test rejects a stale non-idle baseline before waiting', async () => {
  let reads = 0;
  let waits = 0;
  await assert.rejects(
    observeSettingsTestTransition({
      baselineStatus: 'available',
      readInitialStatus: async () => {
        reads += 1;
        return 'testing';
      },
      readSettledStatus: async () => {
        reads += 1;
        return 'available';
      },
      waitImpl: async () => {
        waits += 1;
      },
      settleDelayMs: 0,
    }),
    (error) => error.safeCode === 'settings_live_test_baseline_invalid',
  );
  assert.equal(reads, 0);
  assert.equal(waits, 0);
});

test('settings live test fails closed when the tap never starts testing', async () => {
  await assert.rejects(
    observeSettingsTestTransition({
      baselineStatus: 'idle',
      readInitialStatus: async () => 'idle',
      readSettledStatus: async () => 'available',
      waitImpl: async () => {},
      settleDelayMs: 0,
    }),
    (error) => error.safeCode === 'settings_live_test_not_started',
  );
});

test('settings live test times out when the settled state is still testing', async () => {
  await assert.rejects(
    observeSettingsTestTransition({
      baselineStatus: 'idle',
      readInitialStatus: async () => 'testing',
      readSettledStatus: async () => 'testing',
      waitImpl: async () => {},
      settleDelayMs: 0,
    }),
    (error) => error.safeCode === 'settings_available_timed_out',
  );
});

test('fixed first question uses the bounded hook; replacement stays ordered', async () => {
  const operationsFor = () => {
    const calls = [];
    return {
      calls,
      operations: {
        waitForComposer: async () => {
          calls.push('wait-composer');
          return { x: 1, y: 1 };
        },
        tapComposer: async () => calls.push('tap-composer'),
        proveComposerEmpty: async () => calls.push('prove-empty'),
        waitForPromptHook: async () => {
          calls.push('wait-prompt-hook');
          return { x: 2, y: 2 };
        },
        longPressPrompt: async () => calls.push('long-press-prompt'),
        proveFixedPrompt: async () => calls.push('prove-fixed-prompt'),
        selectAll: async () => calls.push('ctrl-a'),
        deleteSelection: async () => calls.push('delete'),
        inputReplacement: async () => calls.push('type-replacement'),
        waitForSend: async () => {
          calls.push('wait-send');
          return { x: 2, y: 2 };
        },
        tapSend: async () => calls.push('tap-send'),
        waitImpl: async () => calls.push('wait-after-delete'),
      },
    };
  };

  const fixedHook = operationsFor();
  const first = await prepareAndSubmitQuestion(0, fixedHook.operations);
  assert.deepEqual(first, { inputMode: 'fixedPromptHook' });
  assert.deepEqual(fixedHook.calls, [
    'wait-composer',
    'tap-composer',
    'prove-empty',
    'wait-prompt-hook',
    'long-press-prompt',
    'prove-fixed-prompt',
    'wait-send',
    'tap-send',
  ]);

  const replacement = operationsFor();
  const second = await prepareAndSubmitQuestion(1, replacement.operations);
  assert.deepEqual(second, { inputMode: 'replace' });
  assert.deepEqual(replacement.calls, [
    'wait-composer',
    'tap-composer',
    'ctrl-a',
    'delete',
    'wait-after-delete',
    'type-replacement',
    'wait-send',
    'tap-send',
  ]);
  assert.equal(questionInputMode(0), 'fixedPromptHook');
  assert.equal(questionInputMode(1), 'replace');
  assert.throws(
    () => questionInputMode(2),
    (error) => error.safeCode === 'question_index_invalid',
  );
});

test('question completion accepts exactly one user and one assistant message', async () => {
  const states = [
    { phase: 'sending', messageCount: 5 },
    { phase: 'sending', messageCount: 6 },
    { phase: 'answer_complete', messageCount: 6 },
    { phase: 'answer_complete', messageCount: 6 },
    { phase: 'answer_complete', messageCount: 6 },
    { phase: 'answer_complete', messageCount: 6 },
    { phase: 'answer_complete', messageCount: 6 },
  ];
  const waits = [];
  const result = await observeQuestionCompletion({
    baselineMessageCount: 4,
    readState: async () => states.shift(),
    waitImpl: async (milliseconds) => waits.push(milliseconds),
    now: () => 0,
  });

  assert.deepEqual(result, {
    sendingObserved: true,
    answerCompleted: true,
    messageDelta: 2,
    duplicateResponse: false,
  });
  assert.equal(states.length, 0);
  assert.deepEqual(waits.slice(-4), [200, 200, 200, 200]);
});

test('question completion rejects a late duplicate during bounded settle', async () => {
  const states = [
    { phase: 'answer_complete', messageCount: 6 },
    { phase: 'answer_complete', messageCount: 6 },
    { phase: 'answer_complete', messageCount: 7 },
  ];

  await assert.rejects(
    observeQuestionCompletion({
      baselineMessageCount: 4,
      readState: async () => states.shift(),
      waitImpl: async () => {},
      now: () => 0,
    }),
    (error) => error.safeCode === 'groq_duplicate_response_observed',
  );
});

test('question completion rejects a duplicate assistant message', async () => {
  await assert.rejects(
    observeQuestionCompletion({
      baselineMessageCount: 4,
      readState: async () => ({
        phase: 'answer_complete',
        messageCount: 7,
      }),
      waitImpl: async () => {},
      now: () => 0,
    }),
    (error) => error.safeCode === 'groq_duplicate_response_observed',
  );
});

test('question state and input contracts stay bounded and fail closed', async () => {
  const composerNode = (text) =>
    `<node text="${text}" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_ai_composer" bounds="[0,0][100,100]" />`;

  assert.throws(
    () =>
      composerInputStateFromUiXml(
        `<hierarchy>${composerNode('')}${composerNode(fixedArabicPrompt)}</hierarchy>`,
      ),
    (error) => error.safeCode === 'composer_state_ambiguous',
  );
  assert.throws(
    () =>
      acceptanceStateFromUiXml(
        '<hierarchy>' +
          '<node resource-id="com.example.cashpilot_ai:id/cashpilot_ai_acceptance_idle_0" />' +
          '<node resource-id="com.example.cashpilot_ai:id/cashpilot_ai_acceptance_sending_1" />' +
          '</hierarchy>',
      ),
    (error) => error.safeCode === 'acceptance_state_ambiguous',
  );
  assert.throws(
    () =>
      acceptanceStateFromUiXml(
        '<hierarchy><node resource-id="com.example.cashpilot_ai:id/cashpilot_ai_acceptance_answer_complete_1001" /></hierarchy>',
      ),
    (error) => error.safeCode === 'acceptance_state_invalid',
  );
  await assert.rejects(
    prepareAndSubmitQuestion(0, {
      waitForComposer: async () => ({ x: 1, y: 1 }),
      tapComposer: async () => {},
      waitForSend: async () => ({ x: 2, y: 2 }),
      tapSend: async () => {},
      waitImpl: async () => {},
    }),
    (error) => error.safeCode === 'question_input_contract_invalid',
  );
});

test('question completion preserves failure, regression, timeout, and settle bounds', async () => {
  await assert.rejects(
    observeQuestionCompletion({
      baselineMessageCount: 4,
      readState: async () => ({ phase: 'failure', messageCount: 4 }),
      waitImpl: async () => {},
      now: () => 0,
    }),
    (error) => error.safeCode === 'groq_ui_failure',
  );
  await assert.rejects(
    observeQuestionCompletion({
      baselineMessageCount: 4,
      readState: async () => ({ phase: 'sending', messageCount: 3 }),
      waitImpl: async () => {},
      now: () => 0,
    }),
    (error) => error.safeCode === 'groq_message_count_regressed',
  );
  await assert.rejects(
    observeQuestionCompletion({
      baselineMessageCount: 4,
      readState: async () => ({ phase: 'idle', messageCount: 4 }),
      waitImpl: async () => {},
      timeoutMs: 1_000,
      settleSnapshotCount: 1,
      now: () => 0,
    }),
    (error) => error.safeCode === 'question_completion_contract_invalid',
  );

  let clock = 0;
  let reads = 0;
  const waits = [];
  await assert.rejects(
    observeQuestionCompletion({
      baselineMessageCount: 4,
      readState: async () => {
        reads += 1;
        return { phase: 'sending', messageCount: 5 };
      },
      waitImpl: async (milliseconds) => {
        waits.push(milliseconds);
        clock += milliseconds;
      },
      timeoutMs: 399,
      now: () => clock,
    }),
    (error) => error.safeCode === 'groq_answer_timed_out',
  );
  assert.equal(reads, 2);
  assert.deepEqual(waits, [200, 200]);
});

test('synthetic Firestore profile creation is create-only', async () => {
  const calls = [];
  await createSyntheticProfile(
    { accessToken: 'synthetic-access' },
    syntheticProfile,
    async (url, options) => {
      calls.push({ url, options });
      return {
        ok: true,
        status: 200,
        async json() {
          return matchingProfileDocument();
        },
      };
    },
  );

  assert.equal(calls.length, 1);
  assert.equal(calls[0].options.method, 'PATCH');
  assert.match(calls[0].url, /\?currentDocument\.exists=false$/);
  assert.equal(
    firestoreProfileUrl(syntheticProfile.localId, { createOnly: true }),
    calls[0].url,
  );
});

test('synthetic profile deletion requires a confirmed follow-up 404', async () => {
  const methods = [];
  const responses = [
    {
      ok: true,
      status: 200,
      json: async () => matchingProfileDocument(),
    },
    { ok: true, status: 200, json: async () => ({}) },
    { ok: false, status: 404, json: async () => ({}) },
  ];

  const deleted = await deleteSyntheticProfile(
    { accessToken: 'synthetic-access' },
    syntheticProfile,
    async (_url, options) => {
      methods.push(options.method);
      return responses.shift();
    },
    async () => {},
  );

  assert.equal(deleted, true);
  assert.deepEqual(methods, ['GET', 'DELETE', 'GET']);
});

test('synthetic profile cleanup never deletes a nonmatching document', async () => {
  const methods = [];
  const document = matchingProfileDocument();
  document.fields.email.stringValue = 'not-the-synthetic-profile@example.com';

  const deleted = await deleteSyntheticProfile(
    { accessToken: 'synthetic-access' },
    syntheticProfile,
    async (_url, options) => {
      methods.push(options.method);
      return { ok: true, status: 200, json: async () => document };
    },
    async () => {},
  );

  assert.equal(deleted, false);
  assert.deepEqual(methods, ['GET']);
});

test('acceptance-only UI identifiers do not depend on localized text or class', () => {
  const xml = [
    '<hierarchy>',
    '<node text="" content-desc="" class="android.view.View" enabled="true" resource-id="com.example.cashpilot_ai:id/cashpilot_acceptance_login_email" bounds="[100,200][500,300]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(findUiTarget(xml, 'email'), { x: 300, y: 250 });
});

test('process proof requires absence followed by a different PID', () => {
  assert.deepEqual(
    proveProcessRestart({ oldPid: '1200', stopped: true, newPid: '1300' }),
    {
      oldProcessStopped: true,
      newProcessStarted: true,
      pidChanged: true,
    },
  );
  assert.throws(
    () =>
      proveProcessRestart({ oldPid: '1200', stopped: true, newPid: '1200' }),
    (error) => error.safeCode === 'process_restart_not_proven',
  );
  assert.throws(
    () =>
      proveProcessRestart({ oldPid: '1200', stopped: false, newPid: '1300' }),
    (error) => error.safeCode === 'process_restart_not_proven',
  );
});

test('pid query treats Android status 1 with empty output as stopped', () => {
  assert.equal(
    pidFromCommandResult({ status: 1, stdout: '', stderr: '' }),
    null,
  );
  assert.equal(pidFromCommandResult({ status: 0, stdout: '4321\n' }), '4321');
  assert.throws(
    () => pidFromCommandResult({ status: 1, stdout: 'unexpected' }),
    (error) => error.safeCode === 'pid_query_failed',
  );
  assert.throws(
    () =>
      pidFromCommandResult({
        status: 1,
        stdout: '',
        stderr: 'transport unavailable',
      }),
    (error) => error.safeCode === 'pid_query_failed',
  );
  assert.throws(
    () => pidFromCommandResult({ status: null, stdout: '', error: {} }),
    (error) => error.safeCode === 'pid_query_failed',
  );
});

test('dry run invokes feasibility inspection only', async () => {
  const calls = [];
  const adapter = {
    async inspectFeasibility() {
      calls.push('inspect');
      return {
        adbAvailable: true,
        deviceAvailable: true,
        flutterAvailable: true,
        packageInstalled: false,
        uiDriverAvailable: true,
      };
    },
  };
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: parseForceStopArguments([]),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.deepEqual(calls, ['inspect']);
  assert.equal(result.exitCode, 0);
  assert.equal(result.liveExecuted, false);
  assert.deepEqual(logs, [
    'ANDROID_GROQ_RESTART_FEASIBILITY adb=true device=true flutter=true packageInstalled=false uiDriver=uiautomator liveExecuted=false',
  ]);
});

function successfulFakeAdapter({
  samePid = false,
  appCheckSamePid = false,
  appCheckPidMissing = false,
  appCheckStopFailure = false,
  askFailure = false,
  cleanupFailure = false,
  settingsFailure = null,
  settingsBaseline = 'idle',
  dashboardFailure = false,
} = {}) {
  const calls = [];
  const settingsBaselines = [];
  let restartAttempt = 0;
  const sensitiveToken = 'TOKEN_SENTINEL_DO_NOT_LOG';
  const sensitiveUid = 'UID_SENTINEL_DO_NOT_LOG';
  const sensitiveEmail = 'EMAIL_SENTINEL_DO_NOT_LOG@example.com';
  const adapter = {
    async inspectFeasibility() {
      calls.push('inspect');
      return {
        adbAvailable: true,
        deviceAvailable: true,
        flutterAvailable: true,
        packageInstalled: false,
        uiDriverAvailable: true,
      };
    },
    async verifyGatewayHealth() {
      calls.push('health');
    },
    async loadCloudCredentials() {
      calls.push('cloud');
      return { accessToken: sensitiveToken, apiKey: 'API_KEY_SENTINEL' };
    },
    async createSyntheticUser() {
      calls.push('create-user');
      return {
        localId: sensitiveUid,
        email: sensitiveEmail,
        password: 'PASSWORD_SENTINEL_DO_NOT_LOG',
      };
    },
    async buildAndInstall() {
      calls.push('build-install');
    },
    async launchFromLauncher() {
      calls.push('launcher');
    },
    async registerAppCheck() {
      calls.push('app-check');
      return {
        existing: false,
        resourceCreated: true,
        resourceName: 'RESOURCE_SENTINEL_DO_NOT_LOG',
      };
    },
    async reachLoginScreen() {
      calls.push('reach-login');
    },
    async login() {
      calls.push('login');
    },
    async openAi() {
      calls.push('open-ai');
    },
    async navigateToDashboard() {
      calls.push('dashboard-after');
      if (dashboardFailure) {
        const error = new Error('DASHBOARD_TEXT_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'dashboard_navigation_unavailable';
        throw error;
      }
    },
    async askQuestion(_device, index) {
      calls.push(`ask-${index}`);
      if (askFailure && index === 1) {
        const error = new Error('SENSITIVE_RESPONSE_MUST_NOT_LOG');
        error.safeCode = 'groq_ui_failure';
        throw error;
      }
      return {
        sendingObserved: true,
        answerCompleted: true,
        messageDelta: 2,
        duplicateResponse: false,
      };
    },
    async verifySettings() {
      calls.push('settings-before');
      if (settingsFailure === 'before') {
        const error = new Error('SETTINGS_TEXT_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'settings_rows_incomplete';
        throw error;
      }
      return {
        rowsVerified: true,
        rowCount: settingsRequiredResourceIds.length,
        testStatus: settingsBaseline,
        liveTestPoint: { x: 101, y: 202 },
      };
    },
    async runSettingsLiveTest(_deviceId, baselineStatus) {
      calls.push('settings-live-test');
      settingsBaselines.push(baselineStatus);
      return {
        baselineIdle: true,
        testingUiObserved: false,
        stateMachineOrdered: true,
        available: true,
      };
    },
    async getPid() {
      calls.push('get-pid');
      restartAttempt += 1;
      if (restartAttempt === 1 && appCheckPidMissing) {
        return null;
      }
      return restartAttempt === 1 ? '1100' : '1200';
    },
    async forceStop() {
      calls.push('force-stop');
    },
    async waitForStopped() {
      calls.push('wait-stopped');
      if (restartAttempt === 1 && appCheckStopFailure) {
        const error = new Error('PROCESS_TEXT_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'old_process_still_running';
        throw error;
      }
      return true;
    },
    async waitForNewPid(_deviceId, oldPid) {
      calls.push('wait-new-pid');
      const reusePid = restartAttempt === 1 ? appCheckSamePid : samePid;
      return reusePid ? oldPid : String(Number(oldPid) + 100);
    },
    async verifyRestoredSettings() {
      calls.push('settings-after');
      if (settingsFailure === 'after') {
        const error = new Error('SETTINGS_TEXT_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'settings_route_not_restored';
        throw error;
      }
      return {
        rowsVerified: true,
        rowCount: settingsRequiredResourceIds.length,
        restoredSession: true,
        settingsReopened: true,
        dynamicStatusObserved: true,
      };
    },
    async logout() {
      calls.push('logout');
      return true;
    },
    async deleteSyntheticUser() {
      calls.push('delete-user');
      return !cleanupFailure;
    },
    async deleteSyntheticProfile() {
      calls.push('delete-profile');
      return true;
    },
    async deleteAppCheckRegistration() {
      calls.push('delete-app-check');
      return true;
    },
    async clearLogs() {
      calls.push('clear-logs');
      return true;
    },
    async clearUiDump() {
      calls.push('clear-ui-dump');
      return true;
    },
    uninstall() {
      calls.push('uninstall');
      return true;
    },
  };
  return { adapter, calls, settingsBaselines };
}

test('live orchestration proves two UI requests around an OS process restart', async () => {
  const { adapter, calls, settingsBaselines } = successfulFakeAdapter();
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 0);
  assert.deepEqual(settingsBaselines, ['idle']);
  assert.deepEqual(calls, [
    'inspect',
    'health',
    'build-install',
    'cloud',
    'create-user',
    'launcher',
    'app-check',
    'get-pid',
    'force-stop',
    'wait-stopped',
    'launcher',
    'wait-new-pid',
    'reach-login',
    'login',
    'open-ai',
    'ask-0',
    'settings-before',
    'settings-live-test',
    'get-pid',
    'force-stop',
    'wait-stopped',
    'launcher',
    'wait-new-pid',
    'settings-after',
    'dashboard-after',
    'open-ai',
    'ask-1',
    'delete-profile',
    'delete-user',
    'delete-app-check',
    'logout',
    'clear-ui-dump',
    'clear-logs',
    'uninstall',
  ]);
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_APPCHECK_PROCESS oldProcessStopped=true launcherCategory=true newProcessStarted=true pidChanged=true durationMs=[0-9]+/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_PROCESS oldProcessStopped=true launcherCategory=true newProcessStarted=true pidChanged=true/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_FIRST sendingObserved=true answerCompleted=true messageDelta=2 duplicateResponse=false promptClass=arabicInflation inputMode=oneShotHook prefilled=false providerConfigured=groq route=generalConversation firebaseFallback=false/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_SETTINGS phase=beforeRestart rowsVerified=true dynamicStatus=true card=true remoteGroq=true general20b=true financial120b=true localParser=true receiptFirebase=true fallbackDisabled=true gatewayAvailable=true authReady=true appCheckVerified=true liveTest=true durationMs=[0-9]+/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_SETTINGS_TEST baselineIdle=true testingUiObserved=false stateMachineOrdered=true availableObserved=true durationMs=[0-9]+/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_SETTINGS_REOPEN restoredSession=true settingsReopened=true rowsVerified=true dynamicStatus=true card=true remoteGroq=true general20b=true financial120b=true localParser=true receiptFirebase=true fallbackDisabled=true gatewayAvailable=true authReady=true appCheckVerified=true liveTest=true durationMs=[0-9]+/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_SECOND restoredSession=true sendingObserved=true answerCompleted=true messageDelta=2 duplicateResponse=false providerConfigured=groq route=generalConversation firebaseFallback=false/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_RESULT completed=true processRestart=true secondQuestion=true cleanup=true settingsBefore=true settingsTest=true settingsAfter=true/,
  );
  assert.doesNotMatch(
    output,
    /TOKEN_SENTINEL|UID_SENTINEL|EMAIL_SENTINEL|PASSWORD_SENTINEL|RESOURCE_SENTINEL|SETTINGS_TEXT_SENTINEL|1200|1300|Give me three|<hierarchy>/,
  );
});

test('same PID is rejected as an integration restart and cleanup still runs', async () => {
  const { adapter, calls } = successfulFakeAdapter({ samePid: true });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'process_restart_not_proven');
  assert.ok(calls.includes('settings-before'));
  assert.ok(calls.includes('settings-live-test'));
  assert.ok(!calls.includes('settings-after'));
  assert.ok(!calls.includes('ask-1'));
  assert.ok(calls.includes('delete-user'));
  assert.ok(calls.includes('uninstall'));
  assert.match(
    logs.join('\n'),
    /ANDROID_GROQ_RESTART_FAILURE stage=launcher_reopen code=process_restart_not_proven/,
  );
});

test('App Check process refresh rejects the same PID before login and cleans up', async () => {
  const { adapter, calls } = successfulFakeAdapter({ appCheckSamePid: true });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'process_restart_not_proven');
  assert.ok(!calls.includes('reach-login'));
  assert.ok(!calls.includes('login'));
  assert.ok(calls.includes('delete-user'));
  assert.ok(calls.includes('uninstall'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_FAILURE stage=app_check_process_refresh code=process_restart_not_proven/,
  );
  assert.doesNotMatch(output, /PROCESS_TEXT_SENTINEL_DO_NOT_LOG|1100|1200/);
});

test('missing App Check bootstrap PID fails before stopping and cleans up', async () => {
  const { adapter, calls } = successfulFakeAdapter({
    appCheckPidMissing: true,
  });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'app_check_process_not_observed');
  assert.equal(calls.filter((call) => call === 'force-stop').length, 0);
  assert.ok(!calls.includes('reach-login'));
  assert.ok(calls.includes('delete-user'));
  assert.ok(calls.includes('uninstall'));
  assert.match(
    logs.join('\n'),
    /ANDROID_GROQ_RESTART_FAILURE stage=app_check_process_refresh code=app_check_process_not_observed/,
  );
});

test('App Check stop timeout remains content-blind and cleans up', async () => {
  const { adapter, calls } = successfulFakeAdapter({
    appCheckStopFailure: true,
  });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'old_process_still_running');
  assert.ok(!calls.includes('reach-login'));
  assert.ok(calls.includes('delete-user'));
  assert.ok(calls.includes('uninstall'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_FAILURE stage=app_check_process_refresh code=old_process_still_running/,
  );
  assert.doesNotMatch(output, /PROCESS_TEXT_SENTINEL_DO_NOT_LOG/);
});

test('settings failure prevents the acceptance restart and still cleans up', async () => {
  const { adapter, calls } = successfulFakeAdapter({
    settingsFailure: 'before',
  });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'settings_rows_incomplete');
  assert.equal(calls.filter((call) => call === 'force-stop').length, 1);
  assert.ok(calls.includes('delete-user'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_FAILURE stage=settings_before_restart code=settings_rows_incomplete/,
  );
  assert.doesNotMatch(output, /SETTINGS_TEXT_SENTINEL_DO_NOT_LOG/);
});

test('stale Settings live-test baseline is rejected before tapping and still cleans up', async () => {
  const { adapter, calls, settingsBaselines } = successfulFakeAdapter({
    settingsBaseline: 'available',
  });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'settings_live_test_baseline_invalid');
  assert.deepEqual(settingsBaselines, []);
  assert.ok(!calls.includes('settings-live-test'));
  assert.equal(calls.filter((call) => call === 'force-stop').length, 1);
  assert.ok(calls.includes('delete-user'));
  assert.match(
    logs.join('\n'),
    /ANDROID_GROQ_RESTART_FAILURE stage=settings_before_restart code=settings_live_test_baseline_invalid/,
  );
});

test('restored Settings failure preserves restart proof and blocks question two', async () => {
  const { adapter, calls } = successfulFakeAdapter({
    settingsFailure: 'after',
  });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'settings_route_not_restored');
  assert.ok(calls.includes('settings-after'));
  assert.ok(!calls.includes('ask-1'));
  assert.ok(calls.includes('delete-user'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_FAILURE stage=settings_after_restart code=settings_route_not_restored/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_RESULT completed=false processRestart=true secondQuestion=false cleanup=true settingsBefore=true settingsTest=true settingsAfter=false/,
  );
  assert.doesNotMatch(output, /SETTINGS_TEXT_SENTINEL_DO_NOT_LOG/);
});

test('dashboard resource navigation is required before the second Chat', async () => {
  const { adapter, calls } = successfulFakeAdapter({
    dashboardFailure: true,
  });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'dashboard_navigation_unavailable');
  assert.equal(calls.filter((call) => call === 'open-ai').length, 1);
  assert.ok(!calls.includes('ask-1'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_FAILURE stage=dashboard_after_restart code=dashboard_navigation_unavailable/,
  );
  assert.doesNotMatch(output, /DASHBOARD_TEXT_SENTINEL_DO_NOT_LOG/);
});

test('critical cleanup failure makes an otherwise complete proof nonzero', async () => {
  const { adapter } = successfulFakeAdapter({ cleanupFailure: true });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  const output = logs.join('\n');
  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'cleanup_incomplete');
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_CLEANUP .*userDeleted=false .*complete=false/,
  );
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_RESULT completed=false processRestart=true secondQuestion=true cleanup=false/,
  );
});

test('second UI failure remains content-blind and still cleans up', async () => {
  const { adapter, calls } = successfulFakeAdapter({ askFailure: true });
  const logs = [];

  const result = await executeForceStopAcceptance({
    options: liveOptions(),
    adapter,
    log: (line) => logs.push(line),
  });

  const output = logs.join('\n');
  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'groq_ui_failure');
  assert.ok(calls.includes('logout'));
  assert.ok(calls.includes('delete-user'));
  assert.ok(calls.includes('delete-app-check'));
  assert.doesNotMatch(output, /SENSITIVE_RESPONSE_MUST_NOT_LOG/);
  assert.match(
    output,
    /ANDROID_GROQ_RESTART_FAILURE stage=second_ui_question code=groq_ui_failure/,
  );
});
