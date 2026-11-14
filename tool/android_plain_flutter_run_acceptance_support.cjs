'use strict';

const {
  approvedGatewayHost,
  createProductionAdapter,
  proveProcessRestart,
  settingsRequiredResourceIds,
} = require('./android_cashpilot_acceptance_support.cjs');
const {
  safeCodeFor,
  serializeSafeMarkerFields,
} = require('./android_safe_output_primitives.cjs');
const {
  createBoundedExternalProcessWaiter,
} = require('./android_external_process_wait_primitives.cjs');

const dedicatedDeviceId = 'emulator-5554';
const defaultRunWaitSeconds = 20 * 60;
const minimumRunWaitSeconds = 30;
const maximumRunWaitSeconds = 60 * 60;
const processPollIntervalMs = 500;

function plainAcceptanceError(code) {
  const error = new Error('The plain Flutter acceptance harness failed safely.');
  error.safeCode = code;
  return error;
}

function emitPlainMarker(log, name, fields) {
  if (typeof log !== 'function' || !/^[A-Z_]+$/.test(name)) {
    throw plainAcceptanceError('unsafe_marker_contract');
  }
  const serialized = serializeSafeMarkerFields(fields, () =>
    plainAcceptanceError('unsafe_marker_value'),
  );
  log(`ANDROID_PLAIN_RUN_${name} ${serialized.join(' ')}`.trim());
}

function parseBoundedSeconds(value) {
  if (!/^[0-9]+$/.test(value)) {
    throw plainAcceptanceError('run_wait_invalid');
  }
  const seconds = Number(value);
  if (
    !Number.isSafeInteger(seconds) ||
    seconds < minimumRunWaitSeconds ||
    seconds > maximumRunWaitSeconds
  ) {
    throw plainAcceptanceError('run_wait_invalid');
  }
  return seconds;
}

