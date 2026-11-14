'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const {
  acceptanceUiStateFromXml,
  emitSafeMarker,
  executeAcceptance,
  listSafeGatewayTraces,
  longPressPoint,
  observeOfflineRetryCompletion,
  offlineQuestionInputCommands,
  parseAcceptanceArguments,
  resourcePointFromUiXml,
  validateTraceExpectation,
  verifyGatewayTraceWindow,
  waitForDeviceNetworkState,
  waitForExternalAppState,
} = require('./android_appcheck_smalltalk_acceptance_support.cjs');
const {
  createBoundedExternalProcessWaiter,
} = require('./android_external_process_wait_primitives.cjs');

function liveOptions() {
  return parseAcceptanceArguments([
    '--execute-live',
    '--dedicated-device',
    '--literal-flutter-run-confirmed',
    '--manual-app-check-registration-confirmed',
    '--synthetic-account-confirmed',
    '--network-control-confirmed',
    '--no-build-install-uninstall-confirmed',
    '--run-wait-seconds',
    '30',
  ]);
}

function successfulQuestionProof() {
  return {
    sendingObserved: true,
    answerCompleted: true,
    messageDelta: 2,
    duplicateResponse: false,
  };
}

function successfulRetryProof() {
  return {
    sendingObserved: true,
    answerCompleted: true,
    reusedUserMessage: true,
    assistantMessageDelta: 1,
    totalMessageDelta: 2,
    duplicateResponse: false,
  };
}

