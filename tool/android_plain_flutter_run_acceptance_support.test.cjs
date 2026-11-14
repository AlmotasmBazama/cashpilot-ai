'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  emitPlainMarker,
  executePlainFlutterAcceptance,
  parsePlainRunArguments,
  waitForExternalProcessState,
} = require('./android_plain_flutter_run_acceptance_support.cjs');
const {
  approvedGatewayHost,
  settingsRequiredResourceIds,
} = require('./android_live_groq_force_stop_support.cjs');

const primaryGatewayUrl = `https://${approvedGatewayHost}`;

function liveOptions() {
  return parsePlainRunArguments([
    '--execute-live',
    '--promotion-confirmed',
    '--dedicated-device',
    '--plain-runs-confirmed',
    '--no-build-install-confirmed',
    '--gateway-url',
    primaryGatewayUrl,
    '--run-wait-seconds',
    '30',
  ]);
}

function settingsProof({ restored = false } = {}) {
  return {
    rowsVerified: true,
    rowCount: settingsRequiredResourceIds.length,
    testStatus: 'idle',
    ...(restored
      ? {
          restoredSession: true,
          settingsReopened: true,
          dynamicStatusObserved: true,
        }
      : {}),
  };
}

function createFakeHarness({
  appCheckExisting = true,
  priorSession = true,
  authNormalizeFails = false,
  syntheticCreateFails = false,
  initialLogoutFails = false,
  cleanupAuthRetrySucceeds = true,
  userDeleteSucceeds = true,
  loginFails = false,
  runOneSettingsFails = false,
  runTwoSettingsFails = false,
  externalStopFailsAt = null,
  finalPackageInstalled = true,
} = {}) {
  const calls = [];
  const settingsBaselines = [];
  let feasibilityReads = 0;
  let settingsReads = 0;
  let restoredSettingsReads = 0;
  let startReads = 0;
  let stopReads = 0;
  let normalizeReads = 0;
  let logoutReads = 0;
  const sensitive = Object.freeze({
    accessToken: 'TOKEN_SENTINEL_DO_NOT_LOG',
    apiKey: 'API_KEY_SENTINEL_DO_NOT_LOG',
    localId: 'UID_SENTINEL_DO_NOT_LOG',
    email: 'EMAIL_SENTINEL_DO_NOT_LOG@example.com',
    password: 'PASSWORD_SENTINEL_DO_NOT_LOG',
    resourceName: 'RESOURCE_SENTINEL_DO_NOT_LOG',
  });

  const adapter = {
    async inspectFeasibility() {
      calls.push('inspect');
      feasibilityReads += 1;
      return {
        adbAvailable: true,
        deviceAvailable: true,
        flutterAvailable: true,
        packageInstalled:
          feasibilityReads === 1 ? true : finalPackageInstalled,
        uiDriverAvailable: true,
      };
    },
    async verifyGatewayHealth() {
      calls.push('health');
    },
    async loadCloudCredentials() {
      calls.push('cloud');
      return { accessToken: sensitive.accessToken, apiKey: sensitive.apiKey };
    },
    async createSyntheticUser() {
      calls.push('create-user');
      if (syntheticCreateFails) {
        const error = new Error('SYNTHETIC_CREATE_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'synthetic_user_create_failed';
        throw error;
      }
      return {
        localId: sensitive.localId,
        email: sensitive.email,
        password: sensitive.password,
      };
    },
    async getPid() {
      calls.push('get-bootstrap-pid');
      return '100';
    },
    async registerAppCheck() {
      calls.push('register-app-check');
      return appCheckExisting
        ? { existing: true, resourceCreated: false }
        : {
            existing: false,
            resourceCreated: true,
            resourceName: sensitive.resourceName,
          };
    },
    async normalizeSignedOut() {
      normalizeReads += 1;
      calls.push(
        normalizeReads === 1
          ? 'normalize-prior-auth'
          : 'normalize-cleanup-auth',
      );
      if (normalizeReads === 1 && authNormalizeFails) {
        const error = new Error('PRIOR_AUTH_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'prior_auth_logout_failed';
        throw error;
      }
      if (normalizeReads > 1 && !cleanupAuthRetrySucceeds) {
        const error = new Error('CLEANUP_AUTH_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'prior_auth_logout_failed';
        throw error;
      }
      return {
        signedOut: true,
        priorSession: normalizeReads === 1 ? priorSession : true,
      };
    },
    async forceStop() {
      calls.push('force-stop');
    },
    async waitForStopped() {
      calls.push('wait-owned-stop');
      return true;
    },
    async reachLoginScreen() {
      calls.push('reach-login');
    },
    async login() {
      calls.push('login');
      if (loginFails) {
        const error = new Error('AUTH_FAILURE_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'ui_login_failure_permission_denied';
        throw error;
      }
    },
    async openAi(_deviceId, options) {
      calls.push(options?.requireRestoredSession ? 'open-ai-restored' : 'open-ai');
    },
    async askQuestion(_deviceId, index) {
      calls.push(`ask-${index}`);
      return {
        sendingObserved: true,
        answerCompleted: true,
        messageDelta: 2,
        duplicateResponse: false,
      };
    },
    async verifySettings() {
      settingsReads += 1;
      calls.push(`settings-${settingsReads}`);
      if (runOneSettingsFails && settingsReads === 1) {
        const error = new Error('UI_XML_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'settings_rows_incomplete';
        throw error;
      }
      return settingsProof();
    },
    async runSettingsLiveTest(_deviceId, baseline) {
      settingsBaselines.push(baseline);
      calls.push(`settings-live-${settingsBaselines.length}`);
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
      calls.push('wait-owned-start');
      return '300';
    },
    async verifyRestoredSettings() {
      restoredSettingsReads += 1;
      calls.push(`settings-restored-${restoredSettingsReads}`);
      if (runTwoSettingsFails && restoredSettingsReads === 2) {
        const error = new Error('RUN_TWO_UI_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'settings_rows_incomplete';
        throw error;
      }
      return settingsProof({ restored: true });
    },
    async navigateToDashboard() {
      calls.push('dashboard');
    },
    async logout() {
      calls.push('logout');
      logoutReads += 1;
      return !(initialLogoutFails && logoutReads === 1);
    },
    async deleteSyntheticProfile() {
      calls.push('delete-profile');
      return true;
    },
    async deleteSyntheticUser() {
      calls.push('delete-user');
      return userDeleteSucceeds;
    },
    async deleteAppCheckRegistration() {
      calls.push('delete-app-check');
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
      throw new Error('build must never run');
    },
    async uninstall() {
      calls.push('FORBIDDEN-uninstall');
      throw new Error('uninstall must never run');
    },
  };
  const coordinator = {
    async waitForStarted(_deviceId, previousPid) {
      startReads += 1;
      calls.push(`external-start-${startReads}`);
      assert.equal(previousPid, startReads === 1 ? '100' : '300');
      return startReads === 1 ? '200' : '400';
    },
    async waitForStopped() {
      stopReads += 1;
      calls.push(`external-stop-${stopReads}`);
      if (externalStopFailsAt === stopReads) {
        const error = new Error('STOP_SENTINEL_DO_NOT_LOG');
        error.safeCode = 'external_plain_run_not_stopped';
        throw error;
      }
      return true;
    },
  };
  return { adapter, calls, coordinator, sensitive, settingsBaselines };
}

test('plain harness defaults to a read-only dry run', async () => {
  const options = parsePlainRunArguments([]);
  const { adapter, calls, coordinator } = createFakeHarness();
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options,
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 0);
  assert.equal(result.liveExecuted, false);
  assert.deepEqual(calls, ['inspect']);
  assert.match(
    logs.join('\n'),
    /ANDROID_PLAIN_RUN_RESULT completed=false dryRun=true noBuild=true noInstall=true noUninstall=true/,
  );
});

test('live mode requires every explicit plain-run safety gate', () => {
  const requiredFlags = [
    '--promotion-confirmed',
    '--dedicated-device',
    '--plain-runs-confirmed',
    '--no-build-install-confirmed',
  ];
  for (const omitted of requiredFlags) {
    assert.throws(
      () =>
        parsePlainRunArguments([
          '--execute-live',
          ...requiredFlags.filter((flag) => flag !== omitted),
          '--gateway-url',
          primaryGatewayUrl,
        ]),
      (error) => error.safeCode === 'live_confirmation_incomplete',
    );
  }
  assert.equal(liveOptions().executeLive, true);
});

test('only the dedicated emulator and stable origin are accepted', () => {
  assert.throws(
    () => parsePlainRunArguments(['--device', 'emulator-5556']),
    (error) => error.safeCode === 'dedicated_emulator_required',
  );
  assert.throws(
    () =>
      parsePlainRunArguments([
        '--gateway-url',
        'https://groq-candidate---cashpilot-ai-gateway-staging-yfgt2ypuvq-ew.a.run.app',
      ]),
    (error) => error.safeCode === 'candidate_tag_forbidden',
  );
  assert.throws(
    () =>
      parsePlainRunArguments([
        '--gateway-url',
        'https://example.test',
      ]),
    (error) => error.safeCode === 'primary_gateway_host_required',
  );
});

test('manual coordination timeout is bounded', () => {
  assert.throws(
    () => parsePlainRunArguments(['--run-wait-seconds', '29']),
    (error) => error.safeCode === 'run_wait_invalid',
  );
  assert.throws(
    () => parsePlainRunArguments(['--run-wait-seconds=3601']),
    (error) => error.safeCode === 'run_wait_invalid',
  );
  assert.equal(liveOptions().runWaitMs, 30_000);
});

test('external process poll proves start/change and stop without exposing PID', async () => {
  const startStates = [null, '100', '200'];
  const waits = [];
  const started = await waitForExternalProcessState({
    readPid: async () => startStates.shift(),
    state: 'started',
    previousPid: '100',
    timeoutMs: 30,
    pollIntervalMs: 10,
    waitImpl: async (milliseconds) => waits.push(milliseconds),
  });
  assert.equal(started, '200');
  assert.deepEqual(waits, [10, 10]);

  const stopStates = ['200', null];
  assert.equal(
    await waitForExternalProcessState({
      readPid: async () => stopStates.shift(),
      state: 'stopped',
      timeoutMs: 20,
      pollIntervalMs: 10,
      waitImpl: async () => {},
    }),
    true,
  );
});

test('external process poll fails closed on timeout or malformed state', async () => {
  await assert.rejects(
    waitForExternalProcessState({
      readPid: async () => '100',
      state: 'started',
      previousPid: '100',
      timeoutMs: 20,
      pollIntervalMs: 10,
      waitImpl: async () => {},
    }),
    (error) => error.safeCode === 'external_plain_run_not_observed',
  );
  await assert.rejects(
    waitForExternalProcessState({
      readPid: async () => 'PID_SENTINEL',
      state: 'started',
      timeoutMs: 20,
      pollIntervalMs: 10,
      waitImpl: async () => {},
    }),
    (error) => error.safeCode === 'process_state_invalid',
  );
});

test('successful orchestration coordinates two external runs without build/install/uninstall', async () => {
  const { adapter, calls, coordinator, sensitive, settingsBaselines } =
    createFakeHarness();
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 0);
  assert.deepEqual(settingsBaselines, ['idle', 'idle']);
  assert.deepEqual(calls, [
    'inspect',
    'health',
    'cloud',
    'create-user',
    'get-bootstrap-pid',
    'register-app-check',
    'force-stop',
    'wait-owned-stop',
    'external-start-1',
    'normalize-prior-auth',
    'reach-login',
    'login',
    'open-ai',
    'ask-0',
    'settings-1',
    'settings-live-1',
    'external-stop-1',
    'launcher',
    'wait-owned-start',
    'settings-restored-1',
    'dashboard',
    'open-ai-restored',
    'ask-1',
    'settings-2',
    'force-stop',
    'wait-owned-stop',
    'external-start-2',
    'settings-restored-2',
    'settings-live-2',
    'logout',
    'delete-profile',
    'delete-user',
    'external-stop-2',
    'clear-ui-dump',
    'clear-logs',
    'inspect',
  ]);
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_READY_RUN run=1 action=startLiteralFlutterRun plainCommand=true noDefines=true noBuild=true noInstall=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_PREP syntheticCreated=true profileCreated=true appCheckExisting=true appCheckCreated=false packagePreserved=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_AUTH_NORMALIZED run=1 signedOut=true priorSessionPresent=true resourceIdOnly=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_FIRST promptClass=arabicInflation inputMode=oneShotHook prefilled=false sendingObserved=true answerCompleted=true messageDelta=2 duplicateResponse=false/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_READY_STOP run=1 action=sendQToFlutterRun reason=workflow accountCleanup=pending packagePreserved=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_SECOND restoredSession=true inputMode=replace questionClass=englishSavingHabits/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_READY_RUN run=2 action=startLiteralFlutterRun/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_SETTINGS run=2 restoredSession=true settingsRestored=true rowsVerified=true rowCount=11 baselineIdle=true testingObserved=true stateMachineOrdered=true availableObserved=true liveGroq=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_READY_STOP run=2 action=sendQToFlutterRun reason=workflow accountCleanup=complete packagePreserved=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_RESULT completed=true firstChat=true run1Settings=true run1Stopped=true launcherReopen=true secondChat=true run2Settings=true run2Stopped=true externalStops=true cleanup=true noBuild=true noInstall=true noUninstall=true/,
  );
  for (const value of Object.values(sensitive)) {
    assert.ok(!output.includes(value));
  }
  assert.doesNotMatch(
    output,
    /<hierarchy>|Give me three|ط§ط´ط±ط­|\b(?:100|200|300|400)\b/,
  );
  assert.ok(!calls.some((call) => call.startsWith('FORBIDDEN-')));
  assert.ok(!calls.includes('delete-app-check'));
  assert.equal(calls.filter((call) => call === 'logout').length, 1);
  assert.equal(
    calls.filter((call) => call === 'normalize-cleanup-auth').length,
    0,
  );
  assert.equal(
    logs.filter((line) => line.startsWith('ANDROID_PLAIN_RUN_READY_STOP '))
      .length,
    2,
  );
});

test('a harness-created App Check registration is deleted after run two', async () => {
  const { adapter, calls, coordinator } = createFakeHarness({
    appCheckExisting: false,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 0);
  assert.equal(calls.filter((call) => call === 'delete-app-check').length, 1);
  assert.match(
    logs.join('\n'),
    /ANDROID_PLAIN_RUN_ACCOUNT_CLEANUP .*appCheckPreserved=false appCheckDeleteAttempted=true appCheckDeleted=true complete=true/,
  );
});

test('already signed-out Auth is normalized without claiming a prior session', async () => {
  const { adapter, coordinator } = createFakeHarness({ priorSession: false });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 0);
  assert.match(
    logs.join('\n'),
    /ANDROID_PLAIN_RUN_AUTH_NORMALIZED run=1 signedOut=true priorSessionPresent=false resourceIdOnly=true/,
  );
});

test('synthetic user creation failure is content-blind and leaves no remote cleanup target', async () => {
  const { adapter, calls, coordinator } = createFakeHarness({
    syntheticCreateFails: true,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'synthetic_user_create_failed');
  assert.ok(calls.includes('create-user'));
  assert.ok(!calls.includes('register-app-check'));
  assert.ok(!calls.includes('delete-profile'));
  assert.ok(!calls.includes('delete-user'));
  assert.ok(!calls.includes('force-stop'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_FAILURE stage=synthetic_auth_create code=synthetic_user_create_failed/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_CLEANUP .*profileDeleteAttempted=false .*userDeleteAttempted=false .*complete=true/,
  );
  assert.doesNotMatch(output, /SYNTHETIC_CREATE_SENTINEL_DO_NOT_LOG/);
});

test('run-one Auth normalization failure requests q and performs critical cleanup', async () => {
  const { adapter, calls, coordinator } = createFakeHarness({
    appCheckExisting: false,
    authNormalizeFails: true,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'prior_auth_logout_failed');
  assert.ok(calls.includes('delete-profile'));
  assert.ok(calls.includes('delete-user'));
  assert.ok(calls.includes('delete-app-check'));
  assert.ok(calls.includes('external-start-1'));
  assert.ok(calls.includes('external-stop-1'));
  assert.ok(!calls.includes('reach-login'));
  const output = logs.join('\n');
  assert.match(output, /ANDROID_PLAIN_RUN_READY_RUN run=1 /);
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_READY_STOP run=1 action=sendQToFlutterRun reason=failure accountCleanup=complete packagePreserved=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_CLEANUP .*appCheckDeleteAttempted=true appCheckDeleted=true externalStopsComplete=true .*complete=true/,
  );
  assert.doesNotMatch(output, /PRIOR_AUTH_SENTINEL_DO_NOT_LOG/);
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_FAILURE stage=run1_auth_normalize code=prior_auth_logout_failed run1Active=false run2Active=false/,
  );
  assert.equal(
    logs.filter((line) =>
      line.startsWith('ANDROID_PLAIN_RUN_READY_STOP run=1 '),
    ).length,
    1,
  );
  const readyRunIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_READY_RUN run=1 '),
  );
  const readyStopIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_READY_STOP run=1 '),
  );
  const cleanupIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_CLEANUP '),
  );
  assert.ok(readyRunIndex >= 0 && readyRunIndex < readyStopIndex);
  assert.ok(readyStopIndex < cleanupIndex);
});

test('login outcome failure arms logout cleanup before shell proof', async () => {
  const { adapter, calls, coordinator, sensitive } = createFakeHarness({
    loginFails: true,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'ui_login_failure_permission_denied');
  assert.ok(calls.includes('login'));
  assert.ok(calls.includes('logout'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_CLEANUP logoutRequired=true logoutAttempted=true .*signedOut=true signedOutConfirmed=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_FAILURE stage=run1_login code=ui_login_failure_permission_denied /,
  );
  assert.doesNotMatch(output, /AUTH_FAILURE_SENTINEL_DO_NOT_LOG/);
  for (const value of Object.values(sensitive)) {
    assert.ok(!output.includes(value));
  }
});

test('run-one Settings failure emits only safe failure data and performs cleanup', async () => {
  const { adapter, calls, coordinator, sensitive } = createFakeHarness({
    runOneSettingsFails: true,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'settings_rows_incomplete');
  assert.ok(calls.includes('logout'));
  assert.ok(calls.includes('delete-profile'));
  assert.ok(calls.includes('delete-user'));
  assert.ok(calls.includes('external-stop-1'));
  assert.ok(!calls.includes('external-start-2'));
  assert.ok(!calls.some((call) => call.startsWith('FORBIDDEN-')));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_FAILURE stage=run1_settings code=settings_rows_incomplete run1Active=false run2Active=false/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_READY_STOP run=1 action=sendQToFlutterRun reason=failure accountCleanup=complete packagePreserved=true/,
  );
  assert.equal(
    logs.filter((line) => line.startsWith('ANDROID_PLAIN_RUN_READY_STOP '))
      .length,
    1,
  );
  const readyStopIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_READY_STOP '),
  );
  const cleanupIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_CLEANUP '),
  );
  const failureIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_FAILURE '),
  );
  assert.ok(readyStopIndex >= 0 && readyStopIndex < cleanupIndex);
  assert.ok(cleanupIndex < failureIndex);
  assert.doesNotMatch(output, /UI_XML_SENTINEL_DO_NOT_LOG/);
  for (const value of Object.values(sensitive)) {
    assert.ok(!output.includes(value));
  }
});

