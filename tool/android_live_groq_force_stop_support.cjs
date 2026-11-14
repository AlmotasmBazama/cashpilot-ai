'use strict';

const {
  safeCodeFor,
  serializeSafeMarkerFields,
} = require('./android_safe_output_primitives.cjs');
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
  fillAndSubmitLogin,
  findAndTapLoginSubmit,
  findUiTarget,
  firestoreProfileUrl,
  loginStateFromUiXml,
  normalizeSignedOutSession,
  observeLoginAuthentication,
  observeQuestionCompletion,
  observeSettingsTestTransition,
  performResourceIdLogout,
  pidFromCommandResult,
  prepareAndSubmitQuestion,
  proveProcessRestart,
  questionInputMode,
  safeRunnerError,
  settingsRequiredResourceIds,
  settingsStateFromUiXml,
  syntheticPassword,
  triggerSettingsLiveTest,
  verifySyntheticCredentials,
} = require('./android_cashpilot_acceptance_support.cjs');

function emitSafeMarker(log, name, fields) {
  if (!/^[A-Z_]+$/.test(name)) {
    throw safeRunnerError('unsafe_marker_name');
  }
  const serialized = serializeSafeMarkerFields(fields, () =>
    safeRunnerError('unsafe_marker_value'),
  );
  log(`ANDROID_GROQ_RESTART_${name} ${serialized.join(' ')}`.trim());
}

function parseForceStopArguments(args, env = process.env) {
  const parsed = {
    executeLive: false,
    explicitDryRun: false,
    promotionConfirmed: false,
    dedicatedDevice: false,
    deviceId: env.CASHPILOT_ACCEPTANCE_DEVICE || 'emulator-5554',
    gatewayValue:
      env.CASHPILOT_GROQ_GATEWAY_URL ||
      env.CASH_PILOT_AI_GATEWAY_BASE_URL ||
      null,
    gatewaySource: 'environment',
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
    if (value === '--gateway-url' || value === '--device') {
      if (index + 1 >= args.length) {
        throw safeRunnerError('argument_value_missing');
      }
      const nextValue = args[index + 1];
      if (value === '--gateway-url') {
        parsed.gatewayValue = nextValue;
        parsed.gatewaySource = 'argument';
      } else {
        parsed.deviceId = nextValue;
      }
      index += 1;
      continue;
    }
    if (value.startsWith('--gateway-url=')) {
      parsed.gatewayValue = value.slice('--gateway-url='.length);
      parsed.gatewaySource = 'argument';
      continue;
    }
    if (value.startsWith('--device=')) {
      parsed.deviceId = value.slice('--device='.length);
      continue;
    }
    throw safeRunnerError('argument_unsupported');
  }

  if (parsed.executeLive && parsed.explicitDryRun) {
    throw safeRunnerError('execution_mode_conflict');
  }
  if (!/^emulator-[0-9]+$/.test(parsed.deviceId)) {
    throw safeRunnerError('dedicated_emulator_required');
  }

  let gatewayUrl = null;
  if (parsed.gatewayValue) {
    let url;
    try {
      url = new URL(parsed.gatewayValue);
    } catch {
      throw safeRunnerError('gateway_origin_invalid');
    }
    if (
      url.protocol !== 'https:' ||
      url.username !== '' ||
      url.password !== '' ||
      url.search !== '' ||
      url.hash !== '' ||
      (url.pathname !== '' && url.pathname !== '/')
    ) {
      throw safeRunnerError('gateway_origin_invalid');
    }
    if (url.hostname.startsWith('groq-candidate---')) {
      throw safeRunnerError('candidate_tag_forbidden');
    }
    if (url.hostname !== approvedGatewayHost) {
      throw safeRunnerError('primary_gateway_host_required');
    }
    gatewayUrl = url.origin;
  }

  if (
    parsed.executeLive &&
    (!parsed.promotionConfirmed ||
      !parsed.dedicatedDevice ||
      gatewayUrl === null)
  ) {
    throw safeRunnerError('live_confirmation_incomplete');
  }

  return Object.freeze({
    executeLive: parsed.executeLive,
    promotionConfirmed: parsed.promotionConfirmed,
    dedicatedDevice: parsed.dedicatedDevice,
    deviceId: parsed.deviceId,
    gatewayUrl,
    gatewaySource: parsed.gatewaySource,
  });
}