function parsePlainRunArguments(args, env = process.env) {
  const parsed = {
    executeLive: false,
    explicitDryRun: false,
    promotionConfirmed: false,
    dedicatedDevice: false,
    plainRunsConfirmed: false,
    noBuildInstallConfirmed: false,
    deviceId: env.CASHPILOT_ACCEPTANCE_DEVICE || dedicatedDeviceId,
    gatewayValue:
      env.CASHPILOT_GROQ_GATEWAY_URL ||
      env.CASH_PILOT_AI_GATEWAY_BASE_URL ||
      null,
    runWaitSeconds: defaultRunWaitSeconds,
  };

  for (let index = 0; index < args.length; index += 1) {
    const value = args[index];
    if (value === '--dry-run') {
      parsed.explicitDryRun = true;
      continue;
    }
    if (value === '--execute-live') {
      parsed.executeLive = true;
      continue;
    }
    if (value === '--promotion-confirmed') {
      parsed.promotionConfirmed = true;
      continue;
    }
    if (value === '--dedicated-device') {
      parsed.dedicatedDevice = true;
      continue;
    }
    if (value === '--plain-runs-confirmed') {
      parsed.plainRunsConfirmed = true;
      continue;
    }
    if (value === '--no-build-install-confirmed') {
      parsed.noBuildInstallConfirmed = true;
      continue;
    }
    if (
      value === '--gateway-url' ||
      value === '--device' ||
      value === '--run-wait-seconds'
    ) {
      if (index + 1 >= args.length) {
        throw plainAcceptanceError('argument_value_missing');
      }
      const nextValue = args[index + 1];
      if (value === '--gateway-url') {
        parsed.gatewayValue = nextValue;
      } else if (value === '--device') {
        parsed.deviceId = nextValue;
      } else {
        parsed.runWaitSeconds = parseBoundedSeconds(nextValue);
      }
      index += 1;
      continue;
    }
    if (value.startsWith('--gateway-url=')) {
      parsed.gatewayValue = value.slice('--gateway-url='.length);
      continue;
    }
    if (value.startsWith('--device=')) {
      parsed.deviceId = value.slice('--device='.length);
      continue;
    }
    if (value.startsWith('--run-wait-seconds=')) {
      parsed.runWaitSeconds = parseBoundedSeconds(
        value.slice('--run-wait-seconds='.length),
      );
      continue;
    }
    throw plainAcceptanceError('argument_unsupported');
  }

  if (parsed.executeLive && parsed.explicitDryRun) {
    throw plainAcceptanceError('execution_mode_conflict');
  }
  if (parsed.deviceId !== dedicatedDeviceId) {
    throw plainAcceptanceError('dedicated_emulator_required');
  }

  let gatewayUrl = null;
  if (parsed.gatewayValue) {
    let url;
    try {
      url = new URL(parsed.gatewayValue);
    } catch {
      throw plainAcceptanceError('gateway_origin_invalid');
    }
    if (
      url.protocol !== 'https:' ||
      url.username !== '' ||
      url.password !== '' ||
      url.search !== '' ||
      url.hash !== '' ||
      (url.pathname !== '' && url.pathname !== '/')
    ) {
      throw plainAcceptanceError('gateway_origin_invalid');
    }
    if (url.hostname.startsWith('groq-candidate---')) {
      throw plainAcceptanceError('candidate_tag_forbidden');
    }
    if (url.hostname !== approvedGatewayHost) {
      throw plainAcceptanceError('primary_gateway_host_required');
    }
    gatewayUrl = url.origin;
  }

  if (
    parsed.executeLive &&
    (!parsed.promotionConfirmed ||
      !parsed.dedicatedDevice ||
      !parsed.plainRunsConfirmed ||
      !parsed.noBuildInstallConfirmed ||
      gatewayUrl === null)
  ) {
    throw plainAcceptanceError('live_confirmation_incomplete');
  }

  return Object.freeze({
    executeLive: parsed.executeLive,
    promotionConfirmed: parsed.promotionConfirmed,
    dedicatedDevice: parsed.dedicatedDevice,
    plainRunsConfirmed: parsed.plainRunsConfirmed,
    noBuildInstallConfirmed: parsed.noBuildInstallConfirmed,
    deviceId: parsed.deviceId,
    gatewayUrl,
    runWaitMs: parsed.runWaitSeconds * 1000,
  });
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

const {
  validPid,
  waitForExternalProcessState,
} = createBoundedExternalProcessWaiter({
  defaultPollIntervalMs: processPollIntervalMs,
  defaultWaitImpl: wait,
  errorForCode: plainAcceptanceError,
});

function createProductionCoordinator(adapter) {
  return Object.freeze({
    waitForStarted(deviceId, previousPid, timeoutMs) {
      return waitForExternalProcessState({
        readPid: () => adapter.getPid(deviceId),
        state: 'started',
        previousPid,
        timeoutMs,
      });
    },
    waitForStopped(deviceId, timeoutMs) {
      return waitForExternalProcessState({
        readPid: () => adapter.getPid(deviceId),
        state: 'stopped',
        timeoutMs,
      });
    },
  });
}

function requireQuestionProof(proof, code) {
  if (
    proof?.answerCompleted !== true ||
    proof?.messageDelta !== 2 ||
    proof?.duplicateResponse !== false
  ) {
    throw plainAcceptanceError(code);
  }
  return proof;
}

function requireSettingsProof(
  proof,
  { code, requireRestored = false, requireIdle = true },
) {
  if (
    proof?.rowsVerified !== true ||
    proof?.rowCount !== settingsRequiredResourceIds.length ||
    (requireIdle && proof?.testStatus !== 'idle') ||
    (requireRestored &&
      (proof?.restoredSession !== true ||
        proof?.settingsReopened !== true ||
        proof?.dynamicStatusObserved !== true))
  ) {
    throw plainAcceptanceError(code);
  }
  return proof;
}

function requireSettingsLiveProof(proof, code) {
  if (
    proof?.baselineIdle !== true ||
    typeof proof?.testingUiObserved !== 'boolean' ||
    proof?.stateMachineOrdered !== true ||
    proof?.available !== true
  ) {
    throw plainAcceptanceError(code);
  }
  return proof;
}

function requireRegistrationProof(registration) {
  const existing = registration?.existing === true;
  const created = registration?.resourceCreated === true;
  if (existing === created) {
    throw plainAcceptanceError('app_check_registration_invalid');
  }
  return registration;
}

async function runBestEffort(operation) {
  try {
    return Boolean(await operation());
  } catch {
    return false;
  }
}

function initialCleanupState() {
  return {
    logoutRequired: false,
    logoutAttempted: false,
    logoutRetryAttempted: false,
    signedOut: true,
    signedOutConfirmed: true,
    profileDeleteAttempted: false,
    profileDeleted: true,
    userDeleteAttempted: false,
    userDeleted: true,
    appCheckDeleteAttempted: false,
    appCheckDeleted: true,
    appCheckPreserved: false,
    uiDumpCleared: false,
    logsCleared: false,
    packagePreserved: false,
    externalStopsComplete: true,
    accountComplete: false,
    complete: false,
  };
}

async function cleanAccountState({
  adapter,
  deviceId,
  cloud,
  synthetic,
  registration,
  cleanup,
}) {
  if (cleanup.logoutRequired && !cleanup.logoutAttempted) {
    cleanup.logoutAttempted = true;
    cleanup.signedOut = await runBestEffort(() => adapter.logout(deviceId));
    cleanup.signedOutConfirmed = cleanup.signedOut;
  }
  if (synthetic && cloud && !cleanup.profileDeleteAttempted) {
    cleanup.profileDeleteAttempted = true;
    cleanup.profileDeleted = await runBestEffort(() =>
      adapter.deleteSyntheticProfile(cloud, synthetic),
    );
  }
  if (synthetic && cloud && !cleanup.userDeleteAttempted) {
    cleanup.userDeleteAttempted = true;
    cleanup.userDeleted = await runBestEffort(() =>
      adapter.deleteSyntheticUser(cloud, synthetic),
    );
  }
  if (
    cleanup.logoutRequired &&
    !cleanup.signedOut &&
    cleanup.userDeleted &&
    !cleanup.logoutRetryAttempted
  ) {
    cleanup.logoutRetryAttempted = true;
    cleanup.signedOut = await runBestEffort(async () => {
      const normalized = await adapter.normalizeSignedOut(deviceId);
      return normalized?.signedOut === true;
    });
    cleanup.signedOutConfirmed = cleanup.signedOut;
  }
  if (registration && cloud) {
    if (registration.existing === true) {
      cleanup.appCheckPreserved = true;
      cleanup.appCheckDeleted = true;
    } else if (!cleanup.appCheckDeleteAttempted) {
      cleanup.appCheckDeleteAttempted = true;
      cleanup.appCheckDeleted = await runBestEffort(() =>
        adapter.deleteAppCheckRegistration(cloud, registration),
      );
    }
  }
  cleanup.accountComplete =
    (!cleanup.logoutRequired ||
      (cleanup.signedOut && cleanup.signedOutConfirmed)) &&
    (!synthetic || (cleanup.profileDeleted && cleanup.userDeleted)) &&
    (!registration || cleanup.appCheckDeleted);
  return cleanup.accountComplete;
}

function createExternalRunState(run) {
  return {
    run,
    started: false,
    active: false,
    stopRequested: false,
    stopWaitAttempted: false,
    stopped: false,
    stopFailureCode: null,
  };
}

async function requestExternalRunStop({
  runState,
  coordinator,
  deviceId,
  timeoutMs,
  log,
  reason,
  accountCleanup,
}) {
  if (!runState.started || !runState.active) {
    return !runState.started || runState.stopped;
  }
  if (!runState.stopRequested) {
    emitPlainMarker(log, 'READY_STOP', {
      run: runState.run,
      action: 'sendQToFlutterRun',
      reason,
      accountCleanup,
      packagePreserved: true,
    });
    runState.stopRequested = true;
  }
  if (runState.stopWaitAttempted) {
    return runState.stopped;
  }
  runState.stopWaitAttempted = true;
  try {
    const stopped = await coordinator.waitForStopped(deviceId, timeoutMs);
    if (stopped !== true) {
      throw plainAcceptanceError('external_plain_run_not_stopped');
    }
    runState.active = false;
    runState.stopped = true;
    return true;
  } catch (error) {
    runState.stopFailureCode = safeCodeFor(error);
    emitPlainMarker(log, 'STOP_FAILURE', {
      run: runState.run,
      code: runState.stopFailureCode,
    });
    return false;
  }
}

function feasibilityIsReady(feasibility) {
  return (
    feasibility?.adbAvailable === true &&
    feasibility?.deviceAvailable === true &&
    feasibility?.flutterAvailable === true &&
    feasibility?.packageInstalled === true &&
    feasibility?.uiDriverAvailable === true
  );
}

async function executePlainFlutterAcceptance({
  options,
  adapter = createProductionAdapter(),
  coordinator = createProductionCoordinator(adapter),
  log = console.log,
}) {
  let feasibility;
  try {
    feasibility = await adapter.inspectFeasibility(options.deviceId);
  } catch (error) {
    emitPlainMarker(log, 'FAILURE', {
      stage: 'feasibility',
      code: safeCodeFor(error),
    });
    return Object.freeze({
      exitCode: 1,
      liveExecuted: false,
      failureCode: safeCodeFor(error),
    });
  }

  emitPlainMarker(log, 'FEASIBILITY', {
    adb: feasibility?.adbAvailable === true,
    device: feasibility?.deviceAvailable === true,
    flutter: feasibility?.flutterAvailable === true,
    packageInstalled: feasibility?.packageInstalled === true,
    uiDriver: feasibility?.uiDriverAvailable === true ? 'uiautomator' : 'unavailable',
    noBuild: true,
    noInstall: true,
    noUninstall: true,
    liveExecuted: options.executeLive,
  });

  if (!options.executeLive) {
    emitPlainMarker(log, 'RESULT', {
      completed: false,
      dryRun: true,
      noBuild: true,
      noInstall: true,
      noUninstall: true,
    });
    return Object.freeze({ exitCode: 0, liveExecuted: false });
  }

  let stage = 'preflight';
  let failureCode = null;
  let cloud;
  let synthetic;
  let registration;
  let bootstrapPid = null;
  let runOnePid = null;
  let reopenedPid = null;
  let runTwoPid = null;
  const runOne = createExternalRunState(1);
  const runTwo = createExternalRunState(2);
  let proofCompleted = false;
  let firstQuestionCompleted = false;
  let secondQuestionCompleted = false;
  let runOneSettingsCompleted = false;
  let runTwoSettingsCompleted = false;
  let launcherReopenProven = false;
  const cleanup = initialCleanupState();

  try {
    if (!feasibilityIsReady(feasibility)) {
      throw plainAcceptanceError('plain_preflight_unavailable');
    }

    stage = 'gateway_health';
    await adapter.verifyGatewayHealth(options.gatewayUrl);

    stage = 'cloud_credentials';
    cloud = await adapter.loadCloudCredentials();
    stage = 'synthetic_auth_create';
    synthetic = await adapter.createSyntheticUser(cloud);

    stage = 'app_check_bootstrap';
    bootstrapPid = await adapter.getPid(options.deviceId);
    if (bootstrapPid === null) {
      await adapter.launchFromLauncher(options.deviceId);
      bootstrapPid = await adapter.waitForNewPid(options.deviceId, null);
    }
    if (!validPid(bootstrapPid)) {
      throw plainAcceptanceError('app_check_process_not_observed');
    }
    registration = await adapter.registerAppCheck(options.deviceId, cloud);
    requireRegistrationProof(registration);

    stage = 'prepare_run1_stop';
    await adapter.forceStop(options.deviceId);
    await adapter.waitForStopped(options.deviceId);
    emitPlainMarker(log, 'PREP', {
      syntheticCreated: true,
      profileCreated: true,
      appCheckExisting: registration.existing,
      appCheckCreated: registration.resourceCreated,
      packagePreserved: true,
    });
    emitPlainMarker(log, 'READY_RUN', {
      run: 1,
      action: 'startLiteralFlutterRun',
      plainCommand: true,
      noDefines: true,
      noBuild: true,
      noInstall: true,
    });

    stage = 'wait_run1_start';
    runOnePid = await coordinator.waitForStarted(
      options.deviceId,
      bootstrapPid,
      options.runWaitMs,
    );
    runOne.started = true;
    runOne.active = true;

    stage = 'run1_auth_normalize';
    const priorAuth = await adapter.normalizeSignedOut(options.deviceId);
    if (
      priorAuth?.signedOut !== true ||
      typeof priorAuth?.priorSession !== 'boolean'
    ) {
      throw plainAcceptanceError('prior_auth_not_normalized');
    }
    emitPlainMarker(log, 'AUTH_NORMALIZED', {
      run: 1,
      signedOut: true,
      priorSessionPresent: priorAuth.priorSession,
      resourceIdOnly: true,
    });

    stage = 'run1_login';
    await adapter.reachLoginScreen(options.deviceId);
    cleanup.logoutRequired = true;
    cleanup.signedOut = false;
    cleanup.signedOutConfirmed = false;
    await adapter.login(options.deviceId, synthetic);

    stage = 'run1_first_question';
    await adapter.openAi(options.deviceId);
    const first = requireQuestionProof(
      await adapter.askQuestion(options.deviceId, 0),
      'first_question_completion_not_proven',
    );
    firstQuestionCompleted = true;
    emitPlainMarker(log, 'FIRST', {
      promptClass: 'arabicInflation',
      inputMode: 'oneShotHook',
      prefilled: false,
      sendingObserved: first.sendingObserved === true,
      answerCompleted: true,
      messageDelta: 2,
      duplicateResponse: false,
      providerConfigured: 'groq',
      route: 'generalConversation',
    });

    stage = 'run1_settings';
    const runOneSettings = requireSettingsProof(
      await adapter.verifySettings(options.deviceId),
      { code: 'run1_settings_not_verified' },
    );
    const runOneLive = requireSettingsLiveProof(
      await adapter.runSettingsLiveTest(
        options.deviceId,
        runOneSettings.testStatus,
      ),
      'run1_settings_live_test_not_verified',
    );
    runOneSettingsCompleted = true;
    emitPlainMarker(log, 'SETTINGS', {
      run: 1,
      rowsVerified: true,
      rowCount: settingsRequiredResourceIds.length,
      baselineIdle: true,
      testingObserved: runOneLive.testingUiObserved,
      stateMachineOrdered: true,
      availableObserved: true,
      liveGroq: true,
    });
    stage = 'wait_run1_stop';
    const firstRunStopped = await requestExternalRunStop({
      runState: runOne,
      coordinator,
      deviceId: options.deviceId,
      timeoutMs: options.runWaitMs,
      log,
      reason: 'workflow',
      accountCleanup: 'pending',
    });
    if (!firstRunStopped) {
      throw plainAcceptanceError(
        runOne.stopFailureCode || 'external_plain_run_not_stopped',
      );
    }

    stage = 'launcher_reopen';
    await adapter.launchFromLauncher(options.deviceId);
    reopenedPid = await adapter.waitForNewPid(options.deviceId, runOnePid);
    proveProcessRestart({
      oldPid: runOnePid,
      stopped: true,
      newPid: reopenedPid,
    });
    const reopenedSettings = requireSettingsProof(
      await adapter.verifyRestoredSettings(options.deviceId),
      {
        code: 'launcher_settings_restore_not_verified',
        requireRestored: true,
      },
    );
    launcherReopenProven = true;

    stage = 'launcher_second_question';
    await adapter.navigateToDashboard(options.deviceId);
    await adapter.openAi(options.deviceId, { requireRestoredSession: true });
    const second = requireQuestionProof(
      await adapter.askQuestion(options.deviceId, 1),
      'second_question_completion_not_proven',
    );
    secondQuestionCompleted = true;
    emitPlainMarker(log, 'SECOND', {
      restoredSession: true,
      inputMode: 'replace',
      questionClass: 'englishSavingHabits',
      sendingObserved: second.sendingObserved === true,
      answerCompleted: true,
      messageDelta: 2,
      duplicateResponse: false,
      providerConfigured: 'groq',
      route: 'generalConversation',
    });

    stage = 'prepare_run2_settings';
    requireSettingsProof(await adapter.verifySettings(options.deviceId), {
      code: 'run2_settings_baseline_not_verified',
    });
    await adapter.forceStop(options.deviceId);
    await adapter.waitForStopped(options.deviceId);
    emitPlainMarker(log, 'REOPEN', {
      run1Stopped: true,
      launcherCategory: true,
      newProcessStarted: true,
      pidChanged: true,
      settingsRestored: reopenedSettings.restoredSession,
      secondChat: true,
    });
    emitPlainMarker(log, 'READY_RUN', {
      run: 2,
      action: 'startLiteralFlutterRun',
      plainCommand: true,
      noDefines: true,
      noBuild: true,
      noInstall: true,
    });

    stage = 'wait_run2_start';
    runTwoPid = await coordinator.waitForStarted(
      options.deviceId,
      reopenedPid,
      options.runWaitMs,
    );
    runTwo.started = true;
    runTwo.active = true;

    stage = 'run2_settings_restore';
    const runTwoSettings = requireSettingsProof(
      await adapter.verifyRestoredSettings(options.deviceId),
      {
        code: 'run2_settings_restore_not_verified',
        requireRestored: true,
      },
    );
    const runTwoLive = requireSettingsLiveProof(
      await adapter.runSettingsLiveTest(
        options.deviceId,
        runTwoSettings.testStatus,
      ),
      'run2_settings_live_test_not_verified',
    );
    runTwoSettingsCompleted = true;
    emitPlainMarker(log, 'SETTINGS', {
      run: 2,
      restoredSession: true,
      settingsRestored: true,
      rowsVerified: true,
      rowCount: settingsRequiredResourceIds.length,
      baselineIdle: true,
      testingObserved: runTwoLive.testingUiObserved,
      stateMachineOrdered: true,
      availableObserved: true,
      liveGroq: true,
    });

    stage = 'account_cleanup';
    await cleanAccountState({
      adapter,
      deviceId: options.deviceId,
      cloud,
      synthetic,
      registration,
      cleanup,
    });
    emitPlainMarker(log, 'ACCOUNT_CLEANUP', {
      logoutAttempted: cleanup.logoutAttempted,
      logoutRetryAttempted: cleanup.logoutRetryAttempted,
      signedOut: cleanup.signedOut,
      signedOutConfirmed: cleanup.signedOutConfirmed,
      profileDeleted: cleanup.profileDeleted,
      userDeleted: cleanup.userDeleted,
      appCheckPreserved: cleanup.appCheckPreserved,
      appCheckDeleteAttempted: cleanup.appCheckDeleteAttempted,
      appCheckDeleted: cleanup.appCheckDeleted,
      complete: cleanup.accountComplete,
    });
    stage = 'wait_run2_stop';
    const secondRunStopped = await requestExternalRunStop({
      runState: runTwo,
      coordinator,
      deviceId: options.deviceId,
      timeoutMs: options.runWaitMs,
      log,
      reason: 'workflow',
      accountCleanup: cleanup.accountComplete ? 'complete' : 'incomplete',
    });
    if (!secondRunStopped) {
      throw plainAcceptanceError(
        runTwo.stopFailureCode || 'external_plain_run_not_stopped',
      );
    }
    if (!cleanup.accountComplete) {
      stage = 'account_cleanup';
      throw plainAcceptanceError('cleanup_incomplete');
    }

    proofCompleted =
      firstQuestionCompleted &&
      runOneSettingsCompleted &&
      runOne.stopped &&
      launcherReopenProven &&
      secondQuestionCompleted &&
      runTwoSettingsCompleted &&
      runTwo.stopped;
  } catch (error) {
    failureCode = safeCodeFor(error);
  } finally {
    await cleanAccountState({
      adapter,
      deviceId: options.deviceId,
      cloud,
      synthetic,
      registration,
      cleanup,
    });
    for (const runState of [runOne, runTwo]) {
      if (runState.active) {
        await requestExternalRunStop({
          runState,
          coordinator,
          deviceId: options.deviceId,
          timeoutMs: options.runWaitMs,
          log,
          reason: 'failure',
          accountCleanup: cleanup.accountComplete ? 'complete' : 'incomplete',
        });
      }
    }
    cleanup.externalStopsComplete =
      (!runOne.started || runOne.stopped) &&
      (!runTwo.started || runTwo.stopped);
    cleanup.uiDumpCleared = await runBestEffort(() =>
      adapter.clearUiDump(options.deviceId),
    );
    cleanup.logsCleared = await runBestEffort(() =>
      adapter.clearLogs(options.deviceId),
    );
    const finalFeasibility = await runBestEffort(async () => {
      const current = await adapter.inspectFeasibility(options.deviceId);
      return current?.packageInstalled === true;
    });
    cleanup.packagePreserved = finalFeasibility;
    cleanup.complete =
      cleanup.accountComplete &&
      cleanup.externalStopsComplete &&
      cleanup.uiDumpCleared &&
      cleanup.logsCleared &&
      cleanup.packagePreserved;
    emitPlainMarker(log, 'CLEANUP', {
      logoutRequired: cleanup.logoutRequired,
      logoutAttempted: cleanup.logoutAttempted,
      logoutRetryAttempted: cleanup.logoutRetryAttempted,
      signedOut: cleanup.signedOut,
      signedOutConfirmed: cleanup.signedOutConfirmed,
      profileDeleteAttempted: cleanup.profileDeleteAttempted,
      profileDeleted: cleanup.profileDeleted,
      userDeleteAttempted: cleanup.userDeleteAttempted,
      userDeleted: cleanup.userDeleted,
      appCheckPreserved: cleanup.appCheckPreserved,
      appCheckDeleteAttempted: cleanup.appCheckDeleteAttempted,
      appCheckDeleted: cleanup.appCheckDeleted,
      externalStopsComplete: cleanup.externalStopsComplete,
      uiDumpCleared: cleanup.uiDumpCleared,
      logsCleared: cleanup.logsCleared,
      packagePreserved: cleanup.packagePreserved,
      noUninstall: true,
      complete: cleanup.complete,
    });
    cloud = undefined;
    synthetic = undefined;
    registration = undefined;
    bootstrapPid = null;
    runOnePid = null;
    reopenedPid = null;
    runTwoPid = null;
  }

  if (!cleanup.complete && failureCode === null) {
    stage = 'cleanup';
    failureCode = 'cleanup_incomplete';
  }
  if (failureCode !== null) {
    emitPlainMarker(log, 'FAILURE', {
      stage,
      code: failureCode,
      run1Active: runOne.active,
      run2Active: runTwo.active,
    });
  }
  emitPlainMarker(log, 'RESULT', {
    completed: failureCode === null && proofCompleted && cleanup.complete,
    firstChat: firstQuestionCompleted,
    run1Settings: runOneSettingsCompleted,
    run1Stopped: runOne.stopped,
    launcherReopen: launcherReopenProven,
    secondChat: secondQuestionCompleted,
    run2Settings: runTwoSettingsCompleted,
    run2Stopped: runTwo.stopped,
    externalStops: cleanup.externalStopsComplete,
    cleanup: cleanup.complete,
    noBuild: true,
    noInstall: true,
    noUninstall: true,
  });
  return Object.freeze({
    exitCode:
      failureCode === null && proofCompleted && cleanup.complete ? 0 : 1,
    liveExecuted: true,
    ...(failureCode === null ? {} : { failureCode }),
  });
}

async function main(args = process.argv.slice(2)) {
  let options;
  try {
    options = parsePlainRunArguments(args);
  } catch (error) {
    emitPlainMarker(console.log, 'FAILURE', {
      stage: 'arguments',
      code: safeCodeFor(error),
    });
    return 1;
  }
  const result = await executePlainFlutterAcceptance({ options });
  return result.exitCode;
}

module.exports = {
  createProductionCoordinator,
  emitPlainMarker,
  executePlainFlutterAcceptance,
  main,
  parsePlainRunArguments,
  requireQuestionProof,
  requireSettingsLiveProof,
  requireSettingsProof,
  waitForExternalProcessState,
};