function createFakeHarness({
  smallTalkFails = false,
  externalStopFails = false,
  logoutSucceeds = true,
} = {}) {
  const calls = [];
  const traceExpectations = [];
  let feasibilityReads = 0;
  let windowNumber = 0;
  const sensitive = Object.freeze({
    accessToken: 'ACCESS_TOKEN_SENTINEL_DO_NOT_LOG',
    apiKey: 'API_KEY_SENTINEL_DO_NOT_LOG',
    localId: 'UID_SENTINEL_DO_NOT_LOG',
    email: 'EMAIL_SENTINEL_DO_NOT_LOG@example.com',
    password: 'PASSWORD_SENTINEL_DO_NOT_LOG',
    prompt: 'PROMPT_SENTINEL_DO_NOT_LOG',
    response: 'RESPONSE_SENTINEL_DO_NOT_LOG',
    appCheckToken: 'APPCHECK_TOKEN_SENTINEL_DO_NOT_READ_OR_LOG',
  });
  const adapter = {
    async inspectFeasibility() {
      feasibilityReads += 1;
      calls.push(`inspect-${feasibilityReads}`);
      return {
        adbAvailable: true,
        deviceAvailable: true,
        flutterAvailable: true,
        uiDriverAvailable: true,
        packageInstalled: feasibilityReads > 1,
      };
    },
    async verifyGatewayHealth() {
      calls.push('gateway-health');
    },
    async loadCloudCredentials() {
      calls.push('cloud-credentials');
      return {
        accessToken: sensitive.accessToken,
        apiKey: sensitive.apiKey,
      };
    },
    async createSyntheticUser() {
      calls.push('create-synthetic');
      return {
        localId: sensitive.localId,
        email: sensitive.email,
        password: sensitive.password,
      };
    },
    async getPid() {
      calls.push('initial-pid');
      return null;
    },
    async forceStop() {
      calls.push('force-stop');
    },
    async waitForStopped() {
      calls.push('wait-force-stop');
      return true;
    },
    async normalizeSignedOut() {
      calls.push('normalize-signed-out');
      return { signedOut: true, priorSession: false };
    },
    async reachLoginScreen() {
      calls.push('reach-login');
    },
    async login() {
      calls.push('login');
    },
    async openAi(_deviceId, options) {
      calls.push(options?.requireRestoredSession ? 'open-ai-restored' : 'open-ai');
    },
    beginGatewayWindow() {
      windowNumber += 1;
      calls.push(`window-open-${windowNumber}`);
      return { windowNumber };
    },
    closeGatewayWindow(window) {
      calls.push(`window-close-${window.windowNumber}`);
      return window;
    },
    async verifyGatewayWindow(_cloud, window, expectedCount) {
      calls.push(`trace-${window.windowNumber}-${expectedCount}`);
      traceExpectations.push(expectedCount);
      return expectedCount === 0
        ? {
            traceCount: 0,
            httpStatus: 'none',
            provider: 'none',
            model: 'none',
          }
        : {
            traceCount: 1,
            httpStatus: 200,
            provider: 'groq',
            model: 'general20b',
          };
    },
    async askSmallTalk() {
      calls.push('small-talk');
      if (smallTalkFails) {
        const error = new Error(sensitive.response);
        error.safeCode = 'small_talk_completion_not_proven';
        throw error;
      }
      return successfulQuestionProof();
    },
    async askRemote(_deviceId, index) {
      calls.push(`remote-${index}`);
      return successfulQuestionProof();
    },
    async verifySettings() {
      calls.push('settings-verify');
      return {
        rowsVerified: true,
        rowCount: 11,
        testStatus: 'idle',
      };
    },
    async runSettingsLiveTest() {
      calls.push('settings-live');
      return {
        baselineIdle: true,
        testingUiObserved: true,
        stateMachineOrdered: true,
        available: true,
      };
    },
    async launchFromLauncher() {
      calls.push('launcher');
    },
    async waitForNewPid() {
      calls.push('new-pid');
      return '300';
    },
    async navigateToDashboard() {
      calls.push('dashboard');
    },
    async setNetworkOnline(_deviceId, online) {
      calls.push(online ? 'network-online' : 'network-offline');
      return true;
    },
    async submitOffline() {
      calls.push('offline-submit');
      return {
        baselineMessageCount: 6,
        failedMessageCount: 8,
        failedMessageDelta: 2,
        retryVisible: true,
        failureReason: 'offline',
      };
    },
    async retryOffline() {
      calls.push('retry');
      return successfulRetryProof();
    },
    async logout() {
      calls.push('logout');
      return logoutSucceeds;
    },
    async deleteSyntheticProfile() {
      calls.push('delete-profile');
      return true;
    },
    async deleteSyntheticUser() {
      calls.push('delete-user');
      return true;
    },
    async clearUiDump() {
      calls.push('clear-ui-dump');
      return true;
    },
    async clearLogs() {
      calls.push('clear-logs');
      return true;
    },
    async buildAndInstall() {
      calls.push('FORBIDDEN-build-install');
      throw new Error('forbidden');
    },
    async uninstall() {
      calls.push('FORBIDDEN-uninstall');
      throw new Error('forbidden');
    },
    async registerAppCheck() {
      calls.push('FORBIDDEN-register-app-check');
      throw new Error(sensitive.appCheckToken);
    },
    async deleteAppCheckRegistration() {
      calls.push('FORBIDDEN-delete-app-check');
      throw new Error(sensitive.appCheckToken);
    },
    async readAppCheckToken() {
      calls.push('FORBIDDEN-read-app-check');
      throw new Error(sensitive.appCheckToken);
    },
  };
  const coordinator = {
    async waitForStarted(_deviceId, previousPid, timeoutMs) {
      calls.push('external-start');
      assert.equal(previousPid, null);
      assert.equal(timeoutMs, 30_000);
      return '200';
    },
    async waitForStopped(_deviceId, timeoutMs) {
      calls.push('external-stop');
      assert.equal(timeoutMs, 30_000);
      if (externalStopFails) {
        const error = new Error('EXTERNAL_STOP_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'external_plain_run_not_stopped';
        throw error;
      }
      return true;
    },
  };
  return { adapter, calls, coordinator, sensitive, traceExpectations };
}

test('defaults to feasibility-only dry run with no mutations', async () => {
  const options = parseAcceptanceArguments([]);
  const { adapter, calls, coordinator } = createFakeHarness();
  const logs = [];
  const result = await executeAcceptance({
    options,
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.deepEqual(result, { exitCode: 0, liveExecuted: false });
  assert.deepEqual(calls, ['inspect-1']);
  assert.match(
    logs.join('\n'),
    /ANDROID_APPCHECK_SMALLTALK_RESULT completed=false dryRun=true .*noAppCheckMutation=true/,
  );
});

test('live mode requires every explicit operator and safety confirmation', () => {
  const flags = [
    '--dedicated-device',
    '--literal-flutter-run-confirmed',
    '--manual-app-check-registration-confirmed',
    '--synthetic-account-confirmed',
    '--network-control-confirmed',
    '--no-build-install-uninstall-confirmed',
  ];
  for (const omitted of flags) {
    assert.throws(
      () =>
        parseAcceptanceArguments([
          '--execute-live',
          ...flags.filter((flag) => flag !== omitted),
        ]),
      (error) => error.safeCode === 'live_confirmation_incomplete',
    );
  }
  assert.equal(liveOptions().runWaitMs, 30_000);
  assert.throws(
    () => parseAcceptanceArguments(['--device', 'emulator-5556']),
    (error) => error.safeCode === 'dedicated_emulator_required',
  );
});

test('resource-ID parser recognizes final small-talk, retry, and typed offline IDs', () => {
  const xml = [
    '<hierarchy>',
    '<node resource-id="com.example.cashpilot_ai:id/cashpilot_ai_acceptance_failure_offline_7" enabled="true" bounds="[0,0][900,1200]" />',
    '<node resource-id="cashpilot_acceptance_ai_small_talk" enabled="true" bounds="[10,20][110,220]" />',
    '<node resource-id="cashpilot_acceptance_ai_retry" enabled="true" bounds="[20,30][220,130]" />',
    '</hierarchy>',
  ].join('');

  assert.deepEqual(resourcePointFromUiXml(xml, 'cashpilot_acceptance_ai_small_talk'), {
    x: 60,
    y: 120,
  });
  assert.deepEqual(acceptanceUiStateFromXml(xml), {
    state: {
      phase: 'failure',
      failureKind: 'offline',
      messageCount: 7,
    },
    retryVisible: true,
    offlineReason: true,
  });
  assert.throws(
    () => resourcePointFromUiXml(xml, 'cashpilot_acceptance_ai_unknown'),
    (error) => error.safeCode === 'ui_target_unsupported',
  );
});

test('identical duplicate semantics nodes settle to one state but conflicts fail closed', () => {
  const duplicate = [
    '<hierarchy>',
    '<node resource-id="cashpilot_ai_acceptance_answer_complete_2" enabled="true" bounds="[0,0][10,10]" />',
    '<node resource-id="cashpilot_ai_acceptance_answer_complete_2" enabled="true" bounds="[0,0][10,10]" />',
    '</hierarchy>',
  ].join('');
  assert.equal(acceptanceUiStateFromXml(duplicate).state.messageCount, 2);
  const conflicting = duplicate.replace(
    'cashpilot_ai_acceptance_answer_complete_2',
    'cashpilot_ai_acceptance_sending_1',
  );
  assert.throws(
    () => acceptanceUiStateFromXml(conflicting),
    (error) => error.safeCode === 'acceptance_state_ambiguous',
  );
});

test('small-talk acceptance hook is one atomic resource-ID long press of at least 650ms', () => {
  const commands = [];
  longPressPoint(
    'emulator-5554',
    { x: 60, y: 120 },
    (deviceId, args, options) => commands.push({ deviceId, args, options }),
  );

  assert.equal(commands.length, 1);
  assert.equal(commands[0].deviceId, 'emulator-5554');
  assert.deepEqual(commands[0].args.slice(0, 3), ['shell', 'input', 'swipe']);
  assert.deepEqual(commands[0].args.slice(3, 7), ['60', '120', '60', '120']);
  assert.ok(Number(commands[0].args[7]) >= 650);
  assert.equal(commands[0].options.safeCode, 'ui_long_press_failed');
});

test('offline request replaces the composer with one fixed shell-safe value', () => {
  const commands = offlineQuestionInputCommands();
  assert.equal(commands.length, 3);
  assert.deepEqual(commands[0], [
    'shell',
    'input',
    'keycombination',
    'KEYCODE_CTRL_LEFT',
    'KEYCODE_A',
  ]);
  assert.deepEqual(commands[1], [
    'shell',
    'input',
    'keyevent',
    'KEYCODE_DEL',
  ]);
  assert.deepEqual(commands[2].slice(0, 3), ['shell', 'input', 'text']);
  assert.match(commands[2][3], /^[A-Za-z0-9.%]+$/);
  assert.ok(commands[2][3].includes('%s'));
});

test('external process polling proves changed start and full stop without logging a PID', async () => {
  const startStates = [null, '100', '200'];
  assert.equal(
    await waitForExternalAppState({
      readPid: async () => startStates.shift(),
      state: 'started',
      previousPid: '100',
      timeoutMs: 30,
      pollIntervalMs: 10,
      waitImpl: async () => {},
    }),
    '200',
  );
  const stopStates = ['200', null];
  assert.equal(
    await waitForExternalAppState({
      readPid: async () => stopStates.shift(),
      state: 'stopped',
      timeoutMs: 20,
      pollIntervalMs: 10,
      waitImpl: async () => {},
    }),
    true,
  );
});

test('shared bounded process waiter preserves ordering, timeout, and safe errors', async () => {
  const waits = [];
  const errorForCode = (code) => {
    const error = new Error('safe');
    error.safeCode = code;
    return error;
  };
  const { waitForExternalProcessState } =
    createBoundedExternalProcessWaiter({
      defaultPollIntervalMs: 500,
      defaultWaitImpl: async (milliseconds) => waits.push(milliseconds),
      errorForCode,
    });
  const states = ['100', '100', '200'];
  assert.equal(
    await waitForExternalProcessState({
      readPid: async () => states.shift(),
      state: 'started',
      previousPid: '100',
      timeoutMs: 1_000,
    }),
    '200',
  );
  assert.deepEqual(waits, [500, 500]);

  let timeoutReads = 0;
  await assert.rejects(
    waitForExternalProcessState({
      readPid: async () => {
        timeoutReads += 1;
        return '100';
      },
      state: 'started',
      previousPid: '100',
      timeoutMs: 1_000,
      waitImpl: async () => {},
    }),
    (error) => error.safeCode === 'external_plain_run_not_observed',
  );
  assert.equal(timeoutReads, 3);
  await assert.rejects(
    waitForExternalProcessState({
      readPid: async () => 'PID_SENTINEL',
      state: 'started',
      timeoutMs: 500,
    }),
    (error) => error.safeCode === 'process_state_invalid',
  );

  const smallTalkSource = fs.readFileSync(
    `${__dirname}/android_appcheck_smalltalk_acceptance_support.cjs`,
    'utf8',
  );
  const plainRunSource = fs.readFileSync(
    `${__dirname}/android_plain_flutter_run_acceptance_support.cjs`,
    'utf8',
  );
  assert.doesNotMatch(
    smallTalkSource,
    /async function waitForExternalAppState\(/,
  );
  assert.doesNotMatch(
    plainRunSource,
    /async function waitForExternalProcessState\(/,
  );
});

test('network-state join waits for proven offline and online reachability', async () => {
  const offline = [true, true, false];
  const online = [false, true];
  let waits = 0;

  assert.equal(
    await waitForDeviceNetworkState('emulator-5554', false, {
      probe: async () => offline.shift(),
      waitImpl: async () => {
        waits += 1;
      },
      timeoutMs: 5_000,
    }),
    true,
  );
  assert.equal(
    await waitForDeviceNetworkState('emulator-5554', true, {
      probe: async () => online.shift(),
      waitImpl: async () => {
        waits += 1;
      },
      timeoutMs: 5_000,
    }),
    true,
  );
  assert.equal(waits, 3);
});

test('network-state join fails closed when reachability never changes', async () => {
  let now = 0;
  const originalNow = Date.now;
  Date.now = () => (now += 1_000);
  try {
    await assert.rejects(
      () =>
        waitForDeviceNetworkState('emulator-5554', false, {
          probe: async () => true,
          waitImpl: async () => {},
          timeoutMs: 2_000,
        }),
      (error) => error.safeCode === 'network_offline_not_proven',
    );
  } finally {
    Date.now = originalNow;
  }
});

test('retry observer proves same failed user plus exactly one settled assistant', async () => {
  const states = [
    { phase: 'sending', messageCount: 7 },
    { phase: 'answer_complete', messageCount: 8 },
    { phase: 'answer_complete', messageCount: 8 },
    { phase: 'answer_complete', messageCount: 8 },
  ];
  const proof = await observeOfflineRetryCompletion({
    failureMessageCount: 8,
    readState: async () => states.shift(),
    waitImpl: async () => {},
    timeoutMs: 1_000,
    now: () => 1,
  });
  assert.deepEqual(proof, {
    sendingObserved: true,
    answerCompleted: true,
    reusedUserMessage: true,
    assistantMessageDelta: 1,
    totalMessageDelta: 2,
    duplicateResponse: false,
  });
  await assert.rejects(
    observeOfflineRetryCompletion({
      failureMessageCount: 8,
      readState: async () => ({ phase: 'answer_complete', messageCount: 9 }),
      waitImpl: async () => {},
      timeoutMs: 1_000,
      now: () => 1,
    }),
    (error) => error.safeCode === 'offline_retry_duplicate_response_observed',
  );
});

test('gateway trace validator requires zero local calls and one successful Groq remote call', () => {
  assert.deepEqual(validateTraceExpectation([], 0), {
    traceCount: 0,
    httpStatus: 'none',
    provider: 'none',
    model: 'none',
  });
  const successfulTrace = {
    revision: 'cashpilot-ai-gateway-staging-00005-civ',
    selectedModelAlias: 'general-primary',
    selectedModel: 'openai/gpt-oss-20b',
    upstreamHttpStatusCategory: 'success',
    finalCode: 'completed',
    statusCode: 200,
    durationMs: 25,
    retryCount: 0,
  };
  assert.deepEqual(validateTraceExpectation([successfulTrace], 1), {
    traceCount: 1,
    httpStatus: 200,
    provider: 'groq',
    model: 'general20b',
    revision: successfulTrace.revision,
  });
  assert.throws(
    () => validateTraceExpectation([successfulTrace], 0),
    (error) => error.safeCode === 'gateway_duplicate_request_observed',
  );
});

test('logging query is bounded and never emits its credential or raw response', async () => {
  const requests = [];
  const accessToken = 'CLOUD_ACCESS_TOKEN_SENTINEL';
  const entries = await listSafeGatewayTraces({
    accessToken,
    window: {
      startedAt: '2026-08-15T10:00:00.000Z',
      endedAt: '2026-08-15T10:01:00.000Z',
    },
    fetchImpl: async (url, init) => {
      requests.push({ url, init });
      return {
        ok: true,
        async json() {
          return {};
        },
      };
    },
  });
  assert.deepEqual(entries, []);
  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].url,
    'https://logging.googleapis.com/v2/entries:list',
  );
  assert.doesNotMatch(requests[0].url, /textPayload|protoPayload|httpRequest/);
  const body = JSON.parse(requests[0].init.body);
  assert.equal(body.pageSize, 20);
  assert.match(body.filter, /cashpilot-ai-gateway-staging/);
  assert.doesNotMatch(JSON.stringify(body), new RegExp(accessToken));
});

test('logging evidence backs off once after a safe 429 and remains bounded', async () => {
  let queries = 0;
  const waits = [];
  const proof = await verifyGatewayTraceWindow({
    accessToken: 'ACCESS_TOKEN_SENTINEL_DO_NOT_LOG',
    window: {
      startedAt: '2026-08-15T10:00:00.000Z',
      endedAt: '2026-08-15T10:01:00.000Z',
    },
    expectedCount: 0,
    queryImpl: async () => {
      queries += 1;
      if (queries === 1) {
        const error = new Error('safe');
        error.safeCode = 'gateway_trace_http_429';
        throw error;
      }
      return [];
    },
    waitImpl: async (milliseconds) => waits.push(milliseconds),
    initialDelayMs: 0,
    retryDelayMs: 0,
    rateLimitDelayMs: 7,
    settleDelayMs: 0,
    maximumQueries: 4,
  });
  assert.equal(proof.traceCount, 0);
  assert.equal(queries, 3);
  assert.deepEqual(waits, [0, 7, 0]);
});

test('logging evidence also backs off when the settle query is rate limited', async () => {
  let queries = 0;
  const waits = [];
  const proof = await verifyGatewayTraceWindow({
    accessToken: 'ACCESS_TOKEN_SENTINEL_DO_NOT_LOG',
    window: {
      startedAt: '2026-08-15T10:00:00.000Z',
      endedAt: '2026-08-15T10:01:00.000Z',
    },
    expectedCount: 0,
    queryImpl: async () => {
      queries += 1;
      if (queries === 2) {
        const error = new Error('safe');
        error.safeCode = 'gateway_trace_http_429';
        throw error;
      }
      return [];
    },
    waitImpl: async (milliseconds) => waits.push(milliseconds),
    initialDelayMs: 0,
    retryDelayMs: 0,
    rateLimitDelayMs: 7,
    settleDelayMs: 0,
    maximumQueries: 4,
  });
  assert.equal(proof.traceCount, 0);
  assert.equal(queries, 4);
  assert.deepEqual(waits, [0, 0, 7, 0]);
});

test('successful orchestration proves the exact sequence and critical cleanup safely', async () => {
  const { adapter, calls, coordinator, sensitive, traceExpectations } =
    createFakeHarness();
  const logs = [];
  const result = await executeAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 0);
  assert.deepEqual(traceExpectations, [0, 1, 1, 1, 0, 1]);
  assert.ok(calls.indexOf('small-talk') < calls.indexOf('remote-0'));
  assert.ok(calls.indexOf('remote-0') < calls.indexOf('trace-1-0'));
  assert.ok(calls.indexOf('remote-0') < calls.indexOf('settings-verify'));
  assert.ok(calls.indexOf('settings-verify') < calls.indexOf('settings-live'));
  assert.ok(calls.indexOf('settings-live') < calls.indexOf('force-stop'));
  assert.ok(calls.indexOf('force-stop') < calls.indexOf('launcher'));
  assert.ok(calls.indexOf('launcher') < calls.indexOf('remote-1'));
  assert.ok(calls.indexOf('remote-1') < calls.indexOf('network-offline'));
  assert.ok(calls.indexOf('offline-submit') < calls.indexOf('retry'));
  assert.ok(calls.indexOf('logout') < calls.indexOf('delete-profile'));
  assert.ok(calls.indexOf('delete-profile') < calls.indexOf('delete-user'));
  assert.ok(calls.indexOf('delete-user') < calls.indexOf('external-stop'));
  assert.equal(
    calls.filter((call) => call.startsWith('FORBIDDEN-')).length,
    0,
  );
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_READY_RUN action=startLiteralFlutterRun device=emulator-5554 plainCommand=true noDefines=true noWrapper=true/,
  );
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_SMALL_TALK .*messageDelta=2 duplicateResponse=false appCheckPathEntered=false cloudTraceCount=0/,
  );
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_COLD_REMOTE .*gatewayCalls=1 provider=groq model=general20b httpStatus=200 firebaseFallback=false/,
  );
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_RETRY reusedUserMessage=true answerCompleted=true assistantMessageDelta=1 totalMessageDelta=2 duplicateResponse=false gatewayCalls=1/,
  );
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_READY_STOP action=sendQToFlutterRun reason=workflow accountCleanup=complete packagePreserved=true/,
  );
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_RESULT completed=true .*externalStop=true cleanup=true .*noAppCheckMutation=true/,
  );
  for (const value of Object.values(sensitive)) {
    assert.ok(!output.includes(value));
  }
  assert.doesNotMatch(output, /<hierarchy>|\b(?:pid|oldPid|newPid)=/i);
});