async function runBestEffort(operation) {
  try {
    return Boolean(await operation());
  } catch {
    return false;
  }
}

async function executeForceStopAcceptance({
  options,
  adapter = createProductionAdapter(),
  log = console.log,
}) {
  const feasibility = await adapter.inspectFeasibility(options.deviceId);
  emitSafeMarker(log, 'FEASIBILITY', {
    adb: feasibility.adbAvailable,
    device: feasibility.deviceAvailable,
    flutter: feasibility.flutterAvailable,
    packageInstalled: feasibility.packageInstalled,
    uiDriver: feasibility.uiDriverAvailable ? 'uiautomator' : 'unavailable',
    liveExecuted: options.executeLive,
  });
  if (!options.executeLive) {
    return Object.freeze({ exitCode: 0, liveExecuted: false });
  }

  let stage = 'preflight';
  let failureCode = null;
  let cloud;
  let synthetic;
  let registration;
  let packageTouched = false;
  let launched = false;
  let proofCompleted = false;
  let processRestartProven = false;
  let settingsBeforeVerified = false;
  let settingsLiveTestPassed = false;
  let settingsAfterVerified = false;
  let secondQuestionCompleted = false;
  let logoutAttempted = false;
  let signedOut = false;
  let profileDeleteAttempted = false;
  let profileDeleted = false;
  let userDeleteAttempted = false;
  let userDeleted = false;
  let appCheckCleaned = true;
  let uiDumpCleared = false;
  let packageAbsent = !feasibility.packageInstalled;
  let logsCleared = false;
  let cleanupComplete = false;

  try {
    if (
      !feasibility.adbAvailable ||
      !feasibility.deviceAvailable ||
      !feasibility.flutterAvailable ||
      !feasibility.uiDriverAvailable
    ) {
      throw safeRunnerError('live_tooling_unavailable');
    }
    if (feasibility.packageInstalled) {
      throw safeRunnerError('dedicated_emulator_not_clean');
    }
    stage = 'gateway_health';
    await adapter.verifyGatewayHealth(options.gatewayUrl);
    emitSafeMarker(log, 'CONFIG', {
      primaryHost: true,
      promotionConfirmation: 'operator',
      healthReady: true,
      clientVersion: 'compatible',
    });
    emitSafeMarker(log, 'SCOPE', {
      buildVariant: 'debug',
      appCheck: 'debugToken',
      uiPath: 'productionWidgets',
      releaseArtifact: false,
      playIntegrity: false,
    });

    stage = 'build_install';
    packageTouched = true;
    const buildStartedAt = Date.now();
    await adapter.buildAndInstall(options.deviceId, options.gatewayUrl);
    emitSafeMarker(log, 'BUILD', {
      installed: true,
      packageWasAbsent: true,
      durationMs: Date.now() - buildStartedAt,
    });

    stage = 'cloud_credentials';
    cloud = await adapter.loadCloudCredentials();
    stage = 'synthetic_auth_create';
    synthetic = await adapter.createSyntheticUser(cloud);
    emitSafeMarker(log, 'AUTH', {
      syntheticCreated: true,
      emailVerified: true,
      profileComplete: true,
      profileDocument: true,
    });

    stage = 'initial_launcher_start';
    await adapter.launchFromLauncher(options.deviceId);
    launched = true;
    stage = 'app_check_registration';
    registration = await adapter.registerAppCheck(options.deviceId, cloud);
    emitSafeMarker(log, 'APPCHECK', {
      available: true,
      registrationCreated: registration.resourceCreated,
      registrationExisting: registration.existing,
    });

    // A newly allowlisted debug token may have been rejected and cached by
    // the SDK process that exposed it. Prove a bounded process refresh before
    // authentication so protected Firebase hydration uses the accepted token.
    stage = 'app_check_process_refresh';
    const appCheckOldPid = await adapter.getPid(options.deviceId);
    if (!appCheckOldPid) {
      throw safeRunnerError('app_check_process_not_observed');
    }
    const appCheckRefreshStartedAt = Date.now();
    await adapter.forceStop(options.deviceId);
    const appCheckStopped = await adapter.waitForStopped(options.deviceId);
    await adapter.launchFromLauncher(options.deviceId);
    const appCheckNewPid = await adapter.waitForNewPid(
      options.deviceId,
      appCheckOldPid,
    );
    const appCheckRefresh = proveProcessRestart({
      oldPid: appCheckOldPid,
      stopped: appCheckStopped,
      newPid: appCheckNewPid,
    });
    emitSafeMarker(log, 'APPCHECK_PROCESS', {
      oldProcessStopped: appCheckRefresh.oldProcessStopped,
      launcherCategory: true,
      newProcessStarted: appCheckRefresh.newProcessStarted,
      pidChanged: appCheckRefresh.pidChanged,
      durationMs: Date.now() - appCheckRefreshStartedAt,
    });

    stage = 'ui_reach_login';
    await adapter.reachLoginScreen(options.deviceId);
    emitSafeMarker(log, 'UI', { loginScreen: true });
    stage = 'ui_auth_submit';
    await adapter.login(options.deviceId, synthetic);
    stage = 'first_ui_question';
    await adapter.openAi(options.deviceId);
    const firstStartedAt = Date.now();
    const first = await adapter.askQuestion(options.deviceId, 0);
    if (
      first?.answerCompleted !== true ||
      first?.messageDelta !== 2 ||
      first?.duplicateResponse !== false
    ) {
      throw safeRunnerError('first_question_completion_not_proven');
    }
    emitSafeMarker(log, 'FIRST', {
      sendingObserved: first.sendingObserved,
      answerCompleted: first.answerCompleted,
      messageDelta: first.messageDelta,
      duplicateResponse: first.duplicateResponse,
      promptClass: 'arabicInflation',
      inputMode: 'oneShotHook',
      prefilled: false,
      providerConfigured: 'groq',
      route: 'generalConversation',
      firebaseFallback: false,
      durationMs: Date.now() - firstStartedAt,
    });

    stage = 'settings_before_restart';
    const settingsBeforeStartedAt = Date.now();
    const settingsBefore = await adapter.verifySettings(options.deviceId);
    if (
      settingsBefore?.rowsVerified !== true ||
      settingsBefore?.rowCount !== settingsRequiredResourceIds.length ||
      settingsBefore?.testStatus === null ||
      settingsBefore?.testStatus === undefined
    ) {
      throw safeRunnerError('settings_rows_not_verified');
    }
    if (settingsBefore.testStatus !== 'idle') {
      throw safeRunnerError('settings_live_test_baseline_invalid');
    }
    settingsBeforeVerified = true;
    emitSafeMarker(log, 'SETTINGS', {
      phase: 'beforeRestart',
      rowsVerified: true,
      dynamicStatus: true,
      card: true,
      remoteGroq: true,
      general20b: true,
      financial120b: true,
      localParser: true,
      receiptFirebase: true,
      fallbackDisabled: true,
      gatewayAvailable: true,
      authReady: true,
      appCheckVerified: true,
      liveTest: true,
      durationMs: Date.now() - settingsBeforeStartedAt,
    });

    stage = 'settings_live_test';
    const settingsTestStartedAt = Date.now();
    const settingsTest = await adapter.runSettingsLiveTest(
      options.deviceId,
      settingsBefore.testStatus,
    );
    if (
      settingsTest?.baselineIdle !== true ||
      typeof settingsTest?.testingUiObserved !== 'boolean' ||
      settingsTest?.stateMachineOrdered !== true ||
      settingsTest?.available !== true
    ) {
      throw safeRunnerError('settings_live_test_not_verified');
    }
    settingsLiveTestPassed = true;
    emitSafeMarker(log, 'SETTINGS_TEST', {
      baselineIdle: true,
      testingUiObserved: settingsTest.testingUiObserved,
      stateMachineOrdered: settingsTest.stateMachineOrdered,
      availableObserved: true,
      durationMs: Date.now() - settingsTestStartedAt,
    });

    stage = 'force_stop';
    const oldPid = await adapter.getPid(options.deviceId);
    if (!oldPid) {
      throw safeRunnerError('old_process_not_observed');
    }
    const restartStartedAt = Date.now();
    await adapter.forceStop(options.deviceId);
    const stopped = await adapter.waitForStopped(options.deviceId);
    stage = 'launcher_reopen';
    await adapter.launchFromLauncher(options.deviceId);
    const newPid = await adapter.waitForNewPid(options.deviceId, oldPid);
    const restart = proveProcessRestart({ oldPid, stopped, newPid });
    processRestartProven = true;
    emitSafeMarker(log, 'PROCESS', {
      oldProcessStopped: restart.oldProcessStopped,
      launcherCategory: true,
      newProcessStarted: restart.newProcessStarted,
      pidChanged: restart.pidChanged,
      durationMs: Date.now() - restartStartedAt,
    });

    stage = 'settings_after_restart';
    const settingsAfterStartedAt = Date.now();
    const settingsAfter = await adapter.verifyRestoredSettings(
      options.deviceId,
    );
    if (
      settingsAfter?.rowsVerified !== true ||
      settingsAfter?.rowCount !== settingsRequiredResourceIds.length ||
      settingsAfter?.restoredSession !== true ||
      settingsAfter?.settingsReopened !== true ||
      settingsAfter?.dynamicStatusObserved !== true
    ) {
      throw safeRunnerError('settings_reopen_not_verified');
    }
    settingsAfterVerified = true;
    emitSafeMarker(log, 'SETTINGS_REOPEN', {
      restoredSession: true,
      settingsReopened: true,
      rowsVerified: true,
      dynamicStatus: true,
      card: true,
      remoteGroq: true,
      general20b: true,
      financial120b: true,
      localParser: true,
      receiptFirebase: true,
      fallbackDisabled: true,
      gatewayAvailable: true,
      authReady: true,
      appCheckVerified: true,
      liveTest: true,
      durationMs: Date.now() - settingsAfterStartedAt,
    });

    stage = 'dashboard_after_restart';
    await adapter.navigateToDashboard(options.deviceId);

    stage = 'second_ui_question';
    await adapter.openAi(options.deviceId, { requireRestoredSession: true });
    const secondStartedAt = Date.now();
    const second = await adapter.askQuestion(options.deviceId, 1);
    if (
      second?.answerCompleted !== true ||
      second?.messageDelta !== 2 ||
      second?.duplicateResponse !== false
    ) {
      throw safeRunnerError('second_question_completion_not_proven');
    }
    secondQuestionCompleted = true;
    emitSafeMarker(log, 'SECOND', {
      restoredSession: true,
      sendingObserved: second.sendingObserved,
      answerCompleted: second.answerCompleted,
      messageDelta: second.messageDelta,
      duplicateResponse: second.duplicateResponse,
      providerConfigured: 'groq',
      route: 'generalConversation',
      firebaseFallback: false,
      durationMs: Date.now() - secondStartedAt,
    });
    proofCompleted =
      settingsBeforeVerified &&
      settingsLiveTestPassed &&
      processRestartProven &&
      settingsAfterVerified &&
      secondQuestionCompleted;
  } catch (error) {
    if (error?.safeSettingsPresence) {
      emitSafeMarker(log, 'SETTINGS_INCOMPLETE', error.safeSettingsPresence);
    }
    failureCode = safeCodeFor(error);
  } finally {
    if (synthetic && cloud) {
      profileDeleteAttempted = true;
      profileDeleted = await runBestEffort(() =>
        adapter.deleteSyntheticProfile(cloud, synthetic),
      );
      userDeleteAttempted = true;
      userDeleted = await runBestEffort(() =>
        adapter.deleteSyntheticUser(cloud, synthetic),
      );
    }
    if (registration && cloud) {
      appCheckCleaned = await runBestEffort(() =>
        adapter.deleteAppCheckRegistration(cloud, registration),
      );
    }
    if (launched) {
      logoutAttempted = true;
      signedOut = await runBestEffort(() => adapter.logout(options.deviceId));
    }
    uiDumpCleared = await runBestEffort(() =>
      adapter.clearUiDump(options.deviceId),
    );
    logsCleared = await runBestEffort(() =>
      adapter.clearLogs(options.deviceId),
    );
    if (packageTouched) {
      packageAbsent = await runBestEffort(() =>
        adapter.uninstall(options.deviceId),
      );
    }
    cleanupComplete =
      (!synthetic || (profileDeleted && userDeleted)) &&
      (!registration || appCheckCleaned) &&
      uiDumpCleared &&
      logsCleared &&
      packageAbsent;
    emitSafeMarker(log, 'CLEANUP', {
      logoutAttempted,
      signedOut,
      profileDeleteAttempted,
      profileDeleted,
      userDeleteAttempted,
      userDeleted,
      appCheckCleaned,
      uiDumpCleared,
      logsCleared,
      packageAbsent,
      complete: cleanupComplete,
    });
    cloud = undefined;
    synthetic = undefined;
    registration = undefined;
  }

  if (!cleanupComplete && failureCode === null) {
    stage = 'cleanup';
    failureCode = 'cleanup_incomplete';
  }

  if (failureCode !== null) {
    emitSafeMarker(log, 'FAILURE', { stage, code: failureCode });
    emitSafeMarker(log, 'RESULT', {
      completed: false,
      processRestart: processRestartProven,
      secondQuestion: secondQuestionCompleted,
      cleanup: cleanupComplete,
      settingsBefore: settingsBeforeVerified,
      settingsTest: settingsLiveTestPassed,
      settingsAfter: settingsAfterVerified,
    });
    return Object.freeze({ exitCode: 1, liveExecuted: true, failureCode });
  }
  emitSafeMarker(log, 'RESULT', {
    completed: proofCompleted && cleanupComplete,
    processRestart: processRestartProven,
    secondQuestion: secondQuestionCompleted,
    cleanup: cleanupComplete,
    settingsBefore: settingsBeforeVerified,
    settingsTest: settingsLiveTestPassed,
    settingsAfter: settingsAfterVerified,
  });
  return Object.freeze({
    exitCode: proofCompleted && cleanupComplete ? 0 : 1,
    liveExecuted: true,
  });
}

async function main(args = process.argv.slice(2)) {
  let options;
  try {
    options = parseForceStopArguments(args);
  } catch (error) {
    emitSafeMarker(console.log, 'FAILURE', {
      stage: 'arguments',
      code: safeCodeFor(error),
    });
    return 1;
  }
  const result = await executeForceStopAcceptance({ options });
  return result.exitCode;
}

module.exports = {
  acceptanceBuildExtraDefines,
  acceptanceStateFromUiXml,
  approvedGatewayHost,
  authSurfaceFromUiXml,
  collectRequiredSettingsRows,
  collectSettingsRowsAcrossRefreshes,
  composerInputStateFromUiXml,
  credentialClearCommands,
  createSyntheticProfile,
  createProductionAdapter,
  deleteSyntheticProfile,
  emailInputCommands,
  emitSafeMarker,
  executeForceStopAcceptance,
  fillAndSubmitLogin,
  findAndTapLoginSubmit,
  findUiTarget,
  firestoreProfileUrl,
  loginStateFromUiXml,
  main,
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
};