test('run-two active failure requests q once, waits, then reports safe cleanup', async () => {
  const { adapter, calls, coordinator, sensitive } = createFakeHarness({
    runTwoSettingsFails: true,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'settings_rows_incomplete');
  assert.ok(calls.includes('external-start-2'));
  assert.ok(calls.includes('external-stop-2'));
  assert.ok(calls.indexOf('logout') < calls.indexOf('external-stop-2'));
  assert.ok(calls.indexOf('delete-user') < calls.indexOf('external-stop-2'));
  assert.ok(!calls.some((call) => call.startsWith('FORBIDDEN-')));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_READY_STOP run=2 action=sendQToFlutterRun reason=failure accountCleanup=complete packagePreserved=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_CLEANUP .*externalStopsComplete=true .*complete=true/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_FAILURE stage=run2_settings_restore code=settings_rows_incomplete run1Active=false run2Active=false/,
  );
  assert.equal(
    logs.filter((line) =>
      line.startsWith('ANDROID_PLAIN_RUN_READY_STOP run=1 '),
    ).length,
    1,
  );
  assert.equal(
    logs.filter((line) =>
      line.startsWith('ANDROID_PLAIN_RUN_READY_STOP run=2 '),
    ).length,
    1,
  );
  const runTwoStopIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_READY_STOP run=2 '),
  );
  const cleanupIndex = logs.findIndex((line) =>
    line.startsWith('ANDROID_PLAIN_RUN_CLEANUP '),
  );
  assert.ok(runTwoStopIndex >= 0 && runTwoStopIndex < cleanupIndex);
  assert.doesNotMatch(output, /RUN_TWO_UI_SENTINEL_DO_NOT_LOG/);
  for (const value of Object.values(sensitive)) {
    assert.ok(!output.includes(value));
  }
});