test('workflow failure still deletes synthetic profile/user and requests external stop once', async () => {
  const { adapter, calls, coordinator, sensitive } = createFakeHarness({
    smallTalkFails: true,
  });
  const logs = [];
  const result = await executeAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'small_talk_completion_not_proven');
  assert.ok(calls.includes('logout'));
  assert.ok(calls.includes('delete-profile'));
  assert.ok(calls.includes('delete-user'));
  assert.equal(calls.filter((call) => call === 'external-stop').length, 1);
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_READY_STOP .*reason=failure accountCleanup=complete/,
  );
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_FAILURE stage=small_talk code=small_talk_completion_not_proven/,
  );
  for (const value of Object.values(sensitive)) {
    assert.ok(!output.includes(value));
  }
});

test('external Flutter stop failure is critical and reflected only as a safe code', async () => {
  const { adapter, coordinator } = createFakeHarness({ externalStopFails: true });
  const logs = [];
  const result = await executeAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'external_plain_run_not_stopped');
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_STOP_FAILURE code=external_plain_run_not_stopped/,
  );
  assert.match(
    output,
    /ANDROID_APPCHECK_SMALLTALK_RESULT completed=false .*externalStop=false cleanup=false/,
  );
  assert.doesNotMatch(output, /EXTERNAL_STOP_SENTINEL_DO_NOT_LOG/);
});

test('marker serializer fails closed instead of reflecting unsafe text', () => {
  assert.throws(
    () => emitSafeMarker(() => {}, 'SAFE', { value: 'unsafe value' }),
    (error) => error.safeCode === 'unsafe_marker_value',
  );
  assert.throws(
    () => emitSafeMarker(() => {}, 'bad-name', { value: true }),
    (error) => error.safeCode === 'unsafe_marker_contract',
  );
});