test('an external stop timeout is a critical cleanup failure', async () => {
  const { adapter, coordinator } = createFakeHarness({
    runOneSettingsFails: true,
    externalStopFailsAt: 1,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_STOP_FAILURE run=1 code=external_plain_run_not_stopped/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_CLEANUP .*externalStopsComplete=false .*complete=false/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_RESULT completed=false .*run1Stopped=false .*externalStops=false cleanup=false/,
  );
  assert.doesNotMatch(output, /STOP_SENTINEL_DO_NOT_LOG/);
  assert.equal(
    logs.filter((line) =>
      line.startsWith('ANDROID_PLAIN_RUN_READY_STOP run=1 '),
    ).length,
    1,
  );
});

test('failed initial logout retries only after remote profile and user deletion', async () => {
  const { adapter, calls, coordinator } = createFakeHarness({
    initialLogoutFails: true,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 0);
  const initialLogoutIndex = calls.indexOf('logout');
  const profileDeleteIndex = calls.indexOf('delete-profile');
  const userDeleteIndex = calls.indexOf('delete-user');
  const retryIndex = calls.indexOf('normalize-cleanup-auth');
  assert.ok(initialLogoutIndex >= 0 && initialLogoutIndex < profileDeleteIndex);
  assert.ok(profileDeleteIndex < userDeleteIndex);
  assert.ok(userDeleteIndex < retryIndex);
  assert.equal(calls.filter((call) => call === 'logout').length, 1);
  assert.equal(
    calls.filter((call) => call === 'normalize-cleanup-auth').length,
    1,
  );
  assert.match(
    logs.join('\n'),
    /ANDROID_PLAIN_RUN_ACCOUNT_CLEANUP logoutAttempted=true logoutRetryAttempted=true signedOut=true signedOutConfirmed=true .*complete=true/,
  );
});

test('failed logout confirmation remains a critical cleanup failure', async () => {
  const { adapter, calls, coordinator } = createFakeHarness({
    initialLogoutFails: true,
    cleanupAuthRetrySucceeds: false,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'cleanup_incomplete');
  assert.equal(
    calls.filter((call) => call === 'normalize-cleanup-auth').length,
    1,
  );
  assert.ok(calls.indexOf('delete-user') < calls.indexOf('normalize-cleanup-auth'));
  assert.ok(calls.includes('external-stop-2'));
  const output = logs.join('\n');
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_ACCOUNT_CLEANUP logoutAttempted=true logoutRetryAttempted=true signedOut=false signedOutConfirmed=false .*complete=false/,
  );
  assert.match(
    output,
    /ANDROID_PLAIN_RUN_RESULT completed=false .*externalStops=true cleanup=false/,
  );
  assert.doesNotMatch(output, /CLEANUP_AUTH_SENTINEL_DO_NOT_LOG/);
});

test('critical user cleanup failure fails acceptance after requesting run-two q', async () => {
  const { adapter, calls, coordinator } = createFakeHarness({
    userDeleteSucceeds: false,
  });
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'cleanup_incomplete');
  assert.ok(calls.includes('external-stop-2'));
  assert.match(
    logs.join('\n'),
    /ANDROID_PLAIN_RUN_READY_STOP run=2 action=sendQToFlutterRun reason=workflow accountCleanup=incomplete/,
  );
  assert.match(
    logs.join('\n'),
    /ANDROID_PLAIN_RUN_RESULT completed=false .*cleanup=false noBuild=true noInstall=true noUninstall=true/,
  );
});

test('missing installed package fails before credentials or mutation', async () => {
  const { adapter, calls, coordinator } = createFakeHarness();
  adapter.inspectFeasibility = async () => {
    calls.push('inspect-missing');
    return {
      adbAvailable: true,
      deviceAvailable: true,
      flutterAvailable: true,
      packageInstalled: false,
      uiDriverAvailable: true,
    };
  };
  const logs = [];

  const result = await executePlainFlutterAcceptance({
    options: liveOptions(),
    adapter,
    coordinator,
    log: (line) => logs.push(line),
  });

  assert.equal(result.exitCode, 1);
  assert.equal(result.failureCode, 'plain_preflight_unavailable');
  assert.ok(!calls.includes('cloud'));
  assert.ok(!calls.some((call) => call.startsWith('FORBIDDEN-')));
  assert.match(
    logs.join('\n'),
    /ANDROID_PLAIN_RUN_FAILURE stage=preflight code=plain_preflight_unavailable/,
  );
});

test('marker serializer rejects unsafe fields rather than reflecting content', () => {
  assert.throws(
    () => emitPlainMarker(() => {}, 'SAFE', { value: 'unsafe value' }),
    (error) => error.safeCode === 'unsafe_marker_value',
  );
  assert.throws(
    () => emitPlainMarker(() => {}, 'bad-name', { value: true }),
    (error) => error.safeCode === 'unsafe_marker_contract',
  );
});
